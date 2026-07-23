/** @file
 * A store pack model describing one purchasable song pack: its identifier, its StoreKit product,
 * the display metadata read from the catalogue entry dictionary, and the tunes it contains.
 * Instances are built either from a @c SKProduct, from a bare pack identifier, or from a server
 * catalogue entry dictionary, and are handed to @c RBStorePageViewController and its detail views.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackInfo, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class StoreMusicInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A store model for a single purchasable song pack.
 */
@interface StorePackInfo : NSObject

/**
 * @brief The pack identifier.
 * @ghidraAddress 0x69278 (getter)
 * @ghidraAddress 0x69288 (setter)
 */
@property(nonatomic, assign) int packID;
/**
 * @brief Whether the pack is flagged as new in the catalogue.
 * @ghidraAddress 0x69298 (getter)
 * @ghidraAddress 0x692a8 (setter)
 */
@property(nonatomic, assign) BOOL isNew;
/**
 * @brief The pack artwork URL.
 * @ghidraAddress 0x692b8 (getter)
 * @ghidraAddress 0x692c8 (setter)
 */
@property(nonatomic, strong, nullable) NSString *artworkURL;
/**
 * @brief The pack display name.
 * @ghidraAddress 0x69300 (getter)
 * @ghidraAddress 0x69310 (setter)
 */
@property(nonatomic, strong, nullable) NSString *packName;
/**
 * @brief The pack long-form comment.
 * @ghidraAddress 0x69348 (getter)
 * @ghidraAddress 0x69358 (setter)
 */
@property(nonatomic, strong, nullable) NSString *comment;
/**
 * @brief The pack short-form comment.
 * @ghidraAddress 0x69390 (getter)
 * @ghidraAddress 0x693a0 (setter)
 */
@property(nonatomic, strong, nullable) NSString *s_comment;
/**
 * @brief The pack copyright notice.
 * @ghidraAddress 0x693d8 (getter)
 * @ghidraAddress 0x693e8 (setter)
 */
@property(nonatomic, strong, nullable) NSString *copyright;
/**
 * @brief The number of extend-note charts advertised for the pack.
 * @ghidraAddress 0x69420 (getter)
 * @ghidraAddress 0x69430 (setter)
 */
@property(nonatomic, assign) int extCount;
/**
 * @brief The tunes contained in the pack, once its detail is loaded.
 * @ghidraAddress 0x69440 (getter)
 * @ghidraAddress 0x69450 (setter)
 */
@property(nonatomic, strong, nullable) NSArray<StoreMusicInfo *> *musicInfos;
/**
 * @brief The pack artist URL.
 * @ghidraAddress 0x69488 (getter)
 * @ghidraAddress 0x69498 (setter)
 */
@property(nonatomic, strong, nullable) NSString *artistURL;
/**
 * @brief The pack artist-banner URL.
 * @ghidraAddress 0x694d0 (getter)
 * @ghidraAddress 0x694e0 (setter)
 */
@property(nonatomic, strong, nullable) NSString *bunnerURL;
/**
 * @brief The StoreKit product backing the pack, once loaded.
 * @ghidraAddress 0x69518 (getter)
 * @ghidraAddress 0x69528 (setter)
 */
@property(nonatomic, strong, nullable) SKProduct *product;
/**
 * @brief The most recent detail-download error message.
 * @ghidraAddress 0x69560 (getter)
 * @ghidraAddress 0x69570 (setter)
 */
@property(nonatomic, strong, nullable) NSString *ErrorMessage;

/**
 * @brief Build a pack info from a StoreKit product.
 *
 * The product is stored and the pack identifier is derived from its product identifier through
 * @c StoreUtil.
 * @param product The StoreKit product to wrap.
 * @return The initialised instance, or @c nil when @p product is @c nil.
 * @ghidraAddress 0x68824
 */
- (nullable instancetype)initWithProduct:(SKProduct *)product;

/**
 * @brief Build a pack info from a bare pack identifier.
 * @param packID The pack identifier.
 * @return The initialised instance.
 * @ghidraAddress 0x68924
 */
- (instancetype)initWithPackID:(int)packID;

/**
 * @brief Build a pack info from a catalogue entry dictionary.
 *
 * The dictionary provides the @c ID entry, from which the pack identifier is read, and the entry is
 * then handed to @c setDictionary: to populate the remaining metadata.
 * @param dictionary The catalogue entry dictionary to read.
 * @return The initialised instance, or @c nil when @p dictionary is @c nil.
 * @ghidraAddress 0x68984
 */
- (nullable instancetype)initWithDictionary:(NSDictionary *)dictionary;

/**
 * @brief Populate the pack metadata from a catalogue entry dictionary.
 *
 * The entry is ignored unless its @c ID matches the pack's own identifier. The @c Name, @c Comment,
 * @c ShortComment, @c IsNew, @c Copyright, @c ArtworkURL, @c ArtistURL, and @c ArtistBunnerURL
 * entries are copied (the three URL entries only when they are @c NSString instances), the
 * @c ExtNum entry sets the advertised extend-note count, and the @c MusicList entry is handed to
 * @c setMusicInfo:.
 * @param dictionary The catalogue entry dictionary to read.
 * @return @c YES when the entry matched and at least one contained tune was stored.
 * @ghidraAddress 0x68a54
 */
- (BOOL)setDictionary:(NSDictionary *)dictionary;

/**
 * @brief Build the contained-tune list from a music-list array of catalogue entry dictionaries.
 *
 * Does nothing when the tune list is already loaded. Each entry becomes a @c StoreMusicInfo through
 * its @c initWithDictionary:, and at most four tunes are kept; the resulting immutable list is
 * stored in @c musicInfos.
 * @param musicInfo The array of tune catalogue entry dictionaries.
 * @return @c YES when at least one tune was stored.
 * @ghidraAddress 0x68e94
 */
- (BOOL)setMusicInfo:(nullable NSArray<NSDictionary *> *)musicInfo;

/**
 * @brief The pack's localised price string, formatted from the StoreKit product via @c StoreUtil.
 * @return The formatted price string.
 * @ghidraAddress 0x68e30
 */
- (nullable NSString *)priceString;

/**
 * @brief Whether the pack still needs its detailed tune info downloaded.
 * @return @c YES when the tune list has not yet been loaded.
 * @ghidraAddress 0x69114
 */
- (BOOL)downloadDetailInfo;

/**
 * @brief Whether every contained tune's archive is already present on disk.
 * @return @c YES when the tune list is empty or every tune reports @c fileExist.
 * @ghidraAddress 0x69150
 */
- (BOOL)allDownloaded;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
