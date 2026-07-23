/** @file
 * A @c UICollectionView subclass that forwards its layout passes to an auxiliary delegate: it tells
 * the delegate just before and just after @c -layoutSubviews so the host view can size its page
 * control from the freshly laid-out content.
 *
 * Speculative interface: only the members other classes use are declared here. Reconstructed from
 * Ghidra project rb458, program rb458 (class @c RBCollectionView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

@class RBCollectionView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Auxiliary delegate notified around an @c RBCollectionView's layout pass.
 */
@protocol RBCollectionViewDelegate <NSObject>

@optional

/**
 * @brief Sent just before the collection view lays its subviews out.
 * @param collectionView The collection view about to lay out.
 * @ghidraAddress 0x9d5d8
 */
- (void)willLayoutSubviews:(RBCollectionView *)collectionView;

/**
 * @brief Sent just after the collection view has laid its subviews out.
 * @param collectionView The collection view that finished laying out.
 * @ghidraAddress 0x9d5d8
 */
- (void)didLayoutSubviews:(RBCollectionView *)collectionView;

@end

/**
 * @brief A collection view that forwards its layout passes to an auxiliary delegate.
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
