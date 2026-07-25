#include "result_window_classic_layer.h"

#include <cassert>

#include "classic_parts_data_table.h"
#import "deviceenvironment.h"
#import "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "polygon2d_trail.h"
#import "s_vector2.h"

// The process-wide Classic result-window layer, created lazily by shared().
static ResultWindowClassicLayer *g_pClassicResultLayer = nullptr; // @ghidraAddress 0x3dd2f8

// The Classic pad parts table (declared in classic_parts_data_table.h): zero-initialised here to
// match the binary's __common segment, filled at runtime.
PartsDataRecord g_aClassicPartsPad[kClassicPartsRecordBound] = {}; // @ghidraAddress 0x3d6650

// The Classic phone-layout position tables (declared in classic_parts_data_table.h):
// zero-initialised here to match the binary's __common segment, filled at runtime.
PhoneAnchorRecord g_aClassicPositionPhoneLandscape[kClassicPositionRecordCount] =
    {}; // @ghidraAddress 0x3d84c0
PhoneAnchorRecord g_aClassicPositionPhonePortrait[kClassicPositionRecordCount] =
    {}; // @ghidraAddress 0x3d80e8

// The Classic phone parts table (@ghidraAddress 0x303580): static read-only sprite descriptors, one
// per result-window part, giving each part's placement offset, size, and UV-palette index.
const PartsDataRecord g_aClassicPartsPhone[kClassicPhonePartsRecordCount] = {
    {1, 0.0f, 0.0f, 1024.0f, 1024.0f, 0}, {1, 0.0f, 0.0f, 57.0f, 20.0f, 1},
    {1, 0.0f, 0.0f, 9.0f, 9.0f, 2},       {1, 0.0f, 0.0f, 1.0f, 9.0f, 3},
    {1, 0.0f, 0.0f, 9.0f, 1.0f, 4},       {1, 0.0f, 0.0f, 1.0f, 1.0f, 5},
    {1, 0.0f, 0.0f, 9.0f, 9.0f, 6},       {1, 0.0f, 0.0f, 1.0f, 9.0f, 7},
    {1, 0.0f, 0.0f, 9.0f, 1.0f, 8},       {1, 0.0f, 0.0f, 1.0f, 1.0f, 9},
    {1, 0.0f, 0.0f, 15.0f, 17.0f, 10},    {1, 0.0f, 0.0f, 1.0f, 17.0f, 11},
    {1, 0.0f, 0.0f, 1.0f, 1.0f, 12},      {1, 0.0f, 0.0f, 1.0f, 1.0f, 13},
    {1, 0.0f, 0.0f, 48.0f, 8.0f, 14},     {1, 0.0f, 0.0f, 30.0f, 8.0f, 15},
    {1, 0.0f, 0.0f, 26.0f, 8.0f, 16},     {1, 0.0f, 0.0f, 164.0f, 8.0f, 17},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 18},      {1, 0.0f, 0.0f, 38.0f, 8.0f, 19},
    {1, 0.0f, 0.0f, 38.0f, 8.0f, 20},     {1, 0.0f, 0.0f, 38.0f, 8.0f, 21},
    {1, 0.0f, 0.0f, 38.0f, 8.0f, 22},     {1, 0.0f, 0.0f, 4.0f, 6.0f, 23},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 24},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 25},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 26},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 27},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 28},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 29},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 30},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 31},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 32},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 33},
    {1, 0.0f, 0.0f, 6.0f, 6.0f, 34},      {1, 0.0f, 0.0f, 6.0f, 6.0f, 35},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 36},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 37},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 38},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 39},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 40},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 41},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 42},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 43},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 44},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 45},
    {1, 13.0f, 12.0f, 26.0f, 24.0f, 46},  {1, 10.0f, 12.0f, 20.0f, 24.0f, 47},
    {1, 13.0f, 12.0f, 26.0f, 24.0f, 48},  {1, 20.0f, 12.0f, 40.0f, 24.0f, 49},
    {1, 20.0f, 12.0f, 40.0f, 24.0f, 50},  {1, 20.0f, 12.0f, 40.0f, 24.0f, 51},
    {1, 0.0f, 0.0f, 50.0f, 6.0f, 52},     {1, 0.0f, 0.0f, 26.0f, 10.0f, 53},
    {1, 0.0f, 0.0f, 26.0f, 10.0f, 54},    {1, 0.0f, 0.0f, 33.0f, 10.0f, 55},
    {1, 0.0f, 0.0f, 33.0f, 10.0f, 56},    {1, 0.0f, 0.0f, 6.0f, 8.0f, 57},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 58},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 59},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 60},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 61},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 62},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 63},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 64},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 65},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 66},      {1, 0.0f, 0.0f, 2.0f, 8.0f, 67},
    {1, 0.0f, 0.0f, 4.0f, 8.0f, 68},      {1, 0.0f, 0.0f, 8.0f, 8.0f, 69},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 70},      {1, 13.0f, 4.0f, 26.0f, 8.0f, 71},
    {1, 13.0f, 4.0f, 26.0f, 8.0f, 72},    {1, 13.0f, 4.0f, 26.0f, 8.0f, 73},
    {1, 13.0f, 4.0f, 26.0f, 8.0f, 74},    {1, 18.0f, 4.0f, 36.0f, 8.0f, 75},
    {1, 18.0f, 4.0f, 36.0f, 8.0f, 76},    {1, 13.0f, 4.0f, 26.0f, 8.0f, 77},
    {1, 30.0f, 4.0f, 60.0f, 8.0f, 78},    {1, 30.0f, 4.0f, 60.0f, 8.0f, 79},
    {1, 30.0f, 4.0f, 60.0f, 8.0f, 80},    {1, 30.0f, 4.0f, 60.0f, 8.0f, 81},
    {1, 33.0f, 4.0f, 66.0f, 8.0f, 82},    {1, 18.0f, 4.0f, 36.0f, 8.0f, 83},
    {1, 46.0f, 4.0f, 92.0f, 8.0f, 84},    {1, 0.0f, 0.0f, 8.0f, 10.0f, 85},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 86},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 87},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 88},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 89},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 90},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 91},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 92},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 93},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 94},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 95},
    {1, 0.0f, 0.0f, 5.0f, 10.0f, 96},     {1, 0.0f, 0.0f, 114.0f, 10.0f, 97},
    {1, 0.0f, 0.0f, 1.0f, 8.0f, 98},      {1, 0.0f, 0.0f, 8.0f, 11.0f, 99},
    {1, 0.0f, 0.0f, 62.0f, 62.0f, 100},   {1, 3.0f, 3.0f, 6.0f, 6.0f, 101},
    {1, 0.0f, 0.0f, 66.0f, 8.0f, 102},    {1, 0.0f, 0.0f, 76.0f, 8.0f, 103},
    {1, 0.0f, 0.0f, 32.0f, 7.0f, 104},    {1, 0.0f, 0.0f, 86.0f, 12.0f, 105},
    {1, 0.0f, 0.0f, 170.0f, 20.0f, 106},  {1, 0.0f, 0.0f, 150.0f, 26.0f, 107},
    {1, 0.0f, 0.0f, 123.0f, 26.0f, 108},  {1, 0.0f, 0.0f, 150.0f, 26.0f, 109},
    {1, 0.0f, 0.0f, 1.0f, 28.0f, 110},    {1, 0.0f, 0.0f, 22.0f, 28.0f, 111},
    {1, 0.0f, 0.0f, 1.0f, 28.0f, 112},    {1, 0.0f, 0.0f, 24.0f, 50.0f, 113},
    {1, 0.0f, 0.0f, 1.0f, 50.0f, 114},    {1, 58.0f, 9.0f, 116.0f, 18.0f, 115},
    {1, 0.0f, 0.0f, 72.0f, 24.0f, 116},   {1, 0.0f, 0.0f, 70.0f, 24.0f, 117},
    {1, 0.0f, 0.0f, 94.0f, 24.0f, 118},   {1, 51.0f, 6.0f, 102.0f, 12.0f, 119},
    {1, 56.0f, 6.0f, 112.0f, 12.0f, 120}, {1, 22.0f, 5.0f, 44.0f, 10.0f, 121},
    {1, 51.0f, 5.0f, 102.0f, 10.0f, 122}, {1, 51.0f, 5.0f, 102.0f, 10.0f, 123},
    {1, 22.0f, 5.0f, 44.0f, 10.0f, 124},  {1, 51.0f, 5.0f, 102.0f, 10.0f, 125},
};

