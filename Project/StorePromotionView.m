#import "StorePromotionView.h"

#import "BannerView.h"
#import "Downloader.h"
#import "ImageDownloader.h"
#import "PagingScrollView.h"
#import "RBBGMManager.h"
#import "RBUserSettingData.h"
#import "StorePackInfo.h"
#import "deviceenvironment.h"

static NSString *const kPromotionKeyID = @"ID";
static NSString *const kPromotionKeyImageURL = @"ImageURL";
static NSString *const kPromotionKeyName = @"Name";
static NSString *const kPromotionKeySampleURL = @"SampleURL";
static NSString *const kPromotionKeyImage = @"image";

// @ghidraAddress 0x301088, 0x100301878, 0x100301880
static const CGFloat kPageInsetReference = -300.0;
static const CGFloat kBannerWidthReference = -292.0;
static const CGFloat kBannerHeightReference = -96.0;
static const CGFloat kCenterScale = 0.5;

static const CGFloat kPadPageOffsetX = 145.0;
static const CGFloat kPadBannerOffsetX = 20.0;
static const CGFloat kPadBannerOffsetY = 8.0;

static const CGFloat kBannerBackgroundWhite = 0.5;
static const CGFloat kBannerCornerRadius = 8.0;
static const CGFloat kBannerShadowOffsetHeight = 1.0;
static const CGFloat kBannerShadowOpacity = 0.8; // @ghidraAddress 0x2f856c
static const CGFloat kBannerShadowRadius = 1.0;

// The carousel holds two extra wrap-around banner copies so paging can loop seamlessly.
static const NSInteger kWrapAroundBannerCount = 2;

// @ghidraAddress 0x301890
static const CGFloat kBannerContentHeightRatio = 0.32876712328767121;

static const NSTimeInterval kPageAdvanceInterval = 2.0;

static const CGFloat kRotatedScrollViewWidth = 300.0;  // @ghidraAddress 0x2ee930
static const CGFloat kRotatedScrollViewHeight = 102.0; // @ghidraAddress 0x3012a8

static const NSUInteger kDownloaderCapacity = 32;

@implementation StorePromotionView {
    NSInteger m_Index;
}

#pragma mark - Setup

/** @ghidraAddress 0xffbbc */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self SetupView];
        self.imageDownloader = [[NSMutableArray alloc] initWithCapacity:kDownloaderCapacity];
        self.sampleDownloader = [[NSMutableDictionary alloc] initWithCapacity:kDownloaderCapacity];
    }
    return self;
}

/** @ghidraAddress 0x100498 */
- (void)SetupView {
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indicator.center =
        CGPointMake(self.bounds.size.width * kCenterScale, self.bounds.size.height * kCenterScale);
    [indicator startAnimating];
    [self addSubview:indicator];
    self.indicator = indicator;

    if (!IsPad()) {
        self.pageOffsetX = (self.frame.size.width + kPageInsetReference) * kCenterScale;
        CGFloat bannerX = (self.frame.size.width + kBannerWidthReference) * kCenterScale;
        CGFloat bannerY = (self.frame.size.height + kBannerHeightReference) * kCenterScale;
        self.bannerOffset = CGPointMake(bannerX, bannerY);
    } else {
        self.pageOffsetX = kPadPageOffsetX;
        self.bannerOffset = CGPointMake(kPadBannerOffsetX, kPadBannerOffsetY);
    }

    self.pageWidth = self.frame.size.width - self.pageOffsetX * 2.0;

    self.scrollView = [[PagingScrollView alloc]
        initWithFrame:CGRectMake(self.pageOffsetX, 0.0, self.pageWidth, self.frame.size.height)];
    self.scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.delegate = self;
    self.scrollView.pagingEnabled = YES;
    self.scrollView.clipsToBounds = NO;
    [self addSubview:self.scrollView];

    self.bannerViewArray = nil;
}

/** @ghidraAddress 0x100464 */
- (void)layoutSubviews {
    [super layoutSubviews];
}

