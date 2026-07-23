/** @file
 * Reconstructed interface for the KONAMI Applilink SDK's @c Crypto helper.
 *
 * @c Crypto encrypts and decrypts the SDK's persisted payloads with AES-128 in ECB mode and PKCS#7
 * padding, using CommonCrypto, and derives the SHA-1 and SHA-256 hashes the SDK keys those payloads
 * and signs its requests by. The class is stateless: it has no instance state and exposes only class
 * methods. Reconstructed from Ghidra program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Symmetric-crypto helper for the Applilink SDK's persisted data.
 *
 * The helper wraps a single @c CCCrypt call: AES-128 (@c kCCAlgorithmAES128) with PKCS#7 padding
 * (@c kCCOptionPKCS7Padding) and no initialisation vector, which is ECB mode.
 */
@interface Crypto : NSObject

/**
 * @brief Encrypt or decrypt @p value under @p key with AES-128/ECB/PKCS#7.
 * @param mode The CommonCrypto operation: @c kCCEncrypt (0) to encrypt @p value, @c kCCDecrypt (1)
 * to decrypt it.
 * @param value The plaintext (when encrypting) or the ciphertext (when decrypting).
 * @param key The key data. Only the first 16 bytes are used as the AES-128 key.
 * @return The transformed data, or @c nil if the @c CCCrypt call fails.
 * @ghidraAddress 0x234c84
 */
+ (nullable NSData *)cryptorToData:(unsigned int)mode
                             value:(nullable NSData *)value
                               key:(nullable NSData *)key;

/**
 * @brief The SHA-1 digest of a string's UTF-8 bytes as a 40-character lowercase hexadecimal string.
 * @param string The string to hash.
 * @return The 40-character lowercase hexadecimal digest.
 * @ghidraAddress 0x23496c
 */
+ (nullable NSString *)sha1:(nullable NSString *)string;

/**
 * @brief The 20-byte SHA-1 digest of the input data.
 * @param inputData The data to hash.
 * @return The 20-byte SHA-1 digest.
 * @ghidraAddress 0x234894
 */
+ (nullable NSData *)createHash:(nullable NSData *)inputData;

/**
 * @brief The SHA-256 digest of a string's UTF-8 bytes as a 64-character lowercase hexadecimal
 * string.
 * @param string The string to hash.
 * @return The 64-character lowercase hexadecimal digest.
 * @ghidraAddress 0x234af8
 */
+ (nullable NSString *)sha256:(nullable NSString *)string;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
