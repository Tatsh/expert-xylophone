#import "RBPlaylistViewController.h"

#import "MusicData.h"
#import "RBMusicManager.h"
#import "RBPlaylistManager.h"
#import "RBUserSettingData.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The playlist filter identifiers persisted in RBUserSettingData.playlistID.
enum {
    RBPlaylistIDAll = 0,      // The "all songs" filter.
    RBPlaylistIDNew = 1,      // The "new songs" filter.
    RBPlaylistIDLevel = 2,    // A per-level filter (playlistLevel selects the level).
    RBPlaylistIDPlaylist = 3, // A saved playlist (playlistLevel selects the playlist index).
    RBPlaylistIDAppend = 4,   // The "append" (special) filter.
};

// The unfiltered-level sentinel stored in RBUserSettingData.playlistLevel.
static const int kPlaylistLevelNone = -1;

// The playlistType modes.
enum {
    RBPlaylistTypeMenu = 0, // The playlist menu / level node.
    RBPlaylistTypeAdd = 1,  // The add-to-playlist picker.
};

// The playlistNode modes.
enum {
    RBPlaylistNodeRoot = 0,  // The top-level playlist menu.
    RBPlaylistNodeLevel = 1, // The level-select node.
};

// Table sections.
enum {
    kSectionMenu = 0,      // The menu rows (or level rows).
    kSectionPlaylists = 1, // The user's saved playlists.
};

// Menu row indices in the root menu's section zero.
enum {
    kMenuRowAll = 0,
    kMenuRowNew = 1,
    kMenuRowLevel = 2,
    kMenuRowAppend = 3,
};

// The number of difficulty levels tracked in the level node (Level1..Level15).
static const int kNumDifficultyLevels = 15;

// The sort-segment order matches RBUserSettingData.menuItemSort.
enum {
    kMenuItemSortMusic = 0,  // Sort by music (segment index zero).
    kMenuItemSortArtist = 1, // Sort by artist (segment index one).
};

// The row-descriptor dictionary keys.
static NSString *const kRowKeyTitle = @"title";
static NSString *const kRowKeyText = @"text";
static NSString *const kMusicNameKey = @"NAME";

// The reusable list-cell identifier.
static NSString *const kCellReuseID = @"cell";

// The row-title formats and header formats.
static NSString *const kSongsCountFormat = @"%d songs";
static NSString *const kHeaderMusicFormat = @"%@ - MUSIC -";   // @ghidraAddress cf____MUSIC_
static NSString *const kHeaderArtistFormat = @"%@ - ARTIST -"; // @ghidraAddress cf____ARTIST_

// The sort segment titles (untranslated literals).
static NSString *const kHeaderMusicSegmentTitle = @"MUSIC";   // @ghidraAddress cf_MUSIC
static NSString *const kHeaderArtistSegmentTitle = @"ARTIST"; // @ghidraAddress cf_ARTIST

// On the pad, when the view is taller than this the frame is clamped back to it in
// -viewWillAppear:.
static const CGFloat kPadFullHeightThreshold = 528.0; // @ghidraAddress 0x2fee00

// The row accessory / icon image asset names.
static NSString *const kIconAllImageName = @"01_music_select/sel_playlist_icon_all";
static NSString *const kIconNewImageName = @"01_music_select/sel_playlist_icon_new";
static NSString *const kIconLevelImageName = @"01_music_select/sel_playlist_icon_level";
static NSString *const kIconAppendImageName = @"01_music_select/sel_playlist_icon_append";
static NSString *const kCheckImageName = @"01_music_select/sel_playlist_check";

// Header title label point sizes.
static const CGFloat kTitleFontSizePhone = 16.0;
static const CGFloat kTitleFontSizePad = 18.0;

// The music/artist sort-segment layout: the label height is fourteen points and the control spans
// the phone mascot-message width.
static const CGFloat kSortSegmentHeight = 30.0;
static const CGFloat kSortLabelFontSize = 14.0;

// The system version at which the navigation bar switched from tintColor to barTintColor.
static const CGFloat kBarTintColorMinSystemVersion = 7.0;

@interface RBPlaylistViewController () {
    // Per-difficulty-level song counts (Level1..Level15), rebuilt by -reloadData in the level node.
    int songCounts[kNumDifficultyLevels];
}
@end

@implementation RBPlaylistViewController

#pragma mark - Lifecycle

