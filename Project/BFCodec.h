/** @file
 * Blowfish-in-CBC codec used to encipher and decipher the game's on-disk save and music data.
 * This is textbook Blowfish with a single deviation in the round function (see @c BFCodec.m) run in
 * cipher-block-chaining mode with a fixed default IV and a self-describing length trailer.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class BFCodec, image base 0x100000000).
 * @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief Blowfish-CBC codec that enciphers and deciphers @c NSMutableData buffers in place.
 *
 * Usage is always: allocate, seed the key with @c -cipherInit: (or @c -cipherInit:keyLength:), then
 * call @c -encipher: or @c -decipher: on a mutable buffer.
 */
@interface BFCodec : NSObject

/**
 * @brief Seed the cipher from an @c NSData key.
 *
 * Convenience overload that forwards the key's raw bytes and byte length to
 * @c -cipherInit:keyLength:. Does nothing when @p key is nil.
 * @param key The Blowfish key material.
 * @ghidraAddress 0x153c0
 */
- (void)cipherInit:(NSData *)key;

/**
 * @brief Seed the cipher from a raw key buffer.
 *
 * Wipes the Blowfish context, copies the fixed default CBC IV into the @c _iv ivar, then runs the
 * Blowfish key schedule over @p key.
 * @param key The Blowfish key material.
 * @param length The length of @p key in bytes; the key is cycled modulo this length.
 * @ghidraAddress 0x1534c
 */
- (void)cipherInit:(const char *)key keyLength:(int)length;

/**
 * @brief Encipher a mutable buffer in place with Blowfish-CBC.
 *
 * Grows @p data to hold the padded ciphertext plus an 8-byte length trailer, then enciphers it in
 * place. The trailer records the original and padded lengths so @c -decipher: can validate and
 * trim.
 * @param data The plaintext buffer, replaced by the ciphertext and trailer.
 * @return The total ciphertext length including the 8-byte trailer.
 * @ghidraAddress 0x15450
 */
- (unsigned long long)encipher:(NSMutableData *)data;

/**
 * @brief Decipher a mutable buffer in place with Blowfish-CBC.
 *
 * Validates the length trailer, deciphers the body, then trims @p data back to the original
 * plaintext length.
 * @param data The ciphertext buffer (body plus trailer), replaced by the recovered plaintext.
 * @return @c YES on success, or @c NO when the length trailer is malformed.
 * @ghidraAddress 0x156f4
 */
- (BOOL)decipher:(NSMutableData *)data;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
