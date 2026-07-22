/** @file
 * StoreKit in-app-purchase manager. Wraps @c SKPaymentQueue to buy and restore products, tracks the
 * set of owned product identifiers, and verifies each purchase or restore against the game server
 * before the entitlement is granted.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBPurchaseManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import "Downloader.h"

@class RBPurchaseManager;

/**
 * @brief Optional callbacks the purchase manager sends to its delegate as a purchase or restore
 * progresses.
 *
 * Every method is optional; the manager guards each call with @c -respondsToSelector: .
 */
@protocol RBPurchaseManagerDelegate <NSObject>

@optional

/**
 * @brief Sent when a purchase has been bought and verified by the server.
 * @param productID The product identifier that was purchased.
 */
- (void)purchaseSucceeded:(NSString *)productID;

/**
 * @brief Sent when a purchase failed at any stage (the queue, verification, or download).
 * @param productID The product identifier that failed, or @c nil when none is known.
 * @param error The failure reason.
 */
- (void)purchaseFailed:(NSString *)productID error:(NSError *)error;

/**
 * @brief Sent when every restored transaction has been verified and granted.
 */
- (void)restoreSucceeded;

/**
 * @brief Sent when a restore completed but there was nothing to restore.
 */
- (void)restoreNothing;

/**
 * @brief Sent when a restore failed.
 * @param error The failure reason.
 */
- (void)restoreFailed:(NSError *)error;

@end

/**
 * @brief Singleton that drives StoreKit purchases and restores and verifies their receipts.
 */
@interface RBPurchaseManager
    : NSObject <SKPaymentTransactionObserver, SKRequestDelegate, DownloaderDelegate>

/**
 * @brief The delegate that receives purchase and restore progress callbacks.
 */
@property(nonatomic, weak) id<RBPurchaseManagerDelegate> delegate;

/**
 * @brief The product identifiers the user owns.
 */
@property(nonatomic, strong) NSMutableArray *purchasedProducts;

/**
 * @brief Transactions queued for server-side receipt verification.
 */
@property(nonatomic, strong) NSMutableArray *purchaseCheckTransactions;

/**
 * @brief Product identifiers whose purchase has been checked during the current flow.
 */
@property(nonatomic, strong) NSMutableArray *purchaseCheckedProductsIn;

/**
 * @brief Restored transactions still awaiting verification.
 */
@property(nonatomic, strong) NSMutableArray *restoredTransactions;

/**
 * @brief The in-flight receipt-verification request, if any.
 */
@property(nonatomic, strong) Downloader *downloader;

/**
 * @brief Whether a purchase or restore flow is currently in progress.
 */
@property(nonatomic, assign) BOOL transactioing;

/**
 * @brief Whether the current flow is a restore rather than a purchase.
 */
@property(nonatomic, assign) BOOL isRestored;

/**
 * @brief Product identifiers gathered from the transactions of the current flow.
 */
@property(nonatomic, strong) NSMutableArray *productIds;

/**
 * @brief The nonce carried through the current receipt-verification request for replay protection.
 */
@property(nonatomic, strong) NSString *nonce;

/**
 * @brief The shared purchase manager.
 * @return The lazily created singleton instance.
 * @ghidraAddress 0x6d260
 */
+ (instancetype)sharedManager;

/**
 * @brief Whether the device is allowed to make payments.
 * @return @c YES when @c SKPaymentQueue reports that payments can be made.
 * @ghidraAddress 0x6d4d0
 */
+ (BOOL)isPurchasable;

/**
 * @brief Begin observing the payment queue for transaction updates.
 * @ghidraAddress 0x6d5ac
 */
- (void)start;

/**
 * @brief Stop observing the payment queue.
 * @ghidraAddress 0x6d610
 */
- (void)end;

/**
 * @brief Persist the owned product identifiers to encrypted local storage.
 * @ghidraAddress 0x6d674
 */
- (void)saveProductList;

/**
 * @brief Load the owned product identifiers from encrypted local storage.
 * @ghidraAddress 0x6d8e8
 */
- (void)loadProductList;

/**
 * @brief Whether the given product identifier is already owned.
 * @param productID The product identifier to test.
 * @return @c YES when @p productID is in the owned set.
 * @ghidraAddress 0x6dc30
 */
- (BOOL)isPurchased:(NSString *)productID;

/**
 * @brief Start buying the given product.
 * @param product The product to buy.
 * @return @c YES when a payment was queued, @c NO when the purchase could not be started.
 * @ghidraAddress 0x6dcc8
 */
- (BOOL)beginPurchase:(SKProduct *)product;

/**
 * @brief Start restoring previously bought products.
 * @return @c YES when a restore was started, @c NO when it could not be started.
 * @ghidraAddress 0x6de88
 */
- (BOOL)beginRestore;

/**
 * @brief The product identifiers checked during the current flow.
 * @return The purchase-checked product list.
 * @ghidraAddress 0x6e024
 */
- (NSMutableArray *)purchaseCheckedProducts;

/**
 * @brief Remove a product identifier from the purchase-checked list.
 * @param productID The product identifier to remove.
 * @ghidraAddress 0x6e030
 */
- (void)removePurchaseCheckedProduct:(NSString *)productID;

/**
 * @brief Empty the purchase-checked list.
 * @ghidraAddress 0x6e0bc
 */
- (void)clearPurchaseCheckedProducts;

/**
 * @brief Add a product identifier to the owned set, optionally persisting it.
 * @param productID The product identifier to add.
 * @param save Whether to persist the owned set afterwards.
 * @return @c YES when the identifier was newly added, @c NO when it was already owned.
 * @ghidraAddress 0x6e110
 */
- (BOOL)addProductID:(NSString *)productID Save:(BOOL)save;

/**
 * @brief Add every purchase-checked product to the owned set and persist it.
 * @ghidraAddress 0x6e21c
 */
- (void)addProductFromPurchaseCheckedProducts;

/**
 * @brief Queue a transaction for server-side receipt verification.
 * @param transaction The cached transaction to verify.
 * @return @c YES when the transaction was queued, @c NO when it was already owned or was @c nil.
 * @ghidraAddress 0x6e370
 */
- (BOOL)addPurchaseCheckTransaction:(id)transaction;

/**
 * @brief Send the next queued receipt to the server for verification.
 * @return @c YES when a verification request was started.
 * @ghidraAddress 0x6e468
 */
- (BOOL)checkNextReceipt;

/**
 * @brief Base64-encode the bytes of the given data.
 * @param data The data to encode.
 * @return The Base64 string.
 * @ghidraAddress 0x6f3b8
 */
+ (NSString *)encodedStringWithBase64:(NSData *)data;

/**
 * @brief Base64-encode the bytes of the given data using the padded variant.
 * @param data The data to encode.
 * @return The Base64 string.
 * @ghidraAddress 0x6f544
 */
+ (NSString *)encodedStringWithBase64V2:(NSData *)data;

/**
 * @brief Base64-decode the given string.
 * @param string The Base64 string to decode.
 * @return The decoded data.
 * @ghidraAddress 0x6f784
 */
+ (NSData *)decodedStringWithBase64:(NSString *)string;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