/** @ghidraAddress 0x90f18 */
- (void)viewDidLoad {
    [super viewDidLoad];

    [self.navigationController setNavigationBarHidden:NO];
    [self.navigationController setToolbarHidden:NO];

    RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    if (theme == RBUserSettingDataThemeClassic) {
        self.titleColor = g_pPaletteWhiteColor;
        self.buttonColor = g_pPaletteOpaqueBlackColor;
        self.musicColor = g_pPaletteGreenGrassColor;
        self.artistColor = g_pPaletteMagentaColor;
        self.selectedRowColor = g_pPalettePurpleColor;
        if ([UIDevice currentDevice].systemVersion.floatValue >= kBarTintColorMinSystemVersion) {
            self.navigationController.navigationBar.barTintColor = UIColor.blackColor;
            self.navigationController.toolbar.barTintColor = UIColor.blackColor;
        } else {
            self.navigationController.navigationBar.tintColor = UIColor.blackColor;
            self.navigationController.toolbar.tintColor = UIColor.blackColor;
        }
    } else if (theme == RBUserSettingDataThemeLimelight) {
        self.titleColor = g_pPaletteDarkGreenColor;
        self.buttonColor = g_pPaletteLeafGreenColor;
        self.musicColor = g_pPaletteGreenGrassColor2;
        self.artistColor = g_pPaletteMagentaColor2;
        self.selectedRowColor = g_pPaletteLeafGreenColor2;
        if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
            self.navigationController.navigationBar.tintColor = UIColor.whiteColor;
            self.navigationController.toolbar.tintColor = UIColor.whiteColor;
        }
    } else if (theme == RBUserSettingDataThemeColette) {
        self.titleColor = g_pPaletteSteelBlueColor;
        self.buttonColor = g_pPaletteLeafGreenColor3;
        self.musicColor = g_pPaletteSteelBlueColor2;
        self.artistColor = g_pPaletteGoldColor;
        self.selectedRowColor = g_pPaletteSteelBlueColor3;
        if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
            self.navigationController.navigationBar.tintColor = UIColor.whiteColor;
            self.navigationController.toolbar.tintColor = UIColor.whiteColor;
        }
    }

    int sortIndex = [RBUserSettingData sharedInstance].menuItemSort;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.textColor = self.titleColor;
    CGFloat titleFontSize = IsPad() ? kTitleFontSizePad : kTitleFontSizePhone;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:titleFontSize];
    self.titleLabel.backgroundColor = UIColor.clearColor;
    self.navigationItem.titleView = self.titleLabel;

    self.segmentedControl =
        [[UISegmentedControl alloc] initWithItems:@[ kHeaderMusicSegmentTitle,
                                                     kHeaderArtistSegmentTitle ]];
    self.segmentedControl.frame =
        CGRectMake(0.0, 0.0, g_dMascotMessageMaxWidthPhone, kSortSegmentHeight);
    self.segmentedControl.selectedSegmentIndex = sortIndex;
    [self.segmentedControl addTarget:self
                              action:@selector(valueChanged:)
                    forControlEvents:UIControlEventValueChanged];

    UILabel *sortLabel = [[UILabel alloc] init];
    sortLabel.backgroundColor = UIColor.clearColor;
    sortLabel.textColor = self.titleColor;
    sortLabel.font = [UIFont boldSystemFontOfSize:kSortLabelFontSize];
    sortLabel.text = g_pLocalizedSort;
    [sortLabel sizeToFit];

    UIBarButtonItem *sortLabelItem = [[UIBarButtonItem alloc] initWithCustomView:sortLabel];
    UIBarButtonItem *segmentItem =
        [[UIBarButtonItem alloc] initWithCustomView:self.segmentedControl];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                             target:nil
                             action:nil];
    self.toolbarItems = @[ flexSpace, sortLabelItem, segmentItem, flexSpace ];

    if (self.playlistNode == RBPlaylistNodeRoot) {
        if (self.playlistType == RBPlaylistTypeMenu) {
            [self setTitle:g_pLocalizedPlaylist];
        } else if (self.playlistType == RBPlaylistTypeAdd) {
            [self setTitle:g_pLocalizedAddToPlaylist];
        }
        if (!IsPad()) {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                initWithTitle:g_pLocalizedClose
                        style:UIBarButtonItemStyleDone
                       target:self
                       action:@selector(closeButtonPush:)];
            if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
                self.navigationItem.leftBarButtonItem.tintColor = self.buttonColor;
            }
        }
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:g_pLocalizedNew
                                             style:UIBarButtonItemStyleDone
                                            target:self
                                            action:@selector(addButtonPush:)];
        if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
            self.navigationItem.rightBarButtonItem.tintColor = self.buttonColor;
        }
    } else if (self.playlistNode == RBPlaylistNodeLevel) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithTitle:g_pLocalizedReturn
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(returnButtonPush:)];
        if ([UIDevice currentDevice].systemVersion.floatValue < kBarTintColorMinSystemVersion) {
            self.navigationItem.leftBarButtonItem.tintColor = self.buttonColor;
        }
        [self setTitle:g_pLocalizedLevel];
    } else {
        self.menuItems = nil;
    }
}

