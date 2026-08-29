/**
 * @file
 * The persisted user-settings singleton.
 *
 * It holds every player-adjustable option: the selected
 * theme, the per-theme customise items (BGM, shot, explosion, frame, background, and note types,
 * gauge and ghost styles, shot volume, and background brightness), the play options (difficulty,
 * difficulty level, game type, speed type, play and player colours, rival alpha, CPU level, and the
 * bounds, explosion, and damage effect styling), the first-run information flags, the news, terms,
 * and resource-download bookkeeping, the purchase totals, and the tutorial-status map. The instance
 * archives itself to and from the user defaults, keyed by its own class name, and seeds sensible
 * defaults on a fresh install.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBUserSettingData, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * The player theme identifiers stored in @c thema.
 */
typedef NS_ENUM(int, RBUserSettingDataTheme) {
    RBUserSettingDataThemeClassic = 0,   /*!< The Classic theme. */
    RBUserSettingDataThemeLimelight = 1, /*!< The Limelight theme. */
    RBUserSettingDataThemeColette = 2,   /*!< The Colette theme. */
};

NS_ASSUME_NONNULL_BEGIN

/**
 * An archivable singleton of every persisted user setting.
 */
@interface RBUserSettingData : NSObject <NSCoding>

#pragma mark Bookkeeping

/**
 * The application version that last wrote these settings.
 * @ghidraAddress 0x1f8610 (getter)
 * @ghidraAddress 0x1f8620 (setter)
 */
@property(nonatomic, strong) NSString *version;
/**
 * The currently selected player theme.
 * @ghidraAddress 0x1f8658 (getter)
 * @ghidraAddress 0x1f7594 (setter)
 */
@property(nonatomic, assign) RBUserSettingDataTheme thema;

#pragma mark Customise items (current theme)

/**
 * The BGM variant for the current theme.
 * @ghidraAddress 0x1f8668 (getter)
 * @ghidraAddress 0x1f8678 (setter)
 */
@property(nonatomic, assign) int bgmType;
/**
 * The shot effect for the current theme.
 * @ghidraAddress 0x1f8688 (getter)
 * @ghidraAddress 0x1f8698 (setter)
 */
@property(nonatomic, assign) int shotType;
/**
 * The explosion effect for the current theme.
 * @ghidraAddress 0x1f86a8 (getter)
 * @ghidraAddress 0x1f86b8 (setter)
 */
@property(nonatomic, assign) int explosionType;
/**
 * The frame effect for the current theme.
 * @ghidraAddress 0x1f86c8 (getter)
 * @ghidraAddress 0x1f86d8 (setter)
 */
@property(nonatomic, assign) int frameType;
/**
 * The background effect for the current theme.
 * @ghidraAddress 0x1f86e8 (getter)
 * @ghidraAddress 0x1f86f8 (setter)
 */
@property(nonatomic, assign) int backgroundType;
/**
 * The note appearance for the current theme.
 * @ghidraAddress 0x1f8708 (getter)
 * @ghidraAddress 0x1f8718 (setter)
 */
@property(nonatomic, assign) int noteType;
/**
 * The gauge style for the current theme.
 * @ghidraAddress 0x1f8728 (getter)
 * @ghidraAddress 0x1f8738 (setter)
 */
@property(nonatomic, assign) int gaugeStyle;
/**
 * The ghost style for the current theme.
 * @ghidraAddress 0x1f8748 (getter)
 * @ghidraAddress 0x1f8758 (setter)
 */
@property(nonatomic, assign) int ghostStyle;
/**
 * The note delay, in frames.
 * @ghidraAddress 0x1f8768 (getter)
 * @ghidraAddress 0x1f8778 (setter)
 */
@property(nonatomic, assign) int delayFrame;
/**
 * The shot volume for the current theme.
 * @ghidraAddress 0x1f8788 (getter)
 * @ghidraAddress 0x1f8798 (setter)
 */
@property(nonatomic, assign) float shotVolume;
/**
 * The rival ghost's opacity.
 * @ghidraAddress 0x1f87a8 (getter)
 * @ghidraAddress 0x1f87b8 (setter)
 */
@property(nonatomic, assign) float rivalAlpha;
/**
 * The background brightness for the current theme.
 * @ghidraAddress 0x1f87c8 (getter)
 * @ghidraAddress 0x1f87d8 (setter)
 */
@property(nonatomic, assign) float backgroundBrighness;
/**
 * The per-theme customise dictionaries, indexed by @c thema.
 * @ghidraAddress 0x1f87e8 (getter)
 * @ghidraAddress 0x1f87f8 (setter)
 */
@property(nonatomic, strong) NSArray *customizeItems;

#pragma mark Play options

/**
 * The CPU rival level.
 * @ghidraAddress 0x1f8830 (getter)
 * @ghidraAddress 0x1f8840 (setter)
 */
