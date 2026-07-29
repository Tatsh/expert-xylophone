/**
 * @file
 * Shared engine data tables, layout metrics, localised UI strings, and palette colours, seeded at
 * startup and read from the Objective-C application code.
 */

#pragma once

#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#include <CoreGraphics/CoreGraphics.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __OBJC__
/**
 * @brief The per-difficulty minimum valid edited score (basic, medium, hard), used by the score
 * validator. Seeded once at startup by @c BuildGaugeThresholdArrays.
 * @ghidraAddress 0x3de4a0
 */
extern NSArray *g_pScoreMinThresholds;
/**
 * @brief The per-difficulty maximum valid edited score (basic, medium, hard).
 * @ghidraAddress 0x3de4a8
 */
extern NSArray *g_pScoreMaxThresholds;
#endif
/**
 * @brief Seeds @c g_pScoreMinThresholds and @c g_pScoreMaxThresholds. Run once at startup.
 * @ghidraAddress 0x148a70
 */
void BuildGaugeThresholdArrays(void);
#ifdef __OBJC__
/**
 * @brief The network API request-descriptor table, keyed by endpoint name (startup,
 * v3_ssl_resource, v3_packlist); each value is @c {method: GET, param: [target]}. Seeded once at
 * startup by @c InitializeApiRequestTable.
 * @ghidraAddress 0x3dc270
 */
extern NSDictionary *g_pApiRequestTable;
#endif
/**
 * @brief Seeds @c g_pApiRequestTable. Run once at startup.
 * @ghidraAddress 0x3394c
 */
void InitializeApiRequestTable(void);
#ifdef __OBJC__
/**
 * @brief The macron-to-vowel katakana lookup table (89 entries): each katakana maps to its vowel-row
 * representative (ア, イ, ウ, エ, オ, or ン for @c ン), used to resolve a prolonged-sound mark to the
 * preceding character's vowel when building a reading key. Seeded once at startup by
 * @c InitializeGlobalLookupTables.
 * @ghidraAddress 0x3dc258
 */
extern NSDictionary *g_pMacronToVowelTable;
/**
 * @brief The small-kana-to-large-kana lookup table (11 entries): ァィゥェォ→アイウエオ, ャュョ→ヤユヨ,
 * ヮ→ワ, ッ→ツ, and ヶ→ケ. Seeded once at startup by @c InitializeGlobalLookupTables.
 * @ghidraAddress 0x3dc260
 */
extern NSDictionary *g_pLowerToUpperTable;
/**
 * @brief The voiced-kana-to-voiceless-kana lookup table (25 entries): each voiced or semi-voiced
 * katakana (ガ, パ, …) maps to its base kana (カ, ハ, …). Seeded once at startup by
 * @c InitializeGlobalLookupTables.
 * @ghidraAddress 0x3dc268
 */
extern NSDictionary *g_pVoiceToVoicelessTable;
#endif
/**
 * @brief Seeds the three katakana normalisation lookup tables (@c g_pLowerToUpperTable,
 * @c g_pMacronToVowelTable, and @c g_pVoiceToVoicelessTable). Run once at startup.
 * @ghidraAddress 0x2ac00
 */
void InitializeGlobalLookupTables(void);
/**
 * @brief The device screen height, in points, used to centre the variant (wide-font) layout.
 * @ghidraAddress 0x3c8834
 */
extern int g_nVariantScreenHeight;
/**
 * @brief The play-field full-height layout Y coordinate: the variant screen height minus one full
 * 1024-unit field (0x400). It is the vertical base for full-screen background sprites (halved to
 * give their centre). Computed by the play-field layout pass (@c ComputePlayfieldLayoutY, 0x554bc).
 * @ghidraAddress 0x3d0008
 */
extern int g_nPlayfieldFullHeightY;
/**
 * @brief The play-field near-lane slope: the ratio of the near note row's offset to the field-centre
 * row scale. Seeded by the play-field layout pass and read by the note and full-combo effect layers.
 * @ghidraAddress 0x3ce95c
 */
extern float g_flPlayfieldNearLaneSlope;
/**
 * @brief The negative of @c g_flPlayfieldNearLaneSlope, used for the bands below the field centre.
 * Seeded by the play-field layout pass.
 * @ghidraAddress 0x3ce960
 */
