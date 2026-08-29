#include "fade_overlay_layer.h"

#include "gamesystem.h"
#include "neSpriteInstancing.h"

static FadeOverlayLayer *g_pFadeOverlayLayer = nullptr; // @ghidraAddress 0x3deec8

namespace {

constexpr float kAlphaOpaque = 1.0f;
constexpr float kAlphaTransparent = 0.0f;

// @ghidraAddress 0x2eed00
constexpr float kAlphaToByte = 255.0f;

constexpr unsigned int kBlackChannel = 0;

} // namespace

/** @ghidraAddress 0x17f9c0 */
FadeOverlayLayer *FadeOverlayLayer::shared() {
    if (g_pFadeOverlayLayer == nullptr) {
        g_pFadeOverlayLayer = new FadeOverlayLayer();
    }
    return g_pFadeOverlayLayer;
}

/** @ghidraAddress 0x17fa24 */
void FadeOverlayLayer::EnsureInstancer() {
    if (m_bInstancerCreated) {
        return;
    }
    m_pInstancer = ne::CreateSpriteInstancer(1);
    m_pInstancer->RegisterGlobal();
    m_pInstancer->SetVisible(true);
    m_pInstancer->SetSpriteCount(m_nSlotCount);
    m_bInstancerCreated = true;
}

/** @ghidraAddress 0x17fa78 */
void FadeOverlayLayer::StartFadeIn(float flDuration) {
    m_flFadeStart = m_flCurrentAlpha;
    m_flFadeTarget = kAlphaOpaque;
    m_flFadeDuration = flDuration;
    m_flFadeElapsed = 0.0f;
    if (flDuration <= 0.0f) {
        m_flCurrentAlpha = kAlphaOpaque;
    }
}

/** @ghidraAddress 0x17faa0 */
void FadeOverlayLayer::StartFadeOut(float flDuration) {
    m_flFadeStart = m_flCurrentAlpha;
    m_flFadeTarget = kAlphaTransparent;
    m_flFadeDuration = flDuration;
    m_flFadeElapsed = 0.0f;
    if (flDuration <= 0.0f) {
        m_flCurrentAlpha = kAlphaTransparent;
    }
}

/** @ghidraAddress 0x17fb6c */
void FadeOverlayLayer::EmitQuad(const S_VECTOR2 &size, unsigned int nAlpha) {
    const S_VECTOR2 origin{0.0f, 0.0f};
    m_pInstancer->SetSpritePosition(m_nSlotCount, origin);
    m_pInstancer->SetSpriteAnchor(m_nSlotCount, origin);
    m_pInstancer->SetSpriteSize(m_nSlotCount, size);
    m_pInstancer->SetSpriteColor(m_nSlotCount, kBlackChannel, kBlackChannel, kBlackChannel, nAlpha);
    ++m_nSlotCount;
}

/** @ghidraAddress 0x17fac0 */
void FadeOverlayLayer::Render(float flDelta) {
    m_nSlotCount = 0;

    if (m_flFadeElapsed < m_flFadeDuration) {
        float flElapsed = m_flFadeElapsed + flDelta;
        if (flElapsed > m_flFadeDuration) {
            flElapsed = m_flFadeDuration;
        }
        m_flFadeElapsed = flElapsed;
        const float flProgress = (m_flFadeDuration == 0.0f) ? 1.0f : flElapsed / m_flFadeDuration;
        m_flCurrentAlpha = m_flFadeStart + flProgress * (m_flFadeTarget - m_flFadeStart);
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const S_VECTOR2 size{pGameSystem->GetViewportWidth(), pGameSystem->GetViewportHeight()};
    EmitQuad(size, static_cast<unsigned int>(m_flCurrentAlpha * kAlphaToByte));

    m_pInstancer->SetSpriteCount(m_nSlotCount);
}