/** @ghidraAddress 0x92398 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Tint each sort segment: the selected segment gets the current sort's colour and the other
    // gets the opposite colour, so the music/artist labels always read in their own hue. The
    // segment subviews are messaged through their private -isSelected / -setTintColor: selectors,
    // matching the binary.
    NSInteger selected = self.segmentedControl.selectedSegmentIndex;
    for (id segment in self.segmentedControl.subviews) {
        BOOL isSelected = [segment isSelected];
        if (!isSelected) {
            [segment setTintColor:(selected == kMenuItemSortMusic ? self.artistColor
                                                                  : self.musicColor)];
        } else {
            [segment setTintColor:(selected == kMenuItemSortMusic ? self.musicColor
                                                                  : self.artistColor)];
        }
    }

    if (IsPad() && self.view.bounds.size.height > kPadFullHeightThreshold) {
        self.view.frame = CGRectMake(self.view.frame.origin.x,
                                     self.view.frame.origin.y,
                                     self.view.frame.size.width,
                                     kPadFullHeightThreshold);
    }

    [self reloadData];
}

#pragma mark - Title

/** @ghidraAddress 0x90c64 */
- (void)setTitle:(NSString *)title {
    [super setTitle:title];

    if (self.segmentedControl.selectedSegmentIndex == kMenuItemSortMusic) {
        self.titleLabel.text = [NSString stringWithFormat:kHeaderMusicFormat, title];
        self.titleLabel.textColor = self.musicColor;
    } else {
        self.titleLabel.text = [NSString stringWithFormat:kHeaderArtistFormat, title];
        self.titleLabel.textColor = self.artistColor;
    }
    [self.titleLabel sizeToFit];
}

#pragma mark - Sort segment

/** @ghidraAddress 0x927ec */
- (void)valueChanged:(id)sender {
    NSInteger index = ((UISegmentedControl *)sender).selectedSegmentIndex;
    [RBUserSettingData sharedInstance].menuItemSort = (int)index;
    if ([self.delegate respondsToSelector:@selector(didSelectMenuSortViewController:)]) {
        [self.delegate didSelectMenuSortViewController:self];
    }
    [self setTitle:self.title];
}

#pragma mark - Navigation-bar buttons

/** @ghidraAddress 0x93a7c */
- (void)returnButtonPush:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

/** @ghidraAddress 0x93ae8 */
- (void)closeButtonPush:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
      /** @ghidraAddress 0x10035bd10 */
      // The completion is the shared empty global block; nothing to do.
    }];
}

/** @ghidraAddress 0x93bd8 */
- (void)addButtonPush:(id)sender {
    UIViewController *createCtrl =
        [[NSClassFromString(@"RBPlaylistCreateViewController") alloc] init];
    createCtrl.view.frame = self.view.frame;
    [self.navigationController pushViewController:createCtrl animated:YES];
}

#pragma mark - Data

