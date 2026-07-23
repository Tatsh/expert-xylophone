/** @file
 * Minimal reconstructed interface for the Applilink SDK's @c Crypto helper.
 *
 * @c Crypto encrypts and decrypts the SDK's persisted payloads. Only the single entry point the
 * reconstructed sources message is declared here. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Symmetric encryption helper for the Applilink SDK's persisted data.
 */
@interface Crypto : NSObject

/**
 * @brief Encrypt or decrypt @p value under @p key.
 * @param mode @c 0 to encrypt @p value, @c 1 to decrypt it.
 * @param value The plaintext (when encrypting) or ciphertext (when decrypting).
 * @param key The key data.
 * @return The transformed data.
 * @ghidraAddress 0x234c84
 */
+ (nullable NSData *)cryptorToData:(unsigned int)mode
                             value:(nullable NSData *)value
                               key:(nullable NSData *)key;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
