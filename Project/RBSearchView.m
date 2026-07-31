#import "RBSearchView.h"

#import "AppDelegate.h"
#import "RBSearchMapView.h"
#import "RBSettingView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"

// Asset names for the current-position button, in the search image directory.
static NSString *const kSearchCurrentPositionImageName = @"06_search/sear_me";
static NSString *const kSearchCurrentPositionSelectedImageName = @"06_search/sear_me_eff";

// The current-position button, sized 32 points wide and 28 points tall, is anchored from the base
// panel's right and top edges. The height is the only one of these the binary supplies as an
// immediate rather than a constant-pool load.
static const CGFloat kCurrentPositionButtonWidth = 32.0; // @ghidraAddress 0x2ee9b0
static const CGFloat kCurrentPositionButtonHeight = 28.0;
static const CGFloat kCurrentPositionButtonRightInset = 606.0; // @ghidraAddress 0x301630
static const CGFloat kCurrentPositionButtonBottomInsetLimelight = 182.0; // @ghidraAddress 0x2ee9f0
static const CGFloat kCurrentPositionButtonBottomInsetColette = 180.0; // @ghidraAddress 0x2ee970
static const CGFloat kCurrentPositionButtonBottomInsetDefault = 193.0; // @ghidraAddress 0x301638

// The map fills the content view below a themed top inset, its height reduced by the same inset.
// The binary spells the height reduction as an addition of the negated inset.
static const CGFloat kMapTopInsetThemed = 50.0; // @ghidraAddress 0x2ec6e0
static const CGFloat kMapTopInsetDefault = 35.0; // @ghidraAddress 0x2eeca8

@implementation RBSearchView {
    // The theme captured at build time, selecting the current-position button and map geometry.
    RBUserSettingDataTheme _thema;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.musicMenuPopupViewType = RBMusicMenuPopupViewTypeSearch;
        [self setupView];
    }
    return self;
}

- (void)setupView {
    [super setupView];
    _thema = [RBUserSettingData sharedInstance].thema;

    self.currentPositionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.currentPositionButton setImage:[UIImage imageWithName:kSearchCurrentPositionImageName]
                                forState:UIControlStateNormal];
    [self.currentPositionButton
        setImage:[UIImage imageWithName:kSearchCurrentPositionSelectedImageName]
        forState:UIControlStateSelected];
    self.currentPositionButton.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;

    CGFloat buttonBottomInset;
    if (_thema == RBUserSettingDataThemeLimelight) {
        buttonBottomInset = kCurrentPositionButtonBottomInsetLimelight;
    } else if (_thema == RBUserSettingDataThemeColette) {
        buttonBottomInset = kCurrentPositionButtonBottomInsetColette;
    } else {
        buttonBottomInset = kCurrentPositionButtonBottomInsetDefault;
    }
    self.currentPositionButton.frame =
        CGRectMake(kCurrentPositionButtonRightInset - self.baseView.frame.origin.x,
                   buttonBottomInset - self.baseView.frame.origin.y,
                   kCurrentPositionButtonWidth,
                   kCurrentPositionButtonHeight);

    [self.currentPositionButton addTarget:self
                                   action:@selector(selectCurrentPosition:)
                         forControlEvents:UIControlEventTouchUpInside];
    [self.baseView addSubview:self.currentPositionButton];

    CGFloat mapTopInset;
    if (_thema == RBUserSettingDataThemeLimelight || _thema == RBUserSettingDataThemeColette) {
        mapTopInset = kMapTopInsetThemed;
    } else {
        mapTopInset = kMapTopInsetDefault;
    }
    CGRect mapFrame = CGRectMake(0,
                                 mapTopInset,
                                 self.contentView.bounds.size.width,
                                 self.contentView.bounds.size.height - mapTopInset);

    if (self.map) {
        self.map.frame = mapFrame;
    } else {
        self.map = [[RBSearchMapView alloc] initWithFrame:mapFrame];
        self.map.delegate = self;
    }
    [self.contentView addSubview:self.map];
}

#pragma mark - Animation

- (void)showAnimation {
    [super showAnimation];
    [self.map initialView];
}

- (void)hideAnimation {
    [[AppDelegate appDelegate] setIsShowedMap:NO];
    [self.map viewDidDisappear];
    [super hideAnimation];
}

#pragma mark - Actions

- (void)selectCurrentPosition:(id)sender {
    [self.map toggleTrackingMode];
}

#pragma mark - SearchMapViewDelegate

- (void)didChangeUserTracking:(BOOL)tracking {
    self.currentPositionButton.selected = tracking;
}

@end
