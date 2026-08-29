#import "RBMenuMascot.h"

#import "RBCampaignData.h"
#import "RBUrlSchemeManager.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "gamesystem.h"
#import "s_vector2.h"

static NSString *const kNormalMascotAssetBase = @"01_music_select/as_mascot_";
static NSString *const kRareMascotAssetBase = @"01_music_select/as_mascot_r_";
static NSString *const kMessageBubbleAssetName = @"01_music_select/sel_popover_down";

static NSString *const kCampaignAssetNameFormat = @"%@/%@";
static NSString *const kFrameAssetNameFormat = @"%@%02d";

constexpr int kMascotFirstFrameIndex = 1;
constexpr int kMascotFrameIndexLimit = 101;
constexpr int kMascotFramesPerClip = 10;
constexpr int kMascotFrameCountPerClip = 9;

constexpr int kMascotRareThreshold = 80;
constexpr int kMascotRareModulus = 101;

constexpr CGFloat kMessageLabelOrigin = 2.0;
constexpr CGFloat kMessageBubblePaddingX = 18.0;
constexpr CGFloat kMessageBubblePaddingTop = 10.0;
constexpr CGFloat kMessageBubblePaddingBottom = 25.0;

constexpr CGFloat kMessageViewNudgeFraction = 0.125;

constexpr CGFloat kMascotNormalSpawnXOffset = 100.0;
constexpr CGFloat kMascotRareSpawnX = -100.0;

constexpr float kMascotBaseYOffsetPad = 300.0f;
constexpr float kMascotBaseYOffsetPhone = 150.0f;

constexpr float kMascotTapUpwardSpeed = 50.0f;

constexpr CGFloat kMascotMessageMaxWidthPad = 300.0;
constexpr CGFloat kMascotMessageMaxWidthPhone = 200.0;

constexpr CGFloat kMascotMessageLabelConstraintHeight = 40.0;

// The pool slot holds the float literal widened to double, not an exact 0.1.
// @ghidraAddress 0x2ec6a8
constexpr NSTimeInterval kMascotMoveAnimDuration = 0.1f;

constexpr NSTimeInterval kMessageAnimDuration = 0.2;

constexpr CGFloat kMessageBubbleCapInsetTop = 10.0;
constexpr CGFloat kMessageBubbleCapInsetLeft = 47.0;
constexpr CGFloat kMessageBubbleCapInsetBottom = 25.0;
constexpr CGFloat kMessageBubbleCapInsetRight = 9.0;

constexpr NSTimeInterval kMascotAnimationDuration = 0.25;

constexpr NSTimeInterval kMessageFadeOutDelay = 5.0;

constexpr CGFloat kMascotFontSizePad = 14.0;
constexpr CGFloat kMascotFontSizePhone = 11.0;

constexpr int kMascotBaseYSpreadPad = 40;
constexpr int kMascotBaseYSpreadPhone = 5;
constexpr float kMascotSpawnSpeedPad = -10.0f;
constexpr float kMascotSpawnSpeedPhone = -5.0f;

constexpr float kMascotTapDownwardAcceleration = -10.0f;

// The empty-string sentinel that means the campaign ticker is idle; tapping it advances the ticker.
static NSString *const kEmptyMessageText = @"";

constexpr RBUserSettingDataTheme kMascotMoveAnimTheme = RBUserSettingDataThemeColette;

static NSString *const kMessageURLKey = @"url";
static NSString *const kMessageTextKey = @"text";

@interface RBMenuMascot ()

@property(nonatomic, assign) S_VECTOR2 m_screenSize;

// The binary inlines this loop twice in -setup:, once per frame set.
- (void)loadFramesFromBase:(NSString *)base
                imageArray:(NSMutableArray *)imageArray
           frameCountArray:(NSMutableArray *)frameCountArray;

@end

