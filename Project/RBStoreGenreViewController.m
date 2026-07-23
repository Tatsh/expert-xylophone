#import "RBStoreGenreViewController.h"

#import <UIKit/UIKit.h>

#import "RBStorePackList.h"
#import "RBStorePageViewController.h"
#import "StorePackListGenre.h"
#import "neEngineBridge.h"

// The localised navigation title key and its empty fallback value, shared with the store page.
static NSString *const kStoreCategoryKey = @"Category";
static NSString *const kStoreEmptyTitle = @"";

// The reuse identifier for the genre table's cells.
static NSString *const kStoreGenreTableCellIdentifier = @"StoreGenreTableCell";

// The fixed genre-row height, in points.
static const CGFloat kGenreRowHeight = 50.0;

// The genre cell text size, in points.
static const CGFloat kGenreCellFontSize = 19.0;

// The preferred content size: a fixed width, and a height of the genre count times the row height
// clamped to a maximum.
static const CGFloat kGenrePreferredContentWidth = 320.0;
static const CGFloat kGenrePreferredContentMaxHeight = 600.0;

@implementation RBStoreGenreViewController

#pragma mark - Lifecycle

/** @ghidraAddress 0x1ca638 */
- (void)loadView {
    [super loadView];
    self.view.opaque = YES;
    self.view.backgroundColor = [UIColor whiteColor];
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.exclusiveTouch = YES;
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.rowHeight = kGenreRowHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsSelection = YES;
    self.tableView.backgroundColor = [UIColor clearColor];
    CGFloat height = MIN((CGFloat)self.packListCtrl.numGenres * kGenreRowHeight,
                         kGenrePreferredContentMaxHeight);
    self.preferredContentSize = CGSizeMake(kGenrePreferredContentWidth, height);
    [self.view addSubview:self.tableView];
}

/** @ghidraAddress 0x1cab0c */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = [[NSBundle mainBundle] localizedStringForKey:kStoreCategoryKey
                                                        value:kStoreEmptyTitle
                                                        table:nil];
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x1cabe8 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kStoreGenreTableCellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:kStoreGenreTableCellIdentifier];
    }
    cell.textLabel.opaque = NO;
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:kGenreCellFontSize];
    cell.textLabel.text = [self.packListCtrl packListForGenreIndex:indexPath.row].genreName;
    return cell;
}

/** @ghidraAddress 0x1caf08 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x1caf10 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.packListCtrl.numGenres;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x1caf78 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
}

/** @ghidraAddress 0x1caf7c */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kGenreRowHeight;
}

/** @ghidraAddress 0x1caf88 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.storeViewCtrl != nil &&
        [self.storeViewCtrl respondsToSelector:@selector(switchToGenre:)]) {
        [self.storeViewCtrl performSelector:@selector(switchToGenre:)
                                 withObject:@((NSUInteger)indexPath.row)];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // The binary branches on the font variant here, but both arms dismiss identically, so the call
    // is unconditional.
    (void)GetFontVariantFlag();
    [self.storeViewCtrl hideGenreSelect:nil];
}

@end
