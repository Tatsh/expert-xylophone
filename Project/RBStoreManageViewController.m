#import "RBStoreManageViewController.h"

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "MusicDataExtend.h"
#import "NSFileManager+RB.h"
#import "RBCampaignViewController.h"
#import "RBExtendNoteManager.h"
#import "RBManageSortData.h"
#import "RBMusicManager.h"
#import "RBStoreManageCell.h"
#import "RBStoreManageHeaderCell.h"
#import "RBStoreManageSortViewController.h"
#import "RBStoreTabController.h"
#import "StoreDialogView.h"
#import "StoreDownloadManager.h"
#import "StoreDownloadTask.h"
#import "StoreExtendNoteInfo.h"
#import "StoreMusicInfo.h"
#import "StoreUtil.h"
#import "StringConvert.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"

typedef NS_ENUM(NSUInteger, RBStoreManageSortOrder) {
    RBStoreManageSortOrderDownloadAscending = 0,
    RBStoreManageSortOrderDownloadDescending = 1,
    RBStoreManageSortOrderTitle = 2,
    RBStoreManageSortOrderArtist = 3,
};

enum { kSectionCount = 11 };

static const int kAlertButtonConfirm = 1;

static const int kNoWorkingIndex = -1;

// A cell button's tag packs its section and row: tag = section * kCellTagSectionMultiplier + row.
static const int kCellTagSectionMultiplier = 1000000;

// UILocalizedIndexedCollation returns this section index for entries with no collation letter.
static const int kCollationMiscSection = 0x24;

static const int kCollationLeadingSectionsToDrop = 26;

// The divisions are spelled in float because the pooled component is a single-precision quotient.
static const CGFloat kRowColorWhiteEven = 193.0f / 255.0f; // @ghidraAddress 0x310790
static const CGFloat kRowColorAlpha = 1.0;

// Dark grey, not white.
static const CGFloat kTitleLabelWhite = 50.0f / 255.0f; // @ghidraAddress 0x2eeef8
// Dark grey, not white.
static const CGFloat kTableBackgroundWhite = 47.0f / 255.0f; // @ghidraAddress 0x2eef38

static const CGRect kTopRect = {{0.0, 0.0}, {1.0, 1.0}};

static const CGFloat kHeaderHeightPhone = 25.0;
static const CGFloat kHeaderHeightPad = 30.0;

static const CGFloat kCellButtonFontSizePhone = 14.0;
static const CGFloat kCellButtonFontSizePad = 16.0;
static const CGFloat kCellTitleFontSizePhone = 15.0;
static const CGFloat kCellTitleFontSizePad = 17.0;
static const CGFloat kBarButtonFontSizePhone = 12.0;
static const CGFloat kBarButtonFontSizePad = 14.0;

static const CGFloat kCellLabelWidthPhone = 10.0;
static const CGFloat kCellLabelHeightPhone = 16.0;
static const CGFloat kCellLabelHeightPad = 18.0;

static const CGFloat kCellButtonTrailingGap = 10.0;

// @ghidraAddress 0x3107b0 (row heights), 0x3107c0 (button heights)
static const CGFloat kRowHeight[] = {50.0, 60.0};
static const CGFloat kButtonHeight[] = {36.0, 40.0};

// @ghidraAddress 0x36ebc0 (title), 0x36ebe0 (tab title)
static NSString *const kNavigationTitle = @"Manage Library";
static NSString *const kTabTitle = @"Manage";

static NSString *const kTabIconName = @"09_store/icon_manage";
static NSString *const kDeleteImageName = @"09_store/manage_delete";
static NSString *const kDownloadImageName = @"09_store/manage_download";

static NSString *const kHeaderReuseIdentifier = @"ManageHeader";
static NSString *const kCellReuseIdentifier = @"StoreManageCell";

static NSString *const kJapaneseVersionMarker = @"ja_";

// @ghidraAddress 0x365fa0
static NSString *const kSortButtonKey = @"並べ替え";
static NSString *const kTopButtonKey = @"TOP";
static NSString *const kEmptyLocalizedValue = @"";

// Japanese for "purchase order" and "title order".
// @ghidraAddress 0x36ec40
static NSString *const kSortTitleAscending = @"購入順にする";
// @ghidraAddress 0x36ec60
static NSString *const kSortTitleDescending = @"曲名順にする";

