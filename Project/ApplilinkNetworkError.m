//
//  ApplilinkNetworkError.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ApplilinkNetworkError). This is a
//  plain Objective-C file: every collaborator is reached through ordinary message sends, with no
//  C++. The class is the Applilink SDK's NSError factory. It caches, on first use, a dictionary
//  that maps each Applilink error code to a localised message, then builds an NSError whose
//  userInfo carries that message under NSLocalizedDescriptionKey.
//
//  ApplilinkBundle is an SDK-private collaborator that is not itself reconstructed here, so its one
//  messaged class method is forward-declared below rather than imported from a header.
//

#import "ApplilinkNetworkError.h"

// The Applilink SDK's private resource bundle. Only +rewardBundle is messaged here; the bundle is
// used to look up localised strings in its "Error" table. When the bundle is missing the factory
// falls back to the built-in English messages.
@interface ApplilinkBundle : NSObject
+ (nullable NSBundle *)rewardBundle;
@end

/** @ghidraAddress 0x344791 */
NSErrorDomain const ApplilinkErrorDomain = @"ApplilinkErrorDomain";

// The name of the localised-strings table looked up inside the reward bundle.
static NSString *const kApplilinkErrorStringsTable = @"Error";

// The Applilink error codes, in the order the message table is populated. The unexpected-error code
// doubles as the fallback for any code that is not present in the table.
enum {
    kApplilinkErrorCodeUnexpected = 1000,
    kApplilinkErrorCodeParameter = 1001,
    kApplilinkErrorCodeAuthLogin = 1002,
    kApplilinkErrorCodeResponseEmpty = 1003,
    kApplilinkErrorCodeLoginTokenGetFailed = 1004,
    kApplilinkErrorCodeLoginTokenRequestError = 1005,
    kApplilinkErrorCodeContentsServer = 1006,
    kApplilinkErrorCodeInvalidContentsServerStatus = 1007,
    kApplilinkErrorCodeApplicationInstall = 1008,
    kApplilinkErrorCodeApplicationNotFound = 1009,
    kApplilinkErrorCodeNeedToInitialize = 1010,
    kApplilinkErrorCodePasteBoardStorageFull = 1011,
    kApplilinkErrorCodePasteBoardEmptyValue = 1012,
    kApplilinkErrorCodePasteBoardInvalidField = 1013,
    kApplilinkErrorCodePasteBoardUnarchiveFailed = 1014,
    kApplilinkErrorCodePasteBoardWriteFailed = 1015,
    kApplilinkErrorCodePasteBoardValidateError = 1016,
    kApplilinkErrorCodePasteBoardInvalidKey = 1017,
    kApplilinkErrorCodePasteBoardInvalidDataType = 1018,
    kApplilinkErrorCodePasteBoardInvalidFormat = 1019,
    kApplilinkErrorCodePasteBoardInvalidValue = 1020,
    kApplilinkErrorCodePasteBoardInvalidEntryDate = 1021,
    kApplilinkErrorCodePasteBoardInvalidLastAccess = 1022,
    kApplilinkErrorCodePasteBoardInvalidVersion = 1023,
    kApplilinkErrorCodePasteBoardOldVersion = 1024,
    kApplilinkErrorCodeSdkVersionNotSupported = 1025,
    kApplilinkErrorCodeUdidNotFound = 1026,
    kApplilinkErrorCodeHTTPRequestTimeout = 1027,
    kApplilinkErrorCodeCannotGetAdvertisingId = 1028,
    kApplilinkErrorCodeAppliIdNotFound = 1029,
    kApplilinkErrorCodeUserIdNotFound = 1030,
    kApplilinkErrorCodeResponseError = 1031,
    kApplilinkErrorCodeInitializingError = 1032,
    kApplilinkErrorCodeResumeExecutingError = 1033,
    kApplilinkErrorCodeNoAdContent = 1034,
    kApplilinkErrorCodeCannotOpenAdvertisement = 1035,
    kApplilinkErrorCodeOpenedCancel = 1036,
    kApplilinkErrorCodeBannerIsOff = 1037,
    kApplilinkErrorCodeSession = 1038,
    kApplilinkErrorCodeCannotOpenMultiple = 1039,
};