/** @ghidraAddress 0x1151fc */
ResultWindowClassicLayer *ResultWindowClassicLayer::shared() {
    if (g_pClassicResultLayer == nullptr) {
        // The binary allocates the raw 0x1c0-byte object and runs the colour-marker constructor
        // (0x115094), which seeds the transform vectors and four colour sub-objects; that
        // constructor's field initialisation is not yet reconstructed, so only the base is set up
        // here.
        g_pClassicResultLayer = new ResultWindowClassicLayer();
    }
    return g_pClassicResultLayer;
}

/** @ghidraAddress 0x114b78 */
const PartsDataRecord *ResultWindowClassicLayer::getPartsData(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kClassicPartsRecordBound);

    // The pad build reads the runtime-filled pad table; the phone build reads the static table.
    return IsPad() ? &g_aClassicPartsPad[nIndex] : &g_aClassicPartsPhone[nIndex];
}

/** @ghidraAddress 0x114c10 */
const PartsDataRecord *ResultWindowClassicLayer::getPartsData_Phone(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kClassicPhonePartsRecordCount);

    // This accessor always reads the static phone parts table.
    return &g_aClassicPartsPhone[nIndex];
}

namespace {

// The texture-name table entries the result window loads (@ghidraAddress 0x3cea80 and 0x3ceab0).
constexpr const char *kBackgroundTextureName = "00_texture/sel_bg";
constexpr const char *kPartsTextureName = "00_texture/result_parts";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x304170). Slot 1 (the parts atlas) holds
// the most sprites; the rest are small fixed banks.
constexpr unsigned int kSlotCapacities[] = {1, 400, 1, 1, 1, 2, 2, 0};

