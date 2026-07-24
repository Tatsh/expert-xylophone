#import "RBMusicColorBar.h"

#import "RBMusicColorView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The autoresizing mask applied to the background, track, and grip views: the four flexible
// margins plus flexible width and height (0x3f).
static const UIViewAutoresizing kBarAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

// The half factor (the 0x3fe0000000000000 literal) used to centre the grip vertically on the
// track.
static const double kHalf = 0.5;

// The slider-value clamp range.
static const float kSliderValueMin = 0.0f;
static const float kSliderValueMax = 1.0f;

// The background and grip image names.
static NSString *const kBackgroundImageName = @"02_music_detail/det_col_br_4";
static NSString *const kGripImageName = @"02_music_detail/det_col_br_5";

// The track base-view frame on the compact (default-font) layout. The horizontal origin and width
// are fixed; the vertical origin depends on the theme.
static const CGFloat kCompactTrackX = 28.0;
static const CGFloat kCompactTrackYColette = 13.0;
static const CGFloat kCompactTrackYOther = 10.0;
static const CGFloat kCompactTrackWidth = 99.0;
static const CGFloat kCompactTrackHeight = 4.0;

// The track base-view frame on the iPad idiom (Colette) layout. The horizontal origin and width
// depend on the theme; the vertical origin and height are fixed.
static const CGFloat kVariantTrackXColette = 40.0;
static const CGFloat kVariantTrackXOther = 38.0;
static const CGFloat kVariantTrackY = 20.0;
static const CGFloat kVariantTrackWidthColette = 148.0;
static const CGFloat kVariantTrackWidthOther = 152.0;
static const CGFloat kVariantTrackHeight = 9.0;

// The pan gesture is ignored once it has ended, so a release does not re-drive the grip.
static const UIGestureRecognizerState kPanIgnoredState = UIGestureRecognizerStateEnded;

@interface RBMusicColorBar ()
// The tap gesture action: move the grip to the tapped horizontal position.
- (void)tap:(UITapGestureRecognizer *)tap;
// The pan gesture action: track the drag's horizontal position onto the grip.
- (void)pan:(UIPanGestureRecognizer *)pan;
@end

@implementation RBMusicColorBar

@dynamic alphaValue;

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
           MusicSelectedColor:(RBMusicColorView *)MusicSelectedColor {
    self = [super initWithFrame:frame];
    if (self) {
        self.musicSelectedColor = MusicSelectedColor;
        [self SetupView];
    }
    return self;
}

#pragma mark View construction

- (void)SetupView {
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = YES;

    UITapGestureRecognizer *tapRecognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self addGestureRecognizer:tapRecognizer];

    UIPanGestureRecognizer *panRecognizer =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self addGestureRecognizer:panRecognizer];

    UIImage *backgroundImage = [UIImage imageWithName:kBackgroundImageName];
    UIImageView *backgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
    backgroundView.frame = self.bounds;
    backgroundView.autoresizingMask = kBarAutoresizingMask;
    [self addSubview:backgroundView];

    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;
    CGRect trackFrame;
    if (!IsPad()) {
        trackFrame = CGRectMake(kCompactTrackX,
                                thema == RBUserSettingDataThemeColette ? kCompactTrackYColette :
                                                                         kCompactTrackYOther,
                                kCompactTrackWidth,
                                kCompactTrackHeight);
    } else {
        trackFrame = CGRectMake(thema == RBUserSettingDataThemeColette ? kVariantTrackXColette :
                                                                         kVariantTrackXOther,
                                kVariantTrackY,
                                thema == RBUserSettingDataThemeColette ? kVariantTrackWidthColette :
                                                                         kVariantTrackWidthOther,
                                kVariantTrackHeight);
    }

    UIView *track = [[UIView alloc] initWithFrame:trackFrame];
    self.baseView = track;
    self.baseView.backgroundColor = UIColor.clearColor;
    self.baseView.userInteractionEnabled = NO;
    self.baseView.autoresizingMask = kBarAutoresizingMask;
    [self addSubview:self.baseView];

    UIImage *gripImage = [UIImage imageWithName:kGripImageName];
    UIImageView *grip = [[UIImageView alloc] initWithImage:gripImage];
    self.gripView = grip;
    // The grip starts pinned to the left of the track, vertically centred on the track's height.
    self.gripView.center =
        CGPointMake(0.0, (double)(int)(self.baseView.bounds.size.height * kHalf));
    self.gripView.autoresizingMask = kBarAutoresizingMask;
    [self.baseView addSubview:self.gripView];
}

#pragma mark Slider value

- (void)SetBar:(float)SetBar {
    CGFloat gripCenterY = self.gripView.center.y;
    CGFloat trackWidth = self.baseView.bounds.size.width;
    if (SetBar < kSliderValueMin) {
        SetBar = kSliderValueMin;
    }
    if (SetBar > kSliderValueMax) {
        SetBar = kSliderValueMax;
    }
    self.gripView.center = CGPointMake((double)SetBar * trackWidth, gripCenterY);
    self.sliderValue = (double)SetBar;
    if (self.musicSelectedColor != nil) {
        [self.musicSelectedColor setRivalAlpha:self.alphaValue];
    }
}

- (float)alphaValue {
    return (float)self.sliderValue;
}

- (void)setAlphaValue:(float)alphaValue {
    [self SetBar:alphaValue];
}

#pragma mark Gestures

- (void)tap:(UITapGestureRecognizer *)tap {
    CGPoint location = [tap locationInView:self.baseView];
    CGFloat trackWidth = self.baseView.frame.size.width;
    [self SetBar:(float)(location.x / trackWidth)];
}

- (void)pan:(UIPanGestureRecognizer *)pan {
    if (pan.state != kPanIgnoredState) {
        CGPoint location = [pan locationInView:self.baseView];
        CGFloat trackWidth = self.baseView.frame.size.width;
        [self SetBar:(float)(location.x / trackWidth)];
    }
}

@end
