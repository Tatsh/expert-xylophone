/** @file
 * A singleton that fires the game's telemetry and progression calls at the secure API host. Each
 * class method builds a parameter dictionary (region, music, difficulty, score, unlock, or tutorial
 * fields), serialises it to a JSON or query body, wraps it in a @c Downloader aimed at the matching
 * @c NetworkUtil endpoint, retains the connection in a live-request array, and starts it with the
 * shared instance as its delegate. As that delegate it simply drops each connection from the array
 * once it finishes or fails.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBServerAPIManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

@class RBServerAPIManager;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Sends the game's server API calls (play logs, unlocks, and tutorial status) and owns their
 * in-flight @c Downloader connections.
 */
@interface RBServerAPIManager : NSObject <DownloaderDelegate>

/**
 * @brief The live @c Downloader connections started by the API calls, held until each completes.
 * @ghidraAddress 0x17dd3c (getter)
 * @ghidraAddress 0x17dd4c (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *httpArray;

/**
 * @brief The lazily-created shared manager.
 * @ghidraAddress 0x17ca08
 */
+ (instancetype)getInstance;

/**
 * @brief Post a play-log entry for a music selection and difficulty (legacy endpoint).
 * @ghidraAddress 0x17cac4
 */
+ (void)playedAPIWithMusicID:(unsigned int)musicID dif:(unsigned int)dif;

/**
 * @brief Post a detailed play-log entry (version 2) for a music selection, difficulty, and result.
 * @ghidraAddress 0x17ce50
 */
+ (void)playedV2APIWithMusicID:(unsigned int)musicID
                           dif:(unsigned int)dif
                          note:(unsigned int)note
                            jr:(unsigned int)jr
                         score:(unsigned int)score;

/**
 * @brief Report an unlock (type, identity, and point cost) to the server.
 * @ghidraAddress 0x17d484
 */
+ (void)unlockedAPIWithType:(unsigned int)type identity:(unsigned int)identity point:(float)point;

/**
 * @brief Report the current tutorial completion status to the server.
 * @ghidraAddress 0x17d860
 */
+ (void)tutorialAPI;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