// @ghidraAddress 0x36eba0
static NSString *const kHeaderExpandedGlyph = @"\u25bc";
// The trailing U+FE0E forces the text rather than the emoji presentation of the triangle.
// @ghidraAddress 0x36ed20
static NSString *const kHeaderCollapsedGlyph = @"\u25b6\ufe0e";

static NSString *const kMusicKeyID = @"ID";
static NSString *const kMusicKeyName = @"Name";
static NSString *const kMusicKeyArtist = @"Artist";
static NSString *const kMusicKeyItemURL = @"ItemURL";
static NSString *const kMusicKeyNoteList = @"NoteList";
static NSString *const kMusicKeyMusic = @"Music";
static NSString *const kExtendNoteKeyID = @"ExtID";
static NSString *const kExtendNoteKeyURL = @"ExtURL2";
static NSString *const kSortKeyArtistYomi = @"a_yomi";
static NSString *const kSortKeyTitleYomi = @"m_yomi";
static NSString *const kSortKeyPackName = @"pack_name";
static NSString *const kSortKeyMusicId = @"musicId";

static NSString *const kSortLookupKeyFormat = @"%d";

@interface RBStoreManageViewController () {
    NSInteger working_section;
    unsigned char sectionOpenList[kSectionCount];
    NSInteger working_index;
    BOOL isPad;
}
@end

@implementation RBStoreManageViewController

#pragma mark - Section-open helpers

