//
//  RBUserSettingData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBUserSettingData). Verified
//  against the arm64 disassembly: every archive key was read from its literal, the archive order
//  was taken from the send order, and each customise dictionary was recovered from the key and
//  value arrays that -dictionaryWithObjects:forKeys:count: is handed.
//

#import "RBUserSettingData.h"

#import "deviceenvironment.h"
#import "neDebugLog.h"

// Archive keys for the scalar and object settings. They match the shipped literals verbatim.
static NSString *const kVersionCoderKey = @"kVersion";
static NSString *const kThemaCoderKey = @"kThemaKey";
static NSString *const kBGMTypeCoderKey = @"kBGMTypeKey";
static NSString *const kShotTypeCoderKey = @"kShotTypeKey";
static NSString *const kExplosionTypeCoderKey = @"kExplosionTypeKey";
static NSString *const kFrameTypeCoderKey = @"kFrameTypeKey";
static NSString *const kBackgroundTypeCoderKey = @"kBackgroundTypeKey";
static NSString *const kNoteTypeCoderKey = @"kNoteTypeKey";
static NSString *const kGaugeStyleCoderKey = @"kGaugeStyleKey";
static NSString *const kGhostStyleCoderKey = @"kGhostStyleKey";
static NSString *const kShotVolumeCoderKey = @"kShotVolumeKey";
static NSString *const kBackgroundBrighnessCoderKey = @"kBackgroundBrighnessKey";
static NSString *const kCustomizeItemCoderKey = @"kCustomizeItemKey";
static NSString *const kTutorialStatusesCoderKey = @"kTutorialStatusesKey";
static NSString *const kCPULevelCoderKey = @"kCPULevelKey";
static NSString *const kPlayerColorCoderKey = @"kPlayerColorKey";
static NSString *const kDifficultyLevelCoderKey = @"kDifficultyLevelKey";
static NSString *const kSpeedTypeCoderKey = @"kSpeedTypeKey";
static NSString *const kRivalAlphaCoderKey = @"kRivalAlphaKey";
static NSString *const kBoundsEffectStyleCoderKey = @"kBoundsEffectStyleKey";
static NSString *const kExplosionEffectSizeCoderKey = @"kExplosionEffectSizeKey";
static NSString *const kBoundsEffectSizeCoderKey = @"kBoundsEffectSizeKey";
static NSString *const kDamageEffectSizeCoderKey = @"kDamageEffectSizeKey";
static NSString *const kInfoPlaylistCoderKey = @"kInfoPlaylistKey";
static NSString *const kInfoRandomCoderKey = @"kInfoRandomKey";
static NSString *const kHowtoFirstInfoCoderKey = @"kHowtoFirstInfoKey";
static NSString *const kMusicSelectedFirstInfoCoderKey = @"kMusicSelectedFirstInfoKey";
static NSString *const kNewCustomItemCoderKey = @"kNewCustomItemKey";
static NSString *const kNewThemaCoderKey = @"kNewThemaKey";
static NSString *const kBrightnessFirstInfoCoderKey = @"kBrightnessFirstInfoKey";
static NSString *const kNewsInfomationIDCoderKey = @"kNewsInfomationIDKey";
static NSString *const kLastUpdateTimeStringCoderKey = @"kLastUpdateTimeStringKey";
static NSString *const kInfoLastReadTimeStringCoderKey = @"kInfoLastReadTimeStringKey";
static NSString *const kTermVersionCoderKey = @"kTermVersion";
static NSString *const kTermLastUpdateTimeStringCoderKey = @"kTermLastUpdateTimeStringKey";
static NSString *const kTermLastReadTimeStringCoderKey = @"kTermLastReadTimeStringKey";
static NSString *const kTakeoverPointCoderKey = @"kTakeoverPointKey";
static NSString *const kResourceDownloadVersionCoderKey = @"kResourceDownloadVersionKey";
static NSString *const kResourceDownloadPauseCoderKey = @"kResourceDownloadPauseKey";
static NSString *const kPlaylistIDCoderKey = @"kPlaylistIDKey";
static NSString *const kPlaylistLevelCoderKey = @"kPlaylistLevelKey";
static NSString *const kMenuItemSortCoderKey = @"kMenuItemSortKey";
static NSString *const kLastPurchaseMonthCoderKey = @"kLastPurchaseMonth";
static NSString *const kTotalPurchaseCoderKey = @"kTotalPurchase";
static NSString *const kPurchaseLimitTypeCoderKey = @"kPurchaseLimitType";
static NSString *const kRefuseStoreSampleBGMCoderKey = @"kRefuseStoreSampleBGM";
static NSString *const kDelayFrameCoderKey = @"kDelayFrameKey";
static NSString *const kUpdatedErosionMarkCoderKey = @"kUpdatedErosionMark";
static NSString *const kUserFullComboCoderKey = @"kUserFullComboKey";
static NSString *const kCpuFullComboCoderKey = @"kCpuFullComboKey";
static NSString *const kFullJustReflecCoderKey = @"kFullJustReflecKey";
static NSString *const kVsPastelCoderKey = @"kVsPastel";
static NSString *const kAlreadyReadTitleCautionCoderKey = @"kAlreadyReadTitleCaution";

