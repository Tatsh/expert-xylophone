#import "RBUnlockView.h"

#import "AppDelegate.h"
#import "DAProgressOverlayView.h"
#import "ImageDownloader.h"
#import "NetworkUtil.h"
#import "RBCustomInfoPopupView.h"
#import "RBCustomView.h"
#import "RBExperienceData.h"
#import "RBMenuTutorialView.h"
#import "RBMenuView.h"
#import "RBMusicManager.h"
#import "RBNumberLabel.h"
#import "RBServerAPIManager.h"
#import "RBTutorialManager.h"
#import "RBUnlockCollectionCell.h"
#import "RBUnlockData.h"
#import "RBUnlockPackageData.h"
#import "RBUnlockPackageItemData.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "RewardNetwork.h"
#import "StoreDownloadTask.h"
#import "StoreMusicInfo.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "deviceenvironment.h"
#import "shotsoundmanager.h"
#import "soundeffectmanager.h"

static NSString *const kPointBackgroundImageName = @"04_customize/cus_fram_lockp";

static NSString *const kRewardBannerListKey = @"RewardBannerList";
static NSString *const kRewardBannerURLKey = @"URL";
static NSString *const kUnlockIDKey = @"ID";
static NSString *const kUnlockKeyEchoKey = @"Key";

static NSString *const kRetinaSuffix = @"@2x";

static NSString *const kRewardCheckTargetKey = @"target";
static NSString *const kRewardCheckUserIDKey = @"user_id";
static NSString *const kRewardCheckPasswordKey = @"passwd";
static NSString *const kRewardCheckNonceKey = @"nonce";
static NSString *const kRewardCheckRewardIDKey = @"reward_id";
static NSString *const kRewardCheckAppliIDKey = @"appli_id";

static NSString *const kRewardCheckNonceEchoKey = @"CK";
static NSString *const kRewardListKey = @"RewardList";
static NSString *const kAppliIDKey = @"AppliID";
static NSString *const kRewardPointKey = @"Point";

static NSString *const kJsonContentType = @"application/json";

typedef enum {
    RBUnlockItemTypeBGM = 0,
    RBUnlockItemTypeShot = 1,
    RBUnlockItemTypeExplosion = 2,
    RBUnlockItemTypeFrame = 3,
    RBUnlockItemTypeBackground = 4,
    RBUnlockItemTypeMusic = 7,
    RBUnlockItemTypeThema = 10,
} RBUnlockItemType;

constexpr int kSoundEffectPopupCancel = 4;
constexpr int kSoundEffectUnlocked = 9;

constexpr NSInteger kTutorialTypeExperience = 0x20;

constexpr CGFloat kRewardButtonInset = 10.0;
constexpr CGFloat kRewardButtonMargin = 20.0;

constexpr CGFloat kPackageRowHeightNarrow = 124.0;
constexpr CGFloat kPackageRowHeightWide = 144.0;

constexpr CGFloat kPackageRowGapNarrow = 4.0;
constexpr CGFloat kPackageRowGapWide = 10.0;

constexpr CGFloat kRewardBannerRowFactor = 0.8;

constexpr CGFloat kPointBackgroundCenterFactor = 0.5;
constexpr CGFloat kPointBackgroundTopNarrow = 34.0;
constexpr CGFloat kPointBackgroundTopWide = 70.0;

constexpr CGFloat kPointLabelNarrowX = 112.0;
constexpr CGFloat kPointLabelNarrowY = 44.0;
constexpr CGFloat kPointLabelNarrowWidth = 114.0;
constexpr CGFloat kPointLabelNarrowHeight = 20.0;
constexpr CGFloat kPointLabelWideX = 169.0;
constexpr CGFloat kPointLabelWideWidth = 240.0;
constexpr CGFloat kPointLabelLimelightY = 93.0;
constexpr CGFloat kPointLabelLimelightHeight = 36.0;
constexpr CGFloat kPointLabelColetteY = 90.0;
constexpr CGFloat kPointLabelColetteHeight = 40.0;

constexpr CGFloat kScrollTopMarginNarrow = 4.0;
constexpr CGFloat kScrollTopMarginWide = 10.0;

constexpr CGFloat kScrollContentPadNarrow = 45.0;
constexpr CGFloat kScrollContentPadWide = 70.0;