extern float g_flPlayfieldNearLaneSlopeNeg;
/**
 * @brief The far-lane slope: the ratio of the far note row's offset to the field-centre row scale.
 * Seeded by the play-field layout pass and used to place the far result-star rows.
 * @ghidraAddress 0x3ce96c
 */
extern float g_flPlayfieldFarLaneSlope;
/**
 * @brief The negative far-lane slope: the ratio of the far note row's offset to the field-centre row
 * scale, negated. Seeded by the play-field layout pass and used as a note's target travel line.
 * @ghidraAddress 0x3ce970
 */
extern float g_flPlayfieldFarLaneSlopeNeg;
/**
 * @brief The play-field field height, in 1024-scaled layout units (the base scale times 1024). Every
 * other layout coordinate is derived from it. Seeded by the play-field layout pass.
 * @ghidraAddress 0x3ce930
 */
extern int g_nPlayfieldFieldHeight;
/**
 * @brief The play-field field-centre split, in layout units, subtracted from the portrait gauge
 * positions. Seeded by the play-field layout pass.
 * @ghidraAddress 0x3ce934
 */
extern int g_nPlayfieldCentreSplit;
/** @brief The half-height layout row (field height minus 0x200). @ghidraAddress 0x3ce938 */
extern int g_nPlayfieldHalfHeightY;
/** @brief The near-HUD row at field height minus 0x16. @ghidraAddress 0x3ce93c */
extern int g_nPlayfieldRow16;
/** @brief The near-HUD row at field height minus 0x2c. @ghidraAddress 0x3ce940 */
extern int g_nPlayfieldRow2c;
/** @brief The near-HUD row at field height minus 0x36. @ghidraAddress 0x3ce944 */
extern int g_nPlayfieldRow36;
/** @brief The near-HUD row at field height minus 0x6c. @ghidraAddress 0x3ce948 */
extern int g_nPlayfieldRow6c;
/** @brief The field-centre row scale (centre split minus 0x36), the slope denominator.
 * @ghidraAddress 0x3ce94c */
extern float g_flPlayfieldRowScale;
/** @brief The near note row's top offset constant (0x97). @ghidraAddress 0x3ce950 */
extern int g_nPlayfieldNearRowTop;
/** @brief The near note row at field height minus 0x97. @ghidraAddress 0x3ce954 */
extern int g_nPlayfieldNearRowBottom;
/** @brief The near note row at field height minus 0x12e. @ghidraAddress 0x3ce958 */
extern int g_nPlayfieldRow12e;
/** @brief The far note row's top offset constant (0x15e). @ghidraAddress 0x3ce964 */
extern int g_nPlayfieldFarRowTop;
/** @brief The far note row at field height minus 0x15e. @ghidraAddress 0x3ce968 */
extern int g_nPlayfieldFarRowBottom;
/** @brief The mid note row's top offset constant (0xfa). @ghidraAddress 0x3ce974 */
extern int g_nPlayfieldMidRowTop;
/** @brief The mid note row at field height minus 0xfa. @ghidraAddress 0x3ce978 */
extern int g_nPlayfieldMidRowBottom;
/** @brief The mid-lane slope: the mid row offset over the row scale. @ghidraAddress 0x3ce97c */
extern float g_flPlayfieldMidLaneSlope;
/** @brief The negative mid-lane slope. @ghidraAddress 0x3ce980 */
extern float g_flPlayfieldMidLaneSlopeNeg;
/** @brief The gauge row's top offset (centre split minus 0x3e). @ghidraAddress 0x3ce984 */
extern int g_nPlayfieldGaugeRowTop;
/** @brief The gauge row's bottom offset (field height minus the top). @ghidraAddress 0x3ce988 */
extern int g_nPlayfieldGaugeRowBottom;
/** @brief The extra-lane slope: a fixed -62 offset over the row scale. @ghidraAddress 0x3ce98c */
extern float g_flPlayfieldExtraLaneSlope;
/** @brief The negative extra-lane slope. @ghidraAddress 0x3ce990 */
extern float g_flPlayfieldExtraLaneSlopeNeg;
/** @brief The result row at field height minus 0xe4. @ghidraAddress 0x3ce994 */
extern int g_nPlayfieldRowE4;
/** @brief The result row at field height minus 0x192. @ghidraAddress 0x3ce998 */
extern int g_nPlayfieldRow192;
/**
 * @brief Recomputes the whole play-field vertical layout table from a base scale factor.
 *
 * Scales the input by 1024 into the field height, then derives the field centre, every fixed note and
 * HUD row, the near, far, mid, and extra lane slopes, and the two gauge base bands from it. Run
 * whenever the play-field height changes.
 * @param flScale The base field-height scale factor.
 * @ghidraAddress 0x55488
 */