// Resource names for each theme, returned by @c +themaNameWithID:.
static NSString *const kThemaNameClassic = @"01_Classic";
static NSString *const kThemaNameLimelight = @"02_Limelight";
static NSString *const kThemaNameColette = @"03_Colette";
static NSString *const kThemaNameFallback = @"original";
// The resource extension of a theme bundle.
static NSString *const kThemaBundleExtension = @"bundle";

// The seed timestamp for the news and terms bookkeeping on a fresh install.
static NSString *const kDefaultTimeString = @"200001010000";
// The seed version for the downloaded resource pack on a fresh install.
static NSString *const kDefaultResourceDownloadVersion = @"0.0.0";

// The number of customise entries stored per theme dictionary.
static const NSUInteger kCustomizeItemCount = 9;
// The number of themes with their own customise dictionary.
static const NSUInteger kCustomizeThemaCount = 3;

// The shipped default settings seeded by @c setDefault.
static const int kDefaultBgmType = 15;
static const int kDefaultExplosionType = 12;
static const int kDefaultFrameType = 14;
static const int kDefaultBackgroundType = 13;
static const float kDefaultShotVolume = 1.0f;
static const float kDefaultRivalAlpha = 1.0f;
static const float kDefaultBackgroundBrighness = 1.0f;
static const float kDefaultExplosionEffectSize = 0.9f;
static const float kDefaultBoundsEffectSize = 1.0f;
static const float kDefaultDamageEffectSize = 1.0f;
static const int kDefaultCpuLevel = 2;
static const int kDefaultPlayerColor = 2;
static const int kDefaultBoundsEffectStyle = 1;
// The bounds-effect style selected when a theme has no stored customise dictionary.
static const int kBoundsEffectStyleFallback = 1;
// The ghost style that clears the full-combo flags when selected.
static const int kGhostStyleDanger = 1;

// The classic-theme customise defaults (all effects off, unit volume and brightness).
static const int kClassicBgmType = 0;
static const int kClassicExplosionType = 0;
static const int kClassicFrameType = 0;
static const int kClassicBackgroundType = 0;
// The limelight-theme customise defaults.
static const int kLimelightBgmType = 1;
static const int kLimelightExplosionType = 1;
static const int kLimelightFrameType = 7;
static const int kLimelightBackgroundType = 6;
// The colette-theme customise defaults.
static const int kColetteBgmType = 15;
static const int kColetteExplosionType = 12;
static const int kColetteFrameType = 14;
static const int kColetteBackgroundType = 13;

// Builds one theme's customise dictionary from the supplied option values.
static NSMutableDictionary *
RBMakeCustomizeItem(int bgmType, int explosionType, int frameType, int backgroundType) {
    return [@{
        kBGMTypeCoderKey : @((NSUInteger)bgmType),
        kShotTypeCoderKey : @((NSUInteger)0),
        kExplosionTypeCoderKey : @((NSUInteger)explosionType),
        kFrameTypeCoderKey : @((NSUInteger)frameType),
        kBackgroundTypeCoderKey : @((NSUInteger)backgroundType),
        kNoteTypeCoderKey : @((NSUInteger)0),
        kGaugeStyleCoderKey : @((NSUInteger)0),
        kShotVolumeCoderKey : @(kDefaultShotVolume),
        kBackgroundBrighnessCoderKey : @(kDefaultBackgroundBrighness),
    } mutableCopy];
}