@implementation RBMenuMascot

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    /** @ghidraAddress 0x2b578 */
    self = [super initWithFrame:frame];
    if (self) {
        self.normalImageArray = [NSMutableArray array];
        self.normalFrameCountArray = [NSMutableArray array];
        self.rareImageArray = [NSMutableArray array];
        self.rareFrameCountArray = [NSMutableArray array];
        self.mascotView = nil;
        self.type = 0;
        self.isAnimation = NO;
        self.speedX = 0.0f;
        (void)IsPad(); // Yes, the binary discards this call's result.
        self.scale = 1.0f;
    }
    return self;
}

#pragma mark - Setup

- (void)setup:(int)type {
    /** @ghidraAddress 0x2b774 */
    RBCampaignData *campaign = [RBCampaignData sharedInstance];
    self.type = type;
    [self stopAnimation];

    NSString *normalBase = kNormalMascotAssetBase;
    NSString *rareBase = kRareMascotAssetBase;
    NSString *bubbleName = kMessageBubbleAssetName;
    if ([campaign isCampaignHinabita201703]) {
        normalBase =
            [NSString stringWithFormat:kCampaignAssetNameFormat, campaign.campaignName, normalBase];
        rareBase =
            [NSString stringWithFormat:kCampaignAssetNameFormat, campaign.campaignName, rareBase];
        bubbleName =
            [NSString stringWithFormat:kCampaignAssetNameFormat, campaign.campaignName, bubbleName];
        self.isCampaignMode = YES;
    } else {
        self.isCampaignMode = NO;
    }

    [self loadFramesFromBase:normalBase
                  imageArray:self.normalImageArray
             frameCountArray:self.normalFrameCountArray];
    [self loadFramesFromBase:rareBase
                  imageArray:self.rareImageArray
             frameCountArray:self.rareFrameCountArray];

    UIImage *firstFrame = self.normalImageArray[0][0];
    CGSize firstFrameSize = firstFrame.size;
    self.frame = CGRectMake(0, 0, firstFrameSize.width, firstFrameSize.height);

    self.mascotView = [[UIImageView alloc] initWithFrame:self.bounds];
    [self addSubview:self.mascotView];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapped:)];
    [self addGestureRecognizer:tap];

    CGSize labelSize = [self generateCGSize:kEmptyMessageText];
    self.messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(kMessageLabelOrigin,
                                                                  kMessageLabelOrigin,
                                                                  labelSize.width,
                                                                  labelSize.height)];
    self.messageLabel.font =
        [UIFont systemFontOfSize:(IsPad()) ? kMascotFontSizePad : kMascotFontSizePhone];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.text = kEmptyMessageText;

    UIImage *bubbleImage = [[UIImage imageWithName:bubbleName]
        resizableImageWithCapInsets:UIEdgeInsetsMake(kMessageBubbleCapInsetTop,
                                                     kMessageBubbleCapInsetLeft,
                                                     kMessageBubbleCapInsetBottom,
                                                     kMessageBubbleCapInsetRight)
                       resizingMode:UIImageResizingModeStretch];
    self.messageBgView = [[UIImageView alloc] initWithImage:bubbleImage];
    self.messageBgView.frame =
        CGRectMake(0,
                   0,
                   self.messageLabel.frame.size.width + kMessageBubblePaddingX,
                   self.messageLabel.frame.size.height + kMessageBubblePaddingTop +
                       kMessageBubblePaddingBottom);

    self.messageView =
        [[UIView alloc] initWithFrame:CGRectMake(self.frame.size.width * kMessageViewNudgeFraction,
                                                 -self.messageBgView.frame.size.height,
                                                 self.messageBgView.frame.size.width,
                                                 self.messageBgView.frame.size.height)];
    [self.messageBgView addSubview:self.messageLabel];
    [self.messageView addSubview:self.messageBgView];
    [self addSubview:self.messageView];
    self.messageView.center = CGPointZero;
    self.messageView.alpha = 0;

    self.currentMessageIndex = -1;
    self.currentMessageIndex = 0;
    self.messageList = [RBCampaignData sharedInstance].messageList;
    self.messageViewAnimating = NO;
}

