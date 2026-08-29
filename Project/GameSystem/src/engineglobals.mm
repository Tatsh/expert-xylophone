#import "engineglobals.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "deviceenvironment.h"

double g_dSliderRowHeight;
UIColor *g_pCachedWhiteColor;
UIColor *g_pCachedOffWhiteColor;
UIColor *g_pCachedBlueColor;

UIColor *g_pPaletteDimmingCoverColor;
UIColor *g_pPaletteWhiteColor;
UIColor *g_pPaletteOpaqueBlackColor;
UIColor *g_pPaletteGreenGrassColor;
UIColor *g_pPaletteMagentaColor;
UIColor *g_pPalettePurpleColor;
UIColor *g_pPaletteDarkGreenColor;
UIColor *g_pPaletteLeafGreenColor;
UIColor *g_pPaletteGreenGrassColor2;
UIColor *g_pPaletteMagentaColor2;
UIColor *g_pPaletteLeafGreenColor2;
UIColor *g_pPaletteSteelBlueColor;
UIColor *g_pPaletteLeafGreenColor3;
UIColor *g_pPaletteSteelBlueColor2;
UIColor *g_pPaletteGoldColor;
UIColor *g_pPaletteSteelBlueColor3;
const double g_PaletteColorGreenGrassRed = 63.0f / 255.0f;
const double g_PaletteColorGreenGrassGreen = 0.654902f;
const double g_PaletteColorMagentaRed = 254.0f / 255.0f;
const double g_PaletteColorMagentaGreen = 33.0f / 255.0f;
const double g_PaletteColorMagentaBlue = 0.972549f;
const double g_PaletteColorDarkGreenRed = 2.0f / 255.0f;
const double g_PaletteColorDarkGreenGreen = 111.0f / 255.0f;
const double g_PaletteColorLeafGreenRed = 26.0f / 255.0f;
const double g_PaletteColorLeafGreenGreen = 151.0f / 255.0f;
const double g_PaletteColorSteelBlueRed = 133.0f / 255.0f;
const double g_PaletteColorSteelBlueGreen = 173.0f / 255.0f;
const double g_PaletteColorSteelBlueBlue = 217.0f / 255.0f;
const double g_PaletteColorGoldRed = 229.0f / 255.0f;
const double g_PaletteColorGoldGreen = 183.0f / 255.0f;
const double g_PaletteColorGoldBlue = 49.0f / 255.0f;

const double g_dTranslucentAlpha = 0.8f;
const double g_dMascotMoveAnimDuration = 0.1f;
const double g_dMascotMessageAnimDuration = 0.2f;
const float g_flFlashMinOpacity = 0.2f;
const double g_dCustomizeLayoutMetric100 = 100.0;
const double g_dAudioManagerResumeFadeInTime = 0.3f;
const double g_dMascotMessageMaxWidthPad = 300.0;
const double g_dMascotMessageMaxWidthPhone = 200.0;
const double g_dSliderRowHeightWide = 40.0;
const double g_dLayoutMetricThirtyTwo = 32.0;
const double g_dLayoutMetricSixty = 60.0;
const double g_dLayoutMetricEighty = 80.0;
const double g_dCustomizeLayoutMetric82 = 82.0;
const double g_dStoreDetailCopyrightLabelWidth = 310.0;
const double g_dPopupBaseOriginYWide = 160.0;
const double g_dTermButtonRowHeight = 50.0;
const double g_dNameImageMaxWidth = 280.0;
const double g_dRBWebViewGrayViewWhite = 0.6f;
const double g_dRBNavBarTintWhite = 0.054901960784313725;
const float g_flDefaultExplosionEffectSize = 0.9f;

const unsigned int g_dwAutoresizingMaskFlexibleAll = 0x3f;
const unsigned int g_dwRBWebViewIndicatorAutoresizingMask = 0x2d;

// @ghidraAddress 0x310274
const float g_afLimelightPackageTitleColorTable[] = {
    0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 0.0f, 1.0f,
    0.0f, 1.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f,
    1.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 1.0f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f,
    1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f,
};

// The keys are not NUL-terminated, so each carries its length in the table below.
// @ghidraAddress 0x2fcf50
static const char kChartDecodeKeyType0[] = {
    0x4b, 0x6e, 0x6c, 0x5e, 0x69, 0x64, 0x1a, 0x4b, 0x5d, 0x5d, 0x62, 0x5a, 0x57,
    0x35, 0x57, 0x52, 0x64, 0x0f, 0x34, 0x5c, 0x5e, 0x0b, 0x53, 0x38, 0x3b, 0x15,
};
// @ghidraAddress 0x2fcf6a
static const char kChartDecodeKeyType1[] = {
    0x4b, 0x6e, 0x6c, 0x5e, 0x69, 0x64, 0x1a, 0x4b, 0x5d, 0x5d, 0x62,
    0x5a, 0x57, 0x35, 0x57, 0x52, 0x64, 0x5f, 0x5a, 0x62, 0x5f, 0x19,
};

