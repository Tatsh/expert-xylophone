//
//  soundeffectmanager.mm
//  REFLEC BEAT plus
//
//  The themed sound-effect manager (SoundEffectManager). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "soundeffectmanager.h"

#import <Foundation/Foundation.h>

#import "AudioManager.h"
#import "NSFileManager+RB.h"
#import "RBUserSettingData.h"

namespace {

// The per-theme sound-effect slot names, substituted into "Sounds/<thema>/SE/SD_SE_<name>.m4a".
static NSString *const kThemedSlotNames[] = {
    @"SELECT01",      @"SELECT02",     @"SELECT04",    @"WINDOW_OPEN", @"WINDOW_CLOSE",
    @"RESULT_WINDOW", @"RESULT_SCORE", @"RESULT_PAGE", @"CLEAR",       @"NEW",
    @"CROWN",         @"WARNING",      @"TAB",         @"GRA",         @"GRA3",
    @"SPECIAL",       @"TITLE",        @"PASTELIN",    @"PASTELOUT",   @"JUMP"};

// The shared (theme-independent) sound-effect slot names, substituted into
// "Sounds/00_Share/SE/SD_SE_<name>.m4a".
static NSString *const kSharedSlotNames[] = {
    @"CUSTOM_CLASSIC",      @"CUSTOM_LIMELIGHT", @"CUSTOM_TAG",          @"CUSTOM_QRISPY",
    @"CUSTOM_YUKKY",        @"CUSTOM_LED",       @"CUSTOM_96",           @"CUSTOM_DJTAKA",
    @"CUSTOM_NEKOMATA",     @"CUSTOM_TOMOSUKE",  @"CUSTOM_DJYOSHITAKA",  @"CUSTOM_QRISPY2",
    @"CUSTOM_QRISPY3",      @"CUSTOM_SOTA",      @"CUSTOM_SCU",          @"CUSTOM_COLETTE",
    @"CUSTOM_WINTER",       @"CUSTOM_SPRING",    @"CUSTOM_SUMMER",       @"CUSTOM_AUTUMN",
    @"CUSTOM_QRISPY4",      @"CUSTOM_TAG2",      @"CUSTOM_LED2",         @"CUSTOM_NEKOMATA2",
    @"CUSTOM_SCU2",         @"CUSTOM_PON",       @"CUSTOM_2BWAVES",      @"CUSTOM_PRIM",
    @"CUSTOM_DJSILVERBERG", @"CUSTOM_SEIYA",     @"CUSTOM_TOTTO",        @"CUSTOM_AKHUTA",
    @"CUSTOM_VENUS",        @"CUSTOM_VENUS2",    @"CUSTOM_MAXMAXIMIZER", @"CUSTOM_MAXMAXIMIZER2"};

// The per-theme voice (CV) names, substituted into "Sounds/<thema>/VOICE/SD_CV_<name>.m4a". The
// binary indexes a table selected by the current theme; theme 0 and every non-zero theme share the
// same eighteen entries apart from the second and third slots.
static NSString *const kVoiceNamesTheme0[] = {@"REFLECBEAT",
                                              @"MUSICSELECT",
                                              @"BATTLESTART",
                                              @"YOUWIN",
                                              @"YOULOSE",
                                              @"DRAW",
                                              @"RESULT",
                                              @"NEWRECORD",
                                              @"EXCELLENT",
                                              @"FULLCOMBO",
                                              @"BASIC",
                                              @"MEDIUM",
                                              @"HARD",
                                              @"THANKYOU",
                                              @"NEW",
                                              @"BLUEWIN",
                                              @"REDWIN",
                                              @"DECIDE"};
static NSString *const kVoiceNamesThemeOther[] = {@"REFLECBEAT",
                                                  @"MUSICSELECT",
                                                  @"AREYOUREADY",
                                                  @"CLEAR",
                                                  @"FAILED",
                                                  @"DRAW",
                                                  @"RESULT",
                                                  @"NEWRECORD",
                                                  @"EXCELLENT",
                                                  @"FULLCOMBO",
                                                  @"BASIC",
                                                  @"MEDIUM",
                                                  @"HARD",
                                                  @"THANKYOU",
                                                  @"NEW",
                                                  @"BLUEWIN",
                                                  @"REDWIN",
                                                  @"DECIDE"};

// The playback group index the sound-effect manager loads and plays its slots on.
constexpr int kSeGroup = 1;
// The volume-table index every themed sound effect plays at.
constexpr int kSePlayVolume = 0x7f;
// The voice state that always plays regardless of the recorded state.
constexpr long kVoiceStateAlways = 0x13;

// Returns the localised path to a sound file in the bundle, or nil when it does not exist.
NSString *SoundPath(NSString *relativeName) {
    return [NSBundle.mainBundle pathForResource:relativeName ofType:@"m4a"];
}

} // namespace