constexpr CGFloat kSpinnerBackgroundAlpha = 0.5;
constexpr CGFloat kSpinnerCornerRadius = 5.0;

constexpr NSUInteger kFileExtensionLength = 4;

constexpr int kNonceLength = 0x20;

constexpr CGFloat kPopupInteractiveAlpha = 0.01;

constexpr CGFloat kProgressOverlayInset = 3.0;

constexpr int kUnlockRandomKeyModulus = 0xffff;

constexpr int kProgressStepCount = 11;
constexpr float kProgressIncrement = 0.1;
constexpr float kProgressTickFraction = 0.05;
constexpr double kNanosecondsPerSecond = 1000000000.0;

@implementation RBUnlockView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

// The binary's -dealloc only chains to [super dealloc], which ARC does for us, so it has no
// override here.

- (void)setParentView:(RBCustomView *)parentView {
    self.parentCustomView = parentView;
}

#pragma mark Layout

- (void)setupView {
    BOOL isPad = IsPad();

    self.rewardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.rewardButton addTarget:self
                          action:@selector(pushRewardButton:)
                forControlEvents:UIControlEventTouchUpInside];
    self.rewardButton.exclusiveTouch = YES;

    UIImage *backgroundImage = [UIImage imageWithName:kPointBackgroundImageName];
    self.pointBackgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
    CGFloat backgroundTop = (!isPad) ? kPointBackgroundTopNarrow : kPointBackgroundTopWide;
    self.pointBackgroundView.frame =
        CGRectMake((self.width - self.pointBackgroundView.width) * kPointBackgroundCenterFactor,
                   backgroundTop,
                   self.pointBackgroundView.width,
                   self.pointBackgroundView.height);
    [self addSubview:self.pointBackgroundView];

    self.pointLabel = [[RBNumberLabel alloc] init];
    self.pointLabel.imageType = RBNumberLabelImageTypeDecimal;
    [self.pointBackgroundView addSubview:self.pointLabel];

    CGFloat scrollTopMargin = kScrollTopMarginWide;
    if (!isPad) {
        self.pointLabel.frame = CGRectMake(kPointLabelNarrowX,
                                           kPointLabelNarrowY,
                                           kPointLabelNarrowWidth,
                                           kPointLabelNarrowHeight);
        scrollTopMargin = kScrollTopMarginNarrow;
    } else {
        const RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
        if (theme == RBUserSettingDataThemeLimelight) {
            self.pointLabel.frame = CGRectMake(kPointLabelWideX,
                                               kPointLabelLimelightY,
                                               kPointLabelWideWidth,
                                               kPointLabelLimelightHeight);
        } else if (theme == RBUserSettingDataThemeColette) {
            self.pointLabel.frame = CGRectMake(kPointLabelWideX,
                                               kPointLabelColetteY,
                                               kPointLabelWideWidth,
                                               kPointLabelColetteHeight);
        }
    }

    CGFloat scrollTop = scrollTopMargin + self.pointBackgroundView.bottom;
    self.scrollView =
        [[UIScrollView alloc] initWithFrame:CGRectMake(0.0,
                                                       scrollTop,
                                                       self.frame.size.width,
                                                       self.frame.size.height - scrollTop)];
    [self addSubview:self.scrollView];

    self.activityIndicatorView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.activityIndicatorView.backgroundColor =
        [UIColor.grayColor colorWithAlphaComponent:kSpinnerBackgroundAlpha];
    self.activityIndicatorView.layer.cornerRadius = kSpinnerCornerRadius;
    self.activityIndicatorView.center = self.center;
    [self addSubview:self.activityIndicatorView];

    ShotSoundManager::GetInstance()->LoadAll();
    [self reloadData];
}