@property(nonatomic, assign) int cpuLevel;
/**
 * The play colour.
 * @ghidraAddress 0x1f8850 (getter)
 * @ghidraAddress 0x1f8860 (setter)
 */
@property(nonatomic, assign) int playColor;
/**
 * The player colour.
 * @ghidraAddress 0x1f8870 (getter)
 * @ghidraAddress 0x1f8880 (setter)
 */
@property(nonatomic, assign) int playerColor;
/**
 * The selected difficulty.
 * @ghidraAddress 0x1f8890 (getter)
 * @ghidraAddress 0x1f88a0 (setter)
 */
@property(nonatomic, assign) int difficulty;
/**
 * The selected difficulty level.
 * @ghidraAddress 0x1f88b0 (getter)
 * @ghidraAddress 0x1f88c0 (setter)
 */
@property(nonatomic, assign) int difficultyLevel;
/**
 * The selected game type.
 * @ghidraAddress 0x1f88d0 (getter)
 * @ghidraAddress 0x1f88e0 (setter)
 */
@property(nonatomic, assign) int gameType;
/**
 * The note-speed type.
 * @ghidraAddress 0x1f88f0 (getter)
 * @ghidraAddress 0x1f8900 (setter)
 */
@property(nonatomic, assign) int speedType;
/**
 * The bounds effect style.
 * @ghidraAddress 0x1f8910 (getter)
 * @ghidraAddress 0x1f8920 (setter)
 */
@property(nonatomic, assign) int boundsEffectStyle;
/**
 * The explosion effect size.
 * @ghidraAddress 0x1f8930 (getter)
 * @ghidraAddress 0x1f8940 (setter)
 */
@property(nonatomic, assign) float explosionEffectSize;
/**
 * The bounds effect size.
 * @ghidraAddress 0x1f8950 (getter)
 * @ghidraAddress 0x1f8960 (setter)
 */
@property(nonatomic, assign) float boundsEffectSize;
/**
 * The damage effect size.
 * @ghidraAddress 0x1f8970 (getter)
 * @ghidraAddress 0x1f8980 (setter)
 */
@property(nonatomic, assign) float damageEffectSize;

#pragma mark First-run information flags

/**
 * Whether the playlist information has been shown.
 * @ghidraAddress 0x1f8990 (getter)
 * @ghidraAddress 0x1f89a0 (setter)
 */
@property(nonatomic, assign) BOOL infoPlaylist;
/**
 * Whether the random information has been shown.
 * @ghidraAddress 0x1f89b0 (getter)
 * @ghidraAddress 0x1f89c0 (setter)
 */
@property(nonatomic, assign) BOOL infoRandom;
/**
 * Whether the how-to information has been shown for the first time.
 * @ghidraAddress 0x1f89d0 (getter)
 * @ghidraAddress 0x1f89e0 (setter)
 */
@property(nonatomic, assign) BOOL howtoFirstInfo;
/**
 * Whether the first music-selected information has been shown.
 * @ghidraAddress 0x1f89f0 (getter)
 * @ghidraAddress 0x1f8a00 (setter)
 */
@property(nonatomic, assign) BOOL musicSelectedFirstInfo;
/**
 * Whether a new customise item is present.
 * @ghidraAddress 0x1f8a10 (getter)
 * @ghidraAddress 0x1f8a20 (setter)
 */
@property(nonatomic, assign) BOOL newCustomItem;
/**
 * Whether a new theme is present.
 * @ghidraAddress 0x1f8a30 (getter)
 * @ghidraAddress 0x1f8a40 (setter)
 */
@property(nonatomic, assign) BOOL newThema;
/**
 * Whether the brightness information has been shown for the first time.
 * @ghidraAddress 0x1f8a50 (getter)
 * @ghidraAddress 0x1f8a60 (setter)
 */
@property(nonatomic, assign) BOOL brightnessFirstInfo;

#pragma mark News, terms, and resource download

/**
 * The identifier of the most recently seen news item.
 * @ghidraAddress 0x1f8a70 (getter)
 * @ghidraAddress 0x1f8a80 (setter)
 */
@property(nonatomic, assign) int newsInfomationID;
/**
 * The timestamp string of the last news update.
 * @ghidraAddress 0x1f8a90 (getter)
 * @ghidraAddress 0x1f8aa0 (setter)
 */
@property(copy, nonatomic) NSString *lastUpdateTimeString;
/**
 * The timestamp string when the news was last read.
 * @ghidraAddress 0x1f8aac (getter)
 * @ghidraAddress 0x1f8abc (setter)
 */
@property(copy, nonatomic) NSString *infoLastReadTimeString;
/**
 * The version string of the accepted terms.
 * @ghidraAddress 0x1f8ac8 (getter)
 * @ghidraAddress 0x1f8ad8 (setter)
 */
