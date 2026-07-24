// The binary's source file is neGLES.cpp (pure C++). It is reconstructed here as an Objective-C++
// translation unit because neGLESRenderer is declared in the Foundation-importing engine bridge;
// once neGLESRenderer is extracted into its own pure-C++ header this becomes neGLES.cpp.

#include <cassert>

#import <OpenGLES/ES1/gl.h>

#import "neEngineBridge.h"

namespace {

// Engine texture formats. Format 0 is the compressed sentinel, which the uploader rejects; 1..3
// are the uncompressed formats mapped below.
enum {
    kTexFormatCompressed = 0,
    kTexFormatMax = 4,
};

// Maps an engine texture format (1..3) to its unsized GL ES 1.1 pixel format.
constexpr GLenum kEngineFormatToGl[] = {GL_RGBA, GL_RGB, GL_LUMINANCE_ALPHA};

} // namespace

/** @ghidraAddress 0x21a60 */
void neGLESRenderer::GenTexture(unsigned int *pOutHandle) {
    glGenTextures(1, pOutHandle);
}

/** @ghidraAddress 0x2147c */
void neGLESRenderer::GenBuffer(unsigned int *pOutBuffer) {
    glGenBuffers(1, pOutBuffer);
}

/** @ghidraAddress 0x21bd0 */
void neGLESRenderer::UploadTexture2d(int nFormat, int nWidth, int nHeight, const void *pData) {
    // The binary asserts the format is in range and not the compressed sentinel before mapping it.
    assert(nFormat > kTexFormatCompressed && nFormat < kTexFormatMax);
    const GLenum glFormat = kEngineFormatToGl[nFormat - 1];
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 static_cast<GLint>(glFormat),
                 nWidth,
                 nHeight,
                 0,
                 glFormat,
                 GL_UNSIGNED_BYTE,
                 pData);
}
