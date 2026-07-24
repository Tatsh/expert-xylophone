/**
 * @file
 * Shared engine data tables, layout metrics, localised UI strings, and palette colours, seeded at
 * startup and read from the Objective-C application code.
 */

#pragma once

#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief The macron-to-vowel katakana lookup table (89 entries).
 * @ghidraAddress 0x3dc258
 */
extern NSDictionary *const g_pMacronToVowelTable;
/**
 * @brief The small-kana-to-large-kana lookup table (11 entries).
 * @ghidraAddress 0x3dc260
 */
extern NSDictionary *const g_pLowerToUpperTable;
/**
 * @brief The voiced-kana-to-voiceless-kana lookup table (25 entries).
 * @ghidraAddress 0x3dc268
 */
extern NSDictionary *const g_pVoiceToVoicelessTable;
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
 * @brief The play-field top edge, in normalised field units (negative). Seeded by the play-field
 * layout pass and read by the note and full-combo effect layers.
 * @ghidraAddress 0x3ce95c
 */
extern float g_flPlayfieldBoundTop;
/**
 * @brief The play-field bottom edge, in normalised field units (positive). Seeded by the play-field
 * layout pass and read by the note and full-combo effect layers.
 * @ghidraAddress 0x3ce960
 */
extern float g_flPlayfieldBoundBottom;
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
/**
 * @brief The localised "Delete" action-button title (pad layout).
 * @ghidraAddress 0x3cfbb0
 */
extern NSString *const g_pLocalizedDelete;
/**
 * @brief The localised "Download" action-button title (pad layout).
 * @ghidraAddress 0x3cfbc8
 */
extern NSString *const g_pLocalizedDownload;
/**
 * @brief The localised action-button title format for a purchasable store item (one @c %@ price,
 * localised from the @c "BUY (%@)" catalogue key).
 * @ghidraAddress 0x3cfb78
 */
extern NSString *const g_pLocalizedBuyFormat;
/**
 * @brief The localised "Error" alert title.
 * @ghidraAddress 0x3cfbc8
 */
extern NSString *const g_pLocalizedError;
/**
 * @brief The localised "INSTALL" action-button title shown for a purchased but not-yet-downloaded
 * store item.
 * @ghidraAddress 0x3cfc00
 */
extern NSString *const g_pLocalizedInstall;
/**
 * @brief The localised "INSTALLED" action-button title shown once a store item is fully downloaded.
 * @ghidraAddress 0x3cfc08
 */
extern NSString *const g_pLocalizedInstalled;
/**
 * @brief The localised "INSTALLING" action-button title shown while a store item downloads.
 * @ghidraAddress 0x3cfc10
 */
extern NSString *const g_pLocalizedInstalling;
/**
 * @brief The localised "Purchased" disabled-button title shown on the pack detail purchase button
 * once the pack has been bought.
 * @ghidraAddress 0x3cfd10
 */
extern NSString *const g_pLocalizedPurchased;
/**
 * @brief The localised "OK" button title.
 * @ghidraAddress 0x3cfce0
 */
extern NSString *const g_pLocalizedOK;
/**
 * @brief The localised "Cancel" button title.
 * @ghidraAddress 0x3cfb80
 */
extern NSString *const g_pLocalizedCancel;
/**
 * @brief The download-progress modal-dialog message format string (one @c %@ tune name).
 * @ghidraAddress 0x3cfbd8
 */
extern NSString *const g_pDownloadingMessageFormat;
/**
 * @brief The delete-confirmation alert message format string (one @c %@ tune name).
 * @ghidraAddress 0x3cfcb8
 */
extern NSString *const g_pDeleteConfirmFormat;
/**
 * @brief The localised "failed to connect to the server" message.
 * @ghidraAddress 0x3cfcc0
 */
extern NSString *const g_pLocalizedServerConnectFailed;
/**
 * @brief The localised message shown when the server returns no usable data.
 * @ghidraAddress 0x3cfd60
 */
