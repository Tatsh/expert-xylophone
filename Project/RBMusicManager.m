//
//  RBMusicManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMusicManager). Verified against
//  the arm64 disassembly (the fast-enumeration loops, the Blowfish key derivation, and the
//  property-list salt-and-encipher round-trip are partly obscured by the decompiler).
//

#import "RBMusicManager.h"

#import <CoreFoundation/CoreFoundation.h>

// Collaborator classes reached from these methods. Their headers are not all reconstructed in this
// tree yet (the same speculative-import style AppDelegate.mm and ScoreData.m already use); they
// resolve once those classes land. MusicData is committed.
#import "AppDelegate.h"
#import "BFCodec.h"
#import "MusicData.h"
#import "NSData+RB.h"
#import "NSFileManager+RB.h"
#import "StoreMusicInfo.h"

// Plain-C engine helpers shared with the persistence and asset layers. These live in the C++
// engine bridge, which is not C-safe, so the prototypes are declared locally rather than by
// importing it.
// @ghidraAddress 0x1a1624 (GetApplicationSupportPath)
// @ghidraAddress 0x1a1224 (GetPrivateDocumentsPath)
// @ghidraAddress 0x1a1218 (GetCachesDirectoryPath)
// @ghidraAddress 0x17534 (Md5StringToData)
NSString *GetApplicationSupportPath(void);
NSString *GetPrivateDocumentsPath(void);
NSString *GetCachesDirectoryPath(void);
NSData *Md5StringToData(const char *pString);

/// The archive filename format: a nine-digit zero-padded tune identifier with a @c .rb extension.
/// @ghidraAddress 0x337a27 (the format-string literal)
static NSString *const kMusicDataFilenameFormat = @"%09d.rb";

/// The archive resource type passed to @c -[NSBundle pathForResource:ofType:] (already carried by
/// the filename, so the type is empty).
static NSString *const kEmptyResourceType = @"";

/// The empty replacement stored for a missing name or artist string in a purchase dictionary.
static NSString *const kEmptyString = @"";

/// The filename of the enciphered purchased-music list under the Application Support directory.
static NSString *const kPurchasedMusicListFilename = @"mulist";

/// The keys of a purchased-music dictionary within the persisted list.
static NSString *const kPurchasedMusicKeyID = @"ID";
static NSString *const kPurchasedMusicKeyName = @"Name";
static NSString *const kPurchasedMusicKeyArtist = @"Artist";
static NSString *const kPurchasedMusicKeyItemURL = @"ItemURL";
static NSString *const kPurchasedMusicKeyITunesURL = @"iTunesURL";

/// The three preinstalled tune identifiers seeded on construction.
/// @ghidraAddress 0x2fcfe0 (g_nPreinstallMusicIDs)
static const int kPreinstallMusicIDs[] = {99999595, 99999597, 99999907};
static const NSUInteger kPreinstallMusicIDCount =
    sizeof(kPreinstallMusicIDs) / sizeof(kPreinstallMusicIDs[0]);

/// The initial capacity reserved for the purchased-music and identifier lists.
static const NSUInteger kPurchasedMusicListCapacity = 64;
static const NSUInteger kMusicIDsCapacity = 3;

/// The initial capacity reserved for the enciphered-list scratch buffer and a fresh purchase
/// dictionary.
static const NSUInteger kEncipherBufferCapacity = 128;
static const NSUInteger kPurchaseDictionaryCapacity = 5;

/// The number of leading salt bytes prepended to the plaintext before enciphering; the same count
/// is stripped after deciphering.
static const NSUInteger kListSaltLength = 4;

/// The number of client-music entries reserved per outstanding page.
static const int kClientMusicEntriesPerPage = 20;

@implementation RBMusicManager

// The page count keeps its own backing ivar because the setter is overridden to reset the
// accumulated client-music list.
@synthesize clientMusicPageNum = _clientMusicPageNum;

#pragma mark - Singleton

