#import "StoreDetailCopyrightCell.h"

#import "engineglobals.h"

static const CGFloat kLabelInset = 5.0;
static const CGFloat kLabelInitialHeight = 0.0;

// The binary loads the shared short-fade value (0x2ec718) directly as the label's white component.
static const CGFloat kLabelTextAlpha = 1.0;

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
