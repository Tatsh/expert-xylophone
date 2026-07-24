//
//  RBUnlockView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBUnlockView). Verified against the
//  arm64 disassembly: -setupView's idiom- and theme-dependent soft-float geometry and
//  -reloadData's scroll-content layout were recovered from the register moves the decompiler folds
//  into pseudo-variables. This is an Objective-C++ file because it preloads the C++ shot-sound and
//  themed sound-effect engine singletons.
//

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

// The framed backdrop drawn behind the lime-point count.
static NSString *const kPointBackgroundImageName = @"04_customize/cus_fram_lockp";

// The JSON keys read out of the unlock-catalogue response.
static NSString *const kRewardBannerListKey = @"RewardBannerList";
static NSString *const kRewardBannerURLKey = @"URL";
static NSString *const kUnlockIDKey = @"ID";
// The music-info response key echoed back from the request's random key.
static NSString *const kUnlockKeyEchoKey = @"Key";

// The "@2x" retina marker inserted into or stripped from a banner URL before its extension.
static NSString *const kRetinaSuffix = @"@2x";

// The JSON body keys sent with the reward-check request.
static NSString *const kRewardCheckTargetKey = @"target";
static NSString *const kRewardCheckUserIDKey = @"user_id";
static NSString *const kRewardCheckPasswordKey = @"passwd";
static NSString *const kRewardCheckNonceKey = @"nonce";
static NSString *const kRewardCheckRewardIDKey = @"reward_id";
static NSString *const kRewardCheckAppliIDKey = @"appli_id";

// The JSON keys read out of the reward-check response.
static NSString *const kRewardCheckNonceEchoKey = @"CK";
static NSString *const kRewardListKey = @"RewardList";
static NSString *const kAppliIDKey = @"AppliID";
static NSString *const kRewardPointKey = @"Point";

// The content type of the reward-check request body.
static NSString *const kJsonContentType = @"application/json";

// The item type values decided by the confirmation popup; each routes to a different
// RBExperienceData grant.
typedef enum {
    RBUnlockItemTypeBGM = 0,
    RBUnlockItemTypeShot = 1,
    RBUnlockItemTypeExplosion = 2,
    RBUnlockItemTypeFrame = 3,
    RBUnlockItemTypeBackground = 4,
    RBUnlockItemTypeMusic = 7,
    RBUnlockItemTypeThema = 10,
} RBUnlockItemType;

// The player theme identifiers returned by -[RBUserSettingData thema].
typedef enum {
    RBUnlockViewThemeLimelight = 1,
    RBUnlockViewThemeColette = 2,
} RBUnlockViewTheme;

// The sound-effect slots played by the picker.
constexpr int kSoundEffectPopupCancel = 4;
constexpr int kSoundEffectUnlocked = 9;

// The tutorial type launched once a music item has been unlocked during the customise walkthrough.
constexpr NSInteger kTutorialTypeExperience = 0x20;

// The reward banner button is inset ten points from the scroll view's left and top, and its width
// and height each leave a twenty-point margin.
constexpr CGFloat kRewardButtonInset = 10.0;
constexpr CGFloat kRewardButtonMargin = 20.0;

// Each package row, and the reward banner, are laid out at this fixed height, by device idiom.
constexpr CGFloat kPackageRowHeightNarrow = 124.0;
constexpr CGFloat kPackageRowHeightWide = 144.0;

// The gap left above the first package row, by device idiom.
constexpr CGFloat kPackageRowGapNarrow = 4.0;
constexpr CGFloat kPackageRowGapWide = 10.0;

// On the narrow font, the reward banner occupies eighty per cent of a row height above the first
// package row.
constexpr CGFloat kRewardBannerRowFactor = 0.8;

// The lime-point backdrop sits centred horizontally, at a idiom-dependent vertical offset.
constexpr CGFloat kPointBackgroundCentreFactor = 0.5;
constexpr CGFloat kPointBackgroundTopNarrow = 34.0;
constexpr CGFloat kPointBackgroundTopWide = 70.0;

// The lime-point count label geometry, chosen by device idiom and theme.
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

// The gap between the lime-point backdrop and the package scroll view, by device idiom.
constexpr CGFloat kScrollTopMarginNarrow = 4.0;
constexpr CGFloat kScrollTopMarginWide = 10.0;

// The extra scroll content height left below the last package row, by device idiom.
constexpr CGFloat kScrollContentPadNarrow = 45.0;
constexpr CGFloat kScrollContentPadWide = 70.0;

// The loading spinner's dimmed backdrop and rounded corner.
constexpr CGFloat kSpinnerBackgroundAlpha = 0.5;
constexpr CGFloat kSpinnerCornerRadius = 5.0;

// The number of trailing characters of a banner URL that make up its file extension, spliced around
// when the "@2x" retina marker is inserted.
constexpr NSUInteger kFileExtensionLength = 4;