// Mirrors one option into the current theme's customise dictionary. The binary inlines this block
// into each of the reset methods; it is a plain function rather than a method because the class
// metadata defines no such selector.
static void
RBWriteCustomizeValue(RBUserSettingData *settings, NSNumber *value, NSString *key) {
    NSMutableDictionary *item = settings.customizeItems[settings.thema];
    [item setValue:value forKey:key];
}

@implementation RBUserSettingData

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x1f4214 */
    self = [super init];
    if (self) {
        [self setDefault];
    }
    return self;
}

- (void)setDefault {
    /** @ghidraAddress 0x1f4288 */
    self.thema = RBUserSettingDataThemeColette;
    self.version = GetBundleVersionString();
    self.shotType = 0;
    self.bgmType = kDefaultBgmType;
    self.explosionType = kDefaultExplosionType;
    self.frameType = kDefaultFrameType;
    self.backgroundType = kDefaultBackgroundType;
    self.playlistID = 0;
    self.playlistLevel = 0;
    self.noteType = 0;
    self.gaugeStyle = 0;
    self.ghostStyle = 0;
    self.shotVolume = kDefaultShotVolume;
    self.rivalAlpha = kDefaultRivalAlpha;
    self.backgroundBrighness = kDefaultBackgroundBrighness;

    NSMutableDictionary *classic = RBMakeCustomizeItem(
        kClassicBgmType, kClassicExplosionType, kClassicFrameType, kClassicBackgroundType);
    NSMutableDictionary *limelight = RBMakeCustomizeItem(
        kLimelightBgmType, kLimelightExplosionType, kLimelightFrameType, kLimelightBackgroundType);
    NSMutableDictionary *colette = RBMakeCustomizeItem(
        kColetteBgmType, kColetteExplosionType, kColetteFrameType, kColetteBackgroundType);
    self.customizeItems = [[NSMutableArray alloc] initWithArray:@[ classic, limelight, colette ]];
    self.tutorialStatuses = [[NSMutableDictionary alloc] init];

    self.cpuLevel = kDefaultCpuLevel;
    self.playerColor = kDefaultPlayerColor;
    self.difficulty = 0;
    self.difficultyLevel = 0;
    self.gameType = 0;
    self.speedType = 0;
    self.boundsEffectStyle = kDefaultBoundsEffectStyle;
    self.explosionEffectSize = kDefaultExplosionEffectSize;
    self.boundsEffectSize = kDefaultBoundsEffectSize;
    self.damageEffectSize = kDefaultDamageEffectSize;
    self.infoPlaylist = NO;
    self.infoRandom = NO;
    self.howtoFirstInfo = NO;
    self.musicSelectedFirstInfo = NO;
    self.newCustomItem = NO;
    self.newThema = NO;
    self.brightnessFirstInfo = NO;
    self.newsInfomationID = 0;
    self.lastUpdateTimeString = kDefaultTimeString;
    self.infoLastReadTimeString = kDefaultTimeString;
    self.termVersion = nil;
    self.termLastUpdateTimeString = kDefaultTimeString;
    self.termLastReadTimeString = kDefaultTimeString;
    self.takeoverPoint = NO;
    self.resourceDownloadVersion = kDefaultResourceDownloadVersion;
    self.resourceDownloadPause = NO;
    self.menuItemSort = 0;
    self.lastPurchaseMonth = 0;
    self.totalPurchase = 0;
    self.purchaseLimitType = 0;
    self.refuseStoreSampleBGM = NO;
    self.delayFrame = 0;
    self.updatedErosionMark = NO;
    self.cpuFullCombo = NO;
    self.userFullCombo = NO;
    self.fullJustReflec = NO;
    self.vsPastel = NO;
    self.alreadyReadTitleCaution = NO;
}

#pragma mark - Singleton and persistence

