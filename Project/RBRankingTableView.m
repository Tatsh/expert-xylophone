//
//  RBRankingTableView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBRankingTableView). Verified
//  against the arm64 disassembly: -initWithFrame:style: geometry, the per-theme row and stroke
//  colours, and the soft-float register moves were recovered from the disassembly where the
//  decompiler folds doubles into pseudo-variables. This class uses only Objective-C and Game
//  Center, so it is a plain Objective-C (.m) file.
//

#import "RBRankingTableView.h"

#import <GameKit/GameKit.h>
#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "RBRankingTableCell.h"
#import "RBUserSettingData.h"
#import "UIAlertView+RB.h"

// The reuse identifier shared by every ranking row cell.
static NSString *const kRankingCellIdentifier = @"RANKING_TABLE";

// The rank column format: a single signed value.
static NSString *const kRankFormat = @"%zd";

// The upper bound on the number of score rows a single page load may request.
static const NSUInteger kMaxLoadCount = 100;

// The number of extra rows to request beyond the current page when the user asks for more.
static const NSUInteger kLoadNextIncrement = 20;

// Only one section is ever shown.
static const NSInteger kRankingSectionCount = 1;

// Row height (points): the iPad board uses the wide slider height, the phone board a shorter row.
static const CGFloat kRowHeightPad = 40.0;
static const CGFloat kRowHeightPhone = 30.0;
// The fixed row height reported to the table view for every row.
static const CGFloat kRowHeightMetric = 32.0;

// The footer that hosts the "show more" button is a fixed-height strip spanning the table width.
static const CGFloat kFooterHeight = 50.0;
// The message label is inset from the table width by this amount and is a fixed height.
static const CGFloat kMessageLabelWidthInset = -40.0;
static const CGFloat kMessageLabelHeight = 30.0;
static const CGFloat kHalf = 0.5;

// The "show more" button appearance.
static const CGFloat kLoadNextTitleFontSize = 16.0;
static const CGFloat kLoadNextCenterY = 20.0;
static const CGFloat kLoadNextShadowAlpha = 0.3;
static const UIEdgeInsets kLoadNextContentInsets = {5.0, 10.0, 5.0, 10.0};
static const CGSize kLoadNextShadowOffset = {0.0, 1.0};

// The scroll indicator is inset from the top and bottom.
static const UIEdgeInsets kScrollIndicatorInsets = {4.0, 0.0, 4.0, 0.0};

// The message label font size.
static const CGFloat kMessageLabelFontSize = 17.0;

// The current-player highlight and alternating-row background colours are stored in the binary as
// precomputed 8-bit-channel values divided by 255. They are grouped by theme.
static const CGFloat kColorScale = 255.0;

// The Classic theme uses a single grey stroke colour.
static const CGFloat kClassicStrokeGrey = 129.0 / kColorScale;

// The Limelight and Colette themes: alternating light rows, and a warm current-player highlight.
static const CGFloat kThemedAltRowWhite = 232.0 / kColorScale;
static const CGFloat kThemedHighlightRedBlue = 192.0 / kColorScale;
static const CGFloat kThemedHighlightGreen = 126.0 / kColorScale;

// The Classic theme: alternating dark rows, and a cool current-player highlight.
static const CGFloat kClassicAltRowWhite = 27.0 / kColorScale;
static const CGFloat kClassicHighlightRed = 75.0 / kColorScale;
static const CGFloat kClassicHighlightGreen = 13.0 / kColorScale;
static const CGFloat kClassicHighlightBlue = 79.0 / kColorScale;

// The following localized-string globals are cached at startup by the shared localization loader
// and defined in that translation unit; they are read here by address.

// 0x3cfbe8, localization key "Failed to connect GameCenter."
extern NSString *g_localizedGameCenterConnectFailed;
// 0x3cfbf0, localization key "No Leaderboard data".
extern NSString *g_localizedNoLeaderboardData;
// 0x3cfca8, localization key "Loading...".
extern NSString *g_localizedLoading;
// 0x3cfcb0, localization key "LOADING...".
extern NSString *g_localizedLoadingUpper;
// 0x3cfd78, localization key "_", the "show more" arrow glyph.
extern NSString *g_localizedShowMoreArrow;

