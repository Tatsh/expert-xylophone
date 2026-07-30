//
//  RBMenuNewsTickerView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMenuNewsTickerView). The
//  soft-float CGRect layout, the marquee keyframe timing, and the rbplus:// link routing were
//  recovered from the arm64 disassembly, whose register/stack float moves the decompiler folds into
//  pseudo-variables.
//

#import "RBMenuNewsTickerView.h"

#import <QuartzCore/QuartzCore.h>

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"

// The news-ticker banner background image, whose height sets the ticker's overall bounds.
static NSString *const kNewsTickerBackgroundImageName = @"01_music_select/sel_news";

// The leading icon label's text. The binary builds it through a "%@" format rather than using the
// literal directly.
static NSString *const kNewsTickerIconFormat = @"%@";
static NSString *const kNewsTickerIconText = @"NEWS";

// The point size of the news text, chosen by the active iPad idiom. The pad uses the larger glyph.
static const CGFloat kNewsTickerFontSizePad = 18.0;
static const CGFloat kNewsTickerFontSizePhone = 12.0;

// The horizontal inset of the clipping text base view within the ticker, chosen by the iPad idiom.
// It is also the width consumed by the leading news icon.
static const CGFloat kNewsTickerTextInsetPad = 100.0;
static const CGFloat kNewsTickerTextInsetPhone = 50.0;

// The theme index whose news text and background use the light (white-on-black) colour scheme. The
// two darker themes draw black text on a near-white translucent background.
enum {
    kNewsTickerThemeLight = 0,
    kNewsTickerThemeDarkOne = 1,
    kNewsTickerThemeDarkTwo = 2,
};

// The near-white background colour component used by the two darker themes. It is 0xda/0xff
// rounded to single precision and widened again, which is how the constant sits in the pool.
static const CGFloat kNewsTickerDarkThemeBackgroundComponent =
    0.8549019694328308; /** @ghidraAddress 0x300fa8 */
static const CGFloat kNewsTickerDarkThemeBackgroundAlpha = 1.0;

// The marquee scroll speed, expressed as the divisor that converts the text's overflow width in
// points into extra scroll seconds.
static const CGFloat kNewsTickerScrollPointsPerSecond = 75.0; /** @ghidraAddress 0x300fb0 */

// The fixed number of seconds added to every overflowing marquee scroll on top of the
// overflow-width term and the base duration.
static const CGFloat kNewsTickerScrollConstantSeconds = 3.0;

// The two y-coordinates the scrolling text layer's position alternates between. The label's anchor
// point is its top-left corner, so the parked value drops the text clear of the clipping base view
// and the visible value seats it against the base view's top edge. Every marquee begins and ends
// parked, which is why a finished animation leaves the ticker blank until it is restarted.
static const CGFloat kNewsTickerTextLayerParkedY = 40.0; /** @ghidraAddress 0x2ee950 */
static const CGFloat kNewsTickerTextLayerVisibleY = 0.0;

// The anchor-point x-coordinate the ticker's own layer animates to at startup.
static const CGFloat kNewsTickerAnchorCenterX = 0.5;

// The anchor-point y-coordinate the ticker's own layer animates to, and the text label's anchor
// point, both of which the binary pins to the top edge.
static const CGFloat kNewsTickerAnchorTopY = 0.0;

// The relative time, within a scroll cycle, at which the text sits fully centred.
static const CGFloat kNewsTickerScrollMidpointFraction = 0.5;

// The animation keys under which the marquee animations are stored on the text layer.
static NSString *const kNewsTickerAnchorAnimationKey = @"NEWS_INFO_SET_ANCHOR";
static NSString *const kNewsTickerPositionAnimationKey = @"NEWS_INFO_SET_POSITION";
static NSString *const kNewsTickerPositionEndAnimationKey = @"NEWS_INFO_SET_POSITION_END";

// The rbplus:// link scheme and the host, path, and query tokens that select each in-app
// destination.
static NSString *const kNewsTickerLinkScheme = @"rbplus";
static NSString *const kNewsTickerLinkHostStore = @"store";
static NSString *const kNewsTickerLinkHostInfo = @"info";
static NSString *const kNewsTickerLinkPathPack = @"pack";
static NSString *const kNewsTickerLinkPathCampaign = @"campaign";
static NSString *const kNewsTickerLinkPathSequence = @"seq";
static NSString *const kNewsTickerLinkPathWeb = @"web";
static NSString *const kNewsTickerLinkQuerySeparator = @"=";
static NSString *const kNewsTickerLinkQueryKeyID = @"id";

