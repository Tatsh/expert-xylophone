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

// The process-wide theme-marker layer, created lazily by shared().
static ThemaMarkerLayer *g_pThemaMarkerLayer = nullptr; // @ghidraAddress 0x3deed0

namespace {

// The atlas the markers draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// Which of the two batches each marker group draws into (@ghidraAddress 0x30de28).
constexpr int kMarkerBatch[] = {0, 0, 1, 1, 1, 1};

// How many sprites each marker group emits (@ghidraAddress 0x30de40).
constexpr int kMarkerSpriteCount[] = {1, 1, 1, 1, 4, 4};

// Per-marker layout (@ghidraAddress 0x30de58): the anchor (half the size), the size, and the index
// into the UV table below.
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

// The UV table (@ghidraAddress 0x2ef668, entry = base + nUvIndex * 0x10): the UV origin and UV size
// mapped to each marker. Only the six entries the markers use (indices 95 through 100) are listed,
// keyed by their table index.
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

// The marker count for the Classic theme versus the others.
constexpr int kClassicMarkerCount = 6;
constexpr int kOtherMarkerCount = 4;
constexpr int kClassicThema = 0;

// The batch that draws in 3D (its vertex flag is set), and the additive-style vertex flag value.
constexpr int k3dBatch = 1;

// The bitmask of marker groups (0, 2, and 4) whose Y is mirrored by the play side; the others take
// the opposite mirror selector.
constexpr unsigned int kSideMirroredGroupMask = 0x15;
// The first marker group of the tall band (groups 4 and 5, double-height) and of the mid band
// (groups 2 and 3, single-height); groups 0 and 1 set only the Y position.
constexpr int kTallBandFirstGroup = 4;
constexpr int kMidBandFirstGroup = 2;
constexpr int kBandGroupSpan = 2;
// The two mirrored Y positions, indexed by the side selector.
constexpr int kMirrorSlotCount = 2;

const UvEntry &LookupUv(int nUvIndex) {
    for (const UvEntry &entry : kUvTable) {
        if (entry.nIndex == nUvIndex) {
            return entry;
        }
    }
    return kUvTable[0];
}

// The danger/warning brightness maps a normalised level onto [kDangerBrightnessBase,
// kDangerBrightnessBase + kDangerBrightnessRange] = [0.3, 1.0].
constexpr float kDangerBrightnessRange = 0.7f;
constexpr float kDangerBrightnessBase = 0.3f;

} // namespace

/** @ghidraAddress 0x17fc00 */
ThemaMarkerLayer::ThemaMarkerLayer() {
    m_flScaleX = 1.0f;
    m_flScaleY = 1.0f;
    m_flDangerBrightness = 1.0f;

    // Assign each marker group a non-overlapping index range within its batch, accumulating each
    // batch's total sprite capacity as it goes.
    for (int nMarker = 0; nMarker < kMarkerLayoutCount; ++nMarker) {
        const int nBatch = kMarkerBatch[nMarker];
        m_aMarkerBaseIndex[nMarker] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kMarkerSpriteCount[nMarker];
    }
}

/** @ghidraAddress 0x17fccc */
ThemaMarkerLayer *ThemaMarkerLayer::shared() {
    if (g_pThemaMarkerLayer == nullptr) {
        // The binary allocates the raw 0x98-byte object and runs the constructor.
        g_pThemaMarkerLayer = new ThemaMarkerLayer();
    }
    return g_pThemaMarkerLayer;
}