@implementation RBRankingTableView {
    // Non-property backing ivars.
    // Whether the board is being shown on an iPad, selecting the wider row height.
    BOOL m_IsPad;
    // The theme captured at build time, selecting the row and highlight colours.
    RBUserSettingDataTheme _thema;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
    self = [super initWithFrame:frame style:style];
    if (self) {
        self.localPlayerScore = nil; // Yes, the binary clears this before the theme is read.

        _thema = [RBUserSettingData sharedInstance].thema;
        if (_thema == RBUserSettingDataThemeClassic) {
            self.strokeColor = [UIColor whiteColor];
        } else if (_thema == RBUserSettingDataThemeLimelight) {
            self.strokeColor = [UIColor colorWithRed:kClassicStrokeGrey
                                               green:kClassicStrokeGrey
                                                blue:kClassicStrokeGrey
                                               alpha:1.0];
        } else if (_thema == RBUserSettingDataThemeColette) {
            self.strokeColor = [UIColor colorWithRed:kClassicStrokeGrey
                                               green:kClassicStrokeGrey
                                                blue:kClassicStrokeGrey
                                               alpha:1.0];
        }

        self.backgroundColor = [UIColor clearColor];
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.allowsSelection = NO;
        self.scrollIndicatorInsets = kScrollIndicatorInsets;
        self.rowHeight = m_IsPad ? kRowHeightPad : kRowHeightPhone;
        self.delegate = self;
        self.dataSource = self;

        // The footer strip that carries the "show more" button.
        self.footer =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, kFooterHeight)];
        self.footer.opaque = NO;
        self.footer.backgroundColor = [UIColor clearColor];
        self.footer.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

        // The "show more" button.
        self.buttonLoadNext = [UIButton buttonWithType:UIButtonTypeCustom];
        self.buttonLoadNext.backgroundColor = [UIColor clearColor];
        self.buttonLoadNext.contentEdgeInsets = kLoadNextContentInsets;
        self.buttonLoadNext.titleLabel.shadowOffset = kLoadNextShadowOffset;
        [self.buttonLoadNext setTitleColor:self.strokeColor forState:UIControlStateNormal];
        [self.buttonLoadNext setTitleShadowColor:[UIColor colorWithWhite:1.0
                                                                   alpha:kLoadNextShadowAlpha]
                                        forState:UIControlStateNormal];
        [self.buttonLoadNext setTitleColor:self.strokeColor forState:UIControlStateHighlighted];
        [self.buttonLoadNext setTitleColor:self.strokeColor forState:UIControlStateSelected];
        [self.buttonLoadNext setTitle:g_localizedShowMoreArrow forState:UIControlStateNormal];
        [self.buttonLoadNext setTitle:g_localizedLoadingUpper forState:UIControlStateSelected];
        self.buttonLoadNext.titleLabel.font = [UIFont boldSystemFontOfSize:kLoadNextTitleFontSize];
        [self.buttonLoadNext addTarget:self
                                action:@selector(pushLoadNext:)
                      forControlEvents:UIControlEventTouchUpInside];
        [self.buttonLoadNext sizeToFit];
        self.buttonLoadNext.center =
            CGPointMake((int)(self.frame.size.width * kHalf), kLoadNextCenterY);
        self.buttonLoadNext.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self.footer addSubview:self.buttonLoadNext];
        self.tableFooterView = self.footer;

        // The status message label, centred in the table.
        self.msgLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(0,
                                     0,
                                     self.frame.size.width + kMessageLabelWidthInset,
                                     kMessageLabelHeight)];
        self.msgLabel.center =
            CGPointMake((int)(self.frame.size.width * kHalf), (int)(kMessageLabelHeight * kHalf));
        self.msgLabel.backgroundColor = [UIColor clearColor];
        self.msgLabel.font = [UIFont systemFontOfSize:kMessageLabelFontSize];
        if (_thema == RBUserSettingDataThemeClassic) {
            self.msgLabel.textColor = [UIColor whiteColor];
        } else if (_thema == RBUserSettingDataThemeLimelight) {
            self.msgLabel.textColor = [UIColor grayColor];
        } else if (_thema == RBUserSettingDataThemeColette) {
            self.msgLabel.textColor = [UIColor grayColor];
        }
        self.msgLabel.textAlignment = NSTextAlignmentCenter;
        self.msgLabel.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:self.msgLabel];
    }
    return self;
}

- (void)dealloc {
    // The base table view's teardown runs through super.
}

#pragma mark - Loading

- (NSUInteger)numEntries {
    NSUInteger count = self.arrayScore.count;
    if (count == 0) {
        return 0;
    }
    if (self.localPlayerScore == nil) {
        return count;
    }
    // Reserve one extra row for the local player when their rank falls beyond the loaded page.
    return count + (count < self.localPlayerScore.rank ? 1 : 0);
}

