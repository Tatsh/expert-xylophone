/**
 * @file
 * The shared GL ES 1.1 render-state backend, @c neGLESRenderer.
 */

#pragma once

/**
 * The engine render-kind that selects a GL framebuffer attachment point.
 *
 * Passed to @c AttachRenderbufferToFramebuffer; @c neGLESRenderer::RenderKindToGl maps the kind
 * to its GL attachment enum (colour, depth, or stencil).
 *
 * Reconstructed type @c neGLES::RenderKind: engine enumeration.
 */
enum RenderKind {
    RENDER_KIND_COLOR = 0,   /*!< The colour attachment (@c GL_COLOR_ATTACHMENT0_OES). */
    RENDER_KIND_DEPTH = 1,   /*!< The depth attachment (@c GL_DEPTH_ATTACHMENT_OES). */
    RENDER_KIND_STENCIL = 2, /*!< The stencil attachment (@c GL_STENCIL_ATTACHMENT_OES). */
    RENDER_KIND_MAX = 3,     /*!< The number of render kinds. */
};

/**
 * The engine texture-parameter type that selects a GL sampler parameter name.
 *
 * @c neGLES::TexParamTypeToGl maps the type to its GL parameter-name enum (the magnification and
 * minification filters and the S and T wrap modes).
 *
 * Reconstructed type @c neIGLES::TEX_PARAM_TYPE: engine enumeration.
 */
enum TexParamType {
    TEX_PARAM_TYPE_MAG_FILTER = 0, /*!< The magnification filter (@c GL_TEXTURE_MAG_FILTER). */
    TEX_PARAM_TYPE_MIN_FILTER = 1, /*!< The minification filter (@c GL_TEXTURE_MIN_FILTER). */
    TEX_PARAM_TYPE_WRAP_S = 2,     /*!< The S-axis wrap mode (@c GL_TEXTURE_WRAP_S). */
    TEX_PARAM_TYPE_WRAP_T = 3,     /*!< The T-axis wrap mode (@c GL_TEXTURE_WRAP_T). */
    TEX_PARAM_TYPE_MAX = 4,        /*!< The number of texture-parameter types. */
};

/**
 * Maps a texture-parameter type to its GL sampler parameter-name enum.
 *
 * Asserts the type is in range; the four parameter names are consecutive enums, so the binary
 * computes the result inline as @c GL_TEXTURE_MAG_FILTER @c + @p nType.
 * @param nType The texture-parameter type.
 * @return The GL parameter-name enum for @p nType.
 * @ghidraAddress 0x21b6c
 */
int TexParamTypeToGl(TexParamType nType);

/**
 * The shared @c ne::neGLES_11 GL ES 1.1 render-state backend.
 *
 * Only the members the application and render layers call are declared; the state-cache fields the
 * render-state setters touch are modelled, and the rest of the 0x258-byte object is reserved until
 * the full engine class is reconstructed. GL object names are @c GLuint and the size-out arguments
 * are @c GLint, spelled as their C-safe equivalents so this header need not import the OpenGL ES
 * headers. The application layer only ever holds a @c neGLESRenderer* obtained from
 * @c neGLESRenderer::GetShared() / @c neGLESRenderer::EnsureShared().
 */
class neGLESRenderer {
public:
    /**
     * Constructs the render state: clears the viewport, matrix-mode, and array-pointer
     *        caches, seeds the default blend function, cull mode, current colour, sampler
     *        parameters, and colour-matrix diagonal, and marks every buffer and texture binding
     *        unbound.
     * @ghidraAddress 0x210ec
     */
    neGLESRenderer();

