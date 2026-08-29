#import "StorePromotionTableCell.h"

#import "StorePromotionView.h"

// The tag RBStorePageViewController assigns to the promotion carousel it adds to this cell.
static const NSInteger kTagPromotionView = 10101;

@implementation StorePromotionTableCell

- (void)layoutSubviews {
    [super layoutSubviews];
    StorePromotionView *promotionView =
        (StorePromotionView *)[self.contentView viewWithTag:kTagPromotionView];
    if (promotionView != nil) {
        promotionView.frame = self.contentView.bounds;
        [promotionView setImageViewSize:self.bounds.size];
    }
}

@end
