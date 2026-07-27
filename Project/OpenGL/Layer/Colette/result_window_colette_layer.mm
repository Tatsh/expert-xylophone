#include "result_window_colette_layer.h"

#include <cassert>

#include "../Classic/classic_parts_data_table.h"
#include "../Limelight/limelight_parts_data_table.h"
#import "deviceenvironment.h"
#import "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "parts_data_table.h"
#include "phone_anchor_table.h"
#import "s_vector2.h"
#include "soundeffectmanager.h"

// The process-wide Colette result-window layer, created lazily by shared().
static ResultWindowColetteLayer *g_pColetteResultLayer = nullptr; // @ghidraAddress 0x3dc598

// The phone-layout anchor-position tables (declared in phone_anchor_table.h): zero-initialised here
// to match the binary's __common segment, filled at runtime by the result-layout-table initialisers.
PhoneAnchorRecord g_aPhoneAnchorPortrait[kPhoneAnchorRecordCount] = {}; // @ghidraAddress 0x3d4d50
PhoneAnchorRecord g_aPhoneAnchorDefault[kPhoneAnchorRecordCount] = {};  // @ghidraAddress 0x3d5530

// The Colette parts tables (declared in parts_data_table.h): zero-initialised here to match the
// binary's __common segment, filled at runtime.
PartsDataRecord g_aColettePartsPad[kColettePartsRecordCount] = {};        // @ghidraAddress 0x3d0010
PartsDataRecord g_aColettePartsPhone[kColettePhonePartsRecordCount] = {}; // @ghidraAddress 0x3d20b0

// The Colette part UV-palette table the part-sprite emitters index by a parts record's UV-palette
// index; distinct from the glyph palette below. Read-only ROM data in the binary; its length is not
// referenced by the code.
extern const UvPaletteEntry g_aColettePartUvPalette[]; // @ghidraAddress 0x2f39d8

// The single Colette phone-layout centre-position records (16-byte PhoneLayoutRect, no anchor mode):
// the state record, and the portrait and default records (selected by the is-pad flag and
// orientation flags). Zero-initialised in the binary's __common segment and filled at runtime.
PhoneLayoutRect g_ColetteCenterPositionPhoneState = {};    // @ghidraAddress 0x3d6620
PhoneLayoutRect g_ColetteCenterPositionPhonePortrait = {}; // @ghidraAddress 0x3d6630
PhoneLayoutRect g_ColetteCenterPositionPhoneDefault = {};  // @ghidraAddress 0x3d6640

// The Colette glyph UV-palette table the dimmable-glyph emitter indexes by a parts record's
// UV-palette index; distinct from the shared Limelight palette (@c g_aUvPalette). Read-only ROM data
// in the binary; its length is not referenced by the code.
extern const UvPaletteEntry g_aColetteGlyphUvPalette[]; // @ghidraAddress 0x2f5e88

namespace {

// The texture-name table entries the result window loads (@ghidraAddress 0x3cea80 and 0x3ceab0).
constexpr const char *kBackgroundTextureName = "00_texture/sel_bg";
constexpr const char *kPartsTextureName = "00_texture/result_parts";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x2fe874). Slot 1 (the parts atlas) holds
// the most sprites; the rest are small fixed banks.
constexpr unsigned int kSlotCapacities[] = {1, 500, 1, 1, 1, 2, 2, 1};

// The slot that draws the result-parts atlas, and the slot that draws the overlay texture. The
// per-slot source table (@ghidraAddress 0x2fe854) selects the layer texture field for each: slot 1
// binds the parts atlas (+0x18) and slot 7 binds the overlay (+0x20).
constexpr int kPartsSlot = 1;
constexpr int kOverlaySlot = 7;

// The sprite colour intensities for the main pass and the half-intensity dimmed pass.
constexpr unsigned int kIntensityFull = 0xff;
constexpr unsigned int kIntensityDimmed = 0x80;

