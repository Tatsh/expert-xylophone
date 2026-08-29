#import "RBUnlockCollectionView.h"

#import "RBExperienceData.h"
#import "RBMusicGridLayout.h"
#import "RBMusicManager.h"
#import "RBNumberLabel.h"
#import "RBUnlockCollectionCell.h"
#import "RBUnlockPackageData.h"
#import "RBUnlockPackageItemData.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"

static NSString *const kUnlockFrameImageName = @"04_customize/cus_fram_unlock";

enum {
    kUnlockItemTypeBGM = 0,
    kUnlockItemTypeShot = 1,
    kUnlockItemTypeExplosion = 2,
    kUnlockItemTypeFrame = 3,
    kUnlockItemTypeBackground = 4,
    kUnlockItemTypeMusic = 7,
    kUnlockItemTypeThema = 10,
};

enum {
    kThemeLimelight = 1,
    kThemeColette = 2,
};

static const CGFloat kFrameCapInsetNarrow = 20.0;
static const CGFloat kFrameCapInsetWide = 36.0;

static const CGFloat kBackgroundCenterFactor = 0.5;

static const CGFloat kTitleNarrowLimelightX = 23.0;
static const CGFloat kTitleNarrowLimelightY = 5.0;
static const CGFloat kTitleNarrowColetteX = 3.0;
static const CGFloat kTitleNarrowColetteY = 6.0;
static const CGFloat kTitleNarrowWidth = 100.0;
static const CGFloat kTitleNarrowHeight = 12.0;
static const CGFloat kTitleNarrowLimelightFontSize = 12.0;
static const CGFloat kTitleNarrowColetteFontSize = 11.0;
static const CGFloat kTitleWideX = 32.0;
static const CGFloat kTitleWideY = 11.0;
static const CGFloat kTitleWideWidth = 180.0;
static const CGFloat kTitleWideHeight = 18.0;
static const CGFloat kTitleWideFontSize = 18.0;

static const CGFloat kCollectionHeightNarrow = 84.0;
static const CGFloat kCollectionHeightWide = 100.0;
static const CGFloat kItemSizeNarrow = 80.0;
static const CGFloat kItemSizeWide = 90.0;

static const CGFloat kCollectionWidthInset = 2.0;

static const CGFloat kPageInsetVerticalNarrow = 2.0;
static const CGFloat kPageInsetVerticalWide = 5.0;
static const CGFloat kPageInsetHorizontalNarrow = 3.0;
static const CGFloat kPageInsetHorizontalWide = 8.0;

static const CGFloat kPageControlHeight = 20.0;
static const CGFloat kPageControlScale = 0.8;

static const CGFloat kPageIndicatorWhiteThemed = 170.0f / 255.0f;
static const CGFloat kCurrentPageIndicatorWhiteThemed = 0.5;
static const CGFloat kCurrentPageIndicatorWhiteDefault = 1.0;

static const NSInteger kMinimumPageCountForVisiblePageControl = 2;

static const CGFloat kPageSnapFraction = 0.5;

// @ghidraAddress 0x2fcf38 (g_dBrownTintRed)
// @ghidraAddress 0x2fcf40 (g_dBrownTintGreen)
// @ghidraAddress 0x2fcf48 (g_dBrownTintBlue)
static const CGFloat kColetteTitleRed = 78.0 / 255.0;
static const CGFloat kColetteTitleGreen = 69.0 / 255.0;
static const CGFloat kColetteTitleBlue = 58.0 / 255.0;

static const int kPackageColorStride = 3;

enum {
    kColorComponentRed = 0,
    kColorComponentGreen = 1,
    kColorComponentBlue = 2,
};

@implementation RBUnlockCollectionView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
        experiencePackageData:(RBUnlockPackageData *)experiencePackageData {
    self = [super initWithFrame:frame];
    if (self) {
        self.experiencePackageData = experiencePackageData;
        [self setupView];
    }
    return self;
}

#pragma mark Layout

