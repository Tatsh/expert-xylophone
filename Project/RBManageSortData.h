/** @file
 * A lightweight per-tune sort record for the store manage screens. Each instance holds the yomigana
 * readings used to collate a tune by artist and by title, the tune's pack name, its identifier, and
 * the raw catalogue dictionary it was built from. Instances are created while
 * @c -[RBStoreManageViewController sortList:] partitions the purchased-tune list into the alphabet
 * sections of the current @c UILocalizedIndexedCollation, with @c a_yomi and @c m_yomi serving as
 * the collation-string selectors.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBManageSortData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A per-tune sort record carrying the collation readings and source data for a single tune on
 * the store manage screens.
 */
@interface RBManageSortData : NSObject

/**
 * @brief The artist-name yomigana reading, used as the collation string when sorting by artist.
 * @ghidraAddress 0x1cd5c4 (getter)
 * @ghidraAddress 0x1cd5d4 (setter)
 */
@property(nonatomic, strong, nullable) NSString *a_yomi;
/**
 * @brief The tune-title yomigana reading, used as the collation string when sorting by title.
 * @ghidraAddress 0x1cd60c (getter)
 * @ghidraAddress 0x1cd61c (setter)
 */
@property(nonatomic, strong, nullable) NSString *m_yomi;
/**
 * @brief The name of the pack the tune belongs to.
 * @ghidraAddress 0x1cd654 (getter)
 * @ghidraAddress 0x1cd664 (setter)
 */
@property(nonatomic, strong, nullable) NSString *pack_name;
/**
 * @brief The tune identifier.
 * @ghidraAddress 0x1cd69c (getter)
 * @ghidraAddress 0x1cd6ac (setter)
 */
@property(nonatomic, assign) NSUInteger musicId;
/**
 * @brief The raw catalogue dictionary the tune's sort record was built from.
 * @ghidraAddress 0x1cd6bc (getter)
 * @ghidraAddress 0x1cd6cc (setter)
 */
@property(nonatomic, strong, nullable) NSDictionary *dict;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
