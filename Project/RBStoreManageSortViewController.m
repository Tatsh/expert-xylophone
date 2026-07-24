#import "RBStoreManageSortViewController.h"

#import "RBStoreManageViewController.h"
#import "neEngineBridge.h"

// The four built-in sort-order titles, seeded into sortTitleList when it is empty.
static NSString *const kSortTitleDownloadAscending = @"ダウンロード：昇順";
static NSString *const kSortTitleDownloadDescending = @"ダウンロード：降順";
static NSString *const kSortTitleSongName = @"楽曲名順";
static NSString *const kSortTitleArtistName = @"アーティスト名";

// The localisation key for the navigation title (the "sort" heading).
static NSString *const kSortTitleLocalizationKey = @"並べ替え";

// The reuse identifier for the sort-order cells.
static NSString *const kSortTableCellReuseIdentifier = @"ManageSortTableCell";

// The height of every sort-order row.
static const CGFloat kSortRowHeight = 50.0;
// The per-row contribution to the popover's preferred content height.
static const CGFloat kSortRowContentHeight = 50.0;
// The upper bound on the popover's preferred content height.
static const CGFloat kSortMaxContentHeight = 600.0;
// The fixed width of the popover's preferred content size.
static const CGFloat kSortContentWidth = 320.0;
// The point size of the sort-order cell title font.
static const CGFloat kSortCellFontSize = 19.0;

@implementation RBStoreManageSortViewController

#pragma mark - View lifecycle

- (void)loadView {
    if (self.sortTitleList == nil) {
        self.sortTitleList = @[
            kSortTitleDownloadAscending,
            kSortTitleDownloadDescending,
            kSortTitleSongName,
            kSortTitleArtistName
        ];
    }
    self.sortRuleCount = self.sortTitleList.count;

    [super loadView];

    self.view.opaque = YES;
    self.view.backgroundColor = UIColor.whiteColor;
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.exclusiveTouch = YES;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.rowHeight = kSortRowHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsSelection = YES;
    self.tableView.backgroundColor = UIColor.clearColor;

    CGFloat contentHeight = self.sortRuleCount * kSortRowContentHeight;
    if (contentHeight > kSortMaxContentHeight) {
        contentHeight = kSortMaxContentHeight;
    }
    self.preferredContentSize = CGSizeMake(kSortContentWidth, contentHeight);

    [self.view addSubview:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = [[NSBundle mainBundle] localizedStringForKey:kSortTitleLocalizationKey
                                                        value:@""
                                                        table:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sortRuleCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kSortTableCellReuseIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:kSortTableCellReuseIdentifier];
    }
    cell.textLabel.opaque = NO;
    cell.textLabel.backgroundColor = UIColor.clearColor;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:kSortCellFontSize];
    cell.textLabel.text = self.sortTitleList[indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kSortRowHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.manageViewCtrl != nil &&
        [self.manageViewCtrl respondsToSelector:@selector(switchToSort:title:)]) {
        [self.manageViewCtrl performSelector:@selector(switchToSort:title:)
                                  withObject:@(indexPath.row)
                                  withObject:self.sortTitleList[indexPath.row]];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // The binary tests the iPad idiom flag here but takes the same action either way.
    if (!IsPad()) {
        [self.manageViewCtrl hideSortSelect:nil];
    } else {
        [self.manageViewCtrl hideSortSelect:nil];
    }
}

@end
