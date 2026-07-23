/** @file
 * A store genre model describing one pack-list genre: its display name and the pack identifiers it
 * contains. This is a minimal stub declaring only the surface @c RBStorePageViewController relies
 * on; the full model class is reconstructed separately.
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
 * @brief The pack identifiers in the genre.
 */
@property(nonatomic, strong, nullable) NSArray<NSNumber *> *packIDList;

/**
 * @brief Build a genre with the given display name and identifier.
 * @param name The genre display name.
 * @param genreID The genre identifier.
 * @return The initialised genre.
 */
- (instancetype)initWithName:(nullable NSString *)name genreID:(NSUInteger)genreID;

/**
 * @brief The number of packs in the genre.
 * @return The pack count.
 */
- (NSInteger)packCount;

/**
 * @brief The genre display name.
 * @return The genre name.
 */
- (nullable NSString *)genreName;

/**
 * @brief The genre identifier.
 * @return The genre identifier.
 */
- (unsigned int)genreID;

/**
 * @brief The number of packs already fetched for this genre, used as the next page offset.
 * @return The fetched-pack count.
 */
- (int)numFetchedPack;

/**
 * @brief Append a fetched page of pack identifiers to the genre.
 * @param list The pack-identifier numbers from the page.
 * @param step The page size requested.
 * @param hasNext Whether the server reports a further page.
 */
- (void)updateList:(nullable NSArray<NSNumber *> *)list step:(int)step hasNext:(BOOL)hasNext;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
