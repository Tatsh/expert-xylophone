#import "RBPastelManager.h"

#include <string.h>

static const NSUInteger kPastelShowStageCount = 4;

@implementation RBPastelManager {
    BOOL currentShowList[kPastelShowStageCount];
}

#pragma mark - Singleton

+ (instancetype)getInstance {
    /** @ghidraAddress 0x20a30 */
    static RBPastelManager *instance = nil;
    if (instance == nil) {
        instance = [[RBPastelManager alloc] init];
    }
    return instance;
}

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x20a88 */
    self = [super init];
    if (self) {
        [self allReset];
    }
    return self;
}

#pragma mark - Show sequence

- (void)allReset {
    /** @ghidraAddress 0x20afc */
    memset(currentShowList, 0, sizeof(currentShowList));
}

/** @ghidraAddress 0x20b0c */
+ (BOOL)tryShow:(unsigned int)tryShow {
    RBPastelManager *manager = [RBPastelManager getInstance];
    BOOL *currentShowList = manager->currentShowList;
    unsigned int firstToClear;
    if (tryShow == 0) {
        currentShowList[0] = YES;
        firstToClear = 1;
    } else {
        for (unsigned int stage = 0; stage < tryShow; ++stage) {
            if (currentShowList[stage]) {
                return NO;
            }
        }
        currentShowList[tryShow] = YES;
        firstToClear = tryShow + 1;
        if (firstToClear >= kPastelShowStageCount) {
            return YES;
        }
    }
    for (unsigned int stage = firstToClear; stage < kPastelShowStageCount; ++stage) {
        currentShowList[stage] = NO;
    }
    return YES;
}

@end
