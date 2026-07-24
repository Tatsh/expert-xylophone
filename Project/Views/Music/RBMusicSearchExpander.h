/** @file
 * The music-search synonym expander. It maintains a mutable dictionary that maps a search term to
 * the set of extra words the music-select search should also match, persisting it as a JSON file
 * (@c SearchExpandDict.txt) in the application-support directory and seeding it from the bundled
 * copy on first run.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicSearchExpander, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base. Despite the
 * "Expander" name and its home alongside the music-select views, this is a plain @c NSObject
 * dictionary helper, not a @c UIView.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The music-search synonym dictionary helper.
 *
 * The class has no adopted protocols: its class_ro_t baseProtocols list is null. Its single ivar,
 * @c _expandDict, is an ARC-managed strong @c NSMutableDictionary backing the @c expandDict
 * property.
 */
@interface RBMusicSearchExpander : NSObject

/**
 * @brief Copy the bundled synonym dictionary into the application-support directory.
 *
 * Locates the bundled @c SearchExpandDict.txt resource, removes any existing copy in the
 * application-support directory, and copies the bundled file into place. Does nothing when the
 * bundle has no such resource.
 *
 * @ghidraAddress 0x174fe4
 */
+ (void)copyDictionary;

/**
 * @brief Create the expander and load its dictionary.
 *
 * Calls through to @c super then @c loadDictionary to populate @c expandDict.
 *
 * @return The initialised expander.
 * @ghidraAddress 0x174754
 */
- (instancetype)init;

/**
 * @brief An immutable snapshot of the current synonym dictionary.
 *
 * @return A new @c NSDictionary copy of @c expandDict.
 * @ghidraAddress 0x1747c8
 */
- (nullable NSDictionary *)getDictionary;

/**
 * @brief Merge the words for a single search term into the synonym dictionary.
 *
 * Unions @p addWords with any words already stored under @p addSearchInfo, deduplicates the result
 * through an @c NSSet, and stores it back under @p addSearchInfo.
 *
 * @param addSearchInfo The search term key.
 * @param addWords The words to associate with the term.
 * @return @c NO (the binary always returns zero).
 * @ghidraAddress 0x174840
 */
- (BOOL)addSearchInfo:(nullable NSString *)addSearchInfo addWords:(nullable NSDictionary *)addWords;

/**
 * @brief Merge every entry of another dictionary into the synonym dictionary.
 *
 * Iterates the keys of @p addDictionary and merges each entry through
 * @c addSearchInfo:addWords:.
 *
 * @param addDictionary The dictionary whose entries are merged in.
 * @return @c NO (the binary always returns zero).
 * @ghidraAddress 0x174a78
 */
- (BOOL)addDictionary:(nullable NSDictionary *)addDictionary;

/**
 * @brief Load the synonym dictionary from the application-support JSON file.
 *
 * Clears @c expandDict, then, if @c SearchExpandDict.txt exists in the application-support
 * directory, decodes its JSON into a mutable dictionary; otherwise starts with an empty mutable
 * dictionary.
 *
 * @ghidraAddress 0x174c44
 */
- (void)loadDictionary;

/**
 * @brief Persist the synonym dictionary to the application-support JSON file.
 *
 * Serialises @c expandDict to JSON and writes it to @c SearchExpandDict.txt in the
 * application-support directory as UTF-8.
 *
 * @ghidraAddress 0x174e48
 */
- (void)saveDictionary;

/**
 * @brief The synonym dictionary, mapping a search term to its set of extra match words.
 * @ghidraAddress 0x1751b4, 0x1751c4
 */
@property(strong, nullable) NSMutableDictionary *expandDict;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