- (void)reloadData {
    BOOL isPad = IsPad();

    CGFloat rowHeight = (!isPad) ? kPackageRowHeightNarrow : kPackageRowHeightWide;
    CGFloat rowGap = (!isPad) ? kPackageRowGapNarrow : kPackageRowGapWide;
    CGFloat viewWidth = self.frame.size.width;

    self.pointLabel.number = [[RBExperienceData sharedInstance] getPoint];

    for (UIView *subview in self.scrollView.subviews) {
        [subview removeFromSuperview];
    }

    CGFloat contentTop = 0.0;
    if (self.rewardBannerUrl) {
        if (self.rewardButton) {
            self.rewardButton.frame = CGRectMake(kRewardButtonInset,
                                                 kRewardButtonInset,
                                                 viewWidth - kRewardButtonMargin,
                                                 rowHeight - kRewardButtonMargin);
            [self.scrollView addSubview:self.rewardButton];

            ImageDownloader *bannerDownloader =
                [[ImageDownloader alloc] initWithGetURL:self.rewardBannerUrl unUseRetina:NO];
            [bannerDownloader
                startDownloadWithProceed:^(ImageDownloader *downloader) {
                  /** @ghidraAddress 0x1952e0 */
                }
                success:^(ImageDownloader *downloader) {
                  /** @ghidraAddress 0x1952e4 */
                  dispatch_async(dispatch_get_main_queue(), ^{
                    /** @ghidraAddress 0x195390 */
                    [self.rewardButton setImage:[downloader getImage]
                                       forState:UIControlStateNormal];
                    if (!IsPad()) {
                        CGFloat width = viewWidth - kRewardButtonMargin;
                        CGSize imageSize = [downloader getImage].size;
                        self.rewardButton.frame =
                            CGRectMake(kRewardButtonInset,
                                       kRewardButtonInset,
                                       width,
                                       imageSize.height / (imageSize.width / width));
                    } else {
                        self.rewardButton.frame = CGRectMake(kRewardButtonInset,
                                                             kRewardButtonInset,
                                                             viewWidth - kRewardButtonMargin,
                                                             rowHeight - kRewardButtonMargin);
                    }
                  });
                }
                failure:^(ImageDownloader *downloader){
                    /** @ghidraAddress 0x1955dc */
                }];
        }
        contentTop =
            (!isPad) ? (rowGap + rowHeight * kRewardBannerRowFactor) : (rowHeight + rowGap);
    }

    CGFloat rowTop = contentTop;
    for (RBUnlockPackageData *packageData in [[RBUnlockData sharedInstance] getPackage]) {
        RBUnlockCollectionView *collectionView = [[RBUnlockCollectionView alloc]
                    initWithFrame:CGRectMake(0.0, rowTop, viewWidth, rowHeight)
            experiencePackageData:packageData];
        collectionView.tag = 0;
        collectionView.delegate = self;
        [self.scrollView addSubview:collectionView];
        rowTop += rowHeight + rowGap;
    }

    CGFloat bottomPad = (!isPad) ? kScrollContentPadNarrow : kScrollContentPadWide;
    self.scrollView.contentSize = CGSizeMake(self.frame.size.width, rowTop + bottomPad);
}

#pragma mark Requests

