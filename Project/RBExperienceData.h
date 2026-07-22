/** @file
 * The archivable unlock, campaign-point, and reward singleton. It tracks which cosmetic items
 * (background music, shots, explosions, frames, backgrounds, tunes, and themes) the player has
 * unlocked, the running campaign point totals for the two active themes, and the reward
 * application identifiers granted by installed companion applications. The instance persists
 * itself to and from the user defaults, keyed by its own class name, enciphering the point and
 * reward figures with a Blowfish codec so that they cannot be tampered with on disk.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBExperienceData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief The cosmetic item categories an unlock, add, or query can target.
 *
 * The raw values are the on-disk category tags used by @c addItem:ID: and @c unlockWithType:ID:.
 * They are deliberately sparse: the intervening values are reserved for categories this class does
 * not own.
 */
typedef NS_ENUM(NSInteger, RBExperienceItemType) {
    /// Background music items, held in @c bgmItems.
    RBExperienceItemTypeBGM = 0,
    /// Shot items, held in @c shotItems.
    RBExperienceItemTypeShot = 1,
    /// Explosion items, held in @c explosionItems. The binary spells this category "Exprosion".
    RBExperienceItemTypeExprosion = 2,
    /// Frame items, held in @c frameItems.
    RBExperienceItemTypeFrame = 3,
    /// Background items, held in @c backgroundItems.
    RBExperienceItemTypeBackground = 4,
    /// Tune items, held in @c musicItems.
    RBExperienceItemTypeMusic = 7,
    /// Theme items, held in @c themaItems.
    RBExperienceItemTypeThema = 10,
};

/**
 * @brief An archivable singleton of the player's unlocked items, campaign points, and rewards.
 */
@interface RBExperienceData : NSObject <NSCoding>

/**
 * @brief The reward application identifiers for a single companion application. This backing store
 * is transient scratch space; the persisted mapping lives in @c installedAppliIds.
 * @ghidraAddress 0x1bd0d0 (getter)
 * @ghidraAddress 0x1bd0e0 (setter)
 */
@property(nonatomic, assign) NSMutableArray *installedAppliId;
/**
 * @brief The running campaign point total for the first theme.
 * @ghidraAddress 0x1bd0f0 (getter)
 * @ghidraAddress 0x1bd100 (setter)
 */
@property(nonatomic, assign) float point;
/**
 * @brief The running campaign point total for the second theme.
 * @ghidraAddress 0x1bd110 (getter)
 * @ghidraAddress 0x1bd120 (setter)
 */
@property(nonatomic, assign) float pointB;
/**
 * @brief A spare campaign point total reset by @c initialized but not otherwise persisted.
 * @ghidraAddress 0x1bd130 (getter)
 * @ghidraAddress 0x1bd140 (setter)
 */
@property(nonatomic, assign) float pointC;
/**
 * @brief The bundle version string stamped into the archive when the instance is first created.
 * @ghidraAddress 0x1bd150 (getter)
 * @ghidraAddress 0x1bd160 (setter)
 */
@property(nonatomic, copy) NSString *version;
/**
 * @brief A spare date string.
 * @ghidraAddress 0x1bd16c (getter)
 * @ghidraAddress 0x1bd17c (setter)
 */
@property(nonatomic, copy) NSString *pointDate;
/**
 * @brief A spare point string.
 * @ghidraAddress 0x1bd188 (getter)
 * @ghidraAddress 0x1bd198 (setter)
 */
@property(nonatomic, copy) NSString *pointS;
/**
 * @brief A spare point string.
 * @ghidraAddress 0x1bd1a4 (getter)
 * @ghidraAddress 0x1bd1b4 (setter)
 */
@property(nonatomic, copy) NSString *pointP;
/**
 * @brief A spare position string.
 * @ghidraAddress 0x1bd1c0 (getter)
 * @ghidraAddress 0x1bd1d0 (setter)
 */
@property(nonatomic, copy) NSString *pos;
/**
 * @brief The enciphered on-disk form of @c point, produced by @c encodePoint:.
 * @ghidraAddress 0x1bd1dc (getter)
 * @ghidraAddress 0x1bd1ec (setter)
 */
@property(nonatomic, copy) NSMutableData *pointData;
/**
 * @brief The enciphered on-disk form of @c pointB, produced by @c encodePoint:.
 * @ghidraAddress 0x1bd1f8 (getter)
 * @ghidraAddress 0x1bd208 (setter)
 */
