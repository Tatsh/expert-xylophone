#import "RBMusicManager.h"

#import <CoreFoundation/CoreFoundation.h>

#import "AppDelegate.h"
#import "BFCodec.h"
#import "MusicData.h"
#import "NSData+RB.h"
#import "NSFileManager+RB.h"
#import "RBMacros.h"
#import "StoreMusicInfo.h"
#import "deviceenvironment.h"
#import "enginecrypto.h"

#ifdef ENABLE_PATCHES
#import "RBExtendNoteManager.h"
#import "minizip/mz_compat.h"
#endif

// @ghidraAddress 0x337a27 (the format-string literal)
static NSString *const kMusicDataFilenameFormat = @"%09d.rb";

static NSString *const kEmptyResourceType = @"";

static NSString *const kEmptyString = @"";

static NSString *const kPurchasedMusicListFilename = @"mulist";

static NSString *const kPurchasedMusicKeyID = @"ID";
static NSString *const kPurchasedMusicKeyName = @"Name";
static NSString *const kPurchasedMusicKeyArtist = @"Artist";
static NSString *const kPurchasedMusicKeyItemURL = @"ItemURL";
static NSString *const kPurchasedMusicKeyITunesURL = @"iTunesURL";

// @ghidraAddress 0x2fcfe0 (g_nPreinstallMusicIDs)
static const int kPreinstallMusicIDs[] = {100000107, 100000109, 100000419};
static const NSUInteger kPreinstallMusicIDCount = ARRAY_SIZE(kPreinstallMusicIDs);

static const NSUInteger kPurchasedMusicListCapacity = 64;
static const NSUInteger kMusicIDsCapacity = 3;

static const NSUInteger kEncipherBufferCapacity = 128;
static const NSUInteger kPurchaseDictionaryCapacity = 5;

static const NSUInteger kListSaltLength = 4;

#ifdef ENABLE_PATCHES
static NSString *const kMusicDataFileExtension = @"rb";
static const NSUInteger kMusicDataIDDigits = 9;

// Extend-note packages occupy their own identifier block: every one is 100050xxx, and the tune it
// holds the SPECIAL chart for is the same number 50000 lower.
static const int kExtendNoteIDFirst = 100050000;
static const int kExtendNoteIDCount = 1000;
static const int kExtendNoteIDParentDelta = 50000;

// An extend-note archive carries only its SPECIAL chart, served out of the basic slot, and ships
// the other two entries blank.
static NSString *const kArchiveChartEntry = @"note_bas";
static NSString *const kArchiveMediumChartEntry = @"note_med";
static NSString *const kArchiveHardChartEntry = @"note_har";

enum {
    kChartSlotBasic,
    kChartSlotMedium,
    kChartSlotHard,
    kChartSlotCount,
};

// A blank placeholder chart runs to a few dozen bytes; the sparsest real chart is tens of
// kilobytes.
static const uint32_t kBlankChartMaximumSize = 1024;

// Mirrors MusicData's own kLevelMinimum.
static const int kArchiveLevelMinimum = 1;

// The customise screen's timing-adjust preview and the tutorial tune, neither of them catalogue
// entries.
static const int kReservedArchiveIDs[] = {999999998, 999999999};

// A drop-in song must carry some item URL: -[StoreDownloadTask initWithURL:] builds its field with
// -[NSString initWithString:], which raises on nil.
static NSString *const kDropInItemURLFormat = @"%@://%@%@%@";
#endif

static const int kClientMusicEntriesPerPage = 20;

@implementation RBMusicManager

// The page count keeps its own backing ivar because the setter is overridden.
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

#ifdef ENABLE_PATCHES

#pragma mark - Drop-in archive discovery (ENABLE_PATCHES)

static BOOL RBIsExtendNoteID(int musicID) {
    return musicID >= kExtendNoteIDFirst && musicID < kExtendNoteIDFirst + kExtendNoteIDCount;
}

static int RBExtendNoteParentID(int extendNoteID) {
    return extendNoteID - kExtendNoteIDParentDelta;
}

// A structural second opinion for an archive whose identifier is outside the block above: no tune
// ships both the MEDIUM and HARD entries blank.
static BOOL RBArchiveIsExtendNote(NSString *archivePath) {
    unzFile archive = unzOpen(archivePath.fileSystemRepresentation);
    if (archive == NULL) {
        return NO;
    }
    NSString *const entries[] = {
        [kChartSlotBasic] = kArchiveChartEntry,
        [kChartSlotMedium] = kArchiveMediumChartEntry,
        [kChartSlotHard] = kArchiveHardChartEntry,
    };
    uint32_t sizes[kChartSlotCount] = {};
    BOOL readAll = YES;
    for (NSUInteger slot = 0; slot < kChartSlotCount; ++slot) {
        unz_file_info info = {};
        if (unzLocateFile(archive, entries[slot].UTF8String, NULL) != UNZ_OK ||
            unzGetCurrentFileInfo(archive, &info, NULL, 0, NULL, 0, NULL, 0) != UNZ_OK) {
            readAll = NO;
            break;
        }
        sizes[slot] = (uint32_t)info.uncompressed_size;
    }
    unzClose(archive);
    if (!readAll) {
        return NO;
    }
    return sizes[kChartSlotBasic] > kBlankChartMaximumSize &&
           sizes[kChartSlotMedium] <= kBlankChartMaximumSize &&
           sizes[kChartSlotHard] <= kBlankChartMaximumSize;
}