// @ghidraAddress 0x1f7cb4 (g_pRBUserSettingDataSharedInstance)
+ (instancetype)sharedInstance {
    /** @ghidraAddress 0x1f7cb4 */
    static RBUserSettingData *instance = nil;
    if (instance == nil) {
        NSString *key = NSStringFromClass([self class]);
        if ([[[NSUserDefaults standardUserDefaults] dictionaryRepresentation].allKeys
                containsObject:key]) {
            NSData *archived = [[NSUserDefaults standardUserDefaults] dataForKey:key];
            instance = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
        }
        if (instance == nil) {
            instance = [[RBUserSettingData alloc] init];
        }
        // RBPDBG: says whether the defaults entry existed at all, and whether the decode brought
        // the tutorial dictionary back with it.
        if (NE_DBG_FIRST(6)) {
            neDebugLog("tutorialPersist load key=%s present=%d tutorials=%lu",
                       NSStringFromClass([self class]).UTF8String,
                       [[NSUserDefaults standardUserDefaults] dataForKey:NSStringFromClass(
                                                                            [self class])] != nil,
                       (unsigned long)instance.tutorialStatuses.count);
        }
    }
    return instance;
}

- (void)save {
    /** @ghidraAddress 0x1f7ee8 */
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:self];
    [[NSUserDefaults standardUserDefaults] setObject:archived
                                              forKey:NSStringFromClass([self class])];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // RBPDBG: a zero or absent byte count means the archive itself failed, which is silent.
    if (NE_DBG_FIRST(40)) {
        neDebugLog("tutorialPersist save bytes=%lu tutorials=%lu readback=%lu",
                   (unsigned long)archived.length,
                   (unsigned long)self.tutorialStatuses.count,
                   (unsigned long)[[NSUserDefaults standardUserDefaults]
                                      dataForKey:NSStringFromClass([self class])]
                       .length);
    }
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    /** @ghidraAddress 0x1f5038 */
    self = [super init];
    if (self == nil) {
        return nil;
    }

    self.version = [coder decodeObjectForKey:kVersionCoderKey];
    if (self.version == nil) {
        // A pre-versioning archive is upgraded to the current defaults.
        [self setDefault];
        self.version = GetBundleVersionString();
    } else {
        self.thema = [coder decodeInt32ForKey:kThemaCoderKey];
        self.customizeItems = [coder decodeObjectForKey:kCustomizeItemCoderKey];
        // The theme-specific customise items override the flat option ivars.
        NSDictionary *item = self.customizeItems[self.thema];
        self.bgmType = [item[kBGMTypeCoderKey] intValue];
        self.shotType = [item[kShotTypeCoderKey] intValue];
        self.explosionType = [item[kExplosionTypeCoderKey] intValue];
        self.frameType = [item[kFrameTypeCoderKey] intValue];
        self.backgroundType = [item[kBackgroundTypeCoderKey] intValue];
        self.noteType = [item[kNoteTypeCoderKey] intValue];
        self.gaugeStyle = [item[kGaugeStyleCoderKey] intValue];
        self.shotVolume = [item[kShotVolumeCoderKey] floatValue];
        self.backgroundBrighness = [item[kBackgroundBrighnessCoderKey] floatValue];
    }

    self.tutorialStatuses = [coder decodeObjectForKey:kTutorialStatusesCoderKey];
    self.cpuLevel = [coder decodeInt32ForKey:kCPULevelCoderKey];
    self.playerColor = [coder decodeInt32ForKey:kPlayerColorCoderKey];
    self.difficultyLevel = [coder decodeInt32ForKey:kDifficultyLevelCoderKey];
    self.speedType = [coder decodeInt32ForKey:kSpeedTypeCoderKey];
    self.rivalAlpha = [coder decodeFloatForKey:kRivalAlphaCoderKey];
    self.boundsEffectStyle = [coder decodeInt32ForKey:kBoundsEffectStyleCoderKey];
    self.explosionEffectSize = [coder decodeFloatForKey:kExplosionEffectSizeCoderKey];
    self.boundsEffectSize = [coder decodeFloatForKey:kBoundsEffectSizeCoderKey];
    self.damageEffectSize = [coder decodeFloatForKey:kDamageEffectSizeCoderKey];
    self.infoPlaylist = [coder decodeBoolForKey:kInfoPlaylistCoderKey];
    self.infoRandom = [coder decodeBoolForKey:kInfoRandomCoderKey];
    self.howtoFirstInfo = [coder decodeBoolForKey:kHowtoFirstInfoCoderKey];
    self.musicSelectedFirstInfo = [coder decodeBoolForKey:kMusicSelectedFirstInfoCoderKey];
    self.newCustomItem = [coder decodeBoolForKey:kNewCustomItemCoderKey];
    self.newThema = [coder decodeBoolForKey:kNewThemaCoderKey];
    self.brightnessFirstInfo = [coder decodeBoolForKey:kBrightnessFirstInfoCoderKey];
    self.newsInfomationID = [coder decodeInt32ForKey:kNewsInfomationIDCoderKey];

    self.lastUpdateTimeString = [coder decodeObjectForKey:kLastUpdateTimeStringCoderKey];
    if (self.lastUpdateTimeString == nil) {
        self.lastUpdateTimeString = kDefaultTimeString;
    }
    self.infoLastReadTimeString = [coder decodeObjectForKey:kInfoLastReadTimeStringCoderKey];
    if (self.infoLastReadTimeString == nil) {
        self.infoLastReadTimeString = kDefaultTimeString;
    }
    self.termVersion = [coder decodeObjectForKey:kTermVersionCoderKey];
    self.termLastUpdateTimeString = [coder decodeObjectForKey:kTermLastUpdateTimeStringCoderKey];
    if (self.termLastUpdateTimeString == nil) {
        self.termLastUpdateTimeString = kDefaultTimeString;
    }
    self.termLastReadTimeString = [coder decodeObjectForKey:kTermLastReadTimeStringCoderKey];
    if (self.termLastReadTimeString == nil) {
        self.termLastReadTimeString = kDefaultTimeString;
    }
    self.takeoverPoint = [coder decodeBoolForKey:kTakeoverPointCoderKey];
    self.resourceDownloadVersion = [coder decodeObjectForKey:kResourceDownloadVersionCoderKey];
    if (self.resourceDownloadVersion == nil) {
        self.resourceDownloadVersion = kDefaultResourceDownloadVersion;
    }
    self.resourceDownloadPause = [coder decodeBoolForKey:kResourceDownloadPauseCoderKey];
    self.playlistID = [coder decodeInt32ForKey:kPlaylistIDCoderKey];
    self.playlistLevel = [coder decodeInt32ForKey:kPlaylistLevelCoderKey];
    self.menuItemSort = [coder decodeInt32ForKey:kMenuItemSortCoderKey];
    self.lastPurchaseMonth = [coder decodeInt32ForKey:kLastPurchaseMonthCoderKey];
    self.totalPurchase = [coder decodeInt32ForKey:kTotalPurchaseCoderKey];
    self.purchaseLimitType = [coder decodeInt32ForKey:kPurchaseLimitTypeCoderKey];
    self.refuseStoreSampleBGM = [coder decodeBoolForKey:kRefuseStoreSampleBGMCoderKey];
    self.delayFrame = [coder decodeInt32ForKey:kDelayFrameCoderKey];
    self.updatedErosionMark = [coder decodeBoolForKey:kUpdatedErosionMarkCoderKey];
    self.ghostStyle = [coder decodeInt32ForKey:kGhostStyleCoderKey];
    self.userFullCombo = [coder decodeBoolForKey:kUserFullComboCoderKey];
    self.cpuFullCombo = [coder decodeBoolForKey:kCpuFullComboCoderKey];
    self.fullJustReflec = [coder decodeBoolForKey:kFullJustReflecCoderKey];
    self.vsPastel = [coder decodeBoolForKey:kVsPastelCoderKey];
    self.alreadyReadTitleCaution = [coder decodeBoolForKey:kAlreadyReadTitleCautionCoderKey];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    /** @ghidraAddress 0x1f6214 */
    [coder encodeObject:self.version forKey:kVersionCoderKey];
    [coder encodeInt32:(int)self.thema forKey:kThemaCoderKey];
    [coder encodeInt32:self.bgmType forKey:kBGMTypeCoderKey];
    [coder encodeInt32:self.shotType forKey:kShotTypeCoderKey];
    [coder encodeInt32:self.explosionType forKey:kExplosionTypeCoderKey];
    [coder encodeInt32:self.frameType forKey:kFrameTypeCoderKey];
    [coder encodeInt32:self.backgroundType forKey:kBackgroundTypeCoderKey];
    [coder encodeInt32:self.noteType forKey:kNoteTypeCoderKey];
    [coder encodeInt32:self.gaugeStyle forKey:kGaugeStyleCoderKey];
    [coder encodeInt32:self.ghostStyle forKey:kGhostStyleCoderKey];
    [coder encodeFloat:self.shotVolume forKey:kShotVolumeCoderKey];
    [coder encodeFloat:self.backgroundBrighness forKey:kBackgroundBrighnessCoderKey];
    [coder encodeObject:self.customizeItems forKey:kCustomizeItemCoderKey];
    [coder encodeObject:self.tutorialStatuses forKey:kTutorialStatusesCoderKey];
    [coder encodeInt32:self.cpuLevel forKey:kCPULevelCoderKey];
    [coder encodeInt32:self.playerColor forKey:kPlayerColorCoderKey];
    [coder encodeInt32:self.difficultyLevel forKey:kDifficultyLevelCoderKey];
    [coder encodeInt32:self.speedType forKey:kSpeedTypeCoderKey];
    [coder encodeFloat:self.rivalAlpha forKey:kRivalAlphaCoderKey];
    [coder encodeInt32:self.boundsEffectStyle forKey:kBoundsEffectStyleCoderKey];
    [coder encodeFloat:self.explosionEffectSize forKey:kExplosionEffectSizeCoderKey];
    [coder encodeFloat:self.boundsEffectSize forKey:kBoundsEffectSizeCoderKey];
    [coder encodeFloat:self.damageEffectSize forKey:kDamageEffectSizeCoderKey];
    [coder encodeBool:self.infoPlaylist forKey:kInfoPlaylistCoderKey];
    [coder encodeBool:self.infoRandom forKey:kInfoRandomCoderKey];
    [coder encodeBool:self.howtoFirstInfo forKey:kHowtoFirstInfoCoderKey];
    [coder encodeBool:self.musicSelectedFirstInfo forKey:kMusicSelectedFirstInfoCoderKey];
    [coder encodeBool:self.newCustomItem forKey:kNewCustomItemCoderKey];
    [coder encodeBool:self.newThema forKey:kNewThemaCoderKey];
    [coder encodeBool:self.brightnessFirstInfo forKey:kBrightnessFirstInfoCoderKey];
    [coder encodeInt32:self.newsInfomationID forKey:kNewsInfomationIDCoderKey];
    [coder encodeObject:self.lastUpdateTimeString forKey:kLastUpdateTimeStringCoderKey];
    [coder encodeObject:self.infoLastReadTimeString forKey:kInfoLastReadTimeStringCoderKey];
    [coder encodeObject:self.termVersion forKey:kTermVersionCoderKey];
    [coder encodeObject:self.termLastReadTimeString forKey:kTermLastReadTimeStringCoderKey];
    [coder encodeObject:self.termLastUpdateTimeString forKey:kTermLastUpdateTimeStringCoderKey];
    [coder encodeBool:self.takeoverPoint forKey:kTakeoverPointCoderKey];
    [coder encodeObject:self.resourceDownloadVersion forKey:kResourceDownloadVersionCoderKey];
    [coder encodeBool:self.resourceDownloadPause forKey:kResourceDownloadPauseCoderKey];
    [coder encodeInt32:self.playlistID forKey:kPlaylistIDCoderKey];
    [coder encodeInt32:self.playlistLevel forKey:kPlaylistLevelCoderKey];
    [coder encodeInt32:self.menuItemSort forKey:kMenuItemSortCoderKey];
    [coder encodeInt32:self.lastPurchaseMonth forKey:kLastPurchaseMonthCoderKey];
    [coder encodeInt32:self.purchaseLimitType forKey:kPurchaseLimitTypeCoderKey];
    [coder encodeInt32:self.totalPurchase forKey:kTotalPurchaseCoderKey];
    [coder encodeBool:self.refuseStoreSampleBGM forKey:kRefuseStoreSampleBGMCoderKey];
    [coder encodeInt32:self.delayFrame forKey:kDelayFrameCoderKey];
    [coder encodeBool:self.updatedErosionMark forKey:kUpdatedErosionMarkCoderKey];
    [coder encodeBool:self.userFullCombo forKey:kUserFullComboCoderKey];
    [coder encodeBool:self.cpuFullCombo forKey:kCpuFullComboCoderKey];
    [coder encodeBool:self.fullJustReflec forKey:kFullJustReflecCoderKey];
    [coder encodeBool:self.vsPastel forKey:kVsPastelCoderKey];
    [coder encodeBool:self.alreadyReadTitleCaution forKey:kAlreadyReadTitleCautionCoderKey];
}

