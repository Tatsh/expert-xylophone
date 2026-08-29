#import "RBMenuNewsTickerView.h"

#import <QuartzCore/QuartzCore.h>

#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"

static NSString *const kNewsTickerBackgroundImageName = @"01_music_select/sel_news";

// The binary routes the icon text through a format rather than using the literal directly.
static NSString *const kNewsTickerIconFormat = @"%@";
static NSString *const kNewsTickerIconText = @"NEWS";

static const CGFloat kNewsTickerFontSizePad = 18.0;
static const CGFloat kNewsTickerFontSizePhone = 12.0;

static const CGFloat kNewsTickerTextInsetPad = 100.0;
static const CGFloat kNewsTickerTextInsetPhone = 50.0;

enum {
    kNewsTickerThemeLight = 0,
    kNewsTickerThemeDarkOne = 1,
    kNewsTickerThemeDarkTwo = 2,
};

static const CGFloat kNewsTickerDarkThemeBackgroundComponent =
    218.0f / 255.0f; /** @ghidraAddress 0x300fa8 */
static const CGFloat kNewsTickerDarkThemeBackgroundAlpha = 1.0;

static const CGFloat kNewsTickerScrollPointsPerSecond = 75.0; /** @ghidraAddress 0x300fb0 */

static const CGFloat kNewsTickerScrollConstantSeconds = 3.0;

// Every marquee begins and ends parked, so a finished animation leaves the ticker blank.
static const CGFloat kNewsTickerTextLayerParkedY = 40.0; /** @ghidraAddress 0x2ee950 */
static const CGFloat kNewsTickerTextLayerVisibleY = 0.0;

static const CGFloat kNewsTickerAnchorCenterX = 0.5;

static const CGFloat kNewsTickerAnchorTopY = 0.0;

static const CGFloat kNewsTickerScrollMidpointFraction = 0.5;

static NSString *const kNewsTickerAnchorAnimationKey = @"NEWS_INFO_SET_ANCHOR";
static NSString *const kNewsTickerPositionAnimationKey = @"NEWS_INFO_SET_POSITION";
static NSString *const kNewsTickerPositionEndAnimationKey = @"NEWS_INFO_SET_POSITION_END";

static NSString *const kNewsTickerLinkScheme = @"rbplus";
static NSString *const kNewsTickerLinkHostStore = @"store";
static NSString *const kNewsTickerLinkHostInfo = @"info";
static NSString *const kNewsTickerLinkPathPack = @"pack";
static NSString *const kNewsTickerLinkPathCampaign = @"campaign";
static NSString *const kNewsTickerLinkPathSequence = @"seq";
static NSString *const kNewsTickerLinkPathWeb = @"web";
static NSString *const kNewsTickerLinkQuerySeparator = @"=";
static NSString *const kNewsTickerLinkQueryKeyID = @"id";

static const NSUInteger kNewsTickerLinkQueryComponentCount = 2;

@implementation RBMenuNewsTickerView {
    BOOL m_LinkToStore;
    // Declared by the class but never read or written by any of its methods.
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

    // Anchoring top-left makes the layer position the text's origin rather than its centre.
    newsLabel.layer.anchorPoint = CGPointZero;

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
    self.textView.frame = CGRectMake(0.0, 0.0, textSize.width, self.textBaseView.frame.size.height);
    CGFloat overflow = textSize.width - self.textBaseView.bounds.size.width;

    float duration = 0.0;
    if (overflow <= 0.0) {
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
