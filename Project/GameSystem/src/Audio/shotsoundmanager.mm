//
//  shotsoundmanager.mm
//  REFLEC BEAT plus
//
//  The shot (tap) sound sub-manager (ShotSoundManager). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "shotsoundmanager.h"

#import <Foundation/Foundation.h>

#import "AudioManager.h"
#include "gamesystem.h"

namespace {

// The shot slot names, substituted into "Sounds/00_Share/SHOT/SD_SHOT_<slot>_<variant>.m4a".
static NSString *const kSlotNames[] = {
    @"DEFAULT1", @"DEFAULT2",    @"DEFAULT3",  @"HOCKEY",     @"VOLLEYBALL", @"TENNIS",
    @"BASEBALL", @"TABLETENNIS", @"ELECTRO1",  @"ELECTRO2",   @"ELECTRO3",   @"ELECTRO4",
    @"ELECTRO5", @"ELECTRO6",    @"CLAP",      @"TAMBOURINE", @"JAPAN",      @"PERCUSSION",
    @"LATIN",    @"HIT",         @"SWORD",     @"BOMB",       @"FIGHT",      @"STEEL",
    @"LIGHT",    @"FIREWORKS",   @"QRISPY",    @"SOTA",       @"96",         @"PERCUSSION2",
    @"JAPAN2",   @"PAWAPURO",    @"JINGLEBELL"};

// The judgement variant names, substituted as the second path component.
static NSString *const kVariantNames[] = {@"JUST", @"GREAT", @"GOOD", @"RIVAL"};

// The idle sentinel for the pending retrigger priority: no shot is pending at this value.
constexpr int kIdlePriority = 5;
// The retrigger cooldown period, in milliseconds (one frame at 30 fps).
constexpr float kRetriggerPeriod = 33.333332f; // 0x42055555 at 0x1cd564/0x1cd5a4
// The playback channel the timer retriggers the pending shot on.
constexpr int kRetriggerChannel = 1;
// The playback group index shot sounds load and play on.
constexpr int kShotGroup = 0;
// The scale converting the unit-interval shot volume to the audio manager's integer volume range.
constexpr float kVolumeScale = 127.0f;

// Returns the localised path to a shot sound file in the bundle, or nil when it does not exist.
NSString *ShotPath(NSString *slotName, NSString *variantName) {
    NSString *relative =
        [NSString stringWithFormat:@"Sounds/00_Share/SHOT/SD_SHOT_%@_%@", slotName, variantName];
    return [NSBundle.mainBundle pathForResource:relative ofType:@"m4a"];
}

} // namespace

/** @ghidraAddress 0x1ccf30 */
ShotSoundManager::ShotSoundManager() {
    m_bSharedLoaded = false;
    m_nPendingSlot = 0;
    m_nPendingVariant = kIdlePriority;
    m_flRetriggerTimer = 0.0f;
    m_flVolume = 1.0f;
    for (int slot = 0; slot < kSlotCount; ++slot) {
        m_aSlotLoaded[slot] = false;
        for (int variant = 0; variant < kVariantCount; ++variant) {
            m_aResourceId[slot][variant] = -1;
        }
    }
    for (int channel = 0; channel < kChannelCount; ++channel) {
        m_aChannelHandle[channel] = 0xffffffff;
    }
}

/** @ghidraAddress 0x1ccf30 */
ShotSoundManager *ShotSoundManager::GetInstance() {
    static ShotSoundManager *instance = nullptr;
    if (instance == nullptr) {
        instance = new ShotSoundManager();
    }
    return instance;
}

/** @ghidraAddress 0x1ccfac */
void ShotSoundManager::LoadSlotVariants(int slot) {
    if (m_aSlotLoaded[slot]) {
        return;
    }
    AudioManager *audio = AudioManager.sharedManager;
    for (int variant = 0; variant < kVariantCount; ++variant) {
        // Variant zero is the shared JUST sound; once the bank-wide load has run it is already
        // registered, so it is skipped here, matching the binary's shared-flag guard at
        // 0x1cd050-0x1cd058.
        if (variant == 0 && m_bSharedLoaded) {
            continue;
        }
        NSString *path = ShotPath(kSlotNames[slot], kVariantNames[variant]);
        m_aResourceId[slot][variant] = [audio loadSe:path isLoop:NO callName:nil group:kShotGroup];
    }
    m_aSlotLoaded[slot] = true;
}