#pragma mark - Theme

- (void)setThema:(RBUserSettingDataTheme)thema {
    /** @ghidraAddress 0x1f7594 */
    if (_thema == thema) {
        return;
    }
    _thema = thema;

    if (self.customizeItems.count - 1 < (NSUInteger)thema) {
        // No stored customise dictionary for this theme: fall back to the limelight defaults, and
        // always select the middle bounds-effect style.
        self.shotType = 0;
        self.bgmType = kLimelightBgmType;
        self.explosionType = kLimelightExplosionType;
        self.frameType = kLimelightFrameType;
        self.backgroundType = kLimelightBackgroundType;
        self.noteType = 0;
        self.boundsEffectStyle = kBoundsEffectStyleFallback;
        return;
    }

    NSDictionary *item = self.customizeItems[thema];
    self.shotType = [item[kShotTypeCoderKey] intValue];
    self.bgmType = [item[kBGMTypeCoderKey] intValue];
    self.explosionType = [item[kExplosionTypeCoderKey] intValue];
    self.frameType = [item[kFrameTypeCoderKey] intValue];
    self.backgroundType = [item[kBackgroundTypeCoderKey] intValue];
    self.noteType = [item[kNoteTypeCoderKey] intValue];
    self.gaugeStyle = [item[kGaugeStyleCoderKey] intValue];
    self.shotVolume = [item[kShotVolumeCoderKey] floatValue];
    self.backgroundBrighness = [item[kBackgroundBrighnessCoderKey] floatValue];

    // The bounds-effect style tracks the theme index, except an unrecognised theme leaves it
    // untouched.
    switch (thema) {
    case RBUserSettingDataThemeClassic:
        self.boundsEffectStyle = RBUserSettingDataThemeClassic;
        break;
    case RBUserSettingDataThemeLimelight:
        self.boundsEffectStyle = RBUserSettingDataThemeLimelight;
        break;
    case RBUserSettingDataThemeColette:
        self.boundsEffectStyle = RBUserSettingDataThemeColette;
        break;
    default:
        break;
    }
}

