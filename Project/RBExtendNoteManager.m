//
//  RBExtendNoteManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBExtendNoteManager). Verified
//  against the arm64 disassembly (the fast-enumeration loops, the Blowfish key derivation, and the
//  property-list salt-and-encipher round-trip are partly obscured by the decompiler).
//

#import "RBExtendNoteManager.h"

#import <CoreFoundation/CoreFoundation.h>

// Collaborator classes reached from these methods. Their headers are not all reconstructed in this
// tree yet (the same speculative-import style RBMusicManager.m and MusicData.m already use); they
// resolve once those classes land. MusicDataExtend is committed.
#import "AppDelegate.h"
#import "BFCodec.h"
#import "MusicDataExtend.h"
#import "NSData+RB.h"
#import "NSFileManager+RB.h"
#import "neEngineBridge.h"

// The archive filename format: a nine-digit zero-padded extend-note identifier with a @c .rb
// extension.
// @ghidraAddress 0x337a27 (the format-string literal)
static NSString *const kExtendNoteDataFilenameFormat = @"%09d.rb";

// The filename of the enciphered purchased-extend-note list under the Application Support
// directory.
static NSString *const kPurchasedNoteListFilename = @"nolist";

// The keys of a purchased-extend-note dictionary within the persisted list.
static NSString *const kPurchasedNoteKeyExtID = @"ExtID";
static NSString *const kPurchasedNoteKeyID = @"ID";
static NSString *const kPurchasedNoteKeyPackID = @"PackID";
static NSString *const kPurchasedNoteKeyExtLevel = @"ExtLevel";
static NSString *const kPurchasedNoteKeyComment = @"Comment";
static NSString *const kPurchasedNoteKeyExtURL = @"ExtURL";
static NSString *const kPurchasedNoteKeyExtURL2 = @"ExtURL2";

// The initial capacity reserved for the purchased-extend-note list.
static const NSUInteger kPurchasedNoteListCapacity = 64;

// The initial capacity reserved for the extend-note-identifier lists.
static const NSUInteger kExtendNoteIDsCapacity = 3;

// The initial capacity reserved for the enciphered-list scratch buffer and a fresh purchase
// dictionary.
static const NSUInteger kEncipherBufferCapacity = 128;
static const NSUInteger kPurchaseDictionaryCapacity = 5;

// The number of leading salt bytes prepended to the plaintext before enciphering; the same count
// is stripped after deciphering.
static const NSUInteger kListSaltLength = 4;

// The number of client extend-note entries reserved per outstanding page.
static const int kClientNoteEntriesPerPage = 20;

@implementation RBExtendNoteManager

#pragma mark - Singleton

+ (instancetype)getInstance {
    /** @ghidraAddress 0x181aac */
    static RBExtendNoteManager *instance = nil;
    if (instance == nil) {
        instance = [[RBExtendNoteManager alloc] init];
        [instance loadPurchasedNotes];
    }
    return instance;
}

#pragma mark - Asset paths

+ (NSString *)getExtendNoteDataFilename:(int)extendNoteID {
    /** @ghidraAddress 0x181b14 */
    return [NSString stringWithFormat:kExtendNoteDataFilenameFormat, extendNoteID];
}

+ (NSString *)getPathFromBundle:(int)extendNoteID {
    /** @ghidraAddress 0x181b48 */
    // The filename already carries its extension, so the resource is looked up with an empty type.
    NSString *filename = [RBExtendNoteManager getExtendNoteDataFilename:extendNoteID];
    return [NSBundle.mainBundle pathForResource:filename ofType:@""];
}

+ (NSString *)getPathFromPurchased:(int)extendNoteID {
    /** @ghidraAddress 0x181c04 */
    NSString *filename = [RBExtendNoteManager getExtendNoteDataFilename:extendNoteID];
    return [GetPrivateDocumentsPath() stringByAppendingPathComponent:filename];
}

+ (NSString *)getPathFromPurchasedOldDirectory:(int)extendNoteID {
    /** @ghidraAddress 0x181cb4 */
    NSString *filename = [RBExtendNoteManager getExtendNoteDataFilename:extendNoteID];
    return [GetCachesDirectoryPath() stringByAppendingPathComponent:filename];
}

