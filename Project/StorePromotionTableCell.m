#import "StorePromotionTableCell.h"

#import "StorePromotionView.h"

// The tag the hosting RBStorePageViewController assigns to the promotion carousel subview it adds
// to this cell's content view. Matched here to locate the carousel during layout.
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