static void RBCollectArchiveIDs(NSString *directory, NSMutableSet<NSNumber *> *outIDs) {
    if (directory == nil) {
        return;
    }
    NSArray<NSString *> *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory
                                                                                   error:NULL];
    NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    for (NSString *name in names) {
        if (![name.pathExtension isEqualToString:kMusicDataFileExtension]) {
            continue;
        }
        NSString *stem = name.stringByDeletingPathExtension;
        if (stem.length != kMusicDataIDDigits ||
            [stem rangeOfCharacterFromSet:nonDigits].location != NSNotFound) {
            continue;
        }
        [outIDs addObject:@(stem.intValue)];
    }
}

// The writable locations come first so a file placed there overrides one of the same name shipped
// in the bundle.
+ (NSArray<NSString *> *)archiveSearchDirectories {
    return @[
        GetPrivateDocumentsPath(),
        GetDocumentsDirectoryPath(),
        GetCachesDirectoryPath(),
        NSBundle.mainBundle.bundlePath,
    ];
}

+ (NSString *)resolveArchivePath:(int)musicID {
    NSString *filename = [RBMusicManager getMusicDataFilename:musicID];
    for (NSString *directory in [RBMusicManager archiveSearchDirectories]) {
        if (directory == nil) {
            continue;
        }
        NSString *path = [directory stringByAppendingPathComponent:filename];
        if ([NSFileManager isFileExist:path]) {
            return path;
        }
    }
    return nil;
}

- (BOOL)reconcilePurchasedMusics {
    RBExtendNoteManager *noteManager = [RBExtendNoteManager getInstance];

    // Misfiled extend notes are dropped so the pass below can place them properly.
    NSIndexSet *misfiled = [self.purchasedMusicDictionaries
        indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger index, BOOL *stop) {
          return RBIsExtendNoteID([entry[kPurchasedMusicKeyID] intValue]);
        }];
    const BOOL misfiledRemoved = misfiled.count != 0;
    [self.purchasedMusicDictionaries removeObjectsAtIndexes:misfiled];

    // An identifier already in either list is left alone; re-registering one is how a duplicate
    // song appears.
    NSMutableSet<NSNumber *> *listedMusicIDs = [NSMutableSet set];
    for (NSDictionary *entry in self.purchasedMusicDictionaries) {
        [listedMusicIDs addObject:entry[kPurchasedMusicKeyID]];
    }
    NSMutableSet<NSNumber *> *listedNoteIDs =
        [NSMutableSet setWithArray:[noteManager getExtendNoteIDs]];

    // The preinstalled songs come from the bundle through their own loop in -createMusicDataArray,
    // so listing them here would draw each of them twice.
    NSMutableSet<NSNumber *> *knownMusicIDs = [NSMutableSet setWithSet:listedMusicIDs];
    [knownMusicIDs addObjectsFromArray:self.preinstallMusicIDs];

    NSMutableSet<NSNumber *> *reservedIDs = [NSMutableSet set];
    for (NSUInteger index = 0; index < ARRAY_SIZE(kReservedArchiveIDs); ++index) {
        [reservedIDs addObject:@(kReservedArchiveIDs[index])];
    }

    NSMutableSet<NSNumber *> *presentSet = [NSMutableSet set];
    for (NSString *directory in [RBMusicManager archiveSearchDirectories]) {
        RBCollectArchiveIDs(directory, presentSet);
    }

    NSArray<NSNumber *> *presentIDs =
        [presentSet.allObjects sortedArrayUsingSelector:@selector(compare:)];

    NSMutableArray<NSNumber *> *newTuneIDs = [NSMutableArray array];
    NSMutableArray<NSNumber *> *newNoteIDs = [NSMutableArray array];
    for (NSNumber *foundID in presentIDs) {
        if ([listedMusicIDs containsObject:foundID] || [listedNoteIDs containsObject:foundID] ||
            [knownMusicIDs containsObject:foundID] || [reservedIDs containsObject:foundID]) {
            continue;
        }
        NSString *path = [RBMusicManager resolveArchivePath:foundID.intValue];
        if (path == nil) {
            continue;
        }
        if (RBIsExtendNoteID(foundID.intValue)) {
            [newNoteIDs addObject:foundID];
        } else if (!RBArchiveIsExtendNote(path)) {
            [newTuneIDs addObject:foundID];
        }
        // An extend note numbered outside the block is passed over: nothing says which tune it
        // belongs to.
    }

    BOOL musicListChanged = misfiledRemoved;
    BOOL noteListChanged = NO;
    for (NSNumber *foundID in newTuneIDs) {
        NSString *path = [RBMusicManager resolveArchivePath:foundID.intValue];
        // Reading the archive doubles as a validity check: the factory rejects a file whose own
        // identifier disagrees with its name.
        MusicData *data = [MusicData dataWithPath:path ID:foundID.intValue];
        if (data == nil) {
            continue;
        }

        NSMutableDictionary *entry =
            [NSMutableDictionary dictionaryWithCapacity:kPurchaseDictionaryCapacity];
        entry[kPurchasedMusicKeyID] = foundID;
        entry[kPurchasedMusicKeyName] = data.musicName ? data.musicName : kEmptyString;
        entry[kPurchasedMusicKeyArtist] = data.artistName ? data.artistName : kEmptyString;
        entry[kPurchasedMusicKeyItemURL] =
            [NSString stringWithFormat:kDropInItemURLFormat,
                                       @RB_API_SCHEME,
                                       @RB_API_HOST,
                                       @RB_API_BASE_PATH,
                                       [RBMusicManager getMusicDataFilename:foundID.intValue]];
        [self.purchasedMusicDictionaries addObject:[NSDictionary dictionaryWithDictionary:entry]];
        [listedMusicIDs addObject:foundID];
        [knownMusicIDs addObject:foundID];
        musicListChanged = YES;
    }

    for (NSNumber *foundID in newNoteIDs) {
        NSString *path = [RBMusicManager resolveArchivePath:foundID.intValue];
        MusicData *data = [MusicData dataWithPath:path ID:foundID.intValue];
        if (data == nil) {
            continue;
        }

        NSNumber *parentMusicID = @(RBExtendNoteParentID(foundID.intValue));

        // With the tune absent the note is left out: listing it would draw a second copy of the
        // tune with two empty difficulties.
        if (![knownMusicIDs containsObject:parentMusicID] &&
            [RBMusicManager resolveArchivePath:parentMusicID.intValue] == nil) {
            continue;
        }

        if ([noteManager addDiscoveredExtendNote:foundID.intValue
                                         musicID:parentMusicID.intValue
                                           level:data.difficultyBasic + kArchiveLevelMinimum]) {
            [listedNoteIDs addObject:foundID];
            noteListChanged = YES;
        }
    }

    NSUInteger before = self.purchasedMusicDictionaries.count;
    NSIndexSet *missing = [self.purchasedMusicDictionaries
        indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger index, BOOL *stop) {
          return [RBMusicManager resolveArchivePath:[entry[kPurchasedMusicKeyID] intValue]] == nil;
        }];
    [self.purchasedMusicDictionaries removeObjectsAtIndexes:missing];
    musicListChanged = musicListChanged || self.purchasedMusicDictionaries.count != before;

    if (noteListChanged) {
        [noteManager savePurchasedNotes];
    }
    if (musicListChanged) {
        [self setMusicDataArrayDirty];
        [self savePurchasedMusics];
    }
    return musicListChanged || noteListChanged;
}