#pragma mark - Image and data

/** @ghidraAddress 0x1009e8 */
- (void)setImageURLs:(NSArray<NSDictionary *> *)imageURLs {
    if (self.promotionDataArray != nil) {
        return;
    }
    // Dead in the binary too: the early return above already covers it.
    if (self.promotionDataArray != nil) {
        self.promotionDataArray = nil;
    }
    if (imageURLs == nil) {
        return;
    }

    self.promotionDataArray = [[NSMutableArray alloc] initWithArray:imageURLs];

    // A single promotion is duplicated so the carousel still has two pages to page between.
    NSArray<NSDictionary *> *sourceData = nil;
    if (self.promotionDataArray.count == 1) {
        sourceData = @[ self.promotionDataArray[0], self.promotionDataArray[0] ];
    } else {
        sourceData = self.promotionDataArray;
    }

    self.bannerViewArray =
        [[NSMutableArray alloc] initWithCapacity:(sourceData.count + kWrapAroundBannerCount)];

    CGFloat bannerX = self.bannerOffset.x;
    CGFloat bannerY = self.bannerOffset.y;
    for (NSUInteger i = 0; i < sourceData.count + kWrapAroundBannerCount; ++i) {
        BannerView *banner = [[BannerView alloc]
            initWithFrame:CGRectMake(bannerX,
                                     bannerY,
                                     self.pageWidth - self.bannerOffset.x * 2.0,
                                     self.frame.size.height - self.bannerOffset.y * 2.0)];
        banner.backgroundColor = [UIColor colorWithWhite:kBannerBackgroundWhite alpha:1.0];

        NSUInteger wrapped = (sourceData.count != 0) ? (i % sourceData.count) : 0;
        banner.packInfo = [[StorePackInfo alloc] initWithDictionary:sourceData[wrapped]];
        banner.sampleData = nil;
        banner.hidden = NO;

        banner.cornerRadius = kBannerCornerRadius;
        self.layer.shadowOffset = CGSizeMake(0.0, kBannerShadowOffsetHeight);
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = kBannerShadowOpacity;
        self.layer.shadowRadius = kBannerShadowRadius;

        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bannerTapped:)];
        [banner addGestureRecognizer:tap];
        [self.bannerViewArray addObject:banner];

        bannerX += self.pageWidth;
    }

    m_Index = 0;

    for (NSDictionary *promotion in self.promotionDataArray) {
        ImageDownloader *imageDownloader = [[ImageDownloader alloc] init];
        imageDownloader.imageURL = promotion[kPromotionKeyImageURL];
        imageDownloader.indexPathInTableView =
            [NSIndexPath indexPathWithIndex:[self.promotionDataArray indexOfObject:promotion]];
        imageDownloader.delegate = self;
        if (IsPad()) {
            imageDownloader.unUseRetina = YES;
        }
        [self.imageDownloader addObject:imageDownloader];

        if (![RBUserSettingData sharedInstance].refuseStoreSampleBGM) {
            NSURL *sampleURL = [NSURL URLWithString:promotion[kPromotionKeySampleURL]];
            Downloader *sampleDownloader = [[Downloader alloc] initWithURL:sampleURL save:nil];
            self.sampleDownloader[promotion[kPromotionKeyID]] = sampleDownloader;
            [sampleDownloader startDownloadingWithDelegate:self];
        } else {
            [imageDownloader startDownload];
        }
    }
}

