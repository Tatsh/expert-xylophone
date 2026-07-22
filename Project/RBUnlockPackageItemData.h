/** @file
 * A single item entry within an unlock package: its type, identifier, display name, asset path, and
 * point cost. Parsed from an entry dictionary in the unlock catalogue and sorted by point value by
 * @c RBUnlockPackageData.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBUnlockPackageItemData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One unlock item entry: its metadata and point cost.
 */
@interface RBUnlockPackageItemData : NSObject

/**
 * @brief The item type.
 * @ghidraAddress 0x19a330 (getter)
 * @ghidraAddress 0x19a340 (setter)
 */
@property(nonatomic, assign) int type;
/**
 * @brief The item identifier.
 * @ghidraAddress 0x19a350 (getter)
 * @ghidraAddress 0x19a360 (setter)
 */
@property(nonatomic, assign) int identity;
/**
 * @brief The item display name.
 * @ghidraAddress 0x19a370 (getter)
 * @ghidraAddress 0x19a380 (setter)
 */
@property(nonatomic, copy, nullable) NSString *name;
/**
 * @brief The item asset path.
 * @ghidraAddress 0x19a38c (getter)
 * @ghidraAddress 0x19a39c (setter)
 */
@property(nonatomic, copy, nullable) NSString *path;
/**
 * @brief The item's point cost; packages sort their items by descending point value.
 * @ghidraAddress 0x19a3a8 (getter)
 * @ghidraAddress 0x19a3b8 (setter)
 */
@property(nonatomic, assign) int point;

/**
 * @brief Populate the item from an entry dictionary (@c ID, @c Name, @c Path, @c Point, and @c Type
 * entries).
 * @param dictionary The item dictionary to read.
 * @ghidraAddress 0x19a168
 */
- (void)parseDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
