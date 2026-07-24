#import "StoreDetailCopyrightCell.h"

#import "neEngineBridge.h"

// The wrap width of the copyright and terms label, shared with the store extend-note cell. Reached
// by its Ghidra address as the other reconstructed store views do; it is not yet in the engine
// bridge header.
extern const double g_dStoreDetailCopyrightLabelWidth; // @ghidraAddress 0x2eea30 (310.0)

// The label is inset a uniform 5 points from the cell's top-left; its width is fixed and its height
// is grown by the table's row-height measurement, so it starts flat.
static const CGFloat kLabelInset = 5.0;
static const CGFloat kLabelInitialHeight = 0.0;

// The label text is drawn at full opacity; the mid-grey white component is the shared short-fade
// value (@c g_dAudioManagerResumeFadeInTime, 0x2ec718) that the binary loads directly.
static const CGFloat kLabelTextAlpha = 1.0;

// The label wraps across as many lines as needed.
static const NSInteger kLabelUnlimitedLines = 0;

@implementation StoreDetailCopyrightCell

/** @ghidraAddress 0xec604 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        self.labelCopyright =
            [[UILabel alloc] initWithFrame:CGRectMake(kLabelInset,
                                                      kLabelInset,
                                                      g_dStoreDetailCopyrightLabelWidth,
                                                      kLabelInitialHeight)];
        self.labelCopyright.backgroundColor = UIColor.clearColor;
        self.labelCopyright.textColor = [UIColor colorWithWhite:g_dAudioManagerResumeFadeInTime
                                                          alpha:kLabelTextAlpha];
        self.labelCopyright.numberOfLines = kLabelUnlimitedLines;
        self.labelCopyright.lineBreakMode = NSLineBreakByWordWrapping;
        [self.contentView addSubview:self.labelCopyright];
    }
    return self;
}

@end
