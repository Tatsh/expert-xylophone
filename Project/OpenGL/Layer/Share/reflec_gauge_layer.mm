#include "reflec_gauge_layer.h"

#include <algorithm>
#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "sprite_uv_table.h"

// The process-wide Reflec gauge layer, created lazily by shared().
static ReflecGaugeLayer *g_pReflecGaugeLayer = nullptr; // @ghidraAddress 0x3df2c8

namespace {

// The atlas the gauge/combo sprites draw from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// Which batch each part group's capacity accumulates into (@ghidraAddress 0x30fc58).
constexpr int kGroupBatch[] = {0, 1, 2, 1, 2, 3};

// How many sprites each part group contributes to its batch (@ghidraAddress 0x30fc70).
constexpr int kGroupPartCount[] = {2, 5, 5, 5, 5, 2};

// The batch that receives the vertex flag, and that flag value.
constexpr int kVertexFlagBatch = 2;
constexpr int kVertexFlagMode = 1;

// The gauge value is quantised to steps of one hundredth (@ghidraAddress 0x2ec6b0) and clamped to
// the range zero through five.
constexpr float kGaugeQuantizeScale = 100.0f;
constexpr float kGaugeMax = 5.0f;

// The gauge value each side is seeded to in the full-just-reflec challenge mode.
constexpr float kGaugeChallengeValue = 5.0f;

// The affine map applied to the display brightness: value in [0, 1] maps to [kBrightnessBias,
// kBrightnessBias + kBrightnessScale] = [0.3, 1.0] (@ghidraAddress 0x2fd008 and 0x2ee910).
constexpr float kBrightnessScale = 0.7f;
constexpr float kBrightnessBias = 0.3f;

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

// The batch the gauge value/digit sprites are emitted into.
constexpr unsigned int kValueBatch = 1;

// The batch the gauge label sprites are emitted into.
constexpr unsigned int kLabelBatch = 2;

// The batch the gauge icon sprites are emitted into.
constexpr unsigned int kIconBatch = 3;

// The base gauge quad's fixed screen X in each orientation/mode (@ghidraAddress 0x30fcb0 anchor for
// portrait 190.0; the landscape modes use 200.0 and 0.0), and the field half-span subtracted from
// each band Y (0x200 layout units).
constexpr float kPortraitGaugeX = 190.0f;
constexpr float kLandscapeGaugeX = 200.0f;
constexpr float kLandscapeAltGaugeX = 0.0f;
constexpr int kFieldHalfSpan = 0x200;
// The portrait band Y bases (@ghidraAddress 0x30fcb0 region), before the layout-table centre split.
constexpr int kPortraitBandBaseTop = 0x1d6;
constexpr int kPortraitBandBaseBottom = 0x22a;

// The gauge base/frame sprite descriptors, selected by orientation and gauge mode
// (@ghidraAddress 0x30fc88 default, 0x30fc9c alternate, 0x30fcb0 portrait).
constexpr ReflecGaugeLayer::GaugeSpriteDescriptor kBaseSpriteDefault = {
    {80.0f, 20.0f}, {160.0f, 40.0f}, 0x88};
constexpr ReflecGaugeLayer::GaugeSpriteDescriptor kBaseSpriteAlt = {
    {178.0f, 19.0f}, {356.0f, 37.0f}, 0x83};
constexpr ReflecGaugeLayer::GaugeSpriteDescriptor kBaseSpritePortrait = {
    {84.0f, 20.0f}, {168.0f, 40.0f}, 0x113};

// The per-colour-side gauge label descriptor: its anchor Y, size, and atlas frame. The anchor X is
// taken from the per-index table below (@ghidraAddress 0x30fdf4).
struct GaugeLabelSide {
    float flAnchorY = {};
    float flSizeX = {};
    float flSizeY = {};
    int nAtlasFrame = {};
};
constexpr GaugeLabelSide kLabelSideRecord[ReflecGaugeLayer::kSideCount] = {
    {17.0f, 76.0f, 28.0f, 0x85},
    {17.0f, 76.0f, 28.0f, 0x87},
};

// The gauge label anchor X by label index (@ghidraAddress 0x30fe18). Five entries: the table ends
// at 0x30fe2c, where the portrait gauge-icon table below begins, and the three values that used to
// follow here were that table's first descriptor read as floats.
constexpr float kLabelAnchorX[] = {173.0f, 106.0f, 39.0f, -28.0f, -95.0f};

// The gauge icon descriptor tables, indexed by icon index (landscape and portrait variants). Each
// is a 20-byte GaugeSpriteDescriptor read out of the binary's read-only data. Six records each:
// the portrait table's 120 bytes end exactly where the landscape table begins, and the landscape
// table's seventh record decodes as the neighbouring table's bytes rather than a descriptor.
const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeIconPortrait[] = {
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x89},
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x8a},
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x8b},
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x8c},
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x8d},
    {{58.0f, 1.0f}, {17.0f, 14.0f}, 0x8e},
}; // @ghidraAddress 0x30fe2c

