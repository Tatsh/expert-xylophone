//
//  number_effect_layer.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458.
//

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
// The gm_parts2 atlas the number glyphs draw from.
constexpr const char *kAtlasTextureName = "00_texture/gm_parts2";

// The device-dependent transform block the instancer builder seeds into @c m_aTransform. The phone
// (non-pad) uses a mirror offset and the pad width; the pad uses its own shipped offsets
// (@ghidraAddress 0x30fb00 = -103.0, 0x30fb08 = 206.0, 0x30fb0c = 96.0).
constexpr float kMirrorOffset = -6.0f;    // 0xc0c00000
constexpr float kTransformPadX = -103.0f; // @ghidraAddress 0x30fb00
constexpr float kTransformPadZ = 206.0f;  // @ghidraAddress 0x30fb08
constexpr float kTransformPhoneZ = 96.0f; // @ghidraAddress 0x30fb0c
constexpr float kTransformPadW = 7.0f;    // 0x40e00000

// The four instancer capacities (@ghidraAddress 0x30fb70): three of one, one of two.
constexpr int kBatchCapacity[] = {1, 1, 1, 2};

// The viewport width past which the wide-screen layout is used (@ghidraAddress 0x2f8558).
constexpr float kWideScreenSplit = 320.0f;

// The number of anchored elements and wide-layout variant rows.
constexpr int kAnchorElementCount = 4;
constexpr int kWideVariantCount = 2;

// The viewport-relative gravity applied to a base offset (from the anchor gravity tables). The
// offset moves the anchor to the named viewport edge or centre; the top-left case adds nothing (the
// base offset is already absolute).
enum AnchorGravity {
    kGravityBottomCentre = 0, // Offset by half the viewport width and the full height.
    kGravityTopCentre = 1,    // Offset by half the viewport width.
    kGravityTopLeft = 2,      // No offset (the base offset is absolute).
    kGravityTopRight = 3,     // Offset by the full viewport width.
    kGravityLeftCentre = 4,   // Offset by half the viewport height.
};

// The portrait-layout base offsets and per-element gravities (only the first two elements are set;
// the remainder are zero).
constexpr S_VECTOR2 kPortraitAnchor[kAnchorElementCount] = {
    {0.0f, -69.0f}, {132.0f, 63.0f}, {0.0f, 0.0f}, {0.0f, 0.0f}};
constexpr int kPortraitGravity[kAnchorElementCount] = {
    kGravityBottomCentre, kGravityTopLeft, kGravityTopLeft, kGravityTopCentre};

// The landscape-layout base offsets and per-element gravities, per wide-layout variant row.
constexpr S_VECTOR2 kLandscapeAnchor[kWideVariantCount][kAnchorElementCount] = {
    {{29.0f, -13.0f}, {-128.0f, -13.0f}, {0.0f, 31.0f}, {0.0f, 0.0f}},
    {{31.0f, -12.0f}, {-126.0f, -12.0f}, {73.0f, 12.0f}, {-73.0f, 12.0f}},
};
constexpr int kLandscapeGravity[kWideVariantCount][kAnchorElementCount] = {
    {kGravityBottomCentre, kGravityBottomCentre, kGravityTopCentre, kGravityTopCentre},
    {kGravityBottomCentre, kGravityBottomCentre, kGravityTopLeft, kGravityTopRight},
};
} // namespace

// The fully-opaque alpha the fade-in eases toward (a 0-to-255 alpha channel).
namespace {
constexpr float kOpaqueAlpha = 255.0f;

// One number-glyph element descriptor: its anchor, size, and index into the shared sprite-UV table.
struct NumberElementDescriptor {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    int nUvIndex;
};

// The number-glyph element descriptors for the landscape and portrait layouts (@ghidraAddress
// 0x30fbd0 landscape, 0x30fb80 portrait).
constexpr NumberElementDescriptor kLandscapeElements[] = {
    {124.0f, 10.0f, 248.0f, 20.0f, 0x175},
    {2.0f, 6.0f, 4.0f, 12.0f, 0x176},
    {25.0f, 10.0f, 50.0f, 20.0f, 0x177},
    {70.0f, 9.0f, 140.0f, 18.0f, 0x178},
};
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
    // A non-positive duration snaps straight to opaque and marks the fade done.
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
    // A non-positive duration snaps straight to transparent and marks the fade done.
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
    // The iPad uses the portrait table; the phone uses the wide-variant landscape row.
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

    // The portrait (pad) layout uses its own element table; the phone uses the landscape table.
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
// The two brightness-slider touch targets: the track and the draggable knob.
constexpr int kSliderTargetTrack = 0;
constexpr int kSliderTargetKnob = 1;

// The slider hit-rectangle geometry, in atlas pixels. Each target's left inset and width vary by
// device (the iPad rectangles are wider); the top inset and height are shared. @ghidraAddress
// 0x2fedf8/0x30fb04/0x30fb10/0x30fb18 and the shared -25/50 constants.
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

// The themed sound effect played when a knob drag leaves the knob and cancels the adjustment.
constexpr int kSliderCancelSoundEffect = 3;

// A touch point lies inside a slider rectangle when it is within both spans (inclusive).
inline bool
IsInsideSliderRect(float flX, float flY, float flLeft, float flTop, float flWidth, float flHeight) {
    return flLeft <= flX && flX <= flLeft + flWidth && flTop <= flY && flY <= flTop + flHeight;
}
} // namespace