    /**
     * Returns the global OpenGL ES renderer, or @c nullptr when it has not been created.
     * @return The global renderer, or @c nullptr when @c EnsureShared has not run.
     * @ghidraAddress 0x20f50
     */
    static neGLESRenderer *GetShared();
    /**
     * Lazily constructs the global GL render-state singleton and probes GL capabilities.
     *
     * On first call it allocates the render state, runs its constructor, stores it in the global,
     * and probes the GL capabilities; subsequent calls are a no-op.
     * @ghidraAddress 0x20f5c
     */
    static void EnsureShared();
    /**
     * Returns the @c GL_RENDERBUFFER_OES bind target constant (0x8d41).
     * @return The @c GL_RENDERBUFFER_OES bind target constant.
     * @ghidraAddress 0x212a4
     */
    static unsigned int GetRenderbufferTarget();
    /**
     * Returns @c true when the bound framebuffer is complete.
     * @return @c true when the bound framebuffer is complete.
     * @ghidraAddress 0x213b4
     */
    static bool IsFramebufferComplete();
    /**
     * Maps a render kind to its GL framebuffer-attachment enum.
     *
     * Asserts the kind is in range; colour, depth, and stencil map to consecutive attachment enums.
     * @param nKind The render kind.
     * @return The GL attachment enum for @p nKind.
     * @ghidraAddress 0x2131c
     */
    static int RenderKindToGl(RenderKind nKind);