/** @ghidraAddress 0x17ff50 */
void ThemaMarkerLayer::LoadThemaMarkerSprites() {
    if (m_bBuilt) {
        return;
    }

    // The Classic theme shows six marker groups; the others show four.
    const int nThema = [RBUserSettingData.sharedInstance thema];
    m_nMarkerCount = nThema == kClassicThema ? kClassicMarkerCount : kOtherMarkerCount;

    // The markers hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build the two sprite batches, each sized to hold all the marker groups routed to it; mark the
    // 3D batch's vertex flag.
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

    // Emit each marker group's sprites into its batch: the anchor and size come from the layout
    // table, the UV origin and size from the UV table, all at white with zero alpha.
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

    // The Classic theme shows six marker groups; the others show four.
    const int nThema = [RBUserSettingData.sharedInstance thema];
    m_nMarkerCount = nThema == kClassicThema ? kClassicMarkerCount : kOtherMarkerCount;

    // Reload the atlas and re-bind it to both existing batches.
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->SetRefCountedMember(m_pTexture);
        }
    }

    // Re-emit each marker group's sprites: the anchor and size from the layout table, the UV origin
    // and size from the UV table, all white with zero alpha and a zero position.
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
    // A non-positive duration snaps straight to transparent and marks the colour dirty.
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
    // A non-positive duration snaps straight to opaque and marks the colour dirty.
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

    // The two mirrored Y positions: the near-lane slope (and its negative) scaled by the sheet-inset
    // half-height.
    const float flInsetHalfY = pGameSystem->GetSheetInsetHalfY();
    const float aMirroredY[kMirrorSlotCount] = {g_flPlayfieldNearLaneSlope * flInsetHalfY,
                                                g_flPlayfieldNearLaneSlopeNeg * flInsetHalfY};

    const float flWidth = pGameSystem->GetSheetPosX();
    const float flRadius = pGameSystem->GetSheetRadius();

    for (int nGroup = 0; nGroup < m_nMarkerCount; ++nGroup) {
        const int nBaseIndex = m_aMarkerBaseIndex[nGroup];
        ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[kMarkerBatch[nGroup]];

        // Groups 0, 2, and 4 mirror by the play side; the others take the opposite selector.
        float flY = 0.0f;
        if (nGroup < static_cast<int>(kMarkerLayoutCount)) {
            const bool bSideMirrored = ((1u << nGroup) & kSideMirroredGroupMask) != 0;
            const int nSel = bSideMirrored ? (nPlaySide == 0 ? 1 : 0) : (nPlaySide == 1 ? 1 : 0);
            flY = aMirroredY[nSel];
        }

        for (int nSprite = 0; nSprite < kMarkerSpriteCount[nGroup]; ++nSprite) {
            const int nIndex = nBaseIndex + nSprite;
            pBatch->SetSpritePositionY(nIndex, flY);
            // The tall band (groups 4, 5) is double-height with a bottom-centred anchor; the mid band
            // (groups 2, 3) is single-height with a centred anchor; the top band (groups 0, 1) keeps
            // its built size.
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
// The low-gauge danger fade-in ramp: it begins at 450 units and rises with a 130-unit slope,
// capping at 550 for the top marker groups (0, 1) and at 580 for the band groups (2, 3).
// @ghidraAddress 0x308dd8, 0x30dde8, 0x30ddec, 0x30ddf0, 0x3041a8
constexpr float kDangerRampStart = 450.0f;
constexpr float kDangerRampOffset = -450.0f;
constexpr float kDangerRampDivisor = 130.0f;
constexpr float kDangerRampCapTop = 550.0f;
constexpr float kDangerRampCapBand = 580.0f;

// The band groups (2, 3) whose per-group alpha scale the ramp drives, versus the top groups (0, 1)
// whose per-slot vertical scale it drives.
constexpr int kDangerBandFirstGroup = 2;
constexpr int kDangerBandGroupSpan = 2;
constexpr int kDangerTopGroupCount = 2;

// The wobble timer's cap (@ghidraAddress 0x30ddf8), its cosine phase offset (@ghidraAddress
// 0x30de20 = -0.075) and scale (@ghidraAddress 0x2f85a0 = 2*PI folds in as the doubled phase), plus
// the two X-offset amplitudes (22 and 27 pixels) and the half vertical scale.
constexpr float kWobbleTimerCap = 6000.0f;
constexpr double kWobblePhaseOffset = -0.075;
const double kWobblePi = M_PI;
constexpr float kWobbleAmplitudeA = 22.0f;
constexpr float kWobbleAmplitudeB = 27.0f;
constexpr float kWobbleHalfScale = 0.5f;

// The marker groups the wobble animates: 4 and 5 (i.e. group & ~1 == 4).
constexpr int kWobbleGroupBase = 4;

// The wobble base X positions of the four slots, cached once at load from a table
// (@ghidraAddress 0x30de00 -> 0x3deee0).
constexpr float kWobbleBaseX[] = {206.0f, -205.0f, -90.0f, 101.0f};

// The per-slot vertical scales the wobble writes (slots 0 and 1 are fixed; slots 2 and 3 take the
// paired cosine).
constexpr float kWobbleScaleY0 = 0.5f;
} // namespace

/** @ghidraAddress 0x18066c */
void ThemaMarkerLayer::AnimateEffects(float flDelta) {
    // The danger ramp advances its timer toward the band cap, then ramps each marker group's alpha.
    if (m_flDangerTimer < kDangerRampCapBand) {
        m_flDangerTimer = std::min(m_flDangerTimer + flDelta, kDangerRampCapBand);
        for (int nGroup = 0; nGroup < m_nMarkerCount; ++nGroup) {
            if (nGroup - kDangerBandFirstGroup >= 0 &&
                nGroup - kDangerBandFirstGroup < kDangerBandGroupSpan) {
                // Band groups store the ramp in their per-group alpha scale (capping at 580).
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
                // Top groups ramp each slot's vertical scale directly (capping at 550).
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

    // The wobble advances its own timer, then sweeps groups 4 and 5's four slots on cosine curves.
    m_flWobbleTimer = std::min(m_flWobbleTimer + flDelta, kWobbleTimerCap);
    const float flPhase = std::max(0.0f, std::min(m_flWobbleTimer / kWobbleTimerCap, 1.0f));
    // The paired-slot phase (doubled) with and without the -0.075 offset.
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
                pBatch->SetSpriteScale(nIndex, -1.0f, -flCosOffset);
                break;
            default:
                break;
            }
        }
    }
}

namespace {
// The full-alpha byte the per-slot modulation scales (@ghidraAddress 0x2eed00), and the extra dim
// factor the band groups (2, 3) apply (@ghidraAddress 0x2f856c = 0.8).
constexpr float kMarkerAlphaScale = 255.0f;
constexpr float kBandDimFactor = 0.8f;
} // namespace

/** @ghidraAddress 0x1804a4 */
void ThemaMarkerLayer::RefreshMarkerAlpha(float flDelta) {
    // Advance the fade tween: it eases from its start to its end over its duration, but its elapsed
    // baseline is offset by the active-marker value.
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

    // Recompute every marker slot's alpha from the fade value, its per-group scale, and a
    // group-specific modulation.
    for (int nGroup = 0; nGroup < m_nMarkerCount; ++nGroup) {
        ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[kMarkerBatch[nGroup]];
        const int nBaseIndex = m_aMarkerBaseIndex[nGroup];
        for (int nSprite = 0; nSprite < kMarkerSpriteCount[nGroup]; ++nSprite) {
            const float flBase =
                m_fadeChannel.GetCurrent() * m_aTransform[nGroup] * kMarkerAlphaScale;
            float flAlpha;
            switch (nGroup) {
            case 0:
                flAlpha = flBase * m_flScaleX;
                break;
            case 1:
                flAlpha = flBase * m_flScaleY;
                break;
            case 2:
                flAlpha = flBase * m_flDangerBrightness * m_flScaleX * kBandDimFactor;
                break;
            case 3:
                flAlpha = flBase * m_flDangerBrightness * m_flScaleY * kBandDimFactor;
                break;
            default:
                // Groups 4 and 5 use the fade value times the X scale, ignoring the per-group scale.
                flAlpha = m_fadeChannel.GetCurrent() * kMarkerAlphaScale * m_flScaleX;
                break;
            }
            pBatch->SetColorAlpha(nBaseIndex + nSprite,
                                  static_cast<unsigned char>(static_cast<int>(flAlpha)));
        }
    }
}