@property(nonatomic, copy) NSMutableData *pointDataB;
/**
 * @brief The enciphered on-disk form of @c pointC.
 * @ghidraAddress 0x1bd214 (getter)
 * @ghidraAddress 0x1bd224 (setter)
 */
@property(nonatomic, copy) NSMutableData *pointDataC;
/**
 * @brief The set of unlocked background-music item identifiers.
 * @ghidraAddress 0x1bd230 (getter)
 * @ghidraAddress 0x1bd240 (setter)
 */
@property(nonatomic, strong) NSMutableSet *bgmItems;
/**
 * @brief The set of unlocked shot item identifiers.
 * @ghidraAddress 0x1bd278 (getter)
 * @ghidraAddress 0x1bd288 (setter)
 */
@property(nonatomic, strong) NSMutableSet *shotItems;
/**
 * @brief The set of unlocked explosion item identifiers. The binary spells this "explosion".
 * @ghidraAddress 0x1bd2c0 (getter)
 * @ghidraAddress 0x1bd2d0 (setter)
 */
@property(nonatomic, strong) NSMutableSet *explosionItems;
/**
 * @brief The set of unlocked frame item identifiers.
 * @ghidraAddress 0x1bd308 (getter)
 * @ghidraAddress 0x1bd318 (setter)
 */
@property(nonatomic, strong) NSMutableSet *frameItems;
/**
 * @brief The set of unlocked background item identifiers.
 * @ghidraAddress 0x1bd350 (getter)
 * @ghidraAddress 0x1bd360 (setter)
 */
@property(nonatomic, strong) NSMutableSet *backgroundItems;
/**
 * @brief The set of unlocked tune item identifiers.
 * @ghidraAddress 0x1bd398 (getter)
 * @ghidraAddress 0x1bd3a8 (setter)
 */
@property(nonatomic, strong) NSMutableSet *musicItems;
/**
 * @brief The set of unlocked theme item identifiers.
 * @ghidraAddress 0x1bd3e0 (getter)
 * @ghidraAddress 0x1bd3f0 (setter)
 */
@property(nonatomic, strong) NSMutableSet *themaItems;
/**
 * @brief A mapping from a reward application identifier to the array of application identifiers it
 * has granted.
 * @ghidraAddress 0x1bd428 (getter)
 * @ghidraAddress 0x1bd438 (setter)
 */
@property(nonatomic, strong) NSMutableDictionary *installedAppliIds;
/**
 * @brief The enciphered on-disk form of @c installedAppliIds, produced by @c encodeAppliIds:.
 * @ghidraAddress 0x1bd470 (getter)
 * @ghidraAddress 0x1bd480 (setter)
 */
@property(nonatomic, strong) NSMutableData *installedAppliIdsData;

/**
 * @brief Returns the shared experience-data singleton, unarchiving it from the user defaults or
 * seeding a freshly initialised instance on first use.
 * @return The shared @c RBExperienceData instance.
 * @ghidraAddress 0x1b9cfc
 */
+ (instancetype)sharedInstance;

/**
 * @brief Archives the receiver and writes it to the user defaults, keyed by the class name.
 * @ghidraAddress 0x1b9e50
 */
- (void)save;

/**
 * @brief Seeds the default unlocked items, empty themes, and zeroed points on a fresh install.
 * @ghidraAddress 0x1bc104
 */
- (void)initialized;

/**
 * @brief Reports whether a background-music item is unlocked.
 * @param type The background-music item identifier.
 * @return @c YES if the item is unlocked.
 * @ghidraAddress 0x1b9f74
 */
- (BOOL)unlockWithBGMtype:(int)type;
/**
 * @brief Reports whether a shot item is unlocked.
 * @param type The shot item identifier.
 * @return @c YES if the item is unlocked.
 * @ghidraAddress 0x1ba0c8
 */
- (BOOL)unlockWithShotType:(int)type;
/**
 * @brief Reports whether an explosion item is unlocked.
 * @param type The explosion item identifier.
 * @return @c YES if the item is unlocked.
 * @ghidraAddress 0x1ba21c
 */
- (BOOL)unlockWithExprosionType:(int)type;
/**
 * @brief Reports whether a frame item is unlocked.
 * @param type The frame item identifier.
 * @return @c YES if the item is unlocked.
 * @ghidraAddress 0x1ba370
 */
- (BOOL)unlockWithFrameType:(int)type;
/**
 * @brief Reports whether a background item is unlocked.
 * @param type The background item identifier.
 * @return @c YES if the item is unlocked.
 * @ghidraAddress 0x1ba4c4
 */