+ (instancetype)getInstance {
    /** @ghidraAddress 0x6a990 */
    static RBMusicManager *instance = nil;
    if (instance == nil) {
        instance = [[RBMusicManager alloc] init];
    }
    return instance;
}

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x6ae38 */
    self = [super init];
    if (self) {
        [self createPreInMusics];
    }
    return self;
}

- (void)createPreInMusics {
    /** @ghidraAddress 0x6aee0 */
    NSMutableArray *ids = [[NSMutableArray alloc] initWithCapacity:kPreinstallMusicIDCount];
    for (NSUInteger i = 0; i < kPreinstallMusicIDCount; ++i) {
        [ids addObject:[NSNumber numberWithInt:kPreinstallMusicIDs[i]]];
    }
    self.preinstallMusicIDs = [[NSMutableArray alloc] initWithArray:ids];
}

#pragma mark - Asset paths

+ (NSString *)getMusicDataFilename:(int)musicID {
    /** @ghidraAddress 0x6a9e8 */
    return [NSString stringWithFormat:kMusicDataFilenameFormat, musicID];
}

+ (NSString *)getPathFromBundle:(int)musicID {
    /** @ghidraAddress 0x6aa1c */
    NSString *filename = [RBMusicManager getMusicDataFilename:musicID];
    return [NSBundle.mainBundle pathForResource:filename ofType:kEmptyResourceType];
}

+ (NSString *)getPathFromPurchesed:(int)musicID {
    /** @ghidraAddress 0x6aad8 */
    NSString *filename = [RBMusicManager getMusicDataFilename:musicID];
    return [GetPrivateDocumentsPath() stringByAppendingPathComponent:filename];
}

+ (NSString *)getPathFromPurchesedOldDirectory:(int)musicID {
    /** @ghidraAddress 0x6ab88 */
    NSString *filename = [RBMusicManager getMusicDataFilename:musicID];
    return [GetCachesDirectoryPath() stringByAppendingPathComponent:filename];
}

- (BOOL)deleteMusic:(int)musicID {
    /** @ghidraAddress 0x6ac38 */
    NSString *currentPath = [RBMusicManager getPathFromPurchesed:musicID];
    BOOL removedCurrent = NO;
    if ([NSFileManager isFileExist:currentPath]) {
        NSError *error = nil;
        [NSFileManager.defaultManager removeItemAtPath:currentPath error:&error];
        removedCurrent = YES;
    }
    NSString *legacyPath = [RBMusicManager getPathFromPurchesedOldDirectory:musicID];
    if ([NSFileManager isFileExist:legacyPath]) {
        NSError *error = nil;
        [NSFileManager.defaultManager removeItemAtPath:legacyPath error:&error];
    } else if (!removedCurrent) {
        return NO;
    }
    [self setMusicDataArrayDirty];
    return YES;
}

#pragma mark - Purchased music

- (void)loadPurchasedMusics {
    /** @ghidraAddress 0x6b020 */
    NSString *listPath =
        [GetApplicationSupportPath() stringByAppendingPathComponent:kPurchasedMusicListFilename];
    if ([NSFileManager isFileExist:listPath]) {
        NSString *key = [AppDelegate musicListKey];
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:listPath];
        if (data) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:Md5StringToData(key.UTF8String)];
            [codec decipher:data];
            NSData *payload = [data subdataWithRange:NSMakeRange(kListSaltLength,
                                                                 data.length - kListSaltLength)];
            self.purchasedMusicDictionaries = [payload mutableArray];
            [self setMusicDataArrayDirty];
        }
    }
    if (self.purchasedMusicDictionaries == nil) {
        self.purchasedMusicDictionaries =
            [[NSMutableArray alloc] initWithCapacity:kPurchasedMusicListCapacity];
        [self setMusicDataArrayDirty];
    }
}

