#import "StoreCampaignItemInfo.h"

#import <UIKit/UIKit.h>

#import "NSFileManager+RB.h"
#import "RBExperienceData.h"
#import "RBMusicManager.h"
#import "RBPurchaseManager.h"
#import "StoreUtil.h"

static NSString *const kCampaignKeyMusic = @"music";
static NSString *const kCampaignKeyCampaignID = @"campaignId";
static NSString *const kCampaignKeyItemID = @"itemId";
static NSString *const kCampaignKeyItemType = @"itemType";
static NSString *const kCampaignKeyName = @"name";
static NSString *const kCampaignKeyDescription = @"description";
static NSString *const kCampaignKeyTermsDescription = @"termsDescription";
static NSString *const kCampaignKeyBannerURL = @"bannerUrl";
static NSString *const kCampaignKeyThumbnailURL = @"thumbnailUrl";
static NSString *const kCampaignKeyCopyright = @"copyright";
static NSString *const kCampaignKeyOption = @"option";
static NSString *const kCampaignKeyForeignURL = @"foreignUrl";
static NSString *const kCampaignKeyUnlocked = @"unlocked";
static NSString *const kCampaignKeyTermsTable = @"termsTable";
static NSString *const kCampaignKeyUnlockType = @"unlockType";
static NSString *const kCampaignKeyHideType = @"hideType";

static NSString *const kUnlockKeyType = @"Type";
static NSString *const kUnlockKeyID = @"ID";

static NSString *const kTermsURLFormat = @"%@://";

enum {
    kCampaignButtonTypeDownload = 0,
    kCampaignButtonTypeDownloaded = 1,
    kCampaignButtonTypeUnlockCond = 2,
    kCampaignButtonTypeUpdate = 3,
    kCampaignButtonTypeSerialInput = 4,
    kCampaignButtonTypePointUnlocked = 5,
};
static NSString *const kButtonNameDownload = @"ダウンロード";
static NSString *const kButtonNameDownloaded = @"ダウンロード済み";
static NSString *const kButtonNameUnlockCond = @"解禁条件";
static NSString *const kButtonNameUpdate = @"アップデート";
static NSString *const kButtonNameSerialInput = @"シリアル入力";
static NSString *const kButtonNamePointUnlocked = @"ポイント解禁済み";

enum {
    kCampaignUnlockTypeOpen = 0,
    kCampaignUnlockTypeAppLink = 1,
    kCampaignUnlockTypePack = 2,
    kCampaignUnlockTypeUpdate = 3,
    kCampaignUnlockTypeSerial = 4,
};

// These mirror the values the campaign view controller switches on when a cell button is tapped.
enum {
    kCampaignButtonInfoDownload = 0,
    kCampaignButtonTerms = 2,
    kCampaignButtonUpdate = 3,
    kCampaignButtonSerialCode = 4,
    kCampaignButtonExperience = 5,
};

static const int kCampaignItemTypeTune = 0;

static const int kCampaignHideTypeVisible = 0;

@interface StoreCampaignItemInfo () {
    // The binary names these ivars without an underscore prefix.
    int unlockType;
    NSArray *termsTable;
}
@end

@implementation StoreCampaignItemInfo

#ifdef ENABLE_PATCHES
// Overriding a readonly property's getter suppresses its synthesis, so the backing ivar has to be
// named explicitly.
@synthesize bUnlock = _bUnlock;

// Report every gift as granted even before -termCheck has run.
- (BOOL)bUnlock {
    return YES;
}
#endif

#pragma mark - Initialisation

