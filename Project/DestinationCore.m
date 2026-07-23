#import "DestinationCore.h"

#import <Foundation/Foundation.h>

#import "ApplilinkConsts.h"
#import "ApplilinkURLConnection.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkWebAPI.h"

// Request timeout, in seconds, for the destination registration.
static const float kDestinationRequestTimeout = 10.0f;

// Request parameter keys and the system marker value.
static NSString *const kDestinationParamSystem = @"system";
static NSString *const kDestinationParamCountryCode = @"country_code";
static NSString *const kDestinationParamRturl = @"rturl";
static NSString *const kDestinationSystemValueAd = @"ad";

// HTTP method and endpoint path for the destination registration.
static NSString *const kDestinationHTTPMethod = @"GET";
static NSString *const kDestinationPath = @"/destination/regist.php";

@implementation DestinationCore

+ (void)destinationRegistWithCountryCode:(NSString *)countryCode
                                     url:(NSString *)url
                                delegate:(id)delegate {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:3];
    [parameters setValue:kDestinationSystemValueAd forKey:kDestinationParamSystem];
    [parameters setValue:countryCode forKey:kDestinationParamCountryCode];
    [parameters setValue:url forKey:kDestinationParamRturl];
    NSDictionary *joinedParameters =
        [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    ApplilinkWebAPI *webAPI = [[ApplilinkWebAPI alloc] init];
    NSString *requestURL = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kDestinationPath];
    NSMutableURLRequest *request = [webAPI requestWithURL:requestURL
                                                  method:kDestinationHTTPMethod
                                              parameters:joinedParameters
                                                 timeout:kDestinationRequestTimeout
                                             cachePolicy:nil];
    ApplilinkURLConnection *connection = [[ApplilinkURLConnection alloc] init];
    // The class object itself is the connection delegate; the delegate argument is ignored.
    [connection loadRequestWithRequest:request delegate:(id)self];
}

#pragma mark - ApplilinkURLConnectionDelegate

+ (void)failLoadWithError:(NSError *)error {
}

+ (void)finishLoadWithResponse:(NSString *)response {
}

+ (BOOL)redirectStartLoad:(NSURLRequest *)request {
    return NO;
}

@end
