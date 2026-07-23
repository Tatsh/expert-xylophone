/** @file
 * The store pack-list model that fetches, paginates, and caches purchasable packs by genre. This is
 * a minimal stub declaring only the surface @c RBStorePageViewController relies on; the full model
 * class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStorePackList, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

#import "StorePackListDelegate.h"

@class StorePackInfo;
@class StorePackListGenre;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store pack-list model.
 */
@interface RBStorePackList : NSObject

/**
 * @brief The delegate notified of load results.
 */
@property(nonatomic, weak, nullable) id<StorePackListDelegate> delegate;

/**
 * @brief Whether the current genre's pack list can be extended with another page.
 */
@property(nonatomic, assign) BOOL packlistContinued;

/**
 * @brief The promotion banner image URLs for the current genre.
 */
@property(nonatomic, strong, nullable) NSArray<NSString *> *promotionList;

/**
 * @brief The number of available genres.
 */
@property(nonatomic, assign) NSUInteger numGenres;

/**
 * @brief Whether a fetch is currently in flight.
 * @return @c YES while fetching.
 */
- (BOOL)isFetching;

/**
 * @brief The genre model at the given index.
 * @param index The genre index.
 * @return The genre model.
 */
- (nullable StorePackListGenre *)packListForGenreIndex:(NSUInteger)index;

/**
 * @brief Begin fetching (or extending) the given genre's pack list.
 * @param genre The genre to fetch.
 */
- (void)startFetchGenre:(StorePackListGenre *)genre;

/**
 * @brief Cancel any in-flight fetch.
 */
- (void)cancelFetching;

/**
 * @brief The cached pack for the given identifier, if any.
 * @param packID The pack identifier.
 * @return The pack, or @c nil when not cached.
 */
- (nullable StorePackInfo *)getPackInfo:(int)packID;

/**
 * @brief Create and cache a pack for the given identifier.
 * @param packID The pack identifier.
 * @return The newly cached pack.
 */
- (nullable StorePackInfo *)addPackInfoFromID:(int)packID;

/**
 * @brief Request the optional (queued-open) product's detail.
 */
- (void)optionalProductsRequest;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
