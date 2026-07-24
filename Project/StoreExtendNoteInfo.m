#import "StoreExtendNoteInfo.h"

#import <UIKit/UIKit.h>

#import "NSFileManager+RB.h"
#import "RBExtendNoteManager.h"
#import "RBMusicManager.h"
#import "RBPurchaseManager.h"
#import "StoreUtil.h"
#import "neEngineBridge.h"

// Server catalogue dictionary keys read by the extend-note initialisers and by setDictionary:.
static NSString *const kStoreExtendKeyPID = @"PID";
static NSString *const kStoreExtendKeyPackID = @"PackID";
static NSString *const kStoreExtendKeyExtID = @"ExtID";
static NSString *const kStoreExtendKeyPackName = @"PackName";
static NSString *const kStoreExtendKeyComment = @"Comment";
static NSString *const kStoreExtendKeyPrice = @"Price";
static NSString *const kStoreExtendKeyExtLevel = @"ExtLevel";
static NSString *const kStoreExtendKeyExtURL = @"ExtURL";
static NSString *const kStoreExtendKeyExtURL2 = @"ExtURL2";
static NSString *const kStoreExtendKeyIsNew = @"IsNew";
static NSString *const kStoreExtendKeyMusic = @"Music";

// Keys of the nested "Music" sub-dictionary read by setDictionary: into the inherited tune
// metadata.
static NSString *const kStoreExtendMusicKeyID = @"ID";
static NSString *const kStoreExtendMusicKeyName = @"Name";
static NSString *const kStoreExtendMusicKeyArtist = @"Artist";
static NSString *const kStoreExtendMusicKeyItemURL = @"ItemURL";
static NSString *const kStoreExtendMusicKeySampleURL = @"SampleURL";
static NSString *const kStoreExtendMusicKeyArtworkURL = @"ArtworkURL";
static NSString *const kStoreExtendMusicKeyItunesURL = @"iTunesURL";
static NSString *const kStoreExtendMusicKeyLevel = @"Level";

// The number of difficulty entries the "Level" array must contain before it is read.
static const NSUInteger kStoreExtendMinLevelCount = 3;
// The clamp bounds applied to each parsed difficulty level.
static const int kStoreExtendLevelMin = 1;
static const int kStoreExtendLevelBasicMax = 10;
static const int kStoreExtendLevelDetailedMax = 11;

// The smallest value that counts as a valid pack or extend-note identifier.
static const int kStoreExtendMinValidID = 1;

// The more-info action-button title shown for a pack that has not been purchased.
static NSString *const kStoreExtendButtonMoreInfo = @"More Info";

// The blue channel of the not-purchased button tint, and the shared component of the purchased
// tint.
static const CGFloat kStoreExtendButtonTintComponent = 128.0 / 255.0;

@implementation StoreExtendNoteInfo

#pragma mark - Initialisation

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super initWithDictionary:dictionary[kStoreExtendKeyMusic]];
    if (self) {
        self.pid = [dictionary[kStoreExtendKeyPID] intValue];
        self.extMusicID = [dictionary[kStoreExtendKeyExtID] intValue];
        self.packID = [dictionary[kStoreExtendKeyPackID] intValue];
        self.packName = dictionary[kStoreExtendKeyPackName];
        self.comment = dictionary[kStoreExtendKeyComment];
        self.price = [dictionary[kStoreExtendKeyPrice] intValue];
        self.difficulty = [dictionary[kStoreExtendKeyExtLevel] intValue];
        self.extendNoteURL = dictionary[kStoreExtendKeyExtURL];
        self.extendURL = dictionary[kStoreExtendKeyExtURL2];
        self.isNew = [dictionary[kStoreExtendKeyIsNew] boolValue];
    }
    return self;
}