- (NSString *)themaName {
    /** @ghidraAddress 0x1f800c */
    return [RBUserSettingData themaNameWithID:self.thema];
}

- (NSString *)themaPath {
    /** @ghidraAddress 0x1f8048 */
    return [[NSBundle mainBundle] pathForResource:self.themaName ofType:kThemaBundleExtension];
}

+ (NSString *)themaNameWithID:(RBUserSettingDataTheme)themaID {
    /** @ghidraAddress 0x1f80fc */
    switch (themaID) {
    case RBUserSettingDataThemeColette:
        return kThemaNameColette;
    case RBUserSettingDataThemeLimelight:
        return kThemaNameLimelight;
    case RBUserSettingDataThemeClassic:
        return kThemaNameClassic;
    default:
        return kThemaNameFallback;
    }
}

#pragma mark - Customise-item resets

- (void)resetBgmType:(int)bgmType {
    /** @ghidraAddress 0x1f6ba0 */
    self.bgmType = bgmType;
    RBWriteCustomizeValue(self, @((NSUInteger)bgmType), kBGMTypeCoderKey);
}

- (void)resetShotType:(int)shotType {
    /** @ghidraAddress 0x1f6cac */
    self.shotType = shotType;
    RBWriteCustomizeValue(self, @((NSUInteger)shotType), kShotTypeCoderKey);
}

