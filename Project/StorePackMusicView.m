#import "StorePackMusicView.h"

#import "StoreImageView.h"
#import "StoreMusicInfo.h"
#import "StorePackDetailViewPad.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"

// The 32-point layout metric shared across the store screens, reached by its Ghidra address the way
// the sibling store views (for example StorePackView) pull it in.
extern const CGFloat g_dLayoutMetricThirtyTwo; // @ghidraAddress 0x2ee9b0 (32.0)

// Tune-cell background image names. Index 0 (light) is used for the top two rows and index 1 (dark)
// for the bottom two. @c setBG: clamps its argument into this range.
static NSString *const kTuneCellBackgroundImageNames[] = {
    @"09_store/store_pack_bg_1",
    @"09_store/store_pack_bg_2",
};

// Sample-button state images.
static NSString *const kSampleIdleImageName = @"09_store/store_sample_1";
static NSString *const kSamplePlayingImageName = @"09_store/store_sample_2";

// The iTunes-link button image.
static NSString *const kITunesLinkImageName = @"09_store/store_itunes";

// The extend-note cross-sell badge image.
static NSString *const kExtendNoteBadgeImageName = @"09_store/store_sp";

// The difficulty-levels label format ("LEVEL:  %d / %d / %d"). @ghidraAddress 0x32d550.
static NSString *const kLevelsFormat = @"LEVEL:  %d / %d / %d";

// Jacket artwork frame.
static const CGFloat kArtworkOriginX = 18.0;
static const CGFloat kArtworkOriginY = 76.0; // @ghidraAddress 0x2eec58
static const CGFloat kArtworkSide = 110.0;   // @ghidraAddress 0x2eece0

// Name label frame.
static const CGFloat kNameOriginX = 18.0;
static const CGFloat kNameOriginY = 15.0;
static const CGFloat kSideLabelWidth = 244.0; // @ghidraAddress 0x3012d8
static const CGFloat kNameHeight = 22.0;

// Artist label frame.
static const CGFloat kArtistOriginY = 35.0; // @ghidraAddress 0x2eeca8
static const CGFloat kArtistHeight = 20.0;

// Levels label frame.
static const CGFloat kLevelsOriginX = 146.0; // @ghidraAddress 0x3010e8
static const CGFloat kLevelsOriginY = 171.0; // @ghidraAddress 0x301860
static const CGFloat kLevelsWidth = 160.0;   // @ghidraAddress 0x2eea38
static const CGFloat kLevelsHeight = 20.0;

// Sample-button frame.
static const CGFloat kSampleButtonOriginX = 277.0; // @ghidraAddress 0x301858
static const CGFloat kSampleButtonOriginY = 20.0;
static const CGFloat kSampleButtonHeight = 35.0; // reuses the artist-origin metric

// Link-button origin (its size comes from the intrinsic image size).
static const CGFloat kLinkButtonOriginX = 146.0; // @ghidraAddress 0x3010e8
static const CGFloat kLinkButtonOriginY = 120.0; // @ghidraAddress 0x2ef168

// The busy indicator's own frame, before it is centred on the sample button.
static const CGFloat kIndicatorSide = 20.0;

// Font point sizes.
static const CGFloat kNameFontSize = 16.0;
static const CGFloat kArtistFontSize = 13.0;
static const CGFloat kLevelsFontSize = 15.0;

// Artist label text colour (white component).
static const CGFloat kArtistTextWhite = 0.19607843458652496; // @ghidraAddress 0x2eeef8

// Levels label text colour components (a dark green-blue).
static const CGFloat kLevelsColorRed = 0.3333333333333333;    // @ghidraAddress 0x2eec78
static const CGFloat kLevelsColorGreen = 0.03529411926865578; // @ghidraAddress 0x2eec80
static const CGFloat kLevelsColorBlue = 0.47058823529411764;  // @ghidraAddress 0x2eec88

// Jacket layer shadow and border parameters.
static const CGFloat kArtworkBorderWidth = 1.0;
static const CGFloat kArtworkShadowOffset = 2.0;
static const CGFloat kArtworkShadowOpacity = 0.6000000238418579; // @ghidraAddress 0x2ec6b8
static const CGFloat kArtworkShadowRadius = 2.0;

// Tune-cell background stretchable-image cap size.
static const NSInteger kBackgroundCap = 4;