- (void)loadFramesFromBase:(NSString *)base
                imageArray:(NSMutableArray *)imageArray
           frameCountArray:(NSMutableArray *)frameCountArray {
    int clipIndex = 0;
    for (int frame = kMascotFirstFrameIndex; frame < kMascotFrameIndexLimit; ++frame) {
        NSString *assetName = [NSString stringWithFormat:kFrameAssetNameFormat, base, frame];
        UIImage *image = [UIImage imageWithName:assetName];
        if (image == nil) {
            break;
        }
        if (imageArray.count <= (NSUInteger)clipIndex) {
            [imageArray addObject:[NSMutableArray array]];
        }
        [imageArray[clipIndex] addObject:image];
        if (frame % kMascotFramesPerClip == kMascotFrameCountPerClip) {
            [frameCountArray addObject:@(kMascotFrameCountPerClip)];
            ++clipIndex;
        }
    }
}

#pragma mark - Wander animation

- (void)startAnimation:(id)sender {
    /** @ghidraAddress 0x2c850 */
    if (self.isAnimation) {
        return;
    }

    GameSystem *gameSystem = GameSystem::GetGameSystem();
    self.m_screenSize = S_VECTOR2(gameSystem->GetViewportWidth(), gameSystem->GetViewportHeight());

    BOOL playRare = NO;
    if (self.rareImageArray.count != 0) {
        srand((unsigned int)time(NULL));
        playRare = (rand() % kMascotRareModulus) >= kMascotRareThreshold;
    }

    NSMutableArray *clips = playRare ? self.rareImageArray : self.normalImageArray;
    srand((unsigned int)time(NULL));
    NSInteger clipIndex = rand() % (int)clips.count;
    [self.mascotView setAnimationImages:[NSArray arrayWithArray:clips[clipIndex]]];
    self.mascotView.animationDuration = kMascotAnimationDuration;
    self.mascotView.animationRepeatCount = 0;

    UIImage *firstFrame = clips[clipIndex][0];
    int baseYSpread = (IsPad()) ? kMascotBaseYSpreadPad : kMascotBaseYSpreadPhone;
    float baseYOffset = (IsPad()) ? kMascotBaseYOffsetPad : kMascotBaseYOffsetPhone;
    srand((unsigned int)time(NULL));
    int span = (1 - baseYSpread) + (int)(self.m_screenSize.y - baseYOffset);
    int randomBaseY = span != 0 ? (rand() % span) + baseYSpread : baseYSpread;
    self.baseY = (float)randomBaseY;
    self.accellY = 0.0f;

    CGFloat spawnX =
        playRare ? kMascotRareSpawnX : (self.m_screenSize.x + kMascotNormalSpawnXOffset);
    self.frame = CGRectMake(spawnX, self.baseY, firstFrame.size.width, firstFrame.size.height);

    self.mascotView.transform = CGAffineTransformMakeScale(-self.scale, self.scale);
    self.isAnimation = YES;
    [self.mascotView startAnimating];
    self.speedX = (IsPad()) ? kMascotSpawnSpeedPad : kMascotSpawnSpeedPhone;

    if (self.isCampaignMode && self.messageList != nil &&
        (NSUInteger)self.nextMessageIndex < self.messageList.count) {
        [self updateMessage];
    }
    [self update];
}

- (void)stopAnimation {
    /** @ghidraAddress 0x2d478 */
    self.isAnimation = NO;
    if (self.mascotView != nil) {
        [self.mascotView stopAnimating];
    }
    [self.mascotView setAnimationImages:nil];
}

