//
//  PurchaseTransactionCache.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class PurchaseTransactionCache).
//  Verified against the arm64 disassembly (the initialiser performs an iOS-version comparison
//  whose result is discarded, so it is reproduced only for fidelity; the accessors are plain
//  retaining setters and the destructor releases every cached object).
//

#import "PurchaseTransactionCache.h"

#import <UIKit/UIKit.h>

/// The system-version threshold the initialiser compares the running system version against. The
/// comparison result is discarded, so it is a vestigial gate that no longer affects the snapshot.
/// @ghidraAddress 0x36bb00 (the @c "7.0" constant string)
static NSString *const kSystemVersionThreshold = @"7.0";

@implementation PurchaseTransactionCache

- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction {
    /** @ghidraAddress 0x70c28 */
    self = [super init];
    if (self) {
        self.productID = transaction.payment.productIdentifier;
        // The result of this comparison is discarded in the binary; it is a leftover system-version
        // gate that no longer influences the snapshot.
        (void)[UIDevice.currentDevice.systemVersion compare:kSystemVersionThreshold
                                                    options:NSNumericSearch];
        self.transactionID = transaction.transactionIdentifier;
        self.transactionDate = transaction.transactionDate;
    }
    return self;
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
