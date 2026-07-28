#include "event_effect_layer.h"

#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide event-notification effect layer, created lazily by shared().
static EventEffectLayer *g_pEventEffectLayer = nullptr; // @ghidraAddress 0x3df4a8

namespace {

// The atlas the event effect draws from (@ghidraAddress 0x3ceb08).
constexpr const char *kTextureName = "00_texture/gm_event";

// The timer value that marks the event effect fully finished.
constexpr float kEffectFinishedTimer = 5000.0f;

// The background quad's single slot, and the bit shift that packs its alpha into the colour's high
// byte (opaque black tinted by alpha).
constexpr int kBackgroundSlot = 0;
constexpr unsigned int kAlphaShift = 24;

// The factor the phone (non-pad) layout scales the event-sprite anchor and size by.
constexpr float kPortraitScale = 0.5f;

// One event-sprite descriptor: the sprite's anchor, its pixel size, and the atlas-frame index into
// the event UV table.
struct EventSpriteDescriptor {
    S_VECTOR2 anchor = {};  // +0x00: the sprite anchor offset.
    S_VECTOR2 size = {};    // +0x08: the sprite pixel size.
    int nUvFrameIndex = {}; // +0x10: the frame index into the event UV table.
};

// The event-sprite descriptor table, keyed by descriptor index. Static read-only data embedded in
// the binary. @ghidraAddress 0x3105b0
const EventSpriteDescriptor g_aEventSpriteDescriptor[] = {
    {{142.0f, 123.0f}, {284.0f, 247.0f}, 1},
    {{132.0f, 140.0f}, {264.0f, 280.0f}, 2},
    {{132.0f, 140.0f}, {264.0f, 280.0f}, 3},
    {{356.0f, 56.0f}, {712.0f, 112.0f}, 0},
    {{356.0f, 56.0f}, {712.0f, 112.0f}, 0},
    {{356.0f, 56.0f}, {712.0f, 112.0f}, 0},
};

// The event-sprite UV atlas the descriptors index by frame number. Static read-only data embedded in
// the binary; the reconstruction carries only the entries the descriptor table references.
// @ghidraAddress 0x2f7b28
const SpriteUvEntry g_aEventSpriteUvTable[] = {
    {0.0f, 0.0f, 0.6953125f, 0.21875f},
    {0.0f, 0.22265625f, 0.27734375f, 0.482421875f},
    {0.271484375f, 0.22265625f, 0.2578125f, 0.546875f},
    {0.53125f, 0.22265625f, 0.2578125f, 0.546875f},
};

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

/** @ghidraAddress 0x1be9b4 */
void EventEffectLayer::SetEventBackgroundQuad(int nAlpha) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    // Rebuild the single background sprite: opaque black scaled by the alpha (high byte), sized to
    // the whole viewport.
    m_pRootSprite->SetSpriteCount(0);
    m_pRootSprite->SetSpriteColor(kBackgroundSlot,
                                  static_cast<unsigned int>(nAlpha) << kAlphaShift);
    m_pRootSprite->SetSpriteSize(
        kBackgroundSlot,
        S_VECTOR2{pGameSystem->GetViewportWidth(), pGameSystem->GetViewportHeight()});
    m_pRootSprite->SetSpriteCount(1);
}

/** @ghidraAddress 0x1bea48 */
void EventEffectLayer::EmitEventSprite(
    unsigned int uDescIdx, const S_VECTOR2 &position, int iAlpha, float flScaleX, float flScaleY) {
    const int nIndex = m_pMainSprite->GetSpriteCount();
    if (nIndex >= static_cast<int>(m_pMainSprite->GetCapacity())) {
        return;
    }

    // The descriptor gives the anchor, size, and atlas frame; the phone (non-pad) layout halves the
    // anchor and size.
    const EventSpriteDescriptor &descriptor = g_aEventSpriteDescriptor[uDescIdx];
    S_VECTOR2 anchor = descriptor.anchor;
    S_VECTOR2 size = descriptor.size;
    if (!IsPad()) {
        anchor = S_VECTOR2{anchor.x * kPortraitScale, anchor.y * kPortraitScale};
        size = S_VECTOR2{size.x * kPortraitScale, size.y * kPortraitScale};
    }
    const SpriteUvEntry &uv = g_aEventSpriteUvTable[descriptor.nUvFrameIndex];

    m_pMainSprite->SetSpritePosition(nIndex, position);
    m_pMainSprite->SetSpriteAnchor(nIndex, anchor);
    m_pMainSprite->SetSpriteSize(nIndex, size);
    m_pMainSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pMainSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pMainSprite->SetSpriteScale(nIndex, flScaleX, flScaleY);
    m_pMainSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, static_cast<unsigned int>(iAlpha));
    m_pMainSprite->SetSpriteCount(nIndex + 1);
}
