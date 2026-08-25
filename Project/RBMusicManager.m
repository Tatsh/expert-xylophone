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

#import "RBMacros.h"

// Collaborator classes reached from these methods. Their headers are not all reconstructed in this
// tree yet (the same speculative-import style AppDelegate.mm and ScoreData.m already use); they
// resolve once those classes land. MusicData is committed.
#import "AppDelegate.h"
#import "BFCodec.h"
#import "MusicData.h"
#import "NSData+RB.h"
#import "NSFileManager+RB.h"
#import "StoreMusicInfo.h"
#import "deviceenvironment.h"
#import "enginecrypto.h"

#ifdef ENABLE_PATCHES
// minizip's legacy unz API, for the central-directory CRC-32 the drop-in reconcile pairs archives
// by. It is already linked into the target through the vendored SSZipArchive.
#import "RBExtendNoteManager.h"
#import "minizip/mz_compat.h"
#endif

// The archive filename format: a nine-digit zero-padded tune identifier with a @c .rb extension.
// @ghidraAddress 0x337a27 (the format-string literal)
static NSString *const kMusicDataFilenameFormat = @"%09d.rb";

// The archive resource type passed to @c -[NSBundle pathForResource:ofType:] (already carried by
// the filename, so the type is empty).
static NSString *const kEmptyResourceType = @"";

// The empty replacement stored for a missing name or artist string in a purchase dictionary.
static NSString *const kEmptyString = @"";

// The filename of the enciphered purchased-music list under the Application Support directory.
static NSString *const kPurchasedMusicListFilename = @"mulist";

// The keys of a purchased-music dictionary within the persisted list.
static NSString *const kPurchasedMusicKeyID = @"ID";
static NSString *const kPurchasedMusicKeyName = @"Name";
static NSString *const kPurchasedMusicKeyArtist = @"Artist";
static NSString *const kPurchasedMusicKeyItemURL = @"ItemURL";
static NSString *const kPurchasedMusicKeyITunesURL = @"iTunesURL";

// The three songs shipped inside the bundle, read from the table -createPreInMusics indexes. They
// name 100000107.rb, 100000109.rb and 100000419.rb, which are exactly the three .rb files the
// bundle carries. @ghidraAddress 0x2fcfe0 (g_nPreinstallMusicIDs)
static const int kPreinstallMusicIDs[] = {100000107, 100000109, 100000419};
static const NSUInteger kPreinstallMusicIDCount = ARRAY_SIZE(kPreinstallMusicIDs);

// The initial capacity reserved for the purchased-music and identifier lists.
static const NSUInteger kPurchasedMusicListCapacity = 64;
static const NSUInteger kMusicIDsCapacity = 3;

// The initial capacity reserved for the enciphered-list scratch buffer and a fresh purchase
// dictionary.
static const NSUInteger kEncipherBufferCapacity = 128;
static const NSUInteger kPurchaseDictionaryCapacity = 5;

// The number of leading salt bytes prepended to the plaintext before enciphering; the same count
// is stripped after deciphering.
static const NSUInteger kListSaltLength = 4;

#ifdef ENABLE_PATCHES
// The archive extension and identifier width, used to recognise a canonical %09d.rb name on disk.
static NSString *const kMusicDataFileExtension = @"rb";
static const NSUInteger kMusicDataIDDigits = 9;

// Extend-note packages occupy their own identifier block. Every one is 100050xxx, and the tune it
// holds the SPECIAL chart for is the same number 50000 lower: 100050433 belongs to 100000433. That
// is the whole pairing rule, and it needs neither archive opened.
static const int kExtendNoteIDFirst = 100050000;
static const int kExtendNoteIDCount = 1000;
static const int kExtendNoteIDParentDelta = 50000;

// The three chart entries. An extend-note archive carries only its SPECIAL chart, served out of the
// basic slot, and ships the other two as blank placeholders.
static NSString *const kArchiveChartEntry = @"note_bas";
static NSString *const kArchiveMediumChartEntry = @"note_med";
static NSString *const kArchiveHardChartEntry = @"note_har";

// The three chart entries in the order the blank test reads them.
enum {
    kChartSlotBasic,
    kChartSlotMedium,
    kChartSlotHard,
    kChartSlotCount,
};

// The largest a chart entry can be and still be a placeholder rather than a real chart. The blanks
// an extend note ships run to a few dozen bytes, where the sparsest real chart is measured in tens
// of kilobytes, so anything in between separates the two.
static const uint32_t kBlankChartMaximumSize = 1024;

// The lowest level an archive's difficulty field can hold, mirroring MusicData's own kLevelMinimum.
static const int kArchiveLevelMinimum = 1;

// The bundle ships two archives that are not catalogue tunes: the timing-adjust preview used by the
// customise screen (kPreviewMusicID in RBViewController.mm) and the tutorial tune (kTutorialMusicID
// in RBMusicView.mm, spelled 0x3b9ac9fe there). Both are loaded straight from the bundle by
// identifier wherever they are needed, so registering either would list it as an ordinary song.
static const int kReservedArchiveIDs[] = {999999998, 999999999};

// The item URL given to a drop-in song: the configured API endpoint with the archive's own name on
// the end. It has to be something rather than nothing, because -[StoreDownloadTask initWithURL:]
// builds its field with -[NSString initWithString:], which raises on nil — so an entry with no item
// URL turns the store's manage-tab download button into a crash.
static NSString *const kDropInItemURLFormat = @"%@://%@%@%@";
#endif

// The number of client-music entries reserved per outstanding page.
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

#ifdef ENABLE_PATCHES

#pragma mark - Drop-in archive discovery (ENABLE_PATCHES)

