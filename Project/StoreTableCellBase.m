#import "StoreTableCellBase.h"

#import "StoreTableCellViewBase.h"

// The cell background and content-view background share a dark neutral grey (47/255).
static const CGFloat kCellBackgroundWhite = 0.18431372940540314;
static const CGFloat kCellBackgroundAlpha = 1.0;

@implementation StoreTableCellBase

/** @ghidraAddress 0x41fa4 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor colorWithWhite:kCellBackgroundWhite
                                                 alpha:kCellBackgroundAlpha];
        self.contentView.backgroundColor = [UIColor colorWithWhite:kCellBackgroundWhite
                                                             alpha:kCellBackgroundAlpha];
    }
    return self;
}

/** @ghidraAddress 0x42154 */
- (void)dealloc {
    self.leftView.delegate = nil;
    self.rightView.delegate = nil;
}

/** @ghidraAddress 0x42248 */
- (void)prepareForReuse {
    [super prepareForReuse];
    [self.leftView reset];
    [self.rightView reset];
}

@end
