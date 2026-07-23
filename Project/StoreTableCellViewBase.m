#import "StoreTableCellViewBase.h"

#import "UIImage+RB.h"

// The "new" corner badge artwork.
static NSString *const kIconNewImageName = @"09_store/store_new";

@implementation StoreTableCellViewBase

/** @ghidraAddress 0x1777bc */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIImageView *backGroundImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        backGroundImageView.userInteractionEnabled = YES;
        backGroundImageView.exclusiveTouch = YES;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [backGroundImageView addGestureRecognizer:tap];
        self.backGroundImageView = backGroundImageView;

        self.iconNew =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kIconNewImageName]];

        [self addSubview:self.backGroundImageView];
        [self addSubview:self.iconNew];
    }
    return self;
}

/** @ghidraAddress 0x177a38 */
- (void)dealloc {
    self.delegate = nil;
}

#pragma mark - Content

/** @ghidraAddress 0x177ac0 */
- (void)setBgImage:(UIImage *)bgImage {
    self.backGroundImageView.image = bgImage;
}

/** @ghidraAddress 0x177b4c */
- (void)setIsNew:(BOOL)isNew {
    self.iconNew.hidden = !isNew;
    if (!self.iconNew.hidden) {
        [self bringSubviewToFront:self.iconNew];
    }
}

/** @ghidraAddress 0x177d20 */
- (void)reset {
}

#pragma mark - Selection

/** @ghidraAddress 0x177c40 */
- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if ([self.delegate respondsToSelector:@selector(cellViewSelected:)]) {
        [self.delegate performSelector:@selector(cellViewSelected:) withObject:self];
    }
}

@end
