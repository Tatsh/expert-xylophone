#include "thema_marker_layer.h"

#include <algorithm>
#include <cmath>

#import "RBUserSettingData.h"
#include "bg_layer.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "s_vector2.h"

static ThemaMarkerLayer *g_pThemaMarkerLayer = nullptr; // @ghidraAddress 0x3deed0

namespace {

// @ghidraAddress 0x3ceaa0
constexpr const char *kTextureName = "00_texture/gm_parts1";

// @ghidraAddress 0x30de28
constexpr int kMarkerBatch[] = {0, 0, 1, 1, 1, 1};

// @ghidraAddress 0x30de40
constexpr int kMarkerSpriteCount[] = {1, 1, 1, 1, 4, 4};

// @ghidraAddress 0x30de58
struct MarkerLayout {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    int nUvIndex;
};
constexpr MarkerLayout kMarkerLayout[] = {
    {318.0f, 10.0f, 636.0f, 20.0f, 95},
    {318.0f, 10.0f, 636.0f, 20.0f, 96},
    {318.0f, 34.0f, 636.0f, 68.0f, 97},
    {318.0f, 34.0f, 636.0f, 68.0f, 98},
    {248.0f, 34.0f, 496.0f, 124.0f, 99},
    {248.0f, 34.0f, 496.0f, 124.0f, 100},
};

// @ghidraAddress 0x2ef668
struct UvEntry {
    int nIndex;
    float flOriginU;
    float flOriginV;
    float flSizeU;
    float flSizeV;
};
constexpr UvEntry kUvTable[] = {
    {95, 0.51074f, 0.1582f, 0.00098f, 0.01953f},
    {96, 0.5166f, 0.1582f, 0.00098f, 0.01953f},
    {97, 0.51074f, 0.08984f, 0.00098f, 0.06641f},
    {98, 0.5166f, 0.08984f, 0.00098f, 0.06641f},
    {99, 0.00195f, 0.87695f, 0.48438f, 0.12109f},
    {100, 0.48828f, 0.87695f, 0.48438f, 0.12109f},
};

constexpr int kClassicMarkerCount = 6;
constexpr int kOtherMarkerCount = 4;
constexpr int kClassicThema = 0;

constexpr int k3dBatch = 1;

// Groups 0, 2, and 4 are the ones mirrored by the play side.
constexpr unsigned int kSideMirroredGroupMask = 0x15;
constexpr int kTallBandFirstGroup = 4;
constexpr int kMidBandFirstGroup = 2;
constexpr int kBandGroupSpan = 2;
constexpr int kMirrorSlotCount = 2;

const UvEntry &LookupUv(int nUvIndex) {
    for (const UvEntry &entry : kUvTable) {
        if (entry.nIndex == nUvIndex) {
            return entry;
        }
    }
    return kUvTable[0];
}

constexpr float kDangerBrightnessRange = 0.7f;
constexpr float kDangerBrightnessBase = 0.3f;

} // namespace

/** @ghidraAddress 0x17fc00 */
ThemaMarkerLayer::ThemaMarkerLayer() {
    m_flScaleX = 1.0f;
    m_flScaleY = 1.0f;
    m_flDangerBrightness = 1.0f;

    for (float &flTransform : m_aTransform) {
        flTransform = 1.0f;
    }

    for (int nMarker = 0; nMarker < kMarkerLayoutCount; ++nMarker) {
        const int nBatch = kMarkerBatch[nMarker];
        m_aMarkerBaseIndex[nMarker] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kMarkerSpriteCount[nMarker];
    }
}

/** @ghidraAddress 0x17fccc */
ThemaMarkerLayer *ThemaMarkerLayer::shared() {
    if (g_pThemaMarkerLayer == nullptr) {
        g_pThemaMarkerLayer = new ThemaMarkerLayer();
    }
    return g_pThemaMarkerLayer;
}

