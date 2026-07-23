/** @file
 * A @c UICollectionView subclass that brackets its layout pass with callbacks to an auxiliary
 * delegate. Just before it lays its subviews out it sends @c -willLayoutSubviews:, then it runs the
 * inherited @c UICollectionView layout, and finally it sends @c -didLayoutSubviews:. The host views
 * (@c RBUnlockCollectionView and @c RBCustomSelectCollectionView) use the trailing callback to size
 * their page control from the freshly laid-out content.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBCollectionView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBCollectionView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Auxiliary delegate notified around an @c RBCollectionView's layout pass.
 *
 * Both callbacks are optional; @c RBCollectionView guards each with @c -respondsToSelector: before
 * sending it.
 */
@protocol RBCollectionViewDelegate <NSObject>

@optional

/**
 * @brief Sent just before the collection view runs the inherited layout pass.
 * @param collectionView The collection view about to lay out.
 * @ghidraAddress 0x9d5d8
 */
- (void)willLayoutSubviews:(RBCollectionView *)collectionView;

/**
 * @brief Sent just after the collection view has run the inherited layout pass.
 * @param collectionView The collection view that finished laying out.
 * @ghidraAddress 0x9d5d8
 */
- (void)didLayoutSubviews:(RBCollectionView *)collectionView;

@end

/**
 * @brief A collection view that brackets its layout pass with delegate callbacks.
 */
@interface RBCollectionView : UICollectionView

/**
 * @brief The auxiliary delegate notified around each layout pass, held weakly.
 * @ghidraAddress 0x9d9b8 (getter)
 * @ghidraAddress 0x9d9d8 (setter)
 */
@property(weak, nonatomic, nullable) id<RBCollectionViewDelegate> customDelegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