- (void)request {
    [self.activityIndicatorView startAnimating];

    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil unlockListURL] save:nil];
    __weak RBUnlockView *weakSelf = self;
    [self.downloader
        startDownloadingWithProceed:^(Downloader *downloader) {
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x195858 */
          NSDictionary *json = [downloader getDataInJSON];

          if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeLimelight &&
              [json[kRewardBannerListKey] count]) {
              NSDictionary *banner = json[kRewardBannerListKey][0];
              weakSelf.rewardBannerUrl = banner[kRewardBannerURLKey];
              if (weakSelf.rewardBannerUrl) {
                  NSRange retinaRange = [weakSelf.rewardBannerUrl rangeOfString:kRetinaSuffix
                                                                        options:NSBackwardsSearch];
                  if (retinaRange.location == NSNotFound && GetIsRetinaFlag()) {
                      NSUInteger cut = weakSelf.rewardBannerUrl.length - kFileExtensionLength;
                      weakSelf.rewardBannerUrl = [NSString
                          stringWithFormat:@"%@@2x%@",
                                           [weakSelf.rewardBannerUrl substringToIndex:cut],
                                           [weakSelf.rewardBannerUrl substringFromIndex:cut]];
                  } else if (retinaRange.location != NSNotFound && !GetIsRetinaFlag()) {
                      weakSelf.rewardBannerUrl =
                          [NSString stringWithFormat:@"%@%@",
                                                     [weakSelf.rewardBannerUrl
                                                         substringToIndex:retinaRange.location],
                                                     [weakSelf.rewardBannerUrl
                                                         substringFromIndex:retinaRange.location +
                                                                            retinaRange.length]];
                  }
              }
              weakSelf.rewardId = banner[kUnlockIDKey];
          }

          [[RBUnlockData sharedInstance] parseDictionary:json];
          [[RBUnlockData sharedInstance] save];

          if (!weakSelf.rewardBannerUrl) {
              [weakSelf performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:YES];
              [weakSelf.activityIndicatorView performSelectorOnMainThread:@selector(stopAnimating)
                                                               withObject:nil
                                                            waitUntilDone:YES];
          } else {
              [RewardNetwork getAdStatusWithBlock:^(NSInteger status, NSError *error) {
                /** @ghidraAddress 0x196114 */
                if (error) {
                    [AppDelegate ApplilinkInitialize];
                    weakSelf.rewardBannerUrl = nil;
                    weakSelf.rewardId = nil;
                } else if (status != 1) {
                    weakSelf.rewardBannerUrl = nil;
                    weakSelf.rewardId = nil;
                }
                [weakSelf performSelectorOnMainThread:@selector(reloadData)
                                           withObject:nil
                                        waitUntilDone:YES];
                [weakSelf.activityIndicatorView performSelectorOnMainThread:@selector(stopAnimating)
                                                                 withObject:nil
                                                              waitUntilDone:YES];
                if (weakSelf.rewardBannerUrl && weakSelf.rewardId) {
                    [weakSelf requestRewardCheck];
                }
              }];
          }
        }
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0x1963ac */
          dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.activityIndicatorView stopAnimating];
          });
        }];
}

- (void)requestRewardCheck {
    __weak RBUnlockView *weakSelf = self;

    NSMutableArray *seenAppliIds =
        [[RBExperienceData sharedInstance] getRewardAppliId:self.rewardId];
    self.nonce = [NetworkUtil createNonce:kNonceLength];

    NSArray *serverData = [AppDelegate getServerData];
    NSDictionary *parameters = @{
        kRewardCheckTargetKey : GetRegionCode(),
        kRewardCheckUserIDKey : serverData[0],
        kRewardCheckPasswordKey : serverData[1],
        kRewardCheckNonceKey : self.nonce,
        kRewardCheckRewardIDKey : self.rewardId,
        kRewardCheckAppliIDKey : seenAppliIds
    };
    NSData *body = [Downloader dictionaryToJsonData:parameters];

    if (self.downloader) {
        [self.downloader cancel];
        self.downloader = nil;
    }
    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil rewardCheckURL]
                                                 post:body
                                          contentType:kJsonContentType];
    [self.downloader
        startDownloadingWithProceed:^(Downloader *downloader) {
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x196be0 */
          NSDictionary *json = [downloader getDataInJSON];
          NSString *responseNonce = json[kRewardCheckNonceEchoKey];
          NSArray *rewardList = json[kRewardListKey];
          if ([rewardList count] && [responseNonce isEqualToString:weakSelf.nonce]) {
              int totalPoints = 0;
              for (NSDictionary *reward in rewardList) {
                  if ([seenAppliIds indexOfObject:reward[kAppliIDKey]] == NSNotFound) {
                      [[RBExperienceData sharedInstance] addRewardAppliId:weakSelf.rewardId
                                                               andAppliId:reward[kAppliIDKey]];
                      totalPoints += [reward[kRewardPointKey] intValue];
                  }
              }
              [[RBExperienceData sharedInstance] addPoint:totalPoints];
              [[RBExperienceData sharedInstance] save];
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x197168 */
                weakSelf.alertView = [UIAlertView showAddLimepointByApplilink:totalPoints:nil];
                [weakSelf reloadData];
              });
          }
        }
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0x196530 */
          dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.activityIndicatorView stopAnimating];
          });
        }];
}

#pragma mark Tutorial accessors

- (UIScrollView *)getUnlockItemView {
    return self.scrollView;
}

#pragma mark Reward banner

- (void)pushRewardButton:(id)sender {
    [self.parentCustomView toRewardList:sender];
}

#pragma mark Item selection