// The centre-scaling factor used to place the busy indicator over the sample button.
static const CGFloat kCentreScale = 0.5;

// The index of the light tune-cell background, and the highest valid index into
// kTuneCellBackgroundImageNames. Any @c setBG: argument above this clamps to the dark background.
static const int kTuneCellBackgroundLight = 0;
static const int kTuneCellBackgroundMaxIndex = 1;

/**
 * Creates and returns a transparent (clear-background) UILabel with the given frame.
 * @ghidraAddress 0xfc72c
 */
static UILabel *CreateClearLabelWithFrame(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, height)];
    label.opaque = NO;
    label.backgroundColor = UIColor.clearColor;
    return label;
}

// The class acts as the delegate for its own cross-sell alert even though the binary adopts no
// formal protocols.
@interface StorePackMusicView () <UIAlertViewDelegate>
@end

@implementation StorePackMusicView

#pragma mark - Initialisation

/** @ghidraAddress 0xfb4ec */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return self;
    }

    UIImageView *background = [[UIImageView alloc] initWithFrame:self.bounds];
    [self addSubview:background];
    self.bg = background;

    self.artworkView = [[StoreImageView alloc]
        initWithFrame:CGRectMake(kArtworkOriginX, kArtworkOriginY, kArtworkSide, kArtworkSide)];
    self.artworkView.backgroundColor = UIColor.whiteColor;
    self.artworkView.layer.borderWidth = kArtworkBorderWidth;
    self.artworkView.layer.borderColor = UIColor.whiteColor.CGColor;
    self.artworkView.layer.shadowOffset = CGSizeMake(kArtworkShadowOffset, kArtworkShadowOffset);
    self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.artworkView.layer.shadowOpacity = kArtworkShadowOpacity;
    self.artworkView.layer.shadowRadius = kArtworkShadowRadius;
    self.artworkView.layer.shouldRasterize = YES;

    self.labelName =
        CreateClearLabelWithFrame(kNameOriginX, kNameOriginY, kSideLabelWidth, kNameHeight);
    self.labelName.font = [UIFont boldSystemFontOfSize:kNameFontSize];

    self.labelArtist =
        CreateClearLabelWithFrame(kNameOriginX, kArtistOriginY, kSideLabelWidth, kArtistHeight);
    self.labelArtist.font = [UIFont systemFontOfSize:kArtistFontSize];
    self.labelArtist.textColor = [UIColor colorWithWhite:kArtistTextWhite alpha:1.0];

    self.buttonSample = [UIButton buttonWithType:UIButtonTypeCustom];
    self.buttonSample.frame = CGRectMake(
        kSampleButtonOriginX, kSampleButtonOriginY, g_dLayoutMetricThirtyTwo, kSampleButtonHeight);
    self.buttonSample.contentMode = UIViewContentModeScaleAspectFit;
    [self.buttonSample setImage:[UIImage imageWithName:kSampleIdleImageName]
                       forState:UIControlStateNormal];

    self.indicatorSample = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, kIndicatorSide, kIndicatorSide)];
    self.indicatorSample.center = CGPointMake(self.buttonSample.frame.size.width * kCentreScale,
                                              self.buttonSample.frame.size.height * kCentreScale);
    self.indicatorSample.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    self.indicatorSample.hidesWhenStopped = YES;
    [self.buttonSample addSubview:self.indicatorSample];

    self.buttonLink = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *linkImage = [UIImage imageWithName:kITunesLinkImageName];
    self.buttonLink.frame = CGRectMake(
        kLinkButtonOriginX, kLinkButtonOriginY, linkImage.size.width, linkImage.size.height);
    [self.buttonLink setBackgroundImage:linkImage forState:UIControlStateNormal];

    self.labelLevels =
        CreateClearLabelWithFrame(kLevelsOriginX, kLevelsOriginY, kLevelsWidth, kLevelsHeight);
    self.labelLevels.font = [UIFont boldSystemFontOfSize:kLevelsFontSize];
    self.labelLevels.textColor = [UIColor colorWithRed:kLevelsColorRed
                                                 green:kLevelsColorGreen
                                                  blue:kLevelsColorBlue
                                                 alpha:1.0];

    [self addSubview:self.artworkView];
    [self addSubview:self.labelName];
    [self addSubview:self.labelArtist];
    [self addSubview:self.labelLevels];
    [self addSubview:self.buttonSample];
    [self addSubview:self.buttonLink];

    // The badge overlays the artwork's right edge, spanning from the artwork's top down to its
    // bottom.
    self.iconSpView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0,
                                                 self.artworkView.y,
                                                 self.artworkView.x + self.artworkView.width,
                                                 self.artworkView.height - self.artworkView.y)];

    UIImageView *badgeImageView =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kExtendNoteBadgeImageName]];
    badgeImageView.frame = CGRectMake(0.0,
                                      self.iconSpView.height - badgeImageView.height,
                                      badgeImageView.width,
                                      badgeImageView.height);
    [self.iconSpView addSubview:badgeImageView];
    [self addSubview:self.iconSpView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(tapSp)];
    [self.iconSpView addGestureRecognizer:tap];

    return self;
}