/** @ghidraAddress 0x17ff50 */
void ThemaMarkerLayer::LoadThemaMarkerSprites() {
    if (m_bBuilt) {
        return;
    }

    const int nThema = [RBUserSettingData.sharedInstance thema];
    m_nMarkerCount = nThema == kClassicThema ? kClassicMarkerCount : kOtherMarkerCount;

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_aBatchCapacity[nBatch]));
        m_apSprites[nBatch] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(m_aBatchCapacity[nBatch]);
        if (nBatch == k3dBatch) {
            pSprite->SetBlendMode(1);
            break;
        }
    }

    for (int nMarker = 0; nMarker < m_nMarkerCount; ++nMarker) {
        const MarkerLayout &layout = kMarkerLayout[nMarker];
        const UvEntry &uv = LookupUv(layout.nUvIndex);
        ne::C_SPRITE_INSTANCING_2D *pSprite = m_apSprites[kMarkerBatch[nMarker]];
        const int nBaseIndex = m_aMarkerBaseIndex[nMarker];
        for (int nSprite = 0; nSprite < kMarkerSpriteCount[nMarker]; ++nSprite) {
            const int nIndex = nBaseIndex + nSprite;
            pSprite->SetSpritePosition(nIndex, S_VECTOR2{0.0f, 0.0f});
            pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
            pSprite->SetSpriteSize(nIndex, S_VECTOR2{layout.flSizeW, layout.flSizeH});
            pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
            pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
            pSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, 0);
        }
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x17fd1c */
void ThemaMarkerLayer::SetupMarkers() {
    RefreshThema();

    const int nThema = [RBUserSettingData.sharedInstance thema];
    m_nMarkerCount = nThema == kClassicThema ? kClassicMarkerCount : kOtherMarkerCount;

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->SetRefCountedMember(m_pTexture);
        }
    }

    for (int nMarker = 0; nMarker < m_nMarkerCount; ++nMarker) {
        const MarkerLayout &layout = kMarkerLayout[nMarker];
        const UvEntry &uv = LookupUv(layout.nUvIndex);
        ne::C_SPRITE_INSTANCING_2D *pSprite = m_apSprites[kMarkerBatch[nMarker]];
        const int nBaseIndex = m_aMarkerBaseIndex[nMarker];
        for (int nSprite = 0; nSprite < kMarkerSpriteCount[nMarker]; ++nSprite) {
            if (pSprite == nullptr) {
                continue;
            }
            const int nIndex = nBaseIndex + nSprite;
            pSprite->SetSpritePosition(nIndex, S_VECTOR2{0.0f, 0.0f});
            pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
            pSprite->SetSpriteSize(nIndex, S_VECTOR2{layout.flSizeW, layout.flSizeH});
            pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
            pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
            pSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, 0);
        }
    }
}

/** @ghidraAddress 0x180438 */
void ThemaMarkerLayer::StartFadeOut(float flDuration) {
    m_flActiveMarker = 0.0f;
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(0.0f);
        m_bFadeColorDirty = true;
    }
}

/** @ghidraAddress 0x180400 */
void ThemaMarkerLayer::StartFadeIn(float flDuration, float flMarker) {
    m_flActiveMarker = flMarker;
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(1.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(1.0f);
        m_bFadeColorDirty = true;
    }
    m_flDangerTimer = 0.0f;
}

/** @ghidraAddress 0x180464 */
void ThemaMarkerLayer::SetDangerLevel(float flLevel) {
    const float flClamped = flLevel < 0.0f ? 0.0f : (flLevel > 1.0f ? 1.0f : flLevel);
    m_flDangerBrightness = flClamped * kDangerBrightnessRange + kDangerBrightnessBase;
    m_bFadeColorDirty = true;
}

/** @ghidraAddress 0x1801d4 */
void ThemaMarkerLayer::RenderThemaMarkerFrame() {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const int nPlaySide = pGameSystem->GetPlayColor();

    const float flInsetHalfY = pGameSystem->GetSheetInsetHalfY();
    const float aMirroredY[kMirrorSlotCount] = {g_flPlayfieldNearLaneSlope * flInsetHalfY,
                                                g_flPlayfieldNearLaneSlopeNeg * flInsetHalfY};

    const float flWidth = pGameSystem->GetSheetPosX();
    const float flRadius = pGameSystem->GetSheetRadius();

    for (int nGroup = 0; nGroup < m_nMarkerCount; ++nGroup) {
        const int nBaseIndex = m_aMarkerBaseIndex[nGroup];
        ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[kMarkerBatch[nGroup]];

        float flY = 0.0f;
        if (nGroup < static_cast<int>(kMarkerLayoutCount)) {
            const bool bSideMirrored = ((1u << nGroup) & kSideMirroredGroupMask) != 0;
            const int nSel = bSideMirrored ? (nPlaySide == 0 ? 1 : 0) : (nPlaySide == 1 ? 1 : 0);
            flY = aMirroredY[nSel];
        }

        for (int nSprite = 0; nSprite < kMarkerSpriteCount[nGroup]; ++nSprite) {
            const int nIndex = nBaseIndex + nSprite;
            pBatch->SetSpritePositionY(nIndex, flY);
            if (nGroup - kTallBandFirstGroup < kBandGroupSpan &&
                nGroup - kTallBandFirstGroup >= 0) {
                pBatch->SetSpriteSize(nIndex, S_VECTOR2{flWidth, flRadius + flRadius});
                pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{flWidth * 0.5f, flRadius});
            } else if (nGroup - kMidBandFirstGroup < kBandGroupSpan &&
                       nGroup - kMidBandFirstGroup >= 0) {
                pBatch->SetSpriteSize(nIndex, S_VECTOR2{flWidth, flRadius});
                pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{flWidth * 0.5f, flRadius * 0.5f});
            }
        }
    }
}

