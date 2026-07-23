/** @file
 * The Applilink recommend-network advert facade. A thin, class-method-only wrapper over the
 * Applilink recommend SDK (@c RecommendCore): every entry point first asks the SDK whether it may
 * run and then either forwards to the shared @c RecommendCore or reports a localised error back to
 * the caller.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RecommendNetwork, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base. The class has no
 * ivars, no properties, no adopted protocols, and a superclass of @c NSObject; its only instance
 * method is a compiler-generated @c dealloc that simply chains to @c NSObject, so under ARC it is
 * not reconstructed here.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The advert-model identifiers the facade requests from the SDK.
 *
 * These are the fixed @c adModel values baked into the parameterless convenience entry points; the
 * @c adModel-taking entry points forward whatever the caller supplies.
 */
typedef NS_ENUM(NSInteger, RecommendAdModel) {
    RecommendAdModelAppList = 1,      /*!< The companion-application list advert model. */
    RecommendAdModelInterstitial = 5, /*!< The full-screen interstitial advert model. */
    RecommendAdModelOwnAd = 100,      /*!< The first-party (own) advert model. */
};

/**
 * @brief The completion-block status/error callback for the advert-status queries.
 * @param status The SDK-reported status code, or @c 0 when the SDK is unavailable.
 * @param error A localised error when the SDK is unavailable, otherwise @c nil.
 */
typedef void (^RecommendAdStatusCallback)(NSInteger status, NSError *_Nullable error);

/**
 * @brief The completion-block callback for the advert-display-status query.
 * @param status A dictionary keyed by @c "unreadCount" and @c "bannerDisplayStatus", pre-filled
 * with zeroes when the SDK is unavailable.
 * @param error A localised error when the SDK is unavailable, otherwise @c nil.
 */
typedef void (^RecommendAdDisplayStatusCallback)(NSDictionary *_Nullable status,
                                                 NSError *_Nullable error);

/**
 * @brief The companion-application recommend-advert facade over the Applilink SDK.
 *
 * The advert area and screen report back through an informal delegate: the delegate implements
 * @c appListDidAppear, @c appListDidDisappear, and @c appListFailLoadWithError: as it needs them.
 */
@interface RecommendNetwork : NSObject

/**
 * @brief Query the companion-application-list status, forwarding as an @c RecommendAdModelAppList
 * advert-status query.
 * @param callback The status callback.
 * @ghidraAddress 0x211f20
 */
+ (void)getAppListStatusWithCallback:(nullable RecommendAdStatusCallback)callback;

/**
 * @brief Query the advert status for @p adModel asynchronously, on a global queue when the SDK is
 * usable, or synchronously with a localised error when it is not.
 * @param adModel The advert-model identifier.
 * @param callback The status callback.
 * @ghidraAddress 0x211f3c
 */
+ (void)getAdStatusWithAdModel:(RecommendAdModel)adModel
                      callback:(nullable RecommendAdStatusCallback)callback;

/**
 * @brief Query the unread advert count for @p adModel at @p adLocation.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier, such as @c "ADL_TOP".
 * @param callback The status callback, whose status argument carries the unread count.
 * @ghidraAddress 0x2120ac
 */
+ (void)getUnreadCountWithAdModel:(RecommendAdModel)adModel
                       adLocation:(nullable NSString *)adLocation
                         callback:(nullable RecommendAdStatusCallback)callback;

/**
 * @brief Query the advert-display status for @p adModel at @p adLocation.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier, such as @c "ADL_TOP".
 * @param callback The display-status callback.
 * @ghidraAddress 0x21228c
 */
+ (void)getAdDisplayStatusWithAdModel:(RecommendAdModel)adModel
                           adLocation:(nullable NSString *)adLocation
                             callback:(nullable RecommendAdDisplayStatusCallback)callback;

/**
 * @brief Show a first-party advert through the shared @c RecommendCore, when the SDK is usable.
 * @param adLocation The ad-location identifier.
 * @param appliId The advert application identifier.
 * @param creativeId The advert creative identifier.
 * @ghidraAddress 0x212540
 */
+ (void)showOwnAdWithAdLocation:(nullable NSString *)adLocation
                      toAppliId:(nullable NSString *)appliId
                     creativeId:(nullable NSString *)creativeId;

