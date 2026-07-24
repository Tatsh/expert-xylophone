#include "neGLES.h"

#include <cassert>

#include <OpenGLES/ES1/gl.h>
#include <OpenGLES/ES1/glext.h>

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

// The number of engine render capabilities (neIGLES::ES_MAX) and vertex-array client states
// (neIGLES::CS_MAX). They bound the enable- and client-state indices the setters accept.
constexpr int kEnableStateMax = 0x24;
constexpr int kClientStateMax = 7;

// The number of engine blend factors (neIGLES::BLEND_SRC_VALUE_MAX / BLEND_DEST_VALUE_MAX). The
// source table has one extra factor (the destination cannot be a source-only factor).
constexpr int kBlendSrcMax = 9;
constexpr int kBlendDestMax = 8;

// Maps an engine enable-state index to its GL capability. The last slot has no GL ES 1.1 name; it
// is a table entry the engine never enables, kept so the index mapping matches the binary.
constexpr GLenum kEnableStateToGlCap[] = {
    GL_ALPHA_TEST,               // 0
    GL_BLEND,                    // 1
    GL_COLOR_LOGIC_OP,           // 2
    GL_CLIP_PLANE0,              // 3
    GL_CLIP_PLANE1,              // 4
    GL_CLIP_PLANE2,              // 5
    GL_CLIP_PLANE3,              // 6
    GL_CLIP_PLANE4,              // 7
    GL_CLIP_PLANE5,              // 8
    GL_COLOR_MATERIAL,           // 9
    GL_CULL_FACE,                // 10
    GL_DEPTH_TEST,               // 11
    GL_DITHER,                   // 12
    GL_FOG,                      // 13
    GL_LIGHT0,                   // 14
    GL_LIGHT1,                   // 15
    GL_LIGHT2,                   // 16
    GL_LIGHT3,                   // 17
    GL_LIGHT4,                   // 18
    GL_LIGHT5,                   // 19
    GL_LIGHT6,                   // 20
    GL_LIGHT7,                   // 21
    GL_LIGHTING,                 // 22
    GL_LINE_SMOOTH,              // 23
    GL_MULTISAMPLE,              // 24
    GL_NORMALIZE,                // 25
    GL_POINT_SMOOTH,             // 26
    GL_POINT_SPRITE_OES,         // 27
    GL_POLYGON_OFFSET_FILL,      // 28
    GL_RESCALE_NORMAL,           // 29
    GL_SAMPLE_ALPHA_TO_COVERAGE, // 30
    GL_SAMPLE_ALPHA_TO_ONE,      // 31
    GL_SAMPLE_COVERAGE,          // 32
    GL_SCISSOR_TEST,             // 33
    GL_TEXTURE_2D,               // 34
    static_cast<GLenum>(0x8840), // 35 (engine table slot with no GL ES 1.1 capability name)
};

// Maps an engine client-state index to its GL vertex-array client state.
constexpr GLenum kClientStateToGlArray[] = {
    GL_COLOR_ARRAY,            // 0
    GL_MATRIX_INDEX_ARRAY_OES, // 1
    GL_NORMAL_ARRAY,           // 2
    GL_POINT_SIZE_ARRAY_OES,   // 3
    GL_TEXTURE_COORD_ARRAY,    // 4
    GL_VERTEX_ARRAY,           // 5
    GL_WEIGHT_ARRAY_OES,       // 6
};

// Maps an engine matrix-mode index (1..3) to its GL matrix mode; any other index selects model-view.
constexpr GLenum kMatrixModeToGl[] = {GL_PROJECTION, GL_TEXTURE, GL_MATRIX_PALETTE_OES};

