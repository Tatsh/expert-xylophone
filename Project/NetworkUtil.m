#import "NetworkUtil.h"

#import "AppDelegate.h"
#import "RBMacros.h"
#import "RBUserSettingData.h"
#import "SystemHardware.h"
#import "deviceenvironment.h"
#import "enginecrypto.h"

static NSString *const kSecureAPIScheme = @RB_API_SCHEME;
static NSString *const kSecureAPIHost = @RB_API_HOST;
static NSString *const kSecureAPIBasePath = @RB_API_BASE_PATH;

static NSString *const kTokenSetAPIPath = @"push/token/";

static NSString *const kSearchMasterAPIPath = @"search_master/";
static NSString *const kSearchListAPIPath = @"gamecenter/";

static NSString *const kUserInfoFormat = @"uuid=%@&version=%@&device=%@&os=%@&locale=%@";
static NSString *const kSearchMasterParamFormat = @"target=%@&%@";

static NSString *const kUnlockListParamFormat = @"target=%@&thema=%@";
static NSString *const kUnlockMusicParamFormat = @"target=%@&music=%d&key=%d&%@";

static NSString *const kPlayedV2APIPath = @"log/play/";
static NSString *const kUnlockListAPIPath = @"unlock/";
static NSString *const kUnlockMusicAPIPath = @"unlockmusic/";
static NSString *const kUnlockedAPIPath = @"unlocked/";
static NSString *const kTutorialAPIPath = @"tutorial/";
static NSString *const kStartupAPIPath = @"startup/";

static NSString *const kStartupParamFormat = @"target=%@";
static NSString *const kResourceAPIPath = @"v3/ssl_resource/";
static NSString *const kTermListAPIPath = @"v3/terms/list/";
static NSString *const kTermFetchAPIPath = @"v3/terms/fetch/";
static NSString *const kTermAgreeAPIPath = @"v3/terms/log/";
static NSString *const kExtendNoteListAPIPath = @"v3/extmusiclist/";
static NSString *const kExtendNoteInfoAPIPath = @"v3/extmusicinfo/";

static NSString *const kExtendNoteListParamFormat = @"target=%@&head=%d&limit=%d&%@";
static NSString *const kExtendNoteInfoParamFormat = @"target=%@&extitem=%d";
static NSString *const kExtendNoteInfoUserOpenParamFormat = @"target=%@&extitem=%d&%@";

static NSString *const kLineMessageAPIPath = @"new2/";
static NSString *const kPackListAPIPath = @"v3/packlist/";
static NSString *const kPackInfoAPIPath = @"v3/packinfo/";
static NSString *const kMusicInfoAPIPath = @"v3/musicinfo/";
static NSString *const kReceiptV3APIPath = @"v3/verify_receipt/";
static NSString *const kCampaignListAPIPath = @"campaign/list/";
static NSString *const kCampaignItemInfoAPIPath = @"campaign/fetch/";
static NSString *const kCampaignSerialCheckAPIPath = @"campaign/verify/";
static NSString *const kManageSortListAPIPath = @"manage_sort/";
static NSString *const kUserAgeAPIPath = @"v3/age/";

static NSString *const kLineMessageParamFormat = @"target=%@&%@";
static NSString *const kPackListParamFormat = @"target=%@&head=%d&limit=%d&genre=%d&%@";
static NSString *const kPackInfoParamFormat = @"target=%@&pack=%d";
static NSString *const kPackInfoUserOpenParamFormat = @"target=%@&pack=%d&%@";
static NSString *const kMusicInfoParamFormat = @"target=%@&music=%d&%@";
static NSString *const kManageSortListParamFormat = @"target=%@";

static NSString *const kIdentifierKeySuffix = @"STORE";

static NSString *const kNonceCharFormat = @"%c";

@interface NetworkUtil ()
+ (NSString *)userInfo;
@end

@implementation NetworkUtil

+ (NSURL *)createSecureURL:(NSString *)path {
    return [[NSURL alloc] initWithScheme:kSecureAPIScheme host:kSecureAPIHost path:path];
}

+ (NSURL *)createSecureAPI:(NSString *)api withParam:(NSString *)param {
    NSString *path;
    if (param) {
        path = [NSString stringWithFormat:@"%@%@?%@", kSecureAPIBasePath, api, param];
    } else {
        path = [NSString stringWithFormat:@"%@%@", kSecureAPIBasePath, api];
    }
    return [NetworkUtil createSecureURL:path];
}

+ (NSURL *)tokenSetURL {
    return [NetworkUtil createSecureAPI:kTokenSetAPIPath withParam:nil];
}