- (BOOL)deleteExtendNote:(int)extendNoteID {
    /** @ghidraAddress 0x181d64 */
    NSString *currentPath = [RBExtendNoteManager getPathFromPurchased:extendNoteID];
    BOOL removedCurrent = NO;
    if ([NSFileManager isFileExist:currentPath]) {
        NSError *error = nil;
        [NSFileManager.defaultManager removeItemAtPath:currentPath error:&error];
        removedCurrent = YES;
    }
    NSString *legacyPath = [RBExtendNoteManager getPathFromPurchasedOldDirectory:extendNoteID];
    if ([NSFileManager isFileExist:legacyPath]) {
        NSError *error = nil;
        [NSFileManager.defaultManager removeItemAtPath:legacyPath error:&error];
    } else if (!removedCurrent) {
        return NO;
    }
    [self setExtendNoteDataArrayDirty];
    return YES;
}

#pragma mark - Purchased extend notes

- (void)loadPurchasedNotes {
    /** @ghidraAddress 0x181fcc */
    NSString *listPath =
        [GetApplicationSupportPath() stringByAppendingPathComponent:kPurchasedNoteListFilename];
    if ([NSFileManager isFileExist:listPath]) {
        NSString *key = [AppDelegate musicListKey];
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:listPath];
        if (data) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:Md5StringToData(key.UTF8String)];
            [codec decipher:data];
            NSData *payload =
                [data subdataWithRange:NSMakeRange(kListSaltLength, data.length - kListSaltLength)];
            self.purchasedExtendNoteDictionaries = [payload mutableArray];
            [self setExtendNoteDataArrayDirty];
        }
    }
    if (self.purchasedExtendNoteDictionaries == nil) {
        self.purchasedExtendNoteDictionaries =
            [[NSMutableArray alloc] initWithCapacity:kPurchasedNoteListCapacity];
        [self setExtendNoteDataArrayDirty];
    }
}