const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeIconLandscape[] = {
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x116},
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x117},
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x118},
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x119},
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x11a},
    {{69.0f, 6.0f}, {17.0f, 14.0f}, 0x11b},
}; // @ghidraAddress 0x30fea4

// The gauge value/digit descriptor tables (20-byte GaugeSpriteDescriptor), read-only data embedded
// in the binary. The landscape table is indexed by player side; the portrait mode-0 table by
// (side * kPortraitValueRowStride + digit); the portrait alternate-mode table by side, with the
// digit's anchor X taken from a separate per-digit table.
constexpr int kPortraitValueRowStride = 5;

const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeValueLandscape[] = {
    {{50.0f, 10.0f}, {120.0f, 20.0f}, 0x114},
    {{50.0f, 10.0f}, {120.0f, 20.0f}, 0x115},
}; // @ghidraAddress 0x30fdc8

const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeValuePortrait[] = {
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x8f},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x90},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x91},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x92},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x93},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x94},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x95},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x96},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x97},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x98},
}; // @ghidraAddress 0x30fcc4

const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeValuePortraitAlt[] = {
    {{0.0f, 9.0f}, {60.0f, 12.0f}, 0x84},
    {{0.0f, 9.0f}, {60.0f, 12.0f}, 0x86},
}; // @ghidraAddress 0x30fd8c

// The alternate-mode digit anchor-X values, indexed by digit. @ghidraAddress 0x30fdb4
constexpr float kGaugeValueDigitX[] = {164.0f, 97.0f, 30.0f, -37.0f, -104.0f};

} // namespace

/** @ghidraAddress 0x18a7d0 */
ReflecGaugeLayer::ReflecGaugeLayer() {
    m_aScales[0] = 1.0f;
    m_aScales[1] = 1.0f;

    // Accumulate each part group's sprite count into its batch's capacity, recording each group's
    // base index within that batch.
    for (int i = 0; i < kPartGroupCount; ++i) {
        const int nBatch = kGroupBatch[i];
        m_aPartBaseIndex[i] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kGroupPartCount[i];
    }
}

/** @ghidraAddress 0x18a88c */
ReflecGaugeLayer *ReflecGaugeLayer::shared() {
    if (g_pReflecGaugeLayer == nullptr) {
        // The binary allocates the raw 0xa0-byte object and runs the constructor.
        g_pReflecGaugeLayer = new ReflecGaugeLayer();
    }
    return g_pReflecGaugeLayer;
}

/** @ghidraAddress 0x18a8dc */
void ReflecGaugeLayer::CreateGaugeSliderSprites() {
    if (m_bBuilt) {
        return;
    }

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build the four batches, each sized to its accumulated capacity, attach each under the
    // background layer's render object, make it visible, bind the atlas, and clear its frame index;
    // the third batch also sets its vertex flag.
    for (int i = 0; i < kBatchCount; ++i) {
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_aBatchCapacity[i]));
        m_apSprites[i] = pSprite;
        BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
        ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        if (i == kVertexFlagBatch) {
            pSprite->SetBlendMode(kVertexFlagMode);
        }
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x18ab98 */
float ReflecGaugeLayer::GetValueBySide(unsigned int nSide) const {
    assert(static_cast<int>(nSide) >= 0 && nSide < kSideCount);
    return m_aSides[nSide].flValue;
}