/** @ghidraAddress 0x92944 */
- (void)reloadData {
    if (self.playlistNode == RBPlaylistNodeRoot) {
        if (self.playlistType == RBPlaylistTypeMenu) {
            self.menuItems = [NSMutableArray arrayWithObjects:
                @{kRowKeyTitle : g_pLocalizedAll},
                @{kRowKeyTitle : g_pLocalizedNoPlaySongs},
                @{kRowKeyTitle : g_pLocalizedLevel},
                @{kRowKeyTitle : g_pLocalizedSpecial},
                nil];
        } else {
            self.menuItems = nil;
        }
        self.playlistFiles = [RBPlaylistManager sharedInstance].arrayPlaylist;
    } else if (self.playlistNode == RBPlaylistNodeLevel) {
        // Tally, per difficulty level, how many songs have a chart at that level. A chart counts
        // once for basic, again for medium/hard/special only when they differ from the already
        // counted levels.
        for (int i = 0; i < kNumDifficultyLevels; ++i) {
            songCounts[i] = 0;
        }
        NSMutableArray<MusicData *> *musics =
            [NSMutableArray arrayWithArray:[[RBMusicManager getInstance] getMusicDataArray]];
        for (MusicData *music in musics) {
            ++songCounts[music.difficultyBasic];
            if (music.difficultyBasic != music.difficultyMedium) {
                ++songCounts[music.difficultyMedium];
            }
            if (music.difficultyBasic != music.difficultyHard ||
                music.difficultyMedium != music.difficultyHard) {
                ++songCounts[music.difficultyHard];
            }
            if (music.spData != nil) {
                if (music.difficultyBasic != music.difficultySpecial ||
                    music.difficultyMedium != music.difficultySpecial ||
                    music.difficultyHard != music.difficultySpecial) {
                    ++songCounts[music.difficultySpecial];
                }
            }
        }

        NSString *const levelTitles[] = {
            g_pLocalizedLevel1, g_pLocalizedLevel2, g_pLocalizedLevel3, g_pLocalizedLevel4,
            g_pLocalizedLevel5, g_pLocalizedLevel6, g_pLocalizedLevel7, g_pLocalizedLevel8,
            g_pLocalizedLevel9, g_pLocalizedLevel10, g_pLocalizedLevel11, g_pLocalizedLevel12,
            g_pLocalizedLevel13, g_pLocalizedLevel14, g_pLocalizedLevel15};
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:kNumDifficultyLevels];
        for (int level = 0; level < kNumDifficultyLevels; ++level) {
            NSString *countText =
                [NSString stringWithFormat:kSongsCountFormat, songCounts[level]];
            [items addObject:@{kRowKeyTitle : levelTitles[level], kRowKeyText : countText}];
        }
        self.menuItems = items;
    } else {
        self.menuItems = nil;
    }

    [self.tableView reloadData];
}

#pragma mark - Table view data source

/** @ghidraAddress 0x93d00 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.playlistType == RBPlaylistTypeMenu && self.playlistNode == RBPlaylistNodeRoot) {
        return 2;
    }
    if (self.playlistType == RBPlaylistTypeMenu) {
        return 1;
    }
    return 2;
}

/** @ghidraAddress 0x93d50 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.playlistNode == RBPlaylistNodeRoot) {
        if (section == kSectionPlaylists) {
            return self.playlistFiles.count;
        }
        if (section == kSectionMenu) {
            return self.menuItems.count;
        }
        return 1;
    }

    // Level node: the visible row count is the highest populated level (down to level eleven),
    // plus one. The binary scans from the last level downwards.
    int level = kNumDifficultyLevels - 1;
    while (level > 10 && songCounts[level] <= 0) {
        --level;
    }
    return level + 1;
}

/** @ghidraAddress 0x93e54 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:kCellReuseID];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    cell.textLabel.textColor = UIColor.blackColor;
    cell.accessoryView = nil;

    if (self.playlistType == RBPlaylistTypeMenu) {
        if (self.playlistNode == RBPlaylistNodeRoot) {
            int playlistID = [RBUserSettingData sharedInstance].playlistID;
            if (playlistID < RBPlaylistIDPlaylist) {
                if ((NSInteger)[RBUserSettingData sharedInstance].playlistID == indexPath.row &&
                    indexPath.section == kSectionMenu) {
                    cell.accessoryView = [[UIImageView alloc]
                        initWithImage:[UIImage imageWithName:kCheckImageName]];
                    cell.textLabel.textColor = self.selectedRowColor;
                }
            } else if (playlistID == RBPlaylistIDPlaylist) {
                if ([RBUserSettingData sharedInstance].playlistID == RBPlaylistIDPlaylist &&
                    indexPath.section == kSectionPlaylists &&
                    (NSInteger)[RBUserSettingData sharedInstance].playlistLevel == indexPath.row) {
                    cell.accessoryView = [[UIImageView alloc]
                        initWithImage:[UIImage imageWithName:kCheckImageName]];
                    cell.textLabel.textColor = self.selectedRowColor;
                }
            } else if (playlistID == RBPlaylistIDAppend && indexPath.row == kMenuRowAppend &&
                       indexPath.section == kSectionMenu) {
                cell.accessoryView = [[UIImageView alloc]
                    initWithImage:[UIImage imageWithName:kCheckImageName]];
                cell.textLabel.textColor = self.selectedRowColor;
            }
        } else if (self.playlistNode == RBPlaylistNodeLevel) {
            if ([RBUserSettingData sharedInstance].playlistID == RBPlaylistIDLevel &&
                (NSInteger)[RBUserSettingData sharedInstance].playlistLevel == indexPath.row) {
                cell.textLabel.textColor = self.selectedRowColor;
                cell.detailTextLabel.textColor = self.selectedRowColor;
            }
        }
    }

    if (indexPath.section == kSectionPlaylists) {
        NSDictionary *playlist = self.playlistFiles[indexPath.row];
        cell.textLabel.text = playlist[kMusicNameKey];
        cell.imageView.image = nil;
    } else if (indexPath.section == kSectionMenu) {
        if (self.playlistNode == RBPlaylistNodeRoot) {
            NSDictionary *item = self.menuItems[indexPath.row];
            cell.textLabel.text = item[kRowKeyTitle];
            cell.detailTextLabel.text = item[kRowKeyText];
            switch (indexPath.row) {
                case kMenuRowAll:
                    cell.imageView.image = [UIImage imageWithName:kIconAllImageName];
                    break;
                case kMenuRowNew:
                    cell.imageView.image = [UIImage imageWithName:kIconNewImageName];
                    break;
                case kMenuRowLevel:
                    cell.imageView.image = [UIImage imageWithName:kIconLevelImageName];
                    break;
                case kMenuRowAppend:
                    cell.imageView.image = [UIImage imageWithName:kIconAppendImageName];
                    break;
                default:
                    break;
            }
        } else {
            NSDictionary *item = self.menuItems[indexPath.row];
            cell.textLabel.text = item[kRowKeyTitle];
            cell.detailTextLabel.text = item[kRowKeyText];
        }
    }

    cell.backgroundColor = UIColor.clearColor;
    return cell;
}

/** @ghidraAddress 0x94c3c */
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == kSectionPlaylists;
}

