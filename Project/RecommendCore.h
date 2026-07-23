/** @file
 * Reconstructed interface for the Applilink recommend SDK's @c RecommendCore singleton.
 *
 * @c RecommendCore is KONAMI's Applilink recommend-advert controller: a shared instance that
 * regenerates the authentication session, queries advert status, unread counts, and display
 * status, presents the advert screen, advert area, and full-screen advert view controllers, and
 * registers first-party advert impressions and clicks. Every public entry point first regenerates
 * the recommend session (through @c ApplilinkCore and @c RecommendWebAPI) and then either forwards
 * to the network layer or reports a localised @c ApplilinkNetworkError. Reconstructed from Ghidra
 * project rb458, program rb458 (image base 0x100000000); @c \@ghidraAddress values are offsets
 * relative to that image base.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"

@class RecommendFullScreenController;
@class RecommendWebViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend SDK's shared advert controller.
 */
@interface RecommendCore : NSObject

/**
 * @brief Whether the recommend core has been initialised.
 * @ghidraAddress 0x236d14
 */
@property(nonatomic, assign) int initializeFlg;

/**
 * @brief The full-screen (interstitial) advert view controller currently presented, if any.
 * @ghidraAddress 0x23e698
 */
@property(nonatomic, strong, nullable) RecommendFullScreenController *interstitialViewController;

/**
 * @brief The advert-screen web view controller currently presented, if any.
 * @ghidraAddress 0x23e6e0
 */
@property(nonatomic, strong, nullable) RecommendWebViewController *adScreenViewController;

/**
 * @brief The delegate that receives Applilink advert-screen lifecycle callbacks.
 * @ghidraAddress 0x23e728
 */
@property(nonatomic, weak, nullable) id applilinkDelegate;

/**
 * @brief The advert-request parameters for the advert-screen presentation in flight.
 * @ghidraAddress 0x23e75c
 */
@property(nonatomic, copy, nullable) ApplilinkParameters *applilinkParams;

/**
 * @brief Whether the recommend session must be re-established before the next request.
 * @ghidraAddress 0x23e788
 */
@property(nonatomic, assign) BOOL reLoginStatus;

/**
 * @brief Whether the advert screen hides its navigation bar.
 * @ghidraAddress 0x23e7a8
 */
@property(nonatomic, assign) BOOL navigationBarHidden;

/**
 * @brief Whether the advert screen has already been closed, guarding a double close.
 * @ghidraAddress 0x23e7b8
 */
@property(nonatomic, assign) BOOL adScreenviewCloseFlg;

/**
 * @brief Whether a redirect (App Store or external application launch) is in flight.
 * @ghidraAddress 0x23e7d8
 */
@property(nonatomic, assign) BOOL redirectFlg;

/**
 * @brief The delegate that receives advert-area lifecycle callbacks.
 * @ghidraAddress 0x23e7f8
 */
@property(nonatomic, weak, nullable) id adAreaDelegate;

/**
 * @brief The delegate that receives advert-screen lifecycle callbacks.
 * @ghidraAddress 0x23e82c
 */
@property(nonatomic, weak, nullable) id adScreenDelegate;

/**
 * @brief The delegate that receives first-party advert (click) lifecycle callbacks.
 * @ghidraAddress 0x23e860
 */
@property(nonatomic, weak, nullable) id uniqueAdDelegate;

/**
 * @brief The advert-request parameters for the first-party advert click in flight.
 * @ghidraAddress 0x23e894
 */
@property(nonatomic, copy, nullable) ApplilinkParameters *uniqueApplilinkParams;

/**
 * @brief The shared recommend-core instance.
 * @return The singleton.
 * @ghidraAddress 0x236c64
 */
+ (instancetype)sharedInstance;

/**
 * @brief Whether the recommend core is fully initialised.
 * @return @c YES when @c initializeFlg equals one.
 * @ghidraAddress 0x236d24
 */
- (BOOL)isInitialized;

/**
 * @brief Reset the initialisation flag.
 * @ghidraAddress 0x236d3c
 */
