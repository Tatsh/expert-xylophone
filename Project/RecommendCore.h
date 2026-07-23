/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c RecommendCore singleton.
 *
 * The Applilink SDK ships as a closed third-party library, so only the singleton accessor, the
 * @c initializeFlg property, and the methods that @c RecommendNetwork forwards to are declared
 * here. Reconstructed from Ghidra project rb458, program rb458 (image base 0x100000000);
 * @c \@ghidraAddress values are offsets relative to that image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend SDK's shared advert controller.
 */
@interface RecommendCore : NSObject

/**
 * @brief Whether the recommend core has been initialised.
 * @ghidraAddress 0x236d14
 */
@property(nonatomic, assign, readonly) int initializeFlg;

/**
 * @brief The shared recommend-core instance.
 * @return The singleton.
 * @ghidraAddress 0x236c64
 */
+ (instancetype)sharedInstance;

/**
 * @brief Start a recommend session, calling @p callback when it completes.
 * @param callback The completion callback.
 * @ghidraAddress 0x237778
 */
- (void)startSessionWithCallback:(nullable void (^)(void))callback;

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
 * @ghidraAddress 0x238848
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
 * @ghidraAddress 0x239480
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
 * @ghidraAddress 0x239ed8
 */
- (void)openFullViewControllerWithAdModel:(int)adModel
                               adLocation:(nullable NSString *)adLocation
                            verticalAlign:(int)verticalAlign
                              requestCode:(NSInteger)requestCode
                                 delegate:(nullable id)delegate;

/**
 * @brief Close the advert screen.
 * @ghidraAddress 0x23a40c
 */
- (void)closeAdScreen;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