- (void)savePurchasedMusics {
    /** @ghidraAddress 0x6b39c */
    if (self.purchasedMusicDictionaries.count == 0) {
        return;
    }
    NSString *listPath =
        [GetApplicationSupportPath() stringByAppendingPathComponent:kPurchasedMusicListFilename];
    NSString *key = [AppDelegate musicListKey];
    CFDataRef plistData = CFPropertyListCreateXMLData(
        kCFAllocatorDefault, (__bridge CFPropertyListRef)self.purchasedMusicDictionaries);
    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:kEncipherBufferCapacity];
    uint32_t salt = arc4random();
    [buffer appendBytes:&salt length:sizeof(salt)];
    [buffer appendData:(__bridge NSData *)plistData];
    CFRelease(plistData);
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:Md5StringToData(key.UTF8String)];
    [codec encipher:buffer];
    [buffer writeToFile:listPath atomically:YES];
}

- (NSDictionary *)getPurchasedMusicDictionary:(int)musicID {
    /** @ghidraAddress 0x6b610 */
    for (NSDictionary *entry in self.purchasedMusicDictionaries) {
        if ([entry[kPurchasedMusicKeyID] unsignedIntValue] == (unsigned int)musicID) {
            return entry;
        }
    }
    return nil;
}

- (NSMutableArray *)getPurchasedMusicDictionaris {
    /** @ghidraAddress 0x6b7c4 */
    return self.purchasedMusicDictionaries;
}

- (BOOL)addPurchasedMusic:(StoreMusicInfo *)storeMusicInfo {
    /** @ghidraAddress 0x6b7d0 */
    unsigned int musicID = [storeMusicInfo.musicID unsignedIntValue];
    NSUInteger index = 0;
    while (index < self.purchasedMusicDictionaries.count) {
        NSDictionary *existing = self.purchasedMusicDictionaries[index];
        if ([existing[kPurchasedMusicKeyID] unsignedIntValue] == musicID) {
            break;
        }
        ++index;
    }

    if (index >= self.purchasedMusicDictionaries.count) {
        NSMutableDictionary *entry =
            [NSMutableDictionary dictionaryWithCapacity:kPurchaseDictionaryCapacity];
        entry[kPurchasedMusicKeyID] = [NSNumber numberWithUnsignedInt:musicID];
        entry[kPurchasedMusicKeyName] = storeMusicInfo.name ? storeMusicInfo.name : kEmptyString;
        entry[kPurchasedMusicKeyArtist] =
            storeMusicInfo.artist ? storeMusicInfo.artist : kEmptyString;
        if (storeMusicInfo.itemURL) {
            entry[kPurchasedMusicKeyItemURL] = storeMusicInfo.itemURL;
        }
        if (storeMusicInfo.itunesURL) {
            entry[kPurchasedMusicKeyITunesURL] = storeMusicInfo.itunesURL;
        }
        [self.purchasedMusicDictionaries
            addObject:[NSDictionary dictionaryWithDictionary:entry]];
        [self setMusicDataArrayDirty];
        return YES;
    }

    // Merge changed fields into a copy of the existing entry.
    NSDictionary *existing = self.purchasedMusicDictionaries[index];
    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:existing];
    BOOL changed = NO;
    if (storeMusicInfo.name &&
        ![storeMusicInfo.name isEqualToString:existing[kPurchasedMusicKeyName]]) {
        merged[kPurchasedMusicKeyName] = storeMusicInfo.name;
        changed = YES;
    }
    if (storeMusicInfo.artist &&
        ![storeMusicInfo.artist isEqualToString:existing[kPurchasedMusicKeyArtist]]) {
        merged[kPurchasedMusicKeyArtist] = storeMusicInfo.artist;
        changed = YES;
    }
    if (storeMusicInfo.itemURL &&
        ![storeMusicInfo.itemURL isEqualToString:existing[kPurchasedMusicKeyItemURL]]) {
        merged[kPurchasedMusicKeyItemURL] = storeMusicInfo.itemURL;
        changed = YES;
    }
    if (storeMusicInfo.itunesURL &&
        ![storeMusicInfo.itunesURL isEqualToString:existing[kPurchasedMusicKeyITunesURL]]) {
        merged[kPurchasedMusicKeyITunesURL] = storeMusicInfo.itunesURL;
        changed = YES;
    }
    if (!changed) {
        [self setMusicDataArrayDirty];
        return NO;
    }
    self.purchasedMusicDictionaries[index] = [NSDictionary dictionaryWithDictionary:merged];
    [self setMusicDataArrayDirty];
    return YES;
}