- (void)clearInitialize;

/**
 * @brief Whether an application registered under @p scheme is installed on the device.
 * @param scheme The custom URL scheme to probe.
 * @return @c YES when the scheme can be opened.
 * @ghidraAddress 0x236d4c
 */
- (BOOL)isInstalledAppliWithScheme:(nullable NSString *)scheme;

/**
 * @brief Start the recommend SDK, posting the application install once per install.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x236e4c
 */
- (void)startWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Start a recommend session, calling @p callback when it completes.
 * @param callback The completion callback.
 * @ghidraAddress 0x237778
 */
- (void)startSessionWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch the installed-application list, gating the request on a fresh session.
 * @param callback The completion callback invoked with the list and an error.
 * @ghidraAddress 0x237bb0
 */
- (void)appliListWithCallBack:(nullable void (^)(id _Nullable list,
                                                 NSError *_Nullable error))callback;

/**
 * @brief Return the cached installed-application list, fetching it when absent.
 * @param callback The completion callback invoked with the list and an error.
 * @ghidraAddress 0x237cd0
 */
- (void)appliListCacheWithCallBack:(nullable void (^)(id _Nullable list,
                                                      NSError *_Nullable error))callback;

/**
 * @brief Query the advert status for @p adModel.
 * @param adModel The advert-model identifier.
 * @param callback The status callback.
 * @ghidraAddress 0x237d6c
 */
- (void)getAdStatusWithAdModel:(int)adModel
                      callback:
                          (nullable void (^)(NSInteger status, NSError *_Nullable error))callback;

/**
 * @brief Query the unread advert count for @p adModel at @p adLocation.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param callback The status callback.
 * @ghidraAddress 0x237fe4
 */
