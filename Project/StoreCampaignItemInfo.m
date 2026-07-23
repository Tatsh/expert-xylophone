//
//  StoreCampaignItemInfo.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class StoreCampaignItemInfo). Verified
//  against the arm64 disassembly (the objectForKey:/intValue chains in the initialiser, the
//  unlock-terms switch and its two per-entry loops in termCheck, and the granted-experience gate).
//

#import "StoreCampaignItemInfo.h"

#import <UIKit/UIKit.h>

#import "NSFileManager+RB.h"
#import "RBExperienceData.h"
#import "RBMusicManager.h"
#import "RBPurchaseManager.h"
#import "StoreUtil.h"

// The server campaign-list dictionary keys read by the initialiser.
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

// The granted-experience payload keys read from the unlock dictionary by termCheck.
static NSString *const kUnlockKeyType = @"Type";
static NSString *const kUnlockKeyID = @"ID";

// The format that turns a terms-table entry into a scheme URL probed with -canOpenURL:.
static NSString *const kTermsURLFormat = @"%@://";

// The unlock-terms kinds carried by the item's unlockType.
enum {
    kCampaignUnlockTypeOpen = 0,    // Immediately unlocked.
    kCampaignUnlockTypeAppLink = 1, // Unlocked once every companion application can be opened.
    kCampaignUnlockTypePack = 2,    // Unlocked once every listed pack has been purchased.
    kCampaignUnlockTypeUpdate = 3,  // Same companion-application rule, gated behind an app update.
    kCampaignUnlockTypeSerial = 4,  // Unlocked by a server-verified serial code.
};

// The action-button kinds settled into buttonType. These mirror the values the campaign view
// controller switches on when a cell button is tapped.
enum {
    kCampaignButtonInfoDownload = 0, // Download the item's info.
    kCampaignButtonTerms = 2,        // Show the unlock-terms description.
    kCampaignButtonUpdate = 3,       // Prompt to update the application.
    kCampaignButtonSerialCode = 4,   // Prompt for a serial code.
    kCampaignButtonExperience = 5,   // A granted-experience reward, already applied.
};

// The item type identifying a downloadable tune.
static const int kCampaignItemTypeTune = 0;

// The hide mode that keeps a downloadable tune visible in the row list.
static const int kCampaignHideTypeVisible = 0;

@interface StoreCampaignItemInfo () {
    // The unlock-terms kind; see the kCampaignUnlockType* values. The binary names this ivar
    // without an underscore prefix.
    int unlockType;
    // The list of terms entries (application schemes or pack identifiers) evaluated by termCheck.
    // The binary names this ivar without an underscore prefix.
    NSArray *termsTable;
}
@end

@implementation StoreCampaignItemInfo

// The unlock-terms kind and terms table are private ivars with no matching property, so they are
// synthesised explicitly.
@synthesize unlockType = unlockType;
@synthesize termsTable = termsTable;

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
            // The binary looks the tune up twice and discards both results; the calls are kept for
            // their caching side effect.
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
}

/** @ghidraAddress 0x1096c4 */
- (BOOL)checkExistPackList:(NSArray *)checkExistPackList packID:(int)packID {
    if (checkExistPackList == nil || checkExistPackList.count == 0) {
        return NO;
    }
    for (id entry in checkExistPackList) {
        if ([entry intValue] == packID) {
            return YES;
        }
    }
    return NO;
}

/** @ghidraAddress 0x109850 */
- (BOOL)checkNewUnlock {
    if (!self.bUnlock) {
        return NO;
    }
    return !self.alreadyDownload;
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

@end
