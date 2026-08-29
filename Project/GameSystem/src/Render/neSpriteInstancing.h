/**
 * @file
 * The batched sprite draw node, @c ne::C_SPRITE_INSTANCING_2D.
 */

#pragma once

#include "neRender.h"

class neGLESRenderer;
struct S_VECTOR2;

namespace ne {

class C_TEXTURE;

/**
 * A batched sprite draw node (RTTI @c ne::C_SPRITE_INSTANCING_2D).
 *
 * A single node draws up to @c m_dwCapacity sprites of one texture in one instanced draw call; the
 * per-sprite position, size, anchor, UV-origin, UV-size, rotation, scale, and colour arrays are
 * uploaded together. It is a @c C_RENDER, so it lives in the scene graph and inherits visibility
 * and transform. The trailing @c +0xNN comments document the original 32-bit offsets for
 * reference only; state is reached through the accessors, never through those offsets.
 */
class C_SPRITE_INSTANCING_2D : public C_RENDER {
public:
    /**
     * Constructs a sprite batch that can draw up to @p nCapacity sprites.
     *
     * Allocates the per-sprite attribute arrays and the per-frame vertex scratch, then builds and
     * uploads the static quad vertex and index buffers (four vertices and six indices per sprite).
     * The world-space batch is a separate class, @c ne::C_SPRITE_INSTANCING_3D, built by its own
     * constructor at @c 0x3097c.
     * @param nCapacity The maximum number of sprites the batch can draw.
     * @ghidraAddress 0x2f668
     */
    explicit C_SPRITE_INSTANCING_2D(unsigned int nCapacity);
    /** Releases the per-sprite attribute arrays, the vertex scratch, and the GL buffers. */
    ~C_SPRITE_INSTANCING_2D() override;

    /**
     * Draws every live sprite of the batch (the @c C_RENDER vtable render slot).
     *
     * Skips fully-transparent sprites. When any live sprite has a rotation or non-unit scale it
     * takes the slow path, building a per-sprite transform matrix and submitting one instanced draw
     * per @c GetMaxPaletteMatrices sprites; otherwise it takes the fast path, emitting axis-aligned
     * quads directly and issuing a single indexed draw.
     * @ghidraAddress 0x2faa8
     */
    void Render() override;

    /**
     * The number of sprites the node currently draws.
     * @return The active sprite count.
     */
    int GetSpriteCount() const {
        return m_nSpriteCount;
    }

    /**
     * The maximum number of sprites the node can draw.
     * @return The node's sprite capacity.
     */
    unsigned int GetCapacity() const {
        return m_dwCapacity;
    }

    /**
     * Set how many of the node's sprites are drawn.
     * @param nSpriteCount The active sprite count (at most the node's capacity).
     */
    void SetSpriteCount(int nSpriteCount) {
        m_nSpriteCount = nSpriteCount;
    }

    /**
     * The node's blend mode.
     * @return The blend-mode identifier.
     */
    int GetBlendMode() const {
        return m_nBlendMode;
    }

    /**
     * Set the node's blend mode.
     * @param nBlendMode The blend-mode identifier.
     */
    void SetBlendMode(int nBlendMode) {
        m_nBlendMode = nBlendMode;
    }

    /**
     * Store one texture-environment parameter.
     * @param nIndex The parameter slot (0 through 3).
     * @param nValue The parameter value.
     * @ghidraAddress 0x31828
     * @ghidraAddress 0x307f8
     */
    void SetTexParam(int nIndex, int nValue) {
        m_aTexParams[nIndex] = nValue;
    }

    /**
     * Assign the batch's texture, updating reference counts.
     *
     * Retains @p pTexture and releases whatever texture the batch previously held. The compiler
     * emits this both at @c 0x317dc and, identically, out-of-line at @c 0x307ac.
     * @param pTexture The texture to assign.
     * @ghidraAddress 0x317dc
     * @ghidraAddress 0x307ac
     */
    void SetRefCountedMember(C_TEXTURE *pTexture);

    /**
     * The texture the batch currently draws with, or @c nullptr when it has none.
     *
     * The compiler emits this getter twice: inlined at @c 0x31820 and as an out-of-line copy at
     * @c 0x307f0 (the copy the sprite-part emitter calls); both collapse to this one accessor.
     * @return The bound texture, or @c nullptr when the batch has none.
     * @ghidraAddress 0x31820
     * @ghidraAddress 0x307f0
     */
    C_TEXTURE *GetBoundTexture() const {
        return m_pTexture;
    }

