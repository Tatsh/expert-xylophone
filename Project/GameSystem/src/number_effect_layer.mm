#include "number_effect_layer.h"

#import "RBUserSettingData.h"
#include "bg_layer.h"
#include "game_scene.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#include "sprite_uv_table.h"
#include "touch_point.h"
#include "touchmanager.h"

namespace {
constexpr const char *kAtlasTextureName = "00_texture/gm_parts2";

constexpr float kMirrorOffset = -6.0f;
constexpr float kTransformPadX = -103.0f; // @ghidraAddress 0x30fb00
constexpr float kTransformPadZ = 206.0f;  // @ghidraAddress 0x30fb08
constexpr float kTransformPhoneZ = 96.0f; // @ghidraAddress 0x30fb0c
constexpr float kTransformPadW = 7.0f;

// @ghidraAddress 0x30fb70
constexpr int kBatchCapacity[] = {1, 1, 1, 2};

// @ghidraAddress 0x2f8558
constexpr float kWideScreenSplit = 320.0f;

constexpr int kAnchorElementCount = 4;
constexpr int kWideVariantCount = 2;

enum AnchorGravity {
    kGravityBottomCentre = 0,
    kGravityTopCentre = 1,
    kGravityTopLeft = 2,
    kGravityTopRight = 3,
    kGravityLeftCentre = 4,
};

constexpr S_VECTOR2 kPortraitAnchor[kAnchorElementCount] = {
    {0.0f, -69.0f}, {132.0f, 63.0f}, {0.0f, 0.0f}, {0.0f, 0.0f}};
constexpr int kPortraitGravity[kAnchorElementCount] = {
    kGravityBottomCentre, kGravityTopLeft, kGravityTopLeft, kGravityTopCentre};

constexpr S_VECTOR2 kLandscapeAnchor[kWideVariantCount][kAnchorElementCount] = {
    {{29.0f, -13.0f}, {-128.0f, -13.0f}, {0.0f, 31.0f}, {0.0f, 0.0f}},
    {{31.0f, -12.0f}, {-126.0f, -12.0f}, {73.0f, 12.0f}, {-73.0f, 12.0f}},
};
constexpr int kLandscapeGravity[kWideVariantCount][kAnchorElementCount] = {
    {kGravityBottomCentre, kGravityBottomCentre, kGravityTopCentre, kGravityTopCentre},
    {kGravityBottomCentre, kGravityBottomCentre, kGravityTopLeft, kGravityTopRight},
};
} // namespace

namespace {
constexpr float kOpaqueAlpha = 255.0f;

struct NumberElementDescriptor {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    int nUvIndex;
};

// @ghidraAddress 0x30fbd0
constexpr NumberElementDescriptor kLandscapeElements[] = {
    {124.0f, 10.0f, 248.0f, 20.0f, 0x175},
    {2.0f, 6.0f, 4.0f, 12.0f, 0x176},
    {25.0f, 10.0f, 50.0f, 20.0f, 0x177},
    {70.0f, 9.0f, 140.0f, 18.0f, 0x178},
};
// @ghidraAddress 0x30fb80
constexpr NumberElementDescriptor kPortraitElements[] = {
    {178.0f, 25.0f, 356.0f, 50.0f, 0xf4},
    {2.0f, 7.0f, 4.0f, 12.0f, 0xf5},
    {50.0f, 16.0f, 100.0f, 32.0f, 0xf6},
    {70.0f, 9.0f, 140.0f, 18.0f, 0xf7},
};
} // namespace

/** @ghidraAddress 0x189ef0 */
void NumberEffectLayer::AdvanceFadeInterp(float flDeltaTime) {
    if (m_fadeChannel.GetElapsed() >= m_fadeChannel.GetDuration()) {
        return;
    }
    m_fadeChannel.Advance(flDeltaTime);
    m_bFadeActive = true;
}

/** @ghidraAddress 0x189e98 */
void NumberEffectLayer::StartFadeIn(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(kOpaqueAlpha);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(kOpaqueAlpha);
        m_bFadeActive = true;
    }
}

