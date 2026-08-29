#include "neGLES.h"

#include <cassert>
#include <cstring>

#include <OpenGLES/ES1/gl.h>
#include <OpenGLES/ES1/glext.h>

namespace {

enum {
    kTexFormatCompressed = 0,
    kTexFormatMax = 4,
};

constexpr GLenum kEngineFormatToGl[] = {GL_RGBA, GL_RGB, GL_LUMINANCE_ALPHA};

constexpr GLenum kPrimitiveToGlMode[] = {
    GL_POINTS,         //
    GL_LINE_STRIP,     //
    GL_LINE_LOOP,      //
    GL_LINES,          //
    GL_TRIANGLE_STRIP, //
    GL_TRIANGLE_FAN,   //
    GL_TRIANGLES,      //
};

constexpr int kEnableStateMax = 0x24;
constexpr int kClientStateMax = 7;

constexpr int kBlendSrcMax = 9;
constexpr int kBlendDestMax = 8;

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

constexpr GLenum kClientStateToGlArray[] = {
    GL_COLOR_ARRAY,            // 0
    GL_MATRIX_INDEX_ARRAY_OES, // 1
    GL_NORMAL_ARRAY,           // 2
    GL_POINT_SIZE_ARRAY_OES,   // 3
    GL_TEXTURE_COORD_ARRAY,    // 4
    GL_VERTEX_ARRAY,           // 5
    GL_WEIGHT_ARRAY_OES,       // 6
};

constexpr GLenum kMatrixModeToGl[] = {GL_PROJECTION, GL_TEXTURE, GL_MATRIX_PALETTE_OES};

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

// The engine parameter type (0..3: mag filter, min filter, wrap S, wrap T) is added to this base to
// form the GL enum.
constexpr GLenum kTexParamTypeBase = GL_TEXTURE_MAG_FILTER;
constexpr int kTexParamTypeMax = 4;

constexpr GLenum kTexParamValueToGl[] = {
    GL_NEAREST,                //
    GL_LINEAR,                 //
    GL_NEAREST_MIPMAP_NEAREST, //
    GL_LINEAR_MIPMAP_NEAREST,  //
    GL_NEAREST_MIPMAP_LINEAR,  //
    GL_LINEAR_MIPMAP_LINEAR,   //
    GL_CLAMP_TO_EDGE,          //
    GL_REPEAT,                 //
};
constexpr int kTexParamValueMax = 8;

} // namespace

neGLESRenderer *g_glesRenderer = nullptr; // @ghidraAddress 0x3dc250

/** @ghidraAddress 0x20f50 */
neGLESRenderer *neGLESRenderer::GetShared() {
    return g_glesRenderer;
}

/** @ghidraAddress 0x20f5c */
void neGLESRenderer::EnsureShared() {
    if (g_glesRenderer != nullptr) {
        return;
    }
    g_glesRenderer = new neGLESRenderer();
    g_glesRenderer->QueryCaps();
}

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
    glFramebufferRenderbufferOES(
        GL_FRAMEBUFFER_OES, RenderKindToGl(nRenderKind), GL_RENDERBUFFER_OES, dwRenderbuffer);
}

/** @ghidraAddress 0x212a4 */
unsigned int neGLESRenderer::GetRenderbufferTarget() {
    return GL_RENDERBUFFER_OES;
}

/** @ghidraAddress 0x213b4 */
bool neGLESRenderer::IsFramebufferComplete() {
    return glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) == GL_FRAMEBUFFER_COMPLETE_OES;
}

/** @ghidraAddress 0x2131c */
int neGLESRenderer::RenderKindToGl(RenderKind nKind) {
    assert(nKind >= 0 && nKind < RENDER_KIND_MAX);
    constexpr int kAttachments[] = {
        GL_COLOR_ATTACHMENT0_OES, GL_DEPTH_ATTACHMENT_OES, GL_STENCIL_ATTACHMENT_OES};
    return kAttachments[nKind];
}