- (CGPoint)getMovePoint {
    /** @ghidraAddress 0x2ebe4 */
    CGRect frame = self.frame;
    GameSystem *gameSystem = GameSystem::GetGameSystem();
    self.m_screenSize = S_VECTOR2(gameSystem->GetViewportWidth(), gameSystem->GetViewportHeight());

    CGFloat minY;
    CGFloat maxY;
    if (IsPad()) {
        minY = self.frame.size.height * 0.5;
        maxY = self.limitY - self.frame.size.height;
    } else {
        minY = self.frame.size.height;
        maxY = self.limitY + self.frame.size.height * -1.5;
    }

    CGFloat newX = frame.origin.x;
    CGFloat newY = frame.origin.y;
    if (self.isAnimation) {
        newY -= self.speedY;
        self.speedY = self.accellY + self.speedY;
        if (newY < minY) {
            self.speedY = 0.0f;
            newY = minY;
        }
        if (maxY < self.baseY) {
            self.baseY = (float)maxY;
        }
        newX -= self.speedX;
        if (self.baseY < newY) {
            self.speedY = 0.0f;
            self.accellY = 0.0f;
            newY = self.baseY;
        }

        if (newX < -self.m_screenSize.x) {
            self.speedX = -self.speedX;
            self.mascotView.transform = CGAffineTransformMakeScale(-self.scale, self.scale);
            srand((unsigned int)time(NULL));
            int span = ((int)maxY + 1) - (int)minY;
            int bounceY = span != 0 ? (rand() % span) + (int)minY : (int)minY;
            self.baseY = (float)bounceY;
            newY = (double)bounceY;
            newX = -self.m_screenSize.x;
        } else if (newX > self.limitX + self.m_screenSize.x) {
            self.speedX = -self.speedX;
            self.mascotView.transform = CGAffineTransformMakeScale(self.scale, self.scale);
            srand((unsigned int)time(NULL));
            int span = ((int)maxY + 1) - (int)minY;
            int bounceY = span != 0 ? (rand() % span) + (int)minY : (int)minY;
            self.baseY = (float)bounceY;
            newY = (double)bounceY;
            newX = self.limitX + self.m_screenSize.x;
        }
    }

    return CGPointMake(newX, newY);
}

- (void)update {
    /** @ghidraAddress 0x2e6c4 */
    if (!self.isAnimation) {
        return;
    }
    if ([RBUserSettingData sharedInstance].thema != kMascotMoveAnimTheme) {
        return;
    }
    // Both blocks capture self strongly, as the binary does, so the animation re-schedules itself.
    [UIView animateWithDuration:kMascotMoveAnimDuration
        delay:0
        // AllowUserInteraction, not BeginFromCurrentState: w2 is 0x00030002 at 0x2e7a8/0x2e7ac.
        options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear)
        animations:^{
          /** @ghidraAddress 0x2e80c */
          CGPoint movePoint = [self getMovePoint];
          CGRect frame = self.frame;
          frame.origin = movePoint;
          self.frame = frame;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x2e8a8 */
          [self update];
        }];
}

#pragma mark - Tap handling

- (void)onTapped:(UITapGestureRecognizer *)sender {
    /** @ghidraAddress 0x2e8c8 */
    if (!self.isCampaignMode) {
        self.speedY = self.scale * kMascotTapUpwardSpeed;
        self.accellY = self.scale * kMascotTapDownwardAcceleration;
        return;
    }

    if ([self.messageLabel.text isEqualToString:kEmptyMessageText]) {
        [self updateMessage];
        return;
    }

    NSString *url = self.messageList[self.currentMessageIndex][kMessageURLKey];
    if (url == nil || url.length == 0) {
        return;
    }
    if ([[RBUrlSchemeManager sharedManager] parseURL:[NSURL URLWithString:url]]) {
        if ([self.delegate respondsToSelector:@selector(showNotificationPageView)]) {
            [self.delegate performSelector:@selector(showNotificationPageView) withObject:nil];
        }
    }
}

#pragma mark - Message ticker

