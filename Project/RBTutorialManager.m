#import "RBTutorialManager.h"

#import "RBExperienceData.h"
#import "RBServerAPIManager.h"
#import "RBUserSettingData.h"
#import "ScoreData.h"

// Any other stored value means "not yet seen".
static const unsigned int kTutorialSeenValue = 1;

static const NSUInteger kUnlockItemInfoCapacity = 2;

enum { kTutorialStatusReportOnly = 0x12 };

@implementation RBTutorialManager

#pragma mark - Singleton

+ (instancetype)getInstance {
    /** @ghidraAddress 0x356b8 */
    static RBTutorialManager *instance = nil;
    if (instance == nil) {
        instance = [[RBTutorialManager alloc] init];
        instance.currentStatus = RBTutorialStatusNone;
    }
    return instance;
}

#pragma mark - Status queries

+ (BOOL)isTutorial {
    /** @ghidraAddress 0x35724 */
    return [[self getInstance] isTutorial];
}

+ (RBTutorialStatus)getCurrentStatus {
    /** @ghidraAddress 0x35d6c */
    return [[self getInstance] currentStatus];
}

+ (unsigned int)getStatus:(unsigned int)status {
    /** @ghidraAddress 0x35cfc */
    return [[RBUserSettingData sharedInstance] getTutorialStatus:status];
}

#pragma mark - Music-select tutorial

+ (BOOL)needStartTutorialMusicselect {
    /** @ghidraAddress 0x3578c */
#if defined(ENABLE_PATCHES) && defined(SKIP_TUTORIAL)
    return NO;
#else
    if ([ScoreData totalRecordCount] >= 1) {
        return NO;
    }
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    return [settings getTutorialStatus:RBTutorialStatusMusicSelectSeen] != kTutorialSeenValue;
#endif
}

+ (void)startTutorialMusicselect {
    /** @ghidraAddress 0x35820 */
    [RBTutorialManager updateStatus:RBTutorialStatusMusicSelectStart];
}

+ (BOOL)isTutorialMusicselect {
    /** @ghidraAddress 0x35838 */
    // The binary reads currentStatus twice and discards the first result.
    return [[self getInstance] currentStatus] < RBTutorialStatusPlayRangeStart;
}

#pragma mark - In-play tutorial

+ (BOOL)needStartTutorialPlay {
    /** @ghidraAddress 0x358ec */
#if defined(ENABLE_PATCHES) && defined(SKIP_TUTORIAL)
    return NO;
#else
    if ([ScoreData totalRecordCount] >= 1) {
        return NO;
    }
    return [[self getInstance] currentStatus] == RBTutorialStatusPlayStart;
#endif
}

+ (BOOL)isTutorialPlay {
    /** @ghidraAddress 0x3597c */
    RBTutorialStatus status = [[self getInstance] currentStatus];
    if (status < RBTutorialStatusPlayRangeStart) {
        return NO;
    }
    return status < RBTutorialStatusMusicSelectSeen;
}

#pragma mark - Customise tutorial

+ (BOOL)needStartTutorialCustomize {
    /** @ghidraAddress 0x35a40 */
#if defined(ENABLE_PATCHES) && defined(SKIP_TUTORIAL)
    return NO;
#else
    if ([ScoreData totalRecordCount] >= 1) {
        return NO;
    }
    if (![[RBExperienceData sharedInstance] noUnlocked]) {
        return NO;
    }
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    return [settings getTutorialStatus:RBTutorialStatusCustomizeSeen] != kTutorialSeenValue;
#endif
}

+ (void)startTutorialCustomize {
    /** @ghidraAddress 0x35b24 */
    [RBTutorialManager updateStatus:RBTutorialStatusCustomizeStart];
}

+ (BOOL)isTutorialCustomize {
    /** @ghidraAddress 0x35b3c */
    if ([[RBUserSettingData sharedInstance] thema] != RBUserSettingDataThemeColette) {
        return NO;
    }
    RBTutorialStatus status = [[self getInstance] currentStatus];
    if (status < RBTutorialStatusCustomizeStart) {
        return NO;
    }
    return status < RBTutorialStatusCustomizeEnd;
}

#pragma mark - Store tutorial

+ (BOOL)needStartTutorialStore {
    /** @ghidraAddress 0x35c50 */
#if defined(ENABLE_PATCHES) && defined(SKIP_TUTORIAL)
    return NO;
#else
    if ([ScoreData totalRecordCount] >= 1) {
        return NO;
    }
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    return [settings getTutorialStatus:RBTutorialStatusStoreSeen] != kTutorialSeenValue;
#endif
}

+ (void)startTutorialStore {
    /** @ghidraAddress 0x35ce4 */
    [RBTutorialManager updateStatus:RBTutorialStatusStoreStart];
}

#pragma mark - Status mutation

+ (void)updateStatus:(RBTutorialStatus)updateStatus {
    /** @ghidraAddress 0x35dd4 */
    [[RBUserSettingData sharedInstance] updateTutorialStatus:updateStatus value:kTutorialSeenValue];
    [[RBTutorialManager getInstance] setCurrentStatus:updateStatus];

    switch (updateStatus) {
    case RBTutorialStatusMusicSelectStart:
        [[RBTutorialManager getInstance] setIsTutorial:YES];
        break;
    case kTutorialStatusReportOnly:
        // Reports to the server only.
        break;
    case RBTutorialStatusCustomizeStart:
        [[RBTutorialManager getInstance] setIsTutorial:YES];
        break;
    case RBTutorialStatusCustomizeSeen:
        // Reports to the server only.
        break;
    case RBTutorialStatusCustomizeEnd:
        [[RBTutorialManager getInstance] setCurrentStatus:RBTutorialStatusDone];
        [[RBTutorialManager getInstance] setIsTutorial:NO];
        break;
    case RBTutorialStatusStoreStart:
        [[RBTutorialManager getInstance] setIsTutorial:YES];
        return;
    case RBTutorialStatusStoreStart + 1:
        [[RBTutorialManager getInstance] setIsTutorial:YES];
        return;
    case RBTutorialStatusStoreStart + 3:
        [[RBTutorialManager getInstance] setIsTutorial:NO];
        return;
    default:
        // Every other step records the status only, with no server report.
        return;
    }
    [RBServerAPIManager tutorialAPI];
}

/** @ghidraAddress 0x36308 */
+ (NSArray *)getUnlockedItemInfo {
    return [[RBTutorialManager getInstance].unlockItemInfo copy];
}

/** @ghidraAddress 0x363a8 */
+ (void)resetUnlockedItemInfo {
    [[RBTutorialManager getInstance].unlockItemInfo removeAllObjects];
}

/** @ghidraAddress 0x36098 */
+ (void)setUnlockedItemInfo:(int)unlockedItemInfo itemId:(int)itemId {
    if ([RBTutorialManager getInstance].unlockItemInfo == nil) {
        [RBTutorialManager getInstance].unlockItemInfo =
            [[NSMutableArray alloc] initWithCapacity:kUnlockItemInfoCapacity];
    } else {
        [RBTutorialManager resetUnlockedItemInfo];
    }
    [[RBTutorialManager getInstance].unlockItemInfo addObject:@(unlockedItemInfo)];
    [[RBTutorialManager getInstance].unlockItemInfo addObject:@(itemId)];
}

@end