/**
 * @brief Register a first-party advert touch through the shared @c RecommendCore, when the SDK
 * approves the request.
 * @param adLocation The ad-location identifier.
 * @param appliId The advert application identifier.
 * @param creativeId The advert creative identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x212604
 */
+ (void)touchOwnAdWithAdLocation:(nullable NSString *)adLocation
                       toAppliId:(nullable NSString *)appliId
                      creativeId:(nullable NSString *)creativeId
                     requestCode:(NSInteger)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Open the companion-application list at @p adLocation with an implicit request code of
 * zero.
 * @param adLocation The ad-location identifier.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x21271c
 */
+ (void)openAppListWithAdLocation:(nullable NSString *)adLocation delegate:(nullable id)delegate;

/**
 * @brief Open the companion-application list at @p adLocation, reporting to @p delegate.
 * @param adLocation The ad-location identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x212774
 */
+ (void)openAppListWithAdLocation:(nullable NSString *)adLocation
                      requestCode:(NSInteger)requestCode
                         delegate:(nullable id)delegate;

/**
 * @brief Open the advert screen for @p adModel at @p adLocation with an implicit request code of
 * zero.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x212960
 */
+ (void)openAdScreenWithAdModel:(RecommendAdModel)adModel
                     adLocation:(nullable NSString *)adLocation
                       delegate:(nullable id)delegate;

/**
 * @brief Open the advert screen for @p adModel at @p adLocation, reporting to @p delegate.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x2129c0
 */
+ (void)openAdScreenWithAdModel:(RecommendAdModel)adModel
                     adLocation:(nullable NSString *)adLocation
                    requestCode:(NSInteger)requestCode
                       delegate:(nullable id)delegate;

/**
 * @brief Open the recommend-advert area inside @p parentView, filling @p rect, with an implicit
 * request code of zero.
 * @param parentView The view that hosts the advert area.
 * @param rect The advert area's frame within @p parentView.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier, such as @c "ADL_TOP".
 * @param verticalAlign The vertical-alignment identifier.
 * @param delegate The advert-area delegate.
 * @ghidraAddress 0x212bb0
 */
+ (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(RecommendAdModel)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                        delegate:(nullable id)delegate;

/**
 * @brief Open the recommend-advert area inside @p parentView, filling @p rect, reporting to
 * @p delegate.
 * @param parentView The view that hosts the advert area.
 * @param rect The advert area's frame within @p parentView.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier, such as @c "ADL_TOP".
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert-area delegate.
 * @ghidraAddress 0x212c6c
 */
+ (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(RecommendAdModel)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(NSInteger)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Open a full-screen interstitial at @p adLocation with an implicit request code of zero.
 * @param adLocation The ad-location identifier.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x212eb4
 */
+ (void)openInterstitialWithAdLocation:(nullable NSString *)adLocation
                              delegate:(nullable id)delegate;

/**
 * @brief Open a full-screen interstitial at @p adLocation, reporting to @p delegate.
 * @param adLocation The ad-location identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x212f0c
 */
+ (void)openInterstitialWithAdLocation:(nullable NSString *)adLocation
                           requestCode:(NSInteger)requestCode
                              delegate:(nullable id)delegate;

/**
 * @brief Close the advert screen hosted by the shared @c RecommendCore.
 * @ghidraAddress 0x2130f4
 */
+ (void)closeAdScreen;

/**
 * @brief Close the recommend-advert area hosted by @p parentView, sending @c closeAdArea to each
 * area view before removing every recommend subview.
 * @param parentView The view that hosts the advert area; when @c nil the SDK main window is used.
 * @ghidraAddress 0x21316c
 */
+ (void)closeAdAreaWithParentView:(nullable UIView *)parentView;

/**
 * @brief Hide or show the recommend-advert area subviews hosted by @p parentView.
 * @param parentView The view that hosts the advert area; when @c nil the SDK main window is used.
 * @param flag @c YES to make the area visible, @c NO to hide it.
 * @ghidraAddress 0x2133bc
 */
+ (void)setAdAreaVisibleWithParentView:(nullable UIView *)parentView flag:(BOOL)flag;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
