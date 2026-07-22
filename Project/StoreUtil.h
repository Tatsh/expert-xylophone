/** @file
 * In-app-purchase receipt signing helpers. Computes salted SHA-256 hex digests over the
 * receipt-check JSON payload so the server can authenticate the client's verification request.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class StoreUtil, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief Digest builders that sign the IAP receipt-verification request sent to the game server.
 */
@interface StoreUtil : NSObject

/**
 * @brief Compute the salted SHA-256 check digest for a receipt-verification payload.
 * @param jsonString The receipt-check JSON payload to sign.
 * @return A 64-character lowercase SHA-256 hex digest of the salt concatenated with @p jsonString.
 * @ghidraAddress 0x86484
 */
+ (NSString *)createReceiptCheckDigest:(NSString *)jsonString;

/**
 * @brief Compute the nonce-salted SHA-256 check digest for a receipt-verification payload.
 * @param jsonString The receipt-check JSON payload to sign.
 * @param nonce A caller-supplied nonce that provides replay protection.
 * @return A 64-character lowercase SHA-256 hex digest of the shared secret, @p nonce, and
 * @p jsonString concatenated in that order.
 * @ghidraAddress 0x8657c
 */
+ (NSString *)createReceiptCheckDigestV2:(NSString *)jsonString withNonce:(NSString *)nonce;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
