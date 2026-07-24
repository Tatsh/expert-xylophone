#import "RBPushNotificationView.h"

#import "AppDelegate.h"
#import "RBUrlSchemeManager.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "neEngineBridge.h"

// The music-menu themed sound-effect slot played when the banner slides into view. This is the
// same slot the search bar uses for its slide-in in RBMenuView.
constexpr int kSoundEffectNotificationShow = 0x11;

// The default top inset, in points, applied above the banner.
constexpr float kDefaultUpMargin = 2.0f;

// The auto-hide delay, in seconds, before the banner slides back off-screen.
constexpr double kAutoHideDelay = 7.0;

// The banner background artwork.
static NSString *const kNotificationBackgroundImageName = @"01_music_select/sel_push_bg";

// The keys of a popped push-notification dictionary.
static NSString *const kNotificationBodyKey = @"body";
static NSString *const kNotificationURLKey = @"url";

// The URL scheme handed back to the delegate rather than routed through RBUrlSchemeManager.
static NSString *const kExternalURLScheme = @"http";

// Message-label geometry and font size for the default (region) iPad idiom.
constexpr CGRect kMessageLabelFrameDefault{{120.0, 7.0}, {190.0, 32.0}};
constexpr CGFloat kMessageLabelFontSizeDefault = 12.0;

// Message-label geometry and font size for the iPad (wide) layout.
constexpr CGRect kMessageLabelFrameWide{{186.0, 14.0}, {290.0, 40.0}};
constexpr CGFloat kMessageLabelFontSizeWide = 14.0;

// The message label wraps onto at most two lines.
constexpr NSInteger kMessageLabelLineCount = 2;

@implementation RBPushNotificationView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    return [super initWithFrame:frame];
}

- (void)dealloc {
    self.delegate = nil;
    [self stopTimer];
}

#pragma mark - Setup

- (void)setupViewWithDelegate:(id)delegate {
    self.upMargin = kDefaultUpMargin;
    self.backgroundColor = UIColor.clearColor;
    self.delegate = delegate;

    UIImage *bgImage = [UIImage imageWithName:kNotificationBackgroundImageName];
    self.bgView = [[UIImageView alloc] initWithImage:bgImage];
    self.bgView.frame = CGRectMake((self.width - self.bgView.width) * 0.5,
                                   self.upMargin,
                                   self.bgView.width,
                                   self.bgView.height);

    if (!IsPad()) {
        self.messageLabel = [[UILabel alloc] initWithFrame:kMessageLabelFrameDefault];
        self.messageLabel.font = [UIFont systemFontOfSize:kMessageLabelFontSizeDefault];
    } else {
        self.messageLabel = [[UILabel alloc] initWithFrame:kMessageLabelFrameWide];
        self.messageLabel.font = [UIFont systemFontOfSize:kMessageLabelFontSizeWide];
    }
    self.messageLabel.numberOfLines = kMessageLabelLineCount;
    self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.bgView addSubview:self.messageLabel];

    self.frame = CGRectMake(0, -self.bgView.height, self.width, self.bgView.height + self.upMargin);
    [self addSubview:self.bgView];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapped:)];
    [self addGestureRecognizer:tap];
    self.hidden = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.bgView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
}

#pragma mark - Presentation

- (void)showNotification {
    [self setNextNotification];
    [self showAnimation];
}

- (void)setNextNotification {
    NSDictionary *data = [AppDelegate popPushNotificationData];
    self.message = data[kNotificationBodyKey];
    self.urlString = data[kNotificationURLKey];
    self.messageLabel.text = self.message;
}

- (void)showAnimation {
    self.frame = CGRectMake(self.x, -self.height, self.width, self.height);
    self.hidden = NO;
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectNotificationShow);
    [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
        delay:0.0
        options:UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x18ede0 */
          self.frame = CGRectMake(self.x, 0, self.width, self.height);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x18ee6c */
          [self stopTimer];
          self.timer = [NSTimer timerWithTimeInterval:kAutoHideDelay
                                               target:self
                                             selector:@selector(hideAnimationStart)
                                             userInfo:nil
                                              repeats:NO];
          [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        }];
}

#pragma mark - Dismissal

- (void)hideAnimationStart {
    [self stopTimer];
    [self performSelectorOnMainThread:@selector(hideAnimation) withObject:nil waitUntilDone:YES];
}

- (void)hideAnimation {
    __weak RBPushNotificationView *weakSelf = self;
    [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
        animations:^{
          /** @ghidraAddress 0x18f0fc */
          weakSelf.frame =
              CGRectMake(weakSelf.x, -weakSelf.height, weakSelf.width, weakSelf.height);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x18f254 */
          weakSelf.hidden = YES;
          [weakSelf stopTimer];
          [weakSelf.delegate performSelector:@selector(finishPushNotification)];
        }];
}

#pragma mark - Interaction

- (void)onTapped:(UITapGestureRecognizer *)sender {
    if (self.urlString == nil) {
        return;
    }
    NSURL *tappedURL = [NSURL URLWithString:self.urlString];
    if ([[RBUrlSchemeManager sharedManager] parseURL:[NSURL URLWithString:self.urlString]]) {
        if ([self.delegate respondsToSelector:@selector(actionFromPushNotificationView)]) {
            [self hideAnimationStart];
            // The binary passes the delegate itself as the argument; the receiver ignores it.
            [self.delegate performSelector:@selector(actionFromPushNotificationView)
                                withObject:self.delegate];
        }
        return;
    }
    if ([tappedURL.scheme isEqualToString:kExternalURLScheme]) {
        [AppDelegate setOuterURL:tappedURL];
        [self hideAnimationStart];
        // The binary passes the delegate itself as the argument; the receiver ignores it.
        [self.delegate performSelector:@selector(actionFromPushNotificationView)
                            withObject:self.delegate];
    }
}

#pragma mark - Timer

- (void)stopTimer {
    if (self.timer != nil) {
        [self.timer invalidate];
    }
    self.timer = nil;
}

@end
