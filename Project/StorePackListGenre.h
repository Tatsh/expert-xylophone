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
 * @brief The number of packs in the genre.
 * @return The pack count.
 */
- (NSInteger)packCount;

/**
 * @brief The genre display name.
 * @return The genre name.
 */
- (nullable NSString *)genreName;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
