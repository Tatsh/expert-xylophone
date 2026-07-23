#import "AnalysisNetwork.h"

#import "AnalysisNetworkCore.h"
#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"

// Forwarded to the caller's callback when the Applilink SDK may not be used in this environment.
static const NSInteger kApplilinkErrorSdkUnavailable = 0x401;

@implementation AnalysisNetwork

+ (void)postAnalysisDataWithResultId:(NSString *)resultId
                            callback:(void (^)(NSError *error))callback {
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        [AnalysisNetworkCore postAnalysisDataWithResultId:resultId callback:callback];
    } else {
        NSError *error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorSdkUnavailable];
        callback(error);
    }
}

@end