+ (NSString *)userInfo {
    return [NSString stringWithFormat:kUserInfoFormat,
                                      [NetworkUtil identifierParams],
                                      GetBundleVersionString(),
                                      [NetworkUtil deviceName],
                                      GetSystemVersionString(),
                                      GetFormattedVersionString()];
}

+ (NSURL *)searchMasterURL {
    NSString *param = [NSString
        stringWithFormat:kSearchMasterParamFormat, GetRegionCode(), [NetworkUtil userInfo]];
    return [NetworkUtil createSecureAPI:kSearchMasterAPIPath withParam:param];
}

+ (NSURL *)searchURL {
    return [NetworkUtil createSecureAPI:kSearchListAPIPath withParam:nil];
}

/** @ghidraAddress 0x327b0 */
+ (NSString *)identifierParams {
    static NSString *sIdentifierParams = nil;
    if (sIdentifierParams == nil) {
#ifdef ENABLE_PATCHES
        // The identity, not the list key, whose patched value is fixed and shared by every install.
        NSString *seed = [RBDeviceIdentityUUID() stringByAppendingString:kIdentifierKeySuffix];
#else
        NSString *seed = [[AppDelegate musicListKey] stringByAppendingString:kIdentifierKeySuffix];
#endif
        sIdentifierParams = Md5StringToHex(seed.UTF8String);
    }
    return sIdentifierParams;
}

/** @ghidraAddress 0x32740 */
+ (NSString *)deviceName {
    return [SystemHardware.getInstance getHardwareName];
}

/** @ghidraAddress 0x32dac */
+ (NSURL *)playedV2URL {
    return [NetworkUtil createSecureAPI:kPlayedV2APIPath withParam:nil];
}

/** @ghidraAddress 0x33168 */
+ (NSURL *)unlockedURL {
    return [NetworkUtil createSecureAPI:kUnlockedAPIPath withParam:nil];
}

/** @ghidraAddress 0x32f08 */
+ (NSURL *)unlockListURL {
    NSString *param = [NSString stringWithFormat:kUnlockListParamFormat,
                                                 GetRegionCode(),
                                                 @(RBUserSettingData.sharedInstance.thema)];
    return [NetworkUtil createSecureAPI:kUnlockListAPIPath withParam:param];
}

/** @ghidraAddress 0x33058 */
+ (NSURL *)unlockMusicURL:(int)musicID randKey:(int)randKey {
    NSString *param = [NSString stringWithFormat:kUnlockMusicParamFormat,
                                                 GetRegionCode(),
                                                 musicID,
                                                 randKey,
                                                 [NetworkUtil userInfo]];
    return [NetworkUtil createSecureAPI:kUnlockMusicAPIPath withParam:param];
}

/**
 * The reward-check endpoint. The binary references this selector but ships no implementation for
 * it, so it resolves to @c nil at runtime; kept to match the declared interface.
 */
+ (NSURL *)rewardCheckURL {
    return nil;
}

/** @ghidraAddress 0x32610 */
+ (NSString *)createNonce:(NSUInteger)length {
    if (length == 0) {
        return @"";
    }
    static const char kNonceAlphabet[] =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    static const unsigned int kNonceAlphabetSize = 62;
    NSMutableString *nonce = [[NSMutableString alloc] initWithCapacity:length];
    for (NSUInteger i = 0; i < length; ++i) {
        [nonce appendFormat:kNonceCharFormat, kNonceAlphabet[arc4random() % kNonceAlphabetSize]];
    }
    return [[NSString alloc] initWithString:nonce];
}

/** @ghidraAddress 0x32ba0 */
+ (NSURL *)startupURL {
    NSString *param = [NSString stringWithFormat:kStartupParamFormat, GetRegionCode()];
    return [NetworkUtil createSecureAPI:kStartupAPIPath withParam:param];
}

/** @ghidraAddress 0x32dcc */
+ (NSURL *)tutorialStatusURL {
    return [NetworkUtil createSecureAPI:kTutorialAPIPath withParam:nil];
}

/** @ghidraAddress 0x32c70 */
+ (NSURL *)resourceURL {
    return [NetworkUtil createSecureAPI:kResourceAPIPath withParam:nil];
}

/** @ghidraAddress 0x338cc */
+ (NSURL *)termList {
    return [NetworkUtil createSecureAPI:kTermListAPIPath withParam:nil];
}

/** @ghidraAddress 0x338ec */
+ (NSURL *)termFetch {
    return [NetworkUtil createSecureAPI:kTermFetchAPIPath withParam:nil];
}

