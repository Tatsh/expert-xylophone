/** @file
 * The tutorial-progression manager singleton. It tracks which guided tutorial the player is
 * currently in and how far they have advanced, expressed as a single monotonically increasing
 * status code. The class methods answer whether a given tutorial (the music-select walkthrough,
 * the in-play walkthrough, the customise walkthrough, or the store walkthrough) still needs to be
 * shown and, once shown, advance the recorded status. Each advance is mirrored into the persisted
 * @c RBUserSettingData tutorial-status map (so the completed steps survive relaunches) and, for the
 * milestone steps, reported to the server through @c RBServerAPIManager.
 *
 * The "needs to start" predicates gate on the player being brand new: they only return @c YES while
 * @c ScoreData has no recorded plays, so a returning player is never dropped back into a tutorial.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBTutorialManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The tutorial-progression status codes.
 *
 * The value is a single cursor that walks forward through the guided tutorials. The music-select
 * walkthrough occupies the low range, the in-play walkthrough the next range, and the customise
 * walkthrough the range above that; the remaining values are the per-tutorial "seen" flags that are
 * also written into the persisted @c RBUserSettingData tutorial-status map, plus the terminal
 * sentinel. @c RBTutorialStatusNone is the initial value assigned when the singleton is created.
 */
typedef NS_ENUM(NSUInteger, RBTutorialStatus) {
    RBTutorialStatusMusicSelectStart = 0, /*!< First music-select walkthrough step; also the value
                                            *   below which @c +isTutorialMusicselect is true. */
    RBTutorialStatusPlayStart = 9,        /*!< The step at which the in-play walkthrough should
                                            *   begin (the top of the music-select range). */
    RBTutorialStatusPlayRangeStart = 10,  /*!< First in-play walkthrough step. */
    RBTutorialStatusMusicSelectSeen = 23, /*!< Persisted "music-select tutorial seen" flag. */
    RBTutorialStatusCustomizeStart = 24,  /*!< First customise walkthrough step. */
    RBTutorialStatusCustomizeSeen = 33,   /*!< Persisted "customise tutorial seen" flag. */
    RBTutorialStatusCustomizeEnd = 34,    /*!< Last customise walkthrough step; advances the cursor
                                            *   to @c RBTutorialStatusDone. */
    RBTutorialStatusStoreStart = 35,      /*!< First store walkthrough step. */
    RBTutorialStatusStoreSeen = 37,       /*!< Persisted "store tutorial seen" flag. */
    RBTutorialStatusDone = 40,            /*!< Terminal sentinel reached after the customise
                                            *   walkthrough finishes. */
    RBTutorialStatusNone = 0xffffffff,    /*!< No tutorial active; the initial singleton value. */
};

/**
 * @brief The tutorial-progression manager singleton.
 */
@interface RBTutorialManager : NSObject

#pragma mark Singleton

/**
 * @brief The shared tutorial manager, created on first use with its status set to
 *        @c RBTutorialStatusNone.
 * @ghidraAddress 0x356b8
 * @return The shared @c RBTutorialManager.
 */
+ (instancetype)getInstance;

#pragma mark Status queries

/**
 * @brief Whether the player is inside any tutorial, taken from the singleton's @c isTutorial flag.
 * @ghidraAddress 0x35724
 * @return @c YES while a tutorial is running.
 */
+ (BOOL)isTutorial;
/**
 * @brief The singleton's current tutorial status code.
 * @ghidraAddress 0x35d6c
 * @return The current @c RBTutorialStatus.
 */
+ (RBTutorialStatus)getCurrentStatus;

#pragma mark Music-select tutorial

/**
 * @brief Whether the music-select walkthrough still needs to be shown: only while the player has no
 *        recorded plays and @c RBUserSettingData has not stored the music-select "seen" flag.
 * @ghidraAddress 0x3578c
 * @return @c YES when the walkthrough should start.
 */
+ (BOOL)needStartTutorialMusicselect;
/**
 * @brief Begin the music-select walkthrough by advancing the status to
 *        @c RBTutorialStatusMusicSelectStart.
 * @ghidraAddress 0x35820
 */
+ (void)startTutorialMusicselect;
/**
 * @brief Whether the cursor is currently within the music-select walkthrough range.
 * @ghidraAddress 0x35838
 * @return @c YES while in the music-select walkthrough.
 */
