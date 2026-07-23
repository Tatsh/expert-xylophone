//
//  RBMusicGridLayout.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMusicGridLayout). The layout
//  logic in -prepareLayout, -layoutAttributesForElementsInRect:, and -init was recovered from the
//  arm64 decompile and cross-checked against the disassembly at 0x16d5dc/0x16d7d8/0x16df1c; the
//  scalar accessors are auto-synthesised from their ivar-backed getters/setters.
//

#import "RBMusicGridLayout.h"

#import "RBMusicCell.h"
#import "neEngineBridge.h"

// All items live in a single section.
static const NSInteger kGridSection = 0;

// The leftover slack on each axis is split so that half a gap sits before the first cell.
static const NSInteger kGridSlackHalfDivisor = 2;

// Standard (narrow) item metrics used when the large-iPad idiom is off.
static const CGFloat kItemWidthNarrow = 92.0;
static const CGFloat kItemHeightNarrow = 114.0;
static const UIEdgeInsets kPageInsetNarrow = {5.0, 10.0, 0.0, 10.0};

// Large-font (wide) item metrics used when the large-iPad idiom is on.
static const CGFloat kItemWidthWide = 184.0;
static const CGFloat kItemHeightWide = 230.0;
static const CGFloat kSpacingWide = 10.0;
static const UIEdgeInsets kPageInsetWide = {0.0, 30.0, 0.0, 30.0};

@implementation RBMusicGridLayout

- (instancetype)init {
    self = [super init];
    if (self) {
        if (!IsPad()) {
            self.itemSize = CGSizeMake(kItemWidthNarrow, kItemHeightNarrow);
            self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
            self.minimumLineSpacing = 0.0;
            self.minimumInteritemSpacing = 0.0;
            self.pageInset = kPageInsetNarrow;
            (void)GetIsTallScreenFlag(); // Yes, the binary discards this call's result.
        } else {
            self.itemSize = CGSizeMake(kItemWidthWide, kItemHeightWide);
            self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
            self.minimumLineSpacing = kSpacingWide;
            self.minimumInteritemSpacing = kSpacingWide;
            self.pageInset = kPageInsetWide;
        }
        [self registerClass:[RBMusicCell class]
            forDecorationViewOfKind:NSStringFromClass([RBMusicCell class])];
    }
    return self;
}

- (void)prepareLayout {
    [super prepareLayout];

    self.itemCount = [self.collectionView numberOfItemsInSection:kGridSection];
    self.pageSize = self.collectionView.bounds.size;

    CGFloat usableWidth = self.pageSize.width - self.pageInset.left - self.pageInset.right;
    CGFloat usableHeight = self.pageSize.height - self.pageInset.top - self.pageInset.bottom;

    self.colCount = (NSInteger)(usableWidth / (self.itemSize.width + self.minimumInteritemSpacing));
    if (self.colCount < 1) {
        self.colCount = 1;
    }
    self.rowCount = (NSInteger)(usableHeight / (self.itemSize.height + self.minimumLineSpacing));
    if (self.rowCount < 1) {
        self.rowCount = 1;
    }
    self.pageItemCount = self.rowCount * self.colCount;

    NSInteger pageCount = self.pageItemCount ? self.itemCount / self.pageItemCount : 0;
    if (self.pageItemCount && self.itemCount % self.pageItemCount) {
        pageCount += 1;
    }
    self.pageCount = pageCount;

    NSInteger columnSlack = 0;
    if (self.colCount >= 2) {
        columnSlack =
            (NSInteger)((usableWidth - self.colCount * self.itemSize.width) / self.colCount);
    }
    NSInteger rowSlack = 0;
    if (self.rowCount >= 2) {
        rowSlack =
            (NSInteger)((usableHeight - self.rowCount * self.itemSize.height) / self.rowCount);
    }

    NSMutableArray<UICollectionViewLayoutAttributes *> *layouts =
        [NSMutableArray arrayWithCapacity:self.itemCount];
    for (NSInteger i = 0; i < self.itemCount; ++i) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:kGridSection];
        UICollectionViewLayoutAttributes *attributes =
            [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];

        NSInteger page = self.pageItemCount ? i / self.pageItemCount : 0;
        NSInteger indexInPage = self.pageItemCount ? i % self.pageItemCount : i;
        NSInteger row = self.colCount ? indexInPage / self.colCount : 0;
        NSInteger column = self.colCount ? indexInPage % self.colCount : 0;

        CGFloat x = columnSlack / kGridSlackHalfDivisor + page * self.pageSize.width +
                    self.pageInset.left + column * (columnSlack + self.itemSize.width);
        CGFloat y = rowSlack / kGridSlackHalfDivisor + self.pageInset.top +
                    row * (rowSlack + self.itemSize.height);
        attributes.frame = CGRectMake(x, y, self.itemSize.width, self.itemSize.height);

        [layouts addObject:attributes];
    }
    self.layouts = layouts;

    self.contentSize = CGSizeMake(self.pageSize.width * self.pageCount, self.pageSize.height);
}

- (CGSize)collectionViewContentSize {
    return self.contentSize;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
}

- (UICollectionViewLayoutAttributes *)
    layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind
                                   atIndexPath:(NSIndexPath *)indexPath {
    return [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:elementKind
                                                                          withIndexPath:indexPath];
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSMutableArray<UICollectionViewLayoutAttributes *> *visible = [NSMutableArray array];
    for (NSInteger i = 0; i < self.itemCount; ++i) {
        UICollectionViewLayoutAttributes *attributes = self.layouts[i];
        if (CGRectIntersectsRect(rect, attributes.frame)) {
            [visible addObject:attributes];
        }
    }
    return visible;
}

@end
