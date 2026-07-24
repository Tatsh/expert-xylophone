#include "neTexture.h"

#include <cstring>
#include <new>

#import <UIKit/UIKit.h>

#import "UIImage+RB.h"
#import "deviceenvironment.h"
#include "neGLES.h"

namespace ne {

// The texture cache's circular-list head-holder, created lazily by EnsureCacheList.
C_TEXTURE **g_ppTextureCacheHead = nullptr; // @ghidraAddress 0x3cff30

// Sampler-parameter indices and the default values a freshly created texture is given.
enum {
    kTexParamMinFilter = 0,
    kTexParamMagFilter = 1,
    kTexParamWrapS = 2,
    kTexParamWrapT = 3,
};
constexpr int kTexWrapRepeat = 7;
constexpr int kTexFilterNearest = 0;

/** @ghidraAddress 0x319d0 */
C_TEXTURE::C_TEXTURE() {
    // Every other field is zeroed by its in-class initialiser; the scale defaults to 1 and the flag
    // records whether the device is an iPad.
    m_flScale = 1.0f;
    m_fFlag60 = IsPad();
}

/** @ghidraAddress 0x31a24 */
C_TEXTURE::~C_TEXTURE() {
    g_dwTotalTextureMemory -= m_nByteSize;
    // Splice the entry out of the cache list when both links are set.
    if (m_pPrev != nullptr && m_pNext != nullptr) {
        m_pPrev->m_pNext = m_pNext;
        m_pNext->m_pPrev = m_pPrev;
    }
    if (m_pKeyName != nullptr) {
        delete[] m_pKeyName;
        m_pKeyName = nullptr;
    }
    if (m_pSourcePath != nullptr) {
        delete[] m_pSourcePath;
        m_pSourcePath = nullptr;
    }
    if (m_nGLHandle != 0) {
        GetGlRenderer()->DeleteTexture(m_nGLHandle);
    }
}

/** @ghidraAddress 0x31b18 */
void C_TEXTURE::SetSourcePath(const char *pszPath) {
    if (m_pSourcePath != nullptr) {
        delete[] m_pSourcePath;
        m_pSourcePath = nullptr;
    }
    m_pSourcePath = new char[std::strlen(pszPath) + 1];
    std::strcpy(m_pSourcePath, pszPath);
}

/** @ghidraAddress 0x33c78 */
C_TEXTURE *C_TEXTURE::FindOrLoadCached(const char *pszName) {
    C_TEXTURE *pSentinel = *g_ppTextureCacheHead;
    // Walk the circular cache list; a key match bumps the reference count and returns the entry.
    for (C_TEXTURE *pEntry = pSentinel->m_pPrev; pEntry != pSentinel; pEntry = pEntry->m_pPrev) {
        if (pEntry->m_pKeyName != nullptr && std::strcmp(pEntry->m_pKeyName, pszName) == 0) {
            pEntry->AddRef();
            return pEntry;
        }
    }

    // Not cached: construct a new entry and load the image. On a load failure the binary abandons
    // the entry without freeing it; that is reproduced here.
    auto *pNewEntry = new C_TEXTURE();
    if (pNewEntry->LoadFromUIImage(pszName) == 0) {
        return nullptr;
    }

    pNewEntry->AddRef();
    // Splice the new entry in right after the sentinel, at the head of the live list.
    C_TEXTURE *pOldPrev = pSentinel->m_pPrev;
    pOldPrev->m_pNext = pNewEntry;
    pNewEntry->m_pPrev = pOldPrev;
    pNewEntry->m_pNext = pSentinel;
    pSentinel->m_pPrev = pNewEntry;
    return pNewEntry;
}

/** @ghidraAddress 0x33bfc */
void C_TEXTURE::EnsureCacheList() {
    if (g_ppTextureCacheHead != nullptr) {
        return;
    }
    // Value-initialisation zeroes the head cell (the binary stores a null there before the sentinel
    // is ready); the sentinel is then a self-linked one-element circular list.
    g_ppTextureCacheHead = new C_TEXTURE *();
    auto *pSentinel = new C_TEXTURE();
    *g_ppTextureCacheHead = pSentinel;
    pSentinel->m_pPrev = pSentinel;
    pSentinel->m_pNext = pSentinel;
}

/** @ghidraAddress 0x31af4 */
void C_TEXTURE::Release() {
    // Decrement the reference count and destroy the object once it reaches zero. The binary
    // dereferences the object before its now-redundant null check, so callers pass a live object;
    // delete dispatches the same virtual destructor the binary tail-calls through the vtable.
    if (ReleaseRef() == 0) {
        delete this;
    }
}

/** @ghidraAddress 0x31b60 */
int C_TEXTURE::LoadFromUIImage(const char *pszName) {
    UIImage *image = [UIImage imageWithName:[NSString stringWithUTF8String:pszName]];
    if (image == nil) {
        return 0;
    }
    if ([image respondsToSelector:@selector(scale)]) {
        m_flScale = static_cast<float>(image.scale);
    }
    SetSourcePath(pszName);

    CGImageRef cgImage = image.CGImage;
    m_nImageWidth = static_cast<int>(CGImageGetWidth(cgImage));
    m_nImageHeight = static_cast<int>(CGImageGetHeight(cgImage));

    // GL ES 1.x requires power-of-two texture dimensions.
    int nPotWidth = 1;
    while (nPotWidth < m_nImageWidth) {
        nPotWidth <<= 1;
    }
    int nPotHeight = 1;
    while (nPotHeight < m_nImageHeight) {
        nPotHeight <<= 1;
    }

    // Draw the image into a zeroed, top-left-origin RGBA8888 bitmap. CoreGraphics uses a
    // bottom-left origin, so the context is flipped vertically before the image is drawn at its
    // original size into the top-left of the (larger) power-of-two buffer.
    const CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgImage);
    const int nRgbaStride = nPotWidth * 4;
    m_nByteSize = nPotHeight * nRgbaStride;
    auto *pRgbaBuffer = new unsigned char[m_nByteSize]();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pRgbaBuffer,
                                                 static_cast<size_t>(nPotWidth),
                                                 static_cast<size_t>(nPotHeight),
                                                 8,
                                                 static_cast<size_t>(nRgbaStride),
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(context, 0, m_nImageHeight);
    CGContextScaleCTM(context, 1, -1);
    CGContextDrawImage(context, CGRectMake(0, 0, m_nImageWidth, m_nImageHeight), cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    // Upload RGBA (format 1) when the image has an alpha channel; otherwise repack to tight 24-bit
    // RGB (format 2) to save texture memory.
    unsigned char *pUploadData;
    int nFormat;
    if (alphaInfo >= kCGImageAlphaPremultipliedLast && alphaInfo <= kCGImageAlphaFirst) {
        pUploadData = pRgbaBuffer;
        nFormat = 1;
    } else {
        m_nByteSize = nPotWidth * nPotHeight * 3;
        auto *pRgbBuffer = new unsigned char[m_nByteSize];
        for (int y = 0; y < nPotHeight; ++y) {
            const unsigned char *pSrcRow = pRgbaBuffer + y * nRgbaStride;
            unsigned char *pDstRow = pRgbBuffer + y * (nPotWidth * 3);
            for (int x = 0; x < nPotWidth; ++x) {
                pDstRow[x * 3 + 0] = pSrcRow[x * 4 + 0];
                pDstRow[x * 3 + 1] = pSrcRow[x * 4 + 1];
                pDstRow[x * 3 + 2] = pSrcRow[x * 4 + 2];
            }
        }
        delete[] pRgbaBuffer;
        pUploadData = pRgbBuffer;
        nFormat = 2;
    }

    InitializeTexture2d(nPotWidth, nPotHeight, nFormat, pUploadData);
    delete[] pUploadData;
    g_dwTotalTextureMemory += m_nByteSize;

    m_pKeyName = new char[std::strlen(pszName) + 1];
    std::strcpy(m_pKeyName, pszName);
    return 1;
}

/** @ghidraAddress 0x31eb0 */
void C_TEXTURE::InitializeTexture2d(int nWidth, int nHeight, int nFormat, void *pData) {
    m_nAllocWidth = nWidth;
    m_nAllocHeight = nHeight;
    m_nFormat = nFormat;

    neGLESRenderer *pRenderer = GetGlRenderer();
    pRenderer->GenTexture(&m_nGLHandle);
    pRenderer->BindTexture2d(m_nGLHandle);

    // Give the new texture the default sampler state: repeat wrap on both axes, nearest filtering.
    pRenderer->SetTextureParameter(kTexParamWrapS, kTexWrapRepeat);
    pRenderer->SetTextureParameter(kTexParamWrapT, kTexWrapRepeat);
    pRenderer->SetTextureParameter(kTexParamMinFilter, kTexFilterNearest);
    pRenderer->SetTextureParameter(kTexParamMagFilter, kTexFilterNearest);
    m_aTexParams[kTexParamMinFilter] = kTexFilterNearest;
    m_aTexParams[kTexParamMagFilter] = kTexFilterNearest;
    m_aTexParams[kTexParamWrapS] = kTexWrapRepeat;
    m_aTexParams[kTexParamWrapT] = kTexWrapRepeat;

    pRenderer->UploadTexture2d(nFormat, nWidth, nHeight, pData);
}

} // namespace ne
