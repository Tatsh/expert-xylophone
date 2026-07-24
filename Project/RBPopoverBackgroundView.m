#import "RBPopoverBackgroundView.h"

#import <math.h>

#import <QuartzCore/QuartzCore.h>

#import "UIImage+RB.h"

// The popover's edge-to-content padding, returned uniformly on every edge by +contentViewInsets.
static const CGFloat kContentViewInset = 8.0;

// The reserved arrow height and full arrow base width, returned by +arrowHeight and +arrowBase.
static const CGFloat kArrowHeight = 19.0;
static const CGFloat kArrowBase = 37.0;

// The margin the popover body is inset from the view bounds when the extents are recomputed each
// layout pass.
static const CGFloat kExtentsInset = 7.0;

// The drop shadow applied to the background layer: fully-black colour, this opacity, radius, and
// vertical offset. The opacity is the shared g_flDefaultExplosionEffectSize palette float (0.9).
static const float kShadowOpacity = 0.9f;
static const CGFloat kShadowRadius = 10.0;
static const CGFloat kShadowOffsetY = 5.0;

// The bezier shadow rect is inset by the arrow height on the leading edge, and shifted inward by
// this amount when the arrow occupies that edge.
static const CGFloat kShadowArrowInset = 19.0;
static const CGFloat kShadowEdgeShift = 19.0;

// The resizable-image cap insets used to build the arrow artwork. Several metrics are read from
// shared constant-pool doubles that the decompiler names for unrelated call sites
// (g_dCustomizeLayoutMetric41 = 41.0, g_dMenuButtonHeightNarrow = 42.0,
// g_dMascotMessageBgCapInsetLeft = 47.0, and a 43.0 pool constant); they are cached here as
// literals rather than re-declared as shared external constants until those globals are recovered.
//
// The up/down straight and up-right/down-right corner arrows share a top and bottom that depend on
// whether the arrow points up: the up variant uses 41.0/9.0, the down variant uses 23.0/27.0.
static const CGFloat kUpDownLeftInset = 9.0;
static const CGFloat kUpArrowTop = 41.0;
static const CGFloat kUpArrowBottom = 9.0;
static const CGFloat kDownArrowTop = 23.0;
static const CGFloat kDownArrowBottom = 27.0;
// The straight up/down two-part image pins its right inset to 47.0; the corner variant to 42.0.
static const CGFloat kUpDownStraightRightInset = 47.0;
static const CGFloat kUpDownCornerRightInset = 42.0;

// The side (left/right) top/bottom corner arrow: a fixed left and right, with a top and bottom that
// depend on whether the arrow is at the top edge (top variant top 43.0/bottom 9.0, bottom variant
// top 23.0/bottom 43.0).
static const CGFloat kSideArrowLeftInset = 9.0;
static const CGFloat kSideArrowRightInset = 27.0;
static const CGFloat kSideTopArrowTop = 43.0;
static const CGFloat kSideTopArrowBottom = 9.0;
static const CGFloat kSideBottomArrowTop = 23.0;
static const CGFloat kSideBottomArrowBottom = 43.0;

// The straight side two-part image insets.
static const CGFloat kSideTwoPartTop = 24.0;
static const CGFloat kSideTwoPartLeft = 9.0;
static const CGFloat kSideTwoPartBottom = 47.0;
static const CGFloat kSideTwoPartRight = 27.0;

// The half-image split builds a second inset by shrinking the source dimension by this amount and
// pinning the trailing inset to this value.
static const CGFloat kSecondHalfShrink = 10.0;
static const CGFloat kSecondHalfTrailingInset = 9.0;

// The first-half stretch centre is nudged by a one-point rounding correction (both cases) and, for
// the side-arrow case, additionally by the body inset.
static const CGFloat kFirstHalfRoundingNudge = 1.0;

// The image names for each arrow orientation, drawn from the 01_music_select atlas.
static NSString *const kImageNameUp = @"01_music_select/sel_popover_up";
static NSString *const kImageNameDown = @"01_music_select/sel_popover_down";
static NSString *const kImageNameUpRight = @"01_music_select/sel_popover_upright";
static NSString *const kImageNameDownRight = @"01_music_select/sel_popover_downright";
static NSString *const kImageNameSide = @"01_music_select/sel_popover_side";
static NSString *const kImageNameTop = @"01_music_select/sel_popover_top";
static NSString *const kImageNameBottom = @"01_music_select/sel_popover_bottom";

// The layer animation key that carries the shadow-path change across a bounds animation.
static NSString *const kShadowPathAnimationKey = @"shadowPath";
static NSString *const kBoundsAnimationKey = @"bounds";

// The private popover-body extents (the binary's GIKPopoverExtents struct): the inset left, right,
// top, and bottom edges of the popover body in the view's coordinate space.
typedef struct {
    CGFloat left;
    CGFloat right;
    CGFloat top;
    CGFloat bottom;
} GIKPopoverExtents;