// The per-slot texture-field selector (@ghidraAddress 0x304150): the index (0 = background, 1 =
// parts) into the layer's two texture fields for each slot that binds a texture. A slot binds a
// texture only when it is one of the first two or the last (the middle slots share the atlas already
// bound by the batch they mirror).
constexpr int kSlotTextureField[] = {0, 1, 3, 3, 3, 3, 3, 0};

// The default sprite alpha and scale the builder seeds before creating the batches.
constexpr unsigned int kDefaultAlpha = 0xff;
constexpr float kDefaultScale = 1.0f;

// The slot range whose members do not bind a texture: slots kFirstUntexturedSlot through
// kFirstUntexturedSlot + kUntexturedSlotSpan - 1 (that is, slots 2 through 6).
constexpr int kFirstUntexturedSlot = 2;
constexpr int kUntexturedSlotSpan = 5;

} // namespace

namespace {

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

// The part-id upper bound the sprite dispatcher ignores at or above.
constexpr unsigned int kPartIdBound = 0xf0;
// The sprite colour intensities for the main pass and the half-intensity shadow pass.
constexpr unsigned int kIntensityFull = 0xff;
constexpr unsigned int kIntensityShadow = 0x80;

// The glyph banks that carry special digit-sequence layout: the two score-column banks and the
// rating-column bank (which draw a paired glyph and shift the first glyph), plus the banks whose
// trailing '1' is kerned.
constexpr unsigned int kScoreColumnBankA = 0x85;
constexpr unsigned int kScoreColumnBankB = 0x9b;
constexpr unsigned int kRatingColumnBank = 0xb1;
constexpr unsigned int kKernBankPlus4A = 0x4d;
constexpr unsigned int kKernBankPlus4B = 0x57;
constexpr unsigned int kKernBankPlus2 = 0x72;
// The maximum number of digits RenderDigitSequence splits a value into.
constexpr int kMaxDigitCount = 6;

// The digit glyph bank RenderScoreDigitsCompact draws from, and the maximum digits it shows.
constexpr unsigned int kCompactDigitBank = 0x72;
constexpr int kCompactMaxDigits = 4;

// The character-code upper bound the glyph dispatcher ignores at or above.
constexpr unsigned int kCharCodeBound = 0x7e;

} // namespace

/** @ghidraAddress 0x114c80 */
void ResultWindowClassicLayer::getPosition_Phone(int nIndex, S_VECTOR2 *pOutPosition) const {
    assert(nIndex >= 0 && nIndex < kClassicPositionRecordCount);

    // The orientation flag selects the portrait table; otherwise the landscape table is used.
    const PhoneAnchorRecord &record = m_bPortrait ? g_aClassicPositionPhonePortrait[nIndex] :
                                                    g_aClassicPositionPhoneLandscape[nIndex];
    pOutPosition->x = record.flX;
    pOutPosition->y = record.flY;

    // Offset the base coordinate by half or full viewport dimensions per the record's anchor mode.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flWidth = pGameSystem->GetViewportWidth();
    const float flHeight = pGameSystem->GetViewportHeight();
    switch (record.nAnchorMode) {
    case kAnchorHalfHeight:
        pOutPosition->y += flHeight * 0.5f;
        break;
    case kAnchorFullHeight:
        pOutPosition->y += flHeight;
        break;
    case kAnchorHalfWidth:
        pOutPosition->x += flWidth * 0.5f;
        break;
    case kAnchorHalfWidthHalfHeight:
        pOutPosition->x += flWidth * 0.5f;
        pOutPosition->y += flHeight * 0.5f;
        break;
    case kAnchorHalfWidthFullHeight:
        pOutPosition->x += flWidth * 0.5f;
        pOutPosition->y += flHeight;
        break;
    case kAnchorFullWidth:
        pOutPosition->x += flWidth;
        break;
    case kAnchorFullWidthHalfHeight:
        pOutPosition->x += flWidth;
        pOutPosition->y += flHeight * 0.5f;
        break;
    case kAnchorFullWidthFullHeight:
        pOutPosition->x += flWidth;
        pOutPosition->y += flHeight;
        break;
    default:
        break;
    }
}

