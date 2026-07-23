/** @file
 * A store extend-note model describing one purchasable extend-note pack item: the numeric
 * extend-note and pack identifiers, its price, its comment, its download URLs, and the StoreKit
 * product backing it. It is a specialisation of @c StoreMusicInfo — the tune metadata (identifier,
 * name, artist, artwork, sample, iTunes URLs, and per-difficulty levels) is inherited — and adds
 * the extend-note-specific fields together with the purchase-and-download state that drives the
 * store pack cell's action button. Instances are built from a server catalogue dictionary, from a
 * @c SKProduct, or from a bare extend-note identifier, and are handed to
 * @c RBStoreExtendPageViewController and @c RBStoreManageViewController.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteInfo, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "StoreMusicInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The action the store pack cell's button performs for an extend-note item.
 * @ghidraAddress 0x793cc
 */
typedef NS_ENUM(NSInteger, StoreExtendNoteButtonState) {
    StoreExtendNoteButtonStateError = -1,       /*!< The item is in an inconsistent purchase
                                                  state. */
    StoreExtendNoteButtonStateMoreInfo = 0,     /*!< The pack is not purchased; the button opens
                                                  more info. */
    StoreExtendNoteButtonStatePurchase = 1,     /*!< The pack is purchased but the note is not; the
                                                  button purchases it. */
    StoreExtendNoteButtonStateDownloadBin = 2,  /*!< The note is purchased but its tune archive is
                                                  not downloaded. */
    StoreExtendNoteButtonStateDownloadNote = 3, /*!< The tune archive is downloaded but the note
                                                   file is not. */
    StoreExtendNoteButtonStateInstalled = 4,    /*!< The pack, its tune archive, and its note file
                                                   are all present. */
};

/**
 * @brief A store model for a single purchasable extend-note pack item.
 */
@interface StoreExtendNoteInfo : StoreMusicInfo

/**
 * @brief The extend-note item's App Store product identifier.
 * @ghidraAddress 0x798f8 (getter)
 * @ghidraAddress 0x79908 (setter)
 */
@property(nonatomic, assign) int pid;
/**
 * @brief The extend-note chart identifier of the associated tune.
 * @ghidraAddress 0x79918 (getter)
 * @ghidraAddress 0x79928 (setter)
 */
@property(nonatomic, assign) int extMusicID;
/**
 * @brief The identifier of the pack that contains this extend note.
 * @ghidraAddress 0x79938 (getter)
 * @ghidraAddress 0x79948 (setter)
 */
@property(nonatomic, assign) int packID;
/**
 * @brief The containing pack's display name.
 * @ghidraAddress 0x79958 (getter)
 * @ghidraAddress 0x79968 (setter)
 */
@property(nonatomic, strong, nullable) NSString *packName;
/**
 * @brief The extend-note item's comment text.
 * @ghidraAddress 0x799a0 (getter)
 * @ghidraAddress 0x799b0 (setter)
 */
@property(nonatomic, strong, nullable) NSString *comment;
/**
 * @brief The extend-note item's price in the catalogue currency.
 * @ghidraAddress 0x799e8 (getter)
 * @ghidraAddress 0x799f8 (setter)
 */
@property(nonatomic, assign) int price;
/**
 * @brief The extend note's chart difficulty level.
 * @ghidraAddress 0x79a08 (getter)
 * @ghidraAddress 0x79a18 (setter)
 */
@property(nonatomic, assign) int difficulty;
/**
 * @brief The download URL for the extend-note file.
 * @ghidraAddress 0x79a28 (getter)
 * @ghidraAddress 0x79a38 (setter)
 */
@property(nonatomic, strong, nullable) NSString *extendNoteURL;
/**
 * @brief The download URL for the tune archive that hosts the extend note.
 * @ghidraAddress 0x79a70 (getter)
 * @ghidraAddress 0x79a80 (setter)
 */
@property(nonatomic, strong, nullable) NSString *extendURL;
/**
 * @brief Whether the extend-note item is flagged as new in the catalogue.
 * @ghidraAddress 0x79ab8 (getter)
 * @ghidraAddress 0x79ac8 (setter)
 */
@property(nonatomic, assign) BOOL isNew;
/**
 * @brief An informational deep link associated with the item, when present.
 * @ghidraAddress 0x79ad8 (getter)
 */
@property(nonatomic, readonly, strong, nullable) NSString *linkURL;
/**
 * @brief The StoreKit product backing the extend-note item, once loaded.
 * @ghidraAddress 0x79ae8 (getter)
 * @ghidraAddress 0x79af8 (setter)
 */
@property(nonatomic, strong, nullable) SKProduct *product;

/**
 * @brief Whether the extend-note item's containing pack has been purchased.
 * @return @c YES when the pack identifier is positive and its product is recorded as purchased.
 * @ghidraAddress 0x794d8
 */