    /**
     * The red component of sprite @p nIndex's packed colour.
     *
     * The compiler emits these colour accessors (and their @c tempAssert bounds check) twice, once
     * with the assertion inlined and once calling the out-of-line copy, so each appears at two
     * addresses in the binary; that duplication is a template instantiation artefact and collapses
     * to one accessor here.
     * @param nIndex The sprite slot.
     * @return The red channel, in the range 0 through 255.
     * @ghidraAddress 0x318c0
     * @ghidraAddress 0x30898
     */
    unsigned int GetColorRed(int nIndex) const;
    /**
     * The green component of sprite @p nIndex's packed colour.
     * @param nIndex The sprite slot.
     * @return The green channel, in the range 0 through 255.
     * @ghidraAddress 0x31904
     * @ghidraAddress 0x308e4
     */
    unsigned int GetColorGreen(int nIndex) const;
    /**
     * The blue component of sprite @p nIndex's packed colour.
     * @param nIndex The sprite slot.
     * @return The blue channel, in the range 0 through 255.
     * @ghidraAddress 0x31948
     * @ghidraAddress 0x30930
     */
    unsigned int GetColorBlue(int nIndex) const;
    /**
     * The alpha component of sprite @p nIndex's packed colour.
     * @param nIndex The sprite slot.
     * @return The alpha channel, in the range 0 through 255.
     * @ghidraAddress 0x3187c
     * @ghidraAddress 0x3084c
     */
    unsigned int GetColorAlpha(int nIndex) const;

    /**
     * Set the alpha byte of sprite @p nIndex's packed colour, leaving RGB unchanged.
     * @param nIndex The sprite slot.
     * @param nAlpha The alpha byte.
     * @ghidraAddress 0x17b1c8
     * @ghidraAddress 0x17c9b8
     */
    void SetColorAlpha(int nIndex, unsigned char nAlpha);

