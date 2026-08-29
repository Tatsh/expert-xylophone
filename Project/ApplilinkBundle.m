#import "ApplilinkBundle.h"

#import "ApplilinkCore.h"

static NSString *const kResourceBundleName = @"ApplilinkNetworkResources";
static NSString *const kResourceBundleType = @"bundle";

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