- (instancetype)initWithExtendDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        self.pid = [dictionary[kStoreExtendKeyPID] intValue];
        self.extMusicID = [dictionary[kStoreExtendKeyExtID] intValue];
        self.packID = [dictionary[kStoreExtendKeyPackID] intValue];
        self.packName = dictionary[kStoreExtendKeyPackName];
        self.comment = dictionary[kStoreExtendKeyComment];
        self.price = [dictionary[kStoreExtendKeyPrice] intValue];
        self.difficulty = [dictionary[kStoreExtendKeyExtLevel] intValue];
        self.extendNoteURL = dictionary[kStoreExtendKeyExtURL];
        self.extendURL = dictionary[kStoreExtendKeyExtURL2];
        self.isNew = [dictionary[kStoreExtendKeyIsNew] boolValue];
    }
    return self;
}

- (instancetype)initWithProduct:(SKProduct *)product {
    self = [super init];
    if (product && self) {
        self.product = product;
        self.pid = [StoreUtil productIDToPid:self.product.productIdentifier];
    }
    return self;
}

- (instancetype)initWithExtendNoteID:(int)extendNoteID {
    self = [super init];
    if (self) {
        self.pid = extendNoteID;
    }
    return self;
}

#pragma mark - Catalogue parsing

- (BOOL)setDictionary:(NSDictionary *)dictionary {
    if (self.pid != [dictionary[kStoreExtendKeyPID] intValue]) {
        return NO;
    }
    if (dictionary[kStoreExtendKeyPackID]) {
        self.packID = [dictionary[kStoreExtendKeyPackID] intValue];
    }
    if (dictionary[kStoreExtendKeyExtID]) {
        self.extMusicID = [dictionary[kStoreExtendKeyExtID] intValue];
    }
    if (dictionary[kStoreExtendKeyPackName]) {
        self.packName = dictionary[kStoreExtendKeyPackName];
    }
    if (dictionary[kStoreExtendKeyComment]) {
        self.comment = dictionary[kStoreExtendKeyComment];
    }
    if (dictionary[kStoreExtendKeyPrice]) {
        self.price = [dictionary[kStoreExtendKeyPrice] intValue];
    }
    if (dictionary[kStoreExtendKeyExtLevel]) {
        self.difficulty = [dictionary[kStoreExtendKeyExtLevel] intValue];
    }
    if (dictionary[kStoreExtendKeyExtURL]) {
        self.extendNoteURL = dictionary[kStoreExtendKeyExtURL];
    }
    if (dictionary[kStoreExtendKeyExtURL2]) {
        self.extendURL = dictionary[kStoreExtendKeyExtURL2];
    }
    if (dictionary[kStoreExtendKeyIsNew]) {
        self.isNew = [dictionary[kStoreExtendKeyIsNew] boolValue];
    }
    NSDictionary *music = dictionary[kStoreExtendKeyMusic];
    if (music) {
        self.musicID = [music[kStoreExtendMusicKeyID] intValue];
        self.name = music[kStoreExtendMusicKeyName];
        self.artist = music[kStoreExtendMusicKeyArtist];
        self.itemURL = music[kStoreExtendMusicKeyItemURL];
        self.sampleURL = music[kStoreExtendMusicKeySampleURL];
        self.artworkURL = music[kStoreExtendMusicKeyArtworkURL];
        self.itemURL = music[kStoreExtendMusicKeyItemURL];
        NSString *itunesURL = music[kStoreExtendMusicKeyItunesURL];
        if ([StoreUtil isValidURL:itunesURL]) {
            self.itunesURL = itunesURL;
        }
        NSArray *levels = music[kStoreExtendMusicKeyLevel];
        if (levels.count >= kStoreExtendMinLevelCount) {
            self.lvBasic = [levels[0] intValue];
            self.lvMedium = [levels[1] intValue];
            self.lvHard = [levels[2] intValue];
        }
        if (self.lvBasic < kStoreExtendLevelMin) {
            self.lvBasic = kStoreExtendLevelMin;
        } else if (self.lvBasic > kStoreExtendLevelBasicMax) {
            self.lvBasic = kStoreExtendLevelBasicMax;
        }
        if (self.lvMedium < kStoreExtendLevelMin) {
            self.lvMedium = kStoreExtendLevelMin;
        } else if (self.lvMedium > kStoreExtendLevelDetailedMax) {
            self.lvMedium = kStoreExtendLevelDetailedMax;
        }
        if (self.lvHard < kStoreExtendLevelMin) {
            self.lvHard = kStoreExtendLevelMin;
        } else if (self.lvHard > kStoreExtendLevelDetailedMax) {
            self.lvHard = kStoreExtendLevelDetailedMax;
        }
    }
    return YES;
}