/** @ghidraAddress 0x102284 */
- (void)setImage:(UIImage *)image Index:(NSInteger)index {
    NSDictionary *promotion = self.promotionDataArray[index];
    NSDictionary *updated = @{
        kPromotionKeyID : promotion[kPromotionKeyID],
        kPromotionKeyImageURL : promotion[kPromotionKeyImageURL],
        kPromotionKeyName : promotion[kPromotionKeyName],
        kPromotionKeySampleURL : promotion[kPromotionKeySampleURL],
        kPromotionKeyImage : image,
    };
    [self.promotionDataArray replaceObjectAtIndex:index withObject:updated];

    for (NSInteger bannerIndex = index; bannerIndex < (NSInteger)self.bannerViewArray.count;
         bannerIndex += self.promotionDataArray.count) {
        BannerView *banner = self.bannerViewArray[bannerIndex];
        banner.imageView.image = image;
        banner.packInfo = [[StorePackInfo alloc] initWithDictionary:promotion];
        banner.musicName = updated[kPromotionKeyName];
        banner.hidden = NO;
    }

    // A count of one means this is the last outstanding image.
    if (self.imageDownloader.count == 1) {
        for (BannerView *banner in self.bannerViewArray) {
            [self.scrollView addSubview:banner];
        }
        CGFloat contentWidth = self.pageWidth * (CGFloat)self.bannerViewArray.count;
        [self.scrollView setContentSize:CGSizeMake(contentWidth, self.frame.size.height)];
        [self.scrollView
            setContentOffset:CGPointMake(self.pageWidth *
                                             (CGFloat)((NSInteger)self.bannerViewArray.count -
                                                       kWrapAroundBannerCount),
                                         0.0)
                    animated:NO];
        self.indicator.hidden = YES;
        [self startAnimation];
    }
}

/** @ghidraAddress 0x101924 */
- (NSUInteger)getImageCount {
    return self.promotionDataArray.count;
}

/** @ghidraAddress 0x1008cc */
- (int)getPackID {
    NSUInteger imageCount = [self getImageCount];
    if (m_Index >= 0 && (NSUInteger)m_Index < imageCount) {
        NSNumber *packID = self.promotionDataArray[m_Index][kPromotionKeyID];
        if (packID != nil) {
            return packID.intValue;
        }
    }
    return -1;
}

#pragma mark - Animation

/** @ghidraAddress 0x102b04 */
- (void)startAnimation {
    [self stopAnimation];
    if (!self.isSamplePlayable) {
        return;
    }
    if (self.bannerViewArray.count == 0) {
        return;
    }

    if (![RBUserSettingData sharedInstance].refuseStoreSampleBGM) {
        for (BannerView *banner in self.bannerViewArray) {
            if ([banner getIsSamplePlaying]) {
                [[RBBGMManager getInstance] StopMusic:0.0];
                [[RBBGMManager getInstance] popMusic];
            }
            [banner stopSamplePlay];
        }

        NSInteger page = (NSInteger)(self.scrollView.contentOffset.x / self.pageWidth);
        NSUInteger index = ((NSUInteger)page < self.bannerViewArray.count) ? (NSUInteger)page : 0;
        BannerView *banner = self.bannerViewArray[index];
        if (banner != nil) {
            [[RBBGMManager getInstance] LoadMusicWithPush:banner.sampleData Loop:NO];
            [[RBBGMManager getInstance] PlayMusic:1.0];
            [banner startSamplePlay];
            [self.delegate setPlaySampleName:banner.musicName];
        }
    }

    self.timer = [NSTimer scheduledTimerWithTimeInterval:kPageAdvanceInterval
                                                  target:self
                                                selector:@selector(setNext)
                                                userInfo:nil
                                                 repeats:YES];
}

