/** @file
 * The extend-note catalogue manager singleton. Extend notes are the purchasable special (@c SP)
 * charts that augment an existing tune: each is delivered as its own packaged archive and described
 * by a purchased-extend-note dictionary. This manager owns the array of those dictionaries decoded
 * from the persisted @c nolist file, lazily builds and caches an array of @c MusicDataExtend
 * catalogue entries from them, and vends those entries by their own extend identifier or by the base
 * tune identifier they augment. It records and persists purchases, deletes a purchased extend note's
 * files, and holds the paged "client" (server-supplied) extend-note list used when comparing the
 * local catalogue against a remote one.
 *
 * The purchased-extend-note list is stored enciphered with the same per-device Blowfish key as the
 * purchased-music list: the key string is the device-unique value vended by
 * @c +[AppDelegate musicListKey], and the Blowfish key itself is the MD5 digest of that string's
 * UTF-8 bytes.
 *
 * @c MusicData depends on this manager: when a tune is assembled it asks
 * @c -getExtendNoteDataWithMusicID: for any matching extend packs and, if one is present, adopts it
 * as the tune's special chart.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBExtendNoteManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class MusicDataExtend;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The extend-note catalogue-manager singleton.
 */
@interface RBExtendNoteManager : NSObject

#pragma mark Singleton

/**
 * @brief The shared extend-note-manager instance, created and note-loaded on first use.
 * @ghidraAddress 0x181aac
 * @return The shared @c RBExtendNoteManager.
 */
+ (instancetype)getInstance;

#pragma mark Asset paths

/**
 * @brief The bare @c "%09d.rb" archive filename for an extend-note identifier.
 * @ghidraAddress 0x181b14
 * @param extendNoteID The extend-note identifier.
 * @return The archive filename.
 */
+ (NSString *)getExtendNoteDataFilename:(int)extendNoteID;
/**
 * @brief The private Documents path a purchased extend note's archive is stored at.
 * @ghidraAddress 0x181c04
 * @param extendNoteID The extend-note identifier.
 * @return The archive path under the private Documents directory.
 */
+ (NSString *)getPathFromPurchased:(int)extendNoteID;
/**
 * @brief The legacy Caches path a purchased extend note's archive was previously stored at.
 * @ghidraAddress 0x181cb4
 * @param extendNoteID The extend-note identifier.
 * @return The archive path under the Caches directory.
 */
+ (NSString *)getPathFromPurchasedOldDirectory:(int)extendNoteID;

#pragma mark Purchased extend notes

/**
 * @brief Load the purchased-extend-note dictionaries from the persisted @c nolist file, allocating
 *        an empty list when the file is absent or unreadable.
 * @ghidraAddress 0x181fcc
 */
- (void)loadPurchasedNotes;
/**
 * @brief Encipher and write the purchased-extend-note dictionaries to the @c nolist file.
 * @ghidraAddress 0x182348
 */
- (void)savePurchasedNotes;
/**
 * @brief The purchased-extend-note dictionary whose @c ExtID matches @p extendNoteID, or @c nil.
 * @ghidraAddress 0x1825bc
 * @param extendNoteID The extend-note identifier.
 * @return The matching dictionary, or @c nil.
 */
- (nullable NSDictionary *)getPurchasedExtendNoteDictionary:(int)extendNoteID;
/**
 * @brief The purchased-extend-note dictionaries whose base @c ID matches @p musicID.
 * @ghidraAddress 0x182770
 * @param musicID The base tune identifier.
 * @return An array of matching dictionaries.
 */
- (NSMutableArray *)getPurchasedExtendNoteDictionaryWithMusicID:(unsigned int)musicID;
/**
 * @brief The full array of purchased-extend-note dictionaries.
 * @ghidraAddress 0x182960
 * @return The purchased-extend-note dictionary array.
 */
- (nullable NSMutableArray *)getPurchasedExtendNoteDictionaries;
/**
 * @brief Record a purchase described by @p extendNoteInfo, updating an existing entry in place or
 *        appending a new one, and mark the catalogue dirty.
 * @ghidraAddress 0x18296c
 * @param extendNoteInfo The purchased extend note's store information.
 * @return @c YES when the list changed.
 */
- (BOOL)addPurchasedExtendNote:(id)extendNoteInfo;
/**
 * @brief Delete a purchased extend note's archive from both the current and legacy directories,
 *        then mark the catalogue dirty.
 * @ghidraAddress 0x181d64
 * @param extendNoteID The extend-note identifier.
 * @return @c YES when at least one file was removed.
 */