// @ghidraAddress 0x35b7c8
const ChartDecodeKey kChartDecodeKeys[] = {
    {kChartDecodeKeyType0, static_cast<int>(sizeof(kChartDecodeKeyType0))},
    {kChartDecodeKeyType1, static_cast<int>(sizeof(kChartDecodeKeyType1))},
};

float g_aGaugePartsScale[3];

CGPoint g_difficultyNumberOffsetPad;
CGPoint g_difficultyNumberOffsetPhone;

CGPoint g_extendNoteNumberOffsetPad;
CGPoint g_extendNoteNumberOffsetPhone;

CGPoint g_aTwitterImageDrawPos[8];

CGRect g_aTutorialPastelClipRects[4];
CGPoint g_aTutorialPastelPositions[4];

CGPoint g_aSettingLayout[26];

NSDictionary *g_pApiRequestTable;

NSDictionary *g_pMacronToVowelTable;
NSDictionary *g_pLowerToUpperTable;
NSDictionary *g_pVoiceToVoicelessTable;

NSArray *g_pScoreMinThresholds;
NSArray *g_pScoreMaxThresholds;

NSString *g_pLocalizedAbort;
NSString *g_pLocalizedAddToPlaylist;
NSString *g_pLocalizedAll;
NSString *g_pLocalizedBuyFormat;
NSString *g_pLocalizedCancel;
NSString *g_pLocalizedInAppPurchasesDisabled;
NSString *g_pLocalizedCaution;
NSString *g_pLocalizedFreeSpaceLow;
NSString *g_pLocalizedClose;
NSString *g_pLocalizedCreatePlaylist;
NSString *g_pLocalizedDelete;
NSString *g_pLocalizedDeleteSong;
NSString *g_pLocalizedOpenInMap;
NSString *g_pLocalizedDownload;
NSString *g_pLocalizedDownloadFailed;
NSString *g_pDownloadingMessageFormat;
NSString *g_pLocalizedError;
NSString *g_pLocalizedGameCenterConnectFailed;
NSString *g_pLocalizedNoLeaderboardData;
NSString *g_pLocalizedInfomation;
NSString *g_pLocalizedInstall;
NSString *g_pLocalizedInstalled;
NSString *g_pLocalizedInstalling;
NSString *g_pLocalizedNewVersionAvailable;
NSString *g_pLocalizedLevel;
NSString *g_pLocalizedLevel1;
NSString *g_pLocalizedLevel2;
NSString *g_pLocalizedLevel3;
NSString *g_pLocalizedLevel4;
NSString *g_pLocalizedLevel5;
NSString *g_pLocalizedLevel6;
NSString *g_pLocalizedLevel7;
NSString *g_pLocalizedLevel8;
NSString *g_pLocalizedLevel9;
NSString *g_pLocalizedLevel10;
NSString *g_pLocalizedLevel11;
NSString *g_pLocalizedLevel12;
NSString *g_pLocalizedLevel13;
NSString *g_pLocalizedLevel14;
NSString *g_pLocalizedLevel15;
NSString *g_pLocalizedSpecial;
NSString *g_pLocalizedLoadingMixed;
NSString *g_pLocalizedLoadingUpper;
NSString *g_pDeleteConfirmFormat;
NSString *g_pLocalizedServerConnectFailed;
NSString *g_pLocalizedNew;
NSString *g_pLocalizedNo;
NSString *g_pLocalizedNoPlaySongs;
NSString *g_pLocalizedOK;
NSString *g_pLocalizedPacks;
NSString *g_pLocalizedPlaylist;
NSString *g_pLocalizedPlaylistName;
NSString *g_pLocalizedProcessing;
NSString *g_pLocalizedPurchaseCancelled;
NSString *g_pLocalizedPurchased;
NSString *g_pLocalizedPushUpToShowMore;
NSString *g_pLocalizedReflecBeatStore;
NSString *g_pLocalizedReflectedOnLimePoint;
NSString *g_pLocalizedRestorePurchasesButton;
NSString *g_pLocalizedInstallPacksButton;
NSString *g_pLocalizedInstallRestoredPacks;
NSString *g_pLocalizedRestorePurchasedPacks;
NSString *g_pLocalizedRetry;
NSString *g_pLocalizedReturn;
NSString *g_pLocalizedServerNoData;
NSString *g_pLocalizedUpdateRequiredFormat;
NSString *g_pLocalizedShowMore;
NSString *g_pLocalizedSlash;
NSString *g_pLocalizedSort;
NSString *g_pLocalizedStore;
NSString *g_pLocalizedMusicPacks;
NSString *g_pLocalizedSequences;
NSString *g_pLocalizedPurchaseAdditionalSequences;
NSString *g_pLocalizedSequenceRequirementFormat;
NSString *g_pLocalizedEnableLocationService;
NSString *g_pLocalizedTookOverData;
NSString *g_pLocalizedUpdateDataFound;
NSString *g_pLocalizedSearchVersionMismatch;
NSString *g_pLocalizedYes;
NSString *g_pLocalizedLatestGameDataRequired;
NSString *g_pLocalizedInsufficientPoints;
NSString *g_pLocalizedHasBeenAddedFormat;
NSString *g_pLocalizedUnlockRequirement;
NSString *g_pLocalizedUpdateToUnlockSong;
NSString *g_pLocalizedAppInstalledReward;
NSString *g_pLocalizedLimePointAddedFormat;
NSString *g_pLocalizedSearchMusic;