/** @ghidraAddress 0x103048 */
- (void)stopAnimation {
    if (self.timer != nil) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

/** @ghidraAddress 0x101984 */
- (void)setNext {
    NSInteger page = (NSInteger)(self.scrollView.contentOffset.x / self.pageWidth);

    if ([RBUserSettingData sharedInstance].refuseStoreSampleBGM) {
        [self.scrollView setContentOffset:CGPointMake((CGFloat)(page + 1) * self.pageWidth, 0.0)
                                 animated:YES];
        return;
    }

    for (NSUInteger i = 0; i < self.bannerViewArray.count; ++i) {
        if ([self.bannerViewArray[i] getIsSamplePlaying]) {
            // An unsigned index is never -1, but the binary checks anyway.
            if ((int)i != -1) {
                if ([[RBBGMManager getInstance] isPushMusic]) {
                    [[RBBGMManager getInstance] StopMusic:1.0];
                }
                [self.bannerViewArray[i] stopSamplePlay];
                [UIView
                    animateWithDuration:0.0
                                  delay:1.0
                                options:UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                               /** @ghidraAddress 0x101f98 */
                               [[RBBGMManager getInstance] popMusic];
                               [self.scrollView
                                   setContentOffset:CGPointMake(
                                                        (CGFloat)(page + 1) * self.pageWidth, 0.0)
                                           animated:YES];
                               NSUInteger nextIndex =
                                   ((NSUInteger)(page + 1) < self.bannerViewArray.count) ?
                                       (NSUInteger)(page + 1) :
                                       0;
                               BannerView *nextBanner = self.bannerViewArray[nextIndex];
                               if (nextBanner != nil) {
                                   [[RBBGMManager getInstance]
                                       LoadMusicWithPush:nextBanner.sampleData
                                                    Loop:NO];
                                   [[RBBGMManager getInstance] PlayMusic:1.0];
                                   [nextBanner startSamplePlay];
                                   [self.delegate setPlaySampleName:nextBanner.musicName];
                               }
                             }
                             completion:nil];
            }
            return;
        }
    }

    [self.scrollView setContentOffset:CGPointMake((CGFloat)(page + 1) * self.pageWidth, 0.0)
                             animated:YES];
    NSUInteger index =
        ((NSUInteger)(page + 1) < self.bannerViewArray.count) ? (NSUInteger)(page + 1) : 0;
    BannerView *banner = self.bannerViewArray[index];
    if (banner != nil) {
        [[RBBGMManager getInstance] LoadMusicWithPush:banner.sampleData Loop:NO];
        [[RBBGMManager getInstance] PlayMusic:1.0];
        [banner startSamplePlay];
        [self.delegate setPlaySampleName:banner.musicName];
    }
}

/** @ghidraAddress 0x102280 */
- (void)nextShowEnd {
}

// @ghidraAddress 0x1008c8
- (void)setImageViewSize:(CGSize)imageViewSize {
}

#pragma mark - Sample playback

/** @ghidraAddress 0x102a14 */
- (void)startSamplePlay {
    [self startAnimation];
}

/** @ghidraAddress 0x102a20 */
- (void)stopSamplePlay {
    if ([[RBBGMManager getInstance] isPushMusic]) {
        [[RBBGMManager getInstance] StopMusic:0.0];
        [[RBBGMManager getInstance] popMusic];
    }
}

#pragma mark - Banner tap

/** @ghidraAddress 0x1030f0 */
- (void)bannerTapped:(UITapGestureRecognizer *)recognizer {
    BannerView *banner = (BannerView *)recognizer.view;
    if (banner.packInfo == nil) {
        return;
    }
    if (self.delegate == nil) {
        return;
    }

    NSUInteger tappedIndex = [self.bannerViewArray indexOfObject:banner];
    NSUInteger pageCount = self.promotionDataArray.count;
    NSUInteger wrapped = (pageCount != 0) ? (tappedIndex / pageCount) : 0;
    m_Index = tappedIndex - wrapped * pageCount;

    [self.delegate storePromotionViewTaped:self PackID:banner.packInfo.packID];
}

#pragma mark - ImageDownloaderDelegate

/** @ghidraAddress 0x101788 */
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    [self setImage:[downloader getImage] Index:[indexPath indexAtPosition:0]];
    [self.imageDownloader removeObject:downloader];
}

