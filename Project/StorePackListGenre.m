#import "StorePackListGenre.h"

// The initial capacity of the accumulated pack-identifier array.
enum { kPackInfoInitialCapacity = 20 };

// The fetched-page offset a freshly built genre starts from.
enum { kNumFetchedPackInitial = 0 };

@implementation StorePackListGenre

#pragma mark - Lifecycle

/** @ghidraAddress 0x33f00 */
- (instancetype)initWithName:(NSString *)name genreID:(NSUInteger)genreID {
    self = [super init];
    if (self) {
        self.arrayPackInfo = [[NSMutableArray alloc] initWithCapacity:kPackInfoInitialCapacity];
        self->_genreName = name;
        self->_genreID = genreID;
        self->_packlistContinued = NO;
        self->_numFetchedPack = kNumFetchedPackInitial;
    }
    return self;
}

#pragma mark - Pack access

/** @ghidraAddress 0x3403c */
- (NSUInteger)packCount {
    return self.arrayPackInfo.count;
}

/** @ghidraAddress 0x3409c */
- (NSNumber *)packInfoForIndex:(NSUInteger)index {
    if (index < self.arrayPackInfo.count) {
        return self.arrayPackInfo[index];
    }
    return nil;
}

/** @ghidraAddress 0x34170 */
- (NSArray<NSNumber *> *)packIDList {
    return self.arrayPackInfo;
}

#pragma mark - Page accumulation

/** @ghidraAddress 0x3417c */
- (void)updateList:(NSArray<NSNumber *> *)list step:(NSUInteger)step hasNext:(BOOL)hasNext {
    if (list.count != 0) {
        [self.arrayPackInfo addObjectsFromArray:list];
    }
    self->_packlistContinued = hasNext;
    self->_numFetchedPack += step;
}

@end