namespace {
// The bundle is resolved once by the caller; the binary re-fetched it per call.
NSString *Localize(NSBundle *bundle, NSString *key) {
    return [bundle localizedStringForKey:key value:@"" table:nil];
}
} // namespace

/** @ghidraAddress 0x10090 */
__attribute__((constructor)) void CacheLocalizedUIStrings(void) {
    @autoreleasepool {
        NSBundle *bundle = [NSBundle mainBundle];
        g_pLocalizedAbort = Localize(bundle, @"Abort");
        g_pLocalizedAddToPlaylist = Localize(bundle, @"Add to playlist");
        g_pLocalizedAll = Localize(bundle, @"All");
        g_pLocalizedBuyFormat = Localize(bundle, @"BUY (%@)");
        g_pLocalizedCancel = Localize(bundle, @"Cancel");
        g_pLocalizedInAppPurchasesDisabled = Localize(bundle, @"In-app purchases are not allowed.");
        g_pLocalizedCaution = Localize(bundle, @"Caution");
        g_pLocalizedFreeSpaceLow = Localize(
            bundle,
            @"Free space of the storage area is low. \nMay not work correctly when you play the "
            @"game as it is.");
        g_pLocalizedClose = Localize(bundle, @"Close");
        g_pLocalizedCreatePlaylist = Localize(bundle, @"Create playlist");
        g_pLocalizedDelete = Localize(bundle, @"Delete");
        g_pLocalizedDeleteSong = Localize(bundle, @"DELETE SONG");
        g_pLocalizedOpenInMap = Localize(bundle, @"Do you want to open in the 'map' this place?");
        g_pLocalizedDownload = Localize(bundle, @"Download");
        g_pLocalizedDownloadFailed =
            Localize(bundle, @"Falied to download.\nPlease check your network connection.");
        g_pDownloadingMessageFormat = Localize(bundle, @"Downloading \"%@\" ...");
        g_pLocalizedError = Localize(bundle, @"Error");
        g_pLocalizedGameCenterConnectFailed = Localize(bundle, @"Failed to connect Game Center.");
        g_pLocalizedNoLeaderboardData = Localize(bundle, @"No Leaderboard data");
        g_pLocalizedInfomation = Localize(bundle, @"Infomation");
        g_pLocalizedInstall = Localize(bundle, @"INSTALL");
        g_pLocalizedInstalled = Localize(bundle, @"INSTALLED");
        g_pLocalizedInstalling = Localize(bundle, @"INSTALLING");
        g_pLocalizedNewVersionAvailable =
            Localize(bundle, @"A new version is available. \nDo you want to move App Store?");
        g_pLocalizedLevel = Localize(bundle, @"Level");
        g_pLocalizedLevel1 = Localize(bundle, @"Level 1");
        g_pLocalizedLevel10 = Localize(bundle, @"Level 10");
        g_pLocalizedLevel11 = Localize(bundle, @"Level 11");
        g_pLocalizedLevel12 = Localize(bundle, @"Level 12");
        g_pLocalizedLevel13 = Localize(bundle, @"Level 13");
        g_pLocalizedLevel14 = Localize(bundle, @"Level 14");
        g_pLocalizedLevel15 = Localize(bundle, @"Level 15");
        g_pLocalizedLevel2 = Localize(bundle, @"Level 2");
        g_pLocalizedLevel3 = Localize(bundle, @"Level 3");
        g_pLocalizedLevel4 = Localize(bundle, @"Level 4");
        g_pLocalizedLevel5 = Localize(bundle, @"Level 5");
        g_pLocalizedLevel6 = Localize(bundle, @"Level 6");
        g_pLocalizedLevel7 = Localize(bundle, @"Level 7");
        g_pLocalizedLevel8 = Localize(bundle, @"Level 8");
        g_pLocalizedLevel9 = Localize(bundle, @"Level 9");
        g_pLocalizedSpecial = Localize(bundle, @"SPECIAL");
        g_pLocalizedLoadingMixed = Localize(bundle, @"Loading...");
        g_pLocalizedLoadingUpper = Localize(bundle, @"LOADING...");
        g_pDeleteConfirmFormat = Localize(bundle, @"Do you want to delete \"%@\"?");
        g_pLocalizedServerConnectFailed =
            Localize(bundle, @"Can't connect to the server\nPlease check your network connection.");
        g_pLocalizedNew = Localize(bundle, @"New");
        g_pLocalizedNo = Localize(bundle, @"NO");
        g_pLocalizedNoPlaySongs = Localize(bundle, @"No play songs");
        g_pLocalizedOK = Localize(bundle, @"OK");
        g_pLocalizedPacks = Localize(bundle, @"Packs");
        g_pLocalizedPlaylist = Localize(bundle, @"Playlist");
        g_pLocalizedPlaylistName = Localize(bundle, @"Playlist Name");
        g_pLocalizedProcessing = Localize(bundle, @"Processing...");
        g_pLocalizedPurchaseCancelled = Localize(bundle, @"The purchase was cancelled.\n\n%@");
        g_pLocalizedPurchased = Localize(bundle, @"Purchased");
        g_pLocalizedPushUpToShowMore = Localize(bundle, @"Push up to show more");
        g_pLocalizedReflecBeatStore = Localize(bundle, @"REFLEC BEAT Store");
        g_pLocalizedReflectedOnLimePoint = Localize(bundle, @"reflected on the lime point score.");
        g_pLocalizedRestorePurchasesButton = Localize(bundle, @"Restore purchases");
        g_pLocalizedInstallPacksButton = Localize(bundle, @"Install PACKs");
        g_pLocalizedInstallRestoredPacks =
            Localize(bundle, @"To install restored PACKs, select 'OK'");
        g_pLocalizedRestorePurchasedPacks =
            Localize(bundle, @"To restore purchased PACKs, select 'OK'");
        g_pLocalizedRetry = Localize(bundle, @"Retry");
        g_pLocalizedReturn = Localize(bundle, @"Return");
        g_pLocalizedServerNoData =
            Localize(bundle, @"Server error occurred.\nPlease try again later.");
        g_pLocalizedUpdateRequiredFormat =
            Localize(bundle,
                     @"Ver. %2$@ or above is required to access %1$@.\n\nPlease update to the "
                     @"latest version.");
        g_pLocalizedShowMore = Localize(bundle, @"▼ SHOW MORE ▼");
        g_pLocalizedSlash = Localize(bundle, @"/");
        g_pLocalizedSort = Localize(bundle, @"Sort:");
        g_pLocalizedStore = Localize(bundle, @"Store");
        g_pLocalizedMusicPacks = Localize(bundle, @"Music Packs");
        g_pLocalizedSequences = Localize(bundle, @"Sequences");
        g_pLocalizedPurchaseAdditionalSequences =
            Localize(bundle, @"Purchase Additional Sequences?");
        g_pLocalizedSequenceRequirementFormat = Localize(
            bundle, @"\"%1$@\" is required to purchase this Sequence.\n\nPurchase \"%2$@\"?");
        g_pLocalizedEnableLocationService =
            Localize(bundle,
                     @"To display the current position\nFrom the 'Settings' app\nPlease set to "
                     @"'On' position information service");
        g_pLocalizedTookOverData = Localize(bundle, @"Took over the data");
        g_pLocalizedUpdateDataFound =
            Localize(bundle, @"Update data found. \nDo you want to download?");
        g_pLocalizedSearchVersionMismatch =
            Localize(bundle, @"Please update to the latest version.");
        g_pLocalizedYes = Localize(bundle, @"YES");
        g_pLocalizedLatestGameDataRequired =
            Localize(bundle, @"The latest game data is required. \nDownload will commence.");
        g_pLocalizedInsufficientPoints = Localize(bundle, @"Insufficient Points.");
        g_pLocalizedHasBeenAddedFormat = Localize(bundle, @"\"%@\" has been added!");
        g_pLocalizedUnlockRequirement = Localize(bundle, @"Unlock Requirement");
        g_pLocalizedUpdateToUnlockSong =
            Localize(bundle, @"This application must be updated to unlock this song.");
        g_pLocalizedAppInstalledReward = Localize(bundle, @"App Installed Reward");
        g_pLocalizedLimePointAddedFormat = Localize(bundle, @"\"%d Lime Point\" has been Added.");
        g_pLocalizedSearchMusic = Localize(bundle, @"Search music");
    }
}

