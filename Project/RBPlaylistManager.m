//
//  RBPlaylistManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBPlaylistManager). Verified
//  against the arm64 disassembly (the +sharedInstance dispatch_once block, the -initWithFile:
//  fast-enumeration filter, and the -addPlaylistWithName: identifier derivation are partly obscured
//  by the decompiler).
//

#import "RBPlaylistManager.h"

// Collaborator category reached from these methods; its header is committed in this tree.
#import "NSFileManager+RB.h"

#import "neEngineBridge.h"

// The bare filename of the persisted playlist archive under the documents directory.
static NSString *const kPlaylistArchiveFilename = @"playlist";

// The keys of a playlist dictionary within the archive.
static NSString *const kPlaylistKeyIdentifier = @"PLID";
static NSString *const kPlaylistKeyName = @"NAME";
static NSString *const kPlaylistKeyList = @"LIST";

// The date format used to stamp a new playlist's identifier seed.
static NSString *const kPlaylistIdentifierDateFormat = @"yyyy/MM/dd HH:mm:ss z";

// The format that combines a new playlist's name and creation timestamp into the string whose MD5
// hexadecimal digest becomes the playlist identifier.
static NSString *const kPlaylistIdentifierSeedFormat = @"%@(%@)";

// The initial capacity reserved for the in-memory playlist list and each playlist's tune list.
static const NSUInteger kPlaylistListCapacity = 16;
static const NSUInteger kPlaylistTuneListCapacity = 8;

// The number of keys stored in a freshly created playlist dictionary and in a loaded one.
static const NSUInteger kNewPlaylistKeyCount = 3;
static const NSUInteger kLoadedPlaylistKeyCount = 2;

// The sentinel tune identifier that means "no tune". The tune-list mutators reject it before
// touching a playlist's LIST. It is not the tutorial song, which the binary identifies by its
// music name (the string "ZX0"), not by a numeric identifier.
static const NSUInteger kInvalidMusicID = 0;

@implementation RBPlaylistManager

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    /** @ghidraAddress 0x71060 */
    static RBPlaylistManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /** @ghidraAddress 0x710c4 */
        NSString *path = [[NSFileManager documentDirectoryPath]
            stringByAppendingPathComponent:kPlaylistArchiveFilename];
        instance = [[RBPlaylistManager alloc] initWithFile:path];
    });
    return instance;
}

#pragma mark - Lifecycle