/** @ghidraAddress 0x18aa68 */
void ReflecGaugeLayer::SetValueBySide(float flValue, unsigned int nSide) {
    assert(static_cast<int>(nSide) >= 0 && nSide < kSideCount);
    // Quantise to hundredths, floor at zero, then cap at the maximum unless every reflec was a
    // full-just.
    float flQuantized = std::round(flValue * kGaugeQuantizeScale) / kGaugeQuantizeScale;
    if (flQuantized <= 0.0f) {
        flQuantized = 0.0f;
    }
    if (flQuantized > kGaugeMax && !GameSystem::GetGameSystem()->GetFullJustReflec()) {
        flQuantized = kGaugeMax;
    }
    m_aSides[nSide].flValue = flQuantized;
}

/** @ghidraAddress 0x18ab18 */
float ReflecGaugeLayer::GetValue(int nColor) const {
    assert(nColor >= 0 && nColor < kSideCount);
    // The colour selects the side by whether it matches the current play side.
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() == nColor ? 1 : 0;
    return GetValueBySide(nSide);
}

/** @ghidraAddress 0x18ac38 */
float ReflecGaugeLayer::GetAnotherValue(int nColor) const {
    assert(nColor >= 0 && nColor < kSideCount);
    // The colour selects the opposing side: the one that does not match the current play side.
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() != nColor ? 1 : 0;
    return GetValueBySide(nSide);
}

/** @ghidraAddress 0x18a9d8 */
void ReflecGaugeLayer::SetValue(float flValue, int nColor) {
    assert(nColor >= 0 && nColor < kSideCount);
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() == nColor ? 1 : 0;
    SetValueBySide(flValue, nSide);
}

/** @ghidraAddress 0x18abfc */
void ReflecGaugeLayer::AddReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nColor) {
    pGauge->SetValue(pGauge->GetValue(nColor) + flDelta, nColor);
}

/** @ghidraAddress 0x18acb8 */
void ReflecGaugeLayer::SubReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nPlayer) {
    // The gauge side is the player's opposite-of-match against the current play side.
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() != nPlayer ? 1 : 0;
    pGauge->SetValueBySide(pGauge->GetValueBySide(nSide) - flDelta, nSide);
}

/** @ghidraAddress 0x18ad0c */
void ReflecGaugeLayer::SetGaugeDisplayBrightness(float flValue) {
    m_flDisplayBrightness = flValue * kBrightnessScale + kBrightnessBias;
}

/** @ghidraAddress 0x18ad2c */
void ReflecGaugeLayer::SetGaugeStyle(int nStyle) {
    m_nGaugeStyle = nStyle;
}

/** @ghidraAddress 0x18ad34 */
void ReflecGaugeLayer::SetMirrorSide(int nSide) {
    m_nMirrorSide = nSide;
}