static inline void ExpandAllSections(unsigned char *sectionOpen) {
    for (NSUInteger i = 0; i < kSectionCount; ++i) {
        sectionOpen[i] = 1;
    }
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1cddc0 */
- (instancetype)initWithParent:(RBStoreTabController *)parent {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.parent = parent;
    working_section = 0;
    working_index = kNoWorkingIndex;

    self.navigationItem.title = kNavigationTitle;
    self.tabBarItem.title = kTabTitle;
    self.tabBarItem.image = [UIImage imageWithName:kTabIconName];
    self.imgDelete = [UIImage imageWithName:kDeleteImageName];
    self.imgDownload = [UIImage imageWithName:kDownloadImageName];
    self.latestArrayCount = 0;

    if ([GetFormattedVersionString() rangeOfString:kJapaneseVersionMarker].location != NSNotFound &&
        self.sortButton == nil) {
        NSString *sortTitle = [[NSBundle mainBundle] localizedStringForKey:kSortButtonKey
                                                                     value:kEmptyLocalizedValue
                                                                     table:nil];
        self.sortButton = [[UIBarButtonItem alloc] initWithTitle:sortTitle
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(presentSortSelect:)];
        CGFloat fontSize = !IsPad() ? kBarButtonFontSizePhone : kBarButtonFontSizePad;
        UIFont *font = [UIFont systemFontOfSize:fontSize];
        NSDictionary *attributes = @{NSFontAttributeName : font};
        [self.sortButton setTitleTextAttributes:attributes forState:UIControlStateNormal];
    }

    self.sortDict = nil;
    self.sectionList =
        @[ @"あ", @"か", @"さ", @"た", @"な", @"は", @"ま", @"や", @"ら", @"わ", @"#" ];
    ExpandAllSections(sectionOpenList);
    self.currentSortIndex = RBStoreManageSortOrderDownloadAscending;

    [self sortList:[[RBMusicManager getInstance] getPurchasedMusicDictionaris]];

    self.notFoundMusicList = [[NSMutableArray alloc] initWithCapacity:4];

    if (self.topButton == nil) {
        NSString *topTitle = [[NSBundle mainBundle] localizedStringForKey:kTopButtonKey
                                                                    value:kEmptyLocalizedValue
                                                                    table:nil];
        self.topButton = [[UIBarButtonItem alloc] initWithTitle:topTitle
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(goToTop:)];
        CGFloat fontSize = !IsPad() ? kBarButtonFontSizePhone : kBarButtonFontSizePad;
        UIFont *font = [UIFont systemFontOfSize:fontSize];
        NSDictionary *attributes = @{NSFontAttributeName : font};
        [self.topButton setTitleTextAttributes:attributes forState:UIControlStateNormal];
    }

    if (self.sortButton != nil && self.topButton != nil) {
        self.navigationItem.rightBarButtonItems = @[ self.sortButton, self.topButton ];
    } else if (self.topButton != nil) {
        self.navigationItem.rightBarButtonItems = @[ self.topButton ];
    } else if (self.sortButton != nil) {
        self.navigationItem.rightBarButtonItems = @[ self.sortButton ];
    }

    isPad = IsPad();

    return self;
}

/** @ghidraAddress 0x1ce97c */
- (void)loadView {
    [super loadView];

    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.rowHeight = kRowHeight[isPad ? 1 : 0];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsSelection = NO;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithWhite:kTableBackgroundWhite
                                                       alpha:kRowColorAlpha];
    if ([self.tableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]) {
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
#ifdef ENABLE_PATCHES
    // The shipped binary's older linked SDK gave zero padding for free; a current SDK defaults to
    // 22 pt above every section header, including a nil zero-height one.
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
#endif
    [self.view addSubview:self.tableView];

    self.sortViewCtrl = [[RBStoreManageSortViewController alloc] init];
    self.sortViewCtrl.manageViewCtrl = self;
    self.sortNavCtrl =
        [[UINavigationController alloc] initWithRootViewController:self.sortViewCtrl];

    if (IsPad()) {
        self.sortPopoverCtrl =
            [[UIPopoverController alloc] initWithContentViewController:self.sortNavCtrl];
        self.sortPopoverCtrl.delegate = self;
    }

    for (UIView *subview in self.navigationController.navigationBar.subviews) {
        subview.exclusiveTouch = YES;
    }
}

/** @ghidraAddress 0x1d48c0 */
- (void)dealloc {
    self.deleteAlertView.delegate = nil;
    self.tableView.dataSource = nil;
    self.tableView.delegate = nil;
    [self.dlManager cancel];
    if (self.infoDownloader != nil) {
        [self.infoDownloader cancel];
    }
    [self.view removeFromSuperview];
}

#pragma mark - Sort selection

/** @ghidraAddress 0x1cf0ec */
- (void)presentSortSelect:(id)sender {
    if (!IsPad()) {
        [self.navigationController pushViewController:self.sortViewCtrl animated:YES];
        return;
    }

    if (self.sortPopoverCtrl.isPopoverVisible) {
        [self.sortPopoverCtrl dismissPopoverAnimated:YES];
    } else {
        [self.sortPopoverCtrl presentPopoverFromBarButtonItem:sender
                                     permittedArrowDirections:UIPopoverArrowDirectionUp
                                                     animated:YES];
        self.navigationItem.leftBarButtonItem.enabled = NO;
    }
}

/** @ghidraAddress 0x1cf2cc */
- (void)hideSortSelect:(id)sender {
    if (!IsPad()) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self.sortPopoverCtrl dismissPopoverAnimated:YES];
    }
    self.navigationItem.leftBarButtonItem.enabled = YES;
}

/** @ghidraAddress 0x1cf3f4 */
- (void)switchToSort:(NSNumber *)sort title:(NSString *)title {
    NSUInteger newIndex = sort.unsignedIntegerValue;
    if (self.currentSortIndex == newIndex) {
        return;
    }

    if (self.sortDict == nil) {
        self.tmpCurrentSortIndex = newIndex;
        self.tmpCurrentSortTitle = title;
        self.downloadAlertView = [UIAlertView showAlertNeedDownloadMusicNameList:self];
        return;
    }

    self.navigationItem.title = @"";
    self.tmpCurrentSortIndex = 0;
    self.tmpCurrentSortTitle = @"";
    self.currentSortIndex = newIndex;
    self.sortButton.title = title;
    [self sortList:[[RBMusicManager getInstance] getPurchasedMusicDictionaris]];
    ExpandAllSections(sectionOpenList);
    [self.tableView reloadData];
    if (self.notFoundMusicList.count != 0) {
        [UIAlertView showAlertNotFoundMusics:self.notFoundMusicList];
    }
    [self.notFoundMusicList removeAllObjects];
}

