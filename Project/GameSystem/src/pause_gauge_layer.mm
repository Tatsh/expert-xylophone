//
//  pause_gauge_layer.mm
//  REFLEC BEAT plus
//
//  The pause-gauge play-field layer (PauseGaugeLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#import "pause_gauge_layer.h"

#import "RBUserSettingData.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "soundeffectmanager.h"

namespace {
// The themed sound-effect slot the pause gauge plays when it starts charging.
constexpr int kSoundEffectPauseGaugeCharge = 3;

// The pause-gauge parts atlas.
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";

// The number of sprite-slot ids the gauge distributes across the two slots (one gauge sprite plus
// its two side arrows per reachable lane).
constexpr int kLaneSlotStride = 2;

// The per-lane slot-group table: lane 0 uses the gauge slot, every other lane the parts slot.
constexpr int kLaneSlotGroup[PauseGaugeLayer::kLaneSlotCount] = {
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};

// The theme code for which the parts slot binds the shared parts atlas (the second, parts, slot).
constexpr int kPartsSlot = 1;

// The build state the sprite loader leaves the layer in.
constexpr int kStateLoaded = 1;

// The active-lane mask the constructor seeds (all five lanes of both sides plus the spare bit).
constexpr unsigned long kInitialActiveMask = 0x4ffffffffUL;
} // namespace

/** @ghidraAddress 0x1508b4 */
PauseGaugeLayer::PauseGaugeLayer() {
    // The UI-layer base constructor ran first and the compiler installed the task dispatch vtable.
    m_nState = 0;
    m_bCharging = false;
    m_qwActiveMask = kInitialActiveMask;
    m_pTexture = nullptr;
    for (int nSlot = 0; nSlot < kSlotCount; ++nSlot) {
        m_apSprites[nSlot] = nullptr;
        m_aSlotCapacity[nSlot] = 0;
    }
    // Give each lane the next free pair of sprite indices within its slot group.
    for (int nLane = 0; nLane < kLaneSlotCount; ++nLane) {
        const int nGroup = kLaneSlotGroup[nLane];
        m_aLaneSlotId[nLane] = m_aSlotCapacity[nGroup];
        m_aSlotCapacity[nGroup] += kLaneSlotStride;
    }
    LoadSprites();
}

/** @ghidraAddress 0x150994 */
void PauseGaugeLayer::LoadSprites() {
    m_nThema = RBUserSettingData.sharedInstance.thema;
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    for (int nSlot = 0; nSlot < kSlotCount; ++nSlot) {
        m_apSprites[nSlot] = ne::CreateSpriteInstancer(m_aSlotCapacity[nSlot]);
        m_apSprites[nSlot]->RegisterGlobal();
        m_apSprites[nSlot]->SetVisible(true);
        // The parts slot binds the shared parts atlas; the gauge slot leaves its texture unset.
        if (nSlot == kPartsSlot) {
            m_apSprites[nSlot]->SetRefCountedMember(m_pTexture);
        }
        m_apSprites[nSlot]->SetSpriteCount(0);
    }
    m_nState = kStateLoaded;
}

/**
 * @ghidraAddress 0x150a7c
 * @ghidraAddress 0x150b00
 */
PauseGaugeLayer::~PauseGaugeLayer() {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    for (ne::C_SPRITE_INSTANCING *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            // The sprite nodes are owned by the scene graph; flag them for the scene walker.
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
}

/** @ghidraAddress 0x1508b0 */
void PauseGaugeLayer::OnFrame(void *pFrameArg) {
    (void)pFrameArg; // The pause gauge does no per-frame work; its sprites are rendered externally.
}

/** @ghidraAddress 0x150e58 */
void PauseGaugeLayer::SetCharging() {
    // Only the first entry into the charging state plays the sound; later frames are a no-op.
    if (m_bCharging) {
        return;
    }
    m_bCharging = true;
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectPauseGaugeCharge);
}

/** @ghidraAddress 0x150e84 */
void PauseGaugeLayer::ClearCharging() {
    m_bCharging = false;
}