// The bonus voice-cue delay threshold, in milliseconds (@ghidraAddress 0x2fcffc), and the themed
// voice id the cue plays.
constexpr float kBonusCueThreshold = 3956.0f;
constexpr int kBonusCueVoiceId = 7;

// The fixed glyph-table base indices and parts scale the builder stamps into the layer.
constexpr int kGlyphBaseA = 0x4e;
constexpr int kGlyphBaseB = 0x45;
constexpr int kGlyphBaseC = 0x3a;
constexpr float kPartsScale = 1.0f;

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

} // namespace

/** @ghidraAddress 0x73edc */
ResultWindowColetteLayer *ResultWindowColetteLayer::shared() {
    if (g_pColetteResultLayer == nullptr) {
        // The binary allocates the raw 0x180-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the layer's state.
        g_pColetteResultLayer = new ResultWindowColetteLayer();
    }
    return g_pColetteResultLayer;
}

/** @ghidraAddress 0x73f2c */
void ResultWindowColetteLayer::InitializeResultWindowSprites() {
    if (m_bBuilt) {
        return;
    }

    m_nGlyphBaseA = kGlyphBaseA;
    m_nGlyphBaseB = kGlyphBaseB;
    m_nGlyphBaseC = kGlyphBaseC;
    m_flPartsScale = kPartsScale;

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    // Build one sprite instancer per slot, register it in the global scene tree, make it visible,
    // and reset its sprite count. The parts slot binds the parts atlas and the overlay slot binds
    // the overlay texture (which the builder leaves unset, so it binds null here).
    for (int nSlot = 0; nSlot < kSlotCount; ++nSlot) {
        m_apSlots[nSlot] = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        m_apSlots[nSlot]->RegisterGlobal();
        m_apSlots[nSlot]->SetVisible(true);
        if (nSlot == kOverlaySlot) {
            m_apSlots[nSlot]->SetRefCountedMember(m_pOverlayTexture);
        } else if (nSlot == kPartsSlot) {
            m_apSlots[nSlot]->SetRefCountedMember(m_pPartsTexture);
        }
        m_apSlots[nSlot]->SetSpriteCount(0);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x73b4c */
void ResultWindowColetteLayer::getPosition_Phone(int nIndex, S_VECTOR2 *pOutPosition) const {
    assert(nIndex >= 0 && nIndex < kPhoneAnchorRecordCount);

    // The portrait flag selects the portrait table; otherwise the default table is used.
    const PhoneAnchorRecord &record =
        m_bPortrait ? g_aPhoneAnchorPortrait[nIndex] : g_aPhoneAnchorDefault[nIndex];
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

/** @ghidraAddress 0x73a44 */
PartsDataRecord *ResultWindowColetteLayer::getPartsData(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kColettePartsRecordCount);

    // The pad build uses the pad table; the phone build uses the phone table.
    return IsPad() ? &g_aColettePartsPad[nIndex] : &g_aColettePartsPhone[nIndex];
}

/** @ghidraAddress 0x73adc */
PartsDataRecord *ResultWindowColetteLayer::getPartsData_Phone(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kColettePhonePartsRecordCount);

    // This accessor always reads the phone parts table.
    return &g_aColettePartsPhone[nIndex];
}

/** @ghidraAddress 0x73e50 */
void ResultWindowColetteLayer::getCenterPosition_Phone(PhoneLayoutRect *pOutRect) const {
    // When the state flag is set the state record is copied verbatim, with no viewport anchoring.
    if (IsPad()) {
        *pOutRect = g_ColetteCenterPositionPhoneState;
        (void)GameSystem::
            GetGameSystem(); // The binary tail-calls the singleton getter and discards it.
        return;
    }

    // Otherwise the orientation flag selects the portrait or default record, and the leading
    // coordinate is shifted by half the viewport width and height.
    const PhoneLayoutRect &record =
        m_bPortrait ? g_ColetteCenterPositionPhonePortrait : g_ColetteCenterPositionPhoneDefault;
    *pOutRect = record;

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    pOutRect->flX += pGameSystem->GetViewportWidth() * 0.5f;
    pOutRect->flY += pGameSystem->GetViewportHeight() * 0.5f;
}

/** @ghidraAddress 0x74238 */
void ResultWindowColetteLayer::UpdateBonusSoundCueTimer(float flDeltaTime) {
    if (!m_bBonusCueArmed) {
        return;
    }
    m_flBonusCueTimer += flDeltaTime;
    if (m_flBonusCueTimer > kBonusCueThreshold) {
        m_bBonusCueArmed = false;
        SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kBonusCueVoiceId);
    }
}

