/** @file
 * Reconstructed interface for the Applilink reward SDK's private @c RewardCore singleton.
 *
 * @c RewardCore is the reward SDK's stateful core: a lazily-created (via @c dispatch_once)
 * singleton that owns the reward-advert session lifecycle. It drives the create-UDID,
 * post-install, get-installed, and web-view-presentation chain behind
 * @c openAdScreenWithParentView:adLocation:requestCode:delegate:, queries the all-install and
 * banner-display status through @c RewardWebAPI, hosts the reward advert inside a
 * @c RewardWebViewController, forwards the @c applilink://ext-app:80 redirect scheme, and reports
 * lifecycle and failure callbacks to its Applilink delegate through @c ApplilinkCore. The public
 * @c RewardNetwork facade forwards to @c [RewardCore sharedInstance]. Reconstructed from Ghidra
 * project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

@class ApplilinkParameters;
@class RewardWebViewController;
@protocol ApplilinkViewDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The reward SDK's stateful core singleton.
 */
@interface RewardCore : NSObject

/**
 * @brief The SDK initialisation flag: non-zero once the install record has been posted.
 *
 * The getter is overridden to return @c 0 whenever advertising tracking is disabled, regardless of
 * the stored value.
 * @ghidraAddress 0x207a80
 */
@property(nonatomic, assign) int initializeFlg;

/**
 * @brief Whether the reward advert screen hides its navigation bar.
 */
@property(nonatomic, assign) BOOL isNavigationBarHidden;

/**
 * @brief The hosted reward advert web-view controller, created lazily on first open.
 */
@property(nonatomic, strong, nullable) RewardWebViewController *rewardViewController;

/**
 * @brief The Applilink delegate that receives advert lifecycle and failure callbacks.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * @brief The request parameters for the advert currently being opened.
 */
@property(nonatomic, copy, nullable) ApplilinkParameters *applilinkParams;

/**
 * @brief The shared @c RewardCore instance (created with @c dispatch_once).
 * @return The shared instance.
 * @ghidraAddress 0x2079d0
 */
+ (instancetype)sharedInstance;

#pragma mark Session lifecycle

/**
 * @brief Clear the initialisation flag and forget the stored campaign flag.
 * @ghidraAddress 0x207acc
 */
- (void)clearInitialize;

/**
 * @brief The stored campaign flag for the current session.
 * @return The campaign flag, or @c -2 when tracking is off, the session is not initialised, or no
 * flag is stored.
 * @ghidraAddress 0x207b6c
 */
- (int)campaignFlg;

/**
 * @brief Create the device UDID, then post the application-install event, initialising the session.
 * @param callback The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x207c70
 */
- (void)startWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Ensure a valid reward authentication session, regenerating and re-logging in when needed.
 * @param block The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x20810c
 */
- (void)startSessionWithBlock:(nullable void (^)(NSError *_Nullable error))block;

/**
 * @brief Start the session (via @c startWithCallback:), refreshing the reward auth session first.
 * @param block The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x208624
 */
- (void)startWithBlock:(nullable void (^)(NSError *_Nullable error))block;

/**
 * @brief Create and persist the device UDID for the reward network.
 * @param block The completion block invoked with an error when creation fails.
 * @return @c YES when the UDID was created (or already present); @c NO when the block was invoked
 * with an error.
 * @ghidraAddress 0x208738
 */
- (BOOL)createUdidWithBlock:(nullable void (^)(NSError *_Nullable error))block;

/**
 * @brief Resolve, and persist to the keychain, the reward-network UDID for the stored storage index.
 * @param error On failure, set to the localised error; may be @c NULL.
 * @return @c YES on success.
 * @ghidraAddress 0x2088e0
 */
- (BOOL)createCFUdidWithError:(NSError *_Nullable *_Nullable)error;

#pragma mark Status queries

/**
 * @brief Query the all-install flag asynchronously.
 * @param callback The completion block, called with the all-install flag and an optional error.
 * @ghidraAddress 0x208bf0
 */