- (void)loadRanking {
    if (self.arrayScore != nil) {
        return;
    }
    self.msgLabel.hidden = NO;
    self.msgLabel.text = g_localizedLoading;
    self.buttonLoadNext.hidden = YES;
    if (self.playerScope == GKLeaderboardPlayerScopeFriendsOnly) {
        RBRankingTableView *scoreView = self;
        [[GKLocalPlayer localPlayer]
            loadFriendsWithCompletionHandler:^(NSArray *friendIDs, NSError *error) {
              /** @ghidraAddress 0xdc3a8 */
              [scoreView handleFriendsLoaded:friendIDs error:error];
            }];
    } else {
        self.arrayScore = [[NSMutableArray alloc] init];
        [self load:1];
    }
}

// The friend-list load completion handler.
// @ghidraAddress 0xdc3a8 (HandleLeaderboardLoadCompletionBlockInvoke)
- (void)handleFriendsLoaded:(NSArray *)friendIDs error:(nullable NSError *)error {
    if (error == nil) {
        self.arrayScore = nil;
        self.arrayScore = [[NSMutableArray alloc] init];
        [self load:friendIDs.count + 1];
    } else {
        self.msgLabel.text = g_localizedGameCenterConnectFailed;
    }
}

- (void)load:(NSUInteger)count {
    GKLeaderboard *leaderboard = [[GKLeaderboard alloc] init];
    leaderboard.identifier = [AppDelegate totalScoreLeaderboardCategory];
    leaderboard.playerScope = self.playerScope;
    leaderboard.timeScope = GKLeaderboardTimeScopeAllTime;
    if (count > kMaxLoadCount - 1) {
        count = kMaxLoadCount;
    }
    leaderboard.range = NSMakeRange(self.arrayScore.count + 1, count);

    RBRankingTableView *scoreView = self;
    GKLeaderboard *source = leaderboard;
    [leaderboard loadScoresWithCompletionHandler:^(NSArray<GKScore *> *scores, NSError *error) {
      /** @ghidraAddress 0xdb7ec */
      [scoreView handleScoresLoaded:scores source:source error:error];
    }];
}

// The score-page load completion handler: on success, capture the local player's score, gather the
// player identifiers, and kick off the player-name load; on error, re-enable the button and show an
// error message.
// @ghidraAddress 0xdb7ec (HandleScoreLoadCompletionBlockInvoke)
- (void)handleScoresLoaded:(NSArray<GKScore *> *)scores
                    source:(GKLeaderboard *)source
                     error:(nullable NSError *)error {
    if (error == nil) {
        self.localPlayerScore = source.localPlayerScore;
        NSMutableArray<NSString *> *playerIDs = [NSMutableArray array];
        for (GKScore *score in scores) {
            [playerIDs addObject:score.playerID];
        }
        RBRankingTableView *scoreView = self;
        [GKPlayer loadPlayersForIdentifiers:playerIDs
                      withCompletionHandler:^(NSArray<GKPlayer *> *players, NSError *innerError) {
                        /** @ghidraAddress 0xdbb84 */
                        [scoreView handlePlayersLoaded:players
                                                scores:scores
                                                source:source
                                                 error:innerError];
                      }];
    } else {
        self.buttonLoadNext.enabled = YES;
        if (self.arrayScore.count == 0) {
            self.arrayScore = nil;
        }
        [self errorMsg];
    }
}

// The player-name load completion handler: append the loaded scores and player names, update the
// "show more" button visibility, reload, and toggle the no-data message.
// @ghidraAddress 0xdbb84 (HandleLoadPlayersCompletionBlockInvoke)
- (void)handlePlayersLoaded:(NSArray<GKPlayer *> *)players
                     scores:(NSArray<GKScore *> *)scores
                     source:(GKLeaderboard *)source
                      error:(nullable NSError *)error {
    self.buttonLoadNext.enabled = YES;
    if (error == nil) {
        [self.arrayScore addObjectsFromArray:scores];
        for (GKPlayer *player in players) {
            if (self.arrayName == nil) {
                self.arrayName = [[NSMutableArray alloc] init];
            }
            if (player.alias == nil) {
                [self.arrayName addObject:@""];
            } else {
                [self.arrayName addObject:player.alias];
            }
        }
        self.buttonLoadNext.hidden = source.maxRange <= self.arrayScore.count;
        [self reloadData];
        if (self.arrayScore.count == 0) {
            self.msgLabel.hidden = NO;
            self.msgLabel.text = g_localizedNoLeaderboardData;
        } else {
            self.msgLabel.hidden = YES;
        }
    } else {
        if (self.arrayScore.count == 0) {
            self.arrayScore = nil;
        }
        [self errorMsg];
    }
}

