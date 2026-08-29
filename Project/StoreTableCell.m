#import "StoreTableCell.h"

static const CGFloat kCellBackgroundWhite = 47.0f / 255.0f;
static const CGFloat kCellBackgroundAlpha = 1.0;

static const CGFloat kPackTileWidth = 365.0;
static const CGFloat kPackTileHeight = 140.0;

@implementation StoreTableCell

/** @ghidraAddress 0x1042c0 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor colorWithWhite:kCellBackgroundWhite
                                                 alpha:kCellBackgroundAlpha];
        self.contentView.backgroundColor = [UIColor colorWithWhite:kCellBackgroundWhite
                                                             alpha:kCellBackgroundAlpha];
        self.leftPackView = [[StorePackView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, kPackTileWidth, kPackTileHeight)];
        self.rightPackView = [[StorePackView alloc]
            initWithFrame:CGRectMake(kPackTileWidth, 0.0, kPackTileWidth, kPackTileHeight)];
        [self.contentView addSubview:self.leftPackView];
        [self.contentView addSubview:self.rightPackView];
    }
    return self;
}

/** @ghidraAddress 0x104628 */
- (void)dealloc {
    self.leftPackView.delegate = nil;
    self.rightPackView.delegate = nil;
}

/** @ghidraAddress 0x10471c */
- (void)prepareForReuse {
    [super prepareForReuse];
    self.leftPackView.artwork = nil;
    self.rightPackView.artwork = nil;
}

@end