@property(copy, nonatomic, nullable) NSString *termVersion;
/**
 * The timestamp string of the last terms update.
 * @ghidraAddress 0x1f8ae4 (getter)
 * @ghidraAddress 0x1f8af4 (setter)
 */
@property(copy, nonatomic) NSString *termLastUpdateTimeString;
/**
 * The timestamp string when the terms were last read.
 * @ghidraAddress 0x1f8b00 (getter)
 * @ghidraAddress 0x1f8b10 (setter)
 */
@property(copy, nonatomic) NSString *termLastReadTimeString;
/**
 * Whether the takeover-point prompt is pending.
 * @ghidraAddress 0x1f8b1c (getter)
 * @ghidraAddress 0x1f8b2c (setter)
 */
@property(nonatomic, assign) BOOL takeoverPoint;
/**
 * The version string of the downloaded resource pack.
 * @ghidraAddress 0x1f8b3c (getter)
 * @ghidraAddress 0x1f8b4c (setter)
 */
@property(copy, nonatomic) NSString *resourceDownloadVersion;
/**
 * Whether the resource download is paused.
 * @ghidraAddress 0x1f8b58 (getter)
 * @ghidraAddress 0x1f8b68 (setter)
 */
@property(nonatomic, assign) BOOL resourceDownloadPause;

#pragma mark Playlist and menu

/**
 * The selected playlist identifier.
 * @ghidraAddress 0x1f8b78 (getter)
 * @ghidraAddress 0x1f8b88 (setter)
 */
@property(nonatomic, assign) int playlistID;
/**
 * The selected playlist level.
 * @ghidraAddress 0x1f8b98 (getter)
 * @ghidraAddress 0x1f8ba8 (setter)
 */
@property(nonatomic, assign) int playlistLevel;
/**
 * The menu item sort order.
 * @ghidraAddress 0x1f8bb8 (getter)
 * @ghidraAddress 0x1f8bc8 (setter)
 */
@property(nonatomic, assign) int menuItemSort;

#pragma mark Purchases

/**
 * The month of the most recent purchase.
 * @ghidraAddress 0x1f8bd8 (getter)
 * @ghidraAddress 0x1f8be8 (setter)
 */
@property(nonatomic, assign) int lastPurchaseMonth;
/**
 * The running purchase total.
 * @ghidraAddress 0x1f8bf8 (getter)
 * @ghidraAddress 0x1f8c08 (setter)
 */
@property(nonatomic, assign) int totalPurchase;
/**
 * The purchase-limit classification.
 * @ghidraAddress 0x1f8c18 (getter)
 * @ghidraAddress 0x1f8c28 (setter)
 */
@property(nonatomic, assign) int purchaseLimitType;
/**
 * Whether store BGM samples are refused.
 * @ghidraAddress 0x1f8c38 (getter)
 * @ghidraAddress 0x1f8c48 (setter)
 */
@property(nonatomic, assign) BOOL refuseStoreSampleBGM;

#pragma mark Miscellaneous flags

/**
 * Whether the erosion mark has been updated.
 * @ghidraAddress 0x1f8c58 (getter)
 * @ghidraAddress 0x1f8c68 (setter)
 */
@property(nonatomic, assign) BOOL updatedErosionMark;
/**
 * Whether the user has achieved a full combo.
 * @ghidraAddress 0x1f8c78 (getter)
 * @ghidraAddress 0x1f8c88 (setter)
 */
@property(nonatomic, assign) BOOL userFullCombo;
/**
 * Whether the CPU rival has achieved a full combo.
 * @ghidraAddress 0x1f8c98 (getter)
 * @ghidraAddress 0x1f8ca8 (setter)
 */
@property(nonatomic, assign) BOOL cpuFullCombo;
/**
 * Whether every note was a full-just reflec.
 * @ghidraAddress 0x1f8cb8 (getter)
 * @ghidraAddress 0x1f8cc8 (setter)
 */
@property(nonatomic, assign) BOOL fullJustReflec;
/**
 * Whether the versus pastel option is enabled.
 * @ghidraAddress 0x1f8cd8 (getter)
 * @ghidraAddress 0x1f8ce8 (setter)
 */
@property(nonatomic, assign) BOOL vsPastel;
/**
 * Whether the title-screen caution has been read.
 * @ghidraAddress 0x1f8cf8 (getter)
 * @ghidraAddress 0x1f8d08 (setter)
 */
@property(nonatomic, assign) BOOL alreadyReadTitleCaution;

#pragma mark Tutorial state

/**
 * The tutorial-status map, keyed by tutorial identifier.
 * @ghidraAddress 0x1f8d18 (getter)
 * @ghidraAddress 0x1f8d28 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *tutorialStatuses;

#pragma mark Singleton and persistence

/**
 * Returns the shared user-settings singleton, unarchiving it from the user defaults or
 * seeding a fresh default-valued instance on first use.
 * @return The shared @c RBUserSettingData instance.
 * @ghidraAddress 0x1f7cb4
 */