namespace {
constexpr double kSliderRowHeightPhone = 20.0;
constexpr CGFloat kOffWhiteBrightness = 0.97;
constexpr CGFloat kBlueRed = 3.0f / 255.0f;
constexpr CGFloat kBlueGreen = 122.0f / 255.0f;
} // namespace

/** @ghidraAddress 0x1c0a78 */
__attribute__((constructor)) void InitializeSliderHeightConstant(void) {
    @autoreleasepool {
        g_dSliderRowHeight = IsPad() ? g_dSliderRowHeightWide : kSliderRowHeightPhone;
    }
}

/** @ghidraAddress 0x1d52a0 */
__attribute__((constructor)) void InitializeUiColorConstants(void) {
    @autoreleasepool {
        g_pCachedWhiteColor = [UIColor colorWithWhite:1.0 alpha:1.0];
        g_pCachedOffWhiteColor = [UIColor colorWithWhite:kOffWhiteBrightness alpha:1.0];
        g_pCachedBlueColor = [UIColor colorWithRed:kBlueRed green:kBlueGreen blue:1.0 alpha:1.0];
    }
}

namespace {
constexpr CGFloat kDimmingCoverAlpha = 0.5;
constexpr float kGaugePartsScaleNegative = -0.88888889f;
constexpr float kGaugePartsScalePositive = 0.88888889f;
constexpr float kGaugePartsScaleTrailing = 288.0f;
} // namespace