/** @ghidraAddress 0x1cf77c */
- (void)SelectSort {
    if (self.sortDict == nil) {
        self.downloadAlertView = [UIAlertView showAlertNeedDownloadMusicNameList:self];
        return;
    }

    if ([self.sortButton.title isEqualToString:kSortTitleAscending]) {
        self.sortButton.title = kSortTitleDescending;
        [self.tableView reloadData];
    } else if ([self.sortButton.title isEqualToString:kSortTitleDescending]) {
        self.sortButton.title = kSortTitleAscending;
        [self.tableView reloadData];
    }
}

/** @ghidraAddress 0x1cf9ec */
- (NSDictionary *)getSortedDictionary:(NSUInteger)section row:(NSUInteger)row {
    if (self.currentSortIndex < RBStoreManageSortOrderTitle) {
        return self.sortedList[section][row];
    }
    RBManageSortData *record = self.sortedList[section][row];
    return record.dict;
}

#pragma mark - Sorting

// Both sorts test a_yomi when re-bucketing a "#" entry, even the title sort, which otherwise
// collates on m_yomi.
// @ghidraAddress 0x1d0484
// @ghidraAddress 0x1d0494
- (NSArray *)collatedListForSort:(NSArray *)list collationSelector:(SEL)collationSelector {
    NSArray *entries = [list copy];
    UILocalizedIndexedCollation *collation = [UILocalizedIndexedCollation currentCollation];
    NSUInteger sectionTitleCount = collation.sectionTitles.count;

    NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionTitleCount];
    for (NSUInteger i = 0; i < sectionTitleCount; ++i) {
        [sections addObject:[NSMutableArray array]];
    }

    for (NSDictionary *entry in entries) {
        RBManageSortData *record = [[RBManageSortData alloc] init];
        NSString *lookupKey =
            [NSString stringWithFormat:kSortLookupKeyFormat, [entry[kMusicKeyID] intValue]];
        NSDictionary *sortInfo = self.sortDict[lookupKey];
        if (sortInfo == nil) {
            record.a_yomi = @"";
            record.m_yomi = @"";
            record.pack_name = @"";
            record.musicId = (NSUInteger)[entry[kMusicKeyID] intValue];
            record.dict = [entry copy];
            [self.notFoundMusicList addObject:entry[kMusicKeyName]];
        } else {
            record.a_yomi = sortInfo[kSortKeyArtistYomi];
            record.m_yomi = sortInfo[kSortKeyTitleYomi];
            record.pack_name = sortInfo[kSortKeyPackName];
            record.musicId = [sortInfo[kSortKeyMusicId] unsignedIntegerValue];
            record.dict = [entry copy];
        }

        NSInteger sectionIndex = [collation sectionForObject:record
                                     collationStringSelector:collationSelector];
        if (sectionIndex == kCollationMiscSection) {
            NSUInteger shift = (record.a_yomi != nil && record.a_yomi.length != 0) ? 1 : 0;
            sectionIndex = kCollationMiscSection - shift;
        }
        [sections[sectionIndex] addObject:record];
    }

    NSMutableArray *sorted = [NSMutableArray arrayWithCapacity:sectionTitleCount];
    for (NSMutableArray *section in sections) {
        [sorted addObject:[collation sortedArrayFromArray:section
                                  collationStringSelector:collationSelector]];
    }
    for (NSInteger i = 0; i < kCollationLeadingSectionsToDrop; ++i) {
        [sorted removeObjectAtIndex:0];
    }
    return sorted;
}

/** @ghidraAddress 0x1cfb48 */
- (NSArray *)sortList:(NSArray *)list {
    [self.notFoundMusicList removeAllObjects];

    NSArray *result;
    switch (self.currentSortIndex) {
    case RBStoreManageSortOrderDownloadDescending: {
        NSArray *reversed = [list reverseObjectEnumerator].allObjects;
        result = @[ reversed ];
        break;
    }
    case RBStoreManageSortOrderTitle:
        result = [self collatedListForSort:list collationSelector:@selector(m_yomi)];
        break;
    case RBStoreManageSortOrderArtist:
        result = [self collatedListForSort:list collationSelector:@selector(a_yomi)];
        break;
    default:
        result = @[ list ];
        break;
    }

    if (self.sortedList != nil) {
        [self.sortedList removeAllObjects];
        self.sortedList = nil;
    }
    self.sortedList = [result mutableCopy];
    self.latestArrayCount = [[RBMusicManager getInstance] getPurchasedMusicDictionaris].count;
    return result;
}

