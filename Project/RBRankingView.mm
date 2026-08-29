#import "RBRankingView.h"

#import "RBRankingTableView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "deviceenvironment.h"
#import "soundeffectmanager.h"

constexpr int kSoundEffectCancel = 1;

constexpr GKLeaderboardPlayerScope kPlayerScopeTotal = GKLeaderboardPlayerScopeGlobal;
constexpr GKLeaderboardPlayerScope kPlayerScopeFriend = GKLeaderboardPlayerScopeFriendsOnly;

constexpr CGFloat kTableWideAnchorX = 134.0;
constexpr CGFloat kTableWideAnchorY = 295.0;
constexpr CGFloat kTableWideWidth = 496.0;
constexpr CGFloat kTableWideHeight = 530.0;

constexpr CGFloat kTableTallThemedX = 10.0;
constexpr CGFloat kTableTallThemedY = 75.0;
constexpr CGFloat kTableTallThemedWidth = 300.0;
constexpr CGFloat kTableTallThemedHeight = 241.0;

constexpr CGFloat kTableTallClassicWidthInset = -300.0;
constexpr CGFloat kTableTallClassicWidth = 300.0;
constexpr CGFloat kTableTallClassicY = 50.0;
constexpr CGFloat kTableTallClassicHeight = 246.0;

constexpr CGFloat kHalf = 0.5;

constexpr CGFloat kFriendButtonWideAnchorX = 179.0;
constexpr CGFloat kFriendButtonWideAnchorY = 235.0;
constexpr CGFloat kFriendButtonTallCenterX = 71.0;
constexpr CGFloat kFriendButtonTallThemedX = 18.0;

constexpr CGFloat kAllButtonWideAnchorX = 437.0;
constexpr CGFloat kAllButtonWideAnchorY = 235.0;
constexpr CGFloat kAllButtonTallCenterXInset = -71.0;
constexpr CGFloat kAllButtonTallThemedX = 188.0;

constexpr CGFloat kTabButtonTallCenterY = 33.0;
constexpr CGFloat kTabButtonTallThemedY = 35.0;

static NSString *const kFriendButtonImageName = @"08_ranking/rank_fri";
static NSString *const kFriendButtonSelectedImageName = @"08_ranking/rank_fri_sel";
static NSString *const kAllButtonImageName = @"08_ranking/rank_all";
static NSString *const kAllButtonSelectedImageName = @"08_ranking/rank_all_sel";

@implementation RBRankingView {
    // Whether a show or hide animation is currently running, distinct from the base popup's flag.
    BOOL m_Animating;
    int _thema;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeRanking];
        [self setupView];
    }
    return self;
}

- (void)dealloc {
    // The base popup's teardown runs through super.
}

#pragma mark - Setup