#pragma mark - Purchase and download state

- (BOOL)purchasedPack {
    if (self.packID < kStoreExtendMinValidID) {
        return NO;
    }
    return
        [[RBPurchaseManager sharedManager] isPurchased:[StoreUtil productIDForPackID:self.packID]];
}

- (BOOL)purchasedNote {
    if (self.pid < kStoreExtendMinValidID) {
        return NO;
    }
    return [[RBPurchaseManager sharedManager] isPurchased:[StoreUtil pidToProductID:self.pid]];
}

- (BOOL)alreadyDownloadBin {
    RBMusicManager *musicManager = [RBMusicManager getInstance];
    if (![musicManager getPurchasedMusicDictionary:self.musicID]) {
        return NO;
    }
    NSString *path = [RBMusicManager getPathFromPurchesed:self.musicID];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (BOOL)alreadyDownloadNote {
    RBExtendNoteManager *extendNoteManager = [RBExtendNoteManager getInstance];
    if (![extendNoteManager getPurchasedExtendNoteDictionary:self.extMusicID]) {
        return NO;
    }
    return [NSFileManager isFileExist:[RBExtendNoteManager getPathFromPurchased:self.extMusicID]];
}

- (BOOL)extFileExist {
    return [NSFileManager isFileExist:[RBExtendNoteManager getPathFromPurchased:self.pid]];
}

#pragma mark - Pack cell button presentation

- (StoreExtendNoteButtonState)getButtonState {
    if (!self.purchasedPack) {
        return StoreExtendNoteButtonStateMoreInfo;
    }
    if (!self.purchasedNote) {
        return StoreExtendNoteButtonStatePurchase;
    }
    if (!self.alreadyDownloadBin) {
        return StoreExtendNoteButtonStateDownloadBin;
    }
    if (!self.alreadyDownloadNote) {
        return StoreExtendNoteButtonStateDownloadNote;
    }
    if (self.purchasedPack && self.purchasedNote && self.alreadyDownloadBin &&
        self.alreadyDownloadNote) {
        return StoreExtendNoteButtonStateInstalled;
    }
    return StoreExtendNoteButtonStateError;
}

- (UIColor *)getButtonColor {
    if (!self.purchasedPack) {
        return [UIColor colorWithRed:0 green:0 blue:kStoreExtendButtonTintComponent alpha:1];
    }
    if (!self.purchasedNote) {
        return [UIColor colorWithRed:kStoreExtendButtonTintComponent
                               green:0
                                blue:kStoreExtendButtonTintComponent
                               alpha:1];
    }
    if (self.purchasedNote && !(self.alreadyDownloadBin && self.alreadyDownloadNote)) {
        return UIColor.blueColor;
    }
    return UIColor.grayColor;
}

- (NSString *)getButtonName {
    if (!self.purchasedPack) {
        return kStoreExtendButtonMoreInfo;
    }
    if (!self.purchasedNote) {
        return
            [NSString stringWithFormat:g_pLocalizedBuyFormat, [StoreUtil priceString:self.product]];
    }
    if (self.purchasedNote && !(self.alreadyDownloadBin && self.alreadyDownloadNote)) {
        return g_pLocalizedDownload;
    }
    if (self.purchasedPack && self.purchasedNote && self.alreadyDownloadBin &&
        self.alreadyDownloadNote) {
        return g_pLocalizedInstalled;
    }
    return g_pLocalizedError;
}

@end
