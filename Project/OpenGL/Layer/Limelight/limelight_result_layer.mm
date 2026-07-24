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