// The number of key/value tokens a well-formed "id=value" link query splits into.
static const NSUInteger kNewsTickerLinkQueryComponentCount = 2;

@implementation RBMenuNewsTickerView {
    // Whether the current link routes to an in-app store, pack, campaign, sequence, or web
    // destination rather than an external URL. Backs isLinkToStore; it has no accessor property.
    BOOL m_LinkToStore;
    // A selector slot declared by the class but never read or written by any of its methods.
    SEL m_Selector;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.baseDuration = 0.0;
        [self SetUpView];
    }
    return self;
}

- (void)SetUpView {
    self.contentScaleFactor = [UIScreen mainScreen].scale;

    BOOL isPad = IsPad();
    NSInteger theme = [RBUserSettingData sharedInstance].thema;
    CGFloat fontSize = isPad ? kNewsTickerFontSizePad : kNewsTickerFontSizePhone;
    CGFloat textInset = isPad ? kNewsTickerTextInsetPad : kNewsTickerTextInsetPhone;

    UIImage *background = [UIImage imageWithName:kNewsTickerBackgroundImageName];
    self.frame = CGRectMake(
        self.frame.origin.x, self.frame.origin.y, self.frame.size.width, background.size.height);
    [self setExclusiveTouch:YES];

    UILabel *iconLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, textInset, self.frame.size.height)];
    iconLabel.font = [UIFont systemFontOfSize:fontSize];
    iconLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    iconLabel.textAlignment = NSTextAlignmentCenter;
    iconLabel.text = [NSString stringWithFormat:kNewsTickerIconFormat, kNewsTickerIconText];
    iconLabel.textColor = UIColor.blackColor;
    iconLabel.backgroundColor = UIColor.clearColor;
    [self addSubview:iconLabel];

    UIView *baseView = [[UIView alloc] initWithFrame:CGRectMake(textInset,
                                                                0.0,
                                                                self.bounds.size.width - textInset,
                                                                self.bounds.size.height)];
    baseView.clipsToBounds = YES;
    baseView.userInteractionEnabled = NO;
    baseView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview:baseView];
    self.textBaseView = baseView;

    self.font = [UIFont systemFontOfSize:fontSize];

    UILabel *newsLabel = [[UILabel alloc] initWithFrame:baseView.bounds];
    newsLabel.font = self.font;
    if (theme == kNewsTickerThemeDarkTwo || theme == kNewsTickerThemeDarkOne) {
        newsLabel.textColor = UIColor.blackColor;
        iconLabel.textColor = UIColor.blackColor;
        self.backgroundColor = [UIColor colorWithRed:kNewsTickerDarkThemeBackgroundComponent
                                               green:kNewsTickerDarkThemeBackgroundComponent
                                                blue:kNewsTickerDarkThemeBackgroundComponent
                                               alpha:kNewsTickerDarkThemeBackgroundAlpha];
    } else if (theme == kNewsTickerThemeLight) {
        newsLabel.textColor = UIColor.whiteColor;
        iconLabel.textColor = UIColor.whiteColor;
        self.backgroundColor = UIColor.blackColor;
    }
    newsLabel.backgroundColor = UIColor.clearColor;
    iconLabel.backgroundColor = UIColor.clearColor;
    newsLabel.textAlignment = NSTextAlignmentLeft;
    newsLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    newsLabel.numberOfLines = 1;
    newsLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [baseView addSubview:newsLabel];
    self.textView = newsLabel;

    // The text label anchors on its top-left corner, so its layer position is its origin rather
    // than its centre.
    newsLabel.layer.anchorPoint = CGPointZero;

    // The anchor-point animation runs on the ticker's own layer, not the text label's.
    CGPoint anchorPoint = self.layer.anchorPoint;
    CABasicAnimation *anchorAnimation = [CABasicAnimation animationWithKeyPath:@"anchorPoint"];
    anchorAnimation.duration = 0.0;
    anchorAnimation.repeatCount = 0.0;
    anchorAnimation.fromValue = [NSValue valueWithCGPoint:anchorPoint];
    anchorAnimation.toValue =
        [NSValue valueWithCGPoint:CGPointMake(kNewsTickerAnchorCenterX, kNewsTickerAnchorTopY)];
    anchorAnimation.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    self.layer.anchorPoint = CGPointMake(kNewsTickerAnchorCenterX, kNewsTickerAnchorTopY);
    [self.layer addAnimation:anchorAnimation forKey:kNewsTickerAnchorAnimationKey];
}