@interface RBPopoverBackgroundView () {
    // Non-property ivars; the binary keeps these literal names (no property backing).
    GIKPopoverExtents _popoverExtents;
    CGFloat _halfBase;
    CGFloat _arrowCenter;
}

- (void)addDropShadowIfNecessary;
- (CGPathRef)shadowPath;
- (void)addShadowPathAnimationIfNecessary:(CGPathRef)shadowPath;
- (CGFloat)halfArrowBase;
- (CGFloat)arrowCenter;
- (BOOL)wantsUpOrDownArrow;
- (BOOL)wantsUpArrow;
- (BOOL)isArrowBetweenLeftAndRightEdgesOfPopover;
- (BOOL)isArrowAtLeftEdgeOfPopover;
- (BOOL)isArrowAtRightEdgeOfPopover;
- (BOOL)isArrowBetweenTopAndBottomEdgesOfPopover;
- (BOOL)isArrowAtTopEdgeOfPopover;
- (BOOL)isArrowAtBottomEdgeOfPopover;
- (void)adjustCentersIfNecessary;
- (UIImage *)upOrDownArrowImage;
- (UIImage *)sideArrowImage;
- (UIImage *)stretchableImageNamed:(NSString *)imageName
                            insets:(UIEdgeInsets)insets
                          mirrored:(BOOL)mirrored;
- (UIImage *)twoPartStretchableImageNamed:(NSString *)imageName insets:(UIEdgeInsets)insets;
- (CGFloat)firstHalfStretchAmountForImage:(UIImage *)image;
- (CGSize)contextSizeForFirstHalfImage:(UIImage *)image;
- (UIEdgeInsets)secondHalfInsetsForStretchedImage:(UIImage *)image insets:(UIEdgeInsets)insets;
- (UIEdgeInsets)horizontalInsetsForStretchedImage:(UIImage *)image insets:(UIEdgeInsets)insets;
- (UIEdgeInsets)verticalInsetsForStretchedImage:(UIImage *)image insets:(UIEdgeInsets)insets;
- (UIImage *)mirroredImage:(UIImage *)image;
- (UIEdgeInsets)mirroredInsets:(UIEdgeInsets)insets;
- (UIImage *)imageFromImageContextWithSourceImage:(UIImage *)image size:(CGSize)size;
@end

@implementation RBPopoverBackgroundView

#pragma mark Required geometry

+ (CGFloat)arrowHeight {
    return kArrowHeight;
}

+ (CGFloat)arrowBase {
    return kArrowBase;
}

+ (UIEdgeInsets)contentViewInsets {
    return UIEdgeInsetsMake(kContentViewInset, kContentViewInset, kContentViewInset,
                            kContentViewInset);
}

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.popoverBackground = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self addSubview:self.popoverBackground];
    }
    return self;
}

#pragma mark Accessors

- (void)setArrowOffset:(CGFloat)arrowOffset {
    _arrowOffset = arrowOffset;
    if (![UIPopoverBackgroundView respondsToSelector:@selector(wantsDefaultContentAppearance)]) {
        CGPathRef path = [self shadowPath];
        [self addShadowPathAnimationIfNecessary:path];
        self.popoverBackground.layer.shadowPath = path;
    }
    [self setNeedsLayout];
}

- (void)setArrowDirection:(UIPopoverArrowDirection)arrowDirection {
    _arrowDirection = arrowDirection;
    [self addDropShadowIfNecessary];
    [self setNeedsLayout];
}

#pragma mark Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    _popoverExtents.left = CGRectGetMinX(bounds) + kExtentsInset;
    _popoverExtents.right = CGRectGetMaxX(bounds) - kExtentsInset;
    _popoverExtents.top = CGRectGetMinY(bounds) + kExtentsInset;
    _popoverExtents.bottom = CGRectGetMaxY(bounds) - kExtentsInset;

    _halfBase = [self halfArrowBase];
    _arrowCenter = [self arrowCenter];

    self.popoverBackground.center = self.center;
    self.popoverBackground.bounds = self.bounds;
    self.popoverBackground.image =
        [self wantsUpOrDownArrow] ? [self upOrDownArrowImage] : [self sideArrowImage];
}

#pragma mark Drop shadow

- (void)addDropShadowIfNecessary {
    if ([UIPopoverBackgroundView respondsToSelector:@selector(wantsDefaultContentAppearance)]) {
        return;
    }
    CALayer *layer = self.popoverBackground.layer;
    // The binary builds the shadow colour with colorWithRed:0 green:0 blue:0 alpha:1.
    layer.shadowColor = UIColor.blackColor.CGColor;
    layer.shadowOpacity = kShadowOpacity;
    layer.shadowRadius = kShadowRadius;
    layer.shadowOffset = CGSizeMake(0, kShadowOffsetY);
}