- (BOOL)deleteExtendNote:(int)extendNoteID;

#pragma mark Catalogue

/**
 * @brief Mark the cached extend-note data array as stale so the next fetch rebuilds it.
 * @ghidraAddress 0x1837e8
 */
- (void)setExtendNoteDataArrayDirty;
/**
 * @brief The cached extend-note data array, rebuilt first when absent or marked dirty.
 * @ghidraAddress 0x1837f8
 * @return The extend-note catalogue-entry array.
 */
- (NSMutableArray *)getExtendNoteDataArray;
/**
 * @brief The catalogue entry whose extend @c ExtMusicID matches @p extendNoteID, or @c nil.
 * @ghidraAddress 0x183894
 * @param extendNoteID The extend-note identifier.
 * @return The matching catalogue entry, or @c nil.
 */
- (nullable MusicDataExtend *)getExtendNoteData:(int)extendNoteID;
/**
 * @brief The extend-note identifiers of every purchased extend note.
 * @ghidraAddress 0x183b24
 * @return An array of @c NSNumber extend-note identifiers.
 */
- (NSMutableArray *)getExtendNoteIDs;
/**
 * @brief The extend-note identifiers of every purchased extend note augmenting @p musicID.
 * @ghidraAddress 0x183cf0
 * @param musicID The base tune identifier.
 * @return An array of @c NSNumber extend-note identifiers.
 */
- (NSMutableArray *)getExtendNoteIDsWithMusicID:(unsigned int)musicID;
/**
 * @brief The catalogue entries augmenting the base tune @p musicID.
 * @ghidraAddress 0x183f14
 * @param musicID The base tune identifier.
 * @return An array of matching @c MusicDataExtend entries.
 */
- (NSMutableArray<MusicDataExtend *> *)getExtendNoteDataWithMusicID:(int)musicID;

#pragma mark Client extend-note list

/**
 * @brief Reset the paged client extend-note list.
 * @ghidraAddress 0x1840c0
 */
- (void)releaseClientMusic;
/**
 * @brief Reset the accumulated client extend-note list and reserve space for @p pageNum pages.
 * @ghidraAddress 0x1840d0
 * @param pageNum The number of client extend-note pages to expect.
 */
- (void)setClientMusicPageNum:(int)pageNum;
/**
 * @brief Append a page of client extend notes and decrement the remaining page count.
 * @ghidraAddress 0x18416c
 * @param clientMusic The page of client extend-note entries.
 * @return The number of pages still outstanding.
 */
- (int)setClientMusic:(NSArray *)clientMusic;
/**
 * @brief The local catalogue entries that match the accumulated client extend-note list, in client
 *        order.
 * @ghidraAddress 0x184238
 * @return An array of matching @c MusicDataExtend entries.
 */
- (NSMutableArray *)getClientCompareExtendNotes;

#pragma mark Properties

/**
 * @brief The purchased-extend-note dictionaries decoded from the @c nolist file.
 * @ghidraAddress 0x184550 (getter)
 * @ghidraAddress 0x184560 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *purchasedExtendNoteDictionaries;
/**
 * @brief The cached catalogue-entry array.
 * @ghidraAddress 0x184598 (getter)
 * @ghidraAddress 0x1845a8 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *extendNoteDataArray;
/**
 * @brief Whether the cached catalogue-entry array is stale and must be rebuilt.
 * @ghidraAddress 0x184628 (getter)
 * @ghidraAddress 0x184638 (setter)
 */
@property(nonatomic, assign) BOOL extendNoteDataArrayDirtyFlag;
/**
 * @brief An auxiliary base-tune lookup dictionary. It is declared and accessible but unused by the
 *        manager's own methods.
 * @ghidraAddress 0x1845e0 (getter)
 * @ghidraAddress 0x1845f0 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *extendNoteMusicDictionary;
/**
 * @brief The number of client extend-note pages still outstanding.
 * @ghidraAddress 0x1844e8 (getter)
 * @ghidraAddress 0x1844f8 (setter)
 */
@property(nonatomic, assign) int clientExtendNotePageNum;
/**
 * @brief The accumulated client extend-note entries across the fetched pages.
 * @ghidraAddress 0x184508 (getter)
 * @ghidraAddress 0x184518 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *clientExtendNotes;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