- (float)setText:(NSString *)text LINK:(NSURL *)LINK {
    self.textView.text = text;
    CGSize textSize = [text sizeWithFont:self.font];
    // The label is sized to the text, not to the base view: only the width comes from the measured
    // text, while the height is the one the base view's frame left behind.
    self.textView.frame =
        CGRectMake(0.0, 0.0, textSize.width, self.textBaseView.frame.size.height);
    CGFloat overflow = textSize.width - self.textBaseView.bounds.size.width;

    float duration = 0.0;
    if (overflow <= 0.0) {
        // The text fits: no horizontal travel, so the marquee only lifts the text from its parked
        // y into view and drops it back at the end.
        CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        animation.duration = self.baseDuration;
        animation.repeatCount = 0.0;
        animation.values = @[
            [NSValue valueWithCGPoint:CGPointMake(0.0, kNewsTickerTextLayerParkedY)],
            [NSValue valueWithCGPoint:CGPointMake(0.0, kNewsTickerTextLayerVisibleY)],
            [NSValue valueWithCGPoint:CGPointMake(0.0, kNewsTickerTextLayerVisibleY)],
            [NSValue valueWithCGPoint:CGPointMake(0.0, kNewsTickerTextLayerParkedY)],
        ];
        animation.keyTimes = @[
            @(0.0),
            @(kNewsTickerScrollMidpointFraction / self.baseDuration),
            @(-kNewsTickerScrollMidpointFraction / self.baseDuration + 1.0),
            @(1.0),
        ];
        animation.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        ];
        self.textView.layer.position = CGPointMake(0.0, kNewsTickerTextLayerParkedY);
        [self.textView.layer addAnimation:animation forKey:kNewsTickerPositionAnimationKey];
    } else {
        // The text overflows: scroll it left by the overflow distance over a duration proportional
        // to that distance, plus the fixed and base terms.
        float scrollSeconds =
            overflow / kNewsTickerScrollPointsPerSecond + kNewsTickerScrollConstantSeconds;
        duration = scrollSeconds;
        float totalDuration = scrollSeconds + self.baseDuration;
        CGFloat scrolledX = -overflow;

        CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        animation.duration = totalDuration;
        animation.repeatCount = 0.0;
        animation.values = @[
            [NSValue valueWithCGPoint:CGPointMake(0.0, kNewsTickerTextLayerParkedY)],
            [NSValue valueWithCGPoint:CGPointMake(0.0, kNewsTickerTextLayerVisibleY)],
            [NSValue valueWithCGPoint:CGPointMake(0.0, kNewsTickerTextLayerVisibleY)],
            [NSValue valueWithCGPoint:CGPointMake(scrolledX, kNewsTickerTextLayerVisibleY)],
            [NSValue valueWithCGPoint:CGPointMake(scrolledX, kNewsTickerTextLayerVisibleY)],
            [NSValue valueWithCGPoint:CGPointMake(scrolledX, kNewsTickerTextLayerParkedY)],
        ];
        animation.keyTimes = @[
            @(0.0),
            @(kNewsTickerScrollMidpointFraction / totalDuration),
            @((self.baseDuration * kNewsTickerScrollMidpointFraction +
               kNewsTickerScrollMidpointFraction) /
              totalDuration),
            @((totalDuration - kNewsTickerScrollMidpointFraction +
               self.baseDuration * -kNewsTickerScrollMidpointFraction) /
              totalDuration),
            @((totalDuration - kNewsTickerScrollMidpointFraction) / totalDuration),
            @(1.0),
        ];
        animation.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
        ];
        self.textView.layer.position = CGPointMake(scrolledX, kNewsTickerTextLayerParkedY);
        [self.textView.layer addAnimation:animation forKey:kNewsTickerPositionAnimationKey];
    }

    self.linkURL = nil;
    self.packID = nil;
    self.campaignID = nil;
    self.sequenceID = nil;

    if (LINK != nil) {
        if (![LINK.scheme isEqualToString:kNewsTickerLinkScheme]) {
            m_LinkToStore = NO;
            self.linkURL = LINK;
        } else if ([LINK.host isEqualToString:kNewsTickerLinkHostStore]) {
            NSArray<NSString *> *pathComponents = LINK.pathComponents;
            if (pathComponents.count > 1) {
                if ([pathComponents[1] isEqualToString:kNewsTickerLinkPathPack]) {
                    NSArray<NSString *> *query =
                        [LINK.query componentsSeparatedByString:kNewsTickerLinkQuerySeparator];
                    if (query.count == kNewsTickerLinkQueryComponentCount &&
                        [query[0] isEqualToString:kNewsTickerLinkQueryKeyID]) {
                        m_LinkToStore = YES;
                        self.packID = query[1];
                    }
                } else if ([pathComponents[1] isEqualToString:kNewsTickerLinkPathCampaign]) {
                    NSArray<NSString *> *query =
                        [LINK.query componentsSeparatedByString:kNewsTickerLinkQuerySeparator];
                    if (query.count == kNewsTickerLinkQueryComponentCount &&
                        [query[0] isEqualToString:kNewsTickerLinkQueryKeyID]) {
                        m_LinkToStore = YES;
                        self.campaignID = query[1];
                    }
                } else if ([pathComponents[1] isEqualToString:kNewsTickerLinkPathSequence]) {
                    NSArray<NSString *> *query =
                        [LINK.query componentsSeparatedByString:kNewsTickerLinkQuerySeparator];
                    if (query.count == kNewsTickerLinkQueryComponentCount &&
                        [query[0] isEqualToString:kNewsTickerLinkQueryKeyID]) {
                        m_LinkToStore = YES;
                        self.sequenceID = query[1];
                    }
                }
            }
        } else if ([LINK.host isEqualToString:kNewsTickerLinkHostInfo]) {
            NSArray<NSString *> *pathComponents = LINK.pathComponents;
            if (pathComponents.count > 1 &&
                [pathComponents[1] isEqualToString:kNewsTickerLinkPathWeb]) {
                NSArray<NSString *> *query =
                    [LINK.query componentsSeparatedByString:kNewsTickerLinkQuerySeparator];
                if (query.count == kNewsTickerLinkQueryComponentCount &&
                    [query[0] isEqualToString:kNewsTickerLinkQueryKeyID]) {
                    m_LinkToStore = YES;
                    self.webID = query[1];
                }
            }
        }
    }

    return duration;
}

