#import "Crypto.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

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

/** @ghidraAddress 0x234894 */
+ (NSData *)createHash:(NSData *)inputData {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH] = {0};
    CC_SHA1(inputData.bytes, (CC_LONG)inputData.length, digest);
    return [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}

/** @ghidraAddress 0x23496c */
+ (NSString *)sha1:(NSString *)string {
    // The digest is taken over the UTF-8 C string, but the byte count passed is the string's
    // -length (its character count, not the UTF-8 byte count) exactly as the binary does.
    NSData *data = [NSData dataWithBytes:[string cStringUsingEncoding:NSUTF8StringEncoding]
                                  length:string.length];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; ++i) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

/** @ghidraAddress 0x234af8 */
+ (NSString *)sha256:(NSString *)string {
    // As with -sha1:, the digest is taken over the UTF-8 C string but the byte count passed is the
    // string's -length (its character count, not the UTF-8 byte count) exactly as the binary does.
    NSData *data = [NSData dataWithBytes:[string cStringUsingEncoding:NSUTF8StringEncoding]
                                  length:string.length];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

@end