- (BOOL)unlockWithBackgroundType:(int)type;
/**
 * @brief Reports whether a tune item is unlocked.
 * @param musicID The tune item identifier.
 * @return @c YES if the item is unlocked.
 * @ghidraAddress 0x1ba618
 */
- (BOOL)unlockWithMusicID:(int)musicID;
/**
 * @brief Reports whether a theme item is unlocked.
 * @param themaID The theme item identifier.
 * @return @c YES if the item is unlocked.
 * @ghidraAddress 0x1ba76c
 */
- (BOOL)unlockWithThemaID:(int)themaID;
/**
 * @brief Reports whether an item of a given category is unlocked.
 * @param type The item category, an @c RBExperienceItemType raw value.
 * @param ID The item identifier within that category.
 * @return @c YES if the item is unlocked.
 * @ghidraAddress 0x1ba8c0
 */
- (BOOL)unlockWithType:(int)type ID:(int)ID;

/**
 * @brief Unlocks a background-music item.
 * @param type The background-music item identifier.
 * @ghidraAddress 0x1ba980
 */
- (void)addBGMType:(int)type;
/**
 * @brief Unlocks a shot item.
 * @param type The shot item identifier.
 * @ghidraAddress 0x1baa24
 */
- (void)addShotType:(int)type;
/**
 * @brief Unlocks an explosion item.
 * @param type The explosion item identifier.
 * @ghidraAddress 0x1baac8
 */
- (void)addExprosionType:(int)type;
/**
 * @brief Unlocks a frame item.
 * @param type The frame item identifier.
 * @ghidraAddress 0x1bab6c
 */
- (void)addFrameType:(int)type;
/**
 * @brief Unlocks a background item.
 * @param type The background item identifier.
 * @ghidraAddress 0x1bac10
 */
- (void)addBackgroundType:(int)type;
/**
 * @brief Unlocks a tune item.
 * @param musicID The tune item identifier.
 * @ghidraAddress 0x1bad00
 */
- (void)addMusicID:(int)musicID;
/**
 * @brief Unlocks a theme item.
 * @param themaID The theme item identifier.
 * @ghidraAddress 0x1bad80
 */
- (void)addThemaID:(int)themaID;
/**
 * @brief Unlocks an item of a given category.
 * @param type The item category, an @c RBExperienceItemType raw value.
 * @param ID The item identifier within that category.
 * @ghidraAddress 0x1bae00
 */
- (void)addItem:(int)type ID:(int)ID;

/**
 * @brief Records that a reward application has granted an application identifier, persisting the
 * change immediately.
 * @param rewardAppliId The reward application identifier that granted the reward.
 * @param appliId The granted application identifier.
 * @return @c YES if a new grant was recorded, @c NO if it was already present or either argument
 * was @c nil.
 * @ghidraAddress 0x1baebc
 */
- (BOOL)addRewardAppliId:(id)rewardAppliId andAppliId:(id)appliId;
/**
 * @brief Returns the application identifiers granted by a reward application.
 * @param rewardAppliId The reward application identifier to look up.
 * @return The granted application identifiers, or an empty array if none.
 * @ghidraAddress 0x1bb0a0
 */
- (NSMutableArray *)getRewardAppliId:(id)rewardAppliId;

/**
 * @brief Adds points to the campaign total of the currently active theme.
 * @param point The points to add.
 * @ghidraAddress 0x1bb21c
 */
- (void)addPoint:(float)point;
/**
 * @brief Returns the campaign point total of the currently active theme.
 * @return The active theme's point total, or zero when no theme is active.
 * @ghidraAddress 0x1bb2fc
 */
- (float)getPoint;
/**
 * @brief Resets the campaign point total for a theme.
 * @param thema The theme whose total to reset; only the second theme is reset.
 * @ghidraAddress 0x1bb3a8
 */
- (void)resetPoint:(int)thema;

/**
 * @brief Rebuilds every unlocked-item set from the current level tables and saves.
 * @ghidraAddress 0x1bb3c4
 */
- (void)takeover;
/**
 * @brief Recomputes the campaign point total from every cleared score record and saves.
 * @return The recomputed active point total.
 * @ghidraAddress 0x1bba38
 */
- (float)takeoverPoint;

/**
 * @brief Reports whether the player has unlocked nothing beyond the default items.
 * @return @c YES when only the default items are present.
 * @ghidraAddress 0x1bce1c
 */
- (BOOL)noUnlocked;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