- (CGPathRef)shadowPath {
    CGRect rect = self.bounds;
    if ([self wantsUpOrDownArrow]) {
        rect.origin.y = [self wantsUpArrow] ? kShadowEdgeShift : 0.0;
        rect.size.height -= kShadowArrowInset;
    } else {
        rect.origin.x =
            (self.arrowDirection == UIPopoverArrowDirectionLeft) ? kShadowEdgeShift : 0.0;
        rect.size.width -= kShadowArrowInset;
    }
    return [UIBezierPath bezierPathWithRect:rect].CGPath;
}

- (void)addShadowPathAnimationIfNecessary:(CGPathRef)shadowPath {
    CALayer *layer = self.popoverBackground.layer;
    if (![layer.animationKeys containsObject:kBoundsAnimationKey]) {
        return;
    }
    CAAnimation *bounds = [layer animationForKey:kBoundsAnimationKey];
    CABasicAnimation *animation =
        [CABasicAnimation animationWithKeyPath:kShadowPathAnimationKey];
    animation.toValue = [NSValue valueWithPointer:shadowPath];
    animation.timingFunction = bounds.timingFunction;
    animation.duration = bounds.duration;
    [self.popoverBackground.layer addAnimation:animation forKey:kShadowPathAnimationKey];
}

#pragma mark Arrow geometry

- (CGFloat)halfArrowBase {
    return [RBPopoverBackgroundView arrowBase] * 0.5;
}

- (CGFloat)arrowCenter {
    CGRect bounds = self.bounds;
    CGFloat center =
        [self wantsUpOrDownArrow] ? CGRectGetMidX(bounds) : CGRectGetMidY(bounds);
    return center + self.arrowOffset;
}

- (BOOL)wantsUpOrDownArrow {
    return [self wantsUpArrow] || self.arrowDirection == UIPopoverArrowDirectionDown;
}

- (BOOL)wantsUpArrow {
    return self.arrowDirection == UIPopoverArrowDirectionUp;
}

- (BOOL)isArrowBetweenLeftAndRightEdgesOfPopover {
    return ![self isArrowAtRightEdgeOfPopover] && ![self isArrowAtLeftEdgeOfPopover];
}

- (BOOL)isArrowAtLeftEdgeOfPopover {
    return _arrowCenter - _halfBase < _popoverExtents.left;
}

- (BOOL)isArrowAtRightEdgeOfPopover {
    return _popoverExtents.right < _arrowCenter + _halfBase;
}

- (BOOL)isArrowBetweenTopAndBottomEdgesOfPopover {
    return ![self isArrowAtTopEdgeOfPopover] && ![self isArrowAtBottomEdgeOfPopover];
}

- (BOOL)isArrowAtTopEdgeOfPopover {
    return _arrowCenter - _halfBase < _popoverExtents.top;
}

- (BOOL)isArrowAtBottomEdgeOfPopover {
    return _popoverExtents.bottom < _arrowCenter + _halfBase;
}

- (void)adjustCentersIfNecessary {
    if (self.arrowDirection != UIPopoverArrowDirectionLeft) {
        return;
    }
    CGPoint center = self.center;
    center.x += [RBPopoverBackgroundView arrowHeight];
    self.center = center;

    CGPoint backgroundCenter = self.popoverBackground.center;
    backgroundCenter.x -= [RBPopoverBackgroundView arrowHeight];
    self.popoverBackground.center = backgroundCenter;
}

#pragma mark Arrow images

- (UIImage *)upOrDownArrowImage {
    BOOL wantsUpArrow = [self wantsUpArrow];
    CGFloat top = wantsUpArrow ? kUpArrowTop : kDownArrowTop;
    CGFloat bottom = wantsUpArrow ? kUpArrowBottom : kDownArrowBottom;
    if ([self isArrowBetweenLeftAndRightEdgesOfPopover]) {
        NSString *imageName = wantsUpArrow ? kImageNameUp : kImageNameDown;
        UIEdgeInsets insets =
            UIEdgeInsetsMake(top, kUpDownLeftInset, bottom, kUpDownStraightRightInset);
        return [self twoPartStretchableImageNamed:imageName insets:insets];
    }
    NSString *imageName = wantsUpArrow ? kImageNameUpRight : kImageNameDownRight;
    UIEdgeInsets insets =
        UIEdgeInsetsMake(top, kUpDownLeftInset, bottom, kUpDownCornerRightInset);
    BOOL mirrored = [self isArrowAtLeftEdgeOfPopover];
    return [self stretchableImageNamed:imageName insets:insets mirrored:mirrored];
}

