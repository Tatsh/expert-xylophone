#import "ApplilinkMessage.h"

#import "ApplilinkBundle.h"

static NSString *const kApplilinkMessageStringsTable = @"Message";

static NSString *const kAppListTitleKey = @"RewardNetworkAppListTitle";
static NSString *const kAppListTitleDefault = @"App List";
static NSString *const kAppListCloseButtonKey = @"RewardNetworkAppListCloseButton";
static NSString *const kAppListCloseButtonDefault = @"Close";

static NSString *const kEmptyDefault = @"";

@implementation ApplilinkMessage

+ (NSString *)localizedMessage:(NSString *)localizedMessage {
    NSBundle *bundle = [ApplilinkBundle rewardBundle];
    NSString *defaultValue;
    if ([localizedMessage isEqualToString:kAppListTitleKey]) {
        defaultValue = kAppListTitleDefault;
    } else if ([localizedMessage isEqualToString:kAppListCloseButtonKey]) {
        defaultValue = kAppListCloseButtonDefault;
    } else {
        defaultValue = kEmptyDefault;
    }
    return [bundle localizedStringForKey:localizedMessage
                                   value:defaultValue
                                   table:kApplilinkMessageStringsTable];
}

@end
