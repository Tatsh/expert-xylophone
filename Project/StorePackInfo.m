#import "StorePackInfo.h"

#import "StoreMusicInfo.h"
#import "StoreUtil.h"

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

#ifdef ENABLE_PATCHES
// The shipped server never sends a pack price, so this is read only when present.
static NSString *const kPackInfoKeyPrice = @"Price";
#endif

static const NSUInteger kMaxPackMusicInfos = 4;

static const int kDefaultExtCount = 0;

#ifdef ENABLE_PATCHES
// Held off the object so the class gains no ivar and no accessor the shipped one lacks.
static NSMutableDictionary<NSNumber *, NSNumber *> *g_catalogPackPrices = nil;

NSNumber *RBStorePackCatalogPrice(int packID) {
    return g_catalogPackPrices[@(packID)];
}

BOOL RBStorePackIsFreeFromCatalog(int packID) {
    NSNumber *price = RBStorePackCatalogPrice(packID);
    return price != nil && price.intValue == 0;
}

static void RBNotePackCatalogPrice(int packID, NSDictionary *dictionary) {
    NSNumber *price = dictionary[kPackInfoKeyPrice];
    if (price == nil) {
        return;
    }
    if (g_catalogPackPrices == nil) {
        g_catalogPackPrices = [NSMutableDictionary dictionary];
    }
    g_catalogPackPrices[@(packID)] = price;
}
#endif

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
#ifdef ENABLE_PATCHES
    RBNotePackCatalogPrice(self.packID, dictionary);
#endif
    NSString *copyright = dictionary[kPackInfoKeyCopyright];
    if (copyright != nil) {
        self.copyright = copyright;
    }
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
#ifdef ENABLE_PATCHES
    // With no StoreKit product there is no localised price, so fall back to the catalogue's bare
    // number rather than leaving the label blank.
    if (self.product == nil) {
        NSNumber *price = RBStorePackCatalogPrice(self.packID);
        return price != nil ? price.stringValue : nil;
    }
#endif
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
