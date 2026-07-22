/** @file
 * One unlock package within the unlock catalogue: an identifier, a display order, a title, and the
 * list of item entries it grants. Parsed from a catalogue dictionary by @c RBUnlockData.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBUnlockPackageData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class RBUnlockPackageItemData;

/**
 * @brief An unlock package: its metadata and the item entries it contains.
 */
@interface RBUnlockPackageData : NSObject

/**
 * @brief The package identifier.
 * @ghidraAddress 0x19a980 (getter)
 * @ghidraAddress 0x19a990 (setter)
 */
@property(nonatomic, assign) int identity;
/**
 * @brief The package's display order within the catalogue.
 * @ghidraAddress 0x19a9a0 (getter)
 * @ghidraAddress 0x19a9b0 (setter)
 */
@property(nonatomic, assign) int order;
/**
 * @brief The package title.
 * @ghidraAddress 0x19a9c0 (getter)
 * @ghidraAddress 0x19a9d0 (setter)
 */
@property(nonatomic, strong) NSString *title;
/**
 * @brief The package's item entries, ordered by descending point value.
 * @ghidraAddress 0x19a9dc (getter)
 * @ghidraAddress 0x19a9ec (setter)
 */
@property(nonatomic, strong) NSArray<RBUnlockPackageItemData *> *data;

/**
 * @brief Populate the package from a catalogue dictionary (@c ID, @c Order, @c Title, and @c Data
 * entries).
 * @param dictionary The package dictionary to read.
 * @ghidraAddress 0x19a548
 */
- (void)parseDictionary:(NSDictionary *)dictionary;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
