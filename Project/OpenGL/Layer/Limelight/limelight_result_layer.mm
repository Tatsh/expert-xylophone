#include "limelight_result_layer.h"

#include <cassert>

#include "../Classic/classic_parts_data_table.h"
#include "../Colette/phone_anchor_table.h"
#import "RBViewController.h"
#include "deviceenvironment.h"
#import "gamesystem.h"
#include "limelight_parts_data_table.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "parts_data_table.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#include "vectormath.h"

// The process-wide Limelight result-window layer, created lazily by shared().
static LimelightResultLayer *g_pLimelightResultLayer = nullptr; // @ghidraAddress 0x3de008

// The number of records in each Limelight phone-layout anchor-position table.
constexpr int kLimelightPhoneAnchorRecordCount = 88;

// The Limelight phone-layout anchor-position tables, zero-initialised in the binary's __common
// segment and filled at runtime by the result-layout-table initialisers; the orientation flag
// selects between them.
PhoneAnchorRecord
    g_aLimelightPhoneAnchorDefault[kLimelightPhoneAnchorRecordCount]; // @ghidraAddress 0x3dad10
PhoneAnchorRecord
    g_aLimelightPhoneAnchorPortrait[kLimelightPhoneAnchorRecordCount]; // @ghidraAddress 0x3db130

// The number of records in each Limelight phone-layout separator table.
constexpr int kLimelightSeparatorRecordCount = 52;

// The Limelight phone-layout separator tables (0x14-stride PhoneLayoutRecord), zero-initialised in
// the binary's __common segment and filled at runtime; the orientation flag selects between them.
PhoneLayoutRecord
    g_aLimelightSeparatorPhoneDefault[kLimelightSeparatorRecordCount]; // @ghidraAddress 0x3db550
PhoneLayoutRecord
    g_aLimelightSeparatorPhonePortrait[kLimelightSeparatorRecordCount]; // @ghidraAddress 0x3db960

// The number of records in each Limelight phone-layout by-state position table.
constexpr int kLimelightPositionByStateRecordCount = 4;

// The Limelight phone-layout by-state position tables (0x14-stride PhoneLayoutRecord): the state
// table (used on the iPad), and the portrait and default tables (selected by the orientation flag on
// the phone). Zero-initialised in the binary's __common segment and filled at runtime.
PhoneLayoutRecord
    g_aLimelightPositionPhoneState[kLimelightPositionByStateRecordCount]; // @ghidraAddress 0x3dbd70
PhoneLayoutRecord g_aLimelightPositionPhoneStatePortrait
    [kLimelightPositionByStateRecordCount]; // @ghidraAddress 0x3dbdc0
PhoneLayoutRecord g_aLimelightPositionPhoneStateDefault
    [kLimelightPositionByStateRecordCount]; // @ghidraAddress 0x3dbe10

// The single Limelight phone-layout centre-position records (16-byte PhoneLayoutRect, no anchor
// mode): the state record, and the portrait and default records (selected by the is-pad flag and
// orientation flags). Zero-initialised in the binary's __common segment and filled at runtime.
PhoneLayoutRect g_LimelightCenterPositionPhoneState = {};    // @ghidraAddress 0x3dbe60
PhoneLayoutRect g_LimelightCenterPositionPhonePortrait = {}; // @ghidraAddress 0x3dbe70
PhoneLayoutRect g_LimelightCenterPositionPhoneDefault = {};  // @ghidraAddress 0x3dbe80

namespace {

// The atlases the result window loads (@ghidraAddress 0x3cea80 and 0x3ceab0).
constexpr const char *kBackgroundTextureName = "00_texture/sel_bg";
constexpr const char *kPartsTextureName = "00_texture/result_parts";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x308a60). Slot 1 (the parts atlas) holds
// the most sprites; the rest are small fixed banks.
constexpr unsigned int kSlotCapacities[] = {1, 400, 1, 1, 1, 2, 2, 1};

// The per-slot texture-field selector (@ghidraAddress 0x308a40): the field index (0 = background,
// 1 = parts, 2 = overlay) into the layer's three texture fields for each slot that binds a texture.
// A slot binds a texture only when it is one of the first two or the last; the middle slots share
// the atlas already bound by the batch they mirror.
constexpr int kSlotTextureField[] = {0, 1, 4, 4, 4, 4, 4, 2};

// The base scale the builder seeds before creating the batches.
constexpr float kBaseScale = 0.7f;

// The non-zero defaults the constructor seeds: the default part alpha, and the "none" sentinels for
// the current result step and each button's tracked touch id.
constexpr int kDefaultPartAlpha = 0xff;
constexpr int kNoStep = -1;
constexpr int kNoTouchId = -1;

// The slot range whose members do not bind a texture: slots kFirstUntexturedSlot through
// kFirstUntexturedSlot + kUntexturedSlotSpan - 1 (that is, slots 2 through 6).
constexpr int kFirstUntexturedSlot = 2;
constexpr int kUntexturedSlotSpan = 5;

// The anchor modes that offset a base coordinate relative to the play-field viewport. Mode 0 (and
// any value outside this range) leaves the coordinate unshifted.
enum AnchorMode {
    kAnchorNone = 0,                // No offset.
    kAnchorHalfHeight = 1,          // y += viewportHeight / 2.
    kAnchorFullHeight = 2,          // y += viewportHeight.
    kAnchorHalfWidth = 3,           // x += viewportWidth / 2.
    kAnchorHalfWidthHalfHeight = 4, // x += viewportWidth / 2, y += viewportHeight / 2.
    kAnchorHalfWidthFullHeight = 5, // x += viewportWidth / 2, y += viewportHeight.
    kAnchorFullWidth = 6,           // x += viewportWidth.
    kAnchorFullWidthHalfHeight = 7, // x += viewportWidth, y += viewportHeight / 2.
    kAnchorFullWidthFullHeight = 8, // x += viewportWidth, y += viewportHeight.
};

// Offsets a base coordinate by half or full viewport dimensions per the anchor mode.
inline void ApplyAnchorOffset(int nAnchorMode, float *pX, float *pY) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flWidth = pGameSystem->GetViewportWidth();
    const float flHeight = pGameSystem->GetViewportHeight();
    switch (nAnchorMode) {
    case kAnchorHalfHeight:
        *pY += flHeight * 0.5f;
        break;
    case kAnchorFullHeight:
        *pY += flHeight;
        break;
    case kAnchorHalfWidth:
        *pX += flWidth * 0.5f;
        break;
    case kAnchorHalfWidthHalfHeight:
        *pX += flWidth * 0.5f;
        *pY += flHeight * 0.5f;
        break;
    case kAnchorHalfWidthFullHeight:
        *pX += flWidth * 0.5f;
        *pY += flHeight;
        break;
    case kAnchorFullWidth:
        *pX += flWidth;
        break;
    case kAnchorFullWidthHalfHeight:
        *pX += flWidth;
        *pY += flHeight * 0.5f;
        break;
    case kAnchorFullWidthFullHeight:
        *pX += flWidth;
        *pY += flHeight;
        break;
    default:
        break;
    }
}

} // namespace