@property(nonatomic, readonly) BOOL purchasedPack;
/**
 * @brief Whether the extend-note item itself has been purchased.
 * @return @c YES when the item identifier is positive and its product is recorded as purchased.
 * @ghidraAddress 0x795c0
 */
@property(nonatomic, readonly) BOOL purchasedNote;
/**
 * @brief Whether the tune archive that hosts the extend note is already downloaded.
 * @return @c YES when the tune is a purchased tune and its archive is present on disk.
 * @ghidraAddress 0x796a8
 */
@property(nonatomic, readonly) BOOL alreadyDownloadBin;
/**
 * @brief Whether the extend-note file is already downloaded.
 * @return @c YES when the extend note is purchased and its file is present on disk.
 * @ghidraAddress 0x797e8
 */
@property(nonatomic, readonly) BOOL alreadyDownloadNote;

/**
 * @brief Build an extend-note item from a server catalogue dictionary.
 *
 * The dictionary's @c Music sub-dictionary is handed to @c StoreMusicInfo to populate the inherited
 * tune metadata, then the top-level @c PID, @c ExtID, @c PackID, @c PackName, @c Comment, @c Price,
 * @c ExtLevel, @c ExtURL, @c ExtURL2, and @c IsNew entries populate the extend-note fields.
 * @param dictionary The catalogue dictionary to read.
 * @return The initialised item, or @c nil when the inherited initialiser rejects the @c Music
 * entry.
 * @ghidraAddress 0x77e58
 */
- (nullable instancetype)initWithDictionary:(nullable NSDictionary *)dictionary;

/**
 * @brief Build an extend-note item from a flat catalogue dictionary.
 *
 * Reads the top-level @c PID, @c ExtID, @c PackID, @c PackName, @c Comment, @c Price, @c ExtLevel,
 * @c ExtURL, @c ExtURL2, and @c IsNew entries; unlike @c initWithDictionary: it does not read a
 * nested @c Music sub-dictionary.
 * @param dictionary The flat catalogue dictionary to read.
 * @return The initialised item, or @c nil when the superclass initialiser fails.
 * @ghidraAddress 0x781f4
 */
- (nullable instancetype)initWithExtendDictionary:(nullable NSDictionary *)dictionary;

/**
 * @brief Build an extend-note item from a StoreKit product.
 *
 * The product is stored and the item identifier is derived from its product identifier through
 * @c StoreUtil.
 * @param product The StoreKit product to wrap.
 * @return The initialised item, or @c nil when @p product is @c nil or the superclass initialiser
 * fails.
 * @ghidraAddress 0x7858c
 */
- (nullable instancetype)initWithProduct:(nullable SKProduct *)product;

/**
 * @brief Build an extend-note item from a bare extend-note identifier.
 * @param extendNoteID The extend-note item identifier to store as the product identifier.
 * @return The initialised item, or @c nil when the superclass initialiser fails.
 * @ghidraAddress 0x786d8
 */
- (nullable instancetype)initWithExtendNoteID:(int)extendNoteID;

/**
 * @brief Populate the extend-note fields from a server catalogue dictionary.
 *
 * The entry is ignored unless its @c PID matches the item's own identifier. When it matches, the
 * @c PackID, @c ExtID, @c PackName, @c Comment, @c Price, @c ExtLevel, @c ExtURL, @c ExtURL2, and
 * @c IsNew entries populate the extend-note fields, and the nested @c Music sub-dictionary's @c ID,
 * @c Name, @c Artist, @c ItemURL, @c SampleURL, @c ArtworkURL, @c iTunesURL, and @c Level entries
 * populate the inherited tune metadata. The three @c Level entries are clamped: basic to one
 * through ten and medium and hard to one through eleven.
 * @param dictionary The catalogue dictionary to read.
 * @return @c YES when the entry's @c PID matched the item's identifier.
 * @ghidraAddress 0x7875c
 */
- (BOOL)setDictionary:(nullable NSDictionary *)dictionary;

/**
 * @brief Whether the extend-note file is already present on disk.
 * @return @c YES when the extend note's purchased file exists.
 * @ghidraAddress 0x78ff0
 */
- (BOOL)extFileExist;

/**
 * @brief The tint colour for the pack cell's action button.
 * @return A dark-blue colour for a not-purchased pack, purple for a purchased pack whose note is
 * not purchased, blue while the item is downloading, and grey once it is installed or in error.
 * @ghidraAddress 0x79078
 */
- (nullable UIColor *)getButtonColor;

/**
 * @brief The title text for the pack cell's action button.
 * @return The more-info label for a not-purchased pack, a formatted "buy for the price" title for a
 * purchased pack whose note is not purchased, the download label while downloading, the installed
 * label once complete, and the error label otherwise.
 * @ghidraAddress 0x791fc
 */
- (nullable NSString *)getButtonName;

/**
 * @brief The action the pack cell's button should perform for the item.
 * @return The current button state.
 * @ghidraAddress 0x793cc
 */
- (StoreExtendNoteButtonState)getButtonState;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
