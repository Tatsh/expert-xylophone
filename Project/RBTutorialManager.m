//
//  RBTutorialManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBTutorialManager). Verified
//  against the arm64 disassembly (the -updateStatus: jump table over the status codes is partly
//  obscured by the decompiler).
//

#import "RBTutorialManager.h"

// Collaborator classes reached from these methods. Their headers are not all reconstructed in this
// tree yet (the same speculative-import style RBMusicManager.m and AppDelegate.mm already use); the
// RBUserSettingData tutorial accessors are already declared in its real header.
#import "RBExperienceData.h"
#import "RBServerAPIManager.h"
#import "RBUserSettingData.h"
#import "ScoreData.h"

// The value the persisted tutorial-status map stores once a tutorial has been seen. The
// "needs to start" predicates treat any other stored value as "not yet seen".
static const unsigned int kTutorialSeenValue = 1;

// The initial capacity of the pending unlocked-item info queue (the {itemInfo, itemId} pair).
static const NSUInteger kUnlockItemInfoCapacity = 2;

// The music-select "seen" flag identifier stored in the persisted tutorial-status map. It is the
// same value as RBTutorialStatusMusicSelectSeen but is queried directly against RBUserSettingData
// rather than compared against the live cursor.
static const unsigned int kTutorialFlagMusicSelectSeen = 0x17;

// The status code that reports its bare completion to the server rather than starting a tutorial:
// it carries no local side effect beyond the persisted-status update. Declared as an enumerator so
// it can serve as a switch case label.
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

#pragma mark - Music-select tutorial

+ (BOOL)needStartTutorialMusicselect {
    /** @ghidraAddress 0x3578c */
    if ([ScoreData totalRecordCount] >= 1) {
        return NO;
    }
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    return [settings getTutorialStatus:kTutorialFlagMusicSelectSeen] != kTutorialSeenValue;
}

+ (void)startTutorialMusicselect {
    /** @ghidraAddress 0x35820 */
    [[self getInstance] updateStatus:RBTutorialStatusMusicSelectStart];
}

+ (BOOL)isTutorialMusicselect {
    /** @ghidraAddress 0x35838 */
    return [[self getInstance] currentStatus] < RBTutorialStatusPlayRangeStart;
}

#pragma mark - In-play tutorial

+ (BOOL)needStartTutorialPlay {
    /** @ghidraAddress 0x358ec */
    if ([ScoreData totalRecordCount] >= 1) {
        return NO;
    }
    return [[self getInstance] currentStatus] == RBTutorialStatusPlayStart;
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
    if ([ScoreData totalRecordCount] >= 1) {
        return NO;
    }
    if (![[RBExperienceData sharedInstance] noUnlocked]) {
        return NO;
    }
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    return [settings getTutorialStatus:RBTutorialStatusCustomizeSeen] != kTutorialSeenValue;
}

+ (void)startTutorialCustomize {
    /** @ghidraAddress 0x35b24 */
    [[self getInstance] updateStatus:RBTutorialStatusCustomizeStart];
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
    if ([ScoreData totalRecordCount] >= 1) {
        return NO;
    }
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    return [settings getTutorialStatus:RBTutorialStatusStoreSeen] != kTutorialSeenValue;
}

+ (void)startTutorialStore {
    /** @ghidraAddress 0x35ce4 */
    [[self getInstance] updateStatus:RBTutorialStatusStoreStart];
}

#pragma mark - Status mutation

- (void)updateStatus:(RBTutorialStatus)updateStatus {
    /** @ghidraAddress 0x35dd4 */
    [[RBUserSettingData sharedInstance] updateTutorialStatus:updateStatus value:kTutorialSeenValue];
    [[RBTutorialManager getInstance] setCurrentStatus:updateStatus];

    switch (updateStatus) {
    case RBTutorialStatusMusicSelectStart:
        // The music-select walkthrough start (0) enters the tutorial and reports to the server.
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
        // Every other in-progress step (the customise steps 25-32, and the store "seen" flag 37)
        // records the status only, with no further side effect and no server report.
        return;
    }
    [RBServerAPIManager tutorialAPI];
}

/** @ghidraAddress 0x363a8 */
+ (void)resetUnlockedItemInfo {
    [[RBTutorialManager getInstance].unlockItemInfo removeAllObjects];
}

/** @ghidraAddress 0x36098 */
+ (void)setUnlockedItemInfo:(int)unlockedItemInfo itemId:(int)itemId {
    // Create the queue on first use; otherwise empty it before re-queuing the pair.
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