- (void)setupView {
    BOOL isPad = IsPad();

    UIImage *frameImage = [UIImage imageWithName:kUnlockFrameImageName];
    CGFloat capInset = (!isPad) ? kFrameCapInsetNarrow : kFrameCapInsetWide;
    frameImage = [frameImage
        resizableImageWithCapInsets:UIEdgeInsetsMake(
                                        capInset, 0.0, frameImage.size.height - capInset, 0.0)];
    self.backgroundView = [[UIImageView alloc] initWithImage:frameImage];
    self.backgroundView.frame =
        CGRectMake((self.frame.size.width - frameImage.size.width) * kBackgroundCenterFactor,
                   0.0,
                   frameImage.size.width,
                   self.frame.size.height);
    [self addSubview:self.backgroundView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textColor = UIColor.blackColor;
    self.titleLabel.textAlignment = NSTextAlignmentLeft;
    self.titleLabel.backgroundColor = UIColor.clearColor;
    [self.backgroundView addSubview:self.titleLabel];

    if (!isPad) {
        NSInteger theme = [RBUserSettingData sharedInstance].thema;
        if (theme == kThemeLimelight) {
            self.titleLabel.frame = CGRectMake(kTitleNarrowLimelightX,
                                               kTitleNarrowLimelightY,
                                               kTitleNarrowWidth,
                                               kTitleNarrowHeight);
            self.titleLabel.font = [UIFont systemFontOfSize:kTitleNarrowLimelightFontSize];
            self.titleLabel.textAlignment = NSTextAlignmentCenter;
        } else if (theme == kThemeColette) {
            self.titleLabel.frame = CGRectMake(
                kTitleNarrowColetteX, kTitleNarrowColetteY, kTitleNarrowWidth, kTitleNarrowHeight);
            self.titleLabel.font = [UIFont boldSystemFontOfSize:kTitleNarrowColetteFontSize];
            self.titleLabel.textAlignment = NSTextAlignmentLeft;
        }
    } else {
        NSInteger theme = [RBUserSettingData sharedInstance].thema;
        if (theme == kThemeLimelight) {
            self.titleLabel.frame =
                CGRectMake(kTitleWideX, kTitleWideY, kTitleWideWidth, kTitleWideHeight);
            self.titleLabel.font = [UIFont systemFontOfSize:kTitleWideFontSize];
        } else if (theme == kThemeColette) {
            self.titleLabel.frame =
                CGRectMake(kTitleWideX, kTitleWideY, kTitleWideWidth, kTitleWideHeight);
            self.titleLabel.font = [UIFont boldSystemFontOfSize:kTitleWideFontSize];
        }
    }

    CGFloat collectionHeight = (!isPad) ? kCollectionHeightNarrow : kCollectionHeightWide;
    RBMusicGridLayout *layout = [RBMusicGridLayout new];
    CGFloat itemSize = (!isPad) ? kItemSizeNarrow : kItemSizeWide;
    layout.itemSize = CGSizeMake(itemSize, itemSize);
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 0.0;
    layout.minimumInteritemSpacing = 0.0;
    CGFloat pageInsetVertical = (!isPad) ? kPageInsetVerticalNarrow : kPageInsetVerticalWide;
    CGFloat pageInsetHorizontal = (!isPad) ? kPageInsetHorizontalNarrow : kPageInsetHorizontalWide;
    layout.pageInset = UIEdgeInsetsMake(
        pageInsetVertical, pageInsetHorizontal, pageInsetVertical, pageInsetHorizontal);
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;

    CGFloat collectionWidth = (float)(frameImage.size.width - kCollectionWidthInset);
    self.collectionView = [[RBCollectionView alloc]
               initWithFrame:CGRectMake((self.frame.size.width - collectionWidth) *
                                            kBackgroundCenterFactor,
                                        capInset,
                                        collectionWidth,
                                        collectionHeight)
        collectionViewLayout:layout];
    self.collectionView.backgroundColor = UIColor.clearColor;
    [self.collectionView registerClass:[RBUnlockCollectionCell class]
            forCellWithReuseIdentifier:NSStringFromClass([RBUnlockCollectionCell class])];
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.pagingEnabled = YES;
    self.collectionView.customDelegate = self;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self addSubview:self.collectionView];

    if (!IsPad()) {
        NSInteger theme = [RBUserSettingData sharedInstance].thema;
        CGFloat indicatorWhite;
        CGFloat currentIndicatorWhite;
        if (theme == 0) {
            indicatorWhite = 0.0;
            currentIndicatorWhite = kCurrentPageIndicatorWhiteDefault;
        } else if (theme == kThemeLimelight) {
            indicatorWhite = kPageIndicatorWhiteThemed;
            currentIndicatorWhite = kCurrentPageIndicatorWhiteThemed;
        } else {
            indicatorWhite = (theme == kThemeColette) ? kPageIndicatorWhiteThemed : 0.0;
            currentIndicatorWhite =
                (theme == kThemeColette) ? kCurrentPageIndicatorWhiteThemed : 0.0;
        }

        self.pageControl =
            [[UIPageControl alloc] initWithFrame:CGRectMake(0.0,
                                                            self.collectionView.bottom,
                                                            self.frame.size.width,
                                                            kPageControlHeight)];
        self.pageControl.numberOfPages = 1;
        self.pageControl.currentPage = 0;
        self.pageControl.transform =
            CGAffineTransformMakeScale(kPageControlScale, kPageControlScale);
        self.pageControl.pageIndicatorTintColor = [UIColor colorWithWhite:indicatorWhite alpha:1.0];
        self.pageControl.currentPageIndicatorTintColor =
            [UIColor colorWithWhite:currentIndicatorWhite alpha:1.0];
        self.pageControl.userInteractionEnabled = NO;
        [self addSubview:self.pageControl];
    }

    [self reloadData];
}

