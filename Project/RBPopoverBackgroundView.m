#import "RBPopoverBackgroundView.h"

#import <math.h>

#import <QuartzCore/QuartzCore.h>

#import "UIImage+RB.h"

static const CGFloat kContentViewInset = 8.0;

static const CGFloat kArrowHeight = 19.0;
static const CGFloat kArrowBase = 37.0;

static const CGFloat kExtentsInset = 7.0;

static const float kShadowOpacity = 0.9f;
static const CGFloat kShadowRadius = 10.0;
static const CGFloat kShadowOffsetY = 5.0;

static const CGFloat kShadowArrowInset = 19.0;
static const CGFloat kShadowEdgeShift = 19.0;

static const CGFloat kUpDownLeftInset = 9.0;
static const CGFloat kUpArrowTop = 41.0;
static const CGFloat kUpArrowBottom = 9.0;
static const CGFloat kDownArrowTop = 23.0;
static const CGFloat kDownArrowBottom = 27.0;
static const CGFloat kUpDownStraightRightInset = 47.0;
static const CGFloat kUpDownCornerRightInset = 42.0;

static const CGFloat kSideArrowLeftInset = 9.0;
static const CGFloat kSideArrowRightInset = 27.0;
static const CGFloat kSideTopArrowTop = 43.0;
static const CGFloat kSideTopArrowBottom = 9.0;
static const CGFloat kSideBottomArrowTop = 23.0;
static const CGFloat kSideBottomArrowBottom = 43.0;

static const CGFloat kSideTwoPartTop = 24.0;
static const CGFloat kSideTwoPartLeft = 9.0;
static const CGFloat kSideTwoPartBottom = 47.0;
static const CGFloat kSideTwoPartRight = 27.0;

static const CGFloat kSecondHalfShrink = 10.0;
static const CGFloat kSecondHalfTrailingInset = 9.0;

static const CGFloat kFirstHalfRoundingNudge = 1.0;

static NSString *const kImageNameUp = @"01_music_select/sel_popover_up";
static NSString *const kImageNameDown = @"01_music_select/sel_popover_down";
static NSString *const kImageNameUpRight = @"01_music_select/sel_popover_upright";
static NSString *const kImageNameDownRight = @"01_music_select/sel_popover_downright";
static NSString *const kImageNameSide = @"01_music_select/sel_popover_side";
static NSString *const kImageNameTop = @"01_music_select/sel_popover_top";
static NSString *const kImageNameBottom = @"01_music_select/sel_popover_bottom";

static NSString *const kShadowPathAnimationKey = @"shadowPath";
static NSString *const kBoundsAnimationKey = @"bounds";

typedef struct {
    CGFloat left;
    CGFloat right;
    CGFloat top;
    CGFloat bottom;
} GIKPopoverExtents;

@interface RBPopoverBackgroundView () {
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

// The superclass's abstract accessors need explicit storage in the subclass.
@synthesize arrowOffset = _arrowOffset;
@synthesize arrowDirection = _arrowDirection;

#pragma mark Required geometry

+ (CGFloat)arrowHeight {
    return kArrowHeight;
}

+ (CGFloat)arrowBase {
    return kArrowBase;
}

+ (UIEdgeInsets)contentViewInsets {
    return UIEdgeInsetsMake(
        kContentViewInset, kContentViewInset, kContentViewInset, kContentViewInset);
}

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // @ghidraAddress 0xd7cc8
        // @ghidraAddress 0xd7c78
        _popoverBackground = [[UIImageView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, frame.size.height)];
        [self addSubview:_popoverBackground];
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
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:kShadowPathAnimationKey];
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
    CGFloat center = [self wantsUpOrDownArrow] ? CGRectGetMidX(bounds) : CGRectGetMidY(bounds);
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
    UIEdgeInsets insets = UIEdgeInsetsMake(top, kUpDownLeftInset, bottom, kUpDownCornerRightInset);
    BOOL mirrored = [self isArrowAtLeftEdgeOfPopover];
    return [self stretchableImageNamed:imageName insets:insets mirrored:mirrored];
}

- (UIImage *)sideArrowImage {
    [self adjustCentersIfNecessary];
    if ([self isArrowBetweenTopAndBottomEdgesOfPopover]) {
        UIEdgeInsets insets = UIEdgeInsetsMake(
            kSideTwoPartTop, kSideTwoPartLeft, kSideTwoPartBottom, kSideTwoPartRight);
        return [self twoPartStretchableImageNamed:kImageNameSide insets:insets];
    }
    BOOL wantsTop = [self isArrowAtTopEdgeOfPopover];
    NSString *imageName = wantsTop ? kImageNameTop : kImageNameBottom;
    CGFloat top = wantsTop ? kSideTopArrowTop : kSideBottomArrowTop;
    CGFloat bottom = wantsTop ? kSideTopArrowBottom : kSideBottomArrowBottom;
    UIEdgeInsets insets = UIEdgeInsetsMake(top, kSideArrowLeftInset, bottom, kSideArrowRightInset);
    BOOL mirrored = self.arrowDirection == UIPopoverArrowDirectionLeft;
    return [self stretchableImageNamed:imageName insets:insets mirrored:mirrored];
}

#pragma mark Stretchable image construction

- (UIImage *)stretchableImageNamed:(NSString *)imageName
                            insets:(UIEdgeInsets)insets
                          mirrored:(BOOL)mirrored {
    UIImage *image = [UIImage imageWithName:imageName];
    if (mirrored) {
        return
            [[self mirroredImage:image] resizableImageWithCapInsets:[self mirroredInsets:insets]];
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
    UIEdgeInsets secondHalfInsets = [self secondHalfInsetsForStretchedImage:firstHalf
                                                                     insets:insets];
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
    return UIEdgeInsetsMake(
        insets.top, size.width - kSecondHalfShrink, insets.bottom, kSecondHalfTrailingInset);
}

- (UIEdgeInsets)verticalInsetsForStretchedImage:(UIImage *)image insets:(UIEdgeInsets)insets {
    CGSize size = image.size;
    return UIEdgeInsetsMake(
        size.height - kSecondHalfShrink, insets.left, kSecondHalfTrailingInset, insets.right);
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