namespace {
// @ghidraAddress 0x308dd8, 0x30dde8, 0x30ddec, 0x30ddf0, 0x3041a8
constexpr float kDangerRampStart = 450.0f;
constexpr float kDangerRampOffset = -450.0f;
constexpr float kDangerRampDivisor = 130.0f;
constexpr float kDangerRampCapTop = 550.0f;
constexpr float kDangerRampCapBand = 580.0f;

constexpr int kDangerBandFirstGroup = 2;
constexpr int kDangerBandGroupSpan = 2;
constexpr int kDangerTopGroupCount = 2;

// @ghidraAddress 0x30ddf8, 0x30de20, 0x2f85a0
constexpr float kWobbleTimerCap = 6000.0f;
// @ghidraAddress 0x30ddf4
constexpr float kWobbleTimerWrap = -6000.0f;
constexpr double kWobblePhaseOffset = -0.075;
const double kWobblePi = M_PI;
constexpr float kWobbleAmplitudeA = 22.0f;
constexpr float kWobbleAmplitudeB = 27.0f;
constexpr float kWobbleHalfScale = 0.5f;

constexpr int kWobbleGroupBase = 4;

// @ghidraAddress 0x30de00 -> 0x3deee0
constexpr float kWobbleBaseX[] = {206.0f, -205.0f, -90.0f, 101.0f};

constexpr float kWobbleScaleY0 = 0.5f;
} // namespace

/** @ghidraAddress 0x18066c */
void ThemaMarkerLayer::AnimateEffects(float flDelta) {
    if (m_flDangerTimer < kDangerRampCapBand) {
        m_flDangerTimer = std::min(m_flDangerTimer + flDelta, kDangerRampCapBand);
        for (int nGroup = 0; nGroup < m_nMarkerCount; ++nGroup) {
            if (nGroup - kDangerBandFirstGroup >= 0 &&
                nGroup - kDangerBandFirstGroup < kDangerBandGroupSpan) {
                float flRamp;
                if (m_flDangerTimer < kDangerRampStart) {
                    flRamp = 0.0f;
                } else if (m_flDangerTimer >= kDangerRampCapBand) {
                    flRamp = 1.0f;
                } else {
                    flRamp = (m_flDangerTimer + kDangerRampOffset) / kDangerRampDivisor;
                }
                if (m_aTransform[nGroup] != flRamp) {
                    m_bFadeColorDirty = true;
                }
                m_aTransform[nGroup] = flRamp;
            } else if (nGroup < kDangerTopGroupCount) {
                ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[kMarkerBatch[nGroup]];
                const int nBaseIndex = m_aMarkerBaseIndex[nGroup];
                for (int nSprite = 0; nSprite < kMarkerSpriteCount[nGroup]; ++nSprite) {
                    float flRamp;
                    if (m_flDangerTimer < kDangerRampStart) {
                        flRamp = 0.0f;
                    } else if (m_flDangerTimer >= kDangerRampCapTop) {
                        flRamp = 1.0f;
                    } else {
                        flRamp = (m_flDangerTimer + kDangerRampOffset) / kDangerRampDivisor;
                    }
                    pBatch->SetSpriteScale(nBaseIndex + nSprite, 1.0f, flRamp);
                }
            }
        }
    }

    // The binary wraps the timer rather than clamping it, so the sweep loops instead of sticking.
    const float flWobbleAdvanced = m_flWobbleTimer + flDelta;
    m_flWobbleTimer =
        flWobbleAdvanced > kWobbleTimerCap ? flWobbleAdvanced + kWobbleTimerWrap : flWobbleAdvanced;
    const float flPhase = std::max(0.0f, std::min(m_flWobbleTimer / kWobbleTimerCap, 1.0f));
    const float flCosOffset = static_cast<float>(
        std::cos((static_cast<double>(flPhase) + kWobblePhaseOffset) * 2.0 * kWobblePi));
    const float flCosPlain =
        static_cast<float>(std::cos(static_cast<double>(flPhase) * 2.0 * kWobblePi));
    const float flOffsetA = flCosPlain * kWobbleAmplitudeA;
    const float flOffsetB = flCosPlain * kWobbleAmplitudeB;

    for (int nGroup = 0; nGroup < m_nMarkerCount; ++nGroup) {
        if ((nGroup & ~1) != kWobbleGroupBase) {
            continue;
        }
        ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[kMarkerBatch[nGroup]];
        const int nBaseIndex = m_aMarkerBaseIndex[nGroup];
        for (int nSprite = 0; nSprite < kMarkerSpriteCount[nGroup]; ++nSprite) {
            const int nIndex = nBaseIndex + nSprite;
            switch (nSprite) {
            case 0:
                pBatch->SetSpritePositionX(nIndex, kWobbleBaseX[0] - flOffsetA);
                pBatch->SetSpriteScale(nIndex, 1.0f, kWobbleScaleY0);
                break;
            case 1:
                pBatch->SetSpritePositionX(nIndex, kWobbleBaseX[1] + flOffsetA);
                pBatch->SetSpriteScale(nIndex, -1.0f, -1.0f);
                break;
            case 2:
                pBatch->SetSpritePositionX(nIndex, kWobbleBaseX[2] - flOffsetB);
                pBatch->SetSpriteScale(nIndex, 1.0f, flCosOffset);
                break;
            case 3:
                pBatch->SetSpritePositionX(nIndex, kWobbleBaseX[3] + flOffsetB);
                pBatch->SetSpriteScale(nIndex, -1.0f, -flCosPlain);
                break;
            default:
                break;
            }
        }
    }
}

