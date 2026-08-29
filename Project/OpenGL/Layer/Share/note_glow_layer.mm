#include "note_glow_layer.h"

#include <cassert>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

extern const SpriteUvEntry g_aScoreGaugeUvTable[]; // @ghidraAddress 0x2ef668

namespace {
constexpr float kInitialScale = 1.0f;

constexpr const char *kAtlasTextureName = "00_texture/gm_parts1";

constexpr int kSpriteCapacity = 2;
constexpr int kAdditiveBlendMode = 1;

// @ghidraAddress 0x30c9a0
constexpr int kGlowUvRow[] = {0x5d, 0x5e};

constexpr float kGlowAnchorX = 0.5f;
// @ghidraAddress 0x2ec6b0
constexpr float kGlowBarHeight = 100.0f;
constexpr float kGlowAnchorWidth = 1.0f;

// @ghidraAddress 0x2feff4
constexpr float kGlowLifetime = 500.0f;
// @ghidraAddress 0x2feff8
constexpr float kGlowFadeDivisor = -500.0f;
constexpr float kHalf = 0.5f;
// @ghidraAddress 0x2eed00
constexpr float kAlphaByteScale = 255.0f;

// The play colour indexes element one (0x176c38, 0x176c4c), so the other colour's bar is flipped.
// @ghidraAddress 0x30c998
constexpr float kGlowRotation[] = {3.1415927f, 0.0f};
} // namespace

static NoteGlowLayer *g_pNoteGlowLayer = nullptr; // @ghidraAddress 0x3deb40

/** @ghidraAddress 0x1769a8 */
NoteGlowLayer *NoteGlowLayer::shared() {
    if (g_pNoteGlowLayer == nullptr) {
        g_pNoteGlowLayer = new NoteGlowLayer();
    }
    return g_pNoteGlowLayer;
}

/** @ghidraAddress 0x176964 */
NoteGlowLayer::NoteGlowLayer() {
    m_aScale[0] = kInitialScale;
    m_aScale[1] = kInitialScale;
}

/** @ghidraAddress 0x176a84 */
void NoteGlowLayer::SetTexture() {
    RefreshThema();
    if (m_pSprite != nullptr) {
        m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
        m_pSprite->SetRefCountedMember(m_pTexture);
    }
}

/** @ghidraAddress 0x1769f8 */
void NoteGlowLayer::InitializeSprites() {
    if (m_bLoaded) {
        return;
    }

    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
    m_nCapacity = kSpriteCapacity;
    m_pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);

    m_bLoaded = true;
}

/** @ghidraAddress 0x176ad8 */
void NoteGlowLayer::CreateEffect(unsigned int nColor) {
    if (!m_bLoaded) {
        InitializeSprites();
    }
    assert(static_cast<int>(nColor) >= 0 && static_cast<int>(nColor) < kColorCount);
    m_aEffects[nColor].bActive = true;
    m_aEffects[nColor].flTimer = 0.0f;
}

/** @ghidraAddress 0x176cb0 */
void NoteGlowLayer::EmitGlowSprite(
    unsigned int nColor, const S_VECTOR2 *pPosition, int nAlpha, float flScale, float flRotation) {
    assert(static_cast<int>(nColor) >= 0 && static_cast<int>(nColor) < kColorCount);

    const SpriteUvEntry &uv = g_aScoreGaugeUvTable[kGlowUvRow[nColor]];
    const int nIndex = m_nSpriteCount;

    m_pSprite->SetSpritePosition(nIndex, *pPosition);
    m_pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{kGlowAnchorX, kGlowBarHeight});
    m_pSprite->SetSpriteSize(nIndex, S_VECTOR2{kGlowAnchorWidth, kGlowBarHeight});
    m_pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprite->SetSpriteScale(nIndex, flScale, kGlowAnchorWidth);
    m_pSprite->SetSpriteRotation(nIndex, flRotation);
    m_pSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, static_cast<unsigned int>(nAlpha));
    ++m_nSpriteCount;
}

/** @ghidraAddress 0x176b64 */
void NoteGlowLayer::Process(float flDelta) {
    m_nSpriteCount = 0;

    const int nPlayColor = GameSystem::GetGameSystem()->GetPlayColor();
    for (int nColor = 0; nColor < kColorCount; ++nColor) {
        EffectSlot &slot = m_aEffects[nColor];
        if (!slot.bActive) {
            continue;
        }
        slot.flTimer += flDelta;
        if (slot.flTimer > kGlowLifetime) {
            slot.bActive = false;
            continue;
        }

        float flFade = slot.flTimer / kGlowFadeDivisor + 1.0f;
        const bool bPlayColour = nColor == nPlayColor;
        const float flPosY = GameSystem::GetGameSystem()->GetSheetPosY() * kHalf;
        S_VECTOR2 position{0.0f, bPlayColour ? flPosY : -flPosY};
        flFade *= m_aScale[bPlayColour ? 1 : 0];

        EmitGlowSprite(nColor,
                       &position,
                       static_cast<int>(flFade * kAlphaByteScale),
                       GameSystem::GetGameSystem()->GetSheetPosX(),
                       kGlowRotation[bPlayColour ? 1 : 0]);
    }

    m_pSprite->SetSpriteCount(m_nSpriteCount);
}