// One row of the message table: the Applilink error code, the reward bundle's localisation key, and
// the built-in English fallback used both as the localisation default value and when the bundle is
// absent.
typedef struct {
    NSInteger code;
    __unsafe_unretained NSString *localizationKey;
    __unsafe_unretained NSString *fallbackMessage;
} ApplilinkErrorMessageEntry;

static const ApplilinkErrorMessageEntry kApplilinkErrorMessages[] = {
    {kApplilinkErrorCodeUnexpected, @"ApplilinkUnexpectedError", @"Unexpected error."},
    {kApplilinkErrorCodeParameter, @"ApplilinkParameterError", @"Parameter error."},
    {kApplilinkErrorCodeAuthLogin, @"ApplilinkAuthLoginError", @"Failed to log in."},
    {kApplilinkErrorCodeResponseEmpty, @"ApplilinkErrorResponseEmpty", @"Response empty."},
    {kApplilinkErrorCodeLoginTokenGetFailed,
     @"ApplilinkErrorLoginTokenGetFailed",
     @"Failed to get login token."},
    {kApplilinkErrorCodeLoginTokenRequestError,
     @"ApplilinkErrorLoginTokenRequestError",
     @"Login token request unexpected error."},
    {kApplilinkErrorCodeContentsServer,
     @"ApplilinkErrorContentsServer",
     @"Contents server error occurred."},
    {kApplilinkErrorCodeInvalidContentsServerStatus,
     @"ApplilinkInvalidContentsServerStatus",
     @"Invalid response status from contents server."},
    {kApplilinkErrorCodeApplicationInstall,
     @"ApplilinkErrorApplicationInstall",
     @"Failed to notify application install."},
    {kApplilinkErrorCodeApplicationNotFound,
     @"ApplilinkErrorApplicationNotFound",
     @"Application not found."},
    {kApplilinkErrorCodeNeedToInitialize, @"ApplilinkErrorNeedToInitialize", @"Need to initilize."},
    {kApplilinkErrorCodePasteBoardStorageFull,
     @"ApplilinkPasteBoardErrorStorageFull",
     @"Storage is full."},
    {kApplilinkErrorCodePasteBoardEmptyValue,
     @"ApplilinkPasteBoardErrorEmptyValue",
     @"Not found key."},
    {kApplilinkErrorCodePasteBoardInvalidField,
     @"ApplilinkPasteBoardErrorInvalidField",
     @"Failed to get paste board index pointer."},
    {kApplilinkErrorCodePasteBoardUnarchiveFailed,
     @"ApplilinkPasteBoardErrorUnarchiveFailed",
     @"Failed to un-archive paste board data"},
    {kApplilinkErrorCodePasteBoardWriteFailed,
     @"ApplilinkPasteBoardErrorWriteFailed",
     @"Failed to write paste board data."},
    {kApplilinkErrorCodePasteBoardValidateError,
     @"ApplilinkPasteBoardErrorValidateError",
     @"Validate error."},
    {kApplilinkErrorCodePasteBoardInvalidKey,
     @"ApplilinkPasteBoardErrorInvalidKey",
     @"Invalid paste board key."},
    {kApplilinkErrorCodePasteBoardInvalidDataType,
     @"ApplilinkPasteBoardErrorInvalidDataType",
     @"Failed to get directed paste board data type."},
    {kApplilinkErrorCodePasteBoardInvalidFormat,
     @"ApplilinkPasteBoardErrorInvalidFormat",
     @"Invalid data format."},
    {kApplilinkErrorCodePasteBoardInvalidValue,
     @"ApplilinkPasteBoardErrorInvalidValue",
     @"Invalid value data."},
    {kApplilinkErrorCodePasteBoardInvalidEntryDate,
     @"ApplilinkPasteBoardErrorInvalidEntryDate",
     @"Invalid entry_date data."},
    {kApplilinkErrorCodePasteBoardInvalidLastAccess,
     @"ApplilinkPasteBoardErrorInvalidLastAccess",
     @"Invalid last_access data."},
    {kApplilinkErrorCodePasteBoardInvalidVersion,
     @"ApplilinkPasteBoardErrorInvalidVersion",
     @"Invalid version data."},
    {kApplilinkErrorCodePasteBoardOldVersion,
     @"ApplilinkPasteBoardErrorOldVersion",
     @"Old system version."},
    {kApplilinkErrorCodeSdkVersionNotSupported,
     @"ApplilinkErrorSdkVersionNotSupported",
     @"Reward SDK is supported in iOS 6.1 and later."},
    {kApplilinkErrorCodeUdidNotFound,
     @"ApplilinkErrorUdidNotFound",
     @"Udid not found. Please restart application."},
    {kApplilinkErrorCodeHTTPRequestTimeout,
     @"ApplilinkErrorHTTPRequestTimeout",
     @"HTTP Request timeout."},
    {kApplilinkErrorCodeCannotGetAdvertisingId,
     @"ApplilinkErrorCannotGetAdvertisingId",
     @"Cannot get Advertising Identifier."},
    {kApplilinkErrorCodeAppliIdNotFound, @"ApplilinkErrorAppliIdNotFound", @"AppId Not Found."},
    {kApplilinkErrorCodeUserIdNotFound, @"ApplilinkErrorUserIdNotFound", @"UserId Not Found."},
    {kApplilinkErrorCodeResponseError, @"ApplilinkErrorResponseError", @"Response Error."},
    {kApplilinkErrorCodeInitializingError,
     @"ApplilinkErrorInitializingError",
     @"Initializing Error."},
    {kApplilinkErrorCodeResumeExecutingError,
     @"ApplilinkErrorResumeExecutingError",
     @"Resume executing Error."},
    {kApplilinkErrorCodeNoAdContent, @"ApplilinkErrorNoAdContent", @"No Ad Content."},
    {kApplilinkErrorCodeCannotOpenAdvertisement,
     @"ApplilinkErrorCannotOpenAdvertisement",
     @"can not open advertisement."},
    {kApplilinkErrorCodeOpenedCancel, @"ApplilinkErrorOpenedCancel", @"Opened Cancel."},
    {kApplilinkErrorCodeBannerIsOff, @"ApplilinkErrorBannerIsOff", @"Banner is off."},
    {kApplilinkErrorCodeSession, @"ApplilinkSessionError", @"Session error."},
    {kApplilinkErrorCodeCannotOpenMultiple,
     @"ApplilinkErrorCannotOpenMultiple",
     @"can not open multiple."},
};