/** @ghidraAddress 0x1cc4ac */
SoundEffectManager::SoundEffectManager() {
    for (int theme = 0; theme < kThemeCount; ++theme) {
        for (int slot = 0; slot < kThemedSlotCount; ++slot) {
            m_aThemeLoaded[theme][slot] = false;
            m_aThemeResourceId[theme][slot] = -1;
        }
    }
    for (int slot = 0; slot < kSharedSlotCount; ++slot) {
        m_aSharedLoaded[slot] = false;
        m_aSharedResourceId[slot] = -1;
    }
}

/** @ghidraAddress 0x1cc514 */
SoundEffectManager *SoundEffectManager::GetInstance() {
    static SoundEffectManager *instance = nullptr;
    if (instance == nullptr) {
        instance = new SoundEffectManager();
    }
    return instance;
}

/** @ghidraAddress 0x1cc548 */
void SoundEffectManager::LoadThemedSoundEffect(int theme, int slot) {
    if (m_aThemeLoaded[theme][slot]) {
        return;
    }
    NSString *themaName =
        [RBUserSettingData themaNameWithID:static_cast<RBUserSettingDataTheme>(theme)];
    NSString *path = SoundPath(
        [NSString stringWithFormat:@"Sounds/%@/SE/SD_SE_%@", themaName, kThemedSlotNames[slot]]);
    // Only slots whose file ships are loaded; a missing file leaves the slot unloaded.
    if ([NSFileManager isFileExist:path]) {
        m_aThemeResourceId[theme][slot] = [AudioManager.sharedManager loadSe:path
                                                                      isLoop:NO
                                                                    callName:nil
                                                                       group:kSeGroup];
        m_aThemeLoaded[theme][slot] = true;
    }
}

/** @ghidraAddress 0x1cc75c */
void SoundEffectManager::LoadAll() {
    for (int theme = 0; theme < kThemeCount; ++theme) {
        for (int slot = 0; slot < kThemedSlotCount; ++slot) {
            LoadThemedSoundEffect(theme, slot);
        }
    }
    for (int slot = 0; slot < kSharedSlotCount; ++slot) {
        if (m_aSharedLoaded[slot]) {
            continue;
        }
        NSString *path = SoundPath(
            [NSString stringWithFormat:@"Sounds/00_Share/SE/SD_SE_%@", kSharedSlotNames[slot]]);
        m_aSharedResourceId[slot] = [AudioManager.sharedManager loadSe:path
                                                                isLoop:NO
                                                              callName:nil
                                                                 group:kSeGroup];
        m_aSharedLoaded[slot] = true;
    }
}

/** @ghidraAddress 0x1cc934 */
unsigned int SoundEffectManager::PlayThemedSoundEffect(int slotID) {
    const int theme = RBUserSettingData.sharedInstance.thema;
    if (!m_aThemeLoaded[theme][slotID]) {
        return 0xffffffff;
    }
    return [AudioManager.sharedManager playSe:nil
                                   resourceId:m_aThemeResourceId[theme][slotID]
                                       Volume:kSePlayVolume];
}

/** @ghidraAddress 0x1ccc44 */
bool SoundEffectManager::LoadThemedVoiceData(int voiceID) {
    m_nCurrentVoiceState = voiceID;
    const int theme = RBUserSettingData.sharedInstance.thema;
    NSString *voiceName = theme != 0 ? kVoiceNamesThemeOther[voiceID] : kVoiceNamesTheme0[voiceID];
    NSString *themaName = RBUserSettingData.sharedInstance.themaName;
    NSString *path =
        SoundPath([NSString stringWithFormat:@"Sounds/%@/VOICE/SD_CV_%@", themaName, voiceName]);
    NSData *data = [NSData dataWithContentsOfFile:path];
    [AudioManager.sharedManager loadVoiceData:data isLoop:NO];
    return true;
}

/** @ghidraAddress 0x1cceac */
bool SoundEffectManager::PlayThemedVoice(int voiceID) {
    if (voiceID != kVoiceStateAlways && m_nCurrentVoiceState != voiceID) {
        return false;
    }
    return [AudioManager.sharedManager playVoice];
}

/** @ghidraAddress 0x1ccc18 */
void SoundEffectManager::LoadAndSetThemedVoice(int voiceID) {
    LoadThemedVoiceData(voiceID);
    PlayThemedVoice(voiceID);
}

/** @ghidraAddress 0x1ccba8 */
bool SoundEffectManager::IsPlaying(unsigned int playHandle) {
    return [AudioManager.sharedManager isPlayingSe:playHandle];
}