+ (BOOL)isTutorialMusicselect;

#pragma mark In-play tutorial

/**
 * @brief Whether the in-play walkthrough still needs to be shown: only while the player has no
 *        recorded plays and the cursor is at @c RBTutorialStatusPlayStart.
 * @ghidraAddress 0x358ec
 * @return @c YES when the walkthrough should start.
 */
+ (BOOL)needStartTutorialPlay;
/**
 * @brief Whether the cursor is currently within the in-play walkthrough range.
 * @ghidraAddress 0x3597c
 * @return @c YES while in the in-play walkthrough.
 */
+ (BOOL)isTutorialPlay;

#pragma mark Customise tutorial

/**
 * @brief Whether the customise walkthrough still needs to be shown: only while the player has no
 *        recorded plays, @c RBExperienceData reports nothing unlocked, and @c RBUserSettingData has
 *        not stored the customise "seen" flag.
 * @ghidraAddress 0x35a40
 * @return @c YES when the walkthrough should start.
 */
+ (BOOL)needStartTutorialCustomize;
/**
 * @brief Begin the customise walkthrough by advancing the status to
 *        @c RBTutorialStatusCustomizeStart.
 * @ghidraAddress 0x35b24
 */
+ (void)startTutorialCustomize;
/**
 * @brief Whether the cursor is currently within the customise walkthrough range, only when the
 *        Colette theme is active.
 * @ghidraAddress 0x35b3c
 * @return @c YES while in the customise walkthrough.
 */
+ (BOOL)isTutorialCustomize;

#pragma mark Store tutorial

/**
 * @brief Whether the store walkthrough still needs to be shown: only while the player has no
 *        recorded plays and @c RBUserSettingData has not stored the store "seen" flag.
 * @ghidraAddress 0x35c50
 * @return @c YES when the walkthrough should start.
 */
+ (BOOL)needStartTutorialStore;
/**
 * @brief Begin the store walkthrough by advancing the status to @c RBTutorialStatusStoreStart.
 * @ghidraAddress 0x35ce4
 */
+ (void)startTutorialStore;

#pragma mark Status mutation

/**
 * @brief Record @p updateStatus as the new tutorial status: persist it into @c RBUserSettingData,
 *        store it on the singleton, apply the per-status side effects (setting or clearing the
 *        @c isTutorial flag, and advancing to @c RBTutorialStatusDone at the end of the customise
 *        walkthrough), and report the milestone statuses to the server.
 * @ghidraAddress 0x35dd4
 * @param updateStatus The new tutorial status.
 */
- (void)updateStatus:(RBTutorialStatus)updateStatus;

/**
 * @brief Record the type and item identifier of an item unlocked during the customise walkthrough,
 *        allocating the pair store on first use and resetting it on each subsequent call.
 * @param unlockedItemInfo The unlocked item's type.
 * @param itemId The unlocked item's identifier.
 * @ghidraAddress 0x36098
 */
+ (void)setUnlockedItemInfo:(int)unlockedItemInfo itemId:(int)itemId;

#pragma mark Properties

/**
 * @brief The singleton's current tutorial status code.
 * @ghidraAddress 0x3643c (getter)
 * @ghidraAddress 0x3644c (setter)
 */
@property(nonatomic, assign) RBTutorialStatus currentStatus;
/**
 * @brief Whether a tutorial is currently running.
 * @ghidraAddress 0x3645c (getter)
 * @ghidraAddress 0x3646c (setter)
 */
@property(nonatomic, assign) BOOL isTutorial;
/**
 * @brief The view presenting the active tutorial overlay, held weakly.
 * @ghidraAddress 0x3649c (getter)
 * @ghidraAddress 0x364bc (setter)
 */
@property(nonatomic, weak, nullable) UIView *tutorialView;

/**
 * @brief The pending unlocked-item info: a flat @c {itemInfo, itemId} pair queued by
 * @c +setUnlockedItemInfo:itemId:.
 * @ghidraAddress 0x364d0 (getter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *unlockItemInfo;

/**
 * @brief Clear the pending unlocked-item info.
 * @ghidraAddress 0x363a8
 */
+ (void)resetUnlockedItemInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
