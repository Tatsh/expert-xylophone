#import "StoreExtendNoteCell.h"

// The two product views are a fixed 364x140 point rectangle each; the right view sits immediately
// to the right of the left view.
static const CGFloat kProductViewWidth = 364.0;
static const CGFloat kProductViewHeight = 140.0;

@implementation StoreExtendNoteCell

/** @ghidraAddress 0xfdb8 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.leftView = [[StoreExtendNoteCellView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, kProductViewWidth, kProductViewHeight)];
        self.rightView = [[StoreExtendNoteCellView alloc]
            initWithFrame:CGRectMake(
                              kProductViewWidth, 0.0, kProductViewWidth, kProductViewHeight)];
        [self.contentView addSubview:self.leftView];
        [self.contentView addSubview:self.rightView];
    }
    return self;
}

#pragma mark - Background (flattened from StoreTableCellBase)

- (void)setBgImage:(UIImage *)image {
    // StoreTableCellBase's implementation, which this cell inherits in the binary, forwards to the
    // base's background image view; StoreExtendNoteCellPhone (0x1c1fa0) does the same through its
    // own. The base is not reconstructed, so the assignment is made against the flattened property.
    self.backGroundImageView.image = image;
}

- (void)setBgColor:(UIColor *)color {
    // The binary's body is empty, matching StoreExtendNoteCellPhone::setBgColor: (0x1c202c): the
    // extend-note cells take no background tint.
    (void)color;
}

@end
