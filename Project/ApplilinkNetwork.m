//
//  ApplilinkNetwork.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ApplilinkNetwork). This is a plain
//  Objective-C file: it is the SDK's public umbrella class, and every collaborator (ApplilinkConsts,
//  ApplilinkCore, RewardCore, and RecommendCore) is reached through ordinary class-method message
//  sends, with no C++.
//
//  The class has no instance state; every member is a thin class-method facade that forwards to an
//  internal SDK collaborator.
//

#import "ApplilinkNetwork.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "RecommendCore.h"
#import "RewardCore.h"

@implementation ApplilinkNetwork

#pragma mark Lifecycle

/** @ghidraAddress 0x248464 */
+ (void)initializeWithAppliId:(NSString *)appliId
                          env:(NSString *)env
                     callback:(void (^)(NSError *_Nullable error))callback {
    [ApplilinkCore initializeWithAppliId:appliId env:env resume:NO callback:callback];
}

/** @ghidraAddress 0x2484d8 */
+ (void)resume {
    [ApplilinkCore resume];
}

#pragma mark Configuration

/** @ghidraAddress 0x2484f0 */
+ (void)setUserId:(NSString *)userId {
    [ApplilinkConsts setUserId:userId];
}

/** @ghidraAddress 0x248508 */
+ (void)setNavigationBarCommonAppearance:(BOOL)navigationBarCommonAppearance {
    [ApplilinkCore setNavigationBarCommonAppearance:navigationBarCommonAppearance];
}

/** @ghidraAddress 0x248520 */
+ (void)setPriorityDeviceLanguages:(BOOL)priorityDeviceLanguages {
    [ApplilinkCore setPriorityDeviceLanguages:priorityDeviceLanguages];
}

/** @ghidraAddress 0x248538 */
+ (void)setIndicatorColor:(UIColor *)indicatorColor {
    [ApplilinkCore setIndicatorColor:indicatorColor];
}

/** @ghidraAddress 0x248550 */
+ (void)unusedInStore {
    [ApplilinkCore unusedInStore];
}

/** @ghidraAddress 0x248568 */
+ (void)buildUnderXcode6 {
    [ApplilinkCore buildUnderXcode6];
}

#pragma mark Identifiers and version

/** @ghidraAddress 0x248580 */
+ (NSString *)appliId {
    return [ApplilinkConsts appliId];
}

/** @ghidraAddress 0x248598 */
+ (NSString *)version {
    return [ApplilinkConsts version];
}

/** @ghidraAddress 0x2485b0 */
+ (NSString *)versionDev {
    return [ApplilinkCore versionDev];
}

/** @ghidraAddress 0x2485c8 */
+ (BOOL)isSupportediOSVersion {
    return [ApplilinkConsts canUseApplilinkSdk];
}

/** @ghidraAddress 0x2485e0 */
+ (NSString *)currentUdid {
    return [ApplilinkCore currentUdid];
}

#pragma mark Rotation

/** @ghidraAddress 0x2485f8 */
+ (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                              duration:(NSTimeInterval)duration {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return;
    }
    [[RewardCore sharedInstance] rotateAdScreenWithInterfaceOrientation:interfaceOrientation
                                                               duration:duration];
    [[RecommendCore sharedInstance] rotateWithInterfaceOrientation:interfaceOrientation
                                                          duration:duration];
}

@end