- (void)clear {
    [self reloadData];
}

- (void)errorMsg {
    if (!self.msgLabel.isHidden) {
        self.msgLabel.text = g_localizedGameCenterConnectFailed;
    } else {
        [UIAlertView showGameCenterError];
    }
}

#pragma mark - Actions

- (void)pushLoadNext:(id)sender {
    self.buttonLoadNext.enabled = NO;
    [self load:kLoadNextIncrement];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kRankingSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.numEntries;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RBRankingTableCell *cell = [tableView dequeueReusableCellWithIdentifier:kRankingCellIdentifier];
    if (cell == nil) {
        cell = [[RBRankingTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:kRankingCellIdentifier];
        cell.strokeColor = self.strokeColor;
    }

    GKScore *score;
    NSString *name;
    if (indexPath.row == self.arrayScore.count) {
        // The final synthetic row shows the local player's own out-of-page score.
        score = self.localPlayerScore;
        name = [GKLocalPlayer localPlayer].alias;
    } else {
        score = self.arrayScore[indexPath.row];
        name = self.arrayName[indexPath.row];
    }

    cell.labelRank.text = [NSString stringWithFormat:kRankFormat, score.rank];
    cell.labelName.text = name;
    cell.labelScore.text = score.formattedValue;

    NSUInteger row = indexPath.row;
    NSUInteger entries = self.numEntries;
    UIColor *fillColor = nil;
    if (_thema == RBUserSettingDataThemeClassic) {
        BOOL isLocalPlayer = [score.playerID isEqualToString:self.localPlayerScore.playerID];
        if (isLocalPlayer) {
            fillColor = [UIColor colorWithRed:kClassicHighlightRed
                                        green:kClassicHighlightGreen
                                         blue:kClassicHighlightBlue
                                        alpha:1.0];
        } else {
            CGFloat white = (indexPath.row & 1) ? kClassicAltRowWhite : 0.0;
            fillColor = [UIColor colorWithWhite:white alpha:1.0];
        }
    } else if (_thema == RBUserSettingDataThemeLimelight) {
        BOOL isLocalPlayer = [score.playerID isEqualToString:self.localPlayerScore.playerID];
        if (isLocalPlayer) {
            fillColor = [UIColor colorWithRed:kThemedHighlightRedBlue
                                        green:kThemedHighlightGreen
                                         blue:kThemedHighlightRedBlue
                                        alpha:1.0];
        } else {
            CGFloat white = (indexPath.row & 1) ? 1.0 : kThemedAltRowWhite;
            fillColor = [UIColor colorWithWhite:white alpha:1.0];
        }
    } else if (_thema == RBUserSettingDataThemeColette) {
        BOOL isLocalPlayer = [score.playerID isEqualToString:self.localPlayerScore.playerID];
        if (isLocalPlayer) {
            fillColor = [UIColor colorWithRed:kThemedHighlightRedBlue
                                        green:kThemedHighlightGreen
                                         blue:kThemedHighlightRedBlue
                                        alpha:1.0];
        } else {
            CGFloat white = (indexPath.row & 1) ? 1.0 : kThemedAltRowWhite;
            fillColor = [UIColor colorWithWhite:white alpha:1.0];
        }
    }

    // Only reassign isTop/isLast when the value actually changes, to avoid a needless redraw.
    BOOL isTop = (row == 0);
    BOOL topUnchanged = (isTop == cell.isTop);
    if (!topUnchanged) {
        cell.isTop = isTop;
    }
    BOOL isLast = (row == entries - 1);
    BOOL lastUnchanged = (isLast == cell.isLast);
    if (!lastUnchanged) {
        cell.isLast = isLast;
    }

    if (!CGColorEqualToColor(cell.fillColor.CGColor, fillColor.CGColor)) {
        cell.fillColor = fillColor;
    } else if (lastUnchanged && topUnchanged) {
        // Nothing changed; skip the redraw.
        return cell;
    }
    [cell setNeedsDisplay];
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kRowHeightMetric;
}

- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = [UIColor clearColor];
}

@end