void ComputePlayfieldLayoutY(float flScale);
/**
 * @brief The two gauge Y base positions used in the alternate (non-zero) gauge mode: the top band's
 * base and the bottom band's base. Seeded by the play-field layout pass.
 * @ghidraAddress 0x3ce99c
 */
extern int g_nGaugeAltTopBaseY;
/** @brief The alternate-mode bottom-band gauge Y base. @ghidraAddress 0x3ce9a0 */
extern int g_nGaugeAltBottomBaseY;
/**
 * @brief The two gauge Y base positions used in the default (mode-zero) gauge layout: the top band's
 * base and the bottom band's base. Seeded by the play-field layout pass.
 * @ghidraAddress 0x3ce9a4
 */
extern int g_nGaugeTopBaseY;
/** @brief The default-mode bottom-band gauge Y base. @ghidraAddress 0x3ce9a8 */
extern int g_nGaugeBottomBaseY;
/**
 * @brief The per-decode-type Blowfish key table shared with the chart loader.
 * @ghidraAddress 0x35b7c8
 */
extern const char *const kChartDecodeKeys[];
/**
 * @brief The per-decode-type Blowfish key lengths that pair with @c kChartDecodeKeys.
 * @ghidraAddress 0x35b7d0
 */
extern const int kChartDecodeKeyLengths[];

/**
 * @brief A shared layout metric of 100 points used across the customize and store screens.
 * @ghidraAddress 0x2ec6f8
 */
extern const double g_dCustomizeLayoutMetric100;
/**
 * @brief The wide (pad) slider and section row height metric.
 * @ghidraAddress 0x2ee950
 */
extern const double g_dSliderRowHeightWide;
/**
 * @brief The slider/section row height for the current device, seeded once at startup by
 * @c InitializeSliderHeightConstant: 20 on the phone layout, else the wide metric.
 * @ghidraAddress 0x3df4f8
 */
extern double g_dSliderRowHeight;
#ifdef __OBJC__
/**
 * @brief The cached opaque-white UI colour, seeded once at startup by @c InitializeUiColorConstants.
 * @ghidraAddress 0x3df560
 */
extern UIColor *g_pCachedWhiteColor;
/**
 * @brief The cached near-white (0.97) UI colour, seeded by @c InitializeUiColorConstants.
 * @ghidraAddress 0x3df568
 */
extern UIColor *g_pCachedOffWhiteColor;
/**
 * @brief The cached blue accent UI colour (RGB 0.012, 0.478, 1.0), seeded by
 * @c InitializeUiColorConstants.
 * @ghidraAddress 0x3df570
 */
extern UIColor *g_pCachedBlueColor;
#endif
/**
 * @brief The mascot message-balloon maximum width on the pad layout.
 * @ghidraAddress 0x2ee930
 */
extern const double g_dMascotMessageMaxWidthPad;
/**
 * @brief The mascot message-balloon maximum width on the phone layout.
 * @ghidraAddress 0x2ee938
 */
extern const double g_dMascotMessageMaxWidthPhone;
/**
 * @brief The shared translucent-panel background white value.
 * @ghidraAddress 0x2ec6a0
 */
extern const double g_dTranslucentAlpha;
/**
 * @brief The shared minimum flash opacity, reused as the store BGM push/pop fade duration.
 * @ghidraAddress 0x2ec6b4
 */
extern const float g_flFlashMinOpacity;
/**
 * @brief The audio-manager resume fade-in time, reused as the shared short UI fade duration.
 * @ghidraAddress 0x2ec718
 */
extern const double g_dAudioManagerResumeFadeInTime;
#ifdef __OBJC__
/**
 * @brief The localised "Delete" action-button title (pad layout).
 * @ghidraAddress 0x3cfbb0
 */