    /**
     * Set sprite @p nIndex's world position: the point the anchor is translated to.
     * @param nIndex The sprite slot.
     * @param position The world position the anchor is translated to.
     * @ghidraAddress 0x5a0c4
     * @ghidraAddress 0x66f6c
     */
    void SetSpritePosition(int nIndex, const S_VECTOR2 &position);
    /**
     * Set sprite @p nIndex's world position from separate components (the same position
     * stream as @c SetSpritePosition, taking @p x and @p y directly).
     * @param nIndex The sprite slot.
     * @param x The world-position x component.
     * @param y The world-position y component.
     * @ghidraAddress 0x83c98
     */
    void SetSpritePositionXY(int nIndex, float x, float y);
    /**
     * Write sprite @p nSlot's world position from a vector, bounds-checking the slot index
     * against the capacity (asserting when out of range).
     *
     * The same position store as @c SetSpritePosition, but reached through the checked entry point
     * the star-effect emitter uses.
     * @param nSlot The sprite slot, checked against the batch capacity.
     * @param position The world position the anchor is translated to.
     * @ghidraAddress 0x189c14
     */
    void SetVertexPosition(int nSlot, const S_VECTOR2 &position);
    /**
     * Set only sprite @p nIndex's world-position X component.
     * @param nIndex The sprite slot.
     * @param x The world-position x component.
     * @ghidraAddress 0x180b04
     */
    void SetSpritePositionX(int nIndex, float x);
    /**
     * Set only sprite @p nIndex's world-position Y component.
     * @param nIndex The sprite slot.
     * @param y The world-position y component.
     * @ghidraAddress 0x180ab4
     */
    void SetSpritePositionY(int nIndex, float y);
    /**
     * Set sprite @p nIndex's pixel size: the quad spans from the origin to (width, height).
     * @param nIndex The sprite slot.
     * @param size The quad's pixel size.
     * @ghidraAddress 0x59fbc
     * @ghidraAddress 0x67020
     */
    void SetSpriteSize(int nIndex, const S_VECTOR2 &size);
    /**
     * Set sprite @p nIndex's anchor: the pivot offset subtracted from the position, so an
     * anchor of half the size centres the quad on the position.
     * @param nIndex The sprite slot.
     * @param anchor The pivot offset subtracted from the position.
     * @ghidraAddress 0x59f64
     * @ghidraAddress 0x66fc8
     */
    void SetSpriteAnchor(int nIndex, const S_VECTOR2 &anchor);
    /**
     * Set sprite @p nIndex's UV origin: the top-left texture coordinate of the quad.
     * @param nIndex The sprite slot.
     * @param uvOrigin The quad's top-left texture coordinate.
     * @ghidraAddress 0x5a014
     * @ghidraAddress 0x67078
     */
    void SetSpriteUvOrigin(int nIndex, const S_VECTOR2 &uvOrigin);
    /**
     * Set sprite @p nIndex's UV size: the texture-coordinate span added to the UV origin for
     * the quad's far corners.
     * @param nIndex The sprite slot.
     * @param uvSize The texture-coordinate span added to the UV origin.
     * @ghidraAddress 0x5a06c
     * @ghidraAddress 0x670d0
     */
    void SetSpriteUvSize(int nIndex, const S_VECTOR2 &uvSize);
    /**
     * Set sprite @p nIndex's rotation, in radians.
     * @param nIndex The sprite slot.
     * @param flRotation The rotation in radians.
     * @ghidraAddress 0x5a174
     * @ghidraAddress 0x67128
     */
    void SetSpriteRotation(int nIndex, float flRotation);
    /**
     * Set sprite @p nIndex's per-axis scale, applied to its pixel size.
     * @param nIndex The sprite slot.
     * @param flScaleX The x-axis scale.
     * @param flScaleY The y-axis scale.
     * @ghidraAddress 0x5a11c
     * @ghidraAddress 0x67174
     */
    void SetSpriteScale(int nIndex, float flScaleX, float flScaleY);
    /**
     * Set sprite @p nIndex's colour from four @c [0, 255] channel values.
     *
     * Packs the channels into the sprite's colour word as @c R @c | @c (G @c << @c 8) @c |
     * @c (B @c << @c 16) @c | @c (A @c << @c 24).
     * @param nIndex The sprite slot.
     * @param nRed The red channel, 0 through 255.
     * @param nGreen The green channel, 0 through 255.
     * @param nBlue The blue channel, 0 through 255.
     * @param nAlpha The alpha channel, 0 through 255.
     * @ghidraAddress 0x5a1c0
     * @ghidraAddress 0x671cc
     */
    void SetSpriteColor(int nIndex,
                        unsigned int nRed,
                        unsigned int nGreen,
                        unsigned int nBlue,
                        unsigned int nAlpha);
    /**
     * Set sprite @p nIndex's colour from a pre-packed RGBA word.
     *
     * A convenience the batch builders use to write a packed colour directly; the binary inlines
     * this store rather than calling the four-channel setter.
     * @param nIndex The sprite slot.
     * @param nColor The pre-packed RGBA colour word.
     */
    void SetSpriteColor(int nIndex, unsigned int nColor);

protected:
    /**
     * Force-disables every render capability the sprite pass does not want, then enables
     * blending and the arrays it does. Shared by the screen-space and world-space batches.
     * @param pRenderer The GL render-state backend.
     */
    static void ResetRenderState(neGLESRenderer *pRenderer);
    /** Diagnostic only: dumps every sprite of this batch on the armed frame. */
    void DebugSnapshot();
    /**
     * Binds the batch's texture (or disables texturing) and points the texture-unit's
     * coordinate array into the vertex scratch; shared by both draw paths.
     * @param pRenderer The GL render-state backend.
     */
    void BindPassTexture(neGLESRenderer *pRenderer);
    /**
     * The slow path: one instanced draw per sprite, each carrying its own transform matrix
     * through the palette-matrix slot, flushed in batches of @p nMaxPerBatch.
     * @param pRenderer The GL render-state backend.
     * @param nMaxPerBatch The number of sprites emitted before a draw is flushed.
     */
    void RenderWithMatrices(neGLESRenderer *pRenderer, int nMaxPerBatch);
    /**
     * The shared per-sprite matrix-emit loop for the slow and world-space paths: builds each
     * quad into the per-frame vertex scratch and its transform, composes it with @p pComposeMatrix,
     * and flushes a draw every @p nMaxPerBatch sprites.
     * @param pRenderer The GL render-state backend.
     * @param nMaxPerBatch The number of sprites emitted before a draw is flushed.
     * @param pComposeMatrix The 16-float matrix each sprite transform is composed with.
     */
    void
    EmitMatrixSprites(neGLESRenderer *pRenderer, int nMaxPerBatch, const float *pComposeMatrix);
    /**
     * The fast path: axis-aligned quads baked in world space and drawn in one indexed call.
     * @param pRenderer The GL render-state backend.
     */
    void RenderAxisAligned(neGLESRenderer *pRenderer);
    /**
     * Builds sprite @p nSprite's translation*rotation*scale transform into @p pOutMatrix.
     * @param nSprite The sprite slot.
     * @param pOutMatrix Receives the sprite's 16-float transform.
     */
    void BuildSpriteMatrix(int nSprite, float *pOutMatrix);

