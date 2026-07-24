//
//  StoreDialogView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class StoreDialogView). The frame maths
//  in -initWithFrame: and -layout: were verified against the arm64 disassembly: the decompiler
//  folds the frame width and height into pseudo-variables, and the subview positions read shared
//  cross-file double constants that are rebuilt here as named local constants.
//

#import "StoreDialogView.h"

#import "UIImage+RB.h"

// The panel's rounded-corner radius and drop-shadow radius, in points.
static const CGFloat kPanelCornerRadius = 8.0; // @ghidraAddress 0x4020000000000000
static const CGFloat kPanelShadowRadius = 8.0; // @ghidraAddress 0x4020000000000000

// The panel's grey border width, in points.
static const CGFloat kPanelBorderWidth = 2.0; // @ghidraAddress 0x4000000000000000

// The panel's drop-shadow opacity.
static const float kPanelShadowOpacity = 0.5f; // @ghidraAddress 0x3f000000

// The panel's translucent black background: white component 0 with 70% opacity. Rebuilt from the
// shared cross-file double at @0x2ec750 until the palette globals are recovered.
static const CGFloat kPanelBackgroundWhite = 0.0;
static const CGFloat kPanelBackgroundAlpha = 0.7;

// The panel keeps its size fixed and stays centred: it flexes the left, right, top, and bottom
// margins. @ghidraAddress 0x310460 (value 45).
static const UIViewAutoresizing kPanelAutoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

// The activity indicator's square bounds size, in points. @ghidraAddress 0x2ee950 (40.0).
static const CGFloat kIndicatorSize = 40.0;

// The activity indicator sits at 20% of the panel height. @ghidraAddress 0x2eedc0 (0.2).
static const CGFloat kIndicatorCenterYRatio = 0.2;

// The message label spans the panel width less this inset, and is this tall. @ghidraAddress
// 0x310460's neighbour -30.0 (an immediate) and 24.0 (an immediate).
static const CGFloat kLabelWidthInset = 30.0; // @ghidraAddress -0x3fc2000000000000
static const CGFloat kLabelHeight = 24.0;     // @ghidraAddress 0x4038000000000000

// The message label's font size, in points. @ghidraAddress 0x4032000000000000 (18.0).
static const CGFloat kLabelFontSize = 18.0;

// The progress bar's left inset, height, and the panel-width inset that sets its width; it sits
// ten points below the panel's vertical centre.
static const CGFloat kProgressLeft = 30.0;       // @ghidraAddress 0x403e000000000000
static const CGFloat kProgressHeight = 11.0;     // @ghidraAddress 0x4026000000000000
static const CGFloat kProgressWidthInset = 60.0; // @ghidraAddress 0x300fc8 (-60.0)
static const CGFloat kProgressCenterYOffset = 10.0;

// The abort button's stretchable background caps, its fixed width, and its centre as a fraction of
// the panel height.
static const NSInteger kAbortButtonCapWidth = 6;      // @ghidraAddress 0x6
static const NSInteger kAbortButtonCapHeight = 6;     // @ghidraAddress 0x6
static const CGFloat kAbortButtonWidth = 140.0;       // @ghidraAddress 0x2ec6c0 (140.0)
static const CGFloat kAbortButtonCenterYRatio = 0.83; // @ghidraAddress 0x301818 (0.83)

// The abort button's title font size, in points. @ghidraAddress 0x4034000000000000 (20.0).
static const CGFloat kAbortButtonFontSize = 20.0;

// The abort button title's drop shadow: offset one point up, black at 60% opacity.
static const CGFloat kAbortTitleShadowOffsetY = -1.0; // @ghidraAddress -0x4010000000000000
static const CGFloat kAbortTitleShadowWhite = 0.0;
static const CGFloat kAbortTitleShadowAlpha = 0.6; // @ghidraAddress 0x2ec708 (0.6)

// The abort button's stretchable background artwork.
static NSString *const kAbortButtonImageName = @"09_store/store_btn_abort";

// The centre of the panel's width.
static const CGFloat kHalfScale = 0.5; // @ghidraAddress 0x3fe0000000000000

// The initial progress value.
static const float kProgressReset = 0.0f;

@implementation StoreDialogView

#pragma mark - Lifecycle

