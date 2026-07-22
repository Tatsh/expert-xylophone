/** @file
 * A lightweight per-transaction receipt cache. It snapshots the product identifier, transaction
 * identifier, and transaction date of a StoreKit payment transaction so that the purchase manager
 * can carry them through the asynchronous server-side receipt verification, and it holds the
 * receipt data and the response digest gathered during that verification.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class PurchaseTransactionCache, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A snapshot of a single StoreKit payment transaction used during receipt verification.
 */
@interface PurchaseTransactionCache : NSObject

/**
 * @brief The identifier of the purchased product.
 * @ghidraAddress 0x70e70 (getter)
 * @ghidraAddress 0x70e80 (setter)
 */
@property(nonatomic, strong, nullable) NSString *productID;

/**
 * @brief The App Store receipt data captured for verification.
 * @ghidraAddress 0x70eb8 (getter)
 * @ghidraAddress 0x70ec8 (setter)
 */
@property(nonatomic, strong, nullable) NSData *receiptData;

/**
 * @brief The StoreKit transaction identifier.
 * @ghidraAddress 0x70f00 (getter)
 * @ghidraAddress 0x70f10 (setter)
 */
@property(nonatomic, strong, nullable) NSString *transactionID;

/**
 * @brief The date the transaction was added to the payment queue.
 * @ghidraAddress 0x70f48 (getter)
 * @ghidraAddress 0x70f58 (setter)
 */
@property(nonatomic, strong, nullable) NSDate *transactionDate;

/**
 * @brief The digest computed from the verification response.
 * @ghidraAddress 0x70f90 (getter)
 * @ghidraAddress 0x70fa0 (setter)
 */
@property(nonatomic, strong, nullable) NSString *digestString;

/**
 * @brief Build a cache from a StoreKit payment transaction.
 *
 * Snapshots the product identifier of the transaction's payment, its transaction identifier, and
 * its transaction date.
 * @param transaction The payment transaction to snapshot.
 * @return The initialised instance.
 * @ghidraAddress 0x70c28
 */
- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
