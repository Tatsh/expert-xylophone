/** @file
 * A store genre model describing one pack-list genre: its display name, identifier, and the pack
 * identifiers it accumulates as catalogue pages are fetched. Used by the pack store's genre list
 * (@c RBStoreGenreViewController) and the store page (@c RBStorePageViewController), and populated
 * by @c RBStorePackList.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackListGenre, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A store model for a single pack-list genre.
 */
@interface StorePackListGenre : NSObject

/**
 * @brief The accumulated pack identifiers for this genre.
 *
 * Despite the name, the backing array holds the boxed pack identifiers (@c NSNumber values), not
 * pack-info objects.
 */
@property(nonatomic, strong) NSMutableArray<NSNumber *> *arrayPackInfo;

/**
 * @brief The genre display name.
 */
@property(nonatomic, readonly, nullable) NSString *genreName;

/**
 * @brief The genre identifier.
 */
@property(nonatomic, readonly) NSUInteger genreID;

/**
 * @brief Whether the server reported a further catalogue page for this genre.
 */
@property(nonatomic, readonly) BOOL packlistContinued;

/**
 * @brief The number of packs already fetched for this genre, used as the next page offset.
 */
@property(nonatomic, readonly) NSUInteger numFetchedPack;

/**
 * @brief Build a genre with the given display name and identifier.
 * @param name The genre display name.
 * @param genreID The genre identifier.
 * @return The initialised genre.
 * @ghidraAddress 0x33f00
 */
- (instancetype)initWithName:(nullable NSString *)name genreID:(NSUInteger)genreID;

/**
 * @brief The number of packs accumulated for this genre.
 * @return The pack count.
 * @ghidraAddress 0x3403c
 */
- (NSUInteger)packCount;

/**
 * @brief The boxed pack identifier at the given index, or @c nil when out of range.
 * @param index The pack index.
 * @return The boxed pack identifier, or @c nil.
 * @ghidraAddress 0x3409c
 */
- (nullable NSNumber *)packInfoForIndex:(NSUInteger)index;

/**
 * @brief The accumulated pack identifiers for this genre.
 * @return The boxed pack identifiers.
 * @ghidraAddress 0x34170
 */
- (NSArray<NSNumber *> *)packIDList;

/**
 * @brief Append a fetched page of pack identifiers to the genre.
 * @param list The pack-identifier numbers from the page.
 * @param step The page size requested.
 * @param hasNext Whether the server reports a further page.
 * @ghidraAddress 0x3417c
 */
- (void)updateList:(nullable NSArray<NSNumber *> *)list step:(NSUInteger)step hasNext:(BOOL)hasNext;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
