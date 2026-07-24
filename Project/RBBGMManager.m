//
//  RBBGMManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBBGMManager). Verified against
//  the arm64 disassembly: the decompiler drops the theme-name format argument that the title and
//  result loaders splice into their asset paths, and folds the fade duration's float-to-double
//  conversion.
//

#import "RBBGMManager.h"

// Collaborator singletons reached from these methods. AudioManager is committed; RBUserSettingData
// is imported speculatively in the same no-seams style the rest of the tree uses, and resolves
// once that class lands.
#import "AudioManager.h"
#import "RBUserSettingData.h"

// The asset paths of the three background loops. The menu loop lives under the shared theme folder
// and takes a theme-name suffix; the title and result loops live under the user's current theme
// folder. All three are bundled @c .m4a resources.
static NSString *const kMenuMusicPathFormat = @"Sounds/00_Share/BGM/SD_BGM_%@";
static NSString *const kTitleMusicPathFormat = @"Sounds/%@/BGM/SD_BGM_TITLE";
static NSString *const kResultMusicPathFormat = @"Sounds/%@/BGM/SD_BGM_RESULT";
static NSString *const kMusicResourceType = @"m4a";

// The theme asset-name suffixes spliced into the menu loop's path, indexed by the user's stored
// background-music preference. This mirrors the shared theme asset-name table the sound-effect
// loader also reads, so the suffix stays in step with the chosen theme.
// @ghidraAddress 0x359d70 (g_pThemeAssetNames)
static NSString *const kThemeAssetNames[] = {
    @"CUSTOM_CLASSIC",
    @"CUSTOM_LIMELIGHT",
    @"CUSTOM_TAG",
    @"CUSTOM_QRISPY",
    @"CUSTOM_YUKKY",
    @"CUSTOM_LED",
    @"CUSTOM_96",
    @"CUSTOM_DJTAKA",
    @"CUSTOM_NEKOMATA",
    @"CUSTOM_TOMOSUKE",
    @"CUSTOM_DJYOSHITAKA",
    @"CUSTOM_QRISPY2",
    @"CUSTOM_QRISPY3",
    @"CUSTOM_SOTA",
    @"CUSTOM_SCU",
    @"CUSTOM_COLETTE",
    @"CUSTOM_WINTER",
    @"CUSTOM_SPRING",
};

@implementation RBBGMManager {
    // Whether a background track is currently loaded in the audio manager.
    BOOL fIsMusic;
    // Whether a track has been pushed aside onto the audio manager's stack, awaiting a pop.
    BOOL fIsPushMusic;
}

#pragma mark - Singleton

+ (instancetype)getInstance {
    /** @ghidraAddress 0x69e50 */
    static RBBGMManager *instance = nil;
    if (instance == nil) {
        instance = [[RBBGMManager alloc] init];
    }
    return instance;
}

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x69ea8 */
    self = [super init];
    if (self) {
        fIsMusic = NO;
        fIsPushMusic = NO;
    }
    return self;
}

#pragma mark - Track loading

- (void)LoadMusicSelect {
    /** @ghidraAddress 0x6a324 */
    [self RelaseMusic];
    int type = [[RBUserSettingData sharedInstance] bgmType];
    [self LoadMusicType:type Loop:YES];
}

- (void)LoadMusicType:(int)type Loop:(BOOL)loop {
    /** @ghidraAddress 0x6a1cc */
    NSString *name = kThemeAssetNames[type];
    NSString *resource = [NSString stringWithFormat:kMenuMusicPathFormat, name];
    NSString *path = [[NSBundle mainBundle] pathForResource:resource ofType:kMusicResourceType];
    NSData *data = [NSData dataWithContentsOfFile:path];
    [self LoadMusic:data Loop:loop];
}

- (void)LoadMusicTitleWithLoop:(BOOL)loop {
    /** @ghidraAddress 0x6a3b4 */
    NSString *thema = [[RBUserSettingData sharedInstance] themaName];
    NSString *resource = [NSString stringWithFormat:kTitleMusicPathFormat, thema];
    NSString *path = [[NSBundle mainBundle] pathForResource:resource ofType:kMusicResourceType];
    NSData *data = [NSData dataWithContentsOfFile:path];
    [self LoadMusic:data Loop:loop];
}

- (void)LoadMusicResultWithLoop:(BOOL)loop {
    /** @ghidraAddress 0x6a560 */
    NSString *thema = [[RBUserSettingData sharedInstance] themaName];
    NSString *resource = [NSString stringWithFormat:kResultMusicPathFormat, thema];
    NSString *path = [[NSBundle mainBundle] pathForResource:resource ofType:kMusicResourceType];
    NSData *data = [NSData dataWithContentsOfFile:path];
    [self LoadMusic:data Loop:loop];
}

- (void)LoadMusic:(NSData *)data Loop:(BOOL)loop {
    /** @ghidraAddress 0x6a70c */
    fIsMusic = YES;
    [[AudioManager sharedManager] loadBgmData:data isLoop:loop];
}

- (BOOL)LoadMusicWithPush:(NSData *)data Loop:(BOOL)loop {
    /** @ghidraAddress 0x6a7b4 */
    if (fIsPushMusic) {
        [self popMusic];
    }
    [self pushMusic];
    [self LoadMusic:data Loop:loop];
    return fIsPushMusic;
}

- (void)RelaseMusic {
    /** @ghidraAddress 0x69ef8 */
    AudioManager *audio = [AudioManager sharedManager];
    if (fIsMusic) {
        [audio releaseBgm];
    }
    if (fIsPushMusic) {
        [audio popBgm];
        [audio releaseBgm];
    }
    fIsMusic = NO;
    fIsPushMusic = NO;
}

#pragma mark - Playback

- (BOOL)PlayMusic:(float)time {
    /** @ghidraAddress 0x69fac */
    if (!fIsMusic) {
        return NO;
    }
    return [[AudioManager sharedManager] playBgm:time];
}

- (void)PauseMusic:(float)time {
    /** @ghidraAddress 0x6a03c */
    if (fIsMusic) {
        [[AudioManager sharedManager] onPauseBgm:time];
    }
}

- (void)StopMusic:(float)time {
    /** @ghidraAddress 0x6a0c8 */
    if (fIsMusic) {
        [[AudioManager sharedManager] stopBgm:time];
    }
}

- (void)SeekToTop {
    /** @ghidraAddress 0x6a154 */
    if (fIsMusic) {
        [[AudioManager sharedManager] seekBgmToTop];
    }
}

#pragma mark - Overlay stack

- (BOOL)pushMusic {
    /** @ghidraAddress 0x6a854 */
    BOOL wasLoaded = fIsMusic;
    if (wasLoaded) {
        [[AudioManager sharedManager] pushBgm];
        fIsPushMusic = YES;
        fIsMusic = NO;
    }
    return wasLoaded;
}

- (BOOL)popMusic {
    /** @ghidraAddress 0x6a8f0 */
    BOOL wasPushed = fIsPushMusic;
    if (wasPushed) {
        fIsPushMusic = NO;
        fIsMusic = YES;
        [[AudioManager sharedManager] popBgm];
    }
    return wasPushed;
}

- (BOOL)isPushMusic {
    /** @ghidraAddress 0x6a980 */
    return fIsPushMusic;
}

@end