/** @ghidraAddress 0x12abb4 */
LimelightResultLayer::LimelightResultLayer() {
    // The base constructor and the zero-initialised members clear the layer; the constructor then
    // seeds the non-zero defaults: the default part alpha, the current-step "none" sentinel, and each
    // button's "none" touch id.
    m_nDefaultAlpha = kDefaultPartAlpha;
    m_nCurrentStep = kNoStep;
    for (ResultButtonRecord &button : m_aButtons) {
        button.nTouchId = kNoTouchId;
    }
}

/** @ghidraAddress 0x123d54 */
LimelightResultLayer *LimelightResultLayer::shared() {
    if (g_pLimelightResultLayer == nullptr) {
        // The binary allocates the raw 0x170-byte object and runs its initialiser, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pLimelightResultLayer = new LimelightResultLayer();
    }
    return g_pLimelightResultLayer;
}

/** @ghidraAddress 0x12ab60 */
void LimelightResultLayer::InitializePhoneResultLayer() {
    m_nActive = 1;
    m_bBonusCueArmed = GameSystem::GetGameSystem()->GetResultBonusFeatureActive();
    m_flBonusCueTimer = 0.0f;
    m_bTwitterAvailable = [RBViewController hasTwitterAPI];
}

/** @ghidraAddress 0x123db0 */
void LimelightResultLayer::InitializePhoneSpriteInstancers() {
    if (m_bBuilt) {
        return;
    }

    m_nDefaultAlpha = 0;
    m_flBaseScale = kBaseScale;

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {
        m_pBackgroundTexture, m_pPartsTexture, m_pOverlayTexture};

    // Build one sprite instancer per slot, register it in the global scene tree, make it visible,
    // and clear its sprite count. The two edge slots bind a texture per the selector; the middle
    // slots (2 through 6) share the atlas of the batch they mirror, so they bind none here.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot] = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        m_apSprites[nSlot]->RegisterGlobal();
        m_apSprites[nSlot]->SetVisible(true);
        if (static_cast<unsigned int>(nSlot - kFirstUntexturedSlot) >= kUntexturedSlotSpan) {
            m_apSprites[nSlot]->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        }
        m_apSprites[nSlot]->SetSpriteCount(0);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x123e8c */
void LimelightResultLayer::SetPhoneInstancerTextureAndScale(unsigned int nPhoneIndex,
                                                            ne::C_TEXTURE *pTexture) {
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nPhoneIndex];
    if (pInstancer == nullptr) {
        return;
    }
    const int nCount = static_cast<int>(pInstancer->GetCapacity());
    pInstancer->SetRefCountedMember(pTexture);
    if (pTexture == nullptr || nCount < 1) {
        return;
    }

    // The image's point size (its pixels over the retina scale) and its fraction of the allocated
    // power-of-two texture.
    const float flPointWidth = static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetScale();
    const float flPointHeight =
        static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetScale();
    const S_VECTOR2 size{flPointWidth, flPointHeight};
    const S_VECTOR2 uvSize{static_cast<float>(pTexture->GetImageWidth()) /
                               static_cast<float>(pTexture->GetAllocWidth()),
                           static_cast<float>(pTexture->GetImageHeight()) /
                               static_cast<float>(pTexture->GetAllocHeight())};

    for (int nSlot = 0; nSlot < nCount; ++nSlot) {
        pInstancer->SetSpriteSize(nSlot, size);
        pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{0.0f, 0.0f});
        pInstancer->SetSpriteUvSize(nSlot, uvSize);
    }
}

/** @ghidraAddress 0x123838 */
PartsDataRecord *LimelightResultLayer::GetPartsData(unsigned int nIndex) const {
    assert(static_cast<int>(nIndex) >= 0 && nIndex < kLimelightPartsRecordBound);

    // The pad build uses the pad table; the phone build uses the phone table.
    return IsPad() ? &g_aLimelightPartsPad[nIndex] : &g_aLimelightPartsPhone[nIndex];
}

/** @ghidraAddress 0x1238d0 */
PartsDataRecord *LimelightResultLayer::getPartsData_Phone(int nIndex) {
    assert(nIndex >= 0 && nIndex < kLimelightPadGlyphRecordBound);

    // The pad parts table doubles as the phone glyph-metrics table.
    return &g_aLimelightPartsPad[nIndex];
}

/** @ghidraAddress 0x123940 */
void LimelightResultLayer::getPosition_Phone(int nIndex, S_VECTOR2 *pOutPosition) const {
    assert(nIndex >= 0 && nIndex < kLimelightPhoneAnchorRecordCount);

    // The orientation flag selects the portrait table; otherwise the default table is used.
    const PhoneAnchorRecord &record = m_bPortrait ? g_aLimelightPhoneAnchorPortrait[nIndex] :
                                                    g_aLimelightPhoneAnchorDefault[nIndex];
    pOutPosition->x = record.flX;
    pOutPosition->y = record.flY;

    // Offset the base coordinate by half or full viewport dimensions per the record's anchor mode.
    ApplyAnchorOffset(record.nAnchorMode, &pOutPosition->x, &pOutPosition->y);
}

/** @ghidraAddress 0x123b5c */
void LimelightResultLayer::getPositionByState_Phone(int nIndex, PhoneLayoutRect *pOutRect) const {
    // The iPad uses the state table; the phone uses its portrait or default table by orientation.
    const PhoneLayoutRecord &record =
        IsPad() ? g_aLimelightPositionPhoneState[nIndex] :
                  (m_bPortrait ? g_aLimelightPositionPhoneStatePortrait[nIndex] :
                                 g_aLimelightPositionPhoneStateDefault[nIndex]);
    pOutRect->flX = record.flX;
    pOutRect->flY = record.flY;
    pOutRect->flWidth = record.flWidth;
    pOutRect->flHeight = record.flHeight;

    // Offset the leading coordinate by half or full viewport dimensions per the record's anchor mode.
    ApplyAnchorOffset(record.nAnchorMode, &pOutRect->flX, &pOutRect->flY);
}

/** @ghidraAddress 0x123ad8 */
const PhoneLayoutRecord *LimelightResultLayer::getSeparator_Phone(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kLimelightSeparatorRecordCount);

    // The orientation flag selects the portrait table; otherwise the default table is used.
    return m_bPortrait ? &g_aLimelightSeparatorPhonePortrait[nIndex] :
                         &g_aLimelightSeparatorPhoneDefault[nIndex];
}

/** @ghidraAddress 0x123cc8 */
void LimelightResultLayer::getCenterPosition_Phone(PhoneLayoutRect *pOutRect) const {
    // When the state flag is set the state record is copied verbatim, with no viewport anchoring.
    if (IsPad()) {
        *pOutRect = g_LimelightCenterPositionPhoneState;
        (void)GameSystem::
            GetGameSystem(); // The binary tail-calls the singleton getter and discards it.
        return;
    }

    // Otherwise the orientation flag selects the portrait or default record, and the leading
    // coordinate is shifted by half the viewport width and height.
    const PhoneLayoutRect &record = m_bPortrait ? g_LimelightCenterPositionPhonePortrait :
                                                  g_LimelightCenterPositionPhoneDefault;
    *pOutRect = record;
    ApplyAnchorOffset(kAnchorHalfWidthHalfHeight, &pOutRect->flX, &pOutRect->flY);
}

