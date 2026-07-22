//
//  StoreUtil.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class StoreUtil). Verified against the
//  arm64 disassembly (the stringWithFormat: argument lists are variadic and dropped by the
//  decompiler, so their operand order was recovered from the register and stack setup).
//

#import "StoreUtil.h"

/// Source constant the receipt-check salt is carved out of; only a 27-character slice is used.
static NSString *const kReceiptSaltSource = @"2012 Konami Digital Entertainment";

/// The slice of @c kReceiptSaltSource used as the salt: 27 characters starting at index 2, giving
/// @c "12 Konami Digital Entertain".
static const NSUInteger kReceiptSaltLocation = 2;
static const NSUInteger kReceiptSaltLength = 27;

/// Shared secret folded into the V2 digest alongside the caller-supplied nonce.
static NSString *const kReceiptCheckSecretV2 = @"d0dc0448e6c701c9bcfb5358945f4ede";

/// Shared primitive that returns the lowercase SHA-256 hex digest of a NUL-terminated C string.
/// Ghidra: ComputeSha256HexString @ 0x17b0c (CommonCrypto @c CC_SHA256).
extern NSString *ComputeSha256HexString(const char *cString);

@implementation StoreUtil

+ (NSString *)createReceiptCheckDigest:(NSString *)jsonString {
    NSString *salt = [kReceiptSaltSource
        substringWithRange:NSMakeRange(kReceiptSaltLocation, kReceiptSaltLength)];
    NSString *seed = [NSString stringWithFormat:@"%@%@", salt, jsonString];
    return ComputeSha256HexString(seed.UTF8String);
}

+ (NSString *)createReceiptCheckDigestV2:(NSString *)jsonString withNonce:(NSString *)nonce {
    NSString *seed =
        [NSString stringWithFormat:@"%@%@%@", kReceiptCheckSecretV2, nonce, jsonString];
    return ComputeSha256HexString(seed.UTF8String);
}

@end