// Maps engine blend factor indices to their GL blend enums. The first two entries (GL_ZERO, GL_ONE)
// are shared; the source table has the extra GL_SRC_ALPHA_SATURATE at index 8.
constexpr GLenum kBlendSrcToGl[] = {
    GL_ZERO,                //
    GL_ONE,                 //
    GL_DST_COLOR,           //
    GL_ONE_MINUS_DST_COLOR, //
    GL_SRC_ALPHA,           //
    GL_ONE_MINUS_SRC_ALPHA, //
    GL_DST_ALPHA,           //
    GL_ONE_MINUS_DST_ALPHA, //
    GL_SRC_ALPHA_SATURATE,  //
};
constexpr GLenum kBlendDestToGl[] = {
    GL_ZERO,                //
    GL_ONE,                 //
    GL_SRC_COLOR,           //
    GL_ONE_MINUS_SRC_COLOR, //
    GL_SRC_ALPHA,           //
    GL_ONE_MINUS_SRC_ALPHA, //
    GL_DST_ALPHA,           //
    GL_ONE_MINUS_DST_ALPHA, //
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

/** @ghidraAddress 0x21d80 */
void neGLESRenderer::SetGlEnableState(unsigned int nState, unsigned int bEnable) {
    if (m_aEnableStateFlags[nState] == bEnable) {
        return;
    }
    m_aEnableStateFlags[nState] = static_cast<unsigned char>(bEnable);
    assert(static_cast<int>(nState) >= 0 && static_cast<int>(nState) < kEnableStateMax);
    if (bEnable != 0) {
        glEnable(kEnableStateToGlCap[nState]);
    } else {
        glDisable(kEnableStateToGlCap[nState]);
    }
}

/** @ghidraAddress 0x21e14 */
void neGLESRenderer::SetGlClientState(unsigned int nState, unsigned int bEnable) {
    if (m_aClientStateFlags[nState] == bEnable) {
        return;
    }
    m_aClientStateFlags[nState] = static_cast<unsigned char>(bEnable);
    assert(static_cast<int>(nState) >= 0 && static_cast<int>(nState) < kClientStateMax);
    if (bEnable != 0) {
        glEnableClientState(kClientStateToGlArray[nState]);
    } else {
        glDisableClientState(kClientStateToGlArray[nState]);
    }
}

/** @ghidraAddress 0x21460 */
void neGLESRenderer::SetCurrentPaletteMatrix(int nState) {
    if (m_nPaletteMatrix == nState) {
        return;
    }
    m_nPaletteMatrix = nState;
    glCurrentPaletteMatrixOES(static_cast<GLuint>(nState));
}

/** @ghidraAddress 0x21c98 */
void neGLESRenderer::SetBlendFunc(int nSrcFactor, int nDstFactor) {
    if (m_nBlendSrc == nSrcFactor && m_nBlendDest == nDstFactor) {
        return;
    }
    m_nBlendSrc = nSrcFactor;
    m_nBlendDest = nDstFactor;
    // The binary's embedded __func__ here is BlendSrcValueToGLValue: the value-mapping helpers are
    // inlined into the setter, each asserting its factor is in range before the table lookup.
    assert(nSrcFactor >= 0 && nSrcFactor < kBlendSrcMax);
    assert(nDstFactor >= 0 && nDstFactor < kBlendDestMax);
    glBlendFunc(kBlendSrcToGl[nSrcFactor], kBlendDestToGl[nDstFactor]);
}

/** @ghidraAddress 0x21250 */
void neGLESRenderer::SetMatrixMode(int nMode, const float *pMatrix) {
    // The mode switch is cached, but the matrix is loaded every call.
    if (m_nMatrixMode != nMode) {
        m_nMatrixMode = nMode;
        const GLenum glMode =
            (static_cast<unsigned int>(nMode - 1) < 3) ? kMatrixModeToGl[nMode - 1] : GL_MODELVIEW;
        glMatrixMode(glMode);
    }
    glLoadMatrixf(pMatrix);
}

// The number of colour channels a packed vertex colour carries, and the sentinel a reset pointer
// cache stores for its stride.
namespace {
constexpr int kColorComponentCount = 4;
constexpr int kResetStrideSentinel = -1;
} // namespace

/** @ghidraAddress 0x21634 */
void neGLESRenderer::SetVertexPointer(const void *pData, int nSize, int nStride) {
    if (m_nArrayBufferBound != 0) {
        // An array buffer is bound: unbind it so the client pointer takes effect.
        m_nArrayBufferBound = 0;
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        m_nVertexSize = nSize;
        m_nVertexBufferBinding = 0;
        m_pVertexPointer = pData;
        m_nVertexStride = nStride;
    } else {
        if (m_pVertexPointer == pData && m_nVertexStride == nStride && m_nVertexSize == nSize) {
            return;
        }
        m_pVertexPointer = pData;
        m_nVertexStride = nStride;
        m_nVertexSize = nSize;
        m_nVertexBufferBinding = 0;
    }
    glVertexPointer(nSize, GL_FLOAT, nStride, pData);
}

/** @ghidraAddress 0x2155c */
void neGLESRenderer::SetColorPointer(const void *pData, int nStride) {
    if (m_nArrayBufferBound != 0) {
        m_nArrayBufferBound = 0;
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        m_nColorStride = nStride;
        m_nColorBufferBinding = 0;
        m_pColorPointer = pData;
    } else {
        if (m_pColorPointer == pData && m_nColorStride == nStride) {
            return;
        }
        m_pColorPointer = pData;
        m_nColorStride = nStride;
        m_nColorBufferBinding = 0;
    }
    glColorPointer(kColorComponentCount, GL_UNSIGNED_BYTE, nStride, pData);
}

/** @ghidraAddress 0x21718 */
void neGLESRenderer::SetTexCoordPointer(const void *pData, int nStride) {
    const int nUnit = m_nActiveTexUnit;
    if (m_nArrayBufferBound != 0) {
        m_nArrayBufferBound = 0;
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        m_anTexCoordBufferBinding[nUnit] = 0;
        m_apTexCoordPointer[nUnit] = pData;
        m_anTexCoordStride[nUnit] = nStride;
    } else {
        if (m_apTexCoordPointer[nUnit] == pData && m_anTexCoordStride[nUnit] == nStride) {
            return;
        }
        m_apTexCoordPointer[nUnit] = pData;
        m_anTexCoordStride[nUnit] = nStride;
        m_anTexCoordBufferBinding[nUnit] = 0;
    }
    glTexCoordPointer(2, GL_SHORT, nStride, pData);
}

/** @ghidraAddress 0x2183c */
void neGLESRenderer::SetWeightPointer(const void *pData, int nSize, int nStride) {
    if (m_nArrayBufferBound != 0) {
        m_nArrayBufferBound = 0;
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        m_nWeightBufferBinding = 0;
        m_pWeightPointer = pData;
        m_nWeightStride = nStride;
        m_nWeightSize = nSize;
    } else {
        if (m_pWeightPointer == pData && m_nWeightStride == nStride && m_nWeightSize == nSize) {
            return;
        }
        m_pWeightPointer = pData;
        m_nWeightStride = nStride;
        m_nWeightSize = nSize;
        m_nWeightBufferBinding = 0;
    }
    glWeightPointerOES(nSize, GL_FLOAT, nStride, pData);
}

/** @ghidraAddress 0x21928 */
void neGLESRenderer::SetMatrixIndexPointer(const void *pData, int nSize, int nStride) {
    if (m_nArrayBufferBound != 0) {
        m_nArrayBufferBound = 0;
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        m_nMatrixIndexBufferBinding = 0;
        m_pMatrixIndexPointer = pData;
        m_nMatrixIndexStride = nStride;
        m_nMatrixIndexSize = nSize;
    } else {
        if (m_pMatrixIndexPointer == pData && m_nMatrixIndexStride == nStride &&
            m_nMatrixIndexSize == nSize) {
            return;
        }
        m_pMatrixIndexPointer = pData;
        m_nMatrixIndexStride = nStride;
        m_nMatrixIndexSize = nSize;
        m_nMatrixIndexBufferBinding = 0;
    }
    glMatrixIndexPointerOES(nSize, GL_UNSIGNED_BYTE, nStride, pData);
}

/** @ghidraAddress 0x216dc */
void neGLESRenderer::ClearVertexPointer(int nStride, int nSize) {
    // Re-point the array at the bound buffer's default (offset 0) only when the binding changed.
    if (m_nArrayBufferBound != 0 && m_nVertexBufferBinding != m_nArrayBufferBound) {
        m_nVertexBufferBinding = m_nArrayBufferBound;
        m_pVertexPointer = nullptr;
        m_nVertexStride = kResetStrideSentinel;
        m_nVertexSize = 0;
        glVertexPointer(nSize, GL_FLOAT, nStride, nullptr);
    }
}

/** @ghidraAddress 0x215f4 */
void neGLESRenderer::ClearColorPointer(int nStride, int nColorOffset, int nBinding) {
    (void)nBinding; // The binary reloads the cached binding from m_nArrayBufferBound; the caller's
                    // scratch value is unused.
    if (m_nArrayBufferBound != 0 && m_nColorBufferBinding != m_nArrayBufferBound) {
        m_nColorBufferBinding = m_nArrayBufferBound;
        m_nColorStride = kResetStrideSentinel;
        m_pColorPointer = nullptr;
        glColorPointer(kColorComponentCount,
                       GL_UNSIGNED_BYTE,
                       nStride,
                       reinterpret_cast<const void *>(static_cast<long>(nColorOffset)));
    }
}

/** @ghidraAddress 0x217e4 */
void neGLESRenderer::ClearTexCoordPointer(int nStride, int nTexCoordOffset) {
    const int nUnit = m_nActiveTexUnit;
    if (m_nArrayBufferBound != 0 && m_anTexCoordBufferBinding[nUnit] != m_nArrayBufferBound) {
        m_anTexCoordBufferBinding[nUnit] = m_nArrayBufferBound;
        m_apTexCoordPointer[nUnit] = nullptr;
        m_anTexCoordStride[nUnit] = kResetStrideSentinel;
        glTexCoordPointer(2,
                          GL_SHORT,
                          nStride,
                          reinterpret_cast<const void *>(static_cast<long>(nTexCoordOffset)));
    }
}

/** @ghidraAddress 0x218ec */
void neGLESRenderer::ClearWeightPointer(int nStride, int nSize) {
    if (m_nArrayBufferBound != 0 && m_nWeightBufferBinding != m_nArrayBufferBound) {
        m_nWeightBufferBinding = m_nArrayBufferBound;
        m_pWeightPointer = nullptr;
        m_nWeightStride = kResetStrideSentinel;
        m_nWeightSize = 0;
        glWeightPointerOES(nSize, GL_FLOAT, nStride, nullptr);
    }
}

/** @ghidraAddress 0x219d8 */
void neGLESRenderer::ClearMatrixIndexPointer(int nStride, int nSize) {
    if (m_nArrayBufferBound != 0 && m_nMatrixIndexBufferBinding != m_nArrayBufferBound) {
        m_nMatrixIndexBufferBinding = m_nArrayBufferBound;
        m_pMatrixIndexPointer = nullptr;
        m_nMatrixIndexStride = kResetStrideSentinel;
        m_nMatrixIndexSize = 0;
        glMatrixIndexPointerOES(nSize, GL_UNSIGNED_BYTE, nStride, nullptr);
    }
}

/** @ghidraAddress 0x21510 */
void neGLESRenderer::BindArrayBuffer(unsigned int dwBuffer) {
    if (m_nArrayBufferBound == static_cast<int>(dwBuffer)) {
        return;
    }
    m_nArrayBufferBound = static_cast<int>(dwBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, dwBuffer);
}

/** @ghidraAddress 0x21a14 */
void neGLESRenderer::BindIndexBuffer(unsigned int dwBuffer) {
    if (m_nElementBufferBound == static_cast<int>(dwBuffer)) {
        return;
    }
    m_nElementBufferBound = static_cast<int>(dwBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, dwBuffer);
}
