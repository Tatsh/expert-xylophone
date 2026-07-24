/**
 * @file
 * The shared GL ES 1.1 render-state backend, @c neGLESRenderer.
 */

#pragma once

//
//  neGLES.h
//  REFLEC BEAT plus
//
//  The shared ne GL ES 1.1 render-state backend (the binary's neGLES.cpp). Its buffer,
//  framebuffer-object, texture, draw, and render-state entry points are C++ instance methods, each
//  an out-of-line trampoline over a GL / GL_OES_framebuffer_object call that also maintains the
//  renderer's cached GL state so a redundant call is skipped.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

/**
 * @brief The engine render-kind that selects a GL framebuffer attachment point.
 *
 * Passed to @c AttachRenderbufferToFramebuffer; @c neGLES::RenderKindToGLRenderKind maps the kind
 * to its GL attachment enum (colour, depth, or stencil).
 * @ghidraAddress neGLES::RenderKind (engine enumeration)
 */
enum RenderKind {
    RENDER_KIND_COLOR = 0,   /*!< The colour attachment (@c GL_COLOR_ATTACHMENT0_OES). */
    RENDER_KIND_DEPTH = 1,   /*!< The depth attachment (@c GL_DEPTH_ATTACHMENT_OES). */
    RENDER_KIND_STENCIL = 2, /*!< The stencil attachment (@c GL_STENCIL_ATTACHMENT_OES). */
};

// The shared ne::neGLES_11 GL ES 1.1 render-state backend. Only the members the application and
// render layers call are declared; the state-cache fields the render-state setters touch are
// modelled, and the rest of the 0x258-byte object is reserved until the full engine class is
// reconstructed. GL object names are @c GLuint and the size-out arguments are @c GLint, spelled as
// their C-safe equivalents so this header need not import the OpenGL ES headers. The application
// layer only ever holds a @c neGLESRenderer* obtained from @c GetGlRenderer() /
// @c EnsureGLRenderStateSingleton().
class neGLESRenderer {
public:
    /**
     * @brief Clears the current GL buffers selected by the GL clear mask.
     * @ghidraAddress 0x21400
     */
    void ClearBuffers(unsigned int dwMask);
    /**
     * @brief Deletes the GL texture object @p dwHandle.
     * @ghidraAddress 0x21a68
     */
    void DeleteTexture(unsigned int dwHandle);
    /**
     * @brief Generates one GL framebuffer object name into @p pOutFramebuffer.
     * @ghidraAddress 0x212ac
     */
    void GenFramebuffer(unsigned int *pOutFramebuffer);
    /**
     * @brief Deletes the GL framebuffer object @p dwFramebuffer.
     * @ghidraAddress 0x212b4
     */
    void DeleteFramebuffer(unsigned int dwFramebuffer);
    /**
     * @brief Binds @p dwFramebuffer as the current @c GL_FRAMEBUFFER_OES draw target.
     * @ghidraAddress 0x212dc
     */
    void BindFramebuffer(unsigned int dwFramebuffer);
    /**
     * @brief Generates one GL renderbuffer object name into @p pOutRenderbuffer.
     * @ghidraAddress 0x212e4
     */
    void GenRenderbuffer(unsigned int *pOutRenderbuffer);
    /**
     * @brief Deletes the GL renderbuffer object @p dwRenderbuffer.
     * @ghidraAddress 0x212ec
     */
    void DeleteRenderbuffer(unsigned int dwRenderbuffer);
    /**
     * @brief Binds @p dwRenderbuffer as the current @c GL_RENDERBUFFER_OES.
     * @ghidraAddress 0x21314
     */
    void BindRenderbuffer(unsigned int dwRenderbuffer);
    /**
     * @brief Attaches @p dwRenderbuffer to the bound framebuffer at the @p nRenderKind attachment.
     * @ghidraAddress 0x21380
     */
    void AttachRenderbufferToFramebuffer(RenderKind nRenderKind, unsigned int dwRenderbuffer);
    /**
     * @brief Reads the bound renderbuffer's width into @p pOutWidth.
     * @ghidraAddress 0x213d8
     */
    void GetRenderbufferWidth(int *pOutWidth);
    /**
     * @brief Reads the bound renderbuffer's height into @p pOutHeight.
     * @ghidraAddress 0x213ec
     */
    void GetRenderbufferHeight(int *pOutHeight);
    /**
     * @brief Generates one GL buffer object name into @p pOutBuffer.
     * @ghidraAddress 0x2147c
     */
    void GenBuffer(unsigned int *pOutBuffer);
    /**
     * @brief Binds @p dwBuffer as the current @c GL_ELEMENT_ARRAY_BUFFER.
     * @ghidraAddress 0x21a14
     */
    void BindIndexBuffer(unsigned int dwBuffer);
    /**
     * @brief Binds @p dwBuffer as the current @c GL_ARRAY_BUFFER.
     * @ghidraAddress 0x21510
     */
    void BindArrayBuffer(unsigned int dwBuffer);
    /**
     * @brief Uploads @p nSize bytes of index data to the bound element-array buffer.
     * @ghidraAddress 0x21a30
     */
    void UploadIndexBufferData(const void *pData, unsigned int nSize, int nUsage);
    /**
     * @brief Uploads @p nSize bytes of vertex data to the bound array buffer.
     * @ghidraAddress 0x2152c
     */
    void UploadArrayBufferData(const void *pData, unsigned int nSize, int nUsage);
    /**
     * @brief Deletes the GL buffer object @p dwBuffer.
     * @ghidraAddress 0x21484
     */
    void DeleteBuffer(unsigned int dwBuffer);
    /**
     * @brief Generates one GL texture object name into @p pOutHandle.
     * @ghidraAddress 0x21a60
     */
    void GenTexture(unsigned int *pOutHandle);
    /**
     * @brief Binds @p dwHandle as the current @c GL_TEXTURE_2D.
     * @ghidraAddress 0x21ab4
     */
    void BindTexture2d(unsigned int dwHandle);
    /**
     * @brief Sets one texture sampler parameter (@p nParameter: 0 min filter, 1 mag filter, 2 wrap
     *        S, 3 wrap T) to @p nValue on the bound texture.
     * @ghidraAddress 0x21ae8
     */
    void SetTextureParameter(int nParameter, int nValue);
    /**
     * @brief Uploads @p nWidth by @p nHeight pixels in the given @p nFormat to the bound texture.
     * @ghidraAddress 0x21bd0
     */
    void UploadTexture2d(int nFormat, int nWidth, int nHeight, const void *pData);
    /**
     * @brief Draws indexed primitives of the given engine primitive kind from the bound element
     *        buffer (Ghidra names this @c SetGlParameterByIndex).
     * @param nPrimitive The engine primitive index; an out-of-range value draws points.
     * @param nCount The number of indices to draw.
     * @param pIndices The index data (or the byte offset into the bound element buffer).
     * @ghidraAddress 0x21ea8
     */
    void DrawIndexedPrimitives(int nPrimitive, int nCount, const void *pIndices);
    /**
     * @brief The maximum number of vertex units (bone matrices) the renderer supports per vertex.
     *
     * Read from the renderer's capability block; used to size a skinned mesh's per-bone arrays.
     */
    int GetMaxVertexUnits() const;
    /**
     * @brief The maximum number of sprite instances a single instanced draw call may submit.
     *
     * Read from the renderer's capability block; the sprite batch flushes a draw once this many
     * per-instance matrices have been queued.
     */
    int GetMaxSpritesPerBatch() const {
        return m_nMaxSpritesPerBatch;
    }