// The length of the nonce generated for the reward-check request.
constexpr int kNonceLength = 0x20;

// The confirmation popup ignores taps once its fade-out has dimmed it below this alpha.
constexpr CGFloat kPopupInteractiveAlpha = 0.01;

// The download-progress spinner is inset three points from the cell's artwork bounds.
constexpr CGFloat kProgressOverlayInset = 3.0;

// The music-info request key echoed back to guard against a stale response is masked to sixteen
// bits.
constexpr int kUnlockRandomKeyModulus = 0xffff;

// The unlock reveal steps the progress overlay from empty to full over eleven ticks, advancing it
// by a tenth each and spacing the ticks a twentieth of a second apart.
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

// The binary's -dealloc (0x991a4) only chains to [super dealloc]; under ARC that chaining is
// automatic, so no override is reconstructed. The strong subview ivars and the weak
// parentCustomView/selectedView/selectedCell references are cleared by the compiler-generated
// .cxx_destruct (0x99ea0).

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

    // The lime-point backdrop, centred horizontally and dropped by a idiom-dependent offset.
    UIImage *backgroundImage = [UIImage imageWithName:kPointBackgroundImageName];
    self.pointBackgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
    CGFloat backgroundTop = (!isPad) ? kPointBackgroundTopNarrow : kPointBackgroundTopWide;
    self.pointBackgroundView.frame =
        CGRectMake((self.width - self.pointBackgroundView.width) * kPointBackgroundCentreFactor,
                   backgroundTop,
                   self.pointBackgroundView.width,
                   self.pointBackgroundView.height);
    [self addSubview:self.pointBackgroundView];

    self.pointLabel = [[RBNumberLabel alloc] init];
    self.pointLabel.imageType = RBNumberLabelImageTypeDecimal;
    [self.pointBackgroundView addSubview:self.pointLabel];

    // The lime-point count label geometry and the scroll-view top margin are chosen by device idiom
    // and, for the wide font, by theme.
    CGFloat scrollTopMargin = kScrollTopMarginWide;
    if (!isPad) {
        self.pointLabel.frame = CGRectMake(kPointLabelNarrowX,
                                           kPointLabelNarrowY,
                                           kPointLabelNarrowWidth,
                                           kPointLabelNarrowHeight);
        scrollTopMargin = kScrollTopMarginNarrow;
    } else {
        RBUnlockViewTheme theme =
            static_cast<RBUnlockViewTheme>([RBUserSettingData sharedInstance].thema);
        if (theme == RBUnlockViewThemeLimelight) {
            self.pointLabel.frame = CGRectMake(kPointLabelWideX,
                                               kPointLabelLimelightY,
                                               kPointLabelWideWidth,
                                               kPointLabelLimelightHeight);
        } else if (theme == RBUnlockViewThemeColette) {
            self.pointLabel.frame = CGRectMake(kPointLabelWideX,
                                               kPointLabelColetteY,
                                               kPointLabelWideWidth,
                                               kPointLabelColetteHeight);
        }
    }

    // The package scroll view fills the width below the lime-point backdrop.
    CGFloat scrollTop = scrollTopMargin + self.pointBackgroundView.bottom;
    self.scrollView =
        [[UIScrollView alloc] initWithFrame:CGRectMake(0.0,
                                                       scrollTop,
                                                       self.frame.size.width,
                                                       self.frame.size.height - scrollTop)];
    [self addSubview:self.scrollView];

    // The loading spinner, dimmed and rounded, pinned to the view centre.
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

    // Each package row, the reward banner, and the row spacing are sized by the iPad idiom.
    CGFloat rowHeight = (!isPad) ? kPackageRowHeightNarrow : kPackageRowHeightWide;
    CGFloat rowGap = (!isPad) ? kPackageRowGapNarrow : kPackageRowGapWide;
    CGFloat viewWidth = self.frame.size.width;

    self.pointLabel.number = [[RBExperienceData sharedInstance] getPoint];

    // Clear the previous packages out of the scroll view.
    for (UIView *subview in self.scrollView.subviews) {
        [subview removeFromSuperview];
    }

    // Lay the reward banner button out at the top when a banner is available, and start each row of
    // packages below it.
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
                startDownloadWithProceed:nil
                                 success:^(ImageDownloader *downloader) {
                                   /** @ghidraAddress 0x95390 */
                                   [self.rewardButton setImage:[downloader getImage]
                                                      forState:UIControlStateNormal];
                                   if (!IsPad()) {
                                       CGFloat width = viewWidth - kRewardButtonMargin;
                                       CGSize imageSize = [downloader getImage].size;
                                       self.rewardButton.frame =
                                           CGRectMake(kRewardButtonInset,
                                                      kRewardButtonInset,
                                                      width,
                                                      width / (imageSize.width / width));
                                   } else {
                                       self.rewardButton.frame =
                                           CGRectMake(kRewardButtonInset,
                                                      kRewardButtonInset,
                                                      viewWidth - kRewardButtonMargin,
                                                      rowHeight - kRewardButtonMargin);
                                   }
                                 }
                                 failure:nil];
        }
        contentTop =
            (!isPad) ? (rowGap + rowHeight * kRewardBannerRowFactor) : (rowHeight + rowGap);
    }

    // One collection view per package, stacked down the scroll view at the fixed row height.
    CGFloat rowTop = contentTop;
    for (RBUnlockPackageData *packageData in [[RBUnlockData sharedInstance] getPackage]) {
        RBUnlockCollectionView *collectionView = [[RBUnlockCollectionView alloc]
                    initWithFrame:CGRectMake(0.0, rowTop, viewWidth, rowHeight)
            experiencePackageData:packageData];
        collectionView.tag = 0;
        collectionView.delegate = self;
        [self.scrollView addSubview:collectionView];
        rowTop += rowHeight;
    }

    // Size the scroll content to fit every row plus a idiom-dependent bottom pad.
    CGFloat bottomPad = (!isPad) ? kScrollContentPadNarrow : kScrollContentPadWide;
    self.scrollView.contentSize = CGSizeMake(self.frame.size.width, rowTop + bottomPad);
}