/** @ghidraAddress 0x3390c */
+ (NSURL *)termAgree {
    return [NetworkUtil createSecureAPI:kTermAgreeAPIPath withParam:nil];
}

/**
 * The legacy play-log endpoint. The binary references this selector but ships no implementation for
 * it (the version 2 endpoint superseded it), so it resolves to @c nil at runtime; kept to match the
 * declared interface.
 */
+ (NSURL *)playedURL {
    return nil;
}

/** @ghidraAddress 0x3365c */
+ (NSURL *)extendNoteListURL:(unsigned int)offset limit:(unsigned int)limit {
    NSString *param = [NSString stringWithFormat:kExtendNoteListParamFormat,
                                                 GetRegionCode(),
                                                 offset,
                                                 limit,
                                                 [NetworkUtil userInfo]];
    return [NetworkUtil createSecureAPI:kExtendNoteListAPIPath withParam:param];
}

/** @ghidraAddress 0x3376c */
+ (NSURL *)extendNoteInfoURL:(unsigned int)extendNoteID UserOpen:(BOOL)userOpen {
    NSString *param;
    if (userOpen) {
        param = [NSString stringWithFormat:kExtendNoteInfoUserOpenParamFormat,
                                           GetRegionCode(),
                                           extendNoteID,
                                           [NetworkUtil userInfo]];
    } else {
        param =
            [NSString stringWithFormat:kExtendNoteInfoParamFormat, GetRegionCode(), extendNoteID];
    }
    return [NetworkUtil createSecureAPI:kExtendNoteInfoAPIPath withParam:param];
}

/** @ghidraAddress 0x32cb0 */
+ (NSURL *)lineMessageURL {
    NSString *param = [NSString
        stringWithFormat:kLineMessageParamFormat, GetRegionCode(), [NetworkUtil userInfo]];
    return [NetworkUtil createSecureAPI:kLineMessageAPIPath withParam:param];
}

/** @ghidraAddress 0x33188 */
+ (NSURL *)packListURL:(unsigned int)head limit:(unsigned int)limit genre:(unsigned int)genre {
    NSString *param = [NSString stringWithFormat:kPackListParamFormat,
                                                 GetRegionCode(),
                                                 head,
                                                 limit,
                                                 genre,
                                                 [NetworkUtil userInfo]];
    return [NetworkUtil createSecureAPI:kPackListAPIPath withParam:param];
}

/** @ghidraAddress 0x332a8 */
+ (NSURL *)packInfoURL:(unsigned int)packID UserOpen:(BOOL)userOpen {
    NSString *param;
    if (userOpen) {
        param = [NSString stringWithFormat:kPackInfoUserOpenParamFormat,
                                           GetRegionCode(),
                                           packID,
                                           [NetworkUtil userInfo]];
    } else {
        param = [NSString stringWithFormat:kPackInfoParamFormat, GetRegionCode(), packID];
    }
    return [NetworkUtil createSecureAPI:kPackInfoAPIPath withParam:param];
}

/** @ghidraAddress 0x33408 */
+ (NSURL *)musicInfoURL:(unsigned int)musicID {
    NSString *param = [NSString
        stringWithFormat:kMusicInfoParamFormat, GetRegionCode(), musicID, [NetworkUtil userInfo]];
    return [NetworkUtil createSecureAPI:kMusicInfoAPIPath withParam:param];
}

/** @ghidraAddress 0x33514 */
+ (NSURL *)receiptV3URL {
    return [NetworkUtil createSecureAPI:kReceiptV3APIPath withParam:nil];
}

/** @ghidraAddress 0x33534 */
+ (NSURL *)campaignListURL {
    return [NetworkUtil createSecureAPI:kCampaignListAPIPath withParam:nil];
}

/** @ghidraAddress 0x33554 */
+ (NSURL *)campaignSerialCheckURL {
    return [NetworkUtil createSecureAPI:kCampaignSerialCheckAPIPath withParam:nil];
}

/** @ghidraAddress 0x33574 */
+ (NSURL *)campaignItemInfoURL {
    return [NetworkUtil createSecureAPI:kCampaignItemInfoAPIPath withParam:nil];
}

/** @ghidraAddress 0x33594 */
+ (NSURL *)manageSortListURL {
    NSString *param = [NSString stringWithFormat:kManageSortListParamFormat, GetRegionCode()];
    return [NetworkUtil createSecureAPI:kManageSortListAPIPath withParam:param];
}

/** @ghidraAddress 0x3392c */
+ (NSURL *)userAgeURL {
    return [NetworkUtil createSecureAPI:kUserAgeAPIPath withParam:nil];
}

@end
