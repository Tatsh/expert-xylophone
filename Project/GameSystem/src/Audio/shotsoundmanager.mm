#include "shotsoundmanager.h"

#import <Foundation/Foundation.h>

#import "AudioManager.h"
#include "gamesystem.h"

namespace {

static NSString *const kSlotNames[] = {
    @"DEFAULT1", @"DEFAULT2",    @"DEFAULT3",  @"HOCKEY",     @"VOLLEYBALL", @"TENNIS",
    @"BASEBALL", @"TABLETENNIS", @"ELECTRO1",  @"ELECTRO2",   @"ELECTRO3",   @"ELECTRO4",
    @"ELECTRO5", @"ELECTRO6",    @"CLAP",      @"TAMBOURINE", @"JAPAN",      @"PERCUSSION",
    @"LATIN",    @"HIT",         @"SWORD",     @"BOMB",       @"FIGHT",      @"STEEL",
    @"LIGHT",    @"FIREWORKS",   @"QRISPY",    @"SOTA",       @"96",         @"PERCUSSION2",
    @"JAPAN2",   @"PAWAPURO",    @"JINGLEBELL"};

static NSString *const kVariantNames[] = {@"JUST", @"GREAT", @"GOOD", @"RIVAL"};

constexpr int kIdlePriority = 5;
// In milliseconds: one frame at 30 fps.
constexpr float kRetriggerPeriod = 33.333332f; // 0x42055555 at 0x1cd564/0x1cd5a4
constexpr int kRetriggerChannel = 1;
constexpr int kShotGroup = 0;
// Converts the unit-interval shot volume to the audio manager's integer range.
constexpr float kVolumeScale = 127.0f;

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
        // Variant zero is the shared JUST sound, already registered by the bank-wide load
        // (0x1cd050-0x1cd058).
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
    const unsigned int nActive = m_aChannelHandle[uChannel];
    if (nActive != 0xffffffff) {
        if ([audio isPlayingSe:nActive]) {
            [audio stopSe:m_aChannelHandle[uChannel]];
        }
        m_aChannelHandle[uChannel] = 0xffffffff;
    }
    const float flVolume = GameSystem::GetGameSystem()->GetShotVolume() * kVolumeScale;
    m_flVolume = flVolume;
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
        if (m_flRetriggerTimer > kRetriggerPeriod) {
            m_flRetriggerTimer = kRetriggerPeriod;
        }
        m_flRetriggerTimer -= flDeltaTime;
    } else if (m_nPendingVariant != kIdlePriority) {
        PlaySlot(kRetriggerChannel, m_nPendingSlot, m_nPendingVariant);
        m_flRetriggerTimer = kRetriggerPeriod;
    }
    m_nPendingVariant = kIdlePriority;
}