    /**
     * Clears the current GL buffers selected by the GL clear mask.
     * @param dwMask The GL clear mask selecting the buffers to clear.
     * @ghidraAddress 0x21400
     */
    void ClearBuffers(unsigned int dwMask);
    /**
     * Deletes the GL texture object @p dwHandle.
     * @param dwHandle The GL texture object name to delete.
     * @ghidraAddress 0x21a68
     */
    void DeleteTexture(unsigned int dwHandle);
    /**
     * Generates one GL framebuffer object name into @p pOutFramebuffer.
     * @param pOutFramebuffer Receives the generated framebuffer object name.
     * @ghidraAddress 0x212ac
     */
    void GenFramebuffer(unsigned int *pOutFramebuffer);
    /**
     * Deletes the GL framebuffer object @p dwFramebuffer.
     * @param dwFramebuffer The framebuffer object name to delete.
     * @ghidraAddress 0x212b4
     */
    void DeleteFramebuffer(unsigned int dwFramebuffer);
    /**
     * Binds @p dwFramebuffer as the current @c GL_FRAMEBUFFER_OES draw target.
     * @param dwFramebuffer The framebuffer object name to bind.
     * @ghidraAddress 0x212dc
     */
    void BindFramebuffer(unsigned int dwFramebuffer);
    /**
     * Generates one GL renderbuffer object name into @p pOutRenderbuffer.
     * @param pOutRenderbuffer Receives the generated renderbuffer object name.
     * @ghidraAddress 0x212e4
     */
    void GenRenderbuffer(unsigned int *pOutRenderbuffer);
    /**
     * Deletes the GL renderbuffer object @p dwRenderbuffer.
     * @param dwRenderbuffer The renderbuffer object name to delete.
     * @ghidraAddress 0x212ec
     */
    void DeleteRenderbuffer(unsigned int dwRenderbuffer);
    /**
     * Binds @p dwRenderbuffer as the current @c GL_RENDERBUFFER_OES.
     * @param dwRenderbuffer The renderbuffer object name to bind.
     * @ghidraAddress 0x21314
     */
    void BindRenderbuffer(unsigned int dwRenderbuffer);
    /**
     * Attaches @p dwRenderbuffer to the bound framebuffer at the @p nRenderKind attachment.
     * @param nRenderKind The render kind selecting the attachment point.
     * @param dwRenderbuffer The renderbuffer object name to attach.
     * @ghidraAddress 0x21380
     */
    void AttachRenderbufferToFramebuffer(RenderKind nRenderKind, unsigned int dwRenderbuffer);
    /**
     * Reads the bound renderbuffer's width into @p pOutWidth.
     * @param pOutWidth Receives the bound renderbuffer's width in pixels.
     * @ghidraAddress 0x213d8
     */
    void GetRenderbufferWidth(int *pOutWidth);
    /**
     * Reads the bound renderbuffer's height into @p pOutHeight.
     * @param pOutHeight Receives the bound renderbuffer's height in pixels.
     * @ghidraAddress 0x213ec
     */
    void GetRenderbufferHeight(int *pOutHeight);
    /**
     * Generates one GL buffer object name into @p pOutBuffer.
     * @param pOutBuffer Receives the generated buffer object name.
     * @ghidraAddress 0x2147c
     */
    void GenBuffer(unsigned int *pOutBuffer);
    /**
     * Binds @p dwBuffer as the current @c GL_ELEMENT_ARRAY_BUFFER.
     * @param dwBuffer The buffer object name to bind.
     * @ghidraAddress 0x21a14
     */
    void BindIndexBuffer(unsigned int dwBuffer);
    /**
     * Binds @p dwBuffer as the current @c GL_ARRAY_BUFFER.
     * @param dwBuffer The buffer object name to bind.
     * @ghidraAddress 0x21510
     */
    void BindArrayBuffer(unsigned int dwBuffer);
    /**
     * Uploads @p nSize bytes of index data to the bound element-array buffer.
     * @param pData The index data to upload.
     * @param nSize The number of bytes to upload.
     * @param nUsage The GL buffer usage hint.
     * @ghidraAddress 0x21a30
     */
    void UploadIndexBufferData(const void *pData, unsigned int nSize, int nUsage);
    /**
     * Uploads @p nSize bytes of vertex data to the bound array buffer.
     * @param pData The vertex data to upload.
     * @param nSize The number of bytes to upload.
     * @param nUsage The GL buffer usage hint.
     * @ghidraAddress 0x2152c
     */
    void UploadArrayBufferData(const void *pData, unsigned int nSize, int nUsage);
    /**
     * Deletes the GL buffer object @p dwBuffer.
     * @param dwBuffer The buffer object name to delete.
     * @ghidraAddress 0x21484
     */
    void DeleteBuffer(unsigned int dwBuffer);
    /**
     * Generates one GL texture object name into @p pOutHandle.
     * @param pOutHandle Receives the generated texture object name.
     * @ghidraAddress 0x21a60
     */
    void GenTexture(unsigned int *pOutHandle);
    /**
     * Binds @p dwHandle as the current @c GL_TEXTURE_2D.
     * @param dwHandle The texture object name to bind.
     * @ghidraAddress 0x21ab4
     */
    void BindTexture2d(unsigned int dwHandle);
    /**
     * Sets one texture sampler parameter (@p nParameter: 0 min filter, 1 mag filter, 2 wrap
     *        S, 3 wrap T) to @p nValue on the bound texture.
     * @param nParameter The sampler parameter index.
     * @param nValue The sampler parameter value.
     * @ghidraAddress 0x21ae8
     */
    void SetTextureParameter(int nParameter, int nValue);
    /**
     * Uploads @p nWidth by @p nHeight pixels in the given @p nFormat to the bound texture.
     * @param nFormat The GL pixel format of @p pData.
     * @param nWidth The image width in pixels.
     * @param nHeight The image height in pixels.
     * @param pData The pixel data to upload.
     * @ghidraAddress 0x21bd0
     */
    void UploadTexture2d(int nFormat, int nWidth, int nHeight, const void *pData);
    /**
     * Draws indexed primitives of the given engine primitive kind from the bound element
     *        buffer (Ghidra names this @c SetGlParameterByIndex).
     * @param nPrimitive The engine primitive index; an out-of-range value draws points.
     * @param nCount The number of indices to draw.
     * @param pIndices The index data (or the byte offset into the bound element buffer).
     * @ghidraAddress 0x21ea8
     */
    void DrawIndexedPrimitives(int nPrimitive, int nCount, const void *pIndices);
    /**
     * The maximum number of palette matrices a single instanced draw call may use.
     *
     * Read from the renderer's capability block (the GL_OES_matrix_palette limit). The sprite batch
     * flushes a draw once this many per-instance matrices have been queued, and a skinned mesh
     * loads this many bone matrices.
     *
     * @return The maximum number of palette matrices per draw call.
     */
    int GetMaxPaletteMatrices() const {
        return m_nMaxPaletteMatrices;
    }