/** @ghidraAddress 0x148a70 */
__attribute__((constructor)) void BuildGaugeThresholdArrays(void) {
    @autoreleasepool {
        // Per difficulty (basic, medium, hard): the bounds the score validator accepts.
        g_pScoreMinThresholds = @[ @680, @1067, @1946 ];
        g_pScoreMaxThresholds = @[ @740, @1157, @2114 ];
    }
}

/** @ghidraAddress 0x3394c */
__attribute__((constructor)) void InitializeApiRequestTable(void) {
    @autoreleasepool {
        g_pApiRequestTable = @{
            @"startup" : @{@"method" : @"GET", @"param" : @[ @"target" ]},
            @"v3_ssl_resource" : @{@"method" : @"GET", @"param" : @[ @"target" ]},
            @"v3_packlist" : @{@"method" : @"GET", @"param" : @[ @"target" ]},
        };
    }
}

/** @ghidraAddress 0x2ac00 */
__attribute__((constructor)) void InitializeGlobalLookupTables(void) {
    @autoreleasepool {
        // Small katakana fold to full size so a reading can be normalised before matching.
        g_pLowerToUpperTable = @{
            @"ァ" : @"ア",
            @"ィ" : @"イ",
            @"ゥ" : @"ウ",
            @"ェ" : @"エ",
            @"ォ" : @"オ",
            @"ャ" : @"ヤ",
            @"ュ" : @"ユ",
            @"ョ" : @"ヨ",
            @"ヮ" : @"ワ",
            @"ッ" : @"ツ",
            @"ヶ" : @"ケ",
        };

        // Each katakana maps to the bare vowel of its row, so a following prolonged-sound mark (ー)
        // resolves to that vowel; ン maps to itself.
        g_pMacronToVowelTable = @{
            @"ァ" : @"ア",
            @"ア" : @"ア",
            @"ヵ" : @"ア",
            @"カ" : @"ア",
            @"ガ" : @"ア",
            @"サ" : @"ア",
            @"ザ" : @"ア",
            @"タ" : @"ア",
            @"ダ" : @"ア",
            @"ナ" : @"ア",
            @"ハ" : @"ア",
            @"バ" : @"ア",
            @"パ" : @"ア",
            @"マ" : @"ア",
            @"ャ" : @"ア",
            @"ヤ" : @"ア",
            @"ラ" : @"ア",
            @"ヮ" : @"ア",
            @"ワ" : @"ア",
            @"ヷ" : @"ア",
            @"ィ" : @"イ",
            @"イ" : @"イ",
            @"キ" : @"イ",
            @"ギ" : @"イ",
            @"シ" : @"イ",
            @"ジ" : @"イ",
            @"チ" : @"イ",
            @"ヂ" : @"イ",
            @"ニ" : @"イ",
            @"ヒ" : @"イ",
            @"ビ" : @"イ",
            @"ピ" : @"イ",
            @"ミ" : @"イ",
            @"リ" : @"イ",
            @"ヰ" : @"イ",
            @"ヸ" : @"イ",
            @"ゥ" : @"ウ",
            @"ウ" : @"ウ",
            @"ク" : @"ウ",
            @"グ" : @"ウ",
            @"ス" : @"ウ",
            @"ズ" : @"ウ",
            @"ッ" : @"ウ",
            @"ツ" : @"ウ",
            @"ヅ" : @"ウ",
            @"ヌ" : @"ウ",
            @"フ" : @"ウ",
            @"ブ" : @"ウ",
            @"プ" : @"ウ",
            @"ム" : @"ウ",
            @"ュ" : @"ウ",
            @"ユ" : @"ウ",
            @"ル" : @"ウ",
            @"ェ" : @"エ",
            @"エ" : @"エ",
            @"ヶ" : @"エ",
            @"ケ" : @"エ",
            @"ゲ" : @"エ",
            @"セ" : @"エ",
            @"ゼ" : @"エ",
            @"テ" : @"エ",
            @"デ" : @"エ",
            @"ネ" : @"エ",
            @"ヘ" : @"エ",
            @"ベ" : @"エ",
            @"ペ" : @"エ",
            @"メ" : @"エ",
            @"レ" : @"エ",
            @"ヱ" : @"エ",
            @"ヹ" : @"エ",
            @"ォ" : @"オ",
            @"オ" : @"オ",
            @"コ" : @"オ",
            @"ゴ" : @"オ",
            @"ソ" : @"オ",
            @"ゾ" : @"オ",
            @"ト" : @"オ",
            @"ド" : @"オ",
            @"ノ" : @"オ",
            @"ホ" : @"オ",
            @"ボ" : @"オ",
            @"ポ" : @"オ",
            @"モ" : @"オ",
            @"ョ" : @"オ",
            @"ヨ" : @"オ",
            @"ロ" : @"オ",
            @"ヲ" : @"オ",
            @"ヺ" : @"オ",
            @"ン" : @"ン",
        };

        g_pVoiceToVoicelessTable = @{
            @"ガ" : @"カ",
            @"ギ" : @"キ",
            @"グ" : @"ク",
            @"ゲ" : @"ケ",
            @"ゴ" : @"コ",
            @"ザ" : @"サ",
            @"ジ" : @"シ",
            @"ズ" : @"ス",
            @"ゼ" : @"セ",
            @"ゾ" : @"ソ",
            @"ダ" : @"タ",
            @"ヂ" : @"チ",
            @"ヅ" : @"ツ",
            @"デ" : @"テ",
            @"ド" : @"ト",
            @"バ" : @"ハ",
            @"ビ" : @"ヒ",
            @"ブ" : @"フ",
            @"ベ" : @"ヘ",
            @"ボ" : @"ホ",
            @"パ" : @"ハ",
            @"ピ" : @"ヒ",
            @"プ" : @"フ",
            @"ペ" : @"ヘ",
            @"ポ" : @"ホ",
        };
    }
}