/** @ghidraAddress 0x116808 */
void ResultWindowClassicLayer::AppendSpriteToSlot(const S_VECTOR2 &position,
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
    ne::C_SPRITE_INSTANCING *pInstancer = m_apSprites[nSlot];
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

/** @ghidraAddress 0x115864 */
void ResultWindowClassicLayer::EmitPartSprite(float flRotation,
                                              float flScaleX,
                                              float flScaleY,
                                              unsigned int nSlot,
                                              unsigned int nPartId,
                                              const S_VECTOR2 &position,
                                              unsigned int nAlpha,
                                              int bShadowPass) {
    if (nPartId >= kPartIdBound) {
        return;
    }
    const PartsDataRecord *pRecord = getPartsData(static_cast<int>(nPartId));
    const UvPaletteEntry &palette = g_aClassicUvPalette[pRecord->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass != 0 ? kIntensityShadow : kIntensityFull;
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

/** @ghidraAddress 0x115514 */
void ResultWindowClassicLayer::RenderDigitSequence(int nValue,
                                                   int nDigitCount,
                                                   const S_VECTOR2 *pOrigin,
                                                   unsigned int nGlyphBase,
                                                   unsigned int bLeadingZero,
                                                   int bPadRight,
                                                   unsigned int nAlpha,
                                                   float flSpacing) {
    // The glyphs draw into the parts slot at unit scale.
    constexpr unsigned int kGlyphSlot = 1;

    // Split the value into decimal digits (least-significant first), tracking the most-significant
    // non-zero digit.
    int aDigits[kMaxDigitCount] = {};
    int nMostSignificant = 0;
    for (int i = 0; i < nDigitCount; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nMostSignificant = i;
        }
        nValue /= 10;
    }
    // An all-zero value still shows one digit when the leading-zero flag is set.
    if (nMostSignificant == 0 && (bLeadingZero & 1) != 0) {
        nMostSignificant = 1;
    }

    S_VECTOR2 drawPos{pOrigin->x, pOrigin->y};
    float flY = pOrigin->y;
    for (int i = 0; i <= nMostSignificant; ++i) {
        const int nDigit = aDigits[i];
        unsigned int nPartId = nDigit + nGlyphBase;

        // The score columns comma-shift their first glyph and raise their second.
        if (nGlyphBase == kScoreColumnBankB || nGlyphBase == kScoreColumnBankA) {
            if (i == 0 && bLeadingZero != 0) {
                nPartId = nGlyphBase + 0xb + nDigit;
            } else if (i == 1 && bLeadingZero != 0) {
                flY -= 4.0f;
                drawPos.y = flY;
            }
        }
        const bool bFirstPaired = (i == 0) && (bLeadingZero != 0);
        if (nGlyphBase == kRatingColumnBank && bFirstPaired) {
            nPartId = nGlyphBase + 0xb + nDigit;
        }

        const PartsDataRecord *pRecord = getPartsData(static_cast<int>(nPartId));
        drawPos.x -= pRecord->flWidth;
        // Micro-nudge a trailing '1' to keep decimal columns aligned across the glyph banks.
        if (i == nDigitCount - 1 && nDigit == 1) {
            if (nGlyphBase < kScoreColumnBankA) {
                if (nGlyphBase == kKernBankPlus4A || nGlyphBase == kKernBankPlus4B) {
                    drawPos.x += 4.0f;
                } else if (nGlyphBase == kKernBankPlus2) {
                    drawPos.x += 2.0f;
                }
            } else if (nGlyphBase == kScoreColumnBankA || nGlyphBase == kScoreColumnBankB) {
                drawPos.x += 6.0f;
            } else if (nGlyphBase == kRatingColumnBank) {
                drawPos.x += 4.0f;
            }
        }

        EmitPartSprite(0.0f, 1.0f, 1.0f, kGlyphSlot, nPartId, drawPos, nAlpha, 0);
        drawPos.x -= flSpacing;
        // A paired column draws a second glyph ten ids up from the base.
        if (bFirstPaired) {
            const PartsDataRecord *pPaired = getPartsData(static_cast<int>(nGlyphBase + 10));
            drawPos.x -= pPaired->flWidth;
            if (nGlyphBase == kRatingColumnBank) {
                flY -= 2.0f;
                drawPos.y = flY;
            }
            EmitPartSprite(0.0f, 1.0f, 1.0f, kGlyphSlot, nGlyphBase + 10, drawPos, nAlpha, 0);
            drawPos.x -= flSpacing;
        }
    }

    // Pad the remaining leading positions with dimmed zeros.
    if (bPadRight != 0 && nMostSignificant + 1 < nDigitCount) {
        for (int nRemaining = (nDigitCount - 1) - nMostSignificant; nRemaining != 0; --nRemaining) {
            const PartsDataRecord *pRecord = getPartsData(static_cast<int>(nGlyphBase));
            drawPos.x -= pRecord->flWidth;
            EmitPartSprite(0.0f, 1.0f, 1.0f, kGlyphSlot, nGlyphBase, drawPos, nAlpha, 1);
            drawPos.x -= flSpacing;
        }
    }
}

/** @ghidraAddress 0x1161cc */
void ResultWindowClassicLayer::DispatchGlyphSpriteFromTable(unsigned int nSlot,
                                                            unsigned int nCharCode,
                                                            const S_VECTOR2 *pPosition,
                                                            unsigned int nAlpha,
                                                            int bDimmed,
                                                            float flRotation,
                                                            float flScaleX,
                                                            float flScaleY) {
    if (nCharCode >= kCharCodeBound) {
        return;
    }
    // The glyph metrics come from the parts table indexed by the character code; the texture
    // rectangle from the glyph UV palette.
    const PartsDataRecord *pGlyph = &g_aClassicPartsPhone[nCharCode];
    const UvPaletteEntry &palette = g_aClassicGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bDimmed != 0 ? kIntensityShadow : kIntensityFull;
    AppendSpriteToSlot(*pPosition,
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

/** @ghidraAddress 0x115928 */
void ResultWindowClassicLayer::RenderScoreDigitsCompact(int nValue,
                                                        const S_VECTOR2 &position,
                                                        unsigned int nAlpha) {
    constexpr unsigned int kGlyphSlot = 1;

    // Split the value into up to four digits, tracking the significant count (at least one).
    int aDigits[kCompactMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kCompactMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant == 0) {
        nSignificant = 1;
    }

    // Centre the run about the position using the zero glyph's width as the nominal advance.
    const float flAdvance = getPartsData(static_cast<int>(kCompactDigitBank))->flWidth;
    float flX = position.x + static_cast<float>(static_cast<int>(nSignificant * flAdvance)) * 0.5f;
    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nPart = aDigits[i] + kCompactDigitBank;
        const float flGlyphWidth = getPartsData(static_cast<int>(nPart))->flWidth;
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kGlyphSlot,
                       nPart,
                       S_VECTOR2{flX - flGlyphWidth, position.y},
                       nAlpha,
                       0);
        flX -= flGlyphWidth;
    }
}

/** @ghidraAddress 0x11524c */
void ResultWindowClassicLayer::InitSpriteSetsLazy() {
    if (m_bSpritesBuilt) {
        return;
    }

    m_nDefaultAlpha = kDefaultAlpha;
    m_flDefaultScale = kDefaultScale;

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pBackgroundTexture, m_pPartsTexture};

    // Build one sprite instancer per slot, register it in the global scene tree, make it visible,
    // and clear its sprite count. The two edge slots bind a texture per the selector; the middle
    // slots (2 through 6) share the atlas of the batch they mirror, so they bind none here. During
    // the first slot's setup, initialise the four ribbon trails.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot] = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        m_apSprites[nSlot]->RegisterGlobal();
        m_apSprites[nSlot]->SetVisible(true);
        if (static_cast<unsigned int>(nSlot - kFirstUntexturedSlot) >= kUntexturedSlotSpan) {
            m_apSprites[nSlot]->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        }
        m_apSprites[nSlot]->SetSpriteCount(0);
        if (nSlot == 0) {
            for (int nTrail = 0; nTrail < kTrailCount; ++nTrail) {
                m_apTrails[nTrail]->Init();
            }
        }
    }

    m_bSpritesBuilt = true;
}
