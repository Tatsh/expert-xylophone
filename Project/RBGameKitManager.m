//
//  RBGameKitManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBGameKitManager). Verified
//  against the arm64 disassembly (the two completion-handler blocks and the weak capture of the
//  local player in -loginGameCenter are obscured by the decompiler).
//

#import "RBGameKitManager.h"

#import <GameKit/GameKit.h>
#import <UIKit/UIKit.h>

// The minimum system version the GameKit APIs are supported on. Compared as a string against
// -[UIDevice systemVersion].
// @ghidraAddress 0x3bf4b8 (the "4.1" literal)
static NSString *const kMinimumGameCenterSystemVersion = @"4.1";

// The class name probed with NSClassFromString to decide whether GameKit is present at all.
static NSString *const kGameCenterLocalPlayerClassName = @"GKLocalPlayer";

@implementation RBGameKitManager

#pragma mark Singleton

+ (instancetype)sharedInstance {
    // @ghidraAddress 0x1003df590 (g_pRBGameKitManagerShared, once token
    // g_nRBGameKitManagerSharedOnceToken at 0x1003df598)
    static RBGameKitManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /** @ghidraAddress 0x202c54 */
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark Game Center

- (BOOL)isGameCenterAPIAvailable {
    return NSClassFromString(kGameCenterLocalPlayerClassName) != nil &&
           [[UIDevice currentDevice].systemVersion compare:kMinimumGameCenterSystemVersion
                                                    options:NSNumericSearch] !=
               NSOrderedAscending;
}

- (void)loginGameCenter {
    if (![self isGameCenterAPIAvailable]) {
        return;
    }
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    if (localPlayer.isAuthenticated) {
        return;
    }
    __weak GKLocalPlayer *weakLocalPlayer = localPlayer;
    [localPlayer setAuthenticateHandler:^(NSError *error) {
        /** @ghidraAddress 0x202ea4 */
        if (error == nil) {
            (void)weakLocalPlayer.playerID;
        } else {
            (void)error.code;
        }
    }];
}

@end
