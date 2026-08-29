#import "RBRankingTableView.h"

#import <GameKit/GameKit.h>
#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "RBRankingTableCell.h"
#import "RBUserSettingData.h"
#import "UIAlertView+RB.h"
#import "engineglobals.h"

static NSString *const kRankingCellIdentifier = @"RANKING_TABLE";

static NSString *const kRankFormat = @"%zd";

static const NSUInteger kMaxLoadCount = 100;

static const NSUInteger kLoadNextIncrement = 20;

static const NSInteger kRankingSectionCount = 1;

static const CGFloat kRowHeightPad = 40.0;
static const CGFloat kRowHeightPhone = 30.0;
static const CGFloat kRowHeightMetric = 32.0;

static const CGFloat kFooterHeight = 50.0;
static const CGFloat kMessageLabelWidthInset = -40.0;
static const CGFloat kMessageLabelHeight = 30.0;
static const CGFloat kHalf = 0.5;

static const CGFloat kLoadNextTitleFontSize = 16.0;
static const CGFloat kLoadNextCenterY = 20.0;
static const CGFloat kLoadNextShadowAlpha = 0.3;
static const UIEdgeInsets kLoadNextContentInsets = {5.0, 10.0, 5.0, 10.0};
static const CGSize kLoadNextShadowOffset = {0.0, 1.0};

static const UIEdgeInsets kScrollIndicatorInsets = {4.0, 0.0, 4.0, 0.0};

static const CGFloat kMessageLabelFontSize = 17.0;

static const CGFloat kColorScale = 255.0;

static const CGFloat kClassicStrokeGray = 129.0 / kColorScale;

static const CGFloat kThemedAltRowWhite = 232.0 / kColorScale;
static const CGFloat kThemedHighlightRedBlue = 192.0 / kColorScale;
static const CGFloat kThemedHighlightGreen = 126.0 / kColorScale;

static const CGFloat kClassicAltRowWhite = 27.0 / kColorScale;
static const CGFloat kClassicHighlightRed = 75.0 / kColorScale;
static const CGFloat kClassicHighlightGreen = 13.0 / kColorScale;
static const CGFloat kClassicHighlightBlue = 79.0 / kColorScale;

@implementation RBRankingTableView {
    BOOL m_IsPad;
    RBUserSettingDataTheme _thema;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
    self = [super initWithFrame:frame style:style];
    if (self) {
        self.localPlayerScore = nil; // Yes, the binary clears this before the theme is read.

        _thema = [RBUserSettingData sharedInstance].thema;
        if (_thema == RBUserSettingDataThemeClassic) {
            self.strokeColor = UIColor.whiteColor;
        } else if (_thema == RBUserSettingDataThemeLimelight) {
            self.strokeColor = [UIColor colorWithRed:kClassicStrokeGray
                                               green:kClassicStrokeGray
                                                blue:kClassicStrokeGray
                                               alpha:1.0];
        } else if (_thema == RBUserSettingDataThemeColette) {
            self.strokeColor = [UIColor colorWithRed:kClassicStrokeGray
                                               green:kClassicStrokeGray
                                                blue:kClassicStrokeGray
                                               alpha:1.0];
        }

        self.backgroundColor = UIColor.clearColor;
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.allowsSelection = NO;
        self.scrollIndicatorInsets = kScrollIndicatorInsets;
        self.rowHeight = m_IsPad ? kRowHeightPad : kRowHeightPhone;
        self.delegate = self;
        self.dataSource = self;

        self.footer =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, kFooterHeight)];
        self.footer.opaque = NO;
        self.footer.backgroundColor = UIColor.clearColor;
        self.footer.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

        self.buttonLoadNext = [UIButton buttonWithType:UIButtonTypeCustom];
        self.buttonLoadNext.backgroundColor = UIColor.clearColor;
        self.buttonLoadNext.contentEdgeInsets = kLoadNextContentInsets;
        self.buttonLoadNext.titleLabel.shadowOffset = kLoadNextShadowOffset;
        [self.buttonLoadNext setTitleColor:self.strokeColor forState:UIControlStateNormal];
        [self.buttonLoadNext setTitleShadowColor:[UIColor colorWithWhite:1.0
                                                                   alpha:kLoadNextShadowAlpha]
                                        forState:UIControlStateNormal];
        [self.buttonLoadNext setTitleColor:self.strokeColor forState:UIControlStateHighlighted];
        [self.buttonLoadNext setTitleColor:self.strokeColor forState:UIControlStateSelected];
        [self.buttonLoadNext setTitle:g_pLocalizedSlash forState:UIControlStateNormal];
        [self.buttonLoadNext setTitle:g_pLocalizedLoadingUpper forState:UIControlStateSelected];
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

        self.msgLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(0,
                                     0,
                                     self.frame.size.width + kMessageLabelWidthInset,
                                     kMessageLabelHeight)];
        self.msgLabel.center =
            CGPointMake((int)(self.frame.size.width * kHalf), (int)(kMessageLabelHeight * kHalf));
        self.msgLabel.backgroundColor = UIColor.clearColor;
        self.msgLabel.font = [UIFont systemFontOfSize:kMessageLabelFontSize];
        if (_thema == RBUserSettingDataThemeClassic) {
            self.msgLabel.textColor = UIColor.whiteColor;
        } else if (_thema == RBUserSettingDataThemeLimelight) {
            self.msgLabel.textColor = UIColor.grayColor;
        } else if (_thema == RBUserSettingDataThemeColette) {
            self.msgLabel.textColor = UIColor.grayColor;
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
    // The binary defines an empty dealloc.
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
    // GKScore's rank is signed, so compare in that domain rather than promoting it.
    return count + ((NSInteger)count < self.localPlayerScore.rank ? 1 : 0);
}

- (void)loadRanking {
    if (self.arrayScore != nil) {
        return;
    }
    self.msgLabel.hidden = NO;
    self.msgLabel.text = g_pLocalizedLoadingMixed;
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

// @ghidraAddress 0xdc3a8 (HandleLeaderboardLoadCompletionBlockInvoke)
- (void)handleFriendsLoaded:(NSArray *)friendIDs error:(nullable NSError *)error {
    if (error == nil) {
        self.arrayScore = nil;
        self.arrayScore = [[NSMutableArray alloc] init];
        [self load:friendIDs.count + 1];
    } else {
        self.msgLabel.text = g_pLocalizedGameCenterConnectFailed;
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
            self.msgLabel.text = g_pLocalizedNoLeaderboardData;
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
        self.msgLabel.text = g_pLocalizedGameCenterConnectFailed;
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
    if (indexPath.row == (NSInteger)self.arrayScore.count) {
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

    // Reassigning isTop/isLast unchanged would force a needless redraw.
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
    cell.backgroundColor = UIColor.clearColor;
}

@end