/** @ghidraAddress 0x94d70 */
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == kSectionPlaylists;
}

/** @ghidraAddress 0x94c64 */
- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[RBPlaylistManager sharedInstance] removePlaylistAtIndex:indexPath.row];
        [[RBPlaylistManager sharedInstance] synchronize];
        [self reloadData];
    }
}

/** @ghidraAddress 0x94d98 */
- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
           toIndexPath:(NSIndexPath *)destinationIndexPath {
    // The binary leaves the reorder unimplemented (the move is a no-op).
}

#pragma mark - Table view delegate

/** @ghidraAddress 0x94d9c */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath].selectionStyle ==
        UITableViewCellSelectionStyleNone) {
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.playlistType == RBPlaylistTypeMenu) {
        if (self.playlistNode == RBPlaylistNodeRoot) {
            if (indexPath.section == kSectionPlaylists) {
                [RBUserSettingData sharedInstance].playlistID = RBPlaylistIDPlaylist;
                [RBUserSettingData sharedInstance].playlistLevel = (int)indexPath.row;
            } else if (indexPath.section == kSectionMenu) {
                switch (indexPath.row) {
                    case kMenuRowAll:
                        [RBUserSettingData sharedInstance].playlistID = RBPlaylistIDAll;
                        [RBUserSettingData sharedInstance].playlistLevel = kPlaylistLevelNone;
                        break;
                    case kMenuRowNew:
                        [RBUserSettingData sharedInstance].playlistID = RBPlaylistIDNew;
                        [RBUserSettingData sharedInstance].playlistLevel = kPlaylistLevelNone;
                        break;
                    case kMenuRowLevel: {
                        RBPlaylistViewController *levelCtrl =
                            [[RBPlaylistViewController alloc] init];
                        levelCtrl.delegate = self.delegate;
                        levelCtrl.playlistNode = RBPlaylistNodeLevel;
                        levelCtrl.navigationItem.hidesBackButton = YES;
                        levelCtrl.view.frame = self.view.frame;
                        [self.navigationController pushViewController:levelCtrl animated:YES];
                        return;
                    }
                    case kMenuRowAppend:
                        [RBUserSettingData sharedInstance].playlistID = RBPlaylistIDAppend;
                        [RBUserSettingData sharedInstance].playlistLevel = kPlaylistLevelNone;
                        break;
                    default:
                        break;
                }
            }
        } else if (self.playlistNode == RBPlaylistNodeLevel) {
            [RBUserSettingData sharedInstance].playlistID = RBPlaylistIDLevel;
            [RBUserSettingData sharedInstance].playlistLevel = (int)indexPath.row;
        }
        if ([self.delegate respondsToSelector:@selector(didSelectPlaylistViewController:)]) {
            [self.delegate didSelectPlaylistViewController:self];
        }
    } else if (self.playlistType == RBPlaylistTypeAdd) {
        RBPlaylistManager *manager = [RBPlaylistManager sharedInstance];
        for (NSNumber *musicID in self.musicSet) {
            [manager addMusic:musicID.intValue toPlaylistAtIndex:indexPath.row];
        }
        [manager synchronize];
        [self.musicSet removeAllObjects];
        if ([self.delegate respondsToSelector:@selector(didSelectPlaylistViewController:)]) {
            [self.delegate didSelectPlaylistViewController:self];
        }
    }
}

@end