extern NSString *g_pLocalizedDelete;
/**
 * @brief The localised "Download" action-button title (pad layout).
 * @ghidraAddress 0x3cfbc8
 */
extern NSString *g_pLocalizedDownload;
/**
 * @brief The localised action-button title format for a purchasable store item (one @c %@ price,
 * localised from the @c "BUY (%@)" catalogue key).
 * @ghidraAddress 0x3cfb78
 */
extern NSString *g_pLocalizedBuyFormat;
/**
 * @brief The localised "Error" alert title.
 * @ghidraAddress 0x3cfbc8
 */
extern NSString *g_pLocalizedError;
/**
 * @brief The localised "INSTALL" action-button title shown for a purchased but not-yet-downloaded
 * store item.
 * @ghidraAddress 0x3cfc00
 */
extern NSString *g_pLocalizedInstall;
/**
 * @brief The localised "INSTALLED" action-button title shown once a store item is fully downloaded.
 * @ghidraAddress 0x3cfc08
 */
extern NSString *g_pLocalizedInstalled;
/**
 * @brief The localised "INSTALLING" action-button title shown while a store item downloads.
 * @ghidraAddress 0x3cfc10
 */
extern NSString *g_pLocalizedInstalling;
/**
 * @brief The localised "Purchased" disabled-button title shown on the pack detail purchase button
 * once the pack has been bought.
 * @ghidraAddress 0x3cfd10
 */
extern NSString *g_pLocalizedPurchased;
/**
 * @brief The localised "OK" button title.
 * @ghidraAddress 0x3cfce0
 */
extern NSString *g_pLocalizedOK;
/**
 * @brief The localised "Cancel" button title.
 * @ghidraAddress 0x3cfb80
 */
extern NSString *g_pLocalizedCancel;
/**
 * @brief The download-progress modal-dialog message format string (one @c %@ tune name).
 * @ghidraAddress 0x3cfbd8
 */
extern NSString *g_pDownloadingMessageFormat;
/**
 * @brief The delete-confirmation alert message format string (one @c %@ tune name).
 * @ghidraAddress 0x3cfcb8
 */
extern NSString *g_pDeleteConfirmFormat;
/**
 * @brief The localised "failed to connect to the server" message.
 * @ghidraAddress 0x3cfcc0
 */
extern NSString *g_pLocalizedServerConnectFailed;
/**
 * @brief The localised message shown when the server returns no usable data.
 * @ghidraAddress 0x3cfd60
 */
extern NSString *g_pLocalizedServerNoData;
/**
 * @brief The localised "update required" message format shown when the extend-note catalogue
 * demands a newer app version (positional @c %1$@ feature name and @c %2$@ minimum version).
 * @ghidraAddress 0x3cfd68
 */
extern NSString *g_pLocalizedUpdateRequiredFormat;
/**
 * @brief The localised message shown when the shop-master version is older than the app.
 * @ghidraAddress 0x3cfdc8
 */
extern NSString *g_pLocalizedSearchVersionMismatch;
/** @brief The localised "Close" button title. @ghidraAddress 0x3cfba0 */
extern NSString *g_pLocalizedClose;
/** @brief The localised "All" filter title. @ghidraAddress 0x3cfb70 */
extern NSString *g_pLocalizedAll;
/** @brief The localised "Add to playlist" action title. @ghidraAddress 0x3cfb68 */
extern NSString *g_pLocalizedAddToPlaylist;
/** @brief The localised "Create playlist" action title. @ghidraAddress 0x3cfba8 */
extern NSString *g_pLocalizedCreatePlaylist;
/** @brief The localised "No play songs" empty-state message. @ghidraAddress 0x3cfcd8 */
extern NSString *g_pLocalizedNoPlaySongs;
/** @brief The localised "New" badge title. @ghidraAddress 0x3cfcc8 */
extern NSString *g_pLocalizedNew;
/** @brief The localised "SPECIAL" level title. @ghidraAddress 0x3cfca0 */
extern NSString *g_pLocalizedSpecial;
/** @brief The localised "Playlist" title. @ghidraAddress 0x3cfcf0 */
extern NSString *g_pLocalizedPlaylist;
/** @brief The localised "PlaylistName" field label. @ghidraAddress 0x3cfcf8 */
extern NSString *g_pLocalizedPlaylistName;
/** @brief The localised "Return" button title. @ghidraAddress 0x3cfd58 */
extern NSString *g_pLocalizedReturn;
/** @brief The localised "Sort " menu title. @ghidraAddress 0x3cfd80 */
extern NSString *g_pLocalizedSort;
/** @brief The localised "Level" title. @ghidraAddress 0x3cfc20 */
extern NSString *g_pLocalizedLevel;
/**
 * @brief The localised per-level titles "Level1" through "Level15".
 * @ghidraAddress 0x3cfc28
 */
