/**
 * @file
 * The batched sprite draw node, @c ne::C_SPRITE_INSTANCING.
 */

#pragma once

#include "neRender.h"

struct S_VECTOR2;

namespace ne {

class C_TEXTURE;

/**
 * @brief A batched sprite draw node (RTTI @c ne::C_SPRITE_INSTANCING).
 *
 * A single node draws up to @c m_dwCapacity sprites of one texture in one instanced draw call; the
 * per-sprite position, size, anchor, UV-origin, UV-size, rotation, scale, and colour arrays are
 * uploaded together. It is a @c C_RENDER, so it lives in the scene graph and inherits visibility and
 * transform. The trailing @c // +0xNN comments document the original 32-bit offsets for reference
 * only; state is reached through the accessors, never through those offsets.
 */
class C_SPRITE_INSTANCING : public C_RENDER {
public:
    /**
     * @brief Constructs a sprite batch that can draw up to @p nCapacity sprites.
     *
     * Allocates the per-sprite attribute arrays and the per-frame vertex scratch, then builds and
     * uploads the static quad vertex and index buffers (four vertices and six indices per sprite).
     * @param nCapacity The maximum number of sprites the batch can draw.
     * @ghidraAddress 0x3097c
     */
    explicit C_SPRITE_INSTANCING(unsigned int nCapacity);
    ~C_SPRITE_INSTANCING() override;

    /**
     * @brief Draws every live sprite of the batch (the @c C_RENDER vtable render slot).
     *
     * Skips fully-transparent sprites. When any live sprite has a rotation or non-unit scale it
     * takes the slow path, building a per-sprite transform matrix and submitting one instanced draw
     * per @c GetMaxPaletteMatrices sprites; otherwise it takes the fast path, emitting axis-aligned
     * quads directly and issuing a single indexed draw.
     * @ghidraAddress 0x2faa8
     */
    void Render() override;

    /**
     * @brief Draws the batch as a world-space sprite set composed under the current model node's
     * camera matrix (the @c CreateWorldSpriteBatch node's render path).
     *
     * Like @c Render's slow path, every live sprite carries its own transform matrix through the
     * palette-matrix slot, but each is composed with the shared world*camera matrix (the current
     * model node's view matrix times the parent's world matrix) rather than the parent world
     * matrix alone, and there is no axis-aligned fast path.
     * @ghidraAddress 0x30dc0
     */
    void RenderWorldSpace();

    /**
     * @brief The number of sprites the node currently draws.
     */
    int GetSpriteCount() const {
        return m_nSpriteCount;
    }

    /**
     * @brief The maximum number of sprites the node can draw.
     */
    unsigned int GetCapacity() const {
        return m_dwCapacity;
    }

    /**
     * @brief Set how many of the node's sprites are drawn.
     * @param nSpriteCount The active sprite count (at most the node's capacity).
     */
    void SetSpriteCount(int nSpriteCount) {
        m_nSpriteCount = nSpriteCount;
    }

    /**
     * @brief The node's blend mode.
     */
    int GetBlendMode() const {
        return m_nBlendMode;
    }

    /**
     * @brief Set the node's blend mode.
     * @param nBlendMode The blend-mode identifier.
     */
    void SetBlendMode(int nBlendMode) {
        m_nBlendMode = nBlendMode;
    }

    /**
     * @brief Store one texture-environment parameter.
     * @param nIndex The parameter slot (0 through 3).
     * @param nValue The parameter value.
     * @ghidraAddress 0x31828
     */
    void SetTexParam(int nIndex, int nValue) {
        m_aTexParams[nIndex] = nValue;
    }

    /**
     * @brief Assign the batch's texture, updating reference counts.
     *
     * Retains @p pTexture and releases whatever texture the batch previously held. The compiler
     * emits this both at @c 0x317dc and, identically, out-of-line at @c 0x307ac.
     * @param pTexture The texture to assign.
     * @ghidraAddress 0x317dc
     * @ghidraAddress 0x307ac
     */
    void SetRefCountedMember(C_TEXTURE *pTexture);

