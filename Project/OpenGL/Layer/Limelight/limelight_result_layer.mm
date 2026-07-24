#include "limelight_result_layer.h"

#include <cassert>

#include "deviceenvironment.h"
#include "limelight_parts_data_table.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "parts_data_table.h"
#include "s_vector2.h"

// The process-wide Limelight result-window layer, created lazily by shared().
static LimelightResultLayer *g_pLimelightResultLayer = nullptr; // @ghidraAddress 0x3de008

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

// The slot range whose members do not bind a texture: slots kFirstUntexturedSlot through
// kFirstUntexturedSlot + kUntexturedSlotSpan - 1 (that is, slots 2 through 6).
constexpr int kFirstUntexturedSlot = 2;
constexpr int kUntexturedSlotSpan = 5;

} // namespace

/** @ghidraAddress 0x123d54 */
LimelightResultLayer *LimelightResultLayer::shared() {
    if (g_pLimelightResultLayer == nullptr) {
        // The binary allocates the raw 0x170-byte object and runs its initialiser, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pLimelightResultLayer = new LimelightResultLayer();
    }
    return g_pLimelightResultLayer;
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

/** @ghidraAddress 0x123838 */
PartsDataRecord *LimelightResultLayer::GetPartsData(unsigned int nIndex) const {
    assert(static_cast<int>(nIndex) >= 0 && nIndex < kLimelightPartsRecordBound);

    // The pad build uses the pad table; the phone build uses the phone table.
    return IsPad() ? &g_aLimelightPartsPad[nIndex] : &g_aLimelightPartsPhone[nIndex];
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

/** @ghidraAddress 0x126ab4 */
void LimelightResultLayer::EmitPartSprite(float flRotation,
                                          float flScaleX,
                                          float flScaleY,
                                          unsigned int nSlot,
                                          unsigned int nPartId,
                                          const S_VECTOR2 &position,
                                          unsigned int nAlpha,
                                          int bShadowPass) {
    // Part id 0xff is the "no part" sentinel used to skip optional parts.
    if (nPartId >= 0xff) {
        return;
    }
    const PartsDataRecord *pRecord = GetPartsData(nPartId);
    const UvPaletteEntry &palette = g_aUvPalette[pRecord->nUvPaletteIndex];
    // The main pass draws at full intensity; the shadow pass darkens the quad to half intensity.
    const unsigned int nIntensity = bShadowPass != 0 ? 0x80 : 0xff;
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
                                        unsigned int bPaired,
                                        int bPadZeros,
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
    if (nMostSignificant == 0 && (bPaired & 1) != 0) {
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
            if (i == 0 && bPaired != 0) {
                nPartId = nBasePartId + 0xb + nDigit;
            } else if (i == 1 && bPaired != 0) {
                flY -= 4.0f;
                drawPos.y = flY;
            }
        }
        // The rating column's first glyph (when paired) uses the comma-shifted bank.
        const bool bFirstPaired = (i == 0) && (bPaired != 0);
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
    if (bPadZeros != 0 && nMostSignificant + 1 < nMaxDigits) {
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