/** @ghidraAddress 0x76b5c */
void ResultWindowColetteLayer::renderSpriteInstanceFromSlot(int nSlot,
                                                            const S_VECTOR2 &position,
                                                            const S_VECTOR2 &extent,
                                                            unsigned int nAlpha) {
    if (nSlot < 0 || nSlot >= kSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSlots[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
    if (pTexture == nullptr) {
        return;
    }

    // Map the whole used image within its power-of-two allocation.
    const S_VECTOR2 uvSize{static_cast<float>(pTexture->GetImageWidth()) /
                               static_cast<float>(pTexture->GetAllocWidth()),
                           static_cast<float>(pTexture->GetImageHeight()) /
                               static_cast<float>(pTexture->GetAllocHeight())};
    const S_VECTOR2 anchor{extent.x * 0.5f, extent.y * 0.5f};
    appendSpriteToSlot(nSlot,
                       position,
                       anchor,
                       extent,
                       S_VECTOR2{0.0f, 0.0f},
                       uvSize,
                       0.0f,
                       S_VECTOR2{1.0f, 1.0f},
                       0xff,
                       nAlpha);
}

/** @ghidraAddress 0x7ac58 */
void ResultWindowColetteLayer::appendSpriteToSlot(int nSlot,
                                                  const S_VECTOR2 &position,
                                                  const S_VECTOR2 &anchor,
                                                  const S_VECTOR2 &size,
                                                  const S_VECTOR2 &uvOrigin,
                                                  const S_VECTOR2 &uvSize,
                                                  float flRotation,
                                                  const S_VECTOR2 &scale,
                                                  unsigned int nIntensity,
                                                  unsigned int nAlpha) {
    if (nSlot < 0 || nSlot >= kSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSlots[nSlot];
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

/** @ghidraAddress 0x7ada0 */
void ResultWindowColetteLayer::appendSpriteToSlotRgba(int nSlot,
                                                      unsigned int nRed,
                                                      unsigned int nGreen,
                                                      unsigned int nBlue,
                                                      unsigned int nAlpha,
                                                      const S_VECTOR2 &position,
                                                      const S_VECTOR2 &anchor,
                                                      const S_VECTOR2 &size,
                                                      const S_VECTOR2 &uvOrigin,
                                                      const S_VECTOR2 &uvSize,
                                                      float flRotation,
                                                      const S_VECTOR2 &scale) {
    if (nSlot < 0 || nSlot >= kSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSlots[nSlot];
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
    pInstancer->SetSpriteColor(nSprite, nRed, nGreen, nBlue, nAlpha);
    pInstancer->SetSpriteCount(nSprite + 1);
}

/** @ghidraAddress 0x74018 */
void ResultWindowColetteLayer::applySpriteInstancerTexture(int nSlot, ne::C_TEXTURE *pTexture) {
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSlots[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    const int nCapacity = static_cast<int>(pInstancer->GetCapacity());
    pInstancer->SetRefCountedMember(pTexture);
    if (pTexture == nullptr) {
        return;
    }

    // Refresh every sprite slot to the newly bound texture's dimensions.
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flTextureScale = pTexture->GetScale();
    const S_VECTOR2 spriteSize{flImageWidth / flTextureScale, flImageHeight / flTextureScale};
    const S_VECTOR2 uvSize{flImageWidth / static_cast<float>(pTexture->GetAllocWidth()),
                           flImageHeight / static_cast<float>(pTexture->GetAllocHeight())};
    for (int nSprite = 0; nSprite < nCapacity; ++nSprite) {
        pInstancer->SetSpriteSize(nSprite, spriteSize);
        pInstancer->SetSpriteUvOrigin(nSprite, S_VECTOR2{});
        pInstancer->SetSpriteUvSize(nSprite, uvSize);
    }
}

/** @ghidraAddress 0x79e7c */
void ResultWindowColetteLayer::blitSpriteInstanceHalfScale(int nSlot,
                                                           const S_VECTOR2 &position,
                                                           unsigned int nScale) {
    if (nSlot < 0 || nSlot >= kSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSlots[nSlot];
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
        static_cast<unsigned int>(static_cast<float>(nScale) * m_flPartsScale);
    const unsigned int nRed = static_cast<unsigned int>(m_nGlyphBaseA) & 0xff;
    const unsigned int nGreen = static_cast<unsigned int>(m_nGlyphBaseB) & 0xff;
    const unsigned int nBlue = static_cast<unsigned int>(m_nGlyphBaseC) & 0xff;
    appendSpriteToSlotRgba(nSlot,
                           nRed,
                           nGreen,
                           nBlue,
                           nAlpha,
                           position,
                           anchor,
                           spriteSize,
                           S_VECTOR2{},
                           uvSize,
                           0.0f,
                           S_VECTOR2{1.0f, 1.0f});
}

/** @ghidraAddress 0x76c1c */
void ResultWindowColetteLayer::renderSpriteInstanceScaled(int nSlot,
                                                          const S_VECTOR2 &position,
                                                          unsigned int nScale) {
    if (nSlot < 0 || nSlot >= kSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSlots[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
    if (pTexture == nullptr) {
        return;
    }

    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flTextureScale = pTexture->GetScale();
    // The quad is sized by the texture's own scale factor; the UV region is the used image area.
    const S_VECTOR2 spriteSize{flImageWidth / flTextureScale, flImageHeight / flTextureScale};
    const S_VECTOR2 uvSize{flImageWidth / static_cast<float>(pTexture->GetAllocWidth()),
                           flImageHeight / static_cast<float>(pTexture->GetAllocHeight())};
    // The alpha is the requested scale times the layer's parts scale; the colour channels reuse the
    // layer's three glyph-base bytes as a tint.
    const unsigned int nAlpha =
        static_cast<unsigned int>(static_cast<float>(nScale) * m_flPartsScale);
    const unsigned int nRed = static_cast<unsigned int>(m_nGlyphBaseA) & 0xff;
    const unsigned int nGreen = static_cast<unsigned int>(m_nGlyphBaseB) & 0xff;
    const unsigned int nBlue = static_cast<unsigned int>(m_nGlyphBaseC) & 0xff;
    appendSpriteToSlotRgba(nSlot,
                           nRed,
                           nGreen,
                           nBlue,
                           nAlpha,
                           position,
                           S_VECTOR2{},
                           spriteSize,
                           S_VECTOR2{},
                           uvSize,
                           0.0f,
                           S_VECTOR2{1.0f, 1.0f});
}

/** @ghidraAddress 0x7aa54 */
void ResultWindowColetteLayer::RenderAnchoredGlyphWithAlpha(int nSlot,
                                                            int nCharCode,
                                                            int nPositionIndex,
                                                            const S_VECTOR2 &offset,
                                                            unsigned int nAlpha,
                                                            bool bShadowPass,
                                                            float flRotation,
                                                            float flScaleX,
                                                            float flScaleY) {
    if (nCharCode >= kColettePhonePartsRecordCount) {
        return;
    }
    // Resolve the base position by index and add the offset.
    S_VECTOR2 position{};
    getPosition_Phone(nPositionIndex, &position);
    // The glyph metrics come from the phone parts table indexed by the character code; the texture
    // rectangle from the Colette glyph UV palette.
    const PartsDataRecord *pGlyph = &g_aColettePartsPhone[nCharCode];
    const UvPaletteEntry &palette = g_aColetteGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass ? kIntensityDimmed : kIntensityFull;
    appendSpriteToSlot(nSlot,
                       S_VECTOR2{position.x + offset.x, position.y + offset.y},
                       S_VECTOR2{pGlyph->flX, pGlyph->flY},
                       S_VECTOR2{pGlyph->flWidth, pGlyph->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x769cc */
void ResultWindowColetteLayer::RenderPartSpriteByIndex(int nSlot,
                                                       int nPartId,
                                                       const S_VECTOR2 &position,
                                                       unsigned int nAlpha,
                                                       float flRotation,
                                                       float flScaleX,
                                                       float flScaleY,
                                                       float flRed,
                                                       float flGreen,
                                                       float flBlue) {
    if (nPartId >= kColettePartsRecordCount) {
        return;
    }
    // The part metrics come from the device-selected parts table; the texture rectangle from the
    // Colette part UV palette. The float colour channels are truncated to byte channels.
    const PartsDataRecord *pRecord = getPartsData(nPartId);
    const UvPaletteEntry &palette = g_aColettePartUvPalette[pRecord->nUvPaletteIndex];
    appendSpriteToSlotRgba(nSlot,
                           static_cast<unsigned int>(flRed),
                           static_cast<unsigned int>(flGreen),
                           static_cast<unsigned int>(flBlue),
                           nAlpha,
                           position,
                           S_VECTOR2{pRecord->flX, pRecord->flY},
                           S_VECTOR2{pRecord->flWidth, pRecord->flHeight},
                           S_VECTOR2{palette.flU, palette.flV},
                           S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                           flRotation,
                           S_VECTOR2{flScaleX, flScaleY});
}

/** @ghidraAddress 0x76a98 */
void ResultWindowColetteLayer::RenderPartSpriteWithAlpha(int nSlot,
                                                         int nPartId,
                                                         const S_VECTOR2 &position,
                                                         unsigned int nAlpha,
                                                         bool bShadowPass,
                                                         float flRotation,
                                                         float flScaleX,
                                                         float flScaleY) {
    if (nPartId >= kColettePartsRecordCount) {
        return;
    }
    // The part metrics come from the device-selected parts table; the texture rectangle from the
    // Colette part UV palette.
    const PartsDataRecord *pRecord = getPartsData(nPartId);
    const UvPaletteEntry &palette = g_aColettePartUvPalette[pRecord->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass ? kIntensityDimmed : kIntensityFull;
    appendSpriteToSlot(nSlot,
                       position,
                       S_VECTOR2{pRecord->flX, pRecord->flY},
                       S_VECTOR2{pRecord->flWidth, pRecord->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x79df0 */
void ResultWindowColetteLayer::RenderDimmableGlyphFromTable(int nSlot,
                                                            int nPartId,
                                                            const S_VECTOR2 &position,
                                                            unsigned int nAlpha,
                                                            bool bDimmed,
                                                            float flRotation,
                                                            float flScaleX,
                                                            float flScaleY) {
    if (nPartId >= kColettePhonePartsRecordCount) {
        return;
    }
    // The glyph metrics come from the phone parts table indexed by the part id; the texture
    // rectangle from the Colette glyph UV palette.
    const PartsDataRecord *pGlyph = &g_aColettePartsPhone[nPartId];
    const UvPaletteEntry &palette = g_aColetteGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bDimmed ? kIntensityDimmed : kIntensityFull;
    appendSpriteToSlot(nSlot,
                       position,
                       S_VECTOR2{pGlyph->flX, pGlyph->flY},
                       S_VECTOR2{pGlyph->flWidth, pGlyph->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nIntensity,
                       nAlpha);
}
