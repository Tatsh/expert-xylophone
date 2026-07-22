/** @file
 * The music-catalogue manager singleton. It owns the three lists that together make up the tune
 * catalogue: the fixed set of preinstalled music identifiers, the array of purchased-music
 * dictionaries decoded from the persisted @c mulist file, and a lazily built and cached array of
 * @c MusicData catalogue entries assembled from both. It vends catalogue entries by identifier,
 * resolves the on-disk path of a tune's packaged asset archive, adds and persists purchases, and
 * deletes a purchased tune's files. It also holds the paged "client" (server-supplied) music list
 * used when comparing the local catalogue against a remote one.
 *
 * The purchased-music list is stored enciphered with a per-device Blowfish key: the key string is
 * the device-unique value vended by @c +[AppDelegate musicListKey] (a Keychain generic-password
 * item, or a freshly generated @c CFUUID string persisted to the Keychain on first run), and the
 * Blowfish key itself is the MD5 digest of that string's UTF-8 bytes.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMusicManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class MusicData;
@class StoreMusicInfo;

/**
 * @brief The catalogue-manager singleton.
 */
@interface RBMusicManager : NSObject

#pragma mark Singleton

/**
 * @brief The shared catalogue-manager instance, created on first use.
 * @ghidraAddress 0x6a990
 * @return The shared @c RBMusicManager.
 */
+ (instancetype)getInstance;

#pragma mark Asset paths

/**
 * @brief The bare @c "%09d.rb" archive filename for a tune identifier.
 * @ghidraAddress 0x6a9e8
 * @param musicID The tune identifier.
 * @return The archive filename.
 */
+ (NSString *)getMusicDataFilename:(int)musicID;
/**
 * @brief The bundled archive path for a tune, or @c nil when the bundle holds no such resource.
 * @ghidraAddress 0x6aa1c
 * @param musicID The tune identifier.
 * @return The bundle resource path, or @c nil.
 */
+ (NSString *)getPathFromBundle:(int)musicID;
/**
 * @brief The private Documents path a purchased tune's archive is stored at.
 * @ghidraAddress 0x6aad8
 * @param musicID The tune identifier.
 * @return The archive path under the private Documents directory.
 */
+ (NSString *)getPathFromPurchesed:(int)musicID;
/**
 * @brief The legacy Caches path a purchased tune's archive was previously stored at.
 * @ghidraAddress 0x6ab88
 * @param musicID The tune identifier.
 * @return The archive path under the Caches directory.
 */
+ (NSString *)getPathFromPurchesedOldDirectory:(int)musicID;

#pragma mark Purchased music

/**
 * @brief Load the purchased-music dictionaries from the persisted @c mulist file, allocating an
 *        empty list when the file is absent or unreadable.
 * @ghidraAddress 0x6b020
 */
- (void)loadPurchasedMusics;
/**
 * @brief Encipher and write the purchased-music dictionaries to the @c mulist file.
 * @ghidraAddress 0x6b39c
 */
- (void)savePurchasedMusics;
/**
 * @brief The purchased-music dictionary whose @c ID matches @p musicID, or @c nil.
 * @ghidraAddress 0x6b610
 * @param musicID The tune identifier.
 * @return The matching dictionary, or @c nil.
 */
- (NSDictionary *)getPurchasedMusicDictionary:(int)musicID;
/**
 * @brief The full array of purchased-music dictionaries.
 * @ghidraAddress 0x6b7c4
 * @return The purchased-music dictionary array.
 */
- (NSMutableArray *)getPurchasedMusicDictionaris;
/**
 * @brief Record a purchase described by @p storeMusicInfo, updating an existing entry in place or
 *        appending a new one, and mark the catalogue dirty.
 * @ghidraAddress 0x6b7d0
 * @param storeMusicInfo The purchased tune's store information.
 * @return @c YES when the list changed.
 */
