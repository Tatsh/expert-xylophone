#import "BannerView.h"

#import "StorePackInfo.h"

@implementation BannerView

#pragma mark - Setup

/** @ghidraAddress 0xff624 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = UIColor.grayColor;

        self.imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.imageView.opaque = NO;
        self.imageView.backgroundColor = UIColor.clearColor;
        self.imageView.contentMode = UIViewContentModeScaleToFill;
        self.imageView.userInteractionEnabled = NO;
        self.imageView.clipsToBounds = YES;
        self.isRemoveWaiting = NO;
        [self addSubview:self.imageView];
    }
    return self;
}

#pragma mark - Appearance

/** @ghidraAddress 0xff910 */
- (void)setCornerRadius:(CGFloat)cornerRadius {
    self.layer.cornerRadius = cornerRadius;
    self.imageView.layer.cornerRadius = cornerRadius;
}

#pragma mark - Sample playback

/** @ghidraAddress 0xff9c8 */
- (void)startSamplePlay {
    self.isSamplePlaying = YES;
}

/** @ghidraAddress 0xff9d8 */
- (void)stopSamplePlay {
    self.isSamplePlaying = NO;
}

/** @ghidraAddress 0xff9e8 */
- (BOOL)getIsSamplePlaying {
    return self.isSamplePlaying;
}

@end