#endif

#pragma mark - Purchased music

- (void)loadPurchasedMusics {
    /** @ghidraAddress 0x6b020 */
    NSString *listPath =
        [GetDocumentsDirectoryPath() stringByAppendingPathComponent:kPurchasedMusicListFilename];
    if ([NSFileManager isFileExist:listPath]) {
        NSString *key = [AppDelegate musicListKey];
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:listPath];
        if (data) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:Md5StringToData(key.UTF8String)];
            [codec decipher:data];
            NSData *payload =
                [data subdataWithRange:NSMakeRange(kListSaltLength, data.length - kListSaltLength)];
            self.purchasedMusicDictionaries = [payload mutableArray];
            [self setMusicDataArrayDirty];
        }
    }
    if (self.purchasedMusicDictionaries == nil) {
        self.purchasedMusicDictionaries =
            [[NSMutableArray alloc] initWithCapacity:kPurchasedMusicListCapacity];
        [self setMusicDataArrayDirty];
    }
#ifdef ENABLE_PATCHES
    [self reconcilePurchasedMusics];
#endif
}

- (void)savePurchasedMusics {
    /** @ghidraAddress 0x6b39c */
    if (self.purchasedMusicDictionaries.count == 0) {
        return;
    }
    NSString *listPath =
        [GetDocumentsDirectoryPath() stringByAppendingPathComponent:kPurchasedMusicListFilename];
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
    unsigned int musicID = (unsigned int)storeMusicInfo.musicID;
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
        [self.purchasedMusicDictionaries addObject:[NSDictionary dictionaryWithDictionary:entry]];
        [self setMusicDataArrayDirty];
        return YES;
    }

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
#ifdef ENABLE_PATCHES
        // Search every drop-in directory, not just the two the binary knows.
        NSString *path = [RBMusicManager resolveArchivePath:musicID.intValue];
        const BOOL exists = path != nil;
#else
        NSString *path = [RBMusicManager getPathFromPurchesed:musicID.intValue];
        BOOL exists = [NSFileManager isFileExist:path];
        if (!exists) {
            path = [RBMusicManager getPathFromPurchesedOldDirectory:musicID.intValue];
            exists = [NSFileManager isFileExist:path];
        }
#endif
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
    // The binary sends -releaseClientMusic here, which recurses back into this setter forever.
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