/** @ghidraAddress 0xc933c */
__attribute__((constructor)) void InitializeCGAffineTransformGlobals(void) {
    @autoreleasepool {
        g_difficultyNumberOffsetPad = CGPointMake(6.0, 12.0);
        g_difficultyNumberOffsetPhone = CGPointMake(2.0, 10.0);
    }
}

namespace {
// @ghidraAddress 0x301710 and 0x301720
constexpr CGFloat kSettingPanelOriginX = 112.0;
constexpr CGFloat kSettingPanelOriginY = 186.0;
constexpr CGFloat kSettingPanelWidth = 179.0;
constexpr CGFloat kSettingPanelHeight = 160.0;

constexpr CGFloat kSettingColumnLeftTemplateX = 257.0;  // @ghidraAddress 0x301288
constexpr CGFloat kSettingColumnRightTemplateX = 294.0; // @ghidraAddress 0x3016f0

constexpr CGFloat kSettingRowTemplateY[] = {462.0, 358.0, 566.0, 486.0, 382.0, 590.0};
} // namespace

/** @ghidraAddress 0xec450 */
__attribute__((constructor)) void InitializeSettingLayoutGlobals(void) {
    @autoreleasepool {
        g_aSettingLayout[0] = CGPointMake(kSettingPanelOriginX, kSettingPanelOriginY);
        g_aSettingLayout[1] = CGPointMake(kSettingPanelWidth, kSettingPanelHeight);

        const CGFloat flLeftX = kSettingColumnLeftTemplateX - kSettingPanelOriginX;
        g_aSettingLayout[2] = CGPointMake(flLeftX, kSettingRowTemplateY[0] - kSettingPanelHeight);
        g_aSettingLayout[3] = CGPointMake(flLeftX, kSettingRowTemplateY[1] - kSettingPanelHeight);
        g_aSettingLayout[4] = CGPointMake(flLeftX, kSettingRowTemplateY[2] - kSettingPanelHeight);

        const CGFloat flRightX = kSettingColumnRightTemplateX - kSettingPanelOriginX;
        g_aSettingLayout[5] = CGPointMake(flRightX, kSettingRowTemplateY[3] - kSettingPanelHeight);
        g_aSettingLayout[6] = CGPointMake(flRightX, kSettingRowTemplateY[4] - kSettingPanelHeight);
        g_aSettingLayout[7] = CGPointMake(flRightX, kSettingRowTemplateY[5] - kSettingPanelHeight);

        g_aSettingLayout[8] = CGPointMake(13.0, 30.0);
        g_aSettingLayout[9] = CGPointMake(13.0, 30.0);
        g_aSettingLayout[10] = CGPointMake(13.0, 10.0);
        g_aSettingLayout[11] = CGPointMake(5.0, 14.0);
        g_aSettingLayout[12] = CGPointMake(5.0, 14.0);
        g_aSettingLayout[13] = CGPointMake(5.0, 5.0);
        g_aSettingLayout[14] = CGPointMake(0.0, 26.0);
        g_aSettingLayout[15] = CGPointMake(0.0, 26.0);
        g_aSettingLayout[16] = CGPointMake(0.0, 2.0);
        g_aSettingLayout[17] = CGPointMake(0.0, 13.0);
        g_aSettingLayout[18] = CGPointMake(0.0, 13.0);
        g_aSettingLayout[19] = CGPointMake(0.0, 4.0);
        g_aSettingLayout[20] = CGPointMake(0.0, 30.0);
        g_aSettingLayout[21] = CGPointMake(0.0, 30.0);
        g_aSettingLayout[22] = CGPointMake(0.0, 10.0);
        g_aSettingLayout[23] = CGPointMake(0.0, 10.0);
        g_aSettingLayout[24] = CGPointMake(0.0, 10.0);
        g_aSettingLayout[25] = CGPointMake(0.0, 5.0);
    }
}

