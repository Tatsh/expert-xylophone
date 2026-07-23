//
//  RBMenuMascot.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMenuMascot). Verified against the
//  arm64 disassembly: the wander physics and the message-bubble layout use soft-float register moves
//  that the decompiler folds into pseudo-variables, so the CGRect/CGSize maths were recovered from
//  the disassembly. This is an Objective-C++ file because -startAnimation:, -getMovePoint, and
//  -update reach the C++ GameSystem engine singleton and the S_VECTOR2 engine vector type.
//

#import "RBMenuMascot.h"

#import "RBCampaignData.h"
#import "RBUrlSchemeManager.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The base asset names for the mascot sprite frames and the campaign message bubble background.
static NSString *const kNormalMascotAssetBase = @"01_music_select/as_mascot_";
static NSString *const kRareMascotAssetBase = @"01_music_select/as_mascot_r_";
static NSString *const kMessageBubbleAssetName = @"01_music_select/sel_popover_down";

// The format that joins the campaign name to a base asset name, and the format that appends a
// two-digit frame index to a base asset name.
static NSString *const kCampaignAssetNameFormat = @"%@/%@";
static NSString *const kFrameAssetNameFormat = @"%@%02d";

// Sprite-frame loading: frame indices run 1..100 and are grouped into clips of ten frames.
constexpr int kMascotFirstFrameIndex = 1;
constexpr int kMascotFrameIndexLimit = 101;
constexpr int kMascotFramesPerClip = 10;
constexpr int kMascotFrameCountPerClip = 9;

// The tap rarity gate: a random value below this threshold (out of 100) plays a normal clip, at or
// above it plays a rare clip.
constexpr int kMascotRareThreshold = 80;
constexpr int kMascotRareModulus = 101;

// The message-label origin inside the bubble, and the padding added around the label to size the
// bubble background.
constexpr CGFloat kMessageLabelOrigin = 2.0;
constexpr CGFloat kMessageBubblePaddingX = 18.0;
constexpr CGFloat kMessageBubblePaddingTop = 10.0;
constexpr CGFloat kMessageBubblePaddingBottom = 25.0;

// The horizontal nudge applied to the message view, as a fraction of the bubble width, chosen by
// iPad idiom.
constexpr CGFloat kMessageViewNudgeFraction = 0.125;

// The horizontal spawn positions: the normal mascot spawns just off the right screen edge (frame
// width plus this offset) and the rare mascot spawns off the left edge.
constexpr CGFloat kMascotNormalSpawnXOffset = 100.0;
constexpr CGFloat kMascotRareSpawnX = -100.0;

// The resting-height random-range base offset subtracted from the screen height, chosen by font
// variant.
constexpr float kMascotBaseYOffsetPad = 300.0f;
constexpr float kMascotBaseYOffsetPhone = 150.0f;

// The upward launch speed multiplier applied to speedY on a tap (scaled by the mascot scale).
constexpr float kMascotTapUpwardSpeed = 50.0f;

// The message-label constrained max width, chosen by device idiom.
constexpr CGFloat kMascotMessageMaxWidthPad = 300.0;
constexpr CGFloat kMascotMessageMaxWidthPhone = 200.0;

// The height the campaign message text is constrained to when measured in -generateCGSize:.
constexpr CGFloat kMascotMessageLabelConstraintHeight = 40.0;

// The per-frame move animation duration on the Colette theme.
constexpr NSTimeInterval kMascotMoveAnimDuration = 0.1;

// The message-ticker fade/slide animation duration.
constexpr NSTimeInterval kMessageAnimDuration = 0.2;

// The resizable message-bubble background cap insets.
constexpr CGFloat kMessageBubbleCapInsetTop = 10.0;
constexpr CGFloat kMessageBubbleCapInsetLeft = 47.0;
constexpr CGFloat kMessageBubbleCapInsetBottom = 25.0;
constexpr CGFloat kMessageBubbleCapInsetRight = 9.0;

// The sprite-animation frame rate, expressed as the seconds-per-cycle duration UIImageView uses.
constexpr NSTimeInterval kMascotAnimationDuration = 0.25;

