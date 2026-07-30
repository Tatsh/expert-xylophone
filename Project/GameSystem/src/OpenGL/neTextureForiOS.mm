#import "neTextureForiOS.h"

#import <UIKit/UIKit.h>

#include "neTexture.h"

// The pixel formats ne::C_TEXTURE::CreateAndCache accepts.
enum {
    kTexturePixelFormatRgba = 1,
    kTexturePixelFormatRgb = 2,
};

// The bitmap context is always built as 8-bit-per-component RGBA, four bytes per texel; the tight
// repack drops the alpha byte and leaves three.
constexpr int kBitsPerComponent = 8;
constexpr int kRgbaBytesPerTexel = 4;
constexpr int kRgbBytesPerTexel = 3;

@implementation neTextureForiOS

+ (ne::C_TEXTURE *)LoadTexture:(NSData *)pData Scale:(float)flScale {
    UIImage *image = [[UIImage alloc] initWithData:pData];
    if (image == nil) {
        return nullptr;
    }

    CGImageRef cgImage = image.CGImage;
    const int nImageWidth = static_cast<int>(CGImageGetWidth(cgImage));
    const int nImageHeight = static_cast<int>(CGImageGetHeight(cgImage));

    // GL ES 1.x requires power-of-two texture dimensions.
    int nPotWidth = 1;
    while (nPotWidth < nImageWidth) {
        nPotWidth <<= 1;
    }
    int nPotHeight = 1;
    while (nPotHeight < nImageHeight) {
        nPotHeight <<= 1;
    }

    // Draw the image into a zeroed RGBA8888 bitmap. CoreGraphics uses a bottom-left origin, so the
    // context is flipped vertically before the image is drawn at its original size into the
    // (larger) power-of-two buffer. The flip translates by the image height rather than the
    // allocated height, which is what leaves the drawn region at the bottom of the allocation.
    const CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgImage);
    const int nRgbaStride = nPotWidth * kRgbaBytesPerTexel;
    auto *pRgbaBuffer = new unsigned char[nPotHeight * nRgbaStride]();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pRgbaBuffer,
                                                 static_cast<size_t>(nPotWidth),
                                                 static_cast<size_t>(nPotHeight),
                                                 kBitsPerComponent,
                                                 static_cast<size_t>(nRgbaStride),
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(context, 0, nImageHeight);
    CGContextScaleCTM(context, 1, -1);
    CGContextDrawImage(context, CGRectMake(0, 0, nImageWidth, nImageHeight), cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    // Upload RGBA when the image has an alpha channel; otherwise repack to tight 24-bit RGB to save
    // texture memory.
    unsigned char *pUploadData;
    int nFormat;
    if (alphaInfo >= kCGImageAlphaPremultipliedLast && alphaInfo <= kCGImageAlphaFirst) {
        pUploadData = pRgbaBuffer;
        nFormat = kTexturePixelFormatRgba;
    } else {
        const int nRgbStride = nPotWidth * kRgbBytesPerTexel;
        auto *pRgbBuffer = new unsigned char[nPotHeight * nRgbStride];
        for (int y = 0; y < nPotHeight; ++y) {
            const unsigned char *pSrcRow = pRgbaBuffer + y * nRgbaStride;
            unsigned char *pDstRow = pRgbBuffer + y * nRgbStride;
            for (int x = 0; x < nPotWidth; ++x) {
                pDstRow[x * kRgbBytesPerTexel + 0] = pSrcRow[x * kRgbaBytesPerTexel + 0];
                pDstRow[x * kRgbBytesPerTexel + 1] = pSrcRow[x * kRgbaBytesPerTexel + 1];
                pDstRow[x * kRgbBytesPerTexel + 2] = pSrcRow[x * kRgbaBytesPerTexel + 2];
            }
        }
        delete[] pRgbaBuffer;
        pUploadData = pRgbBuffer;
        nFormat = kTexturePixelFormatRgb;
    }

    // The cached texture comes back with one reference, which the caller owns and later drops
    // through Release; the decoded pixels are copied into GL and freed here.
    ne::C_TEXTURE *pTexture = ne::C_TEXTURE::CreateAndCache(
        nPotWidth, nPotHeight, nFormat, pUploadData, nImageWidth, nImageHeight, flScale);
    delete[] pUploadData;
    return pTexture;
}

@end