    /**
     * Whether the driver advertises @c GL_OES_matrix_palette.
     *
     * The binary queries the extension only to decide whether to read the palette size, and every
     * draw path then uses the palette unconditionally. A build running where the extension is
     * absent needs to know, so the flag is exposed.
     *
     * @return @c true when the driver advertises @c GL_OES_matrix_palette.
     */
    bool HasMatrixPalette() const {
        return m_bHasMatrixPalette;
    }

    /**
     * Probes the live GL ES context for its capabilities and sets the initial GL state.
     *
     * Scans @c GL_EXTENSIONS for @c GL_OES_matrix_palette (recording the flag and, when present,
     * the
     * @c GL_MAX_VERTEX_UNITS_OES limit), reads @c GL_MAX_TEXTURE_SIZE, loads a default projection
     * matrix through matrix mode 2, and sets the line width to one. Run once by
     * @c EnsureShared after the render state is constructed.
     * @ghidraAddress 0x20f9c
     */
    void QueryCaps();

    /**
     * Enable or disable one engine render capability, skipping the GL call when the cached
     *        state is already @p bEnable.
     * @param nState The engine enable-state index (0 through @c kEnableStateMax - 1).
     * @param bEnable Whether to enable the capability.
     * @ghidraAddress 0x21d80
     */
    void SetGlEnableState(unsigned int nState, bool bEnable);
    /**
     * Enable or disable one engine vertex-array client state, skipping the GL call when the
     *        cached state is already @p bEnable.
     * @param nState The engine client-state index (0 through @c kClientStateMax - 1).
     * @param bEnable Whether to enable the array.
     * @ghidraAddress 0x21e14
     */
    void SetGlClientState(unsigned int nState, bool bEnable);
    /**
     * Select the current palette matrix, caching it so an unchanged value skips the GL call.
     * @param nState The palette-matrix index.
     * @ghidraAddress 0x21460
     */
    void SetCurrentPaletteMatrix(int nState);
    /**
     * Set the GL blend function, caching the factors so an unchanged pair skips the GL call.
     * @param nSrcFactor The engine blend source factor (0 through @c kBlendSrcMax - 1).
     * @param nDstFactor The engine blend destination factor (0 through @c kBlendDestMax - 1).
     * @ghidraAddress 0x21c98
     */
    void SetBlendFunc(int nSrcFactor, int nDstFactor);
    /**
     * Select the active matrix mode and load @p pMatrix into it; an unchanged mode skips the
     *        @c glMatrixMode call but the matrix is always loaded.
     * @param nMode The engine matrix-mode index (1 through 3, else model-view).
     * @param pMatrix The 16-float matrix to load after switching mode.
     * @ghidraAddress 0x21250
     */
    void SetMatrixMode(int nMode, const float *pMatrix);
    /**
     * Set the GL viewport rectangle, caching it so an unchanged rectangle skips the
     *        @c glViewport call.
     * @param nX The viewport x origin.
     * @param nY The viewport y origin.
     * @param nWidth The viewport width.
     * @param nHeight The viewport height.
     * @ghidraAddress 0x21408
     */
    void SetViewport(int nX, int nY, int nWidth, int nHeight);
    /**
     * Point the vertex (position) array at client memory, caching the pointer, stride, and
     *        size so an unchanged binding skips the @c glVertexPointer call.
     * @param pData The vertex position data.
     * @param nSize The number of position components per vertex.
     * @param nStride The byte stride between vertices.
     * @ghidraAddress 0x21634
     */
    void SetVertexPointer(const void *pData, int nSize, int nStride);
    /**
     * Point the colour array at client memory (four unsigned bytes per colour), caching the
     *        pointer and stride so an unchanged binding skips the @c glColorPointer call.
     * @param pData The vertex colour data.
     * @param nStride The byte stride between colours.
     * @ghidraAddress 0x2155c
     */
    void SetColorPointer(const void *pData, int nStride);
    /**
     * Point the active texture unit's coordinate array at client memory (two shorts per
     *        coordinate), caching the per-unit pointer and stride.
     * @param pData The texture-coordinate data.
     * @param nStride The byte stride between coordinates.
     * @ghidraAddress 0x21718
     */
    void SetTexCoordPointer(const void *pData, int nStride);
    /**
     * Point the skinning weight array at client memory.
     * @param pData The skinning weight data.
     * @param nSize The number of weight components per vertex.
     * @param nStride The byte stride between vertices.
     * @ghidraAddress 0x2183c
     */
    void SetWeightPointer(const void *pData, int nSize, int nStride);
    /**
     * Point the skinning matrix-index array at client memory.
     * @param pData The matrix-index data.
     * @param nSize The number of matrix-index components per vertex.
     * @param nStride The byte stride between vertices.
     * @ghidraAddress 0x21928
     */
    void SetMatrixIndexPointer(const void *pData, int nSize, int nStride);
    /**
     * Re-issue the vertex array against the bound array buffer, resetting the cached vertex
     *        pointer state when the bound buffer changed.
     * @param nStride The interleaved byte stride between vertices.
     * @param nSize The number of position components per vertex.
     * @ghidraAddress 0x216dc
     */
    void ClearVertexPointer(int nStride, int nSize);
    /**
     * Re-issue the colour array against the bound array buffer, resetting the cached colour
     *        pointer state when the bound buffer changed.
     * @param nStride The interleaved byte stride between vertices.
     * @param nColorOffset The colour's byte offset within a vertex, used as the buffer offset.
     * @param nBinding The array-buffer name the colour array is re-issued against.
     * @ghidraAddress 0x215f4
     */
    void ClearColorPointer(int nStride, int nColorOffset, int nBinding);
    /**
     * Re-issue the active unit's texcoord array against the bound array buffer, resetting
     * the cached per-unit pointer state when the bound buffer changed.
     * @param nStride The interleaved byte stride between vertices.
     * @param nTexCoordOffset The coordinate's byte offset within a vertex, used as the buffer
     *        offset.
     * @ghidraAddress 0x217e4
     */
    void ClearTexCoordPointer(int nStride, int nTexCoordOffset);
    /**
     * Re-issue the skinning weight array against the bound array buffer, resetting its
     * cached pointer state when the bound buffer changed.
     * @param nStride The interleaved byte stride between vertices.
     * @param nSize The number of weight components per vertex.
     * @param nWeightOffset The weight's byte offset within a vertex, used as the buffer offset.
     * @ghidraAddress 0x218ec
     */
    void ClearWeightPointer(int nStride, int nSize, int nWeightOffset);
    /**
     * Re-issue the skinning matrix-index array against the bound array buffer, resetting its
     *        cached pointer state when the bound buffer changed.
     * @param nStride The interleaved byte stride between vertices.
     * @param nSize The number of matrix-index components per vertex.
     * @param nMatrixIndexOffset The index's byte offset within a vertex, used as the buffer offset.
     * @ghidraAddress 0x219d8
     */
    void ClearMatrixIndexPointer(int nStride, int nSize, int nMatrixIndexOffset);

private:
    static constexpr int kMaxTextureUnits = 8;
    static constexpr int kTexParamCount = 4;