- (void)savePurchasedNotes {
    /** @ghidraAddress 0x182348 */
    if (self.purchasedExtendNoteDictionaries.count == 0) {
        return;
    }
    NSString *listPath =
        [GetApplicationSupportPath() stringByAppendingPathComponent:kPurchasedNoteListFilename];
    NSString *key = [AppDelegate musicListKey];
    CFDataRef plistData = CFPropertyListCreateXMLData(
        kCFAllocatorDefault, (__bridge CFPropertyListRef)self.purchasedExtendNoteDictionaries);
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

- (NSDictionary *)getPurchasedExtendNoteDictionary:(int)extendNoteID {
    /** @ghidraAddress 0x1825bc */
    for (NSDictionary *entry in self.purchasedExtendNoteDictionaries) {
        if ([entry[kPurchasedNoteKeyExtID] unsignedIntValue] == (unsigned int)extendNoteID) {
            return entry;
        }
    }
    return nil;
}

- (NSMutableArray *)getPurchasedExtendNoteDictionaryWithMusicID:(unsigned int)musicID {
    /** @ghidraAddress 0x182770 */
    NSMutableArray *matches = [[NSMutableArray alloc] init];
    for (NSDictionary *entry in self.purchasedExtendNoteDictionaries) {
        if ([entry[kPurchasedNoteKeyID] unsignedIntValue] == musicID) {
            [matches addObject:entry];
        }
    }
    return matches;
}

- (NSMutableArray *)getPurchasedExtendNoteDictionaries {
    /** @ghidraAddress 0x182960 */
    return self.purchasedExtendNoteDictionaries;
}

- (BOOL)addPurchasedExtendNote:(id)extendNoteInfo {
    /** @ghidraAddress 0x18296c */
    unsigned int extendNoteID = (unsigned int)[extendNoteInfo extMusicID];
    NSUInteger index = 0;
    while (index < self.purchasedExtendNoteDictionaries.count) {
        NSDictionary *existing = self.purchasedExtendNoteDictionaries[index];
        if ([existing[kPurchasedNoteKeyExtID] unsignedIntValue] == extendNoteID) {
            break;
        }
        ++index;
    }

    if (index >= self.purchasedExtendNoteDictionaries.count) {
        NSMutableDictionary *entry =
            [NSMutableDictionary dictionaryWithCapacity:kPurchaseDictionaryCapacity];
        entry[kPurchasedNoteKeyExtID] =
            [NSNumber numberWithUnsignedInt:(unsigned int)[extendNoteInfo extMusicID]];
        entry[kPurchasedNoteKeyPackID] =
            [NSNumber numberWithUnsignedInt:(unsigned int)[extendNoteInfo packID]];
        entry[kPurchasedNoteKeyID] =
            [NSNumber numberWithUnsignedInt:(unsigned int)[extendNoteInfo musicID]];
        entry[kPurchasedNoteKeyExtLevel] =
            [NSNumber numberWithUnsignedInt:(unsigned int)[extendNoteInfo difficulty]];
        if ([extendNoteInfo comment]) {
            entry[kPurchasedNoteKeyComment] = [extendNoteInfo comment];
        }
        if ([extendNoteInfo extendNoteURL]) {
            entry[kPurchasedNoteKeyExtURL] = [extendNoteInfo extendNoteURL];
        }
        if ([extendNoteInfo extendURL]) {
            entry[kPurchasedNoteKeyExtURL2] = [extendNoteInfo extendURL];
        }
        [self.purchasedExtendNoteDictionaries
            addObject:[NSDictionary dictionaryWithDictionary:entry]];
        [self setExtendNoteDataArrayDirty];
        return YES;
    }

    // Merge changed fields into a copy of the existing entry.
    NSDictionary *existing = self.purchasedExtendNoteDictionaries[index];
    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:existing];
    BOOL changed = NO;
    if ([extendNoteInfo packID] != [existing[kPurchasedNoteKeyPackID] intValue]) {
        merged[kPurchasedNoteKeyPackID] = [NSNumber numberWithInt:[extendNoteInfo packID]];
        changed = YES;
    }
    if ([extendNoteInfo musicID] != [existing[kPurchasedNoteKeyID] intValue]) {
        merged[kPurchasedNoteKeyID] = [NSNumber numberWithInt:[extendNoteInfo musicID]];
        changed = YES;
    }
    if ([extendNoteInfo difficulty] != [existing[kPurchasedNoteKeyExtLevel] intValue]) {
        merged[kPurchasedNoteKeyExtLevel] = [NSNumber numberWithInt:[extendNoteInfo difficulty]];
        changed = YES;
    }
    if ([extendNoteInfo comment] &&
        [[extendNoteInfo comment] isEqualToString:existing[kPurchasedNoteKeyComment]]) {
        merged[kPurchasedNoteKeyComment] = [extendNoteInfo comment];
        changed = YES;
    }
    if ([extendNoteInfo extendNoteURL] &&
        [[extendNoteInfo extendNoteURL] isEqualToString:existing[kPurchasedNoteKeyExtURL]]) {
        merged[kPurchasedNoteKeyExtURL] = [extendNoteInfo extendNoteURL];
        changed = YES;
    }
    if ([extendNoteInfo extendURL] &&
        [[extendNoteInfo extendURL] isEqualToString:existing[kPurchasedNoteKeyExtURL2]]) {
        merged[kPurchasedNoteKeyExtURL2] = [extendNoteInfo extendURL];
        changed = YES;
    }
    if (!changed) {
        [self setExtendNoteDataArrayDirty];
        return NO;
    }
    self.purchasedExtendNoteDictionaries[index] = [NSDictionary dictionaryWithDictionary:merged];
    [self setExtendNoteDataArrayDirty];
    return YES;
}

#pragma mark - Catalogue

- (void)setExtendNoteDataArrayDirty {
    /** @ghidraAddress 0x1837e8 */
    self.extendNoteDataArrayDirtyFlag = YES;
}