extern NSString *g_pLocalizedLevel1;
extern NSString *g_pLocalizedLevel2;  /*!< @ghidraAddress 0x3cfc60 */
extern NSString *g_pLocalizedLevel3;  /*!< @ghidraAddress 0x3cfc68 */
extern NSString *g_pLocalizedLevel4;  /*!< @ghidraAddress 0x3cfc70 */
extern NSString *g_pLocalizedLevel5;  /*!< @ghidraAddress 0x3cfc78 */
extern NSString *g_pLocalizedLevel6;  /*!< @ghidraAddress 0x3cfc80 */
extern NSString *g_pLocalizedLevel7;  /*!< @ghidraAddress 0x3cfc88 */
extern NSString *g_pLocalizedLevel8;  /*!< @ghidraAddress 0x3cfc90 */
extern NSString *g_pLocalizedLevel9;  /*!< @ghidraAddress 0x3cfc98 */
extern NSString *g_pLocalizedLevel10; /*!< @ghidraAddress 0x3cfc30 */
extern NSString *g_pLocalizedLevel11; /*!< @ghidraAddress 0x3cfc38 */
extern NSString *g_pLocalizedLevel12; /*!< @ghidraAddress 0x3cfc40 */
extern NSString *g_pLocalizedLevel13; /*!< @ghidraAddress 0x3cfc48 */
extern NSString *g_pLocalizedLevel14; /*!< @ghidraAddress 0x3cfc50 */
extern NSString *g_pLocalizedLevel15; /*!< @ghidraAddress 0x3cfc58 */
/**
 * @brief The remaining localised UI strings, all seeded at startup by @c CacheLocalizedUIStrings.
 * The trailing comments carry the binary's own spellings (e.g. "Infomation").
 * @ghidraAddress 0x10090
 */
