#import "RBCustomSelectCollectionCell.h"

#import "UIImage+RB.h"
#import "UIImageView+RB.h"

// The customize selection overlay image bundled with the app.
static NSString *const kSelectedOverlayImageName = @"04_customize/cus_sel_1";

@implementation RBCustomSelectCollectionCell

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIView *background = [[UIView alloc] initWithFrame:frame];
        self.backgroundView = background;

        self.itemButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.itemButton.userInteractionEnabled = NO;
        [self.backgroundView addSubview:self.itemButton];

        UIImage *overlayImage = [UIImage imageWithName:kSelectedOverlayImageName];
        self.selectedImageView = [[UIImageView alloc] initWithImage:overlayImage];
        self.selectedImageView.hidden = YES;
        [self.backgroundView addSubview:self.selectedImageView];

        self.exclusiveTouch = YES;
    }
    return self;
}

#pragma mark Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    // Centre the item button horizontally within the cell, keeping its own size.
    CGFloat cellWidth = self.frame.size.width;
    CGFloat buttonWidth = self.itemButton.frame.size.width;
    CGFloat buttonHeight = self.itemButton.frame.size.height;
    self.itemButton.frame =
        CGRectMake((int)((cellWidth - buttonWidth) * 0.5), 0.0, buttonWidth, buttonHeight);

    self.selectedImageView.center = self.backgroundView.center;
}

#pragma mark Reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.itemButton setImage:nil forState:UIControlStateNormal];
    self.itemSelected = NO;
}

#pragma mark State

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.itemButton.highlighted = highlighted;
}

- (void)setIsSelected:(BOOL)isSelected {
    _itemSelected = isSelected;
    if (isSelected) {
        self.selectedImageView.hidden = NO;
        [self.selectedImageView SetFlashEffectFast];
    } else {
        self.selectedImageView.hidden = YES;
        [self.selectedImageView RemoveFlashEffect];
    }
}

@end