- (void)createExtendNoteDataArray {
    /** @ghidraAddress 0x1834ec */
    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:0];

    for (NSDictionary *entry in self.purchasedExtendNoteDictionaries) {
        NSNumber *extendNoteID = entry[kPurchasedNoteKeyExtID];
        NSString *path = [RBExtendNoteManager getPathFromPurchased:extendNoteID.intValue];
        if ([NSFileManager isFileExist:path]) {
            MusicDataExtend *data = [MusicDataExtend dataWithPath:path dictionary:entry];
            if (data) {
                [entries addObject:data];
            }
        }
    }

    self.extendNoteDataArray = [[NSMutableArray alloc] initWithArray:entries];
    self.extendNoteDataArrayDirtyFlag = NO;
}

- (NSMutableArray *)getExtendNoteDataArray {
    /** @ghidraAddress 0x1837f8 */
    if (self.extendNoteDataArray == nil || self.extendNoteDataArrayDirtyFlag) {
        [self createExtendNoteDataArray];
    }
    return self.extendNoteDataArray;
}

- (MusicDataExtend *)getExtendNoteData:(int)extendNoteID {
    /** @ghidraAddress 0x183894 */
    for (MusicDataExtend *data in [self getExtendNoteDataArray]) {
        if (data.ExtMusicID == extendNoteID) {
            return data;
        }
    }
    return nil;
}

- (void)releaseCacheMusicData {
    /** @ghidraAddress 0x1839f4 */
    for (MusicDataExtend *data in self.extendNoteDataArray) {
        [data releaseCache];
    }
}

- (NSMutableArray *)getExtendNoteIDs {
    /** @ghidraAddress 0x183b24 */
    NSMutableArray *ids = [NSMutableArray arrayWithCapacity:kExtendNoteIDsCapacity];
    for (NSDictionary *entry in self.purchasedExtendNoteDictionaries) {
        [ids addObject:entry[kPurchasedNoteKeyExtID]];
    }
    return ids;
}

- (NSMutableArray *)getExtendNoteIDsWithMusicID:(unsigned int)musicID {
    /** @ghidraAddress 0x183cf0 */
    NSMutableArray *ids = [NSMutableArray arrayWithCapacity:kExtendNoteIDsCapacity];
    for (NSDictionary *entry in self.purchasedExtendNoteDictionaries) {
        if ([entry[kPurchasedNoteKeyID] intValue] == (int)musicID) {
            [ids addObject:entry[kPurchasedNoteKeyExtID]];
        }
    }
    return ids;
}

- (NSMutableArray<MusicDataExtend *> *)getExtendNoteDataWithMusicID:(int)musicID {
    /** @ghidraAddress 0x183f14 */
    NSMutableArray<MusicDataExtend *> *matches = [[NSMutableArray alloc] init];
    for (MusicDataExtend *data in [self getExtendNoteDataArray]) {
        if (data.MusicID == musicID) {
            [matches addObject:data];
        }
    }
    return matches;
}

#pragma mark - Client extend-note list

- (void)releaseClientMusic {
    /** @ghidraAddress 0x1840c0 */
    [self setClientMusicPageNum:0];
}

- (void)setClientMusicPageNum:(int)pageNum {
    /** @ghidraAddress 0x1840d0 */
    [self releaseClientMusic];
    self.clientExtendNotePageNum = pageNum;
    self.clientExtendNotes =
        [[NSMutableArray alloc] initWithCapacity:(NSUInteger)(pageNum * kClientNoteEntriesPerPage)];
}

- (int)setClientMusic:(NSArray *)clientMusic {
    /** @ghidraAddress 0x18416c */
    [self.clientExtendNotes addObjectsFromArray:clientMusic];
    self.clientExtendNotePageNum = self.clientExtendNotePageNum - 1;
    return self.clientExtendNotePageNum;
}

- (NSMutableArray *)getClientCompareExtendNotes {
    /** @ghidraAddress 0x184238 */
    NSMutableArray *matches = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *catalogue = [self getExtendNoteDataArray];
    for (NSNumber *clientEntry in self.clientExtendNotes) {
        for (MusicDataExtend *data in catalogue) {
            if (clientEntry.intValue == data.MusicID) {
                [matches addObject:data];
                break;
            }
        }
    }
    return matches;
}

@end