- (void)didSelectView:(RBUnlockCollectionView *)view
         selectedCell:(RBUnlockCollectionCell *)selectedCell {
    // Ignore taps until the confirmation popup's fade-out has dimmed it below the threshold.
    if (self.popupView && self.popupView.alpha > kPopupInteractiveAlpha) {
        return;
    }

    self.selectedView = view;
    self.selectedCell = selectedCell;

    RBUnlockPackageItemData *itemData = selectedCell.itemData;
    if (!selectedCell.badgeView.isHidden) {
        selectedCell.enabled = NO;
        [self getMusicInfoWithMusicID:itemData.identity];
        return;
    }

    UIView *hostView = [AppDelegate appDelegate].viewController.view;
    self.popupView = [[RBCustomInfoPopupView alloc] initWithFrame:hostView.bounds];
    self.popupView.itemData = itemData;
    self.popupView.pointLabel.number = [[RBExperienceData sharedInstance] getPoint];
    [self.popupView.yesButton addTarget:self
                                 action:@selector(yesButtonTap:)
                       forControlEvents:UIControlEventTouchUpInside];
    [self.popupView.noButton addTarget:self
                                action:@selector(noButtonTap:)
                      forControlEvents:UIControlEventTouchUpInside];
    [hostView addSubview:self.popupView];
    [self.popupView showAnimation];
}

- (void)yesButtonTap:(id)sender {
    float currentPoints = [[RBExperienceData sharedInstance] getPoint];
    RBUnlockPackageItemData *itemData = self.popupView.itemData;

    if ((float)itemData.point > currentPoints) {
        [UIAlertView showAlertShortageOfPoint];
        return;
    }

    [[RBExperienceData sharedInstance] addPoint:-(float)itemData.point];
    self.pointLabel.number = [[RBExperienceData sharedInstance] getPoint];

    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette &&
        [RBTutorialManager isTutorialCustomize]) {
        [RBTutorialManager setUnlockedItemInfo:self.popupView.itemData.type
                                        itemId:self.popupView.itemData.identity];
    }

    switch (static_cast<RBUnlockItemType>(self.popupView.itemData.type)) {
    case RBUnlockItemTypeBGM:
        [[RBExperienceData sharedInstance] addBGMType:self.popupView.itemData.identity];
        break;
    case RBUnlockItemTypeShot:
        [[RBExperienceData sharedInstance] addShotType:self.popupView.itemData.identity];
        break;
    case RBUnlockItemTypeExplosion:
        [[RBExperienceData sharedInstance] addExprosionType:self.popupView.itemData.identity];
        break;
    case RBUnlockItemTypeFrame:
        [[RBExperienceData sharedInstance] addFrameType:self.popupView.itemData.identity];
        break;
    case RBUnlockItemTypeBackground:
        [[RBExperienceData sharedInstance] addBackgroundType:self.popupView.itemData.identity];
        break;
    case RBUnlockItemTypeMusic:
        // Music items return early, taking no server-report or progress-overlay step.
        [[RBExperienceData sharedInstance] addMusicID:self.popupView.itemData.identity];
        [self.popupView hideAnimation];
        [[RBExperienceData sharedInstance] save];
        self.selectedCell.enabled = NO;
        [self getMusicInfoWithMusicID:self.popupView.itemData.identity];
        return;
    case RBUnlockItemTypeThema:
        [[RBExperienceData sharedInstance] addThemaID:self.popupView.itemData.identity];
        [[RBExperienceData sharedInstance] resetPoint:self.popupView.itemData.identity];
        [RBUserSettingData sharedInstance].newThema = YES;
        break;
    }

    [[RBExperienceData sharedInstance] save];
    [RBServerAPIManager unlockedAPIWithType:self.popupView.itemData.type
                                   identity:self.popupView.itemData.identity
                                      point:[[RBExperienceData sharedInstance] getPoint]];
    [self.popupView hideAnimation];

    self.progressOverlayView =
        [[DAProgressOverlayView alloc] initWithFrame:self.selectedCell.imageView.bounds];
    [self.selectedCell.imageView addSubview:self.progressOverlayView];
    [self.progressOverlayView displayOperationWillTriggerAnimation];
    [self.progressOverlayView setProgress:0.0];
    for (int step = 0; step < kProgressStepCount; ++step) {
        dispatch_time_t when = dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)((double)((float)step * kProgressTickFraction) * kNanosecondsPerSecond));
        dispatch_after(when, dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x198720 */
          [self.progressOverlayView setProgress:(float)step * kProgressIncrement];
          if (self.progressOverlayView.progress >= 1.0) {
              [self.progressOverlayView displayOperationDidFinishAnimation];
              [self.selectedView configureCell:self.selectedCell];
              SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectUnlocked);
          }
        });
    }
    [self reloadData];

    if ([RBTutorialManager isTutorialCustomize]) {
        self.parentCustomView.getCustomButtonView.enabled = YES;
        [self.parentCustomView.musicMenuView.tutorialView
            startTutorialWithType:kTutorialTypeExperience
                     withRootView:self.parentCustomView];
    }
}

