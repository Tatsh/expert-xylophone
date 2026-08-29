#import "BFCodec.h"

static const int kBlowfishPArrayCount = 18;

static const int kBlowfishSBoxCount = 4;

static const int kBlowfishSBoxSize = 256;

static const int kBlowfishBlockSize = 8;

static const int kBlowfishHalfSize = 4;

static const int kBlowfishIVLength = 8;

static const int kBlowfishTrailerLength = 8;

// The 64-bit build stores each Blowfish word as a 64-bit entry, so the context is 0x2090 bytes.
typedef struct {
    uint64_t P[kBlowfishPArrayCount];
    uint64_t S[kBlowfishSBoxCount][kBlowfishSBoxSize];
} BlowfishContext;

// @ghidraAddress 0x2ee7e8 (g_abBFInitPArray)
// @ghidraAddress 0x2ec7e8 (g_abBFInitSBox)
static const unsigned char kBlowfishInitBytes[] = {
#include "bf_init_bytes.inc"
};

// @ghidraAddress 0x2ec7e0 (g_abBFInitIV)
static const uint8_t kBlowfishInitialIV[kBlowfishIVLength] = {
    0xE3, 0x66, 0x31, 0xDA, 0x2C, 0x85, 0xA0, 0x64};

#pragma mark - Byte packing