/** @ghidraAddress 0x21b6c */
int TexParamTypeToGl(TexParamType nType) {
    assert(nType >= 0 && nType < kTexParamTypeMax);
    return static_cast<int>(kTexParamTypeBase + nType);
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
void neGLESRenderer::SetGlEnableState(unsigned int nState, bool bEnable) {
    if (m_aEnableStateFlags[nState] == bEnable) {
        return;
    }
    m_aEnableStateFlags[nState] = bEnable;
    assert(static_cast<int>(nState) >= 0 && static_cast<int>(nState) < kEnableStateMax);
    if (bEnable) {
        glEnable(kEnableStateToGlCap[nState]);
    } else {
        glDisable(kEnableStateToGlCap[nState]);
    }
}

/** @ghidraAddress 0x21e14 */
void neGLESRenderer::SetGlClientState(unsigned int nState, bool bEnable) {
    if (m_aClientStateFlags[nState] == bEnable) {
        return;
    }
    m_aClientStateFlags[nState] = bEnable;
    assert(static_cast<int>(nState) >= 0 && static_cast<int>(nState) < kClientStateMax);
    if (bEnable) {
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
    // The binary inlines the value mappers here; its embedded __func__ is BlendSrcValueToGLValue.
    assert(nSrcFactor >= 0 && nSrcFactor < kBlendSrcMax);
    assert(nDstFactor >= 0 && nDstFactor < kBlendDestMax);
    glBlendFunc(kBlendSrcToGl[nSrcFactor], kBlendDestToGl[nDstFactor]);
}

/** @ghidraAddress 0x21250 */
void neGLESRenderer::SetMatrixMode(int nMode, const float *pMatrix) {
    if (m_nMatrixMode != nMode) {
        m_nMatrixMode = nMode;
        const GLenum glMode =
            (static_cast<unsigned int>(nMode - 1) < 3) ? kMatrixModeToGl[nMode - 1] : GL_MODELVIEW;
        glMatrixMode(glMode);
    }
    glLoadMatrixf(pMatrix);
}

/** @ghidraAddress 0x21408 */
void neGLESRenderer::SetViewport(int nX, int nY, int nWidth, int nHeight) {
    if (m_nViewportX == nX && m_nViewportY == nY && m_nViewportWidth == nWidth &&
        m_nViewportHeight == nHeight) {
        return;
    }
    m_nViewportX = nX;
    m_nViewportY = nY;
    m_nViewportWidth = nWidth;
    m_nViewportHeight = nHeight;
    glViewport(nX, nY, nWidth, nHeight);
}

namespace {
constexpr int kColorComponentCount = 4;
constexpr int kResetStrideSentinel = -1;
} // namespace

/** @ghidraAddress 0x21634 */
void neGLESRenderer::SetVertexPointer(const void *pData, int nSize, int nStride) {
    if (m_nArrayBufferBound != 0) {
        // Unbind the array buffer so the client pointer takes effect.
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
    (void)nBinding; // The binary reloads the binding from m_nArrayBufferBound; unused here.
    if (m_nArrayBufferBound != 0 && m_nColorBufferBinding != m_nArrayBufferBound) {
        m_nColorBufferBinding = m_nArrayBufferBound;
        m_nColorStride = kResetStrideSentinel;
        m_pColorPointer = nullptr;
        // With a buffer bound, the GL pointer argument is a byte offset into the VBO, not a
        // pointer.
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
        // With a buffer bound, the GL pointer argument is a byte offset into the VBO, not a
        // pointer.
        glTexCoordPointer(2,
                          GL_SHORT,
                          nStride,
                          reinterpret_cast<const void *>(static_cast<long>(nTexCoordOffset)));
    }
}

/** @ghidraAddress 0x218ec */
void neGLESRenderer::ClearWeightPointer(int nStride, int nSize, int nWeightOffset) {
    if (m_nArrayBufferBound != 0 && m_nWeightBufferBinding != m_nArrayBufferBound) {
        m_nWeightBufferBinding = m_nArrayBufferBound;
        m_pWeightPointer = nullptr;
        m_nWeightStride = kResetStrideSentinel;
        m_nWeightSize = kResetStrideSentinel;
        glWeightPointerOES(nSize,
                           GL_FLOAT,
                           nStride,
                           reinterpret_cast<const void *>(static_cast<long>(nWeightOffset)));
    }
}

/** @ghidraAddress 0x219d8 */
void neGLESRenderer::ClearMatrixIndexPointer(int nStride, int nSize, int nMatrixIndexOffset) {
    if (m_nArrayBufferBound != 0 && m_nMatrixIndexBufferBinding != m_nArrayBufferBound) {
        m_nMatrixIndexBufferBinding = m_nArrayBufferBound;
        m_pMatrixIndexPointer = nullptr;
        m_nMatrixIndexStride = kResetStrideSentinel;
        m_nMatrixIndexSize = kResetStrideSentinel;
        glMatrixIndexPointerOES(
            nSize,
            GL_UNSIGNED_BYTE,
            nStride,
            reinterpret_cast<const void *>(static_cast<long>(nMatrixIndexOffset)));
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

/** @ghidraAddress 0x21ab4 */
void neGLESRenderer::BindTexture2d(unsigned int dwHandle) {
    if (m_anTexturePerUnit[m_nActiveTextureUnit] == static_cast<int>(dwHandle)) {
        return;
    }
    m_anTexturePerUnit[m_nActiveTextureUnit] = static_cast<int>(dwHandle);
    glBindTexture(GL_TEXTURE_2D, dwHandle);
}

/** @ghidraAddress 0x21ae8 */
void neGLESRenderer::SetTextureParameter(int nParameter, int nValue) {
    // The binary inlines the type and value mappers; its __func__ is TexParamValueFuncToGLValue.
    assert(nParameter >= 0 && nParameter < kTexParamTypeMax);
    assert(nValue >= 0 && nValue < kTexParamValueMax);
    glTexParameteri(GL_TEXTURE_2D,
                    static_cast<GLenum>(kTexParamTypeBase + nParameter),
                    static_cast<GLint>(kTexParamValueToGl[nValue]));
}

/** @ghidraAddress 0x21484 */
void neGLESRenderer::DeleteBuffer(unsigned int dwBuffer) {
    const int nBuffer = static_cast<int>(dwBuffer);
    if (m_nArrayBufferBound == nBuffer) {
        m_nArrayBufferBound = 0;
    }
    if (m_nColorBufferBinding == nBuffer) {
        m_nColorBufferBinding = 0;
    }
    if (m_nBufferBinding2 == nBuffer) {
        m_nBufferBinding2 = 0;
    }
    if (m_nVertexBufferBinding == nBuffer) {
        m_nVertexBufferBinding = 0;
    }
    for (int nUnit = 0; nUnit < kMaxTextureUnits; ++nUnit) {
        if (m_anTexCoordBufferBinding[nUnit] == nBuffer) {
            m_anTexCoordBufferBinding[nUnit] = 0;
        }
    }
    glDeleteBuffers(1, &dwBuffer);
}

/** @ghidraAddress 0x21a68 */
void neGLESRenderer::DeleteTexture(unsigned int dwHandle) {
    const int nTexture = static_cast<int>(dwHandle);
    for (int nUnit = 0; nUnit < kMaxTextureUnits; ++nUnit) {
        if (m_anTexturePerUnit[nUnit] == nTexture) {
            m_anTexturePerUnit[nUnit] = 0;
        }
    }
    glDeleteTextures(1, &dwHandle);
}

/** @ghidraAddress 0x2152c */
void neGLESRenderer::UploadArrayBufferData(const void *pData, unsigned int nSize, int nUsage) {
    if (m_nArrayBufferBound == 0) {
        return;
    }
    glBufferData(GL_ARRAY_BUFFER, nSize, pData, nUsage != 0 ? GL_DYNAMIC_DRAW : GL_STATIC_DRAW);
}

/** @ghidraAddress 0x21a30 */
void neGLESRenderer::UploadIndexBufferData(const void *pData, unsigned int nSize, int nUsage) {
    if (m_nElementBufferBound == 0) {
        return;
    }
    glBufferData(
        GL_ELEMENT_ARRAY_BUFFER, nSize, pData, nUsage != 0 ? GL_DYNAMIC_DRAW : GL_STATIC_DRAW);
}

namespace {
constexpr char kMatrixPaletteExtension[] = "GL_OES_matrix_palette";
constexpr int kDefaultMaxPaletteMatrices = 9;
// Engine matrix modes: 1 model-view, 2 projection, 3 texture.
constexpr int kMatrixModeProjection = 2;
// Maps the engine's 65536-unit space to the [-1, 1] clip range.
constexpr float kProjectionScale = 2.0f / 65536.0f;
constexpr float kDefaultProjection[] = {
    kProjectionScale,
    0.0f,
    0.0f,
    0.0f, //
    0.0f,
    kProjectionScale,
    0.0f,
    0.0f, //
    0.0f,
    0.0f,
    1.0f,
    0.0f, //
    0.0f,
    0.0f,
    0.0f,
    1.0f, //
};
} // namespace

namespace {
// Per-unit sampler defaults: minification filter, magnification filter, S-wrap, and T-wrap.
constexpr int kDefaultTexParams[] = {4, 1, 7, 7};
constexpr int kDefaultBlendSrc = 1;
constexpr int kDefaultBlendDest = 0;
constexpr int kDefaultCullFace = 1;
constexpr int kUnboundHandle = -1;
constexpr float kDefaultColorComponent = 1.0f;
constexpr float kDefaultColorMatrixDiagonal[] = {1.0f, 1.0f, 0.0f, 1.0f};
constexpr int kField030Default = 7;
} // namespace

/** @ghidraAddress 0x210ec */
neGLESRenderer::neGLESRenderer() {
    m_pField000 = nullptr;
    m_pField008 = nullptr;
    m_flCurrentColorR = kDefaultColorComponent;
    m_nField014 = 0;
    m_nViewportX = 0;
    m_nViewportY = 0;
    m_nViewportWidth = kUnboundHandle;
    m_nViewportHeight = kUnboundHandle;
    m_nMatrixMode = 0;
    m_nPaletteMatrix = 0;
    m_nField030 = kField030Default;
    m_nField034 = 0;
    m_bDepthTestEnabled = true;
    m_nCullFace = kDefaultCullFace;
    m_nArrayBufferBound = 0;
    m_pColorPointer = nullptr;
    m_nColorStride = kUnboundHandle;
    m_nColorBufferBinding = 0;
    m_nHandle060 = kUnboundHandle;
    m_nBufferBinding2 = 0;
    m_pVertexPointer = nullptr;
    m_nVertexStride = kUnboundHandle;
    m_nVertexSize = 0;
    m_nVertexBufferBinding = 0;
    m_nActiveTexUnit = 0;
    m_pWeightPointer = nullptr;
    m_nWeightStride = kUnboundHandle;
    m_nWeightSize = 0;
    m_nWeightBufferBinding = 0;
    m_pMatrixIndexPointer = nullptr;
    m_nMatrixIndexStride = kUnboundHandle;
    m_nMatrixIndexSize = 0;
    m_nElementBufferBound = 0;
    for (int nUnit = 0; nUnit < kMaxTextureUnits; ++nUnit) {
        m_apTexCoordPointer[nUnit] = nullptr;
        m_anTexCoordStride[nUnit] = kUnboundHandle;
        m_anTexCoordBufferBinding[nUnit] = 0;
        m_anTexturePerUnit[nUnit] = 0;
        for (int nParam = 0; nParam < kTexParamCount; ++nParam) {
            m_aTexParamCache[nUnit][nParam] = kDefaultTexParams[nParam];
        }
    }
    m_nBlendSrc = kDefaultBlendSrc;
    m_nBlendDest = kDefaultBlendDest;
    m_nField1dc = kDefaultBlendSrc;
    m_nField20c = 0;
    m_bField20e = false;
    for (int i = 0; i < 4; ++i) {
        m_aColorMatrixDiagonal[i] = kDefaultColorMatrixDiagonal[i];
    }
    m_nField220 = 0;
    m_nHandle230 = kUnboundHandle;
    m_nHandle238 = kUnboundHandle;
    m_nHandle240 = kUnboundHandle;
}

/** @ghidraAddress 0x20f9c */
void neGLESRenderer::QueryCaps() {
    const char *pExtensions = reinterpret_cast<const char *>(glGetString(GL_EXTENSIONS));
    for (const char *pSpace = strchr(pExtensions, ' '); pSpace != nullptr;
         pSpace = strchr(pExtensions, ' ')) {
        const size_t nLength = static_cast<size_t>(pSpace - pExtensions);
        char aToken[128];
        strncpy(aToken, pExtensions, nLength);
        aToken[nLength] = '\0';
        if (strncmp(aToken, kMatrixPaletteExtension, nLength) == 0) {
            m_bHasMatrixPalette = true;
        }
        pExtensions = pSpace + 1;
    }
    if (m_bHasMatrixPalette) {
        m_nMaxPaletteMatrices = kDefaultMaxPaletteMatrices;
        // The binary queries 0x8842, the palette size, not GL_MAX_VERTEX_UNITS_OES (0x86a4).
        glGetIntegerv(GL_MAX_PALETTE_MATRICES_OES, &m_nMaxPaletteMatrices);
    }
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &m_nMaxTextureSize);
    SetMatrixMode(kMatrixModeProjection, kDefaultProjection);
    glLineWidth(1.0f);
}