- (void)resetExplosionType:(int)explosionType {
    /** @ghidraAddress 0x1f6db8 */
    self.explosionType = explosionType;
    RBWriteCustomizeValue(self, @((NSUInteger)explosionType), kExplosionTypeCoderKey);
}

- (void)resetFrameType:(int)frameType {
    /** @ghidraAddress 0x1f6ec4 */
    self.frameType = frameType;
    RBWriteCustomizeValue(self, @((NSUInteger)frameType), kFrameTypeCoderKey);
}

- (void)resetBackgroundType:(int)backgroundType {
    /** @ghidraAddress 0x1f6fd0 */
    self.backgroundType = backgroundType;
    RBWriteCustomizeValue(self, @((NSUInteger)backgroundType), kBackgroundTypeCoderKey);
}

- (void)resetNoteType:(int)noteType {
    /** @ghidraAddress 0x1f70dc */
    self.noteType = noteType;
    RBWriteCustomizeValue(self, @((NSUInteger)noteType), kNoteTypeCoderKey);
}

- (void)resetGaugeStyle:(int)gaugeStyle {
    /** @ghidraAddress 0x1f71e8 */
    self.gaugeStyle = gaugeStyle;
    RBWriteCustomizeValue(self, @((NSUInteger)gaugeStyle), kGaugeStyleCoderKey);
}