extern NSString *const g_pLocalizedServerNoData;
/**
 * @brief The localised "update required" message format shown when the extend-note catalogue
 * demands a newer app version (positional @c %1$@ feature name and @c %2$@ minimum version).
 * @ghidraAddress 0x3cfd68
 */
extern NSString *const g_pLocalizedUpdateRequiredFormat;
/**
 * @brief The localised message shown when the shop-master version is older than the app.
 * @ghidraAddress 0x3cfdc8
 */
extern NSString *const g_pLocalizedSearchVersionMismatch;
/** @brief The localised "Close" button title. @ghidraAddress 0x3cfba0 */
extern NSString *const g_pLocalizedClose;
/** @brief The localised "All" filter title. @ghidraAddress 0x3cfb70 */
extern NSString *const g_pLocalizedAll;
/** @brief The localised "Add to playlist" action title. @ghidraAddress 0x3cfb68 */
extern NSString *const g_pLocalizedAddToPlaylist;
/** @brief The localised "Create playlist" action title. @ghidraAddress 0x3cfba8 */
extern NSString *const g_pLocalizedCreatePlaylist;
/** @brief The localised "No play songs" empty-state message. @ghidraAddress 0x3cfcd8 */
extern NSString *const g_pLocalizedNoPlaySongs;
/** @brief The localised "New" badge title. @ghidraAddress 0x3cfcc8 */
extern NSString *const g_pLocalizedNew;
/** @brief The localised "SPECIAL" level title. @ghidraAddress 0x3cfca0 */
extern NSString *const g_pLocalizedSpecial;
/** @brief The localised "Playlist" title. @ghidraAddress 0x3cfcf0 */
extern NSString *const g_pLocalizedPlaylist;
/** @brief The localised "PlaylistName" field label. @ghidraAddress 0x3cfcf8 */
extern NSString *const g_pLocalizedPlaylistName;
/** @brief The localised "Return" button title. @ghidraAddress 0x3cfd58 */
extern NSString *const g_pLocalizedReturn;
/** @brief The localised "Sort " menu title. @ghidraAddress 0x3cfd80 */
extern NSString *const g_pLocalizedSort;
/** @brief The localised "Level" title. @ghidraAddress 0x3cfc20 */
extern NSString *const g_pLocalizedLevel;
/**
 * @brief The localised per-level titles "Level1" through "Level15".
 * @ghidraAddress 0x3cfc28
 */
extern NSString *const g_pLocalizedLevel1;
extern NSString *const g_pLocalizedLevel2;  /*!< @ghidraAddress 0x3cfc60 */
extern NSString *const g_pLocalizedLevel3;  /*!< @ghidraAddress 0x3cfc68 */
extern NSString *const g_pLocalizedLevel4;  /*!< @ghidraAddress 0x3cfc70 */
extern NSString *const g_pLocalizedLevel5;  /*!< @ghidraAddress 0x3cfc78 */
extern NSString *const g_pLocalizedLevel6;  /*!< @ghidraAddress 0x3cfc80 */
extern NSString *const g_pLocalizedLevel7;  /*!< @ghidraAddress 0x3cfc88 */
extern NSString *const g_pLocalizedLevel8;  /*!< @ghidraAddress 0x3cfc90 */
extern NSString *const g_pLocalizedLevel9;  /*!< @ghidraAddress 0x3cfc98 */
extern NSString *const g_pLocalizedLevel10; /*!< @ghidraAddress 0x3cfc30 */
extern NSString *const g_pLocalizedLevel11; /*!< @ghidraAddress 0x3cfc38 */
extern NSString *const g_pLocalizedLevel12; /*!< @ghidraAddress 0x3cfc40 */
extern NSString *const g_pLocalizedLevel13; /*!< @ghidraAddress 0x3cfc48 */
extern NSString *const g_pLocalizedLevel14; /*!< @ghidraAddress 0x3cfc50 */
extern NSString *const g_pLocalizedLevel15; /*!< @ghidraAddress 0x3cfc58 */
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
/** @brief The 32-point shared layout metric. @ghidraAddress 0x2ee9b0 */
extern const double g_dLayoutMetricThirtyTwo;

#ifdef __cplusplus
}
#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
