/** @file
 * The Game Center wrapper singleton. It gates access to the GameKit APIs behind an availability
 * check (the @c GKLocalPlayer class must exist and the system version must be at least 4.1), then
 * authenticates the local player through @c -[GKLocalPlayer setAuthenticateHandler:]. Leaderboard
 * score submission is performed elsewhere (see the free function that builds a @c GKScore from the
 * total-score leaderboard identifier and reports it); this class owns only the availability gate
 * and the sign-in flow.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBGameKitManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Game Center wrapper singleton.
 */
@interface RBGameKitManager : NSObject

#pragma mark Singleton

/**
 * @brief The shared Game Center manager, created once on first use.
 * @ghidraAddress 0x202c30
 * @return The shared @c RBGameKitManager.
 */
+ (instancetype)sharedInstance;

#pragma mark Game Center

/**
 * @brief Whether the GameKit APIs are usable: the @c GKLocalPlayer class exists and the running
 *        system version is at least 4.1.
 * @ghidraAddress 0x202c98
 * @return @c YES when Game Center may be used.
 */
- (BOOL)isGameCenterAPIAvailable;
/**
 * @brief Authenticate the Game Center local player when Game Center is available and the player is
 *        not already authenticated, installing an authentication-completion handler.
 * @ghidraAddress 0x202d64
 */
- (void)loginGameCenter;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