/** @ghidraAddress 0x18ad3c */
void ReflecGaugeLayer::StartFadeIn(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(1.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    // A non-positive duration snaps straight to opaque and marks the fade done.
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(1.0f);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x18ad6c */
void ReflecGaugeLayer::StartFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    // A non-positive duration snaps straight to transparent and marks the fade done.
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(0.0f);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x18a988 */
void ReflecGaugeLayer::ResetSideGauges() {
    // Each side clears to zero, except in the full-just-reflec challenge mode which seeds five.
    const float flReset =
        GameSystem::GetGameSystem()->GetFullJustReflec() ? kGaugeChallengeValue : 0.0f;
    for (SideGauge &side : m_aSides) {
        side = SideGauge{};
        side.flValue = flReset;
    }
}

/** @ghidraAddress 0x18b380 */
void ReflecGaugeLayer::EmitGaugeSprite(const GaugeSpriteDescriptor &descriptor,
                                       unsigned int nBatch,
                                       unsigned int nSide,
                                       int nAlpha,
                                       const S_VECTOR2 &uvOrigin,
                                       const S_VECTOR2 &uvSize) {
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    const int nIndex = pBatch->GetSpriteCount();
    if (nIndex >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    // Pick the quad's screen position and rotation by orientation and gauge mode.
    S_VECTOR2 position{};
    float flRotation = 0.0f;
    // The play-field half-height, rounding toward zero, is the vertical span each band is offset
    // by.
    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;
    if (IsPad()) {
        // Portrait: a fixed X with the two band Y positions taken from the layout table.
        const float aBandY[kSideCount] = {
            static_cast<float>(kPortraitBandBaseTop - g_nPlayfieldCentreSplit),
            static_cast<float>(kPortraitBandBaseBottom - g_nPlayfieldCentreSplit),
        };
        position = S_VECTOR2{kPortraitGaugeX, aBandY[nSide]};
    } else if (m_nGaugeStyle == 0) {
        const float aBandY[kSideCount] = {
            static_cast<float>(g_nGaugeTopBaseY + nHalfHeight - kFieldHalfSpan),
            static_cast<float>(g_nGaugeBottomBaseY - nHalfHeight - kFieldHalfSpan),
        };
        position = S_VECTOR2{kLandscapeGaugeX, aBandY[nSide]};
        // The 1P side mirrors when the mirror flag is set, flipping the X sign and half-turning.
        if (nSide == 0 && m_nMirrorSide == 1) {
            position.x = -position.x;
            flRotation = static_cast<float>(M_PI);
        }
    } else {
        const float aBandY[kSideCount] = {
            static_cast<float>(g_nGaugeAltTopBaseY + nHalfHeight - kFieldHalfSpan),
            static_cast<float>(g_nGaugeAltBottomBaseY - nHalfHeight - kFieldHalfSpan),
        };
        position = S_VECTOR2{kLandscapeAltGaugeX, aBandY[nSide]};
        // Every quad half-turns here except the mirrored 1P side.
        flRotation = static_cast<float>(M_PI);
        if (m_nMirrorSide != 1 || nSide != 0) {
            flRotation = 0.0f;
        }
    }

    pBatch->SetSpritePosition(nIndex, position);
    pBatch->SetSpriteAnchor(nIndex, descriptor.anchor);
    pBatch->SetSpriteSize(nIndex, descriptor.size);
    pBatch->SetSpriteUvOrigin(nIndex, uvOrigin);
    pBatch->SetSpriteUvSize(nIndex, uvSize);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteScale(nIndex, 1.0f, 1.0f);
    pBatch->SetSpriteColor(
        nIndex, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));
    pBatch->SetSpriteCount(nIndex + 1);
}

/** @ghidraAddress 0x18b034 */
void ReflecGaugeLayer::EmitBaseSprite(unsigned int nBatch, int nAlpha) {
    // The base descriptor is selected by orientation and gauge mode.
    GaugeSpriteDescriptor descriptor;
    if (IsPad()) {
        descriptor = kBaseSpritePortrait;
    } else if (m_nGaugeStyle == 0) {
        descriptor = kBaseSpriteDefault;
    } else {
        descriptor = kBaseSpriteAlt;
    }
    const SpriteUvEntry &uv = g_aSpriteUvTable[descriptor.nAtlasFrame];
    EmitGaugeSprite(descriptor,
                    nBatch,
                    0,
                    nAlpha,
                    S_VECTOR2{uv.flOriginU, uv.flOriginV},
                    S_VECTOR2{uv.flSizeU, uv.flSizeV});
}

/** @ghidraAddress 0x18b2cc */
void ReflecGaugeLayer::EmitLabelSprite(unsigned int nSide, int nLabelIndex, int nAlpha) {
    // The label's colour side follows the active player, inverted for the non-1P side.
    unsigned int nColor = static_cast<unsigned int>(GameSystem::GetGameSystem()->GetPlayColor());
    if (nSide != 1) {
        nColor = (nColor == 0) ? 1 : 0;
    }

    // The anchor X comes from the per-index table; the anchor Y, size, and frame from the
    // per-colour-side record.
    const GaugeLabelSide &side = kLabelSideRecord[nColor];
    GaugeSpriteDescriptor descriptor;
    descriptor.anchor = S_VECTOR2{kLabelAnchorX[nLabelIndex], side.flAnchorY};
    descriptor.size = S_VECTOR2{side.flSizeX, side.flSizeY};
    descriptor.nAtlasFrame = side.nAtlasFrame;
    const SpriteUvEntry &uv = g_aSpriteUvTable[descriptor.nAtlasFrame];
    EmitGaugeSprite(descriptor,
                    kLabelBatch,
                    nSide,
                    nAlpha,
                    S_VECTOR2{uv.flOriginU, uv.flOriginV},
                    S_VECTOR2{uv.flSizeU, uv.flSizeV});
}

/** @ghidraAddress 0x18b0dc */
void ReflecGaugeLayer::EmitIconSprite(unsigned int nSide, int nIconIndex, int nAlpha) {
    // The phone (portrait) uses its own icon table; the landscape build uses the other.
    const GaugeSpriteDescriptor &descriptor =
        IsPad() ? g_aGaugeIconPortrait[nIconIndex] : g_aGaugeIconLandscape[nIconIndex];
    const SpriteUvEntry &uv = g_aSpriteUvTable[descriptor.nAtlasFrame];
    EmitGaugeSprite(descriptor,
                    kIconBatch,
                    nSide,
                    nAlpha,
                    S_VECTOR2{uv.flOriginU, uv.flOriginV},
                    S_VECTOR2{uv.flSizeU, uv.flSizeV});
}

/** @ghidraAddress 0x18b174 */
void ReflecGaugeLayer::EmitGaugeValueSprite(float flScale,
                                            unsigned int nSide,
                                            int nDigit,
                                            int nAlpha) {
    // The colour side follows the active player, inverted for the non-1P side.
    unsigned int nColorSide =
        static_cast<unsigned int>(GameSystem::GetGameSystem()->GetPlayColor());
    if (nSide != 1) {
        nColorSide = (nColorSide == 0) ? 1 : 0;
    }

    // Select the cell descriptor and the anchor-X source: landscape and portrait mode 0 take both
    // from one record; the portrait alternate mode takes the anchor X from the per-digit table and
    // the rest from the per-side alternate record.
    const GaugeSpriteDescriptor *pRecord = nullptr;
    float flAnchorX = 0.0f;
    if (!IsPad()) {
        pRecord = &g_aGaugeValueLandscape[nColorSide];
        flAnchorX = pRecord->anchor.x;
    } else if (m_nGaugeStyle == 0) {
        pRecord = &g_aGaugeValuePortrait[nColorSide * kPortraitValueRowStride + nDigit];
        flAnchorX = pRecord->anchor.x;
    } else {
        pRecord = &g_aGaugeValuePortraitAlt[nColorSide];
        flAnchorX = kGaugeValueDigitX[nDigit];
    }

    // The cell's width and its UV width scale with the fill fraction; the anchor Y, height, and UV
    // origin/height are unscaled.
    const SpriteUvEntry &uv = g_aSpriteUvTable[pRecord->nAtlasFrame];
    GaugeSpriteDescriptor descriptor;
    descriptor.anchor = S_VECTOR2{flAnchorX, pRecord->anchor.y};
    descriptor.size = S_VECTOR2{pRecord->size.x * flScale, pRecord->size.y};
    descriptor.nAtlasFrame = pRecord->nAtlasFrame;
    EmitGaugeSprite(descriptor,
                    kValueBatch,
                    nSide,
                    nAlpha,
                    S_VECTOR2{uv.flOriginU, uv.flOriginV},
                    S_VECTOR2{uv.flSizeU * flScale, uv.flSizeV});
}

namespace {

// The per-half rates at which the animated display value climbs toward and falls away from the
// gauge value each frame (@ghidraAddress 0x30fc50 = 0.0012 rising, 0x30fc54 = 0.006 falling).
constexpr float kDisplayRiseRate = 0.0012f;
constexpr float kDisplayFallRate = 0.0060000005178153515f;

// The fractional-fill threshold above which a partially-filled cell counts as an extra whole cell
// (@ghidraAddress 0x2ee878 = 0.001), the maximum whole-cell count, and the alternate gauge mode
// that draws value labels.
constexpr double kCellFillThreshold = 0.001;
constexpr int kMaxCells = 5;
constexpr int kLabelGaugeMode = 1;

} // namespace

/** @ghidraAddress 0x18ad94 */
void ReflecGaugeLayer::UpdateGaugeBar(float flDelta) {
    // Ease the fill toward its target, deriving the bar's 0..1 fill ratio between its two
    // endpoints. The fade channel's five floats are repurposed as the fill tween: start/end are the
    // endpoints, duration the target, elapsed the current fill, and current the resolved fill
    // value.
    const float flTarget = m_fadeChannel.GetDuration();
    float flRatio;
    if (flTarget > m_fadeChannel.GetElapsed()) {
        float flCurrent = m_fadeChannel.GetElapsed() + flDelta;
        if (flCurrent > flTarget) {
            flCurrent = flTarget;
        }
        m_fadeChannel.SetElapsed(flCurrent);
        const float flProgress = flTarget == 0.0f ? 1.0f : flCurrent / flTarget;
        const float flFill = m_fadeChannel.GetStart() +
                             flProgress * (m_fadeChannel.GetEnd() - m_fadeChannel.GetStart());
        m_fadeChannel.SetCurrent(flFill);
        m_bFadeDone = true;
        flRatio = flFill;
    } else {
        flRatio = m_fadeChannel.GetCurrent();
    }

    // The label alpha tracks the fill scaled by the display brightness.
    const float flLabelAlpha = flRatio * m_flDisplayBrightness * kColorMax;

    // Clear every batch's sprite count before re-emitting this frame's cells.
    for (int i = 0; i < kBatchCount; ++i) {
        m_apSprites[i]->SetSpriteCount(0);
    }

    const float flRise = flDelta * kDisplayRiseRate;
    const float flFall = flDelta * kDisplayFallRate;
    for (unsigned int nHalf = 0; nHalf < kSideCount; ++nHalf) {
        const int nColor = static_cast<int>(flRatio * kColorMax * m_aScales[nHalf]);
        EmitBaseSprite(nHalf, nColor);

        // Advance this half's animated display value toward its gauge value, clamping at the
        // target.
        SideGauge &side = m_aSides[nHalf];
        if (side.flDisplayValue < side.flValue) {
            side.flDisplayValue += flRise;
            if (side.flDisplayValue > side.flValue) {
                side.flDisplayValue = side.flValue;
            }
        } else {
            side.flDisplayValue -= flFall;
            if (side.flDisplayValue < side.flValue) {
                side.flDisplayValue = side.flValue;
            }
        }
        const int nWholeCells = static_cast<int>(side.flDisplayValue);

        if (!IsPad()) {
            // Landscape: one icon plus a single value cell showing the fractional fill.
            const float flFrac = nWholeCells == kMaxCells ?
                                     1.0f :
                                     side.flDisplayValue - static_cast<float>(nWholeCells);
            EmitIconSprite(nHalf, nWholeCells, nColor);
            EmitGaugeValueSprite(flFrac, nHalf, nWholeCells, nColor);
            continue;
        }

        // Portrait mode 0 draws the icon; the alternate mode draws one value cell per filled step.
        if (m_nGaugeStyle == 0) {
            EmitIconSprite(nHalf, nWholeCells, nColor);
        }
        const float flFrac = side.flDisplayValue - static_cast<float>(nWholeCells);
        const int nExtra = static_cast<double>(flFrac) > kCellFillThreshold ? 1 : 0;
        const int nCellCount = std::min(nWholeCells + nExtra, kMaxCells);
        if (m_nGaugeStyle == 0) {
            continue;
        }
        for (int nCell = 0; nCell < nCellCount; ++nCell) {
            // The last cell shows the fractional fill; the rest are full.
            const float flCellFill =
                nCell >= nCellCount - 1 ? side.flDisplayValue - static_cast<float>(nCell) : 1.0f;
            EmitGaugeValueSprite(flCellFill, nHalf, nCell, nColor);
            if (flCellFill >= 1.0f && m_nGaugeStyle == kLabelGaugeMode) {
                EmitLabelSprite(nHalf, nCell, static_cast<int>(flLabelAlpha));
            }
        }
    }
}