#pragma mark - Table actions

/** @ghidraAddress 0x1d1080 */
- (void)goToTop:(id)sender {
    if (self.tableView != nil) {
        [self.tableView scrollRectToVisible:kTopRect animated:YES];
    }
}

/** @ghidraAddress 0x1d1130 */
- (void)toggleOpen:(id)sender {
    NSInteger section = [(RBStoreManageHeaderCell *)[sender view] section];
    sectionOpenList[section] ^= 1;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:section]
                  withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

/** @ghidraAddress 0x1d1280 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.currentSortIndex >= RBStoreManageSortOrderTitle &&
        [self.sortedList[section] count] != 0) {
        return IsPad() ? kHeaderHeightPad : kHeaderHeightPhone;
    }
    return 0.0;
}

/** @ghidraAddress 0x1d1364 */
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (self.currentSortIndex < RBStoreManageSortOrderTitle) {
        return nil;
    }

    RBStoreManageHeaderCell *header =
        [tableView dequeueReusableHeaderFooterViewWithIdentifier:kHeaderReuseIdentifier];
    if (header == nil) {
        header = [[RBStoreManageHeaderCell alloc] initWithReuseIdentifier:kHeaderReuseIdentifier
                                                                    frame:tableView.bounds
                                                                  section:section
                                                               withTarget:self];
    }
    header.openedLabel.text =
        sectionOpenList[section] != 0 ? kHeaderExpandedGlyph : kHeaderCollapsedGlyph;
    header.titleLabel.text = self.sectionList[section];
    header.exclusiveTouch = YES;
    header.section = section;
    return header;
}

/** @ghidraAddress 0x1d15b4 */
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.currentSortIndex >= RBStoreManageSortOrderTitle &&
        [self.sortedList[section] count] != 0) {
        return self.sectionList[section];
    }
    return nil;
}

/** @ghidraAddress 0x1d16dc */
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (self.currentSortIndex < RBStoreManageSortOrderTitle) {
        return nil;
    }
    return self.sectionList;
}

/** @ghidraAddress 0x1d172c */
- (NSInteger)tableView:(UITableView *)tableView
    sectionForSectionIndexTitle:(NSString *)title
                        atIndex:(NSInteger)index {
    if (self.currentSortIndex >= RBStoreManageSortOrderTitle) {
        return index;
    }
    return 0;
}

/** @ghidraAddress 0x1d175c */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RBStoreManageCell *cell =
        [self.tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier];
    if (cell == nil) {
        cell = [[RBStoreManageCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                        reuseIdentifier:kCellReuseIdentifier];

        CGFloat labelWidth = isPad ? g_dCustomizeLayoutMetric100 : kCellLabelWidthPhone;
        CGFloat labelHeight = isPad ? kCellLabelHeightPad : kCellLabelHeightPhone;
        UILabel *nameLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(0, 0, labelWidth, labelHeight)];
        nameLabel.opaque = NO;
        nameLabel.backgroundColor = UIColor.clearColor;
        nameLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        self.labelName = nameLabel;
        self.labelName.backgroundColor = UIColor.clearColor;
        self.labelName.font =
            [UIFont boldSystemFontOfSize:isPad ? kCellTitleFontSizePad : kCellTitleFontSizePhone];
        self.labelName.textColor = [UIColor colorWithWhite:kTitleLabelWhite alpha:kRowColorAlpha];
        self.labelName.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        // The binary reads the ivar directly here, unlike the four uses above.
        [cell addSubview:_labelName];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat buttonFontSize = isPad ? kCellButtonFontSizePad : kCellButtonFontSizePhone;
        button.titleLabel.font = [UIFont boldSystemFontOfSize:buttonFontSize];
        [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                  UIViewAutoresizingFlexibleTopMargin |
                                  UIViewAutoresizingFlexibleBottomMargin;
        [button addTarget:self
                      action:@selector(pushCellButton:)
            forControlEvents:UIControlEventTouchUpInside];
        [cell addSubview:button];
        button.exclusiveTouch = YES;
        cell.button = button;
    }

    NSDictionary *entry = [self getSortedDictionary:indexPath.section row:indexPath.row];
    int musicId = [entry[kMusicKeyID] unsignedIntValue];
    BOOL fileExists =
        [NSFileManager isFileExist:[RBMusicManager getPathFromPurchesed:musicId]] ||
        [NSFileManager isFileExist:[RBMusicManager getPathFromPurchesedOldDirectory:musicId]];

    UIButton *button = cell.button;
    button.tag = indexPath.section * kCellTagSectionMultiplier + indexPath.row;
    if (fileExists) {
        [button setImage:self.imgDelete forState:UIControlStateNormal];
        if (isPad) {
            [button setTitle:g_pLocalizedDelete forState:UIControlStateNormal];
        }
    } else {
        [button setImage:self.imgDownload forState:UIControlStateNormal];
        if (isPad) {
            [button setTitle:g_pLocalizedDownload forState:UIControlStateNormal];
        }
    }
    [button sizeToFit];

    CGFloat cellWidth = cell.frame.size.width;
    CGFloat cellHeight = cell.frame.size.height;
    CGFloat buttonWidth = button.frame.size.width;
    CGFloat buttonHeight = kButtonHeight[isPad ? 1 : 0];
    CGFloat trailingInset;
    if (self.currentSortIndex < RBStoreManageSortOrderTitle) {
        trailingInset = kCellButtonTrailingGap;
    } else {
        trailingInset = !IsPad() ? kHeaderHeightPhone : g_dSliderRowHeightWide;
    }
    button.frame = CGRectMake(cellWidth - buttonWidth - trailingInset,
                              (cellHeight - buttonHeight) * 0.5,
                              buttonWidth,
                              buttonHeight);

    cell.textLabel.text = entry[kMusicKeyName];
    cell.detailTextLabel.text = entry[kMusicKeyArtist];
    return cell;
}

