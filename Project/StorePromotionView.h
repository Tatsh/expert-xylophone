/** @file
 * The rotating store promotion banner and the delegate protocol it uses to report a pack tap. This
 * is a minimal stub declaring only the surface @c RBStorePageViewController relies on; the full view
 * class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePromotionView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePromotionView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Tap callbacks a @c StorePromotionView sends to its delegate.
 */
@protocol StorePromotionViewDelegate <NSObject>

@optional

/**
 * @brief Sent when a promotion banner naming a pack is tapped.
 * @param promotionView The tapped promotion view.
 * @param packId The pack identifier the banner names, or a negative value when none.
 */
- (void)storePromotionViewTaped:(StorePromotionView *)promotionView PackID:(int)packId;

@end

/**
 * @brief The rotating store promotion banner shown above the pack list.
 */
@interface StorePromotionView : UIView

/**
 * @brief The delegate notified of banner taps.
 */
@property(nonatomic, weak, nullable) id<StorePromotionViewDelegate> delegate;

/**
 * @brief Whether tapping the sample control starts sample playback.
 */
@property(nonatomic, assign) BOOL isSamplePlayable;

/**
 * @brief Start the banner rotation animation.
 */
- (void)startAnimation;

/**
 * @brief Stop the banner rotation animation.
 */
- (void)stopAnimation;

/**
 * @brief Start playing the current banner's sample tune.
 */
- (void)startSamplePlay;

/**
 * @brief Stop sample playback.
 */
- (void)stopSamplePlay;

/**
 * @brief Set the banner image URLs to rotate through.
 * @param imageURLs The banner image URL strings.
 */
- (void)setImageURLs:(nullable NSArray<NSString *> *)imageURLs;

/**
 * @brief React to an interface rotation with the new view width.
 * @param width The new view width.
 */
- (void)scrollViewDidRotate:(float)width;

/**
 * @brief The pack identifier the current banner names.
 * @return The pack identifier.
 */
- (int)getPackID;

/**
 * @brief Cancel the banner, tearing down its animation and sample playback.
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