#pragma mark Requests

- (void)request {
    [self.activityIndicatorView startAnimating];

    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil unlockListURL] save:nil];
    __weak RBUnlockView *weakSelf = self;
    [self.downloader
        startDownloadingWithProceed:^{
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x95858 */
          NSDictionary *json = [downloader getDataInJSON];

          // On the Limelight theme, take the first reward banner and normalise its URL for the
          // current retina state before storing.
          if ([RBUserSettingData sharedInstance].thema == RBUnlockViewThemeLimelight &&
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
                /** @ghidraAddress 0x96114 */
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
          /** @ghidraAddress 0x963ac */
          // Dispatch the stop-indicator/show-error handler to the main queue.
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
        startDownloadingWithProceed:^{
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x96be0 */
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
                /** @ghidraAddress 0x97168 */
                weakSelf.alertView = [UIAlertView showAddLimepointByApplilink:totalPoints:nil];
                [weakSelf reloadData];
              });
          }
        }
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0x96530 */
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
    // Ignore taps while the confirmation popup is still visible (its fade-out has not yet dimmed it
    // below the interactive threshold).
    if (self.popupView && self.popupView.alpha > kPopupInteractiveAlpha) {
        return;
    }

    self.selectedView = view;
    self.selectedCell = selectedCell;

    RBUnlockPackageItemData *itemData = selectedCell.itemData;
    if (!selectedCell.badgeView.isHidden) {
        // Already unlocked: re-download the item's content directly.
        selectedCell.enabled = NO;
        [self getMusicInfoWithMusicID:itemData.identity];
        return;
    }

    // Not yet unlocked: present the confirmation popup over the menu.
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

    // Reject the unlock when the player cannot afford it.
    if ((float)itemData.point > currentPoints) {
        [UIAlertView showAlertShortageOfPoint];
        return;
    }

    [[RBExperienceData sharedInstance] addPoint:-(float)itemData.point];
    self.pointLabel.number = [[RBExperienceData sharedInstance] getPoint];

    // Record the unlock for the customise walkthrough when it is running on the Colette theme.
    if ([RBUserSettingData sharedInstance].thema == RBUnlockViewThemeColette &&
        [RBTutorialManager isTutorialCustomize]) {
        [RBTutorialManager setUnlockedItemInfo:self.popupView.itemData.type
                                        itemId:self.popupView.itemData.identity];
    }

    // Grant the unlock into RBExperienceData according to the item type.
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
        // Music items grant, dismiss the popup, and then start the track download; they take no
        // further server-report or progress-overlay steps here.
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

    // Play the unlock reveal over the tapped cell, ticking the progress overlay to full.
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
          /** @ghidraAddress 0x98720 */
          [self.progressOverlayView setProgress:(float)step * kProgressIncrement];
          if (self.progressOverlayView.progress >= 1.0) {
              [self.progressOverlayView displayOperationDidFinishAnimation];
              [self.selectedView configureCell:self.selectedCell];
              SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectUnlocked);
          }
        });
    }
    [self reloadData];

    // On the customise walkthrough, re-enable the set button and launch the experience tutorial.
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
    // Overlay the tapped cell's frame artwork, or its plain artwork when the frame is hidden, with a
    // progress spinner inset from the artwork bounds.
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

    // The response is only trusted when it carries a key that matches the request's random key and
    // parses into store music info; anything else is a network error.
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