- (void)resetGhostStyle:(int)ghostStyle {
    /** @ghidraAddress 0x1f72f4 */
    self.ghostStyle = ghostStyle;
    if (ghostStyle == kGhostStyleDanger) {
        // The danger ghost style is incompatible with a scored full combo, so the flags are reset.
        self.userFullCombo = NO;
        self.cpuFullCombo = NO;
        self.fullJustReflec = NO;
    }
}

- (void)resetShotVolume:(float)shotVolume {
    /** @ghidraAddress 0x1f736c */
    self.shotVolume = shotVolume;
    RBWriteCustomizeValue(self, @(shotVolume), kShotVolumeCoderKey);
}

- (void)resetBackgroundBrightness:(float)backgroundBrightness {
    /** @ghidraAddress 0x1f7480 */
    self.backgroundBrighness = backgroundBrightness;
    RBWriteCustomizeValue(self, @(backgroundBrightness), kBackgroundBrighnessCoderKey);
}

#pragma mark - Terms and tutorial

- (BOOL)needUpdateTerms:(NSString *)version {
    /** @ghidraAddress 0x1f8160 */
    if (version == nil || self.termVersion == nil) {
        return YES;
    }
    return [self.termVersion compare:version options:NSNumericSearch] == NSOrderedAscending;
}

- (void)updateTutorialStatus:(unsigned int)status value:(unsigned int)value {
    /** @ghidraAddress 0x1f8234 */
    if (self.tutorialStatuses == nil) {
        self.tutorialStatuses = [[NSMutableDictionary alloc] init];
    }
    // The binary boxes both halves with -numberWithInt:, so the signed cast is deliberate.
    self.tutorialStatuses[@((int)status)] = @((int)value);
    [self save];
    // RBPDBG: the tutorial does not stay completed across launches. Record what was written and
    // what the dictionary holds afterwards, so a write that never happens can be told apart from
    // one that happens and is not persisted.
    if (NE_DBG_FIRST(40)) {
        neDebugLog("tutorialPersist write status=%u value=%u count=%lu class=%s",
                   status,
                   value,
                   (unsigned long)self.tutorialStatuses.count,
                   self.tutorialStatuses.class.description.UTF8String);
    }
}

- (unsigned int)getTutorialStatus:(unsigned int)status {
    /** @ghidraAddress 0x1f83a4 */
    NSNumber *stored = self.tutorialStatuses[@((int)status)];
    if (stored == nil) {
        return 0;
    }
    return stored.unsignedIntValue;
}

- (NSMutableArray *)getTutorialStatusList {
    /** @ghidraAddress 0x1f8494 */
    NSMutableArray *keys = [[NSMutableArray alloc] init];
    for (id key in self.tutorialStatuses) {
        [keys addObject:key];
    }
    return keys;
}

@end