/** @ghidraAddress 0x189f40 */
void NumberEffectLayer::ProcessBrightnessSliderTouch() {
    TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();

    // The track target is processed first, then the knob.
    for (int nTarget = kSliderTargetTrack; nTarget <= kSliderTargetKnob; ++nTarget) {
        // Resolve the target's hit rectangle from its element anchor and the device-dependent
        // insets and width.
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
            // Unclaimed: scan the freshly-pressed touches for one that lands inside the rectangle.
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

        // Claimed: track the touch.
        TouchPoint *pTouch = pTouchManager->FindTouchById(nTouchId);
        if (pTouch == nullptr) {
            nTouchId = -1;
            if (nTarget == kSliderTargetKnob) {
                m_bSliderHeld = false;
            }
            continue;
        }

        if (nTarget == kSliderTargetKnob) {
            // The knob stays held while the touch presses inside it. A touch that leaves the knob
            // is simply not held; a touch released inside the knob cancels the adjustment, plays
            // the cancel sound, clears the knob, and returns the play scene to its state.
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
            // The track maps the touch's X to a normalised brightness (clamped to the unit
            // interval), stores it, pushes it into the user settings and background layer, and
            // saves.
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
    // The slider layout tracks the elements to specific batches and descriptors.
    constexpr unsigned int kTrackBatch = 3;
    constexpr unsigned int kKnobBatch = 2;
    constexpr unsigned int kFillBatch = 0;
    constexpr unsigned int kFillMarkerBatch = 1;
    constexpr unsigned int kTrackElement = 2;
    constexpr unsigned int kTrackWideElement = 3;
    constexpr unsigned int kKnobElement = 1;
    // The knob's glyph row, which is not its anchor element (the immediate 2 at 0x18a5bc).
    constexpr unsigned int kKnobDescriptor = 2;
    constexpr unsigned int kFillElement = 0;
    constexpr unsigned int kOpaque = 0xff;
    constexpr unsigned int kHeldAlpha = 0x80;
    constexpr unsigned int kWhite = 0xff;

    // Re-anchor and refresh the wide-screen flag when the viewport size changes.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flWidth = pGameSystem->GetViewportWidth();
    const float flHeight = pGameSystem->GetViewportHeight();
    if (m_flCachedViewportWidth != flWidth || m_flCachedViewportHeight != flHeight) {
        m_flCachedViewportWidth = flWidth;
        m_flCachedViewportHeight = flHeight;
        m_bWideScreen = GameSystem::GetGameSystem()->GetViewportWidth() > kWideScreenSplit;
    }

    AdvanceFadeInterp(flDeltaTime);

    // Reset every batch's live sprite count for the frame.
    for (auto *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }

    ProcessBrightnessSliderTouch();

    S_VECTOR2 pos{};
    // The landscape layout draws the slider track (element 2) plus its wide-variant extension.
    if (!IsPad()) {
        ComputeAnchorPos(kTrackElement, &pos);
        EmitNumberSprite(pos.x, pos.y, kTrackBatch, kTrackWideElement, kWhite);
        if (m_bWideScreen) {
            ComputeAnchorPos(kTrackWideElement, &pos);
            EmitNumberSprite(pos.x, pos.y, kTrackBatch, kTrackWideElement, kWhite);
        }
    }

    // The knob (element 1) draws at half alpha while the slider is held.
    ComputeAnchorPos(kKnobElement, &pos);
    // The knob's anchor is element 1 but its glyph is descriptor 2 (the immediate at 0x18a5bc).
    EmitNumberSprite(
        pos.x, pos.y, kKnobBatch, kKnobDescriptor, m_bSliderHeld ? kHeldAlpha : kOpaque);

    // The brightness fill (element 0) plus a marker sprite offset along the track vector by the
    // current brightness.
    ComputeAnchorPos(kFillElement, &pos);
    EmitNumberSprite(pos.x, pos.y, kFillBatch, kFillElement, kWhite);
    EmitNumberSprite(pos.x + m_aTransform[0] + m_flBrightness * m_aTransform[2],
                     pos.y + m_aTransform[1],
                     kFillMarkerBatch,
                     kKnobElement,
                     kWhite);
}

// The process-wide number-effect layer, created lazily by shared().
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
    // Each live instancer is flagged for deletion by the scene tree and detached from the layer.
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

    // Seed the device-dependent transform block: the phone mirrors, the pad uses its own offsets.
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
    // The binary fetches the background layer and its render object here but discards both; the
    // instancers register directly into the global scene tree instead.
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

    // The wide-screen layout is used once the viewport is wider than the split threshold.
    m_bWideScreen = GameSystem::GetGameSystem()->GetViewportWidth() > kWideScreenSplit;
}