#pragma mark - Content

/** @ghidraAddress 0xfc814 */
- (void)setInfo:(StoreMusicInfo *)info {
    if (info == nil) {
        self.labelName.text = nil;
        self.labelArtist.text = nil;
        self.labelLevels.text = nil;
        self.artworkView.image = nil;
        self.artworkView.imageURL = nil;
        self.buttonLink.hidden = YES;
        self.buttonSample.hidden = YES;
        self.iconSpView.hidden = YES;
        self.pid = 0;
        return;
    }

    self.labelName.text = info.name;
    self.labelArtist.text = info.artist;
    self.labelLevels.text =
        [NSString stringWithFormat:kLevelsFormat, info.lvBasic, info.lvMedium, info.lvHard];
    self.artworkView.image = nil;
    self.artworkView.imageURL = info.artworkURL;
    self.buttonSample.hidden = (info.sampleURL == nil);
    self.buttonLink.hidden = (info.itunesURL == nil);
    self.iconSpView.hidden = (info.extIDList == nil);
    self.pid = [info.extIDList[0] intValue];
}

/** @ghidraAddress 0xfd100 */
- (void)setBG:(BOOL)bg {
    int index = bg;
    if (index > kTuneCellBackgroundMaxIndex) {
        index = kTuneCellBackgroundMaxIndex;
    }
    if (index < kTuneCellBackgroundLight) {
        index = kTuneCellBackgroundLight;
    }
    UIImage *image = [[UIImage imageWithName:kTuneCellBackgroundImageNames[index]]
        stretchableImageWithLeftCapWidth:kBackgroundCap
                            topCapHeight:kBackgroundCap];
    self.bg.image = image;
}

#pragma mark - Sample-button state

/** @ghidraAddress 0xfce3c */
- (void)sampleStop {
    [self.indicatorSample stopAnimating];
    [self.buttonSample setImage:[UIImage imageWithName:kSampleIdleImageName]
                       forState:UIControlStateNormal];
}

/** @ghidraAddress 0xfcf28 */
- (void)sampleDownloading {
    [self.indicatorSample startAnimating];
    // The button keeps the idle image; only the spinner marks the downloading state, matching the
    // binary.
    [self.buttonSample setImage:[UIImage imageWithName:kSampleIdleImageName]
                       forState:UIControlStateNormal];
}

/** @ghidraAddress 0xfd014 */
- (void)samplePlaying {
    [self.indicatorSample stopAnimating];
    [self.buttonSample setImage:[UIImage imageWithName:kSamplePlayingImageName]
                       forState:UIControlStateNormal];
}

#pragma mark - Cross-sell badge

/** @ghidraAddress 0xfd208 */
- (void)tapSp {
    [[UIAlertView showMovePackDetailToExtendDetail:self] show];
}

#pragma mark - UIAlertViewDelegate

/** @ghidraAddress 0xfd26c */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)clickedButtonAtIndex {
    if (clickedButtonAtIndex == 1 && self.pid != 0) {
        [self.parent switchToSpecialStore:[NSNumber numberWithInt:self.pid]];
    }
}

/** @ghidraAddress 0xfd35c */
- (void)alertViewCancel:(UIAlertView *)alertViewCancel {
}

/** @ghidraAddress 0xfd360 */
- (void)didPresentAlertView:(UIAlertView *)didPresentAlertView {
    [UIAlertView
        setExclusiveTouchForView:[UIApplication sharedApplication]
                                     .keyWindow.rootViewController.presentedViewController.view];
}

@end