/** @ghidraAddress 0x88f24 */
__attribute__((constructor)) void InitializeParticleOffsetTable(void) {
    @autoreleasepool {
        g_aTwitterImageDrawPos[0] = CGPointMake(80.0, 62.0);   // title
        g_aTwitterImageDrawPos[1] = CGPointMake(80.0, 89.0);   // artist
        g_aTwitterImageDrawPos[2] = CGPointMake(24.0, 60.0);   // difficulty
        g_aTwitterImageDrawPos[3] = CGPointMake(33.0, 79.0);   // level (non-Colette theme)
        g_aTwitterImageDrawPos[4] = CGPointMake(129.0, 176.0); // line separator
        g_aTwitterImageDrawPos[5] = CGPointMake(19.0, 57.0);   // level (Colette theme)
        g_aTwitterImageDrawPos[6] = CGPointMake(25.0, 115.0);  // just-reflec badge
        g_aTwitterImageDrawPos[7] = CGPointMake(25.0, 135.0);  // full-combo badge
    }
}

/** @ghidraAddress 0x1b81d8 */
__attribute__((constructor)) void InitializeTutorialPastelLayoutTables(void) {
    @autoreleasepool {
        g_aTutorialPastelClipRects[0] = CGRectMake(361.0, 274.0, 136.0, 96.0);
        g_aTutorialPastelClipRects[1] = CGRectMake(499.0, 274.0, 48.0, 56.0);
        g_aTutorialPastelClipRects[2] = CGRectMake(498.0, 332.0, 24.0, 22.0);
        g_aTutorialPastelClipRects[3] = CGRectMake(525.0, 332.0, 24.0, 22.0);
        g_aTutorialPastelPositions[0] = CGPointMake(101.0, 172.0);
        g_aTutorialPastelPositions[1] = CGPointMake(100.0, 76.0);
        g_aTutorialPastelPositions[2] = CGPointMake(107.0, 120.0);
        g_aTutorialPastelPositions[3] = CGPointMake(95.0, 120.0);
    }
}