/** @ghidraAddress 0x101898 */
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    [self.imageDownloader removeObject:downloader];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x1032e4 */
- (void)downloaderFinished:(Downloader *)downloader {
    NSData *data = [downloader getData];

    NSString *finishedKey = nil;
    if (data != nil) {
        for (NSString *key in [self.sampleDownloader keyEnumerator]) {
            if (self.sampleDownloader[key] == downloader) {
                finishedKey = key;
                break;
            }
        }
    }

    for (BannerView *banner in self.bannerViewArray) {
        if (banner.packInfo.packID == finishedKey.intValue) {
            banner.sampleData = [data copy];
        }
    }

    if (finishedKey != nil) {
        [self.sampleDownloader removeObjectForKey:finishedKey];
        if (self.sampleDownloader.count == 0) {
            for (ImageDownloader *imageDownloader in self.imageDownloader) {
                [imageDownloader startDownload];
            }
        }
    }
}

/** @ghidraAddress 0x1037fc */
- (void)downloaderError:(Downloader *)downloader {
    [downloader cancel];
    for (NSString *key in [self.sampleDownloader keyEnumerator]) {
        if (self.sampleDownloader[key] == downloader) {
            [downloader cancel];
            [self.sampleDownloader removeObjectForKey:key];
            break;
        }
    }
}

#pragma mark - UIScrollViewDelegate

/** @ghidraAddress 0x103a50 */
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self stopAnimation];
}

/** @ghidraAddress 0x103a6c */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offsetX = self.scrollView.contentOffset.x;
    CGFloat span =
        (CGFloat)((NSInteger)self.bannerViewArray.count - kWrapAroundBannerCount) * self.pageWidth;
    CGFloat offsetY = self.scrollView.contentOffset.y;
    if (self.pageWidth * kCenterScale <= offsetX) {
        if (span + self.pageWidth * kCenterScale <= offsetX) {
            self.scrollView.contentOffset = CGPointMake(offsetX - span, offsetY);
        }
    } else {
        self.scrollView.contentOffset = CGPointMake(offsetX + span, offsetY);
    }
    m_Index = (NSInteger)(self.scrollView.contentOffset.x / self.pageWidth);
}

/** @ghidraAddress 0x103c48 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
}

/** @ghidraAddress 0x103c4c */
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
}

/** @ghidraAddress 0x103c50 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self startAnimation];
}

/** @ghidraAddress 0x103c6c */
- (void)scrollViewDidRotate:(float)width {
    if (IsPad()) {
        return;
    }
    self.pageOffsetX = (CGFloat)((width + kPageInsetReference) * kCenterScale);
    self.pageWidth = (CGFloat)width - self.pageOffsetX * 2.0;

    self.scrollView.frame =
        CGRectMake(self.pageOffsetX, 0.0, kRotatedScrollViewWidth, kRotatedScrollViewHeight);
    self.scrollView.contentOffset =
        CGPointMake(self.pageWidth * (CGFloat)m_Index, self.scrollView.contentOffset.y);
    self.scrollView.contentSize = CGSizeMake(self.pageWidth * (CGFloat)self.bannerViewArray.count,
                                             self.pageWidth * kBannerContentHeightRatio);
    // Yes, the binary reads the content size back and discards it.
    (void)self.scrollView.contentSize;
}

#pragma mark - Teardown

/** @ghidraAddress 0x100138 */
- (void)cancel {
    for (ImageDownloader *imageDownloader in self.imageDownloader) {
        imageDownloader.delegate = nil;
        [imageDownloader cancelDownload];
    }
    for (NSString *key in [self.sampleDownloader keyEnumerator]) {
        [self.sampleDownloader[key] cancel];
    }
    self.imageDownloader = nil;
    [self stopAnimation];
    self.scrollView.delegate = nil;
}

/** @ghidraAddress 0xffcf8 */
- (void)dealloc {
    for (ImageDownloader *imageDownloader in self.imageDownloader) {
        imageDownloader.delegate = nil;
        [imageDownloader cancelDownload];
    }
    for (NSString *key in [self.sampleDownloader keyEnumerator]) {
        [self.sampleDownloader[key] cancel];
    }
    for (BannerView *banner in self.bannerViewArray) {
        if ([banner getIsSamplePlaying]) {
            [banner stopSamplePlay];
        }
    }
    [self stopAnimation];
    self.scrollView.delegate = nil;
}

@end
