#import "RBStoreManageHeaderCell.h"

#import "neEngineBridge.h"

// The header height for the pad (wide) and phone (narrow) iPad idioms.
static const CGFloat kHeaderHeightPad = 30.0;
static const CGFloat kHeaderHeightPhone = 25.0;

// The trailing inset reserved beside the expand/collapse indicator on the phone layout; the pad
// layout uses the wide slider-row height metric instead.
static const CGFloat kTrailingInsetPhone = 25.0;

// The leading inset for the title label.
static const CGFloat kTitleLeadingInset = 15.0;

// The x origin the title label's own frame starts at before sizing.
static const CGFloat kTitleInitialOriginX = 30.0;

// The label font point size.
static const CGFloat kLabelFontSize = 14.0;

// The background and label opacity.
static const CGFloat kBackgroundAlpha = 1.0;

// The full opacity used by every reconstructed colour.
static const CGFloat kColorAlpha = 1.0;

// The alternating section-background white values, indexed by section parity.
static const CGFloat kBackgroundWhiteEven = 1.0;
static const CGFloat kBackgroundWhiteOdd = 0.9700000286102295;

// The label text colour components.
static const CGFloat kLabelColorRed = 0.0117647061124444;
static const CGFloat kLabelColorGreen = 0.47843137383461;
static const CGFloat kLabelColorBlue = 1.0;

// The factor that centres a label vertically within the header.
static const CGFloat kVerticalCenterFactor = 0.5;

// The number of distinct alternating background colours.
static const NSInteger kBackgroundColorCount = 2;

// The placeholder glyphs the labels are seeded with so that -sizeToFit measures a representative
// size; the controller replaces the text afterwards. The indicator is measured with a downward
// triangle and the title with an ideographic space.
static NSString *const kIndicatorSizingGlyph = @"▼";
static NSString *const kTitleSizingGlyph = @"　";

@implementation RBStoreManageHeaderCell

/** @ghidraAddress 0x1cd7c8 */
- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier
                                  frame:(CGRect)frame
                                section:(NSInteger)section
                             withTarget:(id)target {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self == nil) {
        return nil;
    }

    BOOL isPad = IsPad();
    CGFloat width = frame.size.width;
    CGFloat headerHeight = isPad ? kHeaderHeightPad : kHeaderHeightPhone;
    CGFloat trailingInset = isPad ? g_dSliderRowHeightWide : kTrailingInsetPhone;

    self.frame = CGRectMake(0, 0, width, headerHeight);
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:target action:@selector(toggleOpen:)];
    [self addGestureRecognizer:tap];

    UIView *background = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, headerHeight)];
    CGFloat backgroundWhite[] = {kBackgroundWhiteEven, kBackgroundWhiteOdd};
    background.backgroundColor =
        [UIColor colorWithWhite:backgroundWhite[section & (kBackgroundColorCount - 1)]
                          alpha:kBackgroundAlpha];
    background.alpha = kBackgroundAlpha;
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview:background];

    UIColor *labelColor = [UIColor colorWithRed:kLabelColorRed
                                          green:kLabelColorGreen
                                           blue:kLabelColorBlue
                                          alpha:kColorAlpha];

    UILabel *indicatorLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(0, 0, headerHeight, headerHeight)];
    indicatorLabel.textColor = labelColor;
    indicatorLabel.font = [UIFont boldSystemFontOfSize:kLabelFontSize];
    indicatorLabel.text = kIndicatorSizingGlyph;
    [indicatorLabel sizeToFit];
    CGFloat indicatorWidth = indicatorLabel.frame.size.width;
    CGFloat indicatorHeight = indicatorLabel.frame.size.height;
    indicatorLabel.frame = CGRectMake(width - indicatorWidth - trailingInset,
                                      (headerHeight - indicatorHeight) * kVerticalCenterFactor,
                                      trailingInset + indicatorWidth,
                                      indicatorHeight);
    indicatorLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self addSubview:indicatorLabel];
    self.openedLabel = indicatorLabel;

    UILabel *titleLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(kTitleInitialOriginX, 0, headerHeight, headerHeight)];
    titleLabel.textColor = labelColor;
    titleLabel.font = [UIFont boldSystemFontOfSize:kLabelFontSize];
    titleLabel.text = kTitleSizingGlyph;
    [titleLabel sizeToFit];
    CGFloat titleWidth = titleLabel.frame.size.width;
    CGFloat titleHeight = titleLabel.frame.size.height;
    titleLabel.frame = CGRectMake(kTitleLeadingInset,
                                  (headerHeight - titleHeight) * kVerticalCenterFactor,
                                  titleWidth,
                                  titleHeight);
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [self addSubview:titleLabel];
    self.titleLabel = titleLabel;

    return self;
}

@end