    /**
     * @brief Enable or disable one engine render capability, skipping the GL call when the cached
     *        state is already @p bEnable.
     * @param nState The engine enable-state index (0 through @c kEnableStateMax - 1).
     * @param bEnable @c 1 to enable the capability, @c 0 to disable it.
     * @ghidraAddress 0x21d80
     */
    void SetGlEnableState(unsigned int nState, unsigned int bEnable);
    /**
     * @brief Enable or disable one engine vertex-array client state, skipping the GL call when the
     *        cached state is already @p bEnable.
     * @param nState The engine client-state index (0 through @c kClientStateMax - 1).
     * @param bEnable @c 1 to enable the array, @c 0 to disable it.
     * @ghidraAddress 0x21e14
     */
    void SetGlClientState(unsigned int nState, unsigned int bEnable);
    /**
     * @brief Select the current palette matrix, caching it so an unchanged value skips the GL call.
     * @param nState The palette-matrix index.
     * @ghidraAddress 0x21460
     */
    void SetCurrentPaletteMatrix(int nState);
    /**
     * @brief Set the GL blend function, caching the factors so an unchanged pair skips the GL call.
     * @param nSrcFactor The engine blend source factor (0 through @c kBlendSrcMax - 1).
     * @param nDstFactor The engine blend destination factor (0 through @c kBlendDestMax - 1).
     * @ghidraAddress 0x21c98
     */
    void SetBlendFunc(int nSrcFactor, int nDstFactor);
    /**
     * @brief Select the active matrix mode and load @p pMatrix into it; an unchanged mode skips the
     *        @c glMatrixMode call but the matrix is always loaded.
     * @param nMode The engine matrix-mode index (1 through 3, else model-view).
     * @param pMatrix The 16-float matrix to load after switching mode.
     * @ghidraAddress 0x21250
     */
    void SetMatrixMode(int nMode, const float *pMatrix);

private:
    // Only the state-cache fields the render-state setters above touch are modelled; the remainder
    // of the 0x258-byte object is reserved until the full engine class is reconstructed. The
    // trailing // +0xNN comments document the original offsets for reference only.
    unsigned char m_aReserved000[0x28] = {};      // +0x000
    int m_nMatrixMode = {};                       // +0x028 cached active matrix mode
    int m_nPaletteMatrix = {};                    // +0x02c cached current palette matrix
    unsigned char m_aReserved030[0x1a4] = {};     // +0x030
    int m_nBlendSrc = {};                         // +0x1d4 cached blend source factor
    int m_nBlendDest = {};                        // +0x1d8 cached blend destination factor
    unsigned char m_aReserved1dc[0x08] = {};      // +0x1dc
    unsigned char m_aEnableStateFlags[0x24] = {}; // +0x1e4 per-capability enable cache
    unsigned char m_aClientStateFlags[0x07] = {}; // +0x208 per-array client-state cache
    unsigned char m_aReserved20f[0x45] = {};      // +0x20f
    int m_nMaxSpritesPerBatch = {};               // +0x254 GL capability: max instances per draw
};

/**
 * @brief Returns the global OpenGL ES renderer, or @c nullptr when it has not been created.
 * @ghidraAddress 0x20f50
 */
neGLESRenderer *GetGlRenderer();
/**
 * @brief Lazily constructs the global GL render-state singleton and probes GL capabilities.
 * @ghidraAddress 0x20f5c
 */
neGLESRenderer *EnsureGLRenderStateSingleton();
/**
 * @brief Returns the @c GL_RENDERBUFFER_OES bind target constant (0x8d41).
 * @ghidraAddress 0x212a4
 */
unsigned int GetGLRenderbufferTarget();
/**
 * @brief Returns @c true when the bound framebuffer is complete.
 * @ghidraAddress 0x213b4
 */
bool CheckFramebufferComplete();

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
