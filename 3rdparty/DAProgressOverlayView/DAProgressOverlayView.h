/**
 * @file
 * A circular download-progress overlay drawn over a view: an inner disc that fills as progress is
 * reported, ringed by a faded outer circle, with animate-in and animate-out transitions.
 */

//
//  DAProgressOverlayView.h
//  DAProgressOverlayView
//
//  Created by Daria Kopaliani on 8/1/13.
//  Copyright (c) 2013 Daria Kopaliani. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A circular progress overlay view.
 */
@interface DAProgressOverlayView : UIView

/**
 * @brief The fill colour of the overlay's circles.
 */
@property(strong, nonatomic) UIColor *overlayColor;

/**
 * @brief The ratio of the inner circle to the minimum side of the view (@c 0 to @c 1).
 *
 * This is @c \#000000 with alpha @c 0.5 by default.
 */
@property(assign, nonatomic) CGFloat innerRadiusRatio;

/**
 * @brief The ratio of the outer circle to the minimum side of the view (@c 0 to @c 1).
 *
 * This is @c 0.7 by default.
 */
@property(assign, nonatomic) CGFloat outerRadiusRatio;

/**
 * @brief The fraction of the inner circle that is filled in (@c 0 to @c 1).
 */
@property(assign, nonatomic) CGFloat progress;

/**
 * @brief The duration of the animations shown by @c displayOperationWillTriggerAnimation and
 * @c displayOperationDidFinishAnimation.
 *
 * This is @c 0.25 by default.
 */
@property(assign, nonatomic) CGFloat stateChangeAnimationDuration;

/**
 * @brief Whether @c displayOperationDidFinishAnimation is called automatically when @c progress is
 * set to @c 1.
 *
 * This is @c YES by default.
 */
@property(assign, nonatomic) BOOL triggersDownloadDidFinishAnimationAutomatically;

/**
 * @brief Expand the faded outer circle until it circumscribes the view's bounds.
 */
- (void)displayOperationDidFinishAnimation;

/**
 * @brief Grow the inner and outer circles from zero to the radii derived from @c innerRadiusRatio
 * and @c outerRadiusRatio.
 */
- (void)displayOperationWillTriggerAnimation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