/** @ghidraAddress 0x1cd190 */
void ShotSoundManager::LoadAll() {
    if (m_bSharedLoaded) {
        return;
    }
    AudioManager *audio = AudioManager.sharedManager;
    for (int slot = 0; slot < kSlotCount; ++slot) {
        if (!m_aSlotLoaded[slot]) {
            NSString *path = ShotPath(kSlotNames[slot], kVariantNames[0]);
            m_aResourceId[slot][0] = [audio loadSe:path isLoop:NO callName:nil group:kShotGroup];
        }
    }
    m_bSharedLoaded = true;
}

/** @ghidraAddress 0x1cd4a4 */
void ShotSoundManager::SetVolume(float flVolume) {
    if (flVolume > 1.0f) {
        flVolume = 1.0f;
    }
    if (flVolume <= 0.0f) {
        flVolume = 0.0f;
    }
    m_flVolume = flVolume;
    [AudioManager.sharedManager setSeVolume:static_cast<int>(m_flVolume * kVolumeScale)
                                    groupId:kShotGroup];
}

/** @ghidraAddress 0x1cd364 */
unsigned int ShotSoundManager::PlaySlot(unsigned long uChannel, int iSlot, int iVariant) {
    AudioManager *audio = AudioManager.sharedManager;
    // Stop and clear any sound still playing on this channel.
    const unsigned int nActive = m_aChannelHandle[uChannel];
    if (nActive != 0xffffffff) {
        if ([audio isPlayingSe:nActive]) {
            [audio stopSe:m_aChannelHandle[uChannel]];
        }
        m_aChannelHandle[uChannel] = 0xffffffff;
    }
    // Refresh the volume from the current game-system shot volume setting.
    const float flVolume = GameSystem::GetGameSystem()->GetShotVolume() * kVolumeScale;
    m_flVolume = flVolume;
    // Play only when the slot's variant is loaded (variant zero also requires the shared load).
    if (!m_aSlotLoaded[iSlot] && (iVariant != 0 || !m_bSharedLoaded)) {
        return m_aChannelHandle[uChannel];
    }
    const unsigned int nHandle = [audio playSe:nil
                                    resourceId:m_aResourceId[iSlot][iVariant]
                                        Volume:static_cast<int>(flVolume)];
    m_aChannelHandle[uChannel] = nHandle;
    return nHandle;
}

/** @ghidraAddress 0x1cd48c */
void ShotSoundManager::SetPendingRetrigger(int nSlot, int nPriority) {
    // Keep the highest-priority request (lowest value) pending for this frame.
    if (m_nPendingVariant > nPriority) {
        m_nPendingSlot = nSlot;
        m_nPendingVariant = nPriority;
    }
}

/** @ghidraAddress 0x1cd538 */
void ShotSoundManager::UpdateRetriggerTimer(float flDeltaTime) {
    if (m_flRetriggerTimer > 0.0f) {
        // A retrigger is cooling down: clamp it to one frame and count it down.
        if (m_flRetriggerTimer > kRetriggerPeriod) {
            m_flRetriggerTimer = kRetriggerPeriod;
        }
        m_flRetriggerTimer -= flDeltaTime;
    } else if (m_nPendingVariant != kIdlePriority) {
        // The cooldown has elapsed and a shot is pending: play it and restart the cooldown.
        PlaySlot(kRetriggerChannel, m_nPendingSlot, m_nPendingVariant);
        m_flRetriggerTimer = kRetriggerPeriod;
    }
    // The pending state returns to idle for the next frame.
    m_nPendingVariant = kIdlePriority;
}