    void *m_pField000 = {};        // +0x000
    void *m_pField008 = {};        // +0x008
    float m_flCurrentColorR = {};  // +0x010 defaults to 1.0
    int m_nField014 = {};          // +0x014
    int m_nViewportX = {};         // +0x018
    int m_nViewportY = {};         // +0x01c
    int m_nViewportWidth = {};     // +0x020
    int m_nViewportHeight = {};    // +0x024
    int m_nMatrixMode = {};        // +0x028
    int m_nPaletteMatrix = {};     // +0x02c
    int m_nField030 = {};          // +0x030 set to 7 on construct
    int m_nField034 = {};          // +0x034
    bool m_bDepthTestEnabled = {}; // +0x038 defaults to true
    // unsigned char m_aReserved039[0x03] = {}; // +0x039
    int m_nCullFace = {};         // +0x03c defaults to 1
    int m_nArrayBufferBound = {}; // +0x040 0 when none
    // unsigned char m_aReserved044[0x04] = {}; // +0x044
    const void *m_pColorPointer = {}; // +0x048
    int m_nColorStride = {};          // +0x050
    int m_nColorBufferBinding = {};   // +0x054
    // unsigned char m_aReserved058[0x08] = {}; // +0x058
    int m_nHandle060 = {};                                  // +0x060 defaults to -1
    int m_nBufferBinding2 = {};                             // +0x064
    const void *m_pVertexPointer = {};                      // +0x068
    int m_nVertexStride = {};                               // +0x070
    int m_nVertexSize = {};                                 // +0x074 position components per vertex
    int m_nVertexBufferBinding = {};                        // +0x078
    int m_nActiveTexUnit = {};                              // +0x07c
    const void *m_apTexCoordPointer[kMaxTextureUnits] = {}; // +0x080
    int m_anTexCoordStride[kMaxTextureUnits] = {};          // +0x0c0
    int m_anTexCoordBufferBinding[kMaxTextureUnits] = {};   // +0x0e0
    const void *m_pWeightPointer = {};                      // +0x100
    int m_nWeightStride = {};                               // +0x108
    int m_nWeightSize = {};                                 // +0x10c weights per vertex
    int m_nWeightBufferBinding = {};                        // +0x110
    // unsigned char m_aReserved114[0x04] = {};                // +0x114
    const void *m_pMatrixIndexPointer = {};        // +0x118
    int m_nMatrixIndexStride = {};                 // +0x120
    int m_nMatrixIndexSize = {};                   // +0x124 matrix indices per vertex
    int m_nMatrixIndexBufferBinding = {};          // +0x128
    int m_nElementBufferBound = {};                // +0x12c
    int m_nActiveTextureUnit = {};                 // +0x130 the unit used for texture binds
    int m_anTexturePerUnit[kMaxTextureUnits] = {}; // +0x134
    // +0x154 per unit {min filter, mag filter, wrap S, wrap T}, defaulted to {4, 1, 7, 7}.
    int m_aTexParamCache[kMaxTextureUnits][kTexParamCount] = {};
    int m_nBlendSrc = {};  // +0x1d4
    int m_nBlendDest = {}; // +0x1d8
    int m_nField1dc = {};  // +0x1dc
    // unsigned char m_aReserved1e0[0x04] = {}; // +0x1e0
    bool m_aEnableStateFlags[0x24] = {}; // +0x1e4
    bool m_aClientStateFlags[0x07] = {}; // +0x208
    short m_nField20c = {};              // +0x20c
    bool m_bField20e = {};               // +0x20e
    // unsigned char m_aReserved20f[0x01] = {}; // +0x20f
    float m_aColorMatrixDiagonal[4] = {}; // +0x210 defaults to {1, 1, 0, 1}
    int m_nField220 = {};                 // +0x220
    // unsigned char m_aReserved224[0x0c] = {}; // +0x224
    long m_nHandle230 = {};     // +0x230 defaults to -1
    long m_nHandle238 = {};     // +0x238 defaults to -1
    int m_nHandle240 = {};      // +0x240 defaults to -1
    int m_nMaxTextureSize = {}; // +0x244 GL_MAX_TEXTURE_SIZE
    // unsigned char m_aReserved248[0x08] = {}; // +0x248
    bool m_bHasMatrixPalette = {}; // +0x250 GL_OES_matrix_palette present
    // unsigned char m_aReserved251[0x03] = {}; // +0x251
    int m_nMaxPaletteMatrices = {}; // +0x254
};