/** @ghidraAddress 0x129f84 */
void LimelightResultLayer::EmitPhonePartWithOffset(unsigned int nSlot,
                                                   unsigned int nCharCode,
                                                   const S_VECTOR2 &position,
                                                   const S_VECTOR2 &offset,
                                                   unsigned int nAlpha,
                                                   bool bShadowPass,
                                                   float flRotation,
                                                   float flScaleX,
                                                   float flScaleY) {
    if (nCharCode >= kLimelightPadGlyphRecordBound) {
        return;
    }
    // The glyph metrics come from the pad parts table indexed by the character code; the texture
    // rectangle from the Limelight glyph UV palette. The sprite is placed at the position plus the
    // offset.
    const PartsDataRecord *pGlyph = &g_aLimelightPartsPad[nCharCode];
    const UvPaletteEntry &palette = g_aLimelightGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass ? 0x80 : 0xff;
    AppendSpriteToSlot(S_VECTOR2{position.x + offset.x, position.y + offset.y},
                       S_VECTOR2{pGlyph->flX, pGlyph->flY},
                       S_VECTOR2{pGlyph->flWidth, pGlyph->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x12a01c */
void LimelightResultLayer::RenderPhonePartWithOffset(unsigned int nSlot,
                                                     unsigned int nCharCode,
                                                     int nPositionIndex,
                                                     const S_VECTOR2 &offset,
                                                     unsigned int nAlpha,
                                                     bool bShadowPass,
                                                     float flRotation,
                                                     float flScaleX,
                                                     float flScaleY) {
    if (nCharCode >= kLimelightPadGlyphRecordBound) {
        return;
    }
    // Resolve the base position by index and add the offset.
    S_VECTOR2 position{};
    getPosition_Phone(nPositionIndex, &position);
    // The glyph metrics come from the pad parts table indexed by the character code; the texture
    // rectangle from the Limelight glyph UV palette.
    const PartsDataRecord *pGlyph = &g_aLimelightPartsPad[nCharCode];
    const UvPaletteEntry &palette = g_aLimelightGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass ? 0x80 : 0xff;
    AppendSpriteToSlot(S_VECTOR2{position.x + offset.x, position.y + offset.y},
                       S_VECTOR2{pGlyph->flX, pGlyph->flY},
                       S_VECTOR2{pGlyph->flWidth, pGlyph->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x129c34 */
void LimelightResultLayer::EmitPhoneHalfScaleTexturedPart(unsigned int nSlot,
                                                          const S_VECTOR2 &position,
                                                          unsigned int nScale,
                                                          unsigned int nIntensity) {
    if (nSlot >= kSpriteSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    // The binary does not null-check the bound texture here.
    ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flTextureScale = pTexture->GetScale();
    // The quad is sized by the texture's scale factor and centred by anchoring at half its size.
    const S_VECTOR2 spriteSize{flImageWidth / flTextureScale, flImageHeight / flTextureScale};
    const S_VECTOR2 anchor{spriteSize.x * 0.5f, spriteSize.y * 0.5f};
    const S_VECTOR2 uvSize{flImageWidth / static_cast<float>(pTexture->GetAllocWidth()),
                           flImageHeight / static_cast<float>(pTexture->GetAllocHeight())};
    const unsigned int nAlpha =
        static_cast<unsigned int>(static_cast<float>(nScale) * m_flBaseScale);
    AppendSpriteToSlot(position,
                       anchor,
                       spriteSize,
                       S_VECTOR2{},
                       uvSize,
                       0.0f,
                       S_VECTOR2{1.0f, 1.0f},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

namespace {

// The digit glyph bank RenderPhoneNumberDigitsRow draws from (its '0'), its maximum digit count, the
// nominal glyph width used to centre the run, and the extra pixel added to each glyph's own width
// when advancing. The glyphs draw into the parts slot.
constexpr unsigned int kPhoneRowGlyphSlot = 1;
constexpr unsigned int kPhoneRowDigitBank = 0x39;
constexpr int kPhoneRowMaxDigits = 4;
constexpr float kPhoneRowNominalGlyphWidth = 7.0f;
constexpr float kPhoneRowGlyphSpacing = 1.0f;

} // namespace

namespace {
// The total-score digit layout: the number of digit places, the minimum drawn, the ones-place and
// higher-place glyph banks, the marker glyph drawn below the ones digit, the marker's x and y
// offsets, the between-digit gap, the tenths scale, and the alpha-halving factor.
constexpr int kTotalScoreDigits = 7;
constexpr int kTotalScoreMinDigits = 2;
constexpr unsigned int kTotalScoreOnesBank = 0x71;
constexpr unsigned int kTotalScoreHighBank = 0x67;
constexpr unsigned int kTotalScoreMarkerGlyph = 0x7b;
constexpr float kTotalScoreMarkerOffsetX = -4.0f;
constexpr float kTotalScoreMarkerOffsetY = -20.0f;
constexpr float kTotalScoreDigitGap = -2.0f;
constexpr float kTotalScoreTenthsScale = 10.0f;
constexpr float kTotalScoreDimFactor = 0.5f;

// The paired ones-place glyph sits ten part ids above the digit-zero base.
constexpr unsigned int kPhonePairedGlyphOffset = 10;

// The multiplier digit layout: the digit count, the minimum drawn, the digit glyph bank, and the
// marker glyph drawn beside the ones digit. It shares the total-score tenths scale, gap, and dim
// factor.
constexpr int kMultiplierDigits = 3;
constexpr int kMultiplierMinDigits = 2;
constexpr unsigned int kMultiplierDigitBank = 0x81;
constexpr unsigned int kMultiplierMarkerGlyph = 0x8d;
} // namespace

/** @ghidraAddress 0x129d04 */
void LimelightResultLayer::RenderPhoneNumber(float flSpacing,
                                             int nValue,
                                             int nMaxDigits,
                                             const S_VECTOR2 *pPosition,
                                             const S_VECTOR2 *pOffset,
                                             unsigned int nBasePartId,
                                             unsigned int nFlags,
                                             int bPadZeros,
                                             unsigned int nAlpha) {
    // Split the value into up to nMaxDigits digits (ones first), tracking the significant count.
    int aDigits[3] = {};
    int nSignificant = 0;
    for (int i = 0; i < nMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i;
        }
        nValue /= 10;
    }
    // When only the ones place is significant and the show-zero flag is set, draw a second (zero)
    // digit as well. The digit slot is already zero from the split.
    const bool bShowZero = (nFlags & 1) != 0;
    if (nSignificant == 0 && bShowZero) {
        nSignificant = 1;
    }

    // Start at the base position plus the offset.
    S_VECTOR2 cursor = *pPosition;
    S_VECTOR2 offset = *pOffset;
    AddVector2(&cursor, &offset);

    // Draw each significant digit right to left, stepping the cursor left by the glyph's own width
    // less the spacing. When the paired flag is set, a second glyph ten ids up is drawn beside the
    // ones digit.
    const bool bPaired = (nFlags & 1) != 0;
    for (int i = 0; i <= nSignificant; ++i) {
        const unsigned int nGlyph = aDigits[i] + nBasePartId;
        cursor.x -= getPartsData_Phone(static_cast<int>(nGlyph))->flWidth;
        RenderPhoneResultSpriteById(1, nGlyph, cursor, nAlpha, 0, 0.0f, 1.0f, 1.0f);
        cursor.x -= flSpacing;
        if (i == 0 && bPaired) {
            const unsigned int nPaired = nBasePartId + kPhonePairedGlyphOffset;
            cursor.x -= getPartsData_Phone(static_cast<int>(nPaired))->flWidth;
            RenderPhoneResultSpriteById(1, nPaired, cursor, nAlpha, 0, 0.0f, 1.0f, 1.0f);
            cursor.x -= flSpacing;
        }
    }

    // Dim-pad the remaining leading positions with the base glyph.
    if (bPadZeros && nSignificant + 1 < nMaxDigits) {
        for (int nPad = (nMaxDigits - 1) - nSignificant; nPad != 0; --nPad) {
            cursor.x -= getPartsData_Phone(static_cast<int>(nBasePartId))->flWidth;
            RenderPhoneResultSpriteById(1, nBasePartId, cursor, nAlpha, 1, 0.0f, 1.0f, 1.0f);
            cursor.x -= flSpacing;
        }
    }
}

/** @ghidraAddress 0x12a760 */
void LimelightResultLayer::RenderPhoneMultiplierDigitSprites(float flMultiplier,
                                                             const S_VECTOR2 *pPosition,
                                                             unsigned int nAlpha) {
    // The multiplier is scaled to tenths and split into three digits (ones first).
    const int nValue = static_cast<int>(flMultiplier * kTotalScoreTenthsScale);
    int aDigits[kMultiplierDigits] = {};
    int nSignificant = 0;
    int nRemaining = nValue;
    for (int i = 0; i < kMultiplierDigits; ++i) {
        aDigits[i] = nRemaining % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nRemaining /= 10;
    }
    const int nDrawCount =
        nSignificant < kMultiplierMinDigits ? kMultiplierMinDigits : nSignificant;

    float flBaseline = pPosition->x;
    const float flPosY = pPosition->y;
    unsigned int nCurrentAlpha = nAlpha;
    for (int i = 0; i < kMultiplierDigits; ++i) {
        // Leading positions beyond the significant digits draw at half alpha.
        if (i == nDrawCount) {
            nCurrentAlpha = static_cast<unsigned int>(static_cast<float>(nCurrentAlpha & 0xff) *
                                                      kTotalScoreDimFactor);
        }
        const PartsDataRecord *pGlyph =
            getPartsData_Phone(static_cast<int>(aDigits[i] + kMultiplierDigitBank));
        const float flDrawX = flBaseline - pGlyph->flWidth;
        const float flDigitY = flPosY - pGlyph->flHeight;
        RenderPhoneResultSpriteById(1,
                                    aDigits[i] + kMultiplierDigitBank,
                                    S_VECTOR2{flDrawX, flDigitY},
                                    nCurrentAlpha & 0xff,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        flBaseline = flDrawX + kTotalScoreDigitGap;
        // The marker glyph is drawn at the post-advance baseline, beside the ones digit.
        if (i == 0) {
            RenderPhoneResultSpriteById(1,
                                        kMultiplierMarkerGlyph,
                                        S_VECTOR2{flBaseline, flDigitY},
                                        nCurrentAlpha & 0xff,
                                        0,
                                        0.0f,
                                        1.0f,
                                        1.0f);
        }
    }
}

/** @ghidraAddress 0x12a928 */
void LimelightResultLayer::RenderPhoneTotalScoreDigits(const S_VECTOR2 *pPosition,
                                                       unsigned int nAlpha) {
    // The total score is the sum of the five result-bonus values, scaled to tenths.
    const int nTotal = static_cast<int>((m_flExperienceBonus + m_flClearBonus + m_flMissBonus +
                                         m_flRankBonus + m_flFirstPlayBonus) *
                                        kTotalScoreTenthsScale);

    // Split into seven digits (ones first), tracking the significant count.
    int aDigits[kTotalScoreDigits] = {};
    int nSignificant = 0;
    int nRemaining = nTotal;
    for (int i = 0; i < kTotalScoreDigits; ++i) {
        aDigits[i] = nRemaining % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nRemaining /= 10;
    }
    const int nDrawCount =
        nSignificant < kTotalScoreMinDigits ? kTotalScoreMinDigits : nSignificant;

    float flCursorX = pPosition->x;
    const float flY = pPosition->y;
    unsigned int nCurrentAlpha = nAlpha;
    for (int i = 0; i < kTotalScoreDigits; ++i) {
        // The between-digit gap precedes every place after the ones digit.
        if (i != 0) {
            flCursorX += kTotalScoreDigitGap;
        }
        // Leading positions beyond the significant digits draw at half alpha.
        if (i == nDrawCount) {
            nCurrentAlpha = static_cast<unsigned int>(static_cast<float>(nCurrentAlpha & 0xff) *
                                                      kTotalScoreDimFactor);
        }
        const unsigned int nBank = i == 0 ? kTotalScoreOnesBank : kTotalScoreHighBank;
        const PartsDataRecord *pGlyph = getPartsData_Phone(static_cast<int>(aDigits[i] + nBank));
        flCursorX -= pGlyph->flWidth;
        RenderPhoneResultSpriteById(1,
                                    aDigits[i] + nBank,
                                    S_VECTOR2{flCursorX, flY - pGlyph->flHeight},
                                    nCurrentAlpha & 0xff,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        // A marker glyph sits below and just left of the ones digit.
        if (i == 0) {
            RenderPhoneResultSpriteById(
                1,
                kTotalScoreMarkerGlyph,
                S_VECTOR2{flCursorX + kTotalScoreMarkerOffsetX, flY + kTotalScoreMarkerOffsetY},
                nCurrentAlpha & 0xff,
                0,
                0.0f,
                1.0f,
                1.0f);
        }
    }
}

/** @ghidraAddress 0x12a11c */
void LimelightResultLayer::RenderPhoneNumberDigitsRow(int nValue,
                                                      const S_VECTOR2 *pPosition,
                                                      unsigned int nAlpha) {
    // Split the value into up to four digits (ones first), tracking the count of significant
    // digits, rendering at least one.
    int aDigits[kPhoneRowMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kPhoneRowMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant == 0) {
        nSignificant = 1;
    }

    // Centre the run about the position using the nominal glyph width, then step left by each
    // glyph's own width (plus one pixel) as it is drawn.
    const int nHalfWidth =
        static_cast<int>(static_cast<float>(nSignificant) * kPhoneRowNominalGlyphWidth);
    float flCursorX = pPosition->x + static_cast<float>(nHalfWidth) * 0.5f;
    const float flY = pPosition->y;

    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nGlyph = aDigits[i] + kPhoneRowDigitBank;
        const float flWidth =
            getPartsData_Phone(static_cast<int>(nGlyph))->flWidth + kPhoneRowGlyphSpacing;
        flCursorX -= flWidth;
        const S_VECTOR2 drawPos{flCursorX, flY};
        RenderPhoneResultSpriteById(
            kPhoneRowGlyphSlot, nGlyph, drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
    }
}

namespace {

// The percent-value glyph banks and layout: the parts slot, the digit bank ('0'), the leading
// percent marker glyph, the decimal-point glyph, the minimum digit count drawn, the fixed per-glyph
// advance, the extra centring pad, and the point's own advance.
constexpr unsigned int kPercentSlot = 1;
constexpr unsigned int kPercentDigitBank = 0x39;
constexpr unsigned int kPercentMarkerGlyph = 0x45;
constexpr unsigned int kPercentPointGlyph = 0x43;
constexpr int kPercentMinDigits = 2;
constexpr float kPercentGlyphAdvance = 6.0f;
constexpr float kPercentCentrePad = 2.0f;
constexpr float kPercentPointAdvance = 2.0f;

} // namespace

/** @ghidraAddress 0x12a50c */
void LimelightResultLayer::RenderPhonePercentValue(int nValue,
                                                   const S_VECTOR2 *pPosition,
                                                   unsigned int nAlpha) {
    // Split the value into up to four digits (ones first), tracking the significant-digit count.
    int aDigits[4] = {};
    int nSignificant = 0;
    for (int i = 0; i < 4; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    const int nDrawCount = nSignificant < kPercentMinDigits ? kPercentMinDigits : nSignificant;

    // Centre the run about the position: one advance per drawn digit plus the leading marker, rounded
    // and halved, then step left by one advance before the marker.
    const int nHalfWidth = static_cast<int>(
        static_cast<float>(nDrawCount + 1) * kPercentGlyphAdvance + kPercentCentrePad);
    float flCursorX = pPosition->x + static_cast<float>(nHalfWidth) * 0.5f - kPercentGlyphAdvance;
    const float flY = pPosition->y;

    // The leading percent marker.
    RenderPhoneResultSpriteById(
        kPercentSlot, kPercentMarkerGlyph, S_VECTOR2{flCursorX, flY}, nAlpha, 0, 0.0f, 1.0f, 1.0f);

    for (int i = 0; i < nDrawCount; ++i) {
        flCursorX -= kPercentGlyphAdvance;
        RenderPhoneResultSpriteById(kPercentSlot,
                                    aDigits[i] + kPercentDigitBank,
                                    S_VECTOR2{flCursorX, flY},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        // The decimal point follows the ones digit.
        if (i == 0) {
            flCursorX -= kPercentPointAdvance;
            RenderPhoneResultSpriteById(kPercentSlot,
                                        kPercentPointGlyph,
                                        S_VECTOR2{flCursorX, flY},
                                        nAlpha,
                                        0,
                                        0.0f,
                                        1.0f,
                                        1.0f);
        }
    }
}

namespace {

// The fraction glyph banks and layout: the parts slot, the digit bank ('0'), the separating slash
// glyph, the nominal per-digit width used to centre the run, the per-digit advance, the slash
// advance, and the centring pad.
constexpr unsigned int kFractionSlot = 1;
constexpr unsigned int kFractionDigitBank = 0x39;
constexpr unsigned int kFractionSlashGlyph = 0x46;
constexpr float kFractionNominalWidth = 7.0f;
constexpr float kFractionDigitInset = 6.0f;
constexpr float kFractionDigitAdvance = 7.0f;
constexpr float kFractionSlashInset = 7.0f;
constexpr float kFractionSlashAdvance = 1.0f;
constexpr float kFractionCentrePad = 2.0f;

// Splits a value into up to four digits (ones first) and returns the significant-digit count (at
// least one).
inline int SplitFractionDigits(int nValue, int (&aDigits)[4]) {
    int nSignificant = 0;
    for (int i = 0; i < 4; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    return nSignificant < 1 ? 1 : nSignificant;
}

} // namespace

/** @ghidraAddress 0x12a27c */
void LimelightResultLayer::RenderPhoneFraction(int nNumerator,
                                               int nDenominator,
                                               const S_VECTOR2 *pPosition,
                                               unsigned int nAlpha) {
    int aNumerator[4] = {};
    int aDenominator[4] = {};
    const int nNumCount = SplitFractionDigits(nNumerator, aNumerator);
    const int nDenCount = SplitFractionDigits(nDenominator, aDenominator);

    // Centre the run: the numerator and denominator digits at the nominal width, plus the slash's
    // advance and the centring pad, rounded and halved.
    const int nHalfWidth = static_cast<int>(static_cast<float>(nNumCount) * kFractionNominalWidth +
                                            static_cast<float>(nDenCount) * kFractionNominalWidth +
                                            kFractionDigitInset + kFractionCentrePad);
    float flCursorX = pPosition->x + static_cast<float>(nHalfWidth) * 0.5f;
    const float flY = pPosition->y;

    // The denominator digits, right to left.
    for (int i = 0; i < nDenCount; ++i) {
        RenderPhoneResultSpriteById(kFractionSlot,
                                    aDenominator[i] + kFractionDigitBank,
                                    S_VECTOR2{flCursorX - kFractionDigitInset, flY},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        flCursorX -= kFractionDigitAdvance;
    }

    // The separating slash: unlike a digit, its inset folds into the running cursor before the
    // slash's own one-pixel advance.
    flCursorX -= kFractionSlashInset;
    RenderPhoneResultSpriteById(
        kFractionSlot, kFractionSlashGlyph, S_VECTOR2{flCursorX, flY}, nAlpha, 0, 0.0f, 1.0f, 1.0f);
    flCursorX -= kFractionSlashAdvance;

    // The numerator digits, right to left.
    for (int i = 0; i < nNumCount; ++i) {
        RenderPhoneResultSpriteById(kFractionSlot,
                                    aNumerator[i] + kFractionDigitBank,
                                    S_VECTOR2{flCursorX - kFractionDigitInset, flY},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        flCursorX -= kFractionDigitAdvance;
    }
}

/** @ghidraAddress 0x12ac64 */
void LimelightResultLayer::AppendSpriteToSlot(const S_VECTOR2 &position,
                                              const S_VECTOR2 &anchor,
                                              const S_VECTOR2 &size,
                                              const S_VECTOR2 &uvOrigin,
                                              const S_VECTOR2 &uvSize,
                                              float flRotation,
                                              const S_VECTOR2 &scale,
                                              unsigned int nSlot,
                                              unsigned int nIntensity,
                                              unsigned int nAlpha) {
    if (nSlot >= kSpriteSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    const int nSprite = pInstancer->GetSpriteCount();
    if (nSprite >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    pInstancer->SetSpritePosition(nSprite, position);
    pInstancer->SetSpriteAnchor(nSprite, anchor);
    pInstancer->SetSpriteSize(nSprite, size);
    pInstancer->SetSpriteUvOrigin(nSprite, uvOrigin);
    pInstancer->SetSpriteUvSize(nSprite, uvSize);
    pInstancer->SetSpriteRotation(nSprite, flRotation);
    pInstancer->SetSpriteScale(nSprite, scale.x, scale.y);
    pInstancer->SetSpriteColor(nSprite, nIntensity, nIntensity, nIntensity, nAlpha);
    pInstancer->SetSpriteCount(nSprite + 1);
}

/** @ghidraAddress 0x1299d8 */
void LimelightResultLayer::RenderPhoneResultSpriteById(unsigned int nSlot,
                                                       unsigned int nPartId,
                                                       const S_VECTOR2 &position,
                                                       unsigned int nAlpha,
                                                       bool bDimmed,
                                                       float flRotation,
                                                       float flScaleX,
                                                       float flScaleY) {
    if (nPartId >= kLimelightPadGlyphRecordBound) {
        return;
    }
    // The glyph metrics come from the pad parts table indexed by the part id; the texture rectangle
    // from the Limelight glyph UV palette.
    const PartsDataRecord *pGlyph = &g_aLimelightPartsPad[nPartId];
    const UvPaletteEntry &palette = g_aLimelightGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bDimmed ? 0x80 : 0xff;
    AppendSpriteToSlot(position,
                       S_VECTOR2{pGlyph->flX, pGlyph->flY},
                       S_VECTOR2{pGlyph->flWidth, pGlyph->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x12a6cc */
void LimelightResultLayer::EmitPhonePartAtAnchor(unsigned int nSlot,
                                                 unsigned int nPartId,
                                                 unsigned int nAnchorIndex,
                                                 const S_VECTOR2 *pOffset,
                                                 unsigned int nAlpha,
                                                 float flScaleX) {
    S_VECTOR2 position{};
    getPosition_Phone(static_cast<int>(nAnchorIndex), &position);
    S_VECTOR2 offset = *pOffset;
    AddVector2(&position, &offset);
    RenderPhoneResultSpriteById(nSlot, nPartId, position, nAlpha, false, 0.0f, flScaleX, 1.0f);
}

/** @ghidraAddress 0x126ab4 */
void LimelightResultLayer::EmitPartSprite(float flRotation,
                                          float flScaleX,
                                          float flScaleY,
                                          unsigned int nSlot,
                                          unsigned int nPartId,
                                          const S_VECTOR2 &position,
                                          unsigned int nAlpha,
                                          bool bShadowPass) {
    // Part id 0xff is the "no part" sentinel used to skip optional parts.
    if (nPartId >= 0xff) {
        return;
    }
    const PartsDataRecord *pRecord = GetPartsData(nPartId);
    const UvPaletteEntry &palette = g_aUvPalette[pRecord->nUvPaletteIndex];
    // The main pass draws at full intensity; the shadow pass darkens the quad to half intensity.
    const unsigned int nIntensity = bShadowPass ? 0x80 : 0xff;
    AppendSpriteToSlot(position,
                       S_VECTOR2{pRecord->flX, pRecord->flY},
                       S_VECTOR2{pRecord->flWidth, pRecord->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

namespace {

// The part id of the '0' digit glyph; digits 0 through 9 are parts kDigitZeroPart through
// kDigitZeroPart + 9.
constexpr unsigned int kDigitZeroPart = 0x69;
// The maximum number of decimal digits RenderDigits draws.
constexpr int kMaxDigits = 4;
// The instancer slot the parts atlas (including digit glyphs) draws into.
constexpr unsigned int kPartsSlot = 1;

// The maximum number of digits RenderNumber splits a value into (the binary's digit buffer holds
// six).
constexpr int kNumberMaxDigits = 6;
// The glyph-bank base part ids that carry special per-column layout handling: the two score-column
// banks, the rating-column bank, and the three banks whose trailing '1' is micro-nudged.
constexpr unsigned int kScoreColumnPartA = 0x7c;
constexpr unsigned int kScoreColumnPartB = 0x92;
constexpr unsigned int kRatingColumnPart = 0xa8;
constexpr unsigned int kNudgeBankPlus4A = 0x44;
constexpr unsigned int kNudgeBankPlus4B = 0x4e;
// The dim factor applied to the padded leading zeros (@ghidraAddress 0x2fd008).
constexpr float kPadZeroDimFactor = 0.7f;

} // namespace

/** @ghidraAddress 0x12705c */
void LimelightResultLayer::RenderDigits(int nValue,
                                        const S_VECTOR2 &position,
                                        unsigned int nAlpha) {
    // Split the value into up to four decimal digits (least-significant first), tracking how many
    // are significant; at least one digit is always drawn.
    int aDigits[kMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant == 0) {
        nSignificant = 1;
    }

    // Centre the run about the position using the zero-glyph's width as the nominal advance.
    const float flAdvance = GetPartsData(kDigitZeroPart)->flWidth;
    float flX = position.x + static_cast<float>(static_cast<int>(nSignificant * flAdvance)) * 0.5f;
    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nPart = kDigitZeroPart + aDigits[i];
        const float flGlyphWidth = GetPartsData(nPart)->flWidth;
        const S_VECTOR2 drawPos{flX - flGlyphWidth, position.y};
        EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nPart, drawPos, nAlpha, 0);
        flX -= flGlyphWidth;
    }
}

/** @ghidraAddress 0x126b78 */
void LimelightResultLayer::EmitTexturedPart(unsigned long nSlot,
                                            const S_VECTOR2 &position,
                                            const S_VECTOR2 &size,
                                            unsigned int nAlpha) {
    if (nSlot >= kSpriteSlotCount || m_apSprites[nSlot] == nullptr) {
        return;
    }
    ne::C_TEXTURE *pTexture = m_apSprites[nSlot]->GetBoundTexture();
    if (pTexture == nullptr) {
        return;
    }
    // The whole used image mapped within its power-of-two allocation.
    const S_VECTOR2 uvSize{static_cast<float>(pTexture->GetImageWidth()) /
                               static_cast<float>(pTexture->GetAllocWidth()),
                           static_cast<float>(pTexture->GetImageHeight()) /
                               static_cast<float>(pTexture->GetAllocHeight())};
    AppendSpriteToSlot(position,
                       S_VECTOR2{0.0f, 0.0f},
                       size,
                       S_VECTOR2{0.0f, 0.0f},
                       uvSize,
                       0.0f,
                       S_VECTOR2{1.0f, 1.0f},
                       static_cast<unsigned int>(nSlot),
                       0xff,
                       nAlpha);
}

/** @ghidraAddress 0x126c34 */
void LimelightResultLayer::EmitAutoUvPart(unsigned long nSlot,
                                          const S_VECTOR2 &position,
                                          unsigned int nBaseAlpha) {
    if (nSlot >= kSpriteSlotCount || m_apSprites[nSlot] == nullptr) {
        return;
    }
    ne::C_TEXTURE *pTexture = m_apSprites[nSlot]->GetBoundTexture();
    if (pTexture == nullptr) {
        return;
    }
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flScale = pTexture->GetScale();
    // The pixel size is the used image over its scale; the UV rectangle is the used fraction of the
    // power-of-two allocation.
    const S_VECTOR2 size{flImageWidth / flScale, flImageHeight / flScale};
    const S_VECTOR2 uvSize{flImageWidth / static_cast<float>(pTexture->GetAllocWidth()),
                           flImageHeight / static_cast<float>(pTexture->GetAllocHeight())};
    const auto nAlpha = static_cast<unsigned int>(static_cast<float>(nBaseAlpha) * m_flBaseScale);
    AppendSpriteToSlot(position,
                       S_VECTOR2{0.0f, 0.0f},
                       size,
                       S_VECTOR2{0.0f, 0.0f},
                       uvSize,
                       0.0f,
                       S_VECTOR2{1.0f, 1.0f},
                       static_cast<unsigned int>(nSlot),
                       static_cast<unsigned int>(m_nDefaultAlpha),
                       nAlpha);
}

/** @ghidraAddress 0x126cf8 */
void LimelightResultLayer::RenderNumber(float flSpacing,
                                        int nValue,
                                        int nMaxDigits,
                                        const S_VECTOR2 &position,
                                        unsigned int nBasePartId,
                                        bool bPaired,
                                        bool bPadZeros,
                                        unsigned int nAlpha) {
    // Split the value into up to nMaxDigits decimal digits (least-significant first), tracking the
    // index of the most-significant non-zero digit.
    int aDigits[kNumberMaxDigits] = {};
    int nMostSignificant = 0;
    for (int i = 0; i < nMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nMostSignificant = i;
        }
        nValue /= 10;
    }
    // An all-zero value still shows one digit when the show-zero flag is set.
    if (nMostSignificant == 0 && bPaired) {
        nMostSignificant = 1;
    }

    S_VECTOR2 drawPos{position.x, position.y};
    float flY = position.y;
    for (int i = 0; i <= nMostSignificant; ++i) {
        const float flColumnX = drawPos.x;
        const int nDigit = aDigits[i];
        unsigned int nPartId = nDigit + nBasePartId;

        // The score columns comma-shift their first glyph and raise their second.
        if (nBasePartId == kScoreColumnPartB || nBasePartId == kScoreColumnPartA) {
            if (i == 0 && bPaired) {
                nPartId = nBasePartId + 0xb + nDigit;
            } else if (i == 1 && bPaired) {
                flY -= 4.0f;
                drawPos.y = flY;
            }
        }
        // The rating column's first glyph (when paired) uses the comma-shifted bank.
        const bool bFirstPaired = (i == 0) && bPaired;
        if (nBasePartId == kRatingColumnPart && bFirstPaired) {
            nPartId = nBasePartId + 0xb + nDigit;
        }

        const PartsDataRecord *pRecord = GetPartsData(nPartId);
        drawPos.x = flColumnX - pRecord->flWidth;
        // Micro-nudge a trailing '1' to keep decimal columns aligned across the glyph banks.
        if (i == nMaxDigits - 1 && nDigit == 1) {
            if (nBasePartId < kScoreColumnPartA) {
                if (nBasePartId == kNudgeBankPlus4A || nBasePartId == kNudgeBankPlus4B) {
                    drawPos.x += 4.0f;
                } else if (nBasePartId == kDigitZeroPart) {
                    drawPos.x += 2.0f;
                }
            } else if (nBasePartId == kScoreColumnPartA || nBasePartId == kScoreColumnPartB) {
                drawPos.x += 6.0f;
            } else if (nBasePartId == kRatingColumnPart) {
                drawPos.x += 4.0f;
            }
        }

        float flNextX = drawPos.x;
        EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nPartId, drawPos, nAlpha, 0);
        flNextX -= flSpacing;
        // A paired column draws a second glyph ten ids up from the base.
        if (bFirstPaired) {
            drawPos.x = flNextX;
            const PartsDataRecord *pPaired = GetPartsData(nBasePartId + 10);
            flNextX -= pPaired->flWidth;
            if (nBasePartId == kRatingColumnPart) {
                flY -= 2.0f;
                drawPos.y = flY;
            }
            drawPos.x = flNextX;
            EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nBasePartId + 10, drawPos, nAlpha, 0);
            flNextX -= flSpacing;
        }
        drawPos.x = flNextX;
    }

    // Pad the remaining leading positions with dimmed grey zeros.
    if (bPadZeros && nMostSignificant + 1 < nMaxDigits) {
        const auto nDimAlpha =
            static_cast<unsigned int>(static_cast<float>(nAlpha) * kPadZeroDimFactor);
        for (int nRemaining = (nMaxDigits - 1) - nMostSignificant; nRemaining != 0; --nRemaining) {
            const PartsDataRecord *pRecord = GetPartsData(nBasePartId);
            drawPos.x -= pRecord->flWidth;
            EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nBasePartId, drawPos, nDimAlpha, 0);
            drawPos.x -= flSpacing;
        }
    }
}

namespace {

// The part id of the decimal-point glyph inserted by RenderPercentValue.
constexpr unsigned int kPointPart = 0x73;
// The minimum number of digits RenderPercentValue draws (the ones digit plus one more).
constexpr int kPercentMinDigits = 2;

} // namespace

/** @ghidraAddress 0x1274b0 */
void LimelightResultLayer::RenderPercentValue(int nValue,
                                              const S_VECTOR2 &position,
                                              unsigned int nAlpha) {
    // Split into up to four digits, tracking the significant count; at least two digits are drawn.
    int aDigits[kMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant < kPercentMinDigits) {
        nSignificant = kPercentMinDigits;
    }

    float flX = position.x;
    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nPart = kDigitZeroPart + aDigits[i];
        const float flGlyphWidth = GetPartsData(nPart)->flWidth;
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       nPart,
                       S_VECTOR2{flX - flGlyphWidth, position.y},
                       nAlpha,
                       0);
        flX -= flGlyphWidth;
        // Insert the decimal point after the ones digit.
        if (i == 0) {
            const float flPointWidth = GetPartsData(kPointPart)->flWidth;
            EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kPartsSlot,
                           kPointPart,
                           S_VECTOR2{flX - flPointWidth, position.y},
                           nAlpha,
                           0);
            flX -= flPointWidth;
        }
    }
}

namespace {

// The part id of the slash glyph drawn between a fraction's denominator and numerator.
constexpr unsigned int kSlashPart = 0x74;

} // namespace

/** @ghidraAddress 0x1271f4 */
void LimelightResultLayer::RenderFraction(int nNumerator,
                                          int nDenominator,
                                          const S_VECTOR2 &position,
                                          unsigned int nAlpha) {
    // Split the numerator and denominator into up to four digits each, tracking their significant
    // counts (each at least one).
    int aNumerator[kMaxDigits] = {};
    int nNumeratorDigits = 0;
    for (int i = 0; i < kMaxDigits; ++i) {
        aNumerator[i] = nNumerator % 10;
        if (aNumerator[i] != 0) {
            nNumeratorDigits = i + 1;
        }
        nNumerator /= 10;
    }
    if (nNumeratorDigits == 0) {
        nNumeratorDigits = 1;
    }

    int aDenominator[kMaxDigits] = {};
    int nDenominatorDigits = 0;
    for (int i = 0; i < kMaxDigits; ++i) {
        aDenominator[i] = nDenominator % 10;
        if (aDenominator[i] != 0) {
            nDenominatorDigits = i + 1;
        }
        nDenominator /= 10;
    }
    if (nDenominatorDigits == 0) {
        nDenominatorDigits = 1;
    }

    // The digits and slash advance by the uniform zero-glyph width; the run is centred about the
    // position, with the slash and a one-pixel pad accounted for.
    const float flAdvance = GetPartsData(kDigitZeroPart)->flWidth;
    float flX = position.x + (static_cast<float>(static_cast<int>(nDenominatorDigits * flAdvance) +
                                                 static_cast<int>(nNumeratorDigits * flAdvance)) +
                              flAdvance + 2.0f) *
                                 0.5f;

    for (int i = 0; i < nDenominatorDigits; ++i) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       aDenominator[i] + kDigitZeroPart,
                       S_VECTOR2{flX - flAdvance, position.y},
                       nAlpha,
                       0);
        flX -= flAdvance;
    }

    flX -= flAdvance + 1.0f;
    EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, kSlashPart, S_VECTOR2{flX, position.y}, nAlpha, 0);
    flX -= 1.0f;

    for (int i = 0; i < nNumeratorDigits; ++i) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       aNumerator[i] + kDigitZeroPart,
                       S_VECTOR2{flX - flAdvance, position.y},
                       nAlpha,
                       0);
        flX -= flAdvance;
    }
}

namespace {

// The rating glyph bank's '0' part id, the rating decimal-point part id, and the per-glyph
// horizontal gap the rating value advances by beyond each glyph's width.
constexpr unsigned int kRatingDigitZeroPart = 0xf1;
constexpr unsigned int kRatingPointPart = 0xfb;
constexpr float kRatingGlyphGap = 4.0f;
// The number of digits the scaled rating value is split into, and the minimum drawn.
constexpr int kRatingDigits = 3;
constexpr int kRatingMinDigits = 2;
// The one-decimal scale applied to the rating value before it is split into digits.
constexpr float kRatingScale = 10.0f;

} // namespace

/** @ghidraAddress 0x127680 */
void LimelightResultLayer::RenderRatingValue(float flValue,
                                             const S_VECTOR2 &position,
                                             unsigned int nAlpha) {
    // Scale to one decimal place and split into up to three digits (least-significant first).
    int aDigits[kRatingDigits] = {};
    int nSignificant = 0;
    int nScaled = static_cast<int>(flValue * kRatingScale);
    for (int i = 0; i < kRatingDigits; ++i) {
        aDigits[i] = nScaled % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nScaled /= 10;
    }
    const int nDrawn = nSignificant > kRatingMinDigits ? nSignificant : kRatingMinDigits;

    float flX = position.x;
    int nDigit = 0;
    while (true) {
        // The fractional digit past the integer part is drawn at half alpha.
        if (nDigit == nDrawn) {
            nAlpha = static_cast<unsigned int>(static_cast<float>(nAlpha & 0xff) * 0.5f);
        }
        const int nValue = aDigits[nDigit];
        const PartsDataRecord *pRecord = GetPartsData(nValue + kRatingDigitZeroPart);
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       nValue + kRatingDigitZeroPart,
                       S_VECTOR2{flX - pRecord->flWidth, position.y - pRecord->flHeight},
                       nAlpha & 0xff,
                       0);
        flX -= pRecord->flWidth;
        if (nDigit == 0) {
            // Insert the decimal point after the ones digit, using its own advance and offset.
            const PartsDataRecord *pPoint = GetPartsData(kRatingPointPart);
            EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kPartsSlot,
                           kRatingPointPart,
                           S_VECTOR2{flX - pPoint->flWidth, position.y - pPoint->flHeight},
                           nAlpha & 0xff,
                           0);
            nDigit = 1;
        } else {
            ++nDigit;
            if (nDigit == kRatingDigits) {
                return;
            }
        }
        flX -= kRatingGlyphGap;
    }
}

namespace {

// The time threshold, in frame-delta units, past which the bonus voice cue fires.
constexpr float kBonusCueThreshold = 3300.0f;
// The themed voice identifier played for the result bonus cue.
constexpr int kBonusCueVoiceId = 7;

} // namespace

/** @ghidraAddress 0x1240a8 */
void LimelightResultLayer::UpdateBonusSoundCueTimer(float flDeltaTime) {
    if (!m_bBonusCueArmed) {
        return;
    }
    m_flBonusCueTimer += flDeltaTime;
    if (m_flBonusCueTimer > kBonusCueThreshold) {
        m_bBonusCueArmed = false;
        SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kBonusCueVoiceId);
    }
}

/** @ghidraAddress 0x123da4 */
void LimelightResultLayer::ResetThemeSelectState() {
    // Clear the five result-bonus display values (the binary bulk-zeroes the 0x150..0x164 span).
    m_flExperienceBonus = 0.0f;
    m_flClearBonus = 0.0f;
    m_flMissBonus = 0.0f;
    m_flRankBonus = 0.0f;
    m_flFirstPlayBonus = 0.0f;
    RefreshThema();
}

/** @ghidraAddress 0x123f60 */
void LimelightResultLayer::SetupOpenTweenPhone(float flBaseTime) {
    // Every channel eases from its current shown value up to one.
    constexpr float kShown = 1.0f;
    // The later channels' fixed durations and the elapsed-time stagger offsets that cascade them in
    // (the stagger constants are at @ghidraAddress 0x2eedcc = 300 and 0x307a38 = 900).
    constexpr float kDuration200 = 200.0f;
    constexpr float kDuration300 = 300.0f;
    constexpr float kStagger300 = 300.0f;
    constexpr float kStagger900 = 900.0f;

    // Channel 0: the base channel, its duration the caller's base time; snaps to shown when the base
    // time is non-positive.
    ResultBonusAnimChannel &ch0 = m_aBonusAnimChannels[0];
    ch0.flStart = ch0.flCurrent;
    ch0.flTarget = kShown;
    ch0.flDuration = flBaseTime;
    ch0.flElapsed = 0.0f;
    ch0.flReserved = 0.0f;
    if (flBaseTime <= 0.0f) {
        ch0.flCurrent = kShown;
    }

    // Channel 2: a 200-unit fade whose elapsed time starts at the base time.
    ResultBonusAnimChannel &ch2 = m_aBonusAnimChannels[2];
    ch2.flStart = ch2.flCurrent;
    ch2.flTarget = kShown;
    ch2.flDuration = kDuration200;
    ch2.flElapsed = flBaseTime;
    ch2.flReserved = 0.0f;

    // Channel 1: a 300-unit fade staggered 300 units after the base time.
    ResultBonusAnimChannel &ch1 = m_aBonusAnimChannels[1];
    ch1.flStart = ch1.flCurrent;
    ch1.flTarget = kShown;
    ch1.flDuration = kDuration300;
    ch1.flElapsed = flBaseTime + kStagger300;
    ch1.flReserved = 0.0f;

    // Channel 4: a 200-unit fade staggered 900 units after the base time.
    ResultBonusAnimChannel &ch4 = m_aBonusAnimChannels[4];
    ch4.flStart = ch4.flCurrent;
    ch4.flTarget = kShown;
    ch4.flDuration = kDuration200;
    ch4.flElapsed = flBaseTime + kStagger900;
    ch4.flReserved = 0.0f;

    // Channel 3: a 300-unit fade staggered 900 units after the base time.
    ResultBonusAnimChannel &ch3 = m_aBonusAnimChannels[3];
    ch3.flStart = ch3.flCurrent;
    ch3.flTarget = kShown;
    ch3.flDuration = kDuration300;
    ch3.flElapsed = flBaseTime + kStagger900;
    ch3.flReserved = 0.0f;
}

/** @ghidraAddress 0x124000 */
void LimelightResultLayer::ResetResultBonusAnimations(float flStartTime) {
    // Each channel eases from its current shown value toward zero over the start time; a non-positive
    // start time snaps the target to zero immediately.
    for (ResultBonusAnimChannel &channel : m_aBonusAnimChannels) {
        channel.flStart = channel.flCurrent;
        channel.flTarget = 0.0f;
        channel.flDuration = flStartTime;
        channel.flElapsed = 0.0f;
        channel.flReserved = 0.0f;
        if (flStartTime <= 0.0f) {
            channel.flCurrent = 0.0f;
        }
    }
    m_bBonusCueArmed = false;
}
