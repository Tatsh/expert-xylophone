/** @file
 * URL builders for the game's secure API host (@c https://akx.s.konaminet.jp): assembles request
 * paths under @c /akx/main/cgi/ and wraps them in an HTTPS @c NSURL.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class NetworkUtil, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Builders for secure (HTTPS) API endpoint URLs on the game server.
 */
@interface NetworkUtil : NSObject

/**
 * @brief Wrap an absolute server path in an @c https://akx.s.konaminet.jp URL.
 * @param path The absolute path (with leading slash), e.g. @c /akx/main/cgi/push/token/.
 * @return The composed HTTPS URL.
 * @ghidraAddress 0x329d0
 */
+ (nullable NSURL *)createSecureURL:(NSString *)path;

/**
 * @brief Build a secure API URL for a CGI endpoint under @c /akx/main/cgi/, optionally appending a
 * query string.
 * @param api The endpoint path relative to @c /akx/main/cgi/ (e.g. @c push/token/).
 * @param param The query string to append after @c ?, or @c nil for none.
 * @return The composed HTTPS URL.
 * @ghidraAddress 0x32a6c
 */
+ (nullable NSURL *)createSecureAPI:(NSString *)api withParam:(nullable NSString *)param;

/**
 * @brief The APNs device-token registration endpoint
 * (@c https://akx.s.konaminet.jp/akx/main/cgi/push/token/).
 * @return The token-registration URL.
 * @ghidraAddress 0x32c90
 */
+ (nullable NSURL *)tokenSetURL;

/**
 * @brief The device fingerprint parameter: the MD5 hex digest of the device UUID key with a fixed
 * suffix, computed once and cached.
 * @ghidraAddress 0x327b0
 */
+ (nullable NSString *)identifierParams;

/**
 * @brief The device model name reported alongside play logs.
 * @ghidraAddress 0x32740
 */
+ (nullable NSString *)deviceName;

/**
 * @brief The legacy play-log endpoint. Referenced by
 * @c +[RBServerAPIManager playedAPIWithMusicID:dif:]; the binary ships no implementation for it (the
 * version 2 endpoint superseded it).
 */
+ (nullable NSURL *)playedURL;

/**
 * @brief The version 2 play-log endpoint (@c .../akx/main/cgi/log/play/).
 * @ghidraAddress 0x32dac
 */
+ (nullable NSURL *)playedV2URL;

/**
 * @brief The unlock-report endpoint (@c .../akx/main/cgi/unlocked/).
 * @ghidraAddress 0x33168
 */
+ (nullable NSURL *)unlockedURL;

/**
 * @brief The tutorial-status endpoint (@c .../akx/main/cgi/tutorial/).
 * @ghidraAddress 0x32dcc
 */
+ (nullable NSURL *)tutorialStatusURL;

/**
 * @brief The downloadable-resource information endpoint (@c .../akx/main/cgi/v3/ssl_resource/).
 * @ghidraAddress 0x32c70
 */
+ (nullable NSURL *)resourceURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
