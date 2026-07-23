//
//  ApplilinkMessage.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ApplilinkMessage). This is a
//  plain Objective-C file: every collaborator is reached through ordinary message sends, with no
//  C++. The class is the Applilink SDK's localised-message helper. It maps a message key to its
//  localised string from the reward bundle's "Message" table, choosing a built-in English default
//  value per recognised key.
//

#import "ApplilinkMessage.h"

#import "ApplilinkBundle.h"

// The name of the localised-strings table looked up inside the reward bundle.
static NSString *const kApplilinkMessageStringsTable = @"Message";

// The two recognised message keys and their built-in English fallback values.
static NSString *const kAppListTitleKey = @"RewardNetworkAppListTitle";
static NSString *const kAppListTitleDefault = @"App List";
static NSString *const kAppListCloseButtonKey = @"RewardNetworkAppListCloseButton";
static NSString *const kAppListCloseButtonDefault = @"Close";

// Fallback value for any unrecognised key.
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
