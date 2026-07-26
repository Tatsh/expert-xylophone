#include "event_effect_layer.h"

#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide event-notification effect layer, created lazily by shared().
static EventEffectLayer *g_pEventEffectLayer = nullptr; // @ghidraAddress 0x3df4a8

namespace {

// The atlas the event effect draws from (@ghidraAddress 0x3ceb08).
constexpr const char *kTextureName = "00_texture/gm_event";

// The timer value that marks the event effect fully finished.
constexpr float kEffectFinishedTimer = 5000.0f;

} // namespace

/** @ghidraAddress 0x1be594 */
void EventEffectLayer::StartEffect() {
    m_bActive = true;
    m_flTimer = 0.0f;
    m_bSoundFlag = true;
    m_nMode = GameSystem::GetGameSystem()->GetPastelBonusType();
}

/** @ghidraAddress 0x1be5cc */
void EventEffectLayer::FinishEffect() {
    m_flTimer = kEffectFinishedTimer;
}

/** @ghidraAddress 0x1be49c */
EventEffectLayer *EventEffectLayer::shared() {
    if (g_pEventEffectLayer == nullptr) {
        // The binary allocates the raw 0x40-byte object and inlines its zero-initialisation after
        // chaining the base-layer constructor.
        g_pEventEffectLayer = new EventEffectLayer();
    }
    return g_pEventEffectLayer;
}

/** @ghidraAddress 0x1be504 */
void EventEffectLayer::CreateEventEffectSprites() {
    if (m_bBuilt) {
        return;
    }

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // The root instancer holds a single sprite and lives directly in the global scene tree.
    m_pRootSprite = ne::CreateSpriteInstancer(kRootCapacity);
    m_pRootSprite->RegisterGlobal();
    m_pRootSprite->SetVisible(true);

    // The main instancer nests beneath the root, draws with the event atlas, and takes its initial
    // sprite count from the layer.
    m_pMainSprite = ne::CreateSpriteInstancer(kMainCapacity);
    m_pRootSprite->AttachChild(m_pMainSprite);
    m_pMainSprite->SetVisible(true);
    m_pMainSprite->SetRefCountedMember(m_pTexture);
    m_pMainSprite->SetSpriteCount(m_nSpriteCount);

    m_bBuilt = true;
}