- (void)noButtonTap:(id)sender {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectPopupCancel);
    [self.popupView hideAnimation];
}

#pragma mark Music download

- (void)getMusicInfoWithMusicID:(unsigned int)musicID {
    if (!self.selectedCell.frameImageView.isHidden) {
        self.progressOverlayView = [[DAProgressOverlayView alloc]
            initWithFrame:CGRectInset(self.selectedCell.frameImageView.bounds,
                                      kProgressOverlayInset,
                                      kProgressOverlayInset)];
        [self.selectedCell.frameImageView addSubview:self.progressOverlayView];
    } else {
        self.progressOverlayView = [[DAProgressOverlayView alloc]
            initWithFrame:CGRectInset(self.selectedCell.imageView.bounds,
                                      kProgressOverlayInset,
                                      kProgressOverlayInset)];
        [self.selectedCell.imageView addSubview:self.progressOverlayView];
    }
    [self.progressOverlayView displayOperationWillTriggerAnimation];
    [self.progressOverlayView setProgress:0.0];

    self.unlockRandomKey = rand() % kUnlockRandomKeyModulus;
    self.downloader = [[Downloader alloc]
        initWithURL:[NetworkUtil unlockMusicURL:musicID randKey:self.unlockRandomKey]
               save:nil];
    [self.downloader startDownloadingWithDelegate:self];
}

- (void)downloadWithMusicInfo:(StoreMusicInfo *)musicInfo {
    StoreDownloadTask *task = [[StoreDownloadTask alloc]
        initWithURL:musicInfo.itemURL
               path:[RBMusicManager getPathFromPurchesed:musicInfo.musicID]
          AddObject:[NSString stringWithString:musicInfo.name]];
    self.storeDownloadManager = [[StoreDownloadManager alloc] initWithTasks:@[ task ]
                                                                   delegate:self];
    self.dlMusicName = [NSString stringWithString:musicInfo.name];
    [self.storeDownloadManager start];
}

#pragma mark Downloader delegate

- (void)downloaderProceed:(Downloader *)downloader {
}

- (void)downloaderError:(Downloader *)downloader {
}

- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    NSNumber *echoedKey = json[kUnlockKeyEchoKey];

    StoreMusicInfo *musicInfo = nil;
    if (json && echoedKey && self.unlockRandomKey == echoedKey.intValue) {
        musicInfo = [[StoreMusicInfo alloc] initWithDictionary:json];
    }
    if (!musicInfo) {
        [self.progressOverlayView displayOperationDidFinishAnimation];
        [UIAlertView showNetworkErrorWithDelegate:nil];
        [self reloadData];
        return;
    }

    if ([[RBMusicManager getInstance] addPurchasedMusic:musicInfo]) {
        [[RBMusicManager getInstance] savePurchasedMusics];
    }
    [self downloadWithMusicInfo:musicInfo];
}

#pragma mark Store download manager delegate

- (void)downloadManagerStartTask:(StoreDownloadManager *)manager {
}

- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    [self.progressOverlayView setProgress:manager.overallProgress];
}

- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    [[AppDelegate appDelegate].viewController.musicMenuView reloadMusicData];
    [self.progressOverlayView displayOperationDidFinishAnimation];
    [self.selectedView configureCell:self.selectedCell];
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectUnlocked);
    [UIAlertView showUnlockedMusicInfoWithDelegate:nil musicName:self.dlMusicName];
    self.dlMusicName = nil;
    [self reloadData];
}

- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    self.dlMusicName = nil;
    [self reloadData];
}

#pragma mark Alert view delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self request];
}

@end