static inline uint32_t blowfishPackBE32(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

static inline void blowfishStoreBE32(uint8_t *p, uint32_t value) {
    p[0] = (uint8_t)(value >> 24);
    p[1] = (uint8_t)(value >> 16);
    p[2] = (uint8_t)(value >> 8);
    p[3] = (uint8_t)value;
}

#pragma mark - Blowfish cipher core

// The round function deviates from textbook Blowfish, which computes
// ((S0[a] + S1[b]) ^ S2[c]) + S3[d].
// @ghidraAddress 0x15c50
static inline uint64_t BlowfishF(const BlowfishContext *ctx, uint64_t x) {
    uint64_t a = (x >> 24) & 0xff;
    uint64_t b = (x >> 16) & 0xff;
    uint64_t c = (x >> 8) & 0xff;
    uint64_t d = x & 0xff;
    return (ctx->S[0][a] + ctx->S[1][b]) ^ (ctx->S[2][c] + ctx->S[3][d]);
}

// @ghidraAddress 0x15c50
static void EncryptBlowfishBlock(const BlowfishContext *ctx, uint64_t *pLeft, uint64_t *pRight) {
    uint64_t left = *pLeft;
    uint64_t right = *pRight;
    for (int i = 0; i < kBlowfishPArrayCount - 2; i += 2) {
        left ^= ctx->P[i];
        right ^= BlowfishF(ctx, left);
        right ^= ctx->P[i + 1];
        left ^= BlowfishF(ctx, right);
    }
    left ^= ctx->P[kBlowfishPArrayCount - 2];
    right ^= ctx->P[kBlowfishPArrayCount - 1];
    *pLeft = right;
    *pRight = left;
}

// @ghidraAddress 0x15cc8
static void DecryptBlowfishBlock(const BlowfishContext *ctx, uint64_t *pLeft, uint64_t *pRight) {
    uint64_t left = *pLeft;
    uint64_t right = *pRight;
    for (int i = kBlowfishPArrayCount - 2; i >= 2; i -= 2) {
        left ^= ctx->P[i + 1];
        right ^= BlowfishF(ctx, left);
        right ^= ctx->P[i];
        left ^= BlowfishF(ctx, right);
    }
    left ^= ctx->P[1];
    right ^= ctx->P[0];
    *pLeft = right;
    *pRight = left;
}

// @ghidraAddress 0x15a68
// @ghidraAddress 0x15a80
// @ghidraAddress 0x15aa8
static inline void blowfishCtxClear(BlowfishContext *ctx) {
    memset(ctx, 0, sizeof(BlowfishContext));
}

// @ghidraAddress 0x15ad0
static void SetBlowfishKey(BlowfishContext *ctx, const char *key, NSUInteger length) {
    size_t index = 0;
    for (int i = 0; i < kBlowfishPArrayCount; ++i) {
        ctx->P[i] = blowfishPackBE32(&kBlowfishInitBytes[index]);
        index += kBlowfishHalfSize;
    }
    for (int box = 0; box < kBlowfishSBoxCount; ++box) {
        for (int i = 0; i < kBlowfishSBoxSize; ++i) {
            ctx->S[box][i] = blowfishPackBE32(&kBlowfishInitBytes[index]);
            index += kBlowfishHalfSize;
        }
    }

    int keyIndex = 0;
    for (int i = 0; i < kBlowfishPArrayCount; ++i) {
        const uint8_t b0 = (uint8_t)key[keyIndex % length];
        const uint8_t b1 = (uint8_t)key[(keyIndex + 1) % length];
        const uint8_t b2 = (uint8_t)key[(keyIndex + 2) % length];
        const uint8_t b3 = (uint8_t)key[(keyIndex + 3) % length];
        const uint32_t word =
            ((uint32_t)b0 << 24) | ((uint32_t)b1 << 16) | ((uint32_t)b2 << 8) | (uint32_t)b3;
        ctx->P[i] ^= word;
        keyIndex = (keyIndex + kBlowfishHalfSize) % length;
    }

    uint64_t left = 0;
    uint64_t right = 0;
    for (int i = 0; i < kBlowfishPArrayCount; i += 2) {
        EncryptBlowfishBlock(ctx, &left, &right);
        ctx->P[i] = left;
        ctx->P[i + 1] = right;
    }
    for (int box = 0; box < kBlowfishSBoxCount; ++box) {
        for (int i = 0; i < kBlowfishSBoxSize; i += 2) {
            EncryptBlowfishBlock(ctx, &left, &right);
            ctx->S[box][i] = left;
            ctx->S[box][i + 1] = right;
        }
    }
}

#pragma mark - BFCodec

@implementation BFCodec {
    uint8_t _iv[kBlowfishIVLength];
    BlowfishContext *_blf;
}

// @ghidraAddress 0x1529c
- (instancetype)init {
    if ((self = [super init])) {
        memset(_iv, 0, sizeof(_iv));
        // The binary uses operator new and delete, which are unavailable in a .m.
        _blf = (BlowfishContext *)malloc(sizeof(BlowfishContext));
        blowfishCtxClear(_blf);
    }
    return self;
}

// @ghidraAddress 0x159c8
- (void)dealloc {
    if (_blf) {
        blowfishCtxClear(_blf);
        free(_blf);
    }
}

// @ghidraAddress 0x153c0
- (void)cipherInit:(NSData *)key {
    if (key == nil) {
        return;
    }
    [self cipherInit:(const char *)key.bytes keyLength:key.length];
}

// @ghidraAddress 0x1534c
- (void)cipherInit:(const char *)key keyLength:(NSUInteger)length {
    blowfishCtxClear(_blf);
    memcpy(_iv, kBlowfishInitialIV, kBlowfishIVLength);
    SetBlowfishKey(_blf, key, length);
}

// @ghidraAddress 0x15450
- (unsigned long long)encipher:(NSMutableData *)data {
    const NSUInteger origLen = data.length;
    const NSUInteger cipherLen = (origLen + kBlowfishBlockSize + (kBlowfishBlockSize - 1)) &
                                 ~((NSUInteger)kBlowfishBlockSize - 1);
    data.length = cipherLen;
    uint8_t *bytes = (uint8_t *)data.mutableBytes;

    uint64_t chainLeft = blowfishPackBE32(&_iv[0]);
    uint64_t chainRight = blowfishPackBE32(&_iv[kBlowfishHalfSize]);

    NSUInteger in = 0;
    NSUInteger out = 0;
    while (in < origLen) {
        uint64_t left = 0;
        uint64_t right = 0;
        for (int k = 0; k < kBlowfishHalfSize; ++k) {
            left <<= 8;
            if (in < origLen) {
                left |= bytes[in++];
            }
        }
        for (int k = 0; k < kBlowfishHalfSize; ++k) {
            right <<= 8;
            if (in < origLen) {
                right |= bytes[in++];
            }
        }
        left ^= chainLeft;
        right ^= chainRight;
        EncryptBlowfishBlock(_blf, &left, &right);
        blowfishStoreBE32(&bytes[out], (uint32_t)left);
        blowfishStoreBE32(&bytes[out + kBlowfishHalfSize], (uint32_t)right);
        chainLeft = left;
        chainRight = right;
        out += kBlowfishBlockSize;
    }

    blowfishStoreBE32(&bytes[out], (uint32_t)origLen);
    const uint32_t paddedLen = (uint32_t)(origLen + (kBlowfishBlockSize - 1));
    bytes[out + kBlowfishHalfSize] = (uint8_t)(paddedLen >> 24);
    bytes[out + kBlowfishHalfSize + 1] = (uint8_t)(paddedLen >> 16);
    bytes[out + kBlowfishHalfSize + 2] = (uint8_t)(paddedLen >> 8);
    bytes[out + kBlowfishHalfSize + 3] = (uint8_t)(paddedLen & 0xf8);
    return cipherLen;
}

// @ghidraAddress 0x156f4
- (BOOL)decipher:(NSMutableData *)data {
    const NSUInteger len = data.length;
    if (len < kBlowfishTrailerLength) {
        return NO;
    }
    const NSUInteger body = len - kBlowfishTrailerLength;

    uint8_t trailer[kBlowfishHalfSize];
    [data getBytes:trailer range:NSMakeRange(body, kBlowfishHalfSize)];
    const uint32_t origLen = blowfishPackBE32(trailer);
    [data getBytes:trailer range:NSMakeRange(len - kBlowfishHalfSize, kBlowfishHalfSize)];
    const uint32_t cipherLen = blowfishPackBE32(trailer);

    const uint32_t expectedCipherLen =
        (origLen + (kBlowfishBlockSize - 1)) & ~((uint32_t)kBlowfishBlockSize - 1);
    if (cipherLen != body || cipherLen != expectedCipherLen) {
        return NO;
    }

    uint8_t *bytes = (uint8_t *)data.mutableBytes;
    uint64_t chainLeft = blowfishPackBE32(&_iv[0]);
    uint64_t chainRight = blowfishPackBE32(&_iv[kBlowfishHalfSize]);

    NSUInteger in = 0;
    NSUInteger out = 0;
    while (in < body) {
        uint64_t left = 0;
        uint64_t right = 0;
        for (int k = 0; k < kBlowfishHalfSize; ++k) {
            left <<= 8;
            if (in < body) {
                left |= bytes[in++];
            }
        }
        for (int k = 0; k < kBlowfishHalfSize; ++k) {
            right <<= 8;
            if (in < body) {
                right |= bytes[in++];
            }
        }
        const uint64_t cipherBlockLeft = left;
        const uint64_t cipherBlockRight = right;
        DecryptBlowfishBlock(_blf, &left, &right);
        left ^= chainLeft;
        right ^= chainRight;
        blowfishStoreBE32(&bytes[out], (uint32_t)left);
        blowfishStoreBE32(&bytes[out + kBlowfishHalfSize], (uint32_t)right);
        chainLeft = cipherBlockLeft;
        chainRight = cipherBlockRight;
        out += kBlowfishBlockSize;
    }

    data.length = origLen;
    return YES;
}

@end
