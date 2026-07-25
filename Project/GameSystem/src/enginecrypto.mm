//
//  enginecrypto.mm
//  REFLEC BEAT plus
//
//  The engine's MD5 and SHA-256 digest helpers. Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "enginecrypto.h"

#include <cstring>

// The digest byte counts and the hexadecimal capacities their strings pre-reserve.
namespace {
constexpr int kMd5HexCapacity = 0x20;    // 16 digest bytes rendered as two hex characters each.
constexpr int kSha256HexCapacity = 0x40; // 32 digest bytes rendered as two hex characters each.
} // namespace

/** @ghidraAddress 0x174dc */
void ComputeMd5Digest(const void *pData, CC_LONG dwLength, unsigned char *pDigest) {
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    CC_MD5_Update(&context, pData, dwLength);
    CC_MD5_Final(pDigest, &context);
}

/** @ghidraAddress 0x17534 */
NSData *Md5StringToData(const char *pString) {
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    ComputeMd5Digest(pString, static_cast<CC_LONG>(std::strlen(pString)), digest);
    return [NSData dataWithBytes:digest length:CC_MD5_DIGEST_LENGTH];
}

/** @ghidraAddress 0x175c8 */
NSString *Md5StringToHex(const char *pString) {
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    ComputeMd5Digest(pString, static_cast<CC_LONG>(std::strlen(pString)), digest);
    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:kMd5HexCapacity];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; ++i) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [NSString stringWithString:hex];
}

/** @ghidraAddress 0x17b0c */
NSString *ComputeSha256HexString(const char *cString) {
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, cString, static_cast<CC_LONG>(std::strlen(cString)));
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:kSha256HexCapacity];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [NSString stringWithString:hex];
}