    S_VECTOR2 *m_pSpritePositionArray = {}; /*!< Per-sprite world positions. +0xd8 */
    S_VECTOR2 *m_pSpriteSizeArray = {};     /*!< Per-sprite pixel sizes. +0xe0 */
    S_VECTOR2 *m_pSpriteAnchorArray = {};   /*!< Per-sprite pivot offsets. +0xe8 */
    S_VECTOR2 *m_pSpriteUvOriginArray = {}; /*!< Per-sprite top-left texture coordinates. +0xf0 */
    S_VECTOR2 *m_pSpriteUvSizeArray = {};   /*!< Per-sprite texture-coordinate spans. +0xf8 */
    float *m_pSpriteRotationArray = {};     /*!< Per-sprite rotations, in radians. +0x100 */
    float *m_pSpriteScaleXArray = {};       /*!< Per-sprite x-axis scales. +0x108 */
    float *m_pSpriteScaleYArray = {};       /*!< Per-sprite y-axis scales. +0x110 */
    unsigned int *m_pSpriteColorArray = {}; /*!< Per-sprite packed RGBA colours. +0x118 */
    unsigned int m_dwCapacity = {};         /*!< The maximum number of sprites. +0x120 */
    int m_nSpriteCount = {};                /*!< The number of sprites currently drawn. +0x124 */
    void *m_pVertexScratch = {};            /*!< The per-frame vertex-assembly scratch. +0x128 */
    unsigned int m_dwIndexVbo = {};         /*!< The static quad index buffer name. +0x130 */
    unsigned int m_dwArrayVbo = {};         /*!< The static quad vertex buffer name. +0x134 */
    C_TEXTURE *m_pTexture = {};             /*!< The texture the batch draws with. +0x138 */
    int m_aTexParams[4] = {};               /*!< The texture-environment parameters. +0x140 */
    int m_nBlendMode = {};                  /*!< The blend-mode identifier. +0x150 */
    /**
     * Selects which of the binary's two vtables this object would have had.
     *
     * @c true is the screen-space batch (constructor 0x2f668, which leaves the byte at +0x154
     * alone) and @c false is the world-space batch (constructor 0x3097c, whose only extra store is
     * strb wzr at +0x154). @c Render dispatches on it. +0x154
     */
    bool m_bBatchFlag = true;
    /**
     * An 8-byte member present in the binary's 0x160-byte object but read or written by no
     * @c C_SPRITE_INSTANCING_2D method.
     *
     * Verified by an exhaustive whole-binary cross-reference of +0x158 accesses. The sibling
     * render-node subclasses (RenderPolygon2dMesh / RenderPolygon3dMesh) keep a live mesh-texture
     * member here; this batch node holds its texture at @c m_pTexture (+0x138) instead, leaving
     * this slot of the shared node layout unused. It is kept so the object matches the binary's
     * allocation size. (+0x155..+0x157 is alignment padding.) +0x158
     */
    long long m_unused158 = {};
};

/**
 * Allocate and initialise a world-space sprite batch node.
 *
 * The node is allocated, initialised to hold up to @p nCapacity sprites, and returned ready to be
 * inserted into the scene graph.
 * @param nCapacity The maximum number of sprites the batch can draw.
 * @return The new sprite batch node.
 * @ghidraAddress 0x31834
 */
C_SPRITE_INSTANCING_2D *CreateWorldSpriteBatch(unsigned int nCapacity);

/**
 * Allocate and initialise a screen-space sprite batch node.
 *
 * Like @c CreateWorldSpriteBatch, but the node is constructed with the screen-space instancer
 * variant used by the result-window and menu layers.
 * @param nCapacity The maximum number of sprites the batch can draw.
 * @return The new sprite batch node.
 * @ghidraAddress 0x30804
 */
C_SPRITE_INSTANCING_2D *CreateSpriteInstancer(unsigned int nCapacity);

} // namespace ne