    /**
     * @brief The texture the batch currently draws with, or @c nullptr when it has none.
     *
     * The compiler emits this getter twice: inlined at @c 0x31820 and as an out-of-line copy at
     * @c 0x307f0 (the copy the sprite-part emitter calls); both collapse to this one accessor.
     * @ghidraAddress 0x31820
     * @ghidraAddress 0x307f0
     */
    C_TEXTURE *GetBoundTexture() const {
        return m_pTexture;
    }

    /**
     * @brief The red component of sprite @p nIndex's packed colour.
     *
     * The compiler emits these colour accessors (and their @c tempAssert bounds check) twice, once
     * with the assertion inlined and once calling the out-of-line copy, so each appears at two
     * addresses in the binary; that duplication is a template instantiation artefact and collapses
     * to one accessor here.
     * @ghidraAddress 0x318c0
     */
    unsigned int GetColorRed(int nIndex) const;
    /**
     * @brief The green component of sprite @p nIndex's packed colour.
     * @ghidraAddress 0x31904
     */
    unsigned int GetColorGreen(int nIndex) const;
    /**
     * @brief The blue component of sprite @p nIndex's packed colour.
     * @ghidraAddress 0x31948
     */
    unsigned int GetColorBlue(int nIndex) const;
    /**
     * @brief The alpha component of sprite @p nIndex's packed colour.
     * @ghidraAddress 0x3187c
     */
    unsigned int GetColorAlpha(int nIndex) const;

    /**
     * @brief Set sprite @p nIndex's world position: the point the anchor is translated to.
     * @ghidraAddress 0x5a0c4
     */
    void SetSpritePosition(int nIndex, const S_VECTOR2 &position);
    /**
     * @brief Set sprite @p nIndex's pixel size: the quad spans from the origin to (width, height).
     * @ghidraAddress 0x59fbc
     */
    void SetSpriteSize(int nIndex, const S_VECTOR2 &size);
    /**
     * @brief Set sprite @p nIndex's anchor: the pivot offset subtracted from the position, so an
     * anchor of half the size centres the quad on the position.
     * @ghidraAddress 0x59f64
     */
    void SetSpriteAnchor(int nIndex, const S_VECTOR2 &anchor);
    /**
     * @brief Set sprite @p nIndex's UV origin: the top-left texture coordinate of the quad.
     * @ghidraAddress 0x5a014
     */
    void SetSpriteUvOrigin(int nIndex, const S_VECTOR2 &uvOrigin);
    /**
     * @brief Set sprite @p nIndex's UV size: the texture-coordinate span added to the UV origin for
     * the quad's far corners.
     * @ghidraAddress 0x5a06c
     */
    void SetSpriteUvSize(int nIndex, const S_VECTOR2 &uvSize);
    /**
     * @brief Set sprite @p nIndex's rotation, in radians.
     * @ghidraAddress 0x5a174
     */
    void SetSpriteRotation(int nIndex, float flRotation);
    /**
     * @brief Set sprite @p nIndex's per-axis scale, applied to its pixel size.
     * @ghidraAddress 0x5a11c
     */
    void SetSpriteScale(int nIndex, float flScaleX, float flScaleY);
    /**
     * @brief Set sprite @p nIndex's colour from four @c [0, 255] channel values.
     *
     * Packs the channels into the sprite's colour word as @c R @c | @c (G @c << @c 8) @c |
     * @c (B @c << @c 16) @c | @c (A @c << @c 24).
     * @ghidraAddress 0x5a1c0
     */
    void SetSpriteColor(int nIndex,
                        unsigned int nRed,
                        unsigned int nGreen,
                        unsigned int nBlue,
                        unsigned int nAlpha);
    /**
     * @brief Set sprite @p nIndex's colour from a pre-packed RGBA word.
     *
     * A convenience the batch builders use to write a packed colour directly; the binary inlines
     * this store rather than calling the four-channel setter.
     */
    void SetSpriteColor(int nIndex, unsigned int nColor);

private:
    // Binds the batch's texture (or disables texturing) and points the texture-unit's coordinate
    // array into the vertex scratch; shared by both draw paths.
    void BindPassTexture(neGLESRenderer *pRenderer);
    // The slow path: one instanced draw per sprite, each carrying its own transform matrix through
    // the palette-matrix slot, flushed in batches of @p nMaxPerBatch.
    void RenderWithMatrices(neGLESRenderer *pRenderer, int nMaxPerBatch);
    // The shared per-sprite matrix-emit loop for the slow and world-space paths: builds each quad
    // into the per-frame vertex scratch and its transform, composes it with @p pComposeMatrix, and
    // flushes a draw every @p nMaxPerBatch sprites.
    void
    EmitMatrixSprites(neGLESRenderer *pRenderer, int nMaxPerBatch, const float *pComposeMatrix);
    // The fast path: axis-aligned quads baked in world space and drawn in one indexed call.
    void RenderAxisAligned(neGLESRenderer *pRenderer);
    // Builds sprite @p nSprite's translation*rotation*scale transform into @p pOutMatrix.
    void BuildSpriteMatrix(int nSprite, float *pOutMatrix);