/** @ghidraAddress 0x189ec8 */
void NumberEffectLayer::StartFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(0.0f);
        m_bFadeActive = true;
    }
}

/** @ghidraAddress 0x18a7a8 */
void NumberEffectLayer::SetBrightness(float flValue) {
    if (flValue < 0.0f) {
        flValue = 0.0f;
    } else if (flValue > 1.0f) {
        flValue = 1.0f;
    }
    m_flBrightness = flValue;
}

/** @ghidraAddress 0x18a2d4 */
void NumberEffectLayer::ComputeAnchorPos(unsigned int nElement, S_VECTOR2 *pOut) const {
    int nGravity;
    if (IsPad()) {
        *pOut = kPortraitAnchor[nElement];
        nGravity = kPortraitGravity[nElement];
    } else {
        const int nVariant = m_bWideScreen ? 1 : 0;
        *pOut = kLandscapeAnchor[nVariant][nElement];
        nGravity = kLandscapeGravity[nVariant][nElement];
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flWidth = pGameSystem->GetViewportWidth();
    const float flHeight = pGameSystem->GetViewportHeight();
    switch (nGravity) {
    case kGravityBottomCentre:
        pOut->x += flWidth * 0.5f;
        pOut->y += flHeight;
        break;
    case kGravityTopCentre:
        pOut->x += flWidth * 0.5f;
        break;
    case kGravityTopRight:
        pOut->x += flWidth;
        break;
    case kGravityLeftCentre:
        pOut->y += flHeight * 0.5f;
        break;
    case kGravityTopLeft:
    default:
        break;
    }
}

/** @ghidraAddress 0x18a674 */
void NumberEffectLayer::EmitNumberSprite(
    float flX, float flY, unsigned int nBatch, unsigned int nDescIndex, unsigned int nColour) {
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    const int nIndex = pBatch->GetSpriteCount();
    if (nIndex >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    const NumberElementDescriptor &element =
        IsPad() ? kPortraitElements[nDescIndex] : kLandscapeElements[nDescIndex];
    const SpriteUvEntry &uv = g_aSpriteUvTable[element.nUvIndex];
    const auto nAlpha = static_cast<unsigned int>(static_cast<int>(m_fadeChannel.GetCurrent()));

    pBatch->SetSpritePosition(nIndex, S_VECTOR2{flX, flY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{element.flSizeW, element.flSizeH});
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{element.flAnchorX, element.flAnchorY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteColor(nIndex, nColour, nColour, nColour, nAlpha);
    pBatch->SetSpriteCount(nIndex + 1);
}

namespace {
constexpr int kSliderTargetTrack = 0;
constexpr int kSliderTargetKnob = 1;

// @ghidraAddress 0x2fedf8/0x30fb04/0x30fb10/0x30fb18
constexpr float kKnobLeftInsetPad = -50.0f;
constexpr float kKnobLeftInsetPhone = -25.0f;
constexpr float kKnobWidthPad = 100.0f;
constexpr float kKnobWidthPhone = 50.0f;
constexpr float kTrackLeftInsetPad = -178.0f;
constexpr float kTrackLeftInsetPhone = -29.0f;
constexpr float kTrackWidthPad = 356.0f;
constexpr float kTrackWidthPhone = 145.0f;
constexpr float kSliderTopInset = -25.0f;
constexpr float kSliderHeight = 50.0f;

constexpr int kSliderCancelSoundEffect = 3;

inline bool
IsInsideSliderRect(float flX, float flY, float flLeft, float flTop, float flWidth, float flHeight) {
    return flLeft <= flX && flX <= flLeft + flWidth && flTop <= flY && flY <= flTop + flHeight;
}
} // namespace

/** @ghidraAddress 0x189f40 */
void NumberEffectLayer::ProcessBrightnessSliderTouch() {
    TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();

    for (int nTarget = kSliderTargetTrack; nTarget <= kSliderTargetKnob; ++nTarget) {
        S_VECTOR2 anchor{0.0f, 0.0f};
        ComputeAnchorPos(static_cast<unsigned int>(nTarget), &anchor);
        float flLeftInset;
        float flWidth;
        if (nTarget == kSliderTargetKnob) {
            flLeftInset = IsPad() ? kKnobLeftInsetPad : kKnobLeftInsetPhone;
            flWidth = IsPad() ? kKnobWidthPad : kKnobWidthPhone;
        } else {
            flLeftInset = IsPad() ? kTrackLeftInsetPad : kTrackLeftInsetPhone;
            flWidth = IsPad() ? kTrackWidthPad : kTrackWidthPhone;
        }
        const float flLeft = anchor.x + flLeftInset;
        const float flTop = anchor.y + kSliderTopInset;

        int &nTouchId = m_anSliderTouchId[nTarget];
        if (nTouchId == -1) {
            for (int i = 0; i < pTouchManager->GetActiveTouchCount(); ++i) {
                TouchPoint *pTouch = pTouchManager->GetActiveTouch(i);
                if (!pTouch->bIsNew) {
                    continue;
                }
                if (IsInsideSliderRect(static_cast<float>(pTouch->nBeginX),
                                       static_cast<float>(pTouch->nBeginY),
                                       flLeft,
                                       flTop,
                                       flWidth,
                                       kSliderHeight)) {
                    nTouchId = pTouch->nId;
                    if (nTarget == kSliderTargetKnob) {
                        m_bSliderHeld = true;
                    }
                    break;
                }
            }
            if (nTouchId == -1) {
                continue;
            }
        }

        TouchPoint *pTouch = pTouchManager->FindTouchById(nTouchId);
        if (pTouch == nullptr) {
            nTouchId = -1;
            if (nTarget == kSliderTargetKnob) {
                m_bSliderHeld = false;
            }
            continue;
        }

        if (nTarget == kSliderTargetKnob) {
            const bool bInside = IsInsideSliderRect(static_cast<float>(pTouch->nCurrentX),
                                                    static_cast<float>(pTouch->nCurrentY),
                                                    flLeft,
                                                    flTop,
                                                    flWidth,
                                                    kSliderHeight);
            bool bHeld;
            if (!bInside) {
                bHeld = false;
            } else if (!pTouch->bEnded) {
                bHeld = true;
            } else {
                bHeld = false;
                SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSliderCancelSoundEffect);
                GameSystem::GetGameSystem()->GetCurrentScene()->SetGameSceneState13();
                m_anSliderTouchId[kSliderTargetKnob] = -1;
            }
            m_bSliderHeld = bHeld;
        } else {
            S_VECTOR2 trackAnchor{0.0f, 0.0f};
            ComputeAnchorPos(kSliderTargetTrack, &trackAnchor);
            float flBrightness =
                ((static_cast<float>(pTouch->nCurrentX) - trackAnchor.x) - m_aTransform[0]) /
                m_aTransform[2];
            if (flBrightness < 0.0f) {
                flBrightness = 0.0f;
            } else if (flBrightness >= 1.0f) {
                flBrightness = 1.0f;
            }
            m_flBrightness = flBrightness;

            [RBUserSettingData.sharedInstance resetBackgroundBrightness:flBrightness];
            BgLayer::GetBackgroundLayer()->SetBackgroundBrightness(
                RBUserSettingData.sharedInstance.backgroundBrighness);
            [RBUserSettingData.sharedInstance save];
        }
    }
}

/** @ghidraAddress 0x18a4ac */
void NumberEffectLayer::Update(float flDeltaTime) {
    constexpr unsigned int kTrackBatch = 3;
    constexpr unsigned int kKnobBatch = 2;
    constexpr unsigned int kFillBatch = 0;
    constexpr unsigned int kFillMarkerBatch = 1;
    constexpr unsigned int kTrackElement = 2;
    constexpr unsigned int kTrackWideElement = 3;
    constexpr unsigned int kKnobElement = 1;
    // The knob's glyph row is not its anchor element. @ghidraAddress 0x18a5bc
    constexpr unsigned int kKnobDescriptor = 2;
    constexpr unsigned int kFillElement = 0;
    constexpr unsigned int kOpaque = 0xff;
    constexpr unsigned int kHeldAlpha = 0x80;
    constexpr unsigned int kWhite = 0xff;

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flWidth = pGameSystem->GetViewportWidth();
    const float flHeight = pGameSystem->GetViewportHeight();
    if (m_flCachedViewportWidth != flWidth || m_flCachedViewportHeight != flHeight) {
        m_flCachedViewportWidth = flWidth;
        m_flCachedViewportHeight = flHeight;
        m_bWideScreen = GameSystem::GetGameSystem()->GetViewportWidth() > kWideScreenSplit;
    }

    AdvanceFadeInterp(flDeltaTime);

    for (auto *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }

    ProcessBrightnessSliderTouch();

    S_VECTOR2 pos{};
    if (!IsPad()) {
        ComputeAnchorPos(kTrackElement, &pos);
        EmitNumberSprite(pos.x, pos.y, kTrackBatch, kTrackWideElement, kWhite);
        if (m_bWideScreen) {
            ComputeAnchorPos(kTrackWideElement, &pos);
            EmitNumberSprite(pos.x, pos.y, kTrackBatch, kTrackWideElement, kWhite);
        }
    }

    ComputeAnchorPos(kKnobElement, &pos);
    EmitNumberSprite(
        pos.x, pos.y, kKnobBatch, kKnobDescriptor, m_bSliderHeld ? kHeldAlpha : kOpaque);

    ComputeAnchorPos(kFillElement, &pos);
    EmitNumberSprite(pos.x, pos.y, kFillBatch, kFillElement, kWhite);
    EmitNumberSprite(pos.x + m_aTransform[0] + m_flBrightness * m_aTransform[2],
                     pos.y + m_aTransform[1],
                     kFillMarkerBatch,
                     kKnobElement,
                     kWhite);
}

static NumberEffectLayer *g_pNumberEffectLayer = nullptr; // @ghidraAddress 0x3df240

/** @ghidraAddress 0x189ce0 */
NumberEffectLayer *NumberEffectLayer::shared() {
    if (g_pNumberEffectLayer == nullptr) {
        g_pNumberEffectLayer = new NumberEffectLayer();
    }
    return g_pNumberEffectLayer;
}

/** @ghidraAddress 0x189d50 */
void NumberEffectLayer::FreeInstance() {
    if (g_pNumberEffectLayer != nullptr) {
        delete g_pNumberEffectLayer;
        g_pNumberEffectLayer = nullptr;
    }
}

/** @ghidraAddress 0x189c70 */
NumberEffectLayer::~NumberEffectLayer() {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    for (ne::C_SPRITE_INSTANCING_2D *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
}

/** @ghidraAddress 0x189d9c */
void NumberEffectLayer::CreateSpriteInstancers() {
    if (m_bBuilt) {
        return;
    }

    if (IsPad()) {
        m_aTransform[0] = kTransformPadX;
        m_aTransform[1] = kMirrorOffset;
        m_aTransform[2] = kTransformPadZ;
        m_aTransform[3] = kTransformPadW;
    } else {
        m_aTransform[0] = kMirrorOffset;
        m_aTransform[1] = 0.0f;
        m_aTransform[2] = kTransformPhoneZ;
        m_aTransform[3] = 0.0f;
    }

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
    // Yes, the binary discards this call's result.
    (void)BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    for (int i = 0; i < kBatchCount; ++i) {
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateSpriteInstancer(static_cast<unsigned int>(kBatchCapacity[i]));
        m_apSprites[i] = pSprite;
        pSprite->RegisterGlobal();
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
    }

    m_bWideScreen = GameSystem::GetGameSystem()->GetViewportWidth() > kWideScreenSplit;
}
