#import "Crypto.h"

#import <CommonCrypto/CommonCryptor.h>

// The AES block size, in bytes. The output buffer is over-allocated by one block so that PKCS#7
// padding added on encryption always fits.
static const NSUInteger kCryptoBlockPadding = kCCBlockSizeAES128;

// The Applilink SDK always keys AES-128 with exactly the first 16 bytes of the supplied key data,
// regardless of that data's actual length.
static const size_t kCryptoKeyLength = kCCKeySizeAES128;

@implementation Crypto

/** @ghidraAddress 0x234c84 */
+ (NSData *)cryptorToData:(unsigned int)mode value:(NSData *)value key:(NSData *)key {
    NSMutableData *output = [NSMutableData dataWithLength:value.length + kCryptoBlockPadding];
    size_t moved = 0;
    // No initialisation vector is supplied, so CommonCrypto runs in ECB mode. The key length is
    // fixed at 16 bytes and the SDK's mode value is used directly as the CommonCrypto operation
    // (kCCEncrypt/kCCDecrypt).
    CCCryptorStatus status = CCCrypt(mode,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kCryptoKeyLength,
                                     NULL,
                                     value.bytes,
                                     value.length,
                                     output.mutableBytes,
                                     output.length,
                                     &moved);
    if (status != kCCSuccess) {
        return nil;
    }
    return [NSData dataWithBytes:output.bytes length:moved];
}

@end