- (void)setDuration:(float)duration {
    self.baseDuration = duration;
}

- (NSString *)getPackID {
    return self.packID;
}

- (NSString *)getCampaignID {
    return self.campaignID;
}

- (NSString *)getSequenceID {
    return self.sequenceID;
}

- (NSString *)getWebID {
    return self.webID;
}

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished {
    if (finished && [animation isKindOfClass:[CABasicAnimation class]]) {
        CABasicAnimation *basic = (CABasicAnimation *)animation;
        CABasicAnimation *loop = [CABasicAnimation animationWithKeyPath:@"position"];
        loop.duration = 0.0;
        loop.repeatCount = 0.0;
        loop.fromValue = basic.toValue;
        loop.toValue = basic.toValue;
        loop.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        self.textView.layer.position = [basic.toValue CGPointValue];
        [self.textView.layer addAnimation:loop forKey:kNewsTickerPositionEndAnimationKey];
    }
}

- (void)stopNews {
    NSArray<NSString *> *keys = self.textView.layer.animationKeys;
    if (keys != nil && keys.count != 0) {
        [self.textView.layer removeAllAnimations];
    }
}

- (BOOL)isLinkToStore {
    return m_LinkToStore;
}

- (void)toLink {
    if (self.linkURL != nil) {
        if ([[UIApplication sharedApplication] canOpenURL:self.linkURL]) {
            [[UIApplication sharedApplication] openURL:self.linkURL];
        }
    }
}

- (NSArray<NSString *> *)parseQuery:(NSString *)query {
    if (query != nil) {
        NSURL *url = [NSURL URLWithString:query];
        if ([url.host isEqualToString:kNewsTickerLinkScheme]) {
            (void)url.pathComponents;
        }
    }
    return nil;
}

@end