/** @ghidraAddress 0x108b90 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    NSDictionary *musicDict = dictionary[kCampaignKeyMusic];
    if (musicDict == nil) {
        self = [super init];
    } else {
        self = [super initWithDictionary:dictionary[kCampaignKeyMusic]];
    }
    if (self == nil) {
        return nil;
    }

    _campaignID = [dictionary[kCampaignKeyCampaignID] intValue];
    _itemID = [dictionary[kCampaignKeyItemID] intValue];
    _itemType = [dictionary[kCampaignKeyItemType] intValue];
    _campaignName = dictionary[kCampaignKeyName];
    _campaignDescription = dictionary[kCampaignKeyDescription];
    _campaignTermsDescription = dictionary[kCampaignKeyTermsDescription];
    _campaignBannerURL = dictionary[kCampaignKeyBannerURL];
    if (_itemType == kCampaignItemTypeTune) {
        _thumbnailURL = dictionary[kCampaignKeyThumbnailURL];
    }
    _copyright = dictionary[kCampaignKeyCopyright];
    _unlockDict = dictionary[kCampaignKeyOption];

    NSString *foreignURL = dictionary[kCampaignKeyForeignURL];
    if (foreignURL != nil && foreignURL.length != 0) {
        _linkURL = [NSURL URLWithString:foreignURL];
    }

    _bServerUnlock = [dictionary[kCampaignKeyUnlocked] boolValue];
    termsTable = dictionary[kCampaignKeyTermsTable];
    unlockType = [dictionary[kCampaignKeyUnlockType] intValue];
    _hideType = [dictionary[kCampaignKeyHideType] intValue];

    [self termCheck];
    return self;
}

#pragma mark - Unlock evaluation

/** @ghidraAddress 0x109088 */
- (BOOL)termCheck {
#ifdef ENABLE_PATCHES
    // Grant every gift outright, overriding the experience-point arm at the tail of the original.
    _bUnlock = YES;
    _alreadyDownload = [self hasItem:self.itemType itemID:self.itemID];
    _buttonType = kCampaignButtonInfoDownload;
    return YES;
#else
    _bUnlock = NO;
    _alreadyDownload = [self hasItem:self.itemType itemID:self.itemID];

    switch (unlockType) {
    case kCampaignUnlockTypeOpen:
        _bUnlock = YES;
        break;
    case kCampaignUnlockTypeAppLink:
    case kCampaignUnlockTypeUpdate: {
        int count = (int)termsTable.count;
        int openable = 0;
        for (int i = 0; i < count; ++i) {
            NSString *scheme = [NSString stringWithFormat:kTermsURLFormat, termsTable[i]];
            NSURL *url = [NSURL URLWithString:scheme];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                ++openable;
            }
        }
        if (count > 0 && openable == count) {
            _bUnlock = YES;
        }
        break;
    }
    case kCampaignUnlockTypePack: {
        int count = (int)termsTable.count;
        int purchased = 0;
        for (int i = 0; i < count; ++i) {
            int packID = [termsTable[i] intValue];
            NSString *productID = [StoreUtil productIDForPackID:packID];
            if ([[RBPurchaseManager sharedManager] isPurchased:productID]) {
                ++purchased;
            }
        }
        if (count > 0 && purchased == count) {
            _bUnlock = YES;
        }
        break;
    }
    case kCampaignUnlockTypeSerial:
        _bUnlock = _bServerUnlock;
        break;
    default:
        break;
    }

    if (_bUnlock) {
        if (_itemType == kCampaignItemTypeTune) {
            // The binary looks this up twice and discards both results; kept for the side effect.
            (void)[[RBMusicManager getInstance] getMusicData:self.itemID];
            (void)[[RBMusicManager getInstance] getMusicData:self.itemID];
            _buttonType = kCampaignButtonInfoDownload;
            _hideType = kCampaignHideTypeVisible;
        }
    } else {
        if (unlockType == kCampaignUnlockTypeSerial) {
            _buttonType = kCampaignButtonSerialCode;
        } else if (unlockType == kCampaignUnlockTypeUpdate ||
                   unlockType == kCampaignUnlockTypePack) {
            _buttonType = kCampaignButtonTerms;
        } else {
            _buttonType = kCampaignButtonUpdate;
        }
    }

    if (_unlockDict != nil && _unlockDict[kUnlockKeyType] != nil &&
        _unlockDict[kUnlockKeyID] != nil) {
        int type = [_unlockDict[kUnlockKeyType] intValue];
        int itemID = [_unlockDict[kUnlockKeyID] intValue];
        BOOL granted = [[RBExperienceData sharedInstance] unlockWithType:type ID:itemID];
        if (granted && !_bServerUnlock) {
            _bUnlock = NO;
            _buttonType = kCampaignButtonExperience;
        }
    }

    return _bUnlock;
#endif
}

/** @ghidraAddress 0x1096c4 */
- (BOOL)checkExistPackList:(NSArray *)checkExistPackList packID:(int)packID {
#ifdef ENABLE_PATCHES
    // Treat the pack as owned whatever the server said.
    return YES;
#else
    if (checkExistPackList == nil || checkExistPackList.count == 0) {
        return NO;
    }
    for (id entry in checkExistPackList) {
        if ([entry intValue] == packID) {
            return YES;
        }
    }
    return NO;
#endif
}

/** @ghidraAddress 0x109850 */
- (BOOL)checkNewUnlock {
#ifdef ENABLE_PATCHES
    // Everything is granted, so the only question left is whether it still needs downloading.
    return !self.alreadyDownload;
#else
    if (!self.bUnlock) {
        return NO;
    }
    return !self.alreadyDownload;
#endif
}

/** @ghidraAddress 0x109898 */
- (BOOL)hasItem:(int)hasItem itemID:(int)itemID {
    if (hasItem != kCampaignItemTypeTune) {
        return NO;
    }
    if ([[RBMusicManager getInstance] getMusicData:itemID] == nil) {
        return NO;
    }
    NSString *path = [RBMusicManager getPathFromPurchesed:itemID];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

/** @ghidraAddress 0x1099ac */
- (void)registSuccess {
    _bServerUnlock = YES;
    _bUnlock = YES;
}

/** @ghidraAddress 0x1099cc */
+ (UIColor *)getButtonColor:(int)buttonType {
    switch (buttonType) {
    case kCampaignButtonTypeDownload:
        return UIColor.blueColor;
    case kCampaignButtonTypeDownloaded:
        return UIColor.grayColor;
    case kCampaignButtonTypeUnlockCond:
        return [UIColor colorWithRed:0 green:0 blue:128.0f / 255.0f alpha:1];
    case kCampaignButtonTypeUpdate:
        return [UIColor colorWithRed:0 green:150.0f / 255.0f blue:1 alpha:1];
    case kCampaignButtonTypeSerialInput:
        return UIColor.greenColor;
    case kCampaignButtonTypePointUnlocked:
        return UIColor.grayColor;
    default:
        // The original built this from components equal to white.
        return UIColor.whiteColor;
    }
}

/** @ghidraAddress 0x109b10 */
+ (NSString *)getButtonName:(int)buttonType {
    switch (buttonType) {
    case kCampaignButtonTypeDownload:
        return kButtonNameDownload;
    case kCampaignButtonTypeDownloaded:
        return kButtonNameDownloaded;
    case kCampaignButtonTypeUnlockCond:
        return kButtonNameUnlockCond;
    case kCampaignButtonTypeUpdate:
        return kButtonNameUpdate;
    case kCampaignButtonTypeSerialInput:
        return kButtonNameSerialInput;
    case kCampaignButtonTypePointUnlocked:
        return kButtonNamePointUnlocked;
    default:
        return nil;
    }
}

@end