- (void)setupView {
    [super setupView];

    BOOL isPad = IsPad();
    _thema = [RBUserSettingData sharedInstance].thema;

    CGRect tableFrame;
    if (isPad) {
        CGFloat baseX = self.baseView.frame.origin.x;
        CGFloat contentX = self.contentView.frame.origin.x;
        CGFloat baseY = self.baseView.frame.origin.y;
        CGFloat contentY = self.contentView.frame.origin.y;
        tableFrame = CGRectMake(kTableWideAnchorX - baseX - contentX,
                                kTableWideAnchorY - baseY - contentY,
                                kTableWideWidth,
                                kTableWideHeight);
    } else if (_thema != RBUserSettingDataThemeClassic) {
        tableFrame = CGRectMake(
            kTableTallThemedX, kTableTallThemedY, kTableTallThemedWidth, kTableTallThemedHeight);
    } else {
        CGFloat contentWidth = self.contentView.frame.size.width;
        tableFrame = CGRectMake((contentWidth + kTableTallClassicWidthInset) * kHalf,
                                kTableTallClassicY,
                                kTableTallClassicWidth,
                                kTableTallClassicHeight);
    }

    RBRankingTableView *friendTable =
        [[RBRankingTableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    [friendTable setPlayerScope:kPlayerScopeFriend];
    [friendTable loadRanking];
    friendTable.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.contentView addSubview:friendTable];
    self.friendRanking = friendTable;

    RBRankingTableView *totalTable =
        [[RBRankingTableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    [totalTable setPlayerScope:kPlayerScopeTotal];
    [totalTable loadRanking];
    totalTable.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.contentView addSubview:totalTable];
    self.totalRanking = totalTable;

    UIImage *friendImage = [UIImage imageWithName:kFriendButtonImageName];
    CGSize friendSize = friendImage.size;
    self.friendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.friendButton setImage:friendImage forState:UIControlStateNormal];
    [self.friendButton setImage:friendImage forState:UIControlStateSelected];
    if (isPad) {
        CGFloat baseX = self.baseView.frame.origin.x;
        CGFloat contentX = self.contentView.frame.origin.x;
        CGFloat baseY = self.baseView.frame.origin.y;
        CGFloat contentY = self.contentView.frame.origin.y;
        self.friendButton.frame = CGRectMake(kFriendButtonWideAnchorX - baseX - contentX,
                                             kFriendButtonWideAnchorY - baseY - contentY,
                                             friendSize.width,
                                             friendSize.height);
    } else {
        self.friendButton.bounds = CGRectMake(0, 0, friendSize.width, friendSize.height);
        self.friendButton.center = CGPointMake(kFriendButtonTallCenterX, kTabButtonTallCenterY);
        if (_thema != RBUserSettingDataThemeClassic) {
            self.friendButton.frame = CGRectMake(kFriendButtonTallThemedX,
                                                 kTabButtonTallThemedY,
                                                 friendSize.width,
                                                 friendSize.height);
        }
    }
    self.friendButton.exclusiveTouch = YES;
    self.friendButton.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.friendButton addTarget:self
                          action:@selector(SelectFriendButton)
                forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.friendButton];

    self.friendButtonEffect =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kFriendButtonSelectedImageName]];
    self.friendButtonEffect.center = CGPointMake(self.friendButton.bounds.size.width * kHalf,
                                                 self.friendButton.bounds.size.height * kHalf);
    self.friendButtonEffect.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.friendButtonEffect SetFlashEffectFast];
    [self.friendButton addSubview:self.friendButtonEffect];

    UIImage *allImage = [UIImage imageWithName:kAllButtonImageName];
    CGSize allSize = allImage.size;
    self.allButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.allButton setImage:allImage forState:UIControlStateNormal];
    [self.allButton setImage:allImage forState:UIControlStateSelected];
    self.allButton.bounds = CGRectMake(0, 0, allSize.width, allSize.height);
    if (isPad) {
        CGFloat baseX = self.baseView.frame.origin.x;
        CGFloat contentX = self.contentView.frame.origin.x;
        CGFloat baseY = self.baseView.frame.origin.y;
        CGFloat contentY = self.contentView.frame.origin.y;
        self.allButton.frame = CGRectMake(kAllButtonWideAnchorX - baseX - contentX,
                                          kAllButtonWideAnchorY - baseY - contentY,
                                          allSize.width,
                                          allSize.height);
    } else {
        CGFloat contentWidth = self.contentView.bounds.size.width;
        self.allButton.center =
            CGPointMake(contentWidth + kAllButtonTallCenterXInset, kTabButtonTallCenterY);
        if (_thema != RBUserSettingDataThemeClassic) {
            self.allButton.frame = CGRectMake(
                kAllButtonTallThemedX, kTabButtonTallThemedY, allSize.width, allSize.height);
        }
    }
    self.allButton.exclusiveTouch = YES;
    self.allButton.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.allButton addTarget:self
                       action:@selector(SelectAllButton)
             forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.allButton];

    self.allButtonEffect =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kAllButtonSelectedImageName]];
    self.allButtonEffect.center = CGPointMake(self.allButton.bounds.size.width * kHalf,
                                              self.allButton.bounds.size.height * kHalf);
    self.allButtonEffect.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.allButtonEffect SetFlashEffectFast];
    [self.allButton addSubview:self.allButtonEffect];

    [self showFriend:NO];
}

#pragma mark - Actions

- (void)showFriend:(BOOL)showFriend {
    self.friendRanking.hidden = !showFriend;
    self.totalRanking.hidden = showFriend;
    self.friendButton.enabled = !showFriend;
    self.allButton.enabled = showFriend;
    self.friendButtonEffect.hidden = !showFriend;
    self.allButtonEffect.hidden = showFriend;
}

- (void)SelectFriendButton {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectCancel);
    [self showFriend:YES];
}

- (void)SelectAllButton {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectCancel);
    [self showFriend:NO];
}

@end