- (void)reloadData {
    self.items = self.experiencePackageData.data;
    self.titleLabel.text = self.experiencePackageData.title;
    [self.titleLabel sizeToFit];

    NSInteger theme = [RBUserSettingData sharedInstance].thema;
    if (theme == kThemeLimelight) {
        int order = self.experiencePackageData.order;
        self.titleLabel.textColor =
            [UIColor colorWithRed:g_afLimelightPackageTitleColorTable[order * kPackageColorStride +
                                                                      kColorComponentRed]
                            green:g_afLimelightPackageTitleColorTable[order * kPackageColorStride +
                                                                      kColorComponentGreen]
                             blue:g_afLimelightPackageTitleColorTable[order * kPackageColorStride +
                                                                      kColorComponentBlue]
                            alpha:1.0];
    } else if (theme == kThemeColette) {
        self.titleLabel.textColor = [UIColor colorWithRed:kColetteTitleRed
                                                    green:kColetteTitleGreen
                                                     blue:kColetteTitleBlue
                                                    alpha:1.0];
    }

    [self.collectionView reloadData];
}

- (void)didLayoutSubviews:(RBCollectionView *)collectionView {
    NSInteger pageCount =
        (NSInteger)(collectionView.contentSize.width / collectionView.frame.size.width);
    self.pageControl.numberOfPages = pageCount;
    self.pageControl.hidden = pageCount < kMinimumPageCountForVisiblePageControl;
}