// The message-ticker fade-out hold before the label is cleared.
constexpr NSTimeInterval kMessageFadeOutDelay = 5.0;

// The mascot base font point sizes, chosen by device idiom (iPad vs phone).
constexpr CGFloat kMascotFontSizePad = 14.0;
constexpr CGFloat kMascotFontSizePhone = 11.0;

// The vertical resting-height random spread, and the base spawn horizontal speed, chosen by font
// variant.
constexpr int kMascotBaseYSpreadPad = 40;
constexpr int kMascotBaseYSpreadPhone = 5;
constexpr float kMascotSpawnSpeedPad = -10.0f;
constexpr float kMascotSpawnSpeedPhone = -5.0f;

// The downward acceleration applied to the mascot after a tap.
constexpr float kMascotTapDownwardAcceleration = -10.0f;

// The empty-string sentinel that means the campaign ticker is idle; tapping it advances the ticker.
static NSString *const kEmptyMessageText = @"";

// The Colette theme value that runs the per-frame move animation.
constexpr RBUserSettingDataTheme kMascotMoveAnimTheme = RBUserSettingDataThemeColette;

// The message-bubble URL key looked up in a campaign message dictionary.
static NSString *const kMessageURLKey = @"url";
static NSString *const kMessageTextKey = @"text";

@interface RBMenuMascot ()

// The cached GL viewport size the wander physics measures against. It is a private engine vector,
// so it lives in the class continuation rather than the public header.
@property(nonatomic, assign) S_VECTOR2 m_screenSize;

// The sprite-frame loading loop that -setup: runs once for the normal frames and once for the rare
// frames; the binary inlines it twice.
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
        self.speedX = (IsPad()) ? kMascotSpawnSpeedPad : kMascotSpawnSpeedPhone;
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

    self.messageView = [[UIView alloc]
        initWithFrame:CGRectMake(self.messageBgView.frame.size.width * kMessageViewNudgeFraction,
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

// Loads the mascot sprite frames from a base asset name into clip sub-arrays: frame indices run
// 1..100 (stopping at the first missing frame) and are grouped into clips of ten, with a nine-frame
// count pushed for each completed clip.
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
    int span = (1 - baseYSpread) + (int)(self.m_screenSize.GetY() - baseYOffset);
    int randomBaseY = span != 0 ? (rand() % span) + baseYSpread : baseYSpread;
    self.baseY = (float)randomBaseY;
    self.accellY = 0.0f;

    CGFloat spawnX =
        playRare ? kMascotRareSpawnX : (firstFrame.size.width + kMascotNormalSpawnXOffset);
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

        if (newX < -self.m_screenSize.GetX()) {
            self.speedX = -self.speedX;
            self.mascotView.transform = CGAffineTransformMakeScale(-self.scale, self.scale);
            srand((unsigned int)time(NULL));
            int span = ((int)maxY + 1) - (int)minY;
            int bounceY = span != 0 ? (rand() % span) + (int)minY : (int)minY;
            self.baseY = (float)bounceY;
            newY = (double)bounceY;
            newX = -self.m_screenSize.GetX();
        } else if (newX > self.limitX + self.m_screenSize.GetX()) {
            self.speedX = -self.speedX;
            self.mascotView.transform = CGAffineTransformMakeScale(self.scale, self.scale);
            srand((unsigned int)time(NULL));
            int span = ((int)maxY + 1) - (int)minY;
            int bounceY = span != 0 ? (rand() % span) + (int)minY : (int)minY;
            self.baseY = (float)bounceY;
            newY = (double)bounceY;
            newX = self.limitX + self.m_screenSize.GetX();
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
    // The binary captures self strongly in both blocks (no weak reference), so the ticking move
    // animation re-schedules itself each frame while the wander animation is running.
    [UIView animateWithDuration:kMascotMoveAnimDuration
        delay:0
        options:(UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveLinear)
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
          // Advances the ticker to the next message and animates it in.
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
          strongSelf.messageView.frame =
              CGRectMake(strongSelf.messageBgView.frame.size.width * nudge,
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
                // Fades the message view out after a hold, then clears the label and idles the ticker.
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
