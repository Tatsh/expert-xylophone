//
//  RBRankingView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBRankingView). Verified against
//  the arm64 disassembly: -setupView's per-theme table, tab-button, and effect geometry were
//  recovered from the soft-float register moves that the decompiler folds into pseudo-variables.
//  This is an Objective-C++ file because the tab handlers reach the C++ SoundEffectManager engine
//  singleton.
//

#import "RBRankingView.h"

#import "RBRankingTableView.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "neEngineBridge.h"

// The themed sound-effect slot played when a ranking tab is pressed.
constexpr int kSoundEffectCancel = 1;

// The player scope passed to each ranking table view.
constexpr int kPlayerScopeTotal = 0;
constexpr int kPlayerScopeFriend = 1;

// The two ranking boards fill the same frame within the content view. The three layout regimes are
// selected by the iPad idiom flag and, within the wide (iPad) regime, by the theme.

// Wide (iPad idiom) table frame. The origin is anchored to the base panel and content view so
// the board sits at a fixed screen position regardless of the popup's own offset.
constexpr CGFloat kTableWideAnchorX = 134.0;
constexpr CGFloat kTableWideAnchorY = 295.0;
constexpr CGFloat kTableWideWidth = 496.0;
constexpr CGFloat kTableWideHeight = 530.0;

// Tall themed (non-variant, non-classic theme) table frame.
constexpr CGFloat kTableTallThemedX = 10.0;
constexpr CGFloat kTableTallThemedY = 75.0;
constexpr CGFloat kTableTallThemedWidth = 300.0;
constexpr CGFloat kTableTallThemedHeight = 241.0;

// Tall classic (non-variant, classic theme) table frame. The X centres a fixed-width board in the
// content view; the width and the vertical inset are fixed.
constexpr CGFloat kTableTallClassicWidthInset = -300.0;
constexpr CGFloat kTableTallClassicWidth = 300.0;
constexpr CGFloat kTableTallClassicY = 50.0;
constexpr CGFloat kTableTallClassicHeight = 246.0;

constexpr CGFloat kHalf = 0.5;

// The friend tab button positioning.
constexpr CGFloat kFriendButtonWideAnchorX = 179.0; // Anchored X in the wide (iPad).
constexpr CGFloat kFriendButtonWideAnchorY = 235.0; // Anchored Y in the wide (iPad).
constexpr CGFloat kFriendButtonTallCenterX = 71.0;  // Centre X in the tall regime.
constexpr CGFloat kFriendButtonTallThemedX = 18.0;  // Frame X for a tall themed (non-classic).

// The all (total) tab button positioning.
constexpr CGFloat kAllButtonWideAnchorX = 437.0;      // Anchored X in the wide regime.
constexpr CGFloat kAllButtonWideAnchorY = 235.0;      // Anchored Y in the wide regime.
constexpr CGFloat kAllButtonTallCenterXInset = -71.0; // Centre X = contentWidth + this (tall).
constexpr CGFloat kAllButtonTallThemedX = 188.0;      // Frame X for a tall themed (non-classic).

// The shared tab-button vertical placement in the tall regime.
constexpr CGFloat kTabButtonTallCenterY = 33.0; // Centre Y in the tall regime.
constexpr CGFloat kTabButtonTallThemedY = 35.0; // Frame Y for a tall themed (non-classic).

// The tab-button artwork.
static NSString *const kFriendButtonImageName = @"08_ranking/rank_fri";
static NSString *const kFriendButtonSelectedImageName = @"08_ranking/rank_fri_sel";
static NSString *const kAllButtonImageName = @"08_ranking/rank_all";
static NSString *const kAllButtonSelectedImageName = @"08_ranking/rank_all_sel";

@implementation RBRankingView {
    // Whether a show or hide animation is currently running, distinct from the base popup's flag.
    BOOL m_Animating;
    // The theme captured at build time, selecting the table and tab-button geometry.
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

    // Compute the shared frame the two ranking boards occupy inside the content view.
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

    // The friend-scope board.
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

    // The total-scope board occupies the same frame.
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

    // The friend tab button.
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

    // The friend tab's flash overlay, centred on the button.
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

    // The all (total) tab button.
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

    // The all tab's flash overlay, centred on the button.
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