extern NSString *g_pLocalizedAbort;                   /*!< "Abort". @ghidraAddress 0x3cfb60 */
extern NSString *g_pLocalizedInAppPurchasesDisabled;  /*!< @ghidraAddress 0x3cfb88 */
extern NSString *g_pLocalizedCaution;                 /*!< "Caution". @ghidraAddress 0x3cfb90 */
extern NSString *g_pLocalizedFreeSpaceLow;            /*!< @ghidraAddress 0x3cfb98 */
extern NSString *g_pLocalizedDeleteSong;              /*!< "DELETE SONG". @ghidraAddress 0x3cfbb8 */
extern NSString *g_pLocalizedOpenInMap;               /*!< @ghidraAddress 0x3cfbc0 */
extern NSString *g_pLocalizedDownloadFailed;          /*!< @ghidraAddress 0x3cfbd0 */
extern NSString *g_pLocalizedGameCenterConnectFailed; /*!< @ghidraAddress 0x3cfbe8 */
extern NSString *g_pLocalizedNoLeaderboardData;       /*!< @ghidraAddress 0x3cfbf0 */
extern NSString *g_pLocalizedInfomation; /*!< "Infomation" (sic). @ghidraAddress 0x3cfbf8 */
extern NSString *g_pLocalizedNewVersionAvailable;  /*!< @ghidraAddress 0x3cfc18 */
extern NSString *g_pLocalizedLoadingMixed;         /*!< "Loading...". @ghidraAddress 0x3cfca8 */
extern NSString *g_pLocalizedLoadingUpper;         /*!< "LOADING...". @ghidraAddress 0x3cfcb0 */
extern NSString *g_pLocalizedNo;                   /*!< "NO". @ghidraAddress 0x3cfcd0 */
extern NSString *g_pLocalizedPacks;                /*!< "Packs". @ghidraAddress 0x3cfce8 */
extern NSString *g_pLocalizedProcessing;           /*!< "Processing...". @ghidraAddress 0x3cfd00 */
extern NSString *g_pLocalizedPurchaseCancelled;    /*!< @ghidraAddress 0x3cfd08 */
extern NSString *g_pLocalizedPushUpToShowMore;     /*!< @ghidraAddress 0x3cfd18 */
extern NSString *g_pLocalizedReflecBeatStore;      /*!< @ghidraAddress 0x3cfd20 */
extern NSString *g_pLocalizedReflectedOnLimePoint; /*!< @ghidraAddress 0x3cfd28 */
extern NSString *g_pLocalizedRestorePurchasesButton; /*!< @ghidraAddress 0x3cfd30 */
extern NSString *g_pLocalizedInstallPacksButton;    /*!< "Install PACKs". @ghidraAddress 0x3cfd38 */
extern NSString *g_pLocalizedInstallRestoredPacks;  /*!< @ghidraAddress 0x3cfd40 */
extern NSString *g_pLocalizedRestorePurchasedPacks; /*!< @ghidraAddress 0x3cfd48 */
extern NSString *g_pLocalizedRetry;                 /*!< "Retry". @ghidraAddress 0x3cfd50 */
extern NSString *g_pLocalizedShowMore;              /*!< "SHOW MORE". @ghidraAddress 0x3cfd70 */
extern NSString *g_pLocalizedSlash;                 /*!< "/". @ghidraAddress 0x3cfd78 */
extern NSString *g_pLocalizedStore;                 /*!< "Store". @ghidraAddress 0x3cfd88 */
extern NSString *g_pLocalizedMusicPacks;            /*!< "Music Packs". @ghidraAddress 0x3cfd90 */
extern NSString *g_pLocalizedSequences;             /*!< "Sequences". @ghidraAddress 0x3cfd98 */
extern NSString *g_pLocalizedPurchaseAdditionalSequences; /*!< @ghidraAddress 0x3cfda0 */
extern NSString *g_pLocalizedSequenceRequirementFormat;   /*!< @ghidraAddress 0x3cfda8 */
extern NSString *g_pLocalizedEnableLocationService;       /*!< @ghidraAddress 0x3cfdb0 */
extern NSString *g_pLocalizedTookOverData;                /*!< @ghidraAddress 0x3cfdb8 */
extern NSString *g_pLocalizedUpdateDataFound;             /*!< @ghidraAddress 0x3cfdc0 */
extern NSString *g_pLocalizedYes;                         /*!< "YES". @ghidraAddress 0x3cfdd0 */
extern NSString *g_pLocalizedLatestGameDataRequired;      /*!< @ghidraAddress 0x3cfdd8 */
extern NSString *g_pLocalizedInsufficientPoints;          /*!< @ghidraAddress 0x3cfde0 */
extern NSString
    *g_pLocalizedHasBeenAddedFormat; /*!< "%@ has been added.". @ghidraAddress 0x3cfde8 */
extern NSString *g_pLocalizedUnlockRequirement;    /*!< @ghidraAddress 0x3cfdf0 */
extern NSString *g_pLocalizedUpdateToUnlockSong;   /*!< @ghidraAddress 0x3cfdf8 */
extern NSString *g_pLocalizedAppInstalledReward;   /*!< @ghidraAddress 0x3cfe00 */
extern NSString *g_pLocalizedLimePointAddedFormat; /*!< @ghidraAddress 0x3cfe08 */
extern NSString *g_pLocalizedSearchMusic;          /*!< "Search music". @ghidraAddress 0x3cfe10 */
#endif
/**
 * @brief Seeds every localised UI string global above from the main bundle's localisation table.
 * Run once at startup as a module initialiser.
 * @ghidraAddress 0x10090
 */
void CacheLocalizedUIStrings(void);
/**
 * @brief Seeds @c g_dSliderRowHeight from the device layout. Run once at startup.
 * @ghidraAddress 0x1c0a78
 */
void InitializeSliderHeightConstant(void);
/**
 * @brief Seeds the three cached UI colours. Run once at startup.
 * @ghidraAddress 0x1d52a0
 */