// The cached code-to-message dictionary, built once on the first factory call and reused
// thereafter. This mirrors the binary's file-scope global at 0x3df628.
static NSMutableDictionary *gApplilinkErrorMessages = nil;

@implementation ApplilinkNetworkError

+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code {
    return [self localizedApplilinkErrorWithCode:code userInfo:nil];
}

+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code
                                    userInfo:(nullable NSDictionary *)userInfo {
    if (gApplilinkErrorMessages == nil) {
        gApplilinkErrorMessages = [[NSMutableDictionary alloc] init];
        NSBundle *bundle = [ApplilinkBundle rewardBundle];
        for (size_t i = 0; i < sizeof(kApplilinkErrorMessages) / sizeof(kApplilinkErrorMessages[0]);
             ++i) {
            const ApplilinkErrorMessageEntry *entry = &kApplilinkErrorMessages[i];
            NSString *message = entry->fallbackMessage;
            if (bundle != nil) {
                message = [bundle localizedStringForKey:entry->localizationKey
                                                  value:entry->fallbackMessage
                                                  table:kApplilinkErrorStringsTable];
            }
            gApplilinkErrorMessages[@(entry->code)] = message;
        }
    }
    NSMutableDictionary *mergedUserInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
    if (gApplilinkErrorMessages != nil) {
        // The lookup keys the code as a 32-bit int number and falls back to the unexpected-error
        // message when the requested code is absent.
        NSString *message = gApplilinkErrorMessages[@((int)code)];
        if (message == nil) {
            message = gApplilinkErrorMessages[@((int)kApplilinkErrorCodeUnexpected)];
        }
        if (message != nil) {
            mergedUserInfo[NSLocalizedDescriptionKey] = message;
        }
    }
    return [NSError errorWithDomain:ApplilinkErrorDomain code:code userInfo:mergedUserInfo];
}

@end
