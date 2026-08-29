#import "PurchaseTransactionCache.h"

#import <UIKit/UIKit.h>

// @ghidraAddress 0x36bb00
static NSString *const kSystemVersionThreshold = @"7.0";

@implementation PurchaseTransactionCache

- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction {
    /** @ghidraAddress 0x70c28 */
    self = [super init];
    if (self) {
        self.productID = transaction.payment.productIdentifier;
        // Yes, the binary discards this comparison's result.
        (void)[UIDevice.currentDevice.systemVersion compare:kSystemVersionThreshold
                                                    options:NSNumericSearch];
        self.transactionID = transaction.transactionIdentifier;
        self.transactionDate = transaction.transactionDate;
    }
    return self;
}

@end