/** @ghidraAddress 0x1d2220 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (sectionOpenList[section] == 0) {
        return 0;
    }
    return [self.sortedList[section] count];
}

/** @ghidraAddress 0x1d22e8 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    UIColor *background;
    if ((indexPath.row & 1) == 0) {
        background = [UIColor colorWithWhite:kRowColorWhiteEven alpha:kRowColorAlpha];
    } else {
        background = [UIColor colorWithWhite:g_dTranslucentAlpha alpha:kRowColorAlpha];
    }
    cell.backgroundColor = background;
}

/** @ghidraAddress 0x1d2434 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.currentSortIndex >= RBStoreManageSortOrderTitle) {
        return self.sectionList.count;
    }
    return 1;
}

#pragma mark - Cell button and downloads

/** @ghidraAddress 0x1d24bc */
- (void)pushCellButton:(id)sender {
    if (working_index != kNoWorkingIndex) {
        return;
    }

    NSInteger tag = [sender tag];
    working_section = tag / kCellTagSectionMultiplier;
    working_index = tag % kCellTagSectionMultiplier;

    NSDictionary *entry = [self getSortedDictionary:working_section row:working_index];
    int musicId = [entry[kMusicKeyID] unsignedIntValue];
    // The binary checks the same purchased path twice rather than falling back to the old
    // directory as the cell renderer does.
    BOOL fileExists = [NSFileManager isFileExist:[RBMusicManager getPathFromPurchesed:musicId]] ||
                      [NSFileManager isFileExist:[RBMusicManager getPathFromPurchesed:musicId]];

    if (!fileExists) {
        // The dialog is laid out before its message is set, not after.
        [self.parent.modalDialog layout:NO];
        self.parent.modalDialog.labelMessage.text =
            [NSString stringWithFormat:g_pDownloadingMessageFormat, entry[kMusicKeyName]];
        if ([self.parent showModalDialog:self]) {
            self.infoDownloader = [[Downloader alloc] initWithURL:[StoreUtil musicInfoURL:musicId]
                                                             save:nil];
            [self.infoDownloader startDownloadingWithDelegate:self];
        } else {
            working_section = kNoWorkingIndex;
            working_index = kNoWorkingIndex;
        }
        return;
    }

    NSString *message =
        [[NSString alloc] initWithFormat:g_pDeleteConfirmFormat, entry[kMusicKeyName]];
    if (self.deleteAlertView != nil) {
        self.deleteAlertView = nil;
    }
    self.deleteAlertView = [UIAlertView deleteAlertViewWithDelegate:self];
    self.deleteAlertView.message = message;
    [self.deleteAlertView show];
}

