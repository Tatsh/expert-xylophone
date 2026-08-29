#import "StoreImageView.h"

#import "UIImage+RB.h"
#import "deviceenvironment.h"

static NSString *const kPlaceholderJacketName = @"09_store/store_jacket_110";

static const NSTimeInterval kArtworkFadeInDuration = 0.3;

static const CGFloat kHiddenAlpha = 0.0;
static const CGFloat kVisibleAlpha = 1.0;

static const CGFloat kNonRetinaScale = 1.0;

@implementation StoreImageView

#pragma mark - Lifecycle

/** @ghidraAddress 0xf3890 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.backgroundView.image = [UIImage imageWithName:kPlaceholderJacketName];
        [self addSubview:self.backgroundView];

        self.imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.imageView.alpha = kHiddenAlpha;
        [self addSubview:self.imageView];
    }
    return self;
}

/** @ghidraAddress 0xf4220 */
- (void)dealloc {
    if (self.imageDownloader) {
        [self.imageDownloader cancelDownload];
    }
}

#pragma mark - Public

/** @ghidraAddress 0xf3b44 */
- (void)startDownloadImage {
    if (!self.imageURL) {
        return;
    }
    if (self.imageDownloader) {
        return;
    }
    self.imageDownloader = [[ImageDownloader alloc] initWithGetURL:self.imageURL
                                                       unUseRetina:!GetIsRetinaFlag()];
    self.imageDownloader.delegate = self;
    [self.imageDownloader startDownload];
}

/** @ghidraAddress 0xf3e90 */
- (BOOL)loadedImage {
    return self.imageView.image != nil;
}

/** @ghidraAddress 0xf3cec */
- (void)unloadImage:(UIImage *)image {
    if (self.imageDownloader) {
        [self.imageDownloader cancelDownload];
        self.imageDownloader = nil;
    }
    [self.imageView setImage:image];
}

/**
 * Overrides @c UIImageView to clear the foreground artwork instead of showing @p image.
 *
 * The @p image argument is deliberately discarded: the binary always resets the foreground view to
 * an empty, transparent state, which is how a consumer clears the artwork before a fresh download.
 * @ghidraAddress 0xf3de4
 */
- (void)setImage:(UIImage *)image {
    [self.imageView setImage:nil];
    self.imageView.alpha = kHiddenAlpha;
}

#pragma mark - ImageDownloaderDelegate

/** @ghidraAddress 0xf3f00 */
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UIImage *image = [downloader getImage];
    if (image) {
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
            [UIScreen mainScreen].scale > kNonRetinaScale && image.scale > kNonRetinaScale) {
            self.contentScaleFactor = image.scale;
        }
        [self.imageView setImage:image];
        self.imageView.alpha = kHiddenAlpha;
        [UIView animateWithDuration:kArtworkFadeInDuration
                         animations:^{
                           /** @ghidraAddress 0xf4190 */
                           self.imageView.alpha = kVisibleAlpha;
                         }];
    }
    self.imageDownloader = nil;
}

/** @ghidraAddress 0xf4200 */
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    self.imageDownloader = nil;
}

@end
