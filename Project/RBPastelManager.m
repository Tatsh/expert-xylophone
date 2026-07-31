//
//  RBPastelManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBPastelManager). Verified against
//  the arm64 disassembly of -tryShow: (the sequential gate-and-clear loop is partly obscured by the
//  decompiler).
//

#import "RBPastelManager.h"

// The number of stages tracked by the show-list. The pastel tutorial advances through these stages
// in order, and -tryShow: gates each stage on all earlier stages having been shown.
static const NSUInteger kPastelShowStageCount = 4;

@implementation RBPastelManager {
    // The per-stage shown flags. A stage is granted by -tryShow: only once every earlier stage is
    // set; granting a stage clears the trailing stages so the sequence always advances in order.
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
    currentShowList[0] = NO;
}

/** @ghidraAddress 0x20b0c */
+ (BOOL)tryShow:(unsigned int)tryShow {
    // A class method: the binary reaches the show list through the shared singleton loaded from
    // its global slot, added to the ivar offset, rather than through any receiver.
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