- (void)getUnreadCountWithAdModel:(int)adModel
                       adLocation:(nullable NSString *)adLocation
                         callback:(nullable void (^)(NSInteger status,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Query the advert-display status for @p adModel at @p adLocation.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param callback The display-status callback.
 * @ghidraAddress 0x238260
 */
- (void)getAdDisplayStatusWithAdModel:(int)adModel
                           adLocation:(nullable NSString *)adLocation
                             callback:(nullable void (^)(NSDictionary *_Nullable status,
                                                         NSError *_Nullable error))callback;

/**
 * @brief Query the advert status for every advert model.
 * @param callback The status callback.
 * @ghidraAddress 0x2385d8
 */
- (void)getAllAdStatusWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Clear every cached advert-data record.
 * @ghidraAddress 0x2387b8
 */
- (void)clearAllAdData;

/**
 * @brief Clear and re-fetch every cached advert-data record.
 * @ghidraAddress 0x2387d0
 */
- (void)reloadAllAdData;

/**
 * @brief Open the advert screen inside @p parentView.
 * @param parentView The view that hosts the advert screen.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x238848
 */
- (void)openAdScreenWithParentView:(nullable UIView *)parentView
                           adModel:(int)adModel
                        adLocation:(nullable NSString *)adLocation
                     verticalAlign:(int)verticalAlign
                       requestCode:(nullable id)requestCode
                          delegate:(nullable id)delegate;

/**
 * @brief Open the advert area inside @p parentView.
 * @param parentView The view that hosts the advert area.
 * @param rect The advert area's frame within @p parentView.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x239480
 */
- (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(int)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Open a full-screen advert view controller.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x239ed8
 */
- (void)openFullViewControllerWithAdModel:(int)adModel
                               adLocation:(nullable NSString *)adLocation
                            verticalAlign:(int)verticalAlign
                              requestCode:(nullable id)requestCode
                                 delegate:(nullable id)delegate;

/**
 * @brief Close the advert screen.
 * @ghidraAddress 0x23a40c
 */
- (void)closeAdScreen;

/**
 * @brief Rotate any open recommend-advert screen to a new interface orientation.
 * @param interfaceOrientation The target @c UIInterfaceOrientation.
 * @param duration The animation duration.
 * @ghidraAddress 0x23a5ac
 */
- (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                              duration:(NSTimeInterval)duration;

/**
 * @brief Handle an advert-screen redirect request using the current advert parameters.
 * @param request The redirect request.
 * @return The redirect outcome code.
 * @ghidraAddress 0x23a644
 */
- (int)redirectViewContollerWithRequest:(nullable NSURLRequest *)request;

/**
 * @brief Handle an advert-screen redirect request with no advert parameters.
 * @param request The redirect request.
 * @return The redirect outcome code.
 * @ghidraAddress 0x23a660
 */
- (int)redirectWithRequest:(nullable NSURLRequest *)request;

/**
 * @brief Handle an advert-screen redirect request, dispatching Applilink deep links.
 *
 * A URL under the @c applilink://ext-app:80 scheme is parsed into its ad identifier, country code,
 * category id, ad type, and store id, then either launched through an external application, opened
 * in the App Store, or forwarded to the advert screen. Ordinary URLs are handed back to the caller
 * to load.
 * @param request The redirect request; its URL may be rewritten in place.
 * @param appParam The advert parameters to report on failure, or @c nil.
 * @return The redirect outcome code.
 * @ghidraAddress 0x23a674
 */
- (int)redirectWithRequest:(nullable NSURLRequest *)request
                  appParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Return the cached banner status for @p adModel, expiring stale entries.
 * @param adModel The advert-model identifier.
 * @return The cached status object, or @c nil when absent or expired.
 * @ghidraAddress 0x23b420
 */
- (nullable id)getTemporaryCacheWithAdModel:(int)adModel;

/**
 * @brief Whether the banner cache may be used, clearing it when no UDID is available.
 * @return @c YES when at least one UDID is present.
 * @ghidraAddress 0x23b758
 */
- (BOOL)canUseBannerCache;

/**
 * @brief Clear the cached banner status.
 * @ghidraAddress 0x23b82c
 */
- (void)clearAdStatus;

/**
 * @brief Clear every stored HTTP cookie, ending the recommend session.
 * @ghidraAddress 0x23b8c0
 */
- (void)clearSession;

/**
 * @brief Clear recommend SDK data, except on the production environment.
 * @ghidraAddress 0x23ba24
 */
- (void)clearData;

/**
 * @brief Register an impression list for the displayed adverts.
 * @param adType The advert-type identifier.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param impressionId The impression identifier.
 * @ghidraAddress 0x23bb5c
 */
- (void)postAnalysisListRegistWithAdType:(int)adType
                                 AdModel:(int)adModel
                              adLocation:(nullable NSString *)adLocation
                            impressionId:(nullable NSString *)impressionId;

/**
 * @brief Show a first-party advert.
 * @param adLocation The ad-location identifier.
 * @param appliId The advert application identifier.
 * @param creativeId The advert creative identifier.
 * @ghidraAddress 0x23c11c
 */
- (void)showOwnAdWithAdLocation:(nullable NSString *)adLocation
                      toAppliId:(nullable NSString *)appliId
                     creativeId:(nullable NSString *)creativeId;

/**
 * @brief Register a first-party advert touch.
 * @param adLocation The ad-location identifier.
 * @param appliId The advert application identifier.
 * @param creativeId The advert creative identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x23c5fc
 */
- (void)touchOwnAdWithAdLocation:(nullable NSString *)adLocation
                       toAppliId:(nullable NSString *)appliId
                      creativeId:(nullable NSString *)creativeId
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Launch the click link action for a first-party advert.
 * @param defaultScheme The advert's default URL scheme.
 * @param adIdTo The destination advert identifier.
 * @param adType The advert-type string.
 * @param adModel The advert-model string.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x23d0dc
 */
- (void)linkActionWithDefaultScheme:(nullable NSString *)defaultScheme
                             adIdTo:(nullable NSString *)adIdTo
                             adType:(nullable NSString *)adType
                            adModel:(nullable NSString *)adModel
                           delegate:(nullable id)delegate;

/**
 * @brief Store, or clear, the unique-advert impression identifier for @p adLocation.
 * @param adLocation The ad-location identifier.
 * @param impressionId The impression identifier, or @c nil to clear it.
 * @ghidraAddress 0x23d330
 */
- (void)setUniqueAdWithAdLocation:(nullable NSString *)adLocation
                     impressionId:(nullable NSString *)impressionId;

/**
 * @brief Return the stored unique-advert impression identifier for @p adLocation.
 * @param adLocation The ad-location identifier.
 * @return The stored impression identifier, or @c nil.
 * @ghidraAddress 0x23d4cc
 */
- (nullable id)getUniqueAdWithAdLocation:(nullable NSString *)adLocation;

/**
 * @brief Report a load failure for the click link connection.
 * @param error The load error.
 * @ghidraAddress 0x23d5c0
 */
- (void)failLoadWithError:(nullable NSError *)error;

/**
 * @brief Report a load completion for the click link connection.
 * @param response The load response.
 * @ghidraAddress 0x23d740
 */
- (void)finishLoadWithResponse:(nullable id)response;

/**
 * @brief Handle a redirect while loading the click link connection.
 * @param request The redirect request.
 * @return Always @c NO; the redirect is handled internally.
 * @ghidraAddress 0x23d744
 */
- (BOOL)redirectStartLoad:(nullable NSURLRequest *)request;

/**
 * @brief Release the advert-screen view controller.
 * @ghidraAddress 0x23d7f8
 */
- (void)releaseAdScreenViewController;

/**
 * @brief Release the full-screen (interstitial) advert view controller.
 * @ghidraAddress 0x23d84c
 */
- (void)releaseInterstitialViewController;

/**
 * @brief Notify the delegate that the installed-application list started.
 * @ghidraAddress 0x23d8cc
 */
- (void)appListDidStart;

/**
 * @brief Notify the delegate that the installed-application list appeared.
 * @ghidraAddress 0x23d9d4
 */
- (void)appListDidAppear;

/**
 * @brief Notify the delegate that the installed-application list disappeared.
 * @ghidraAddress 0x23daf4
 */
- (void)appListDidDisappear;

/**
 * @brief Report an installed-application list open failure to the delegate.
 * @param error The open error.
 * @ghidraAddress 0x23dc50
 */
- (void)appListFailOpenWithError:(nullable NSError *)error;

/**
 * @brief Report an installed-application list load failure to the delegate.
 * @param error The load error.
 * @ghidraAddress 0x23ddf8
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief Report an installed-application list failure to the delegate.
 * @param error The failure error.
 * @ghidraAddress 0x23dfa0
 */
- (void)appListFailWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate that the advert started.
 * @ghidraAddress 0x23e148
 */
- (void)startedNotice;

/**
 * @brief Notify the delegate that the advert opened.
 * @ghidraAddress 0x23e1b0
 */
- (void)openedNotice;

/**
 * @brief Notify the delegate that the advert closed.
 * @ghidraAddress 0x23e250
 */
- (void)closeNotice;

/**
 * @brief Report an advert open failure to the delegate.
 * @param error The open error.
 * @ghidraAddress 0x23e300
 */
- (void)failOpenNoticeWithError:(nullable NSError *)error;

/**
 * @brief Report an advert link failure to the delegate.
 * @param error The link error.
 * @ghidraAddress 0x23e3d0
 */
- (void)failLinkNoticeWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate that the App Store advert opened.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x23e454
 */
- (void)appStoreOpenedNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Notify the delegate that the App Store advert is about to close.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x23e4dc
 */
- (void)appStoreCloseNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Notify the delegate that the App Store advert closed.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x23e4e0
 */
- (void)appStoreClosedNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Report an App Store advert load failure to the delegate.
 * @param error The load error.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x23e5ac
 */
- (void)appStoreFailLoadNoticeWithError:(nullable NSError *)error
                               appParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Notify the delegate that the App Store advert transitioned.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x23e684
 */
- (void)appStoreTransitionNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
