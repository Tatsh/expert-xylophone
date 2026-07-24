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
 * @brief The unlock-catalogue list endpoint.
 * @ghidraAddress 0x32f08
 */
+ (nullable NSURL *)unlockListURL;

/**
 * @brief The music-unlock endpoint for a given music id, echoing @p randKey to guard against a
 * stale response.
 * @param musicID The music identifier to unlock.
 * @param randKey The random key echoed back by the response.
 * @ghidraAddress 0x33058
 */
+ (nullable NSURL *)unlockMusicURL:(int)musicID randKey:(int)randKey;

/**
 * @brief The reward-check endpoint.
 */
+ (nullable NSURL *)rewardCheckURL;

/**
 * @brief Generate a random alphanumeric nonce of the given length.
 * @param length The number of characters to generate.
 * @return The generated nonce string.
 * @ghidraAddress 0x32610
 */
+ (nullable NSString *)createNonce:(int)length;

/**
 * @brief The startup / web-info endpoint (@c .../akx/main/cgi/startup/), carrying the region code.
 * @ghidraAddress 0x32ba0
 */
+ (nullable NSURL *)startupURL;

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

/**
 * @brief The searchable-spot campaign-master endpoint (@c .../akx/main/cgi/search_master/),
 * carrying the region code and the device user-info parameters.
 * @ghidraAddress 0x32dec
 */
+ (nullable NSURL *)searchMasterURL;

/**
 * @brief The searchable-spot list endpoint (@c .../akx/main/cgi/gamecenter/).
 * @ghidraAddress 0x32ee8
 */
+ (nullable NSURL *)searchURL;

/**
 * @brief The terms-of-service list endpoint.
 * @ghidraAddress 0x338cc
 */
+ (nullable NSURL *)termList;

/**
 * @brief The terms-of-service detail (single-term body) endpoint.
 * @ghidraAddress 0x338ec
 */
+ (nullable NSURL *)termFetch;

/**
 * @brief The terms-of-service acceptance endpoint.
 * @ghidraAddress 0x3390c
 */
+ (nullable NSURL *)termAgree;

/**
 * @brief Build the paged extend-note catalogue list endpoint URL, carrying the region code, the
 * device user-info parameters, and the requested page.
 * @param offset The one-based catalogue offset of the first item to fetch.
 * @param limit The maximum number of items to fetch.
 * @return The extend-note list endpoint URL.
 * @ghidraAddress 0x3365c
 */
+ (nullable NSURL *)extendNoteListURL:(unsigned int)offset limit:(unsigned int)limit;

/**
 * @brief Build the extend-note-detail info endpoint URL for an item, carrying the device user-info
 * parameters only for a user-initiated open.
 * @param extendNoteID The extend-note identifier.
 * @param userOpen Whether the request is on behalf of a user-initiated open.
 * @return The extend-note-detail info endpoint URL.
 * @ghidraAddress 0x3376c
 */
+ (nullable NSURL *)extendNoteInfoURL:(unsigned int)extendNoteID UserOpen:(BOOL)userOpen;

/**
 * @brief Build the LINE-message share endpoint URL, carrying the region and device user-info.
 * @return The LINE-message endpoint URL.
 * @ghidraAddress 0x32cb0
 */
+ (nullable NSURL *)lineMessageURL;

/**
 * @brief Build the store pack-list endpoint URL for a page of a genre.
 * @param head The first pack index of the page.
 * @param limit The maximum number of packs to return.
 * @param genre The genre filter.
 * @return The store pack-list endpoint URL.
 * @ghidraAddress 0x33188
 */
+ (nullable NSURL *)packListURL:(unsigned int)head
                          limit:(unsigned int)limit
                          genre:(unsigned int)genre;

/**
 * @brief Build the store pack-info endpoint URL for a pack, carrying the device user-info only for a
 * user-initiated open.
 * @param packID The pack identifier.
 * @param userOpen Whether the request is on behalf of a user-initiated open.
 * @return The store pack-info endpoint URL.
 * @ghidraAddress 0x332a8
 */
+ (nullable NSURL *)packInfoURL:(unsigned int)packID UserOpen:(BOOL)userOpen;

/**
 * @brief Build the store music-info endpoint URL for a tune, carrying the device user-info.
 * @param musicID The tune identifier.
 * @return The store music-info endpoint URL.
 * @ghidraAddress 0x33408
 */
+ (nullable NSURL *)musicInfoURL:(unsigned int)musicID;

/**
 * @brief Build the V3 receipt-verification endpoint URL.
 * @return The receipt-verification endpoint URL.
 * @ghidraAddress 0x33514
 */
+ (nullable NSURL *)receiptV3URL;

/**
 * @brief Build the campaign-list endpoint URL.
 * @return The campaign-list endpoint URL.
 * @ghidraAddress 0x33534
 */
+ (nullable NSURL *)campaignListURL;

/**
 * @brief Build the campaign serial-code verification endpoint URL.
 * @return The campaign serial-check endpoint URL.
 * @ghidraAddress 0x33554
 */
+ (nullable NSURL *)campaignSerialCheckURL;

/**
 * @brief Build the campaign item-info endpoint URL.
 * @return The campaign item-info endpoint URL.
 * @ghidraAddress 0x33574
 */
+ (nullable NSURL *)campaignItemInfoURL;

/**
 * @brief Build the store manage-sort-list endpoint URL, carrying the region.
 * @return The manage-sort-list endpoint URL.
 * @ghidraAddress 0x33594
 */
+ (nullable NSURL *)manageSortListURL;

/**
 * @brief Build the user-age registration endpoint URL.
 * @return The user-age endpoint URL.
 * @ghidraAddress 0x3392c
 */
+ (nullable NSURL *)userAgeURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