// Whether an identifier falls in the extend-note block, and the tune an extend note belongs to.
// Neither reads the archive, so classifying and pairing a drop-in costs no file access at all.
static BOOL RBIsExtendNoteID(int musicID) {
    return musicID >= kExtendNoteIDFirst && musicID < kExtendNoteIDFirst + kExtendNoteIDCount;
}

static int RBExtendNoteParentID(int extendNoteID) {
    return extendNoteID - kExtendNoteIDParentDelta;
}

// A structural second opinion, for an archive whose identifier is outside the block above. An
// extend note has no MEDIUM or HARD chart to carry and ships both entries blank, which no tune
// does, so this recognises one that does not follow the numbering. It cannot say which tune the
// note belongs to — only the identifier can — so such a note is passed over rather than listed.
// The archive is opened once for all three entries rather than once per entry.
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

// Every canonical %09d.rb identifier in one directory. A name that is not exactly nine digits is
// ignored, so only archives the loaders can actually resolve by identifier are considered.
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

// The directories a drop-in archive may be placed in, in the order they are searched. The writable
// locations come first so a file put there overrides one of the same name shipped in the bundle,
// and the bundle comes last because it is the only one a non-jailbroken install cannot write to.
// Extend-note archives use the same %09d.rb naming, so this resolves either kind.
+ (NSArray<NSString *> *)archiveSearchDirectories {
    return @[
        GetPrivateDocumentsPath(),      // Library/Private Documents, where purchases land
        GetDocumentsDirectoryPath(),    // Documents, reachable over iTunes file sharing
        GetCachesDirectoryPath(),       // Library/Caches, the binary's legacy download directory
        NSBundle.mainBundle.bundlePath, // the .app itself
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

    // Drop any song entry that is really an extend note. An earlier pairing rule went by the audio
    // alone, so a note whose package re-encoded its tune's audio matched nothing and was filed as a
    // song of its own; clearing those here lets the pass below place them properly instead of
    // skipping them as already listed.
    NSIndexSet *misfiled = [self.purchasedMusicDictionaries
        indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger index, BOOL *stop) {
          return RBIsExtendNoteID([entry[kPurchasedMusicKeyID] intValue]);
        }];
    const BOOL misfiledRemoved = misfiled.count != 0;
    [self.purchasedMusicDictionaries removeObjectsAtIndexes:misfiled];

    // What each list already claims. An identifier in either list is left alone: it is already
    // provided, and re-registering it is exactly how a duplicate song appears.
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

    // The bundle's two non-catalogue archives are skipped outright: the tutorial and preview tunes
    // are loaded straight from the bundle by identifier, so registering either would list it as an
    // ordinary song.
    NSMutableSet<NSNumber *> *reservedIDs = [NSMutableSet set];
    for (NSUInteger index = 0; index < ARRAY_SIZE(kReservedArchiveIDs); ++index) {
        [reservedIDs addObject:@(kReservedArchiveIDs[index])];
    }

    NSMutableSet<NSNumber *> *presentSet = [NSMutableSet set];
    for (NSString *directory in [RBMusicManager archiveSearchDirectories]) {
        RBCollectArchiveIDs(directory, presentSet);
    }

    // Sorted, so a batch is always considered in the same order rather than in whatever order the
    // set's hashes fall in.
    NSArray<NSNumber *> *presentIDs =
        [presentSet.allObjects sortedArrayUsingSelector:@selector(compare:)];

    // Sort the unlisted archives into tunes and extend notes. The identifier decides it, so a note
    // and the tune it belongs to can be dropped in together in either order.
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
        // An extend note numbered outside the block is passed over: its charts give it away, but
        // nothing says which tune it belongs to, and listing it would draw a second copy of that
        // tune with two empty difficulties.
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

        // The name and artist are copied out of the archive rather than left blank: the store's
        // manage tab draws its rows, its download prompt, and its delete prompt from these two
        // fields rather than from the archive. The item URL is built from the configured endpoint
        // and the archive's own name, so a replacement server serving the file under that name can
        // fetch it again.
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

        // The tune is named by the identifier itself, so the pairing needs nothing read and holds
        // whether or not the note ships that tune's audio unchanged.
        NSNumber *parentMusicID = @(RBExtendNoteParentID(foundID.intValue));

        // With the tune absent the note is left out rather than registered: it carries no MEDIUM or
        // HARD chart, so listing it would draw a second copy of the tune with two empty
        // difficulties.
        if (![knownMusicIDs containsObject:parentMusicID] &&
            [RBMusicManager resolveArchivePath:parentMusicID.intValue] == nil) {
            continue;
        }

        // Its level is the archive's own basic level, because the SPECIAL chart is served out of
        // the basic slot.
        if ([noteManager addDiscoveredExtendNote:foundID.intValue
                                         musicID:parentMusicID.intValue
                                           level:data.difficultyBasic + kArchiveLevelMinimum]) {
            [listedNoteIDs addObject:foundID];
            noteListChanged = YES;
        }
    }

    // Forget entries whose archive has gone, so a deleted file does not linger in the list.
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
    // Pick up anything dropped into the purchased directory since last launch. See PATCHES.md.
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
#ifdef ENABLE_PATCHES
        // Search every drop-in directory, not just the two the binary knows, so an archive placed
        // in Documents or in the bundle plays rather than merely appearing in the list.
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
    // The binary opens by sending releaseClientMusic to self and then sends its own selector
    // rather than storing. Since -releaseClientMusic above is nothing but
    // [self setClientMusicPageNum:0], the two recurse into each other until the stack is
    // exhausted, whichever is called first. The cycle is broken here by both storing directly and
    // dropping the release send: the release would only have allocated an empty array for this
    // line to immediately replace. Not gated behind ENABLE_PATCHES, because the faithful form is
    // an immediate stack overflow and no build wants it.
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