- (void)updateMessage {
    /** @ghidraAddress 0x2d54c */
    if (self.messageList == nil || self.messageList.count == 0 || self.messageViewAnimating) {
        return;
    }
    self.messageViewAnimating = YES;
    if (self.messageView == nil) {
        return;
    }
    __weak RBMenuMascot *weakSelf = self;
    [UIView animateWithDuration:kMessageAnimDuration
        animations:^{
          /** @ghidraAddress 0x2d754 */
          weakSelf.messageView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x2d7ec */
          RBMenuMascot *strongSelf = weakSelf;
          CGSize textSize = [strongSelf
              generateCGSize:strongSelf.messageList[strongSelf.nextMessageIndex][kMessageTextKey]];
          strongSelf.messageLabel.text =
              strongSelf.messageList[strongSelf.nextMessageIndex][kMessageTextKey];

          CGFloat bubbleWidth =
              (CGFloat)(float)(strongSelf.messageLabel.frame.size.width + kMessageBubblePaddingX);
          CGFloat bubbleImageWidth = strongSelf.messageBgView.image.size.width;
          if (bubbleWidth >= bubbleImageWidth) {
              strongSelf.messageLabel.frame = CGRectMake(
                  kMessageLabelOrigin, kMessageLabelOrigin, textSize.width, textSize.height);
          } else {
              strongSelf.messageLabel.frame = CGRectMake((bubbleImageWidth - textSize.width) * 0.5,
                                                         kMessageLabelOrigin,
                                                         textSize.width,
                                                         textSize.height);
          }
          strongSelf.messageBgView.frame =
              CGRectMake(0,
                         0,
                         bubbleWidth,
                         strongSelf.messageLabel.frame.size.height + kMessageBubblePaddingTop +
                             kMessageBubblePaddingBottom);

          CGFloat nudge = (!IsPad()) ? -kMessageViewNudgeFraction : kMessageViewNudgeFraction;
          strongSelf.messageView.frame = CGRectMake(strongSelf.frame.size.width * nudge,
                                                    -strongSelf.messageBgView.frame.size.height,
                                                    strongSelf.messageBgView.frame.size.width,
                                                    strongSelf.messageBgView.frame.size.height);
          [strongSelf.messageView sizeToFit];

          strongSelf.currentMessageIndex = strongSelf.nextMessageIndex;
          strongSelf.nextMessageIndex = strongSelf.nextMessageIndex + 1;
          if ((NSUInteger)strongSelf.nextMessageIndex >= strongSelf.messageList.count) {
              strongSelf.nextMessageIndex = 0;
          }

          [UIView animateWithDuration:kMessageAnimDuration
              animations:^{
                /** @ghidraAddress 0x2e2b0 */
                weakSelf.messageView.alpha = 1.0;
              }
              completion:^(BOOL innerFinished) {
                /** @ghidraAddress 0x2e348 */
                [UIView animateWithDuration:kMessageAnimDuration
                    delay:kMessageFadeOutDelay
                    options:0
                    animations:^{
                      /** @ghidraAddress 0x2e44c */
                      weakSelf.messageView.alpha = 0;
                    }
                    completion:^(BOOL fadeFinished) {
                      /** @ghidraAddress 0x2e4e4 */
                      weakSelf.messageLabel.text = kEmptyMessageText;
                      weakSelf.messageViewAnimating = NO;
                    }];
              }];
        }];
}

#pragma mark - Measurement

- (CGSize)generateCGSize:(NSString *)text {
    /** @ghidraAddress 0x2e5d4 */
    CGFloat maxWidth = (IsPad()) ? kMascotMessageMaxWidthPad : kMascotMessageMaxWidthPhone;
    CGFloat fontSize = (IsPad()) ? kMascotFontSizePad : kMascotFontSizePhone;
    UIFont *font = [UIFont systemFontOfSize:fontSize];
    return [text sizeWithFont:font
            constrainedToSize:CGSizeMake(maxWidth, kMascotMessageLabelConstraintHeight)
                lineBreakMode:NSLineBreakByWordWrapping];
}

@end
