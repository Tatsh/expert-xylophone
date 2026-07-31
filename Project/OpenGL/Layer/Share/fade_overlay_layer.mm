#include "fade_overlay_layer.h"

#include "gamesystem.h"
#include "neDebugLog.h"
#include "neSpriteInstancing.h"

// The process-wide fade overlay layer, created lazily by shared().
static FadeOverlayLayer *g_pFadeOverlayLayer = nullptr; // @ghidraAddress 0x3deec8

namespace {

// The overlay quad is fully opaque at alpha one and transparent at alpha zero.
constexpr float kAlphaOpaque = 1.0f;
constexpr float kAlphaTransparent = 0.0f;

// The current alpha (in the unit interval) scales to a 0-255 colour byte (@ghidraAddress 0x2eed00).
constexpr float kAlphaToByte = 255.0f;

// The fade quad is drawn solid black.
constexpr unsigned int kBlackChannel = 0;

} // namespace

/** @ghidraAddress 0x17f9c0 */
FadeOverlayLayer *FadeOverlayLayer::shared() {
    if (g_pFadeOverlayLayer == nullptr) {
        // The binary allocates the raw 0x30-byte object and runs the base constructor, then zeroes
        // the instancer, slot, tween, and alpha fields; the zero-initialising members reproduce
        // that.
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
    // A non-positive duration snaps straight to opaque.
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
    // A non-positive duration snaps straight to transparent.
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

    // Advance the fade tween: interpolate the current alpha from start to target over the duration.
    if (m_flFadeElapsed < m_flFadeDuration) {
        float flElapsed = m_flFadeElapsed + flDelta;
        if (flElapsed > m_flFadeDuration) {
            flElapsed = m_flFadeDuration;
        }
        m_flFadeElapsed = flElapsed;
        const float flProgress = (m_flFadeDuration == 0.0f) ? 1.0f : flElapsed / m_flFadeDuration;
        m_flCurrentAlpha = m_flFadeStart + flProgress * (m_flFadeTarget - m_flFadeStart);
    }

    // Draw the black full-screen quad at the current alpha, scaled to the viewport.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const S_VECTOR2 size{pGameSystem->GetViewportWidth(), pGameSystem->GetViewportHeight()};
    // A translucent black quadrant appears at the bottom right of the play screen where a
    // full-screen dim belongs. The quad's own terms are all correct against the binary -- position
    // and anchor (0,0), size the viewport, and a top-left-origin ortho -- so record the alpha and
    // the parent transform the quad is actually composed against.
    if (NE_DBG_FIRST(8)) {
        ne::C_RENDER *pNode = m_pInstancer->GetParent();
        const float *pParent = pNode != nullptr ? pNode->GetWorldMatrix() : nullptr;
        neDebugLog("fadeOverlay size=(%.1f,%.1f) alpha=%.3f parent=%p "
                   "parentT=(%.1f,%.1f,%.1f) parentScale=(%.3f,%.3f)",
                   static_cast<double>(size.x),
                   static_cast<double>(size.y),
                   static_cast<double>(m_flCurrentAlpha),
                   static_cast<const void *>(pParent),
                   pParent != nullptr ? static_cast<double>(pParent[12]) : 0.0,
                   pParent != nullptr ? static_cast<double>(pParent[13]) : 0.0,
                   pParent != nullptr ? static_cast<double>(pParent[14]) : 0.0,
                   pParent != nullptr ? static_cast<double>(pParent[0]) : 0.0,
                   pParent != nullptr ? static_cast<double>(pParent[5]) : 0.0);
    }
    EmitQuad(size, static_cast<unsigned int>(m_flCurrentAlpha * kAlphaToByte));

    // Publish the emitted slot count into the instancer's draw count.
    m_pInstancer->SetSpriteCount(m_nSlotCount);
}