void InitializeUiColorConstants(void);
#ifdef __OBJC__
/**
 * @brief The dimming-cover overlay colour (black at half alpha), seeded by
 * @c InitializeUIColorPalette.
 * @ghidraAddress 0x3cff88
 */
extern UIColor *g_pPaletteDimmingCoverColor;
#endif
// The per-channel palette colour components (each n/255), read by InitializeUIColorPalette. Doubles.
extern const double g_PaletteColorGreenGrassRed;   /*!< @ghidraAddress 0x2ef5e8 */
extern const double g_PaletteColorGreenGrassGreen; /*!< @ghidraAddress 0x2ef5f0 */
extern const double g_PaletteColorMagentaRed;      /*!< @ghidraAddress 0x2ef5f8 */
extern const double g_PaletteColorMagentaGreen;    /*!< @ghidraAddress 0x2ef600 */
extern const double g_PaletteColorMagentaBlue;     /*!< @ghidraAddress 0x2ef608 */
extern const double g_PaletteColorDarkGreenRed;    /*!< @ghidraAddress 0x2ef610 */
extern const double g_PaletteColorDarkGreenGreen;  /*!< @ghidraAddress 0x2ef618 */
extern const double g_PaletteColorLeafGreenRed;    /*!< @ghidraAddress 0x2ef620 */
extern const double g_PaletteColorLeafGreenGreen;  /*!< @ghidraAddress 0x2ef628 */
extern const double g_PaletteColorSteelBlueRed;    /*!< @ghidraAddress 0x2ef630 */
extern const double g_PaletteColorSteelBlueGreen;  /*!< @ghidraAddress 0x2ef638 */
extern const double g_PaletteColorSteelBlueBlue;   /*!< @ghidraAddress 0x2ef640 */
extern const double g_PaletteColorGoldRed;         /*!< @ghidraAddress 0x2ef648 */
extern const double g_PaletteColorGoldGreen;       /*!< @ghidraAddress 0x2ef650 */
extern const double g_PaletteColorGoldBlue;        /*!< @ghidraAddress 0x2ef658 */
/**
 * @brief Seeds every @c g_pPalette* colour above. Run once at startup.
 * @ghidraAddress 0x55120
 */
void InitializeUIColorPalette(void);
/**
 * @brief The gauge-parts scale table: the two per-side X scales (-8/9 and +8/9) that
 * @c SyncGaugeValuesFromGameSystem applies to the sheet inset, plus a trailing 288 constant.
 * @ghidraAddress 0x3dc5c0
 */
extern float g_aGaugePartsScale[3];
/**
 * @brief Seeds @c g_aGaugePartsScale. Run once at startup.
 * @ghidraAddress 0x83cf0
 */
void InitializeGaugeAngleTable(void);
/**
 * @brief The difficulty-number image centre offset added over the button centre, per device: the
 * pad and phone layouts each get their own {x, y}. Seeded by @c InitializeCGAffineTransformGlobals.
 * @ghidraAddress 0x3dc6e0
 */
extern CGPoint g_difficultyNumberOffsetPad;
extern CGPoint g_difficultyNumberOffsetPhone; /*!< @ghidraAddress 0x3dc6f0 */
/**
 * @brief Seeds @c g_difficultyNumberOffsetPad and @c g_difficultyNumberOffsetPhone. Run once at
 * startup.
 * @ghidraAddress 0xc933c
 */
void InitializeCGAffineTransformGlobals(void);
/**
 * @brief The Twitter share-image element draw positions, indexed: 0 title, 1 artist, 2 difficulty,
 * 3 level (non-Colette), 4 line, 5 level (Colette), 6 just-reflec badge, 7 full-combo badge. Read by
 * @c -[TwitterImageCreater createImage]. Seeded once by @c InitializeParticleOffsetTable.
 * @ghidraAddress 0x3dc5d0
 */
extern CGPoint g_aTwitterImageDrawPos[8];
/**
 * @brief Seeds @c g_aTwitterImageDrawPos. Run once at startup.
 * @ghidraAddress 0x88f24
 */
void InitializeParticleOffsetTable(void);
/**
 * @brief The setting-screen layout table: a cache of the panel and per-theme button-column geometry
 * points, most derived by offsetting a template point by the base panel origin/size. The button-
 * column origins live at @c [8]/@c [10] and the step gaps at @c [14]/@c [17] (read by @c RBSettingView).
 * Seeded once at startup by @c InitializeSettingLayoutGlobals.
 * @ghidraAddress 0x3dc850
 */
