/**
 * @file
 * The engine's MD5 and SHA-256 digest helpers.
 */

#pragma once

#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Builds the MD5 digest of a C string and returns it as data.
 * @ghidraAddress 0x17534
 */
NSData *Md5StringToData(const char *pString);
/**
 * @brief Computes the MD5 digest of a C string and returns it as a 32-character lowercase
 *        hexadecimal string.
 * @ghidraAddress 0x175c8
 */
NSString *Md5StringToHex(const char *pString);
/**
 * @brief Computes the MD5 digest of a buffer into a 16-byte output.
 * @ghidraAddress 0x174dc
 */
void ComputeMd5Digest(const void *pData, CC_LONG dwLength, unsigned char *pDigest);
/**
 * @brief Computes the SHA-256 of a C string and returns it as a lowercase hexadecimal string.
 * @ghidraAddress 0x17b0c
 */
NSString *ComputeSha256HexString(const char *cString);

#ifdef __cplusplus
}
#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