/** @ghidraAddress 0x1d2ab8 */
- (void)startDownloadMusic {
    NSDictionary *entry = [self getSortedDictionary:working_section row:working_index];
    int musicId = [entry[kMusicKeyID] unsignedIntValue];
    NSString *path = [RBMusicManager getPathFromPurchesed:musicId];

    NSMutableArray *tasks = [[NSMutableArray alloc] init];
    StoreDownloadTask *tuneTask = [[StoreDownloadTask alloc] initWithURL:entry[kMusicKeyItemURL]
                                                                    path:path
                                                               AddObject:nil];
    [tasks addObject:tuneTask];

    NSArray *extendNotes =
        [[RBExtendNoteManager getInstance] getPurchasedExtendNoteDictionaryWithMusicID:musicId];
    if (extendNotes.count != 0) {
        for (NSDictionary *note in extendNotes) {
            int extendNoteId = [note[kExtendNoteKeyID] intValue];
            NSString *notePath = [RBExtendNoteManager getPathFromPurchased:extendNoteId];
            StoreDownloadTask *noteTask =
                [[StoreDownloadTask alloc] initWithURL:note[kExtendNoteKeyURL]
                                                  path:notePath
                                             AddObject:nil];
            [tasks addObject:noteTask];
        }
    }

    self.dlManager = [[StoreDownloadManager alloc] initWithTasks:tasks delegate:self];
    [self.dlManager start];
}

/** @ghidraAddress 0x1d3b10 */
- (void)storeDialogCancel:(id)sender {
    if (self.infoDownloader != nil) {
        [self.infoDownloader cancel];
        self.infoDownloader = nil;
    }
    if (self.dlManager != nil) {
        [self.dlManager cancel];
    }
    [self.parent hideModalDialog];
    working_section = kNoWorkingIndex;
    working_index = kNoWorkingIndex;
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x1d3058 */
- (void)downloaderFinished:(Downloader *)downloader {
    if (self.infoDownloader == downloader) {
        NSDictionary *json = [self.infoDownloader getDataInJSON];
        StoreMusicInfo *musicInfo = [[StoreMusicInfo alloc] initWithDictionary:json];
        if (musicInfo != nil) {
            if ([[RBMusicManager getInstance] addPurchasedMusic:musicInfo]) {
                [[RBMusicManager getInstance] savePurchasedMusics];
            }
        }

        NSArray *noteList = json[kMusicKeyNoteList];
        if (noteList != nil) {
            NSMutableDictionary *musicOnly = [json mutableCopy];
            [musicOnly removeObjectForKey:kMusicKeyNoteList];
            BOOL anyAdded = NO;
            for (NSDictionary *note in noteList) {
                RBExtendNoteManager *manager = [RBExtendNoteManager getInstance];
                NSDictionary *purchased =
                    [manager getPurchasedExtendNoteDictionary:[note[kExtendNoteKeyID] intValue]];
                if (purchased != nil) {
                    NSMutableDictionary *noteInfo = [note mutableCopy];
                    noteInfo[kMusicKeyMusic] = musicOnly;
                    StoreExtendNoteInfo *info =
                        [[StoreExtendNoteInfo alloc] initWithDictionary:noteInfo];
                    anyAdded |= [[RBExtendNoteManager getInstance] addPurchasedExtendNote:info];
                }
            }
            if (anyAdded) {
                [[RBExtendNoteManager getInstance] savePurchasedNotes];
            }
        }

        self.infoDownloader = nil;
        [self startDownloadMusic];
    } else if (self.sortDataDownloader == downloader) {
        self.sortDict = [[self.sortDataDownloader getDataInJSON] mutableCopy];
        if (self.sortDict == nil) {
            [self downloaderError:downloader];
        } else {
            for (id key in self.sortDict) {
                NSMutableDictionary *info = self.sortDict[key];
                info[kSortKeyArtistYomi] = [StringConvert convertYomigana:info[kSortKeyArtistYomi]];
                info[kSortKeyTitleYomi] = [StringConvert convertYomigana:info[kSortKeyTitleYomi]];
            }
            self.sortDataDownloader = nil;
            [self switchToSort:@(self.tmpCurrentSortIndex) title:self.tmpCurrentSortTitle];
        }
    }
}

/** @ghidraAddress 0x1d39e0 */
- (void)downloaderError:(Downloader *)downloader {
    if (self.infoDownloader == downloader) {
        self.infoDownloader = nil;
        [self startDownloadMusic];
        working_section = kNoWorkingIndex;
        working_index = kNoWorkingIndex;
    } else if (self.sortDataDownloader == downloader) {
        self.sortDataDownloader = nil;
        working_section = kNoWorkingIndex;
        working_index = kNoWorkingIndex;
        [UIAlertView showNetworkErrorWithDelegate:nil];
    }
}

#pragma mark - StoreDownloadManagerDelegate

/** @ghidraAddress 0x1d42ec */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    self.dlManager = nil;
    [self.tableView reloadData];
    [self.parent hideModalDialog];
    [self.parent.campaignViewCtrl refreshUnlockTable];
    [[RBMusicManager getInstance] createMusicDataArray];
    [[RBMusicManager getInstance] setMusicDataArrayDirty];
    working_section = kNoWorkingIndex;
    working_index = kNoWorkingIndex;
}