namespace {
// @ghidraAddress 0x2eed00, 0x2f856c
constexpr float kMarkerAlphaScale = 255.0f;
constexpr float kBandDimFactor = 0.8f;
} // namespace

/** @ghidraAddress 0x1804a4 */
void ThemaMarkerLayer::RefreshMarkerAlpha(float flDelta) {
    const float flTarget = m_fadeChannel.GetDuration() + m_flActiveMarker;
    if (flTarget > m_fadeChannel.GetElapsed()) {
        const float flElapsed = std::min(m_fadeChannel.GetElapsed() + flDelta, flTarget);
        m_fadeChannel.SetElapsed(flElapsed);
        float flProgress = m_fadeChannel.GetDuration() == 0.0f ?
                               1.0f :
                               (flElapsed - m_flActiveMarker) / m_fadeChannel.GetDuration();
        flProgress = std::max(flProgress, 0.0f);
        m_fadeChannel.SetCurrent(m_fadeChannel.GetStart() +
                                 flProgress * (m_fadeChannel.GetEnd() - m_fadeChannel.GetStart()));
        m_bFadeColorDirty = true;
    }

    AnimateEffects(flDelta);

    if (!m_bFadeColorDirty) {
        return;
    }
    m_bFadeColorDirty = false;

    for (int nGroup = 0; nGroup < m_nMarkerCount; ++nGroup) {
        ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[kMarkerBatch[nGroup]];
        const int nBaseIndex = m_aMarkerBaseIndex[nGroup];
        for (int nSprite = 0; nSprite < kMarkerSpriteCount[nGroup]; ++nSprite) {
            const float flBase =
                m_fadeChannel.GetCurrent() * m_aTransform[nGroup] * kMarkerAlphaScale;
            float flAlpha;
            switch (nGroup) {
            case 0:
                flAlpha = flBase * m_flScaleY;
                break;
            case 1:
                flAlpha = flBase * m_flScaleX;
                break;
            case 2:
                flAlpha = flBase * m_flDangerBrightness * m_flScaleY * kBandDimFactor;
                break;
            case 3:
                flAlpha = flBase * m_flDangerBrightness * m_flScaleX * kBandDimFactor;
                break;
            default:
                flAlpha = m_fadeChannel.GetCurrent() * kMarkerAlphaScale * m_flScaleY;
                break;
            }
            pBatch->SetColorAlpha(nBaseIndex + nSprite,
                                  static_cast<unsigned char>(static_cast<int>(flAlpha)));
        }
    }
}
