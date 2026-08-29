#import "RBErosionMarkUpdaterScoreView.h"

#import "deviceenvironment.h"
#import "engineglobals.h"

// Also used as the fade animation duration.
// @ghidraAddress 0x2ec718
static const double kBackdropAlpha = 0.3;

// @ghidraAddress 0x308cd8
static const CGFloat kDialogHeightMetric = 260.0;

// @ghidraAddress 0x2eec40
static const CGFloat kTitleBarHeightMetric = 44.0;

// @ghidraAddress 0x301000
static const CGFloat kMessageRowHeightMetric = 40.0;

static const CGFloat kDialogCornerRadius = 5.0;

static const float kPanelShadowOpacity = 0.5f;

static const CGFloat kPanelShadowExtent = 1.0;

static const CGFloat kLabelWidthInset = 10.0;

static const CGFloat kLabelTopInset = 5.0;

static const CGFloat kMinDialogOriginY = 10.0;

static const CGFloat kDialogOriginPadDivisor = 2.0;
static const CGFloat kDialogOriginPhoneDivisor = 4.0;

static const CGFloat kTitleFontSizePad = 18.0;
static const CGFloat kTitleFontSizePhone = 14.0;

static const CGFloat kMessageFontSizePad = 14.0;
static const CGFloat kMessageFontSizePhone = 11.0;

static const UIViewAutoresizing kBackdropAutoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
static const UIViewAutoresizing kPanelAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

@implementation RBErosionMarkUpdaterScoreView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame delegate:(id)delegate {
    self = [super initWithFrame:frame];
    if (self) {
        self.displayRate = IsPad() ? 1.0 : g_dTranslucentAlpha;
        self.delegate = delegate;
        self.autoresizingMask = kBackdropAutoresizingMask;
        [self setupView];
    }
    return self;
}

- (void)dealloc {
}

#pragma mark Setup

- (void)setupView {
    UIView *backdrop = [[UIView alloc] initWithFrame:self.frame];
    // The original used the full component call with alpha 0.3, so keep it rather than blackColor.
    backdrop.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:kBackdropAlpha];
    backdrop.autoresizingMask = kBackdropAutoresizingMask;
    [self addSubview:backdrop];

    CGFloat dialogHeight = self.displayRate * kDialogHeightMetric;
    CGFloat centringDivisor = IsPad() ? kDialogOriginPadDivisor : kDialogOriginPhoneDivisor;
    CGFloat dialogOriginY = self.frame.size.height / centringDivisor - dialogHeight * 0.5;
    if (dialogOriginY < kMinDialogOriginY) {
        dialogOriginY = kMinDialogOriginY;
    }
    CGFloat dialogWidth = self.displayRate * g_dMascotMessageMaxWidthPad;
    CGFloat dialogOriginX = self.frame.size.width * 0.5 - dialogWidth * 0.5;

    UIView *panel = [[UIView alloc]
        initWithFrame:CGRectMake(dialogOriginX, dialogOriginY, dialogWidth, dialogHeight)];
    panel.layer.cornerRadius = kDialogCornerRadius;
    panel.layer.masksToBounds = YES;
    panel.backgroundColor = UIColor.whiteColor;
    panel.autoresizingMask = kPanelAutoresizingMask;
    self.dialogView = panel;
    [self addSubview:panel];

    UIView *titleBar = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, dialogWidth, self.displayRate * kTitleBarHeightMetric)];
    titleBar.backgroundColor = UIColor.whiteColor;
    titleBar.layer.shadowOffset = CGSizeMake(0.0, kPanelShadowExtent);
    titleBar.layer.shadowOpacity = kPanelShadowOpacity;
    titleBar.layer.shadowRadius = kPanelShadowExtent;
    [panel addSubview:titleBar];

    UILabel *title =
        [[UILabel alloc] initWithFrame:CGRectMake(kLabelTopInset,
                                                  kLabelTopInset,
                                                  dialogWidth - kLabelWidthInset,
                                                  self.displayRate * kTitleBarHeightMetric)];
    title.text = @"";
    title.font = [UIFont boldSystemFontOfSize:IsPad() ? kTitleFontSizePad : kTitleFontSizePhone];
    title.textAlignment = NSTextAlignmentCenter;
    self.titleLabel = title;
    [panel addSubview:title];

    UILabel *message = [[UILabel alloc]
        initWithFrame:CGRectMake(kLabelTopInset,
                                 self.displayRate * kTitleBarHeightMetric + kLabelTopInset,
                                 dialogWidth - kLabelWidthInset,
                                 self.displayRate * g_dSliderRowHeightWide)];
    message.text = @"";
    message.font =
        [UIFont boldSystemFontOfSize:IsPad() ? kMessageFontSizePad : kMessageFontSizePhone];
    message.textColor = UIColor.redColor;
    message.textAlignment = NSTextAlignmentCenter;
    self.messageLabel = message;
    [panel addSubview:message];

    CGFloat buttonWidth = panel.frame.size.width * 0.5;
    CGFloat buttonHeight = self.displayRate * kMessageRowHeightMetric;
    CGFloat buttonOriginY = panel.frame.size.height - self.displayRate * kMessageRowHeightMetric;

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.enabled = YES;
    cancelButton.exclusiveTouch = YES;
    cancelButton.layer.borderWidth = 1.0;
    cancelButton.layer.borderColor = [UIColor colorWithWhite:g_dTranslucentAlpha alpha:1.0].CGColor;
    [cancelButton setTitle:g_pLocalizedCancel forState:UIControlStateNormal];
    cancelButton.frame = CGRectMake(0.0, buttonOriginY, buttonWidth, buttonHeight);
    [cancelButton addTarget:self.delegate
                     action:@selector(showAlertCancel)
           forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:cancelButton];
    self.leftButton = cancelButton;

    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.enabled = YES;
    confirmButton.exclusiveTouch = YES;
    confirmButton.layer.borderWidth = 1.0;
    confirmButton.layer.borderColor =
        [UIColor colorWithWhite:g_dTranslucentAlpha alpha:1.0].CGColor;
    [confirmButton setTitle:g_pLocalizedOK forState:UIControlStateNormal];
    confirmButton.frame = CGRectMake(buttonWidth, buttonOriginY, buttonWidth, buttonHeight);
    [confirmButton addTarget:self.delegate
                      action:@selector(showAlertConfirm)
            forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:confirmButton];
    self.rightButton = confirmButton;

    self.dialogView.alpha = 0.0;
}

#pragma mark Animation

- (void)showAnimation:(void (^)(void))completion {
    __weak RBErosionMarkUpdaterScoreView *weakSelf = self;
    [UIView animateWithDuration:kBackdropAlpha
        animations:^{
          /** @ghidraAddress 0x1425fc */
          weakSelf.dialogView.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x142694 */
          if (completion) {
              completion();
          }
        }];
}

- (void)hideAnimation:(void (^)(void))completion {
    __weak RBErosionMarkUpdaterScoreView *weakSelf = self;
    [UIView animateWithDuration:kBackdropAlpha
        animations:^{
          /** @ghidraAddress 0x1427f0 */
          weakSelf.dialogView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x142888 */
          if (completion) {
              completion();
          }
        }];
}

#pragma mark Removal

- (void)remove {
    self.delegate = nil;
    [self removeFromSuperview];
}

@end