+ (instancetype)sharedInstance;

/**
 * Archives the receiver and writes it to the user defaults, keyed by the class name.
 * @ghidraAddress 0x1f7ee8
 */
- (void)save;

/**
 * Restores every setting to its shipped default value.
 * @ghidraAddress 0x1f4288
 */
- (void)setDefault;

#pragma mark Theme helpers

/**
 * Returns the resource name of the currently selected theme.
 * @return The theme's resource name.
 * @ghidraAddress 0x1f800c
 */
- (NSString *)themaName;

/**
 * Returns the bundle resource path for the currently selected theme.
 * @return The theme's resource path in the main bundle.
 * @ghidraAddress 0x1f8048
 */
- (nullable NSString *)themaPath;

/**
 * Returns the resource name for a specific theme identifier.
 * @param themaID The theme identifier.
 * @return The theme's resource name, or the fallback name for an unrecognised identifier.
 * @ghidraAddress 0x1f80fc
 */
+ (NSString *)themaNameWithID:(RBUserSettingDataTheme)themaID;

#pragma mark Customise-item resets

/**
 * Sets the BGM type and mirrors it into the current theme's customise dictionary.
 * @param bgmType The new BGM type.
 * @ghidraAddress 0x1f6ba0
 */
- (void)resetBgmType:(int)bgmType;

/**
 * Sets the shot type and mirrors it into the current theme's customise dictionary.
 * @param shotType The new shot type.
 * @ghidraAddress 0x1f6cac
 */
- (void)resetShotType:(int)shotType;

/**
 * Sets the explosion type and mirrors it into the current theme's customise dictionary.
 * @param explosionType The new explosion type.
 * @ghidraAddress 0x1f6db8
 */
- (void)resetExplosionType:(int)explosionType;

/**
 * Sets the frame type and mirrors it into the current theme's customise dictionary.
 * @param frameType The new frame type.
 * @ghidraAddress 0x1f6ec4
 */
- (void)resetFrameType:(int)frameType;

/**
 * Sets the background type and mirrors it into the current theme's customise dictionary.
 * @param backgroundType The new background type.
 * @ghidraAddress 0x1f6fd0
 */
- (void)resetBackgroundType:(int)backgroundType;

/**
 * Sets the note type and mirrors it into the current theme's customise dictionary.
 * @param noteType The new note type.
 * @ghidraAddress 0x1f70dc
 */
- (void)resetNoteType:(int)noteType;

/**
 * Sets the gauge style and mirrors it into the current theme's customise dictionary.
 * @param gaugeStyle The new gauge style.
 * @ghidraAddress 0x1f71e8
 */
- (void)resetGaugeStyle:(int)gaugeStyle;

/**
 * Sets the ghost style, clearing the full-combo flags when the danger ghost style is chosen.
 * @param ghostStyle The new ghost style.
 * @ghidraAddress 0x1f72f4
 */
- (void)resetGhostStyle:(int)ghostStyle;

/**
 * Sets the shot volume and mirrors it into the current theme's customise dictionary.
 * @param shotVolume The new shot volume.
 * @ghidraAddress 0x1f736c
 */
- (void)resetShotVolume:(float)shotVolume;

/**
 * Sets the background brightness and mirrors it into the current theme's customise
 * dictionary.
 * @param backgroundBrightness The new background brightness.
 * @ghidraAddress 0x1f7480
 */
- (void)resetBackgroundBrightness:(float)backgroundBrightness;

#pragma mark Terms and tutorial

/**
 * Reports whether the accepted terms are older than the supplied version.
 * @param version The latest terms version to compare against the accepted version.
 * @return @c YES when the terms must be updated (or either version is missing).
 * @ghidraAddress 0x1f8160
 */
- (BOOL)needUpdateTerms:(nullable NSString *)version;

/**
 * Records a tutorial's status and immediately persists the settings.
 * @param status The tutorial identifier.
 * @param value The status value to store.
 * @ghidraAddress 0x1f8234
 */
- (void)updateTutorialStatus:(unsigned int)status value:(unsigned int)value;

/**
 * Returns the stored status value for a tutorial identifier.
 * @param status The tutorial identifier.
 * @return The stored status value, or zero when none has been recorded.
 * @ghidraAddress 0x1f83a4
 */
- (unsigned int)getTutorialStatus:(unsigned int)status;

/**
 * Returns the list of tutorial identifiers that have a recorded status.
 * @return A mutable array of the recorded tutorial keys.
 * @ghidraAddress 0x1f8494
 */
- (NSMutableArray *)getTutorialStatusList;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
