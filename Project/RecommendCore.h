/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendCore singleton.
 *
 * The Applilink SDK ships as a closed third-party library, so only the singleton accessor, the
 * @c initializeFlg property, and the methods that @c RecommendNetwork forwards to are declared
 * here. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend SDK's shared advert controller.
 */
@interface RecommendCore : NSObject

/**
 * @brief Whether the recommend core has been initialised.
 */
@property(nonatomic, assign, readonly) int initializeFlg;

/**
 * @brief The shared recommend-core instance.
 * @return The singleton.
 */
+ (instancetype)sharedInstance;

/**
 * @brief Query the advert status for @p adModel.
 * @param adModel The advert-model identifier.
 * @param callback The status callback.
 */
- (void)getAdStatusWithAdModel:(int)adModel
                      callback:
                          (nullable void (^)(NSInteger status, NSError *_Nullable error))callback;

/**
 * @brief Query the unread advert count for @p adModel at @p adLocation.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param callback The status callback.
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
 */
- (void)getAdDisplayStatusWithAdModel:(int)adModel
                           adLocation:(nullable NSString *)adLocation
                             callback:(nullable void (^)(NSDictionary *_Nullable status,
                                                         NSError *_Nullable error))callback;

/**
 * @brief Show a first-party advert.
 * @param adLocation The ad-location identifier.
 * @param appliId The advert application identifier.
 * @param creativeId The advert creative identifier.
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
 */
- (void)touchOwnAdWithAdLocation:(nullable NSString *)adLocation
                       toAppliId:(nullable NSString *)appliId
                      creativeId:(nullable NSString *)creativeId
                     requestCode:(NSInteger)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Open the advert screen inside @p parentView.
 * @param parentView The view that hosts the advert screen.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 */
- (void)openAdScreenWithParentView:(nullable UIView *)parentView
                           adModel:(int)adModel
                        adLocation:(nullable NSString *)adLocation
                     verticalAlign:(int)verticalAlign
                       requestCode:(NSInteger)requestCode
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
 */
- (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(int)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(NSInteger)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Open a full-screen advert view controller.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 */
- (void)openFullViewControllerWithAdModel:(int)adModel
                               adLocation:(nullable NSString *)adLocation
                            verticalAlign:(int)verticalAlign
                              requestCode:(NSInteger)requestCode
                                 delegate:(nullable id)delegate;

/**
 * @brief Close the advert screen.
 */
- (void)closeAdScreen;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