extern CGPoint g_aSettingLayout[26];
/**
 * @brief Seeds @c g_aSettingLayout. Run once at startup.
 * @ghidraAddress 0xec450
 */
void InitializeSettingLayoutGlobals(void);
/**
 * @brief The extend-note view's difficulty-number image centre offset, per device (the same {x, y}
 * pair pattern used by the music-detail view). Seeded by @c InitializeIdentityTransformGlobals.
 * @ghidraAddress 0x3dc2a0
 */
extern CGPoint g_extendNoteNumberOffsetPad;
extern CGPoint g_extendNoteNumberOffsetPhone; /*!< @ghidraAddress 0x3dc2b0 */
/**
 * @brief Seeds @c g_extendNoteNumberOffsetPad and @c g_extendNoteNumberOffsetPhone. Run once at
 * startup.
 * @ghidraAddress 0x3d04c
 */
void InitializeIdentityTransformGlobals(void);
#ifdef __OBJC__
/**
 * @brief The shared UI palette colours, indexed by the customise/playlist theme code.
 * @ghidraAddress 0x3cff90
 */
extern UIColor *g_pPaletteWhiteColor;       /*!< @ghidraAddress 0x3cff90 */
extern UIColor *g_pPaletteOpaqueBlackColor; /*!< @ghidraAddress 0x3cff98 */
extern UIColor *g_pPaletteGreenGrassColor;  /*!< @ghidraAddress 0x3cffa0 */
extern UIColor *g_pPaletteMagentaColor;     /*!< @ghidraAddress 0x3cffa8 */
extern UIColor *g_pPalettePurpleColor;      /*!< @ghidraAddress 0x3cffb0 */
extern UIColor *g_pPaletteDarkGreenColor;   /*!< @ghidraAddress 0x3cffb8 */
extern UIColor *g_pPaletteLeafGreenColor;   /*!< @ghidraAddress 0x3cffc0 */
extern UIColor *g_pPaletteGreenGrassColor2; /*!< @ghidraAddress 0x3cffc8 */
extern UIColor *g_pPaletteMagentaColor2;    /*!< @ghidraAddress 0x3cffd0 */
extern UIColor *g_pPaletteLeafGreenColor2;  /*!< @ghidraAddress 0x3cffd8 */
extern UIColor *g_pPaletteSteelBlueColor;   /*!< @ghidraAddress 0x3cffe0 */
extern UIColor *g_pPaletteLeafGreenColor3;  /*!< @ghidraAddress 0x3cffe8 */
extern UIColor *g_pPaletteSteelBlueColor2;  /*!< @ghidraAddress 0x3cfff0 */
extern UIColor *g_pPaletteGoldColor;        /*!< @ghidraAddress 0x3cfff8 */
extern UIColor *g_pPaletteSteelBlueColor3;  /*!< @ghidraAddress 0x3d0000 */
#endif
/** @brief The 32-point shared layout metric. @ghidraAddress 0x2ee9b0 */
extern const double g_dLayoutMetricThirtyTwo;

/**
 * @brief The tutorial-pastel message-bubble clip rectangles, indexed: 0 head, 1 body, 2 left tail,
 * 3 right tail. The retina rectangles cut out of the message artwork atlas, read by the tutorial
 * pastel classes' @c -getClipList:. Seeded once at startup by @c InitializeTutorialPastelLayoutTables.
 * @ghidraAddress 0x3df3e0
 */
extern CGRect g_aTutorialPastelClipRects[4];
/**
 * @brief The tutorial-pastel child layout points, indexed: 0 head, 1 body, 2 left tail, 3 right
 * tail. Seeded once at startup by @c InitializeTutorialPastelLayoutTables.
 * @ghidraAddress 0x3df460
 */
extern CGPoint g_aTutorialPastelPositions[4];
/**
 * @brief Seeds @c g_aTutorialPastelClipRects and @c g_aTutorialPastelPositions. Run once at startup.
 * @ghidraAddress 0x1b81d8
 */
void InitializeTutorialPastelLayoutTables(void);

#ifdef __cplusplus
}
#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