/** @ghidraAddress 0xf10ec */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    const CGFloat width = frame.size.width;
    const CGFloat height = frame.size.height;

    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
        [self respondsToSelector:@selector(contentScaleFactor)]) {
        self.contentScaleFactor = [UIScreen mainScreen].scale;
    }

    self.opaque = NO;

    CALayer *layer = self.layer;
    layer.cornerRadius = kPanelCornerRadius;
    layer.borderColor = UIColor.grayColor.CGColor;
    layer.borderWidth = kPanelBorderWidth;
    layer.shadowRadius = kPanelShadowRadius;
    layer.shadowOffset = CGSizeZero;
    layer.shadowOpacity = kPanelShadowOpacity;
    layer.shouldRasterize = YES;

    self.backgroundColor = [UIColor colorWithWhite:kPanelBackgroundWhite
                                             alpha:kPanelBackgroundAlpha];
    self.autoresizingMask = kPanelAutoresizingMask;

    self.indicatorView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.indicatorView.bounds = CGRectMake(0, 0, kIndicatorSize, kIndicatorSize);
    self.indicatorView.center =
        CGPointMake(width * kHalfScale, (CGFloat)(int)(height * kIndicatorCenterYRatio));
    [self addSubview:self.indicatorView];

    self.labelMessage =
        [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width - kLabelWidthInset, kLabelHeight)];
    self.labelMessage.backgroundColor = UIColor.clearColor;
    self.labelMessage.textColor = UIColor.whiteColor;
    self.labelMessage.textAlignment = NSTextAlignmentCenter;
    self.labelMessage.numberOfLines = 1;
    self.labelMessage.font = [UIFont systemFontOfSize:kLabelFontSize];
    [self addSubview:self.labelMessage];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    const CGFloat progressTop = (CGFloat)((int)(height * kHalfScale) + (int)kProgressCenterYOffset);
    self.progressView.frame =
        CGRectMake(kProgressLeft, progressTop, width - kProgressWidthInset, kProgressHeight);
    self.progressView.progress = kProgressReset;
    [self addSubview:self.progressView];

    UIImage *abortImage = [[UIImage imageWithName:kAbortButtonImageName]
        stretchableImageWithLeftCapWidth:kAbortButtonCapWidth
                            topCapHeight:kAbortButtonCapHeight];

    self.buttonAbort = [UIButton buttonWithType:UIButtonTypeCustom];
    self.buttonAbort.frame = CGRectMake(0, 0, kAbortButtonWidth, abortImage.size.height);
    self.buttonAbort.titleLabel.textColor = UIColor.whiteColor;
    self.buttonAbort.titleLabel.font = [UIFont boldSystemFontOfSize:kAbortButtonFontSize];
    self.buttonAbort.titleLabel.shadowOffset = CGSizeMake(0, kAbortTitleShadowOffsetY);
    [self.buttonAbort setTitleShadowColor:[UIColor colorWithWhite:kAbortTitleShadowWhite
                                                            alpha:kAbortTitleShadowAlpha]
                                 forState:UIControlStateNormal];
    [self.buttonAbort setBackgroundImage:abortImage forState:UIControlStateNormal];
    [self.buttonAbort setTitle:NSLocalizedString(@"Abort", nil) forState:UIControlStateNormal];
    [self.buttonAbort addTarget:self
                         action:@selector(btnAbort:)
               forControlEvents:UIControlEventTouchUpInside];
    self.buttonAbort.center =
        CGPointMake(width * kHalfScale, (CGFloat)(int)(height * kAbortButtonCenterYRatio));
    [self addSubview:self.buttonAbort];

    return self;
}

#pragma mark - Layout

/** @ghidraAddress 0xf1ccc */
- (void)layout:(BOOL)messageOnly {
    const CGRect bounds = self.frame;
    const CGFloat width = bounds.size.width;
    const CGFloat height = bounds.size.height;

    self.progressView.progress = kProgressReset;
    self.progressView.hidden = messageOnly;
    self.buttonAbort.hidden = messageOnly;

    // When only the message is shown the label drops below centre; otherwise it rises above it.
    const CGFloat labelCenterYOffset =
        messageOnly ? kProgressCenterYOffset : -kProgressCenterYOffset;
    self.labelMessage.center =
        CGPointMake(width * kHalfScale, height * kHalfScale + labelCenterYOffset);
}

#pragma mark - Actions

/** @ghidraAddress 0xf1eb8 */
- (void)btnAbort:(id)sender {
    if ([self.delegate respondsToSelector:@selector(storeDialogCancel:)]) {
        [self.delegate performSelector:@selector(storeDialogCancel:) withObject:self];
    }
}

@end
