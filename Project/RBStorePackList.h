/** @file
 * The store pack-list model. It fetches the server pack catalogue one genre page at a time through a
 * @c Downloader, parses the JSON into @c StorePackInfo records grouped into @c StorePackListGenre
 * genres, resolves each pack's StoreKit product through an @c SKProductsRequest, and reports load
 * progress to its @c StorePackListDelegate. It also caches the parsed packs keyed by pack identifier
 * and exposes the queued deep-link ("open store") pack request.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStorePackList, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import "StorePackListDelegate.h"

@class Downloader;
@class StorePackInfo;
@class StorePackListGenre;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store pack-list model.
 *
 * Adopts @c SKProductsRequestDelegate so it can turn the pack identifiers parsed from the catalogue
 * into localised StoreKit products.
 */
@interface RBStorePackList : NSObject <SKProductsRequestDelegate>

/**
 * @brief A copy of the store-country code cached from the most recently resolved StoreKit products,
 * or @c nil when no products have resolved yet.
 * @return A copy of the cached store-country code, or @c nil.
 * @ghidraAddress 0x1f05fc
 */
+ (nullable NSString *)storeCountry;

/**
 * @brief The parsed packs, keyed by insertion order and cached across pages.
 * @ghidraAddress 0x1f3460 (getter)
 * @ghidraAddress 0x1f3470 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<StorePackInfo *> *arrayPackInfo;
/**
 * @brief The promotion banner entries for the current catalogue.
 * @ghidraAddress 0x1f3418 (getter)
 * @ghidraAddress 0x1f3428 (setter)
 */
@property(nonatomic, strong, nullable) NSArray *promotionList;
/**
 * @brief The in-flight catalogue-page downloader, or @c nil when idle.
 * @ghidraAddress 0x1f34a8 (getter)
 * @ghidraAddress 0x1f34b8 (setter)
 */
@property(nonatomic, strong, nullable) Downloader *packlistDownloader;
/**
 * @brief The most recent catalogue page, retained while the StoreKit product request runs.
 * @ghidraAddress 0x1f34f0 (getter)
 * @ghidraAddress 0x1f3500 (setter)
 */
@property(nonatomic, strong, nullable) NSDictionary *tempPackList;
/**
 * @brief The in-flight StoreKit product request, or @c nil when idle.
 * @ghidraAddress 0x1f3538 (getter)
 * @ghidraAddress 0x1f3548 (setter)
 */
@property(nonatomic, strong, nullable) SKProductsRequest *productsRequest;
/**
 * @brief The number of packs fetched so far (retained for parity; superseded by the genre model).
 * @ghidraAddress 0x1f3580 (getter)
 * @ghidraAddress 0x1f3590 (setter)
 */
@property(nonatomic, assign) unsigned int fetchedPackNum;
/**
 * @brief Whether the running StoreKit request is the queued deep-link ("open store") request.
 * @ghidraAddress 0x1f35a0 (getter)
 * @ghidraAddress 0x1f35b0 (setter)
 */
@property(nonatomic, assign) BOOL isOptionalProductRequest;
/**
 * @brief The genres, each holding an ordered list of pack identifiers.
 * @ghidraAddress 0x1f35c0 (getter)
 * @ghidraAddress 0x1f35d0 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<StorePackListGenre *> *arrayGenre;
/**
 * @brief The genre whose page is currently being fetched.
 * @ghidraAddress 0x1f3608 (getter)
 * @ghidraAddress 0x1f3618 (setter)
 */
@property(nonatomic, strong, nullable) StorePackListGenre *genreFetching;
/**
 * @brief The delegate notified of load results.
 * @ghidraAddress 0x1f33d4 (getter)
 * @ghidraAddress 0x1f33f4 (setter)
 */
@property(nonatomic, weak, nullable) id<StorePackListDelegate> delegate;
/**
 * @brief Whether the current genre's pack list can be extended with another page.
 * @ghidraAddress 0x1f3408 (getter)
 */
@property(nonatomic, assign, readonly) BOOL packlistContinued;

/**
 * @brief The cached packs.
 * @return The cached pack list.
 * @ghidraAddress 0x1f09d0
 */
- (nullable NSMutableArray<StorePackInfo *> *)packInfos;

/**
 * @brief The number of available genres.
 * @return The genre count.
 * @ghidraAddress 0x1f09dc
 */
- (NSUInteger)numGenres;

/**
 * @brief The display names of every genre, in order.
 * @return An array of genre names.
 * @ghidraAddress 0x1f0a3c
 */
- (nullable NSArray<NSString *> *)genreNames;

/**
 * @brief Build the genre models from the catalogue's genre payload.
 *
 * The payload is a two-element array of parallel collections: the first element is the array of
 * genre identifiers, the second the array of genre names. A @c StorePackListGenre is created for
 * each identifier paired with its name.
 * @param genres The two-element genre payload.
 * @ghidraAddress 0x1f0c04
 */
- (void)addGenres:(nullable NSArray *)genres;

/**
 * @brief The genre model at the given index.
 * @param index The genre index.
 * @return The genre model, or @c nil when @p index is out of range.
 * @ghidraAddress 0x1f0fe8
 */
- (nullable StorePackListGenre *)packListForGenreIndex:(NSUInteger)index;

/**
 * @brief Begin fetching (or extending) the genre at the given index.
 * @param index The genre index to fetch.
 * @ghidraAddress 0x1f10bc
 */
- (void)startFetchForGenreIndex:(NSUInteger)index;

/**
 * @brief Begin fetching (or extending) the given genre's pack list.
 * @param genre The genre to fetch.
 * @ghidraAddress 0x1f1304
 */
- (void)startFetchGenre:(StorePackListGenre *)genre;

/**
 * @brief The cached pack for the given identifier, if any.
 * @param packID The pack identifier.
 * @return The pack, or @c nil when not cached.
 * @ghidraAddress 0x1f13b4
 */
- (nullable StorePackInfo *)getPackInfo:(int)packID;

/**
 * @brief Create and cache a pack for the given identifier when it is not already cached.
 * @param packID The pack identifier.
 * @return The cached pack.
 * @ghidraAddress 0x1f1514
 */
- (nullable StorePackInfo *)addPackInfoFromID:(int)packID;

/**
 * @brief Whether a catalogue-page or StoreKit fetch is currently in flight.
 * @return @c YES while fetching.
 * @ghidraAddress 0x1f094c
 */
- (BOOL)isFetching;

/**
 * @brief Cancel any in-flight catalogue-page and StoreKit fetch.
 * @ghidraAddress 0x1f07fc
 */
- (void)cancelFetching;

/**
 * @brief Request the queued deep-link ("open store") pack's StoreKit product.
 * @ghidraAddress 0x1f2a88
 */
- (void)optionalProductsRequest;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