#pragma mark - Catalogue

- (void)setMusicDataArrayDirty {
    /** @ghidraAddress 0x6c6a8 */
    self.musicDataArrayDirtyFlag = YES;
}

- (void)createMusicDataArray {
    /** @ghidraAddress 0x6c18c */
    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:0];

    for (NSNumber *musicID in self.preinstallMusicIDs) {
        NSString *path = [RBMusicManager getPathFromBundle:musicID.intValue];
        if ([NSFileManager isFileExist:path]) {
            MusicData *data = [MusicData dataWithPath:path ID:musicID.intValue];
            if (data) {
                [entries addObject:data];
            }
        }
    }

    for (NSDictionary *entry in self.purchasedMusicDictionaries) {
        NSNumber *musicID = entry[kPurchasedMusicKeyID];
        NSString *path = [RBMusicManager getPathFromPurchesed:musicID.intValue];
        BOOL exists = [NSFileManager isFileExist:path];
        if (!exists) {
            path = [RBMusicManager getPathFromPurchesedOldDirectory:musicID.intValue];
            exists = [NSFileManager isFileExist:path];
        }
        if (exists) {
            MusicData *data = [MusicData dataWithPath:path ID:musicID.intValue];
            if (data) {
                [entries addObject:data];
            }
        }
    }

    self.musicDataArray = [[NSMutableArray alloc] initWithArray:entries];
    self.musicDataArrayDirtyFlag = NO;
}

- (NSMutableArray *)getMusicDataArray {
    /** @ghidraAddress 0x6c6b8 */
    if (self.musicDataArray == nil || self.musicDataArrayDirtyFlag) {
        [self createMusicDataArray];
    }
    return self.musicDataArray;
}

- (MusicData *)getMusicData:(int)musicID {
    /** @ghidraAddress 0x6c754 */
    for (MusicData *data in self.musicDataArray) {
        if (data.MusicID == musicID) {
            return data;
        }
    }
    return nil;
}

- (void)releaseChacheMusicData {
    /** @ghidraAddress 0x6c8b4 */
    for (MusicData *data in self.musicDataArray) {
        [data releaseChache];
    }
}

- (NSArray *)getMusicIDs {
    /** @ghidraAddress 0x6c9e4 */
    NSMutableArray *ids = [NSMutableArray arrayWithCapacity:kMusicIDsCapacity];
    for (NSNumber *musicID in self.preinstallMusicIDs) {
        [ids addObject:musicID];
    }
    for (NSDictionary *entry in self.purchasedMusicDictionaries) {
        [ids addObject:entry[kPurchasedMusicKeyID]];
    }
    return ids;
}

#pragma mark - Client music list

- (void)releaseClientMusic {
    /** @ghidraAddress 0x6cc80 */
    self.clientMusicPageNum = 0;
}

- (void)setClientMusicPageNum:(int)clientMusicPageNum {
    /** @ghidraAddress 0x6cc90 */
    [self releaseClientMusic];
    _clientMusicPageNum = clientMusicPageNum;
    self.clientMusics = [[NSMutableArray alloc]
        initWithCapacity:(NSUInteger)(clientMusicPageNum * kClientMusicEntriesPerPage)];
}

- (int)setClientMusic:(NSArray *)clientMusic {
    /** @ghidraAddress 0x6cd2c */
    [self.clientMusics addObjectsFromArray:clientMusic];
    self.clientMusicPageNum = self.clientMusicPageNum - 1;
    return self.clientMusicPageNum;
}

- (NSMutableArray *)getClientCompareMusics {
    /** @ghidraAddress 0x6cdf8 */
    NSMutableArray *matches = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *catalogue = [self getMusicDataArray];
    for (NSNumber *clientEntry in self.clientMusics) {
        for (MusicData *data in catalogue) {
            if (clientEntry.intValue == data.MusicID) {
                [matches addObject:data];
                break;
            }
        }
    }
    return matches;
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