    S_VECTOR2 *m_pSpritePositionArray = {}; // +0xd8
    S_VECTOR2 *m_pSpriteSizeArray = {};     // +0xe0
    S_VECTOR2 *m_pSpriteAnchorArray = {};   // +0xe8
    S_VECTOR2 *m_pSpriteUvOriginArray = {}; // +0xf0
    S_VECTOR2 *m_pSpriteUvSizeArray = {};   // +0xf8
    float *m_pSpriteRotationArray = {};     // +0x100
    float *m_pSpriteScaleXArray = {};       // +0x108
    float *m_pSpriteScaleYArray = {};       // +0x110
    unsigned int *m_pSpriteColorArray = {}; // +0x118
    unsigned int m_dwCapacity = {};         // +0x120
    int m_nSpriteCount = {};                // +0x124
    void *m_pVertexScratch = {};            // +0x128
    unsigned int m_dwIndexVbo = {};         // +0x130
    unsigned int m_dwArrayVbo = {};         // +0x134
    C_TEXTURE *m_pTexture = {};             // +0x138
    int m_aTexParams[4] = {};               // +0x140
    int m_nBlendMode = {};                  // +0x150
    bool m_bBatchFlag = {};                 // +0x154
    // +0x158: an 8-byte member present in the binary's 0x160-byte object but read or written by no
    // C_SPRITE_INSTANCING method (verified by an exhaustive whole-binary cross-reference of +0x158
    // accesses). The sibling render-node subclasses (RenderPolygon2dMesh / RenderPolygon3dMesh) keep
    // a live mesh-texture member here; this batch node holds its texture at m_pTexture (+0x138)
    // instead, leaving this slot of the shared node layout unused. It is kept so the object matches
    // the binary's allocation size. (+0x155..+0x157 is alignment padding.)
    long long m_unused158 = {}; // +0x158
};

/**
 * @brief Allocate and initialise a world-space sprite batch node.
 *
 * The node is allocated, initialised to hold up to @p nCapacity sprites, and returned ready to be
 * inserted into the scene graph.
 * @param nCapacity The maximum number of sprites the batch can draw.
 * @return The new sprite batch node.
 * @ghidraAddress 0x31834
 */
C_SPRITE_INSTANCING *CreateWorldSpriteBatch(unsigned int nCapacity);

/**
 * @brief Allocate and initialise a screen-space sprite batch node.
 *
 * Like @c CreateWorldSpriteBatch, but the node is constructed with the screen-space instancer
 * variant used by the result-window and menu layers.
 * @param nCapacity The maximum number of sprites the batch can draw.
 * @return The new sprite batch node.
 * @ghidraAddress 0x30804
 */
C_SPRITE_INSTANCING *CreateSpriteInstancer(unsigned int nCapacity);

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
