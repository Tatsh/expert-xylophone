//
//  ApplilinkBundle.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ApplilinkBundle). This is a plain
//  Objective-C file: its only collaborator, ApplilinkCore, is reached through an ordinary class
//  message send, with no C++.
//
//  The class has no instance state. Its single accessor lazily loads and caches the SDK's
//  ApplilinkNetworkResources.bundle, preferring the device-language .lproj sub-bundle when
//  ApplilinkCore prioritises the device languages.
//

#import "ApplilinkBundle.h"

#import "ApplilinkCore.h"

// The name and type of the SDK's localised resource bundle inside the main bundle.
static NSString *const kResourceBundleName = @"ApplilinkNetworkResources";
static NSString *const kResourceBundleType = @"bundle";

// The format that builds the localised sub-bundle path from the resource path and language code.
static NSString *const kLocalizedBundlePathFormat = @"%@/%@.lproj";

@implementation ApplilinkBundle

/** @ghidraAddress 0x20d41c */
+ (NSBundle *)rewardBundle {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /** @ghidraAddress 0x20d460 */
        NSString *path = [[NSBundle mainBundle] pathForResource:kResourceBundleName
                                                         ofType:kResourceBundleType];
        if (path.length == 0) {
            return;
        }
        if ([ApplilinkCore isPriorityDeviceLanguages]) {
            NSString *language = [NSLocale preferredLanguages][0];
            NSString *localizedPath =
                [NSString stringWithFormat:kLocalizedBundlePathFormat, path, language];
            bundle = [NSBundle bundleWithPath:localizedPath];
        }
        if (bundle == nil) {
            bundle = [[NSBundle alloc] initWithPath:path];
        }
        if (bundle == nil) {
            NSLog(@"ApplilinkNetworkResources could not be found.");
        }
    });
    return bundle;
}

@end