- (BOOL)addPurchasedMusic:(StoreMusicInfo *)storeMusicInfo;
/**
 * @brief Delete a purchased tune's archive from both the current and legacy directories, then mark
 *        the catalogue dirty.
 * @ghidraAddress 0x6ac38
 * @param musicID The tune identifier.
 * @return @c YES when at least one file was removed.
 */
- (BOOL)deleteMusic:(int)musicID;

#pragma mark Catalogue

/**
 * @brief Mark the cached @c MusicData array as stale so the next fetch rebuilds it.
 * @ghidraAddress 0x6c6a8
 */
- (void)setMusicDataArrayDirty;
/**
 * @brief The cached @c MusicData array, rebuilt first when absent or marked dirty.
 * @ghidraAddress 0x6c6b8
 * @return The catalogue-entry array.
 */
- (NSMutableArray *)getMusicDataArray;
/**
 * @brief The catalogue entry whose @c MusicID matches @p musicID, or @c nil.
 * @ghidraAddress 0x6c754
 * @param musicID The tune identifier.
 * @return The matching catalogue entry, or @c nil.
 */
- (MusicData *)getMusicData:(int)musicID;
/**
 * @brief Release the cached artwork of every catalogue entry.
 * @ghidraAddress 0x6c8b4
 */
- (void)releaseChacheMusicData;
/**
 * @brief The identifiers of every preinstalled and purchased tune.
 * @ghidraAddress 0x6c9e4
 * @return An array of @c NSNumber tune identifiers.
 */
- (NSArray *)getMusicIDs;

#pragma mark Client music list

/**
 * @brief Reset the paged client-music list.
 * @ghidraAddress 0x6cc80
 */
- (void)releaseClientMusic;
/**
 * @brief Append a page of client music and decrement the remaining page count.
 * @ghidraAddress 0x6cd2c
 * @param clientMusic The page of client-music entries.
 * @return The number of pages still outstanding.
 */
- (int)setClientMusic:(NSArray *)clientMusic;
/**
 * @brief The local catalogue entries that match the accumulated client-music list, in client order.
 * @ghidraAddress 0x6cdf8
 * @return An array of matching @c MusicData entries.
 */
- (NSMutableArray *)getClientCompareMusics;

#pragma mark Properties

/**
 * @brief The number of client-music pages still outstanding. Setting it resets the accumulated
 *        list and reserves space for the requested pages.
 * @ghidraAddress 0x6d0a8 (getter)
 * @ghidraAddress 0x6cc90 (setter)
 */
@property(nonatomic, assign) int clientMusicPageNum;
/**
 * @brief The accumulated client-music entries across the fetched pages.
 * @ghidraAddress 0x6d0b8 (getter)
 * @ghidraAddress 0x6d0c8 (setter)
 */
@property(nonatomic, strong) NSMutableArray *clientMusics;
/**
 * @brief The preinstalled tune identifiers, as @c NSNumber values.
 * @ghidraAddress 0x6d100 (getter)
 * @ghidraAddress 0x6d110 (setter)
 */
@property(nonatomic, strong) NSMutableArray *preinstallMusicIDs;
/**
 * @brief The purchased-music dictionaries decoded from the @c mulist file.
 * @ghidraAddress 0x6d148 (getter)
 * @ghidraAddress 0x6d158 (setter)
 */
@property(nonatomic, strong) NSMutableArray *purchasedMusicDictionaries;
/**
 * @brief The cached catalogue-entry array.
 * @ghidraAddress 0x6d190 (getter)
 * @ghidraAddress 0x6d1a0 (setter)
 */
@property(nonatomic, strong) NSMutableArray *musicDataArray;
/**
 * @brief Whether the cached catalogue-entry array is stale and must be rebuilt.
 * @ghidraAddress 0x6d1d8 (getter)
 * @ghidraAddress 0x6d1e8 (setter)
 */
@property(nonatomic, assign) BOOL musicDataArrayDirtyFlag;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