- (void)configureCell:(RBUnlockCollectionCell *)cell {
    RBUnlockPackageItemData *itemData = self.items[cell.indexPath.row];
    cell.itemData = itemData;

    RBExperienceData *experienceData = [RBExperienceData sharedInstance];

    if (cell.enabled && [experienceData getPoint] < (float)itemData.point) {
        cell.enabled = NO;
    }

    switch (itemData.type) {
    case kUnlockItemTypeBGM:
        if ([experienceData unlockWithBGMtype:itemData.identity]) {
            cell.pointLabel.hidden = YES;
            cell.unlockView.hidden = NO;
            cell.userInteractionEnabled = NO;
            cell.enabled = NO;
        }
        break;
    case kUnlockItemTypeShot:
        if ([experienceData unlockWithShotType:itemData.identity]) {
            cell.pointLabel.hidden = YES;
            cell.unlockView.hidden = NO;
            cell.userInteractionEnabled = NO;
            cell.enabled = NO;
        }
        break;
    case kUnlockItemTypeExplosion:
        if ([experienceData unlockWithExprosionType:itemData.identity]) {
            cell.pointLabel.hidden = YES;
            cell.unlockView.hidden = NO;
            cell.userInteractionEnabled = NO;
            cell.enabled = NO;
        }
        break;
    case kUnlockItemTypeFrame:
        if ([experienceData unlockWithFrameType:itemData.identity]) {
            cell.pointLabel.hidden = YES;
            cell.unlockView.hidden = NO;
            cell.userInteractionEnabled = NO;
            cell.enabled = NO;
        }
        break;
    case kUnlockItemTypeBackground:
        if ([experienceData unlockWithBackgroundType:itemData.identity]) {
            cell.pointLabel.hidden = YES;
            cell.unlockView.hidden = NO;
            cell.userInteractionEnabled = NO;
            cell.enabled = NO;
        }
        break;
    case kUnlockItemTypeMusic:
        if ([experienceData unlockWithMusicID:itemData.identity]) {
            cell.pointLabel.hidden = YES;
            cell.unlockView.hidden = NO;
            cell.badgeView.hidden = YES;
            cell.userInteractionEnabled = NO;
            cell.enabled = NO;
            // An unlocked track that is not downloaded stays interactive so it can be fetched.
            if (![[RBMusicManager getInstance] getMusicData:itemData.identity]) {
                cell.badgeView.hidden = NO;
                cell.userInteractionEnabled = YES;
                cell.enabled = YES;
            }
        }
        break;
    case kUnlockItemTypeThema:
        if ([experienceData unlockWithThemaID:itemData.identity]) {
            cell.pointLabel.hidden = YES;
            cell.unlockView.hidden = NO;
            cell.userInteractionEnabled = NO;
            cell.enabled = NO;
        }
        break;
    default:
        break;
    }

    [cell layoutSubviews];
}

#pragma mark Collection view data source

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    RBUnlockCollectionCell *cell = [collectionView
        dequeueReusableCellWithReuseIdentifier:NSStringFromClass([RBUnlockCollectionCell class])
                                  forIndexPath:indexPath];
    cell.indexPath = indexPath;
    [self configureCell:cell];
    return cell;
}

#pragma mark Collection view delegate

- (void)collectionView:(UICollectionView *)collectionView
    didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    RBUnlockCollectionCell *cell =
        (RBUnlockCollectionCell *)[collectionView cellForItemAtIndexPath:indexPath];
    cell.highlighted = YES;
}

- (void)collectionView:(UICollectionView *)collectionView
    didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    RBUnlockCollectionCell *cell =
        (RBUnlockCollectionCell *)[collectionView cellForItemAtIndexPath:indexPath];
    cell.highlighted = NO;
}

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    RBUnlockCollectionCell *cell =
        (RBUnlockCollectionCell *)[collectionView cellForItemAtIndexPath:indexPath];
    if (cell.userInteractionEnabled && cell.enabled) {
        if ([self.delegate respondsToSelector:@selector(didSelectView:selectedCell:)]) {
            [self.delegate didSelectView:self selectedCell:cell];
        }
    }
}

#pragma mark Scroll view delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    float offset = scrollView.contentOffset.x / scrollView.bounds.size.width;
    int page = (int)offset;
    float snapped = (offset - (float)page > kPageSnapFraction) ? (float)(page + 1) : (float)page;
    if ((float)self.pageControl.currentPage != snapped) {
        self.pageControl.currentPage = (NSInteger)snapped;
    }
}

@end