/** @ghidraAddress 0x1d4494 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    self.dlManager = nil;
    [UIAlertView showDownloadErrorWithDelegate:nil];
    [self.parent hideModalDialog];
    working_section = kNoWorkingIndex;
    working_index = kNoWorkingIndex;
}

/** @ghidraAddress 0x1d454c */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    self.parent.modalDialog.progressView.progress = self.dlManager.overallProgress;
}

#pragma mark - UIPopoverControllerDelegate

/** @ghidraAddress 0x1d2fc4 */
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.navigationItem.leftBarButtonItem.enabled = YES;
}

#pragma mark - UIAlertViewDelegate

/** @ghidraAddress 0x1d3c5c */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.deleteAlertView == alertView) {
        if (buttonIndex == kAlertButtonConfirm) {
            NSDictionary *entry = [self getSortedDictionary:working_section row:working_index];
            int musicId = [entry[kMusicKeyID] unsignedIntValue];
            [[RBMusicManager getInstance] deleteMusic:musicId];

            NSMutableArray<MusicDataExtend *> *extendNotes =
                [[RBExtendNoteManager getInstance] getExtendNoteDataWithMusicID:musicId];
            for (MusicDataExtend *note in extendNotes) {
                [[RBExtendNoteManager getInstance] deleteExtendNote:note.ExtMusicID];
            }

            [self.tableView reloadData];
            [self.parent.campaignViewCtrl refreshUnlockTable];
        }
    } else if (buttonIndex == kAlertButtonConfirm && self.downloadAlertView == alertView) {
        self.sortDataDownloader = [[Downloader alloc] initWithURL:[StoreUtil manageSortListURL]
                                                             save:nil];
        [self.sortDataDownloader startDownloadingWithDelegate:self];
    }
    working_section = kNoWorkingIndex;
    working_index = kNoWorkingIndex;
}

/** @ghidraAddress 0x1d414c */
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    working_section = kNoWorkingIndex;
    working_index = kNoWorkingIndex;
}

/** @ghidraAddress 0x1d416c */
- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    working_section = kNoWorkingIndex;
    working_index = kNoWorkingIndex;
}

/** @ghidraAddress 0x1d418c */
- (void)alertViewCancel:(UIAlertView *)alertView {
    working_section = kNoWorkingIndex;
    working_index = kNoWorkingIndex;
}

/** @ghidraAddress 0x1d41ac */
- (void)didPresentAlertView:(UIAlertView *)alertView {
    UIView *presentedView = [[[[[UIApplication sharedApplication] keyWindow] rootViewController]
        presentedViewController] view];
    [UIAlertView setExclusiveTouchForView:presentedView];
}

#pragma mark - Rotation and appearance

/** @ghidraAddress 0x1d465c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

/** @ghidraAddress 0x1d4664 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.sortedList != nil) {
        if (self.latestArrayCount !=
            [[RBMusicManager getInstance] getPurchasedMusicDictionaris].count) {
            [self sortList:[[RBMusicManager getInstance] getPurchasedMusicDictionaris]];
        }
    }
}

/** @ghidraAddress 0x1d47f8 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView reloadData];
    [self.tableView flashScrollIndicators];
}

@end
