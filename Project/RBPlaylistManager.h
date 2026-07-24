/** @file
 * The user-playlist manager singleton. It owns an ordered list of user-created playlists, each a
 * mutable dictionary of a stable identifier (@c PLID), a display name (@c NAME), and a list of the
 * tune identifiers it contains (@c LIST). It vends and mutates playlists and their tune lists by
 * index, and persists the whole list as a property list at @c Documents/playlist.
 *
 * The list is loaded on first access: @c +sharedInstance runs @c -initWithFile: once, reading the
 * archive from the app documents directory. Mutations are held in memory until @c -synchronize
 * writes the list back to the same file. A new playlist's identifier is the MD5 hexadecimal digest
 * of a @c "name(timestamp)" string, so it stays stable across renames while remaining unique per
 * creation.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBPlaylistManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The user-playlist manager singleton.
 */
@interface RBPlaylistManager : NSObject

#pragma mark Singleton

/**
 * @brief The shared playlist-manager instance, loaded from the @c Documents/playlist archive on
 *        first use.
 * @ghidraAddress 0x71060
 * @return The shared @c RBPlaylistManager.
 */
+ (instancetype)sharedInstance;

#pragma mark Lifecycle

/**
 * @brief Initialise the manager by reading the persisted playlist archive at @p filePath, keeping
 *        only the entries that carry a @c PLID, a @c NAME, and a @c LIST.
 * @ghidraAddress 0x71190
 * @param filePath The property-list path the playlists are read from and later written back to.
 * @return The initialised manager.
 */
- (instancetype)initWithFile:(NSString *)filePath;

#pragma mark Persistence

/**
 * @brief Write the in-memory playlist list back to the archive file as a property list.
 * @ghidraAddress 0x71654
 */
- (void)synchronize;

#pragma mark Playlists

/**
 * @brief The number of playlists.
 * @ghidraAddress 0x716f4
 * @return The playlist count.
 */
- (NSUInteger)numberOfPlaylists;
/**
 * @brief The playlist dictionary at @p index, or @c nil when the index is out of range or the entry
 *        is malformed (missing a @c PLID, @c NAME, or @c LIST).
 * @ghidraAddress 0x71754
 * @param index The playlist index.
 * @return The playlist dictionary, or @c nil.
 */
- (nullable NSDictionary *)playlistAtIndex:(NSUInteger)index;
/**
 * @brief The index of @p playlist by identity, or @c NSNotFound.
 * @ghidraAddress 0x7193c
 * @param playlist The playlist dictionary to locate.
 * @return The playlist index, or @c NSNotFound.
 */
- (NSUInteger)indexOfPlaylist:(NSDictionary *)playlist;
/**
 * @brief The index of the playlist whose @c PLID equals @p identifier, or @c NSNotFound.
 * @ghidraAddress 0x719d4
 * @param identifier The playlist identifier to match, or @c nil.
 * @return The playlist index, or @c NSNotFound.
 */
- (NSUInteger)indexOfPlaylistWithIdentifier:(nullable NSString *)identifier;
/**
 * @brief The display name of the playlist at @p index, or @c nil when out of range.
 * @ghidraAddress 0x71b84
 * @param index The playlist index.
 * @return The playlist name, or @c nil.
 */
- (nullable NSString *)nameOfPlaylistAtIndex:(NSUInteger)index;
/**
 * @brief Rename the playlist at @p index. A rename with an empty name is ignored.
 * @ghidraAddress 0x71db4
 * @param name The new playlist name.
 * @param index The playlist index.
 * @return @c YES when the name was non-empty (and therefore applied when the index was valid).
 */
- (BOOL)setNameOfPlaylist:(NSString *)name atIndex:(NSUInteger)index;
/**
 * @brief The identifier (@c PLID) of the playlist at @p index, or @c nil when out of range.
 * @ghidraAddress 0x71c9c
 * @param index The playlist index.
 * @return The playlist identifier, or @c nil.
 */
- (nullable NSString *)identifierOfPlaylistAtIndex:(NSUInteger)index;
/**
 * @brief Append a new, empty playlist with the given name and an identifier derived from the name
 *        and the current timestamp. A creation with an empty name is ignored.
 * @ghidraAddress 0x71eac
 * @param name The new playlist's display name.
 * @return @c YES when the name was non-empty and the playlist was appended.
 */
- (BOOL)addPlaylistWithName:(NSString *)name;
/**
 * @brief Remove the playlist at @p index.
 * @ghidraAddress 0x721c0
 * @param index The playlist index.
 * @return @c YES when the index was in range.
 */
- (BOOL)removePlaylistAtIndex:(NSUInteger)index;

#pragma mark Playlist contents

/**
 * @brief The number of tunes in the playlist at @p index, or @c 0 when out of range.
 * @ghidraAddress 0x72288
 * @param index The playlist index.
 * @return The tune count.
 */
- (NSUInteger)numberOfMusicInPlaylistAtIndex:(NSUInteger)index;
/**
 * @brief Whether the playlist at @p index contains the tune @p musicID.
 * @ghidraAddress 0x723c8
 * @param musicID The tune identifier.
 * @param index The playlist index.
 * @return @c YES when the tune is present.
 */
- (BOOL)containsMusic:(NSUInteger)musicID inPlaylistAtIndex:(NSUInteger)index;
/**
 * @brief Add the tune @p musicID to the playlist at @p index, allocating the tune list when absent
 *        and skipping tunes already present.
 * @ghidraAddress 0x72560
 * @param musicID The tune identifier.
 * @param index The playlist index.
 */
- (void)addMusic:(NSUInteger)musicID toPlaylistAtIndex:(NSUInteger)index;
/**
 * @brief Remove the tune @p musicID from the playlist at @p index.
 * @ghidraAddress 0x72748
 * @param musicID The tune identifier.
 * @param index The playlist index.
 * @return @c YES when the index was in range (whether or not the tune was present).
 */
- (BOOL)removeMusic:(NSUInteger)musicID fromPlaylistAtIndex:(NSUInteger)index;

#pragma mark Properties

/**
 * @brief The ordered list of playlist dictionaries.
 * @ghidraAddress 0x7291c (getter)
 * @ghidraAddress 0x7292c (setter)
 */
@property(nonatomic, strong) NSMutableArray *arrayPlaylist;
/**
 * @brief The property-list path the playlists are persisted to.
 * @ghidraAddress 0x72964 (getter)
 * @ghidraAddress 0x72974 (setter)
 */
@property(nonatomic, copy) NSString *filePath;
/**
 * @brief The identifier of the tune last selected within a playlist.
 * @ghidraAddress 0x72980 (getter)
 * @ghidraAddress 0x72990 (setter)
 */
@property(nonatomic, assign) unsigned int lastSelectedMusicID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