- (void)allInstallFlgWithCallback:(nullable void (^)(NSInteger flg,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Query the ad-display status asynchronously.
 * @param callback The completion block, called with the status dictionary and an optional error.
 * @ghidraAddress 0x208e48
 */
- (void)getAdDisplayStatusWithCallback:(nullable void (^)(NSDictionary *_Nullable status,
                                                          NSError *_Nullable error))callback;

/**
 * @brief Post the installed companion apps discovered on the device to the reward network.
 * @param callback The completion block, called with an error, or @c nil on success.
 * @ghidraAddress 0x209244
 */
- (void)postInstalledAppWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Query the full list of advertisable application identifiers.
 * @param callback The completion block, called with the identifier array and an optional error.
 * @ghidraAddress 0x209724
 */
- (void)getInstalledAppWithCallback:(nullable void (^)(NSArray *_Nullable appIdList,
                                                       NSError *_Nullable error))callback;

/**
 * @brief Query the app-list (reward-advert) status asynchronously.
 * @param block The completion block, called with the ad-status code and an optional error.
 * @ghidraAddress 0x209a90
 */
- (void)getAppListStatusWithBlock:(nullable void (^)(NSInteger status,
                                                     NSError *_Nullable error))block;

#pragma mark Advert screen

/**
 * @brief Open the reward-advert screen inside @p parentView at @p adLocation, reporting to
 * @p delegate.
 * @param parentView The view that hosts the advert screen.
 * @param adLocation The ad-location identifier.
 * @param requestCode The request code forwarded to the SDK.
 * @param delegate The advert-screen delegate.
 * @ghidraAddress 0x20a0dc
 */
- (void)openAdScreenWithParentView:(nullable UIView *)parentView
                        adLocation:(nullable NSString *)adLocation
                       requestCode:(nullable id)requestCode
                          delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Close the reward-advert screen.
 * @ghidraAddress 0x20ac1c
 */
- (void)closeAdScreen;

/**
 * @brief Rotate any open reward-advert screen to a new interface orientation.
 * @param interfaceOrientation The target @c UIInterfaceOrientation.
 * @param duration The animation duration.
 * @ghidraAddress 0x20accc
 */
- (void)rotateAdScreenWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                      duration:(NSTimeInterval)duration;

/**
 * @brief Handle an @c applilink://ext-app:80 redirect request from the reward web view.
 * @param request The intercepted @c NSURLRequest.
 * @return @c 1 when the request is not an Applilink redirect, @c 0 when it was consumed, @c 2 when
 * the target app could not be opened, or @c 3 when an app-store redirect was shown.
 * @ghidraAddress 0x20acf0
 */
- (int)redirectWithRequest:(nullable NSURLRequest *)request;

/**
 * @brief Set whether the reward advert screen hides its navigation bar.
 * @param navigationBarHidden @c YES to hide the navigation bar.
 * @ghidraAddress 0x20b62c
 */
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden;

#pragma mark Temporary cache

/**
 * @brief Store a value in @c NSUserDefaults under @p key with an expiry.
 * @param key The cache key.
 * @param value The value to store.
 * @param expiration The lifetime in seconds; @c 0 stores a one-second lifetime.
 * @ghidraAddress 0x20b63c
 */
- (void)setTemporaryCacheWithKey:(nullable NSString *)key
                           value:(nullable id)value
                      expiration:(NSInteger)expiration;

/**
 * @brief Read a cached value from @c NSUserDefaults, removing it when it has expired.
 * @param key The cache key.
 * @return The cached value, or @c nil when it is absent or expired.
 * @ghidraAddress 0x20b7f0
 */
- (nullable id)getTemporaryCacheWithKey:(nullable NSString *)key;

#pragma mark Delegate notifications

/**
 * @brief Report that the advert list started loading to the SDK delegate.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x20b9e4
 */
- (void)appListDidStart:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Report that the advert list appeared to the SDK delegate.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x20ba10
 */
- (void)appListDidAppear:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Report that the advert list disappeared to the SDK delegate.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x20ba3c
 */
- (void)appListDidDisappear:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Report a load failure to the SDK delegate.
 * @param error The load error.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x20ba68
 */
- (void)appListFailLoadWithError:(nullable NSError *)error
                        delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Report a link failure to the SDK delegate.
 * @param error The link error.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x20bacc
 */
- (void)appListFailLinkWithError:(nullable NSError *)error
                        delegate:(nullable id<ApplilinkViewDelegate>)delegate;

#pragma mark Web-view notices

/**
 * @brief Notify the stored delegate that the advert list started (called by the web view).
 * @ghidraAddress 0x20bb30
 */
- (void)startedNotice;

/**
 * @brief Notify the stored delegate that the advert list appeared (called by the web view).
 * @ghidraAddress 0x20bb7c
 */
- (void)openedNotice;

/**
 * @brief Tear down the advert web view and notify the delegate it disappeared.
 * @ghidraAddress 0x20bbc8
 */
- (void)closeNotice;

/**
 * @brief Notify the stored delegate of an advert open failure.
 * @param error The open error.
 * @ghidraAddress 0x20bc5c
 */
- (void)failOpenNoticeWithError:(nullable NSError *)error;

/**
 * @brief Notify the stored delegate of an advert link failure.
 * @param error The link error.
 * @ghidraAddress 0x20bccc
 */
- (void)failLinkNoticeWithError:(nullable NSError *)error;

/**
 * @brief Notice hook for an advert open cancellation. The shipped build ignores the argument.
 * @param error The cancellation error.
 * @ghidraAddress 0x20bd3c
 */
- (void)openCancelWithError:(nullable NSError *)error;

#pragma mark Cache and session teardown

/**
 * @brief Whether cached banner status may be used, clearing the cache when no UDID is available.
 * @return @c YES when any of the current, advertising, or old UDID is present.
 * @ghidraAddress 0x20bd40
 */
- (BOOL)canUseBannerCache;

/**
 * @brief Clear the cached banner-display status and its expiry.
 * @ghidraAddress 0x20be1c
 */
- (void)clearAdStatus;

/**
 * @brief Clear the reward session: delete every HTTP cookie and the stored session defaults.
 * @ghidraAddress 0x20be50
 */
- (void)clearSession;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