- (UIImage *)sideArrowImage {
    [self adjustCentersIfNecessary];
    if ([self isArrowBetweenTopAndBottomEdgesOfPopover]) {
        UIEdgeInsets insets = UIEdgeInsetsMake(kSideTwoPartTop, kSideTwoPartLeft,
                                               kSideTwoPartBottom, kSideTwoPartRight);
        return [self twoPartStretchableImageNamed:kImageNameSide insets:insets];
    }
    BOOL wantsTop = [self isArrowAtTopEdgeOfPopover];
    NSString *imageName = wantsTop ? kImageNameTop : kImageNameBottom;
    CGFloat top = wantsTop ? kSideTopArrowTop : kSideBottomArrowTop;
    CGFloat bottom = wantsTop ? kSideTopArrowBottom : kSideBottomArrowBottom;
    UIEdgeInsets insets =
        UIEdgeInsetsMake(top, kSideArrowLeftInset, bottom, kSideArrowRightInset);
    BOOL mirrored = self.arrowDirection == UIPopoverArrowDirectionLeft;
    return [self stretchableImageNamed:imageName insets:insets mirrored:mirrored];
}

#pragma mark Stretchable image construction

- (UIImage *)stretchableImageNamed:(NSString *)imageName
                            insets:(UIEdgeInsets)insets
                          mirrored:(BOOL)mirrored {
    UIImage *image = [UIImage imageWithName:imageName];
    if (mirrored) {
        return [[self mirroredImage:image]
            resizableImageWithCapInsets:[self mirroredInsets:insets]];
    }
    return [image resizableImageWithCapInsets:insets];
}

- (UIImage *)twoPartStretchableImageNamed:(NSString *)imageName insets:(UIEdgeInsets)insets {
    UIImage *image = [UIImage imageWithName:imageName];
    if (self.arrowDirection == UIPopoverArrowDirectionLeft) {
        image = [self mirroredImage:image];
        insets = [self mirroredInsets:insets];
    }
    UIImage *stretched = [image resizableImageWithCapInsets:insets];
    CGSize size = [self contextSizeForFirstHalfImage:stretched];
    UIImage *firstHalf = [self imageFromImageContextWithSourceImage:stretched size:size];
    UIEdgeInsets secondHalfInsets =
        [self secondHalfInsetsForStretchedImage:firstHalf insets:insets];
    return [firstHalf resizableImageWithCapInsets:secondHalfInsets];
}

- (CGFloat)firstHalfStretchAmountForImage:(UIImage *)image {
    CGSize size = image.size;
    CGFloat amount;
    if ([self wantsUpOrDownArrow]) {
        amount = _arrowCenter + (size.width - kFirstHalfRoundingNudge) * 0.5;
    } else {
        amount = _arrowCenter + size.height * 0.5 - kFirstHalfRoundingNudge - kExtentsInset;
    }
    // The binary rounds to the nearest whole point via a round-to-nearest float instruction.
    return (CGFloat)roundf((float)amount);
}

- (CGSize)contextSizeForFirstHalfImage:(UIImage *)image {
    CGFloat stretchAmount = [self firstHalfStretchAmountForImage:image];
    CGSize size = image.size;
    if ([self wantsUpOrDownArrow]) {
        return CGSizeMake(stretchAmount, size.height);
    }
    return CGSizeMake(size.width, stretchAmount);
}

- (UIEdgeInsets)secondHalfInsetsForStretchedImage:(UIImage *)image insets:(UIEdgeInsets)insets {
    if ([self wantsUpOrDownArrow]) {
        return [self horizontalInsetsForStretchedImage:image insets:insets];
    }
    return [self verticalInsetsForStretchedImage:image insets:insets];
}

- (UIEdgeInsets)horizontalInsetsForStretchedImage:(UIImage *)image insets:(UIEdgeInsets)insets {
    CGSize size = image.size;
    return UIEdgeInsetsMake(insets.top, size.width - kSecondHalfShrink, insets.bottom,
                            kSecondHalfTrailingInset);
}

- (UIEdgeInsets)verticalInsetsForStretchedImage:(UIImage *)image insets:(UIEdgeInsets)insets {
    CGSize size = image.size;
    return UIEdgeInsetsMake(size.height - kSecondHalfShrink, insets.left,
                            kSecondHalfTrailingInset, insets.right);
}

#pragma mark Image helpers

- (UIImage *)mirroredImage:(UIImage *)image {
    UIImage *mirrored = [UIImage imageWithCGImage:image.CGImage
                                            scale:UIScreen.mainScreen.scale
                                      orientation:UIImageOrientationUpMirrored];
    return [self imageFromImageContextWithSourceImage:mirrored size:mirrored.size];
}

- (UIEdgeInsets)mirroredInsets:(UIEdgeInsets)insets {
    return UIEdgeInsetsMake(insets.top, insets.right, insets.bottom, insets.left);
}

- (UIImage *)imageFromImageContextWithSourceImage:(UIImage *)image size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@end
