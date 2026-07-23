//
//  StorePackInfo.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class StorePackInfo). Verified against
//  the arm64 disassembly (the setMusicInfo: four-tune cap and immutable-copy store, the
//  setDictionary: key reads, and the allDownloaded/downloadDetailInfo tune-list checks).
//

#import "StorePackInfo.h"

// Collaborator classes reached from these methods. Their headers are not all reconstructed in this
// tree yet (the same speculative-import style the other data models already use); they resolve once
// those classes land.
#import "StoreMusicInfo.h"
#import "StoreUtil.h"

// The catalogue entry dictionary keys.
static NSString *const kPackInfoKeyID = @"ID";
static NSString *const kPackInfoKeyMusicList = @"MusicList";
static NSString *const kPackInfoKeyName = @"Name";
static NSString *const kPackInfoKeyComment = @"Comment";
static NSString *const kPackInfoKeyShortComment = @"ShortComment";
static NSString *const kPackInfoKeyIsNew = @"IsNew";
static NSString *const kPackInfoKeyCopyright = @"Copyright";
static NSString *const kPackInfoKeyArtworkURL = @"ArtworkURL";
static NSString *const kPackInfoKeyArtistURL = @"ArtistURL";
static NSString *const kPackInfoKeyArtistBunnerURL = @"ArtistBunnerURL";
static NSString *const kPackInfoKeyExtNum = @"ExtNum";

// The most tunes kept when a pack's music list is read from the catalogue.
static const NSUInteger kMaxPackMusicInfos = 4;

// The advertised extend-note count when the entry omits it.
static const int kDefaultExtCount = 0;

@implementation StorePackInfo

#pragma mark - Initialisation

- (instancetype)initWithProduct:(SKProduct *)product {
    self = [super init];
    if (product != nil && self != nil) {
        self.product = product;
        self.packID = [StoreUtil packIDForProductID:self.product.productIdentifier];
    }
    return self;
}

- (instancetype)initWithPackID:(int)packID {
    self = [super init];
    if (self != nil) {
        self.packID = packID;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (dictionary != nil && self != nil) {
        self.packID = [dictionary[kPackInfoKeyID] intValue];
        [self setDictionary:dictionary];
    }
    return self;
}

#pragma mark - Catalogue metadata

- (BOOL)setDictionary:(NSDictionary *)dictionary {
    if ([dictionary[kPackInfoKeyID] intValue] != self.packID) {
        return NO;
    }

    NSArray<NSDictionary *> *musicList = dictionary[kPackInfoKeyMusicList];

    NSString *name = dictionary[kPackInfoKeyName];
    if (name != nil) {
        self.packName = name;
    }
    NSString *comment = dictionary[kPackInfoKeyComment];
    if (comment != nil) {
        self.comment = comment;
    }
    NSString *shortComment = dictionary[kPackInfoKeyShortComment];
    if (shortComment != nil) {
        self.s_comment = shortComment;
    }
    NSNumber *isNew = dictionary[kPackInfoKeyIsNew];
    if (isNew != nil) {
        self.isNew = isNew.boolValue;
    }
    NSString *copyright = dictionary[kPackInfoKeyCopyright];
    if (copyright != nil) {
        self.copyright = copyright;
    }
    // The three URL entries are only stored when they arrive as real strings.
    NSString *artworkURL = dictionary[kPackInfoKeyArtworkURL];
    if (artworkURL != nil && [artworkURL isKindOfClass:[NSString class]]) {
        self.artworkURL = artworkURL;
    }
    NSString *artistURL = dictionary[kPackInfoKeyArtistURL];
    if (artistURL != nil && [artistURL isKindOfClass:[NSString class]]) {
        self.artistURL = artistURL;
    }
    NSString *bunnerURL = dictionary[kPackInfoKeyArtistBunnerURL];
    if (bunnerURL != nil && [bunnerURL isKindOfClass:[NSString class]]) {
        self.bunnerURL = bunnerURL;
    }

    NSNumber *extNum = dictionary[kPackInfoKeyExtNum];
    self.extCount = (extNum != nil) ? extNum.intValue : kDefaultExtCount;

    return [self setMusicInfo:musicList];
}

- (BOOL)setMusicInfo:(NSArray<NSDictionary *> *)musicInfo {
    if (self.musicInfos != nil) {
        return YES;
    }
    if (musicInfo.count == 0) {
        return NO;
    }

    NSMutableArray<StoreMusicInfo *> *infos = [NSMutableArray arrayWithCapacity:kMaxPackMusicInfos];
    for (NSDictionary *entry in musicInfo) {
        StoreMusicInfo *info = [[StoreMusicInfo alloc] initWithDictionary:entry];
        if (info != nil) {
            [infos addObject:info];
            if (infos.count > kMaxPackMusicInfos - 1) {
                break;
            }
        }
    }

    if (infos.count == 0) {
        return NO;
    }
    self.musicInfos = [[NSArray alloc] initWithArray:infos];
    return YES;
}

#pragma mark - Derived state

- (NSString *)priceString {
    return [StoreUtil priceString:self.product];
}

- (BOOL)downloadDetailInfo {
    return self.musicInfos == nil;
}

- (BOOL)allDownloaded {
    for (StoreMusicInfo *info in self.musicInfos) {
        if (![info fileExist]) {
            return NO;
        }
    }
    return YES;
}

@end
