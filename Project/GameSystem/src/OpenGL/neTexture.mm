#include "neTexture.h"

#include <cstring>
#include <new>

#import <UIKit/UIKit.h>

#import "UIImage+RB.h"
#import "deviceenvironment.h"
#include "neGLES.h"

namespace ne {

C_TEXTURE **g_ppTextureCacheHead = nullptr; // @ghidraAddress 0x3cff30

// @ghidraAddress 0x3cff28
int g_dwTotalTextureMemory = 0;

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
    m_flScale = 1.0f;
    m_fFlag60 = IsPad();
}

/**
 * @ghidraAddress 0x31a24
 * @ghidraAddress 0x31abc (the deleting-destructor thunk)
 */
C_TEXTURE::~C_TEXTURE() {
    g_dwTotalTextureMemory -= m_nByteSize;
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
        neGLESRenderer::GetShared()->DeleteTexture(m_nGLHandle);
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
    for (C_TEXTURE *pEntry = pSentinel->m_pPrev; pEntry != pSentinel; pEntry = pEntry->m_pPrev) {
        if (pEntry->m_pKeyName != nullptr && std::strcmp(pEntry->m_pKeyName, pszName) == 0) {
            pEntry->AddRef();
            return pEntry;
        }
    }

    // On a load failure the binary abandons the entry without freeing it.
    auto *pNewEntry = new C_TEXTURE();
    if (pNewEntry->LoadFromUIImage(pszName) == 0) {
        return nullptr;
    }

    pNewEntry->AddRef();
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
    g_ppTextureCacheHead = new C_TEXTURE *();
    auto *pSentinel = new C_TEXTURE();
    *g_ppTextureCacheHead = pSentinel;
    pSentinel->m_pPrev = pSentinel;
    pSentinel->m_pNext = pSentinel;
}

/** @ghidraAddress 0x33bf0 */
C_TEXTURE **C_TEXTURE::GetCacheList() {
    return g_ppTextureCacheHead;
}

/** @ghidraAddress 0x31af4 */
void C_TEXTURE::Release() {
    // The binary's null check here is redundant; it dereferences the object first.
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

    // CoreGraphics has a bottom-left origin, so the context is flipped for a top-left bitmap.
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

    // The tight 24-bit repack saves texture memory when the image has no alpha channel.
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

    neGLESRenderer *pRenderer = neGLESRenderer::GetShared();
    pRenderer->GenTexture(&m_nGLHandle);
    pRenderer->BindTexture2d(m_nGLHandle);

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

/** @ghidraAddress 0x31f80 */
int C_TEXTURE::SetDataAndUpload(int nWidth,
                                int nHeight,
                                int nFormat,
                                void *pData,
                                int nLogicalWidth,
                                int nLogicalHeight,
                                float flScale) {
    m_nImageWidth = nLogicalWidth;
    m_nImageHeight = nLogicalHeight;
    m_flScale = flScale;

    int nByteSize;
    if (nFormat == 2) {
        nByteSize = nWidth * nHeight * 3;
    } else if (nFormat == 3) {
        nByteSize = nWidth * nHeight;
    } else {
        nByteSize = nWidth * nHeight * 4;
    }
    m_nByteSize = nByteSize;
    g_dwTotalTextureMemory += nByteSize;

    InitializeTexture2d(nWidth, nHeight, nFormat, pData);
    return 1;
}

/** @ghidraAddress 0x33d3c */
C_TEXTURE *C_TEXTURE::CreateAndCache(int nWidth,
                                     int nHeight,
                                     int nFormat,
                                     void *pData,
                                     int nLogicalWidth,
                                     int nLogicalHeight,
                                     float flScale) {
    auto *pEntry = new C_TEXTURE();
    if (pEntry->SetDataAndUpload(
            nWidth, nHeight, nFormat, pData, nLogicalWidth, nLogicalHeight, flScale) == 0) {
        return nullptr;
    }

    pEntry->AddRef();
    C_TEXTURE *pSentinel = *g_ppTextureCacheHead;
    C_TEXTURE *pOldPrev = pSentinel->m_pPrev;
    pOldPrev->m_pNext = pEntry;
    pEntry->m_pPrev = pOldPrev;
    pEntry->m_pNext = pSentinel;
    pSentinel->m_pPrev = pEntry;
    return pEntry;
}

/** @ghidraAddress 0x31fe0 */
void C_TEXTURE::SetCachedTextureParameter(neGLESRenderer *pRenderer, int nIndex, int nValue) {
    if (m_aTexParams[nIndex] == nValue) {
        return;
    }
    pRenderer->SetTextureParameter(nIndex, nValue);
    m_aTexParams[nIndex] = nValue;
}

/** @ghidraAddress 0x32020 */
void C_TEXTURE::ReleaseGLHandle() {
    // Guarded by the source path so only reloadable entries drop their handle.
    if (m_pSourcePath != nullptr && m_nGLHandle != 0) {
        neGLESRenderer::GetShared()->DeleteTexture(m_nGLHandle);
        m_nGLHandle = 0;
    }
}

/** @ghidraAddress 0x3205c */
int C_TEXTURE::ReloadFromSourceName() {
    if (m_pSourcePath == nullptr) {
        return 1;
    }

    UIImage *image = [UIImage imageWithName:[NSString stringWithCString:m_pSourcePath
                                                               encoding:NSUTF8StringEncoding]];
    if (image == nil) {
        return 0;
    }

    CGImageRef cgImage = image.CGImage;
    m_nImageWidth = static_cast<int>(CGImageGetWidth(cgImage));
    m_nImageHeight = static_cast<int>(CGImageGetHeight(cgImage));

    int nPotWidth = 1;
    while (nPotWidth < m_nImageWidth) {
        nPotWidth <<= 1;
    }
    int nPotHeight = 1;
    while (nPotHeight < m_nImageHeight) {
        nPotHeight <<= 1;
    }

    // Unlike LoadFromUIImage this reload path does not re-record the content scale or source path.
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
    return 1;
}

/** @ghidraAddress 0x33e1c */
void C_TEXTURE::ReleaseAllHandles() {
    C_TEXTURE *pSentinel = *g_ppTextureCacheHead;
    for (C_TEXTURE *pEntry = pSentinel->m_pPrev; pEntry != pSentinel; pEntry = pEntry->m_pPrev) {
        pEntry->ReleaseGLHandle();
    }
}

/** @ghidraAddress 0x33e5c */
void C_TEXTURE::ReloadAll() {
    C_TEXTURE *pSentinel = *g_ppTextureCacheHead;
    for (C_TEXTURE *pEntry = pSentinel->m_pPrev; pEntry != pSentinel; pEntry = pEntry->m_pPrev) {
        pEntry->ReloadFromSourceName();
    }
}

} // namespace ne