- (instancetype)initWithFile:(NSString *)filePath {
    /** @ghidraAddress 0x71190 */
    self = [super init];
    if (self) {
        self.arrayPlaylist = [NSMutableArray arrayWithCapacity:kPlaylistListCapacity];
        self.filePath = [NSString stringWithString:filePath];
        NSArray *loaded = [[NSArray alloc] initWithContentsOfFile:filePath];
        for (id entry in loaded) {
            if (![entry isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSString *identifier = entry[kPlaylistKeyIdentifier];
            NSString *name = entry[kPlaylistKeyName];
            NSArray *list = entry[kPlaylistKeyList];
            if (identifier && name && list) {
                NSMutableDictionary *playlist =
                    [[NSMutableDictionary alloc] initWithCapacity:kLoadedPlaylistKeyCount];
                playlist[kPlaylistKeyIdentifier] = identifier;
                playlist[kPlaylistKeyName] = name;
                playlist[kPlaylistKeyList] = [NSMutableArray arrayWithArray:list];
                [self.arrayPlaylist addObject:playlist];
            }
        }
    }
    return self;
}

#pragma mark - Persistence

- (void)synchronize {
    /** @ghidraAddress 0x71654 */
    [self.arrayPlaylist writeToFile:self.filePath atomically:YES];
}

#pragma mark - Playlists

- (NSUInteger)numberOfPlaylists {
    /** @ghidraAddress 0x716f4 */
    return self.arrayPlaylist.count;
}

- (NSDictionary *)playlistAtIndex:(NSUInteger)index {
    /** @ghidraAddress 0x71754 */
    if (index >= self.arrayPlaylist.count) {
        return nil;
    }
    id playlist = self.arrayPlaylist[index];
    if (![playlist isKindOfClass:[NSDictionary class]] || !playlist[kPlaylistKeyIdentifier] ||
        !playlist[kPlaylistKeyName] || !playlist[kPlaylistKeyList]) {
        return nil;
    }
    return playlist;
}

- (NSUInteger)indexOfPlaylist:(NSDictionary *)playlist {
    /** @ghidraAddress 0x7193c */
    return [self.arrayPlaylist indexOfObjectIdenticalTo:playlist];
}

- (NSUInteger)indexOfPlaylistWithIdentifier:(NSString *)identifier {
    /** @ghidraAddress 0x719d4 */
    if (identifier == nil) {
        return NSNotFound;
    }
    for (NSUInteger index = 0; index < self.arrayPlaylist.count; ++index) {
        NSString *candidate = self.arrayPlaylist[index][kPlaylistKeyIdentifier];
        if (candidate && [candidate isEqualToString:identifier]) {
            return index;
        }
    }
    return NSNotFound;
}

- (NSString *)nameOfPlaylistAtIndex:(NSUInteger)index {
    /** @ghidraAddress 0x71b84 */
    if (index >= self.arrayPlaylist.count) {
        return nil;
    }
    return self.arrayPlaylist[index][kPlaylistKeyName];
}

- (BOOL)setNameOfPlaylist:(NSString *)name atIndex:(NSUInteger)index {
    /** @ghidraAddress 0x71db4 */
    if (name.length == 0) {
        return NO;
    }
    NSMutableDictionary *playlist = self.arrayPlaylist[index];
    if (playlist) {
        playlist[kPlaylistKeyName] = name;
    }
    return YES;
}

- (NSString *)identifierOfPlaylistAtIndex:(NSUInteger)index {
    /** @ghidraAddress 0x71c9c */
    if (index >= self.arrayPlaylist.count) {
        return nil;
    }
    return self.arrayPlaylist[index][kPlaylistKeyIdentifier];
}

- (BOOL)addPlaylistWithName:(NSString *)name {
    /** @ghidraAddress 0x71eac */
    if (name.length == 0) {
        return NO;
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kPlaylistIdentifierDateFormat;
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *seed =
        [NSString stringWithFormat:kPlaylistIdentifierSeedFormat, name, timestamp];
    NSString *identifier = Md5StringToHex(seed.UTF8String);

    NSMutableArray *tuneList = [NSMutableArray arrayWithCapacity:kPlaylistTuneListCapacity];
    NSArray *values = @[identifier, name, tuneList];
    NSArray *keys = @[kPlaylistKeyIdentifier, kPlaylistKeyName, kPlaylistKeyList];
    NSDictionary *playlist = [NSDictionary dictionaryWithObjects:values
                                                         forKeys:keys
                                                           count:kNewPlaylistKeyCount];
    [self.arrayPlaylist addObject:[NSMutableDictionary dictionaryWithDictionary:playlist]];
    return YES;
}

- (BOOL)removePlaylistAtIndex:(NSUInteger)index {
    /** @ghidraAddress 0x721c0 */
    if (index >= self.arrayPlaylist.count) {
        return NO;
    }
    [self.arrayPlaylist removeObjectAtIndex:index];
    return YES;
}

#pragma mark - Playlist contents

- (NSUInteger)numberOfMusicInPlaylistAtIndex:(NSUInteger)index {
    /** @ghidraAddress 0x72288 */
    if (index >= self.arrayPlaylist.count) {
        return 0;
    }
    NSDictionary *playlist = self.arrayPlaylist[index];
    if (playlist == nil) {
        return 0;
    }
    return [playlist[kPlaylistKeyList] count];
}

- (BOOL)containsMusic:(NSUInteger)musicID inPlaylistAtIndex:(NSUInteger)index {
    /** @ghidraAddress 0x723c8 */
    if (musicID == kInvalidMusicID || index >= self.arrayPlaylist.count) {
        return NO;
    }
    NSDictionary *playlist = self.arrayPlaylist[index];
    if (playlist == nil) {
        return NO;
    }
    NSArray *list = playlist[kPlaylistKeyList];
    return [list containsObject:@(musicID)];
}

- (void)addMusic:(NSUInteger)musicID toPlaylistAtIndex:(NSUInteger)index {
    /** @ghidraAddress 0x72560 */
    if (musicID == kInvalidMusicID || index >= self.arrayPlaylist.count) {
        return;
    }
    NSMutableDictionary *playlist = self.arrayPlaylist[index];
    if (playlist == nil) {
        return;
    }
    NSMutableArray *list = playlist[kPlaylistKeyList];
    if (list == nil) {
        list = [NSMutableArray arrayWithCapacity:kPlaylistTuneListCapacity];
        playlist[kPlaylistKeyList] = list;
    }
    NSNumber *tune = @(musicID);
    if (![list containsObject:tune]) {
        [list addObject:tune];
    }
}

- (BOOL)removeMusic:(NSUInteger)musicID fromPlaylistAtIndex:(NSUInteger)index {
    /** @ghidraAddress 0x72748 */
    if (musicID == kInvalidMusicID || index >= self.arrayPlaylist.count) {
        return NO;
    }
    NSMutableDictionary *playlist = self.arrayPlaylist[index];
    if (playlist == nil) {
        return YES;
    }
    NSMutableArray *list = playlist[kPlaylistKeyList];
    NSNumber *tune = @(musicID);
    NSUInteger position = list ? [list indexOfObject:tune] : NSNotFound;
    if (list == nil || position == NSNotFound) {
        return NO;
    }
    [list removeObjectAtIndex:position];
    return YES;
}

@end