/** @ghidraAddress 0x3d04c */
__attribute__((constructor)) void InitializeIdentityTransformGlobals(void) {
    @autoreleasepool {
        g_extendNoteNumberOffsetPad = CGPointMake(6.0, 12.0);
        g_extendNoteNumberOffsetPhone = CGPointMake(2.0, 10.0);
    }
}

/** @ghidraAddress 0x83cf0 */
__attribute__((constructor)) void InitializeGaugeAngleTable(void) {
    @autoreleasepool {
        g_aGaugePartsScale[0] = kGaugePartsScaleNegative;
        g_aGaugePartsScale[1] = kGaugePartsScalePositive;
        g_aGaugePartsScale[2] = kGaugePartsScaleTrailing;
    }
}

/** @ghidraAddress 0x55120 */
__attribute__((constructor)) void InitializeUIColorPalette(void) {
    @autoreleasepool {
        g_pPaletteDimmingCoverColor = [UIColor colorWithRed:0.0
                                                      green:0.0
                                                       blue:0.0
                                                      alpha:kDimmingCoverAlpha];
        g_pPaletteWhiteColor = UIColor.whiteColor;
        g_pPaletteOpaqueBlackColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0];
        g_pPaletteGreenGrassColor = [UIColor colorWithRed:g_PaletteColorGreenGrassRed
                                                    green:g_PaletteColorGreenGrassGreen
                                                     blue:0.0
                                                    alpha:1.0];
        g_pPaletteMagentaColor = [UIColor colorWithRed:g_PaletteColorMagentaRed
                                                 green:g_PaletteColorMagentaGreen
                                                  blue:g_PaletteColorMagentaBlue
                                                 alpha:1.0];
        g_pPalettePurpleColor = UIColor.purpleColor;
        g_pPaletteDarkGreenColor = [UIColor colorWithRed:g_PaletteColorDarkGreenRed
                                                   green:g_PaletteColorDarkGreenGreen
                                                    blue:0.0
                                                   alpha:1.0];
        g_pPaletteLeafGreenColor = [UIColor colorWithRed:g_PaletteColorLeafGreenRed
                                                   green:g_PaletteColorLeafGreenGreen
                                                    blue:0.0
                                                   alpha:1.0];
        g_pPaletteGreenGrassColor2 = [UIColor colorWithRed:g_PaletteColorGreenGrassRed
                                                     green:g_PaletteColorGreenGrassGreen
                                                      blue:0.0
                                                     alpha:1.0];
        g_pPaletteMagentaColor2 = [UIColor colorWithRed:g_PaletteColorMagentaRed
                                                  green:g_PaletteColorMagentaGreen
                                                   blue:g_PaletteColorMagentaBlue
                                                  alpha:1.0];
        g_pPaletteLeafGreenColor2 = [UIColor colorWithRed:g_PaletteColorLeafGreenRed
                                                    green:g_PaletteColorLeafGreenGreen
                                                     blue:0.0
                                                    alpha:1.0];
        g_pPaletteSteelBlueColor = [UIColor colorWithRed:g_PaletteColorSteelBlueRed
                                                   green:g_PaletteColorSteelBlueGreen
                                                    blue:g_PaletteColorSteelBlueBlue
                                                   alpha:1.0];
        g_pPaletteLeafGreenColor3 = [UIColor colorWithRed:g_PaletteColorLeafGreenRed
                                                    green:g_PaletteColorLeafGreenGreen
                                                     blue:0.0
                                                    alpha:1.0];
        g_pPaletteSteelBlueColor2 = [UIColor colorWithRed:g_PaletteColorSteelBlueRed
                                                    green:g_PaletteColorSteelBlueGreen
                                                     blue:g_PaletteColorSteelBlueBlue
                                                    alpha:1.0];
        g_pPaletteGoldColor = [UIColor colorWithRed:g_PaletteColorGoldRed
                                              green:g_PaletteColorGoldGreen
                                               blue:g_PaletteColorGoldBlue
                                              alpha:1.0];
        g_pPaletteSteelBlueColor3 = [UIColor colorWithRed:g_PaletteColorSteelBlueRed
                                                    green:g_PaletteColorSteelBlueGreen
                                                     blue:g_PaletteColorSteelBlueBlue
                                                    alpha:1.0];
    }
}
