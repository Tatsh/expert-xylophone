// The binary's source file is neGLES.cpp (pure C++). It is reconstructed here as an Objective-C++
// translation unit because neGLESRenderer is declared in the Foundation-importing engine bridge;
// once neGLESRenderer is extracted into its own pure-C++ header this becomes neGLES.cpp.

#include <cassert>

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

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

// The framebuffer attachment points are spaced 0x20 apart starting at the colour attachment, and
// there are three of them (colour, depth, stencil).
constexpr int kRenderKindAttachmentStride = 0x20;
constexpr int kRenderKindMax = 3;

// Maps a render-kind to its GL framebuffer attachment enum, computed inline as the binary does.
int RenderKindToGLRenderKind(RenderKind nRenderKind) {
    assert(nRenderKind >= 0 && nRenderKind < kRenderKindMax);
    return GL_COLOR_ATTACHMENT0_OES + static_cast<int>(nRenderKind) * kRenderKindAttachmentStride;
}

// Maps an engine primitive index (0..6) to its GL ES draw mode.
constexpr GLenum kPrimitiveToGlMode[] = {
    GL_POINTS,         //
    GL_LINE_STRIP,     //
    GL_LINE_LOOP,      //
    GL_LINES,          //
    GL_TRIANGLE_STRIP, //
    GL_TRIANGLE_FAN,   //
    GL_TRIANGLES,      //
};

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

/** @ghidraAddress 0x21400 */
void neGLESRenderer::ClearBuffers(unsigned int dwMask) {
    glClear(dwMask);
}

/** @ghidraAddress 0x212ac */
void neGLESRenderer::GenFramebuffer(unsigned int *pOutFramebuffer) {
    glGenFramebuffersOES(1, pOutFramebuffer);
}

/** @ghidraAddress 0x212b4 */
void neGLESRenderer::DeleteFramebuffer(unsigned int dwFramebuffer) {
    glDeleteFramebuffersOES(1, &dwFramebuffer);
}

/** @ghidraAddress 0x212dc */
void neGLESRenderer::BindFramebuffer(unsigned int dwFramebuffer) {
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, dwFramebuffer);
}

/** @ghidraAddress 0x212e4 */
void neGLESRenderer::GenRenderbuffer(unsigned int *pOutRenderbuffer) {
    glGenRenderbuffersOES(1, pOutRenderbuffer);
}

/** @ghidraAddress 0x212ec */
void neGLESRenderer::DeleteRenderbuffer(unsigned int dwRenderbuffer) {
    glDeleteRenderbuffersOES(1, &dwRenderbuffer);
}

/** @ghidraAddress 0x21314 */
void neGLESRenderer::BindRenderbuffer(unsigned int dwRenderbuffer) {
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, dwRenderbuffer);
}

/** @ghidraAddress 0x213d8 */
void neGLESRenderer::GetRenderbufferWidth(int *pOutWidth) {
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, pOutWidth);
}

/** @ghidraAddress 0x213ec */
void neGLESRenderer::GetRenderbufferHeight(int *pOutHeight) {
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, pOutHeight);
}

/** @ghidraAddress 0x21380 */
void neGLESRenderer::AttachRenderbufferToFramebuffer(RenderKind nRenderKind,
                                                     unsigned int dwRenderbuffer) {
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES,
                                 RenderKindToGLRenderKind(nRenderKind),
                                 GL_RENDERBUFFER_OES,
                                 dwRenderbuffer);
}

/** @ghidraAddress 0x212a4 */
unsigned int GetGLRenderbufferTarget() {
    return GL_RENDERBUFFER_OES;
}

/** @ghidraAddress 0x21ea8 */
void neGLESRenderer::DrawIndexedPrimitives(int nPrimitive, int nCount, const void *pIndices) {
    // An out-of-range primitive index maps to GL_POINTS, matching the binary's default.
    const GLenum glMode = (static_cast<unsigned int>(nPrimitive) <
                           sizeof(kPrimitiveToGlMode) / sizeof(kPrimitiveToGlMode[0])) ?
                              kPrimitiveToGlMode[nPrimitive] :
                              GL_POINTS;
    glDrawElements(glMode, nCount, GL_UNSIGNED_SHORT, pIndices);
}
