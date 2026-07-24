//
//  NetworkUtil.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class NetworkUtil). Verified against the
//  arm64 disassembly (the stringWithFormat: argument lists are variadic and dropped by the
//  decompiler).
//

#import "NetworkUtil.h"

#import "AppDelegate.h"
#import "RBUserSettingData.h"
#import "SystemHardware.h"
#import "neEngineBridge.h"

// The secure API endpoint scheme, host, and the common CGI base path every endpoint is built under.
static NSString *const kSecureAPIScheme = @"https";
static NSString *const kSecureAPIHost = @"akx.s.konaminet.jp";
static NSString *const kSecureAPIBasePath = @"/akx/main/cgi/";

// The APNs device-token registration endpoint, relative to the CGI base path.
static NSString *const kTokenSetAPIPath = @"push/token/";

// The searchable-spot campaign-master and list endpoints, relative to the CGI base path.
static NSString *const kSearchMasterAPIPath = @"search_master/";
static NSString *const kSearchListAPIPath = @"gamecenter/";

// The device user-info query and the searchable-spot master query format strings.
static NSString *const kUserInfoFormat = @"uuid=%@&version=%@&device=%@&os=%@&locale=%@";
static NSString *const kSearchMasterParamFormat = @"target=%@&%@";

// The unlock-catalogue-list and music-unlock query format strings.
static NSString *const kUnlockListParamFormat = @"target=%@&thema=%@";
static NSString *const kUnlockMusicParamFormat = @"target=%@&music=%d&key=%d";

// The CGI endpoint paths, relative to the CGI base path, of the remaining authenticated endpoints.
static NSString *const kPlayedV2APIPath = @"log/play/";
static NSString *const kUnlockListAPIPath = @"unlock/";
static NSString *const kUnlockMusicAPIPath = @"unlockmusic/";
static NSString *const kUnlockedAPIPath = @"unlocked/";
static NSString *const kTutorialAPIPath = @"tutorial/";
static NSString *const kStartupAPIPath = @"startup/";

// The startup / web-info query format string.
static NSString *const kStartupParamFormat = @"target=%@";
static NSString *const kResourceAPIPath = @"v3/ssl_resource/";
static NSString *const kTermListAPIPath = @"v3/terms/list/";
static NSString *const kTermFetchAPIPath = @"v3/terms/fetch/";
static NSString *const kTermAgreeAPIPath = @"v3/terms/log/";
static NSString *const kExtendNoteListAPIPath = @"v3/extmusiclist/";
static NSString *const kExtendNoteInfoAPIPath = @"v3/extmusicinfo/";

// The extend-note list and info query format strings. The list and the user-open info variant carry
// the device user-info parameters; the non-user-open info variant does not.
static NSString *const kExtendNoteListParamFormat = @"target=%@&head=%d&limit=%d&%@";
static NSString *const kExtendNoteInfoParamFormat = @"target=%@&extitem=%d";
static NSString *const kExtendNoteInfoUserOpenParamFormat = @"target=%@&extitem=%d&%@";

// The store pack/music/campaign and miscellaneous endpoint paths, relative to the CGI base path.
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

// The store pack/music query format strings. The user-open pack variant and the music query carry
// the device user-info parameters; the closed pack variant does not.
static NSString *const kLineMessageParamFormat = @"target=%@&%@";
static NSString *const kPackListParamFormat = @"target=%@&head=%d&limit=%d&genre=%d&%@";
static NSString *const kPackInfoParamFormat = @"target=%@&pack=%d";
static NSString *const kPackInfoUserOpenParamFormat = @"target=%@&pack=%d&%@";
static NSString *const kMusicInfoParamFormat = @"target=%@&music=%d&%@";
static NSString *const kManageSortListParamFormat = @"target=%@";

// The suffix appended to the device UUID key before hashing it into the request fingerprint.
static NSString *const kIdentifierKeySuffix = @"_STORE";

// The number of random characters a generated nonce holds per iteration and its formatting.
static NSString *const kNonceCharFormat = @"%c";

@interface NetworkUtil ()
// The common device fingerprint query appended to authenticated requests.
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
    // The fingerprint is computed once from the device UUID key with a fixed suffix and cached for
    // the lifetime of the process.
    static NSString *sIdentifierParams = nil;
    if (sIdentifierParams == nil) {
        NSString *seed = [[AppDelegate musicListKey] stringByAppendingString:kIdentifierKeySuffix];
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
    NSString *param =
        [NSString stringWithFormat:kUnlockMusicParamFormat, GetRegionCode(), musicID, randKey];
    return [NetworkUtil createSecureAPI:kUnlockMusicAPIPath withParam:param];
}

/**
 * The reward-check endpoint. The binary references this selector but ships no implementation for it,
 * so it resolves to @c nil at runtime; kept to match the declared interface.
 */
+ (NSURL *)rewardCheckURL {
    return nil;
}

/** @ghidraAddress 0x32610 */
+ (NSString *)createNonce:(int)length {
    if (length == 0) {
        return @"";
    }
    // Draw each character uniformly from the 62-character alphanumeric alphabet.
    static const char kNonceAlphabet[] =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    static const unsigned int kNonceAlphabetSize = 62;
    NSMutableString *nonce = [[NSMutableString alloc] initWithCapacity:length];
    for (int i = 0; i < length; ++i) {
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
    NSString *param =
        [NSString stringWithFormat:kLineMessageParamFormat, GetRegionCode(), [NetworkUtil userInfo]];
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
    NSString *param = [NSString stringWithFormat:kMusicInfoParamFormat,
                                                 GetRegionCode(),
                                                 musicID,
                                                 [NetworkUtil userInfo]];
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
