//
//  StoreMusicInfo.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class StoreMusicInfo). Verified against
//  the arm64 disassembly (the objectForKey:/intValue chains, the iTunes-URL validity gate, and the
//  per-difficulty level clamp).
//

#import "StoreMusicInfo.h"

// Collaborator classes reached from these methods. Their headers are not all reconstructed in this
// tree yet (the same speculative-import style the other data models already use); they resolve once
// those classes land.
#import "NSFileManager+RB.h"
#import "RBMusicManager.h"
#import "StoreUtil.h"

/// The catalogue entry dictionary keys.
static NSString *const kMusicInfoKeyID = @"ID";
static NSString *const kMusicInfoKeyName = @"Name";
static NSString *const kMusicInfoKeyArtist = @"Artist";
static NSString *const kMusicInfoKeyItemURL = @"ItemURL";
static NSString *const kMusicInfoKeySampleURL = @"SampleURL";
static NSString *const kMusicInfoKeyArtworkURL = @"ArtworkURL";
static NSString *const kMusicInfoKeyITunesURL = @"iTunesURL";
static NSString *const kMusicInfoKeyLevel = @"Level";
static NSString *const kMusicInfoKeyPID = @"PID";

/// The smallest valid tune identifier; a lesser value rejects the entry.
static const int kMinValidMusicID = 1;

/// The number of @c Level entries required before the per-difficulty levels are read.
static const NSUInteger kRequiredLevelCount = 3;

/// The indices of the three per-difficulty levels within the @c Level array.
enum {
    kStoreMusicInfoLevelIndexBasic = 0,
    kStoreMusicInfoLevelIndexMedium = 1,
    kStoreMusicInfoLevelIndexHard = 2,
};

/// The inclusive range each per-difficulty level is clamped to.
static const int kMinLevel = 1;
static const int kMaxLevel = 15;

/// Clamp a per-difficulty level to the valid inclusive range.
static int ClampLevel(int level) {
    if (level < kMinLevel) {
        return kMinLevel;
    }
    if (level > kMaxLevel) {
        return kMaxLevel;
    }
    return level;
}

@implementation StoreMusicInfo

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    /** @ghidraAddress 0x67e84 */
    int musicID = [dictionary[kMusicInfoKeyID] intValue];
    if (musicID < kMinValidMusicID) {
        return nil;
    }
    self = [super init];
    if (self == nil) {
        return nil;
    }
    self.musicID = [dictionary[kMusicInfoKeyID] intValue];
    self.name = dictionary[kMusicInfoKeyName];
    self.artist = dictionary[kMusicInfoKeyArtist];
    self.itemURL = dictionary[kMusicInfoKeyItemURL];
    self.sampleURL = dictionary[kMusicInfoKeySampleURL];
    self.artworkURL = dictionary[kMusicInfoKeyArtworkURL];
    NSString *itunesURL = dictionary[kMusicInfoKeyITunesURL];
    if ([StoreUtil isValidURL:itunesURL]) {
        self.itunesURL = itunesURL;
    }

    NSArray *levels = dictionary[kMusicInfoKeyLevel];
    if (levels.count >= kRequiredLevelCount) {
        self.lvBasic = [levels[kStoreMusicInfoLevelIndexBasic] intValue];
        self.lvMedium = [levels[kStoreMusicInfoLevelIndexMedium] intValue];
        self.lvHard = [levels[kStoreMusicInfoLevelIndexHard] intValue];
    }
    self.lvBasic = ClampLevel(self.lvBasic);
    self.lvMedium = ClampLevel(self.lvMedium);
    self.lvHard = ClampLevel(self.lvHard);

    NSArray *extIDList = dictionary[kMusicInfoKeyPID];
    if (extIDList != nil && extIDList.count > 0) {
        self.extIDList = [extIDList copy];
    }
    return self;
}

- (BOOL)fileExist {
    /** @ghidraAddress 0x683f0 */
    NSString *currentPath = [RBMusicManager getPathFromPurchesed:self.musicID];
    if ([NSFileManager isFileExist:currentPath]) {
        return YES;
    }
    NSString *legacyPath = [RBMusicManager getPathFromPurchesedOldDirectory:self.musicID];
    return [NSFileManager isFileExist:legacyPath];
}

@end
