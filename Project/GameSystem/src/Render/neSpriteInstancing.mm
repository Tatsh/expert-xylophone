#include "neSpriteInstancing.h"

#include <cassert>
#include <cstring>

#include "matrixmath.h"
#include "neGLES.h"
#include "neRenderer.h"
#include "neTexture.h"
#import "s_vector2.h"

namespace ne {

namespace {

// The scale mapping a normalised [0, 1] UV coordinate to the signed 16-bit value stored per vertex
// (@ghidraAddress 0x2eed04 for U as a float, 0x2eed08 for V as a double; both are 32767).
constexpr double kUvPackScale = 32767.0;
// The divisor normalising an 8-bit colour channel to the [0, 1] alpha weight (@ghidraAddress
// 0x2eed00).
constexpr float kColorChannelMax = 255.0f;
// The number of quad corners per sprite and the interleaved per-vertex byte stride (a 2D position,
// a packed short2 UV, and a packed RGBA8 colour).
constexpr int kQuadCorners = 4;
constexpr int kVertexStride = 0x10;
// The number of triangle-list indices per sprite (two triangles).
constexpr int kIndicesPerSprite = 6;
// The engine primitive index for a triangle list.
constexpr int kPrimitiveTriangles = 6;

// The neIGLES render-capability indices the sprite pass touches by name; every capability from
// kEnableAlphaTest + 1 through kEnableStateResetMax is force-disabled in the state reset.
enum {
    kEnableAlphaTest = 0,        // GL_ALPHA_TEST: disabled.
    kEnableBlend = 1,            // GL_BLEND: enabled for the sprite pass.
    kEnableStateResetMax = 0x21, // The last general capability cleared by the reset loop.
    kEnableTexture2d = 0x22,     // GL_TEXTURE_2D: on only when the batch has a texture.
    kEnableMatrixPalette = 0x23, // GL_MATRIX_PALETTE_OES: on for the per-instance-matrix slow path.
};

// The neIGLES vertex-array client-state indices the sprite pass toggles.
enum {
    kClientColor = 0,       // The colour array.
    kClientMatrixIndex = 1, // The palette matrix-index array.
    kClientNormal = 2,      // The normal array (always off here).
    kClientTexCoord = 4,    // The texture-coordinate array.
    kClientVertex = 5,      // The position array.
    kClientWeight = 6,      // The skinning weight array.
};

// The neIGLES blend factors: the source is always GL_ONE; the destination is
// GL_ONE_MINUS_SRC_ALPHA for a normal alpha blend or GL_ONE for an additive blend.
enum {
    kBlendOne = 1,
    kBlendOneMinusSrcAlpha = 5,
};

// The neIGLES matrix modes used: the model-view matrix and the per-instance palette matrix.
enum {
    kMatrixModeModelView = 0,
    kMatrixModePalette = 3,
};

// The number of sampler parameters re-applied to a bound texture each draw.
constexpr int kTextureParamCount = 4;

// One interleaved vertex in the per-frame scratch: a 2D position, a signed-short UV pair, and a
// packed RGBA8 colour, sixteen bytes in total; four make one sprite quad.
struct InstancedVertex {
    float flX = {};
    float flY = {};
    short nU = {};
    short nV = {};
    unsigned char nR = {};
    unsigned char nG = {};
    unsigned char nB = {};
    unsigned char nA = {};
};

// The byte offsets of the UV and colour attributes within an @c InstancedVertex, passed to the GL
// texcoord- and colour-pointer calls (the position is at offset 0).
constexpr int kVertexUvOffset = 8;
constexpr int kVertexColorOffset = 0xc;

// Packs the four quad corners' UV coordinates and their shared colour. The quad's UV runs from
// uvOrigin to uvOrigin + uvSize; V is flipped to the texture's top-left origin. The corner order is
// (origin, +u, +v, +uv), matching the quad's two-triangle index order. The colour channels are
// pre-scaled by the normalised alpha, and the raw alpha is stored in the alpha byte.
void PackQuadUvColor(InstancedVertex *pQuad,
                     const S_VECTOR2 &uvOrigin,
                     const S_VECTOR2 &uvSize,
                     unsigned int nColorR,
                     unsigned int nColorG,
                     unsigned int nColorB,
                     unsigned int nAlpha) {
    const float flNormAlpha = static_cast<float>(nAlpha) / kColorChannelMax;
    const auto nR = static_cast<unsigned char>(static_cast<int>(flNormAlpha * nColorR));
    const auto nG = static_cast<unsigned char>(static_cast<int>(flNormAlpha * nColorG));
    const auto nB = static_cast<unsigned char>(static_cast<int>(flNormAlpha * nColorB));
    const auto nA = static_cast<unsigned char>(nAlpha);

    const auto nU0 = static_cast<short>(static_cast<int>(uvOrigin.x * kUvPackScale));
    const auto nU1 = static_cast<short>(static_cast<int>((uvOrigin.x + uvSize.x) * kUvPackScale));
    const auto nV0 = static_cast<short>(
        static_cast<int>((1.0 - static_cast<double>(uvOrigin.y)) * kUvPackScale));
    const auto nV1 = static_cast<short>(
        static_cast<int>((1.0 - static_cast<double>(uvOrigin.y + uvSize.y)) * kUvPackScale));

    pQuad[0].nU = nU0;
    pQuad[0].nV = nV0;
    pQuad[1].nU = nU1;
    pQuad[1].nV = nV0;
    pQuad[2].nU = nU0;
    pQuad[2].nV = nV1;
    pQuad[3].nU = nU1;
    pQuad[3].nV = nV1;
    for (int nCorner = 0; nCorner < kQuadCorners; ++nCorner) {
        pQuad[nCorner].nR = nR;
        pQuad[nCorner].nG = nG;
        pQuad[nCorner].nB = nB;
        pQuad[nCorner].nA = nA;
    }
}

} // namespace

// The sprite-batch precondition check (the binary's tempAssert): aborts when the condition is
// false. The compiler emits it both inlined into the colour accessors and out-of-line (0x2f638).
static void tempAssert(bool bCondition) {
    assert(bCondition);
}

// The static quad geometry the batch builds once: four vertices and six indices (two triangles)
// per sprite.
constexpr int kSpriteVertexCount = 4;
constexpr int kSpriteIndexCount = 6;

// Bytes per sprite in the per-frame vertex-assembly scratch the renderer fills each frame.
constexpr unsigned int kVertexScratchStride = 64;

// The default texture-sampler parameters (min filter, mag filter, s wrap, t wrap).
constexpr int kDefaultTexParams[] = {1, 1, 7, 7};

// One corner of a sprite's initial quad, as uploaded to the GL array buffer: a constant 1.0 and the
// index of the sprite the corner belongs to. The trailing bytes are padding the binary leaves
// uninitialised.
struct InitialSpriteVertex {
    float flConstantW;
    unsigned char nSpriteIndex;
};

/** @ghidraAddress 0x3097c */
C_SPRITE_INSTANCING::C_SPRITE_INSTANCING(unsigned int nCapacity) {
    // The base C_RENDER constructor and the derived vtable are installed by the compiler; the nine
    // attribute-array pointers and the remaining scalars are zero from their member initialisers.
    m_dwCapacity = nCapacity;

    // Per-sprite attribute arrays. The five vec2 arrays are value-initialised to zero; the rotation
    // and scale arrays are filled in the build loop below, and the colour array by the caller.
    m_pSpritePositionArray = new S_VECTOR2[nCapacity];
    m_pSpriteSizeArray = new S_VECTOR2[nCapacity];
    m_pSpriteAnchorArray = new S_VECTOR2[nCapacity];
    m_pSpriteUvOriginArray = new S_VECTOR2[nCapacity];
    m_pSpriteUvSizeArray = new S_VECTOR2[nCapacity];
    m_pSpriteRotationArray = new float[nCapacity];
    m_pSpriteScaleXArray = new float[nCapacity];
    m_pSpriteScaleYArray = new float[nCapacity];
    m_pSpriteColorArray = new unsigned int[nCapacity];
    m_pVertexScratch = new unsigned char[nCapacity * kVertexScratchStride];

    // Build the static geometry into temporaries: one quad per sprite. Each vertex carries a
    // constant 1.0 and its sprite index; the per-sprite positions are applied from the arrays at
    // draw time. The two triangles of each quad are (0, 1, 2) and (2, 1, 3).
    auto *pVertexTemplate = new InitialSpriteVertex[nCapacity * kSpriteVertexCount];
    auto *pIndexData = new unsigned short[nCapacity * kSpriteIndexCount];
    for (unsigned int nSprite = 0; nSprite < nCapacity; ++nSprite) {
        m_pSpriteRotationArray[nSprite] = 0.0f;
        m_pSpriteScaleXArray[nSprite] = 1.0f;
        m_pSpriteScaleYArray[nSprite] = 1.0f;

        const auto nBaseVertex = static_cast<unsigned short>(nSprite * kSpriteVertexCount);
        unsigned short *pIndices = &pIndexData[nSprite * kSpriteIndexCount];
        pIndices[0] = nBaseVertex;
        pIndices[1] = nBaseVertex + 1;
        pIndices[2] = nBaseVertex + 2;
        pIndices[3] = nBaseVertex + 2;
        pIndices[4] = nBaseVertex + 1;
        pIndices[5] = nBaseVertex + 3;

        InitialSpriteVertex *pVertices = &pVertexTemplate[nSprite * kSpriteVertexCount];
        for (int nCorner = 0; nCorner < kSpriteVertexCount; ++nCorner) {
            pVertices[nCorner].flConstantW = 1.0f;
            pVertices[nCorner].nSpriteIndex = static_cast<unsigned char>(nSprite);
        }
    }

    // Upload the index and vertex templates to GL element and array buffers, then free the
    // temporaries.
    neGLESRenderer *pRenderer = GetGlRenderer();
    pRenderer->GenBuffer(&m_dwIndexVbo);
    pRenderer->BindIndexBuffer(m_dwIndexVbo);
    pRenderer->UploadIndexBufferData(
        pIndexData,
        static_cast<unsigned int>(nCapacity * kSpriteIndexCount * sizeof(unsigned short)),
        0);
    delete[] pIndexData;
    pRenderer->GenBuffer(&m_dwArrayVbo);
    pRenderer->BindArrayBuffer(m_dwArrayVbo);
    pRenderer->UploadArrayBufferData(
        pVertexTemplate,
        static_cast<unsigned int>(nCapacity * kSpriteVertexCount * sizeof(InitialSpriteVertex)),
        0);
    delete[] pVertexTemplate;

    m_aTexParams[0] = kDefaultTexParams[0];
    m_aTexParams[1] = kDefaultTexParams[1];
    m_aTexParams[2] = kDefaultTexParams[2];
    m_aTexParams[3] = kDefaultTexParams[3];
}

/** @ghidraAddress 0x30c80 */
C_SPRITE_INSTANCING::~C_SPRITE_INSTANCING() {
    // Release the texture reference, free the per-sprite arrays and the vertex scratch, and delete
    // the GL index buffer; the compiler chains to the C_RENDER base destructor. (The binary guards
    // each free with the engine's safe-delete pattern; delete[] on a null pointer is a no-op.)
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    delete[] m_pSpritePositionArray;
    delete[] m_pSpriteSizeArray;
    delete[] m_pSpriteAnchorArray;
    delete[] m_pSpriteUvOriginArray;
    delete[] m_pSpriteUvSizeArray;
    delete[] m_pSpriteRotationArray;
    delete[] m_pSpriteScaleXArray;
    delete[] m_pSpriteScaleYArray;
    delete[] m_pSpriteColorArray;
    delete[] static_cast<unsigned char *>(m_pVertexScratch);
    GetGlRenderer()->DeleteBuffer(m_dwIndexVbo);
}

/** @ghidraAddress 0x31834 */
C_SPRITE_INSTANCING *CreateWorldSpriteBatch(unsigned int nCapacity) {
    return new C_SPRITE_INSTANCING(nCapacity);
}

/** @ghidraAddress 0x317dc */
void C_SPRITE_INSTANCING::SetRefCountedMember(C_TEXTURE *pTexture) {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    if (pTexture != nullptr) {
        pTexture->AddRef();
        m_pTexture = pTexture;
    }
}

/** @ghidraAddress 0x318c0 */
unsigned int C_SPRITE_INSTANCING::GetColorRed(int nIndex) const {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    return m_pSpriteColorArray[nIndex] & 0xff;
}

/** @ghidraAddress 0x31904 */
unsigned int C_SPRITE_INSTANCING::GetColorGreen(int nIndex) const {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    return (m_pSpriteColorArray[nIndex] >> 8) & 0xff;
}

/** @ghidraAddress 0x31948 */
unsigned int C_SPRITE_INSTANCING::GetColorBlue(int nIndex) const {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    return (m_pSpriteColorArray[nIndex] >> 16) & 0xff;
}

/** @ghidraAddress 0x3187c */
unsigned int C_SPRITE_INSTANCING::GetColorAlpha(int nIndex) const {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    return (m_pSpriteColorArray[nIndex] >> 24) & 0xff;
}

/** @ghidraAddress 0x5a0c4 */
void C_SPRITE_INSTANCING::SetSpritePosition(int nIndex, const S_VECTOR2 &position) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpritePositionArray[nIndex] = position;
}

/** @ghidraAddress 0x59fbc */
void C_SPRITE_INSTANCING::SetSpriteSize(int nIndex, const S_VECTOR2 &size) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteSizeArray[nIndex] = size;
}

/** @ghidraAddress 0x59f64 */
void C_SPRITE_INSTANCING::SetSpriteAnchor(int nIndex, const S_VECTOR2 &anchor) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteAnchorArray[nIndex] = anchor;
}

/** @ghidraAddress 0x5a014 */
void C_SPRITE_INSTANCING::SetSpriteUvOrigin(int nIndex, const S_VECTOR2 &uvOrigin) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteUvOriginArray[nIndex] = uvOrigin;
}

/** @ghidraAddress 0x5a06c */
void C_SPRITE_INSTANCING::SetSpriteUvSize(int nIndex, const S_VECTOR2 &uvSize) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteUvSizeArray[nIndex] = uvSize;
}

/** @ghidraAddress 0x5a174 */
void C_SPRITE_INSTANCING::SetSpriteRotation(int nIndex, float flRotation) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteRotationArray[nIndex] = flRotation;
}

/** @ghidraAddress 0x5a11c */
void C_SPRITE_INSTANCING::SetSpriteScale(int nIndex, float flScaleX, float flScaleY) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteScaleXArray[nIndex] = flScaleX;
    m_pSpriteScaleYArray[nIndex] = flScaleY;
}

/** @ghidraAddress 0x5a1c0 */
void C_SPRITE_INSTANCING::SetSpriteColor(
    int nIndex, unsigned int nRed, unsigned int nGreen, unsigned int nBlue, unsigned int nAlpha) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteColorArray[nIndex] =
        (nRed & 0xff) | ((nGreen & 0xff) << 8) | ((nBlue & 0xff) << 16) | (nAlpha << 24);
}

void C_SPRITE_INSTANCING::SetSpriteColor(int nIndex, unsigned int nColor) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteColorArray[nIndex] = nColor;
}

// Force-disables every general render capability for the sprite pass, leaving only blending (set up
// by the caller) enabled. Runs once before the sprite loop.
static void ResetRenderState(neGLESRenderer *pRenderer) {
    pRenderer->SetGlEnableState(kEnableAlphaTest, 0);
    pRenderer->SetGlEnableState(kEnableBlend, 1);
    for (int nState = kEnableBlend + 1; nState <= kEnableStateResetMax; ++nState) {
        pRenderer->SetGlEnableState(static_cast<unsigned int>(nState), 0);
    }
}

// Binds the batch's texture (or disables texturing when it has none) and points the texture-unit's
// coordinate array into the vertex scratch. Shared by both draw paths.
void C_SPRITE_INSTANCING::BindPassTexture(neGLESRenderer *pRenderer) {
    if (m_pTexture == nullptr) {
        pRenderer->SetGlEnableState(kEnableTexture2d, 0);
        pRenderer->SetGlClientState(kClientTexCoord, 0);
        return;
    }
    pRenderer->SetGlEnableState(kEnableTexture2d, 1);
    pRenderer->BindTexture2d(m_pTexture->GetGLHandle());
    pRenderer->SetGlClientState(kClientTexCoord, 1);
    auto *pScratch = static_cast<unsigned char *>(m_pVertexScratch);
    pRenderer->SetTexCoordPointer(reinterpret_cast<unsigned char *>(pScratch) + kVertexUvOffset,
                                  kVertexStride);
    for (int nParam = 0; nParam < kTextureParamCount; ++nParam) {
        UpdateTextureParameterIfChanged(m_pTexture, pRenderer, nParam, m_aTexParams[nParam]);
    }
}

/** @ghidraAddress 0x2faa8 */
void C_SPRITE_INSTANCING::Render() {
    neGLESRenderer *pRenderer = GetGlRenderer();
    const int nMaxPerBatch = pRenderer->GetMaxPaletteMatrices();
    SetMatrixIdentity(GetLocalMatrix());

    // Count the live (non-transparent) sprites and decide the path: any sprite with a rotation or a
    // non-unit scale forces the per-instance-matrix slow path.
    int nLiveCount = 0;
    bool bNeedsMatrix = false;
    for (int nSprite = 0; nSprite < m_nSpriteCount; ++nSprite) {
        if (GetColorAlpha(nSprite) == 0) {
            continue;
        }
        ++nLiveCount;
        if (m_pSpriteRotationArray[nSprite] != 0.0f || m_pSpriteScaleXArray[nSprite] != 1.0f ||
            m_pSpriteScaleYArray[nSprite] != 1.0f) {
            bNeedsMatrix = true;
            break;
        }
    }
    if (nLiveCount == 0) {
        return;
    }

    // Bind the current projection camera and copy its world matrix into this node's, then reset the
    // render state and select the blend mode (additive when the blend flag is set, else alpha).
    SetCurrentCamera(pRenderer, g_pCurrentProjection);
    std::memcpy(GetWorldMatrix(), GetParent()->GetWorldMatrix(), sizeof(float) * 16);
    ResetRenderState(pRenderer);
    pRenderer->SetBlendFunc(kBlendOne, m_nBlendMode == 0 ? kBlendOneMinusSrcAlpha : kBlendOne);

    if (bNeedsMatrix) {
        RenderWithMatrices(pRenderer, nMaxPerBatch);
    } else {
        RenderAxisAligned(pRenderer);
    }
}

// The slow path: one draw per sprite carries its own translation*rotation*scale matrix through the
// palette-matrix slot. Quads are built in local space around the sprite anchor and flushed in
// batches of nMaxPerBatch.
void C_SPRITE_INSTANCING::RenderWithMatrices(neGLESRenderer *pRenderer, int nMaxPerBatch) {
    // The screen-space path composes each sprite against the parent's world matrix directly.
    EmitMatrixSprites(pRenderer, nMaxPerBatch, GetParent()->GetWorldMatrix());
}

void C_SPRITE_INSTANCING::EmitMatrixSprites(neGLESRenderer *pRenderer,
                                            int nMaxPerBatch,
                                            const float *pComposeMatrix) {
    auto *pScratch = static_cast<InstancedVertex *>(m_pVertexScratch);
    // Point the fixed vertex/colour/texture arrays into the scratch and enable the arrays the
    // per-instance-matrix path needs (weight and matrix-index arrays plus the palette).
    pRenderer->SetGlEnableState(kEnableMatrixPalette, 1);
    pRenderer->SetGlClientState(kClientVertex, 1);
    pRenderer->SetVertexPointer(pScratch, 2, kVertexStride);
    pRenderer->SetGlClientState(kClientNormal, 0);
    pRenderer->SetGlClientState(kClientColor, 1);
    pRenderer->SetColorPointer(reinterpret_cast<unsigned char *>(pScratch) + kVertexColorOffset,
                               kVertexStride);
    BindPassTexture(pRenderer);
    pRenderer->BindArrayBuffer(m_dwArrayVbo);
    pRenderer->SetGlClientState(kClientWeight, 1);
    pRenderer->ClearWeightPointer(8, 1);
    pRenderer->SetGlClientState(kClientMatrixIndex, 1);
    pRenderer->ClearMatrixIndexPointer(8, 1);

    int nQueued = 0;
    for (int nSprite = 0; nSprite < m_nSpriteCount; ++nSprite) {
        const unsigned int nAlpha = GetColorAlpha(nSprite);
        if (nAlpha == 0) {
            continue;
        }

        // Build the four quad corners in local space: corner 0 at the anchor offset, spanning the
        // sprite size, with UV and colour packed by the shared helper.
        InstancedVertex *pQuad = &pScratch[nQueued * kQuadCorners];
        const S_VECTOR2 &size = m_pSpriteSizeArray[nSprite];
        pQuad[0].flX = 0.0f;
        pQuad[0].flY = 0.0f;
        pQuad[1].flX = size.x;
        pQuad[1].flY = 0.0f;
        pQuad[2].flX = 0.0f;
        pQuad[2].flY = size.y;
        pQuad[3].flX = size.x;
        pQuad[3].flY = size.y;
        PackQuadUvColor(pQuad,
                        m_pSpriteUvOriginArray[nSprite],
                        m_pSpriteUvSizeArray[nSprite],
                        GetColorRed(nSprite),
                        GetColorGreen(nSprite),
                        GetColorBlue(nSprite),
                        nAlpha);

        // Build the sprite's transform: translate the anchor to the position, applying rotation and
        // scale about the anchor when present, then compose it with the shared matrix.
        float spriteMatrix[16];
        BuildSpriteMatrix(nSprite, spriteMatrix);
        pRenderer->SetCurrentPaletteMatrix(nQueued);
        ComposeMatrices(spriteMatrix, const_cast<float *>(pComposeMatrix));
        pRenderer->SetMatrixMode(kMatrixModePalette, spriteMatrix);

        ++nQueued;
        if (nQueued == nMaxPerBatch) {
            pRenderer->BindIndexBuffer(m_dwIndexVbo);
            pRenderer->DrawIndexedPrimitives(
                kPrimitiveTriangles, nQueued * kIndicesPerSprite, nullptr);
            nQueued = 0;
        }
    }
    if (nQueued != 0) {
        pRenderer->BindIndexBuffer(m_dwIndexVbo);
        pRenderer->DrawIndexedPrimitives(kPrimitiveTriangles, nQueued * kIndicesPerSprite, nullptr);
    }
}

/** @ghidraAddress 0x30dc0 */
void C_SPRITE_INSTANCING::RenderWorldSpace() {
    neGLESRenderer *pRenderer = GetGlRenderer();
    const int nMaxPerBatch = pRenderer->GetMaxPaletteMatrices();
    SetMatrixIdentity(GetLocalMatrix());

    // Count the live (non-transparent) sprites; bail if there are none.
    int nLiveCount = 0;
    for (int nSprite = 0; nSprite < m_nSpriteCount; ++nSprite) {
        if (GetColorAlpha(nSprite) != 0) {
            ++nLiveCount;
        }
    }
    if (nLiveCount == 0) {
        return;
    }

    // Bind the current projection camera and copy its world matrix into this node's, then reset the
    // render state and select the blend mode.
    SetCurrentCamera(pRenderer, g_pCurrentProjection);
    std::memcpy(GetWorldMatrix(), GetParent()->GetWorldMatrix(), sizeof(float) * 16);
    ResetRenderState(pRenderer);
    pRenderer->SetBlendFunc(kBlendOne, m_nBlendMode == 0 ? kBlendOneMinusSrcAlpha : kBlendOne);

    // The shared compose matrix is the current model node's camera (view) matrix multiplied by the
    // parent's world matrix, so every world-space sprite is placed in the camera's frame.
    float worldCamMatrix[16];
    std::memcpy(worldCamMatrix, g_pCurrentModelNode->GetViewMatrix(), sizeof(worldCamMatrix));
    MultiplyMatrixInPlace(worldCamMatrix, GetParent()->GetWorldMatrix());

    EmitMatrixSprites(pRenderer, nMaxPerBatch, worldCamMatrix);
}

// Builds the per-sprite transform matrix for the slow path: a translation of the anchor to the
// sprite position, composed with any rotation about the anchor and any non-unit scale.
void C_SPRITE_INSTANCING::BuildSpriteMatrix(int nSprite, float *pOutMatrix) {
    const S_VECTOR2 &position = m_pSpritePositionArray[nSprite];
    const S_VECTOR2 &anchor = m_pSpriteAnchorArray[nSprite];
    const float flRotation = m_pSpriteRotationArray[nSprite];
    const float flScaleX = m_pSpriteScaleXArray[nSprite];
    const float flScaleY = m_pSpriteScaleYArray[nSprite];
    const bool bNoRotation = flRotation == 0.0f;
    const bool bUnitScale = flScaleX == 1.0f && flScaleY == 1.0f;

    if (bNoRotation && bUnitScale) {
        // No rotation or scale: the quad only needs to be translated so its anchor sits at position.
        MakeTranslationMatrix(pOutMatrix, position.x - anchor.x, position.y - anchor.y, 0.0f);
        return;
    }
    if (bNoRotation) {
        // Scale only: translate to the anchor-relative position, then scale the 3x3 block in place.
        MakeTranslationMatrix(pOutMatrix, position.x - anchor.x, position.y - anchor.y, 0.0f);
        SetMatrixScale3x3(pOutMatrix, flScaleX, flScaleY, 1.0f);
        return;
    }

    // Rotation (with or without scale): a translate-to-position * rotate matrix, composed with a
    // second matrix that scales and shifts the anchor back to the origin so the rotation pivots on
    // the anchor.
    MakeTranslationMatrix(pOutMatrix, position.x, position.y, 0.0f);
    SetMatrixRotationZ3x3(pOutMatrix, -flRotation);
    float anchorMatrix[16];
    if (bUnitScale) {
        MakeTranslationMatrix(anchorMatrix, -anchor.x, -anchor.y, 0.0f);
    } else {
        MakeScaleMatrix(anchorMatrix, flScaleX, flScaleY, 1.0f);
        SetMatrixTranslation(anchorMatrix, -(anchor.x * flScaleX), -(anchor.y * flScaleY), 0.0f);
    }
    MultiplyMatrixInPlace(pOutMatrix, anchorMatrix);
}

// The fast path: every live sprite is an axis-aligned quad, so world positions are baked straight
// into the scratch and a single indexed draw covers the whole batch under the node's world matrix.
void C_SPRITE_INSTANCING::RenderAxisAligned(neGLESRenderer *pRenderer) {
    auto *pScratch = static_cast<InstancedVertex *>(m_pVertexScratch);
    int nQueued = 0;
    for (int nSprite = 0; nSprite < m_nSpriteCount; ++nSprite) {
        const unsigned int nAlpha = GetColorAlpha(nSprite);
        if (nAlpha == 0) {
            continue;
        }

        // The quad spans from (position - anchor) to (position - anchor + size), baked in world
        // space; the two triangles read corners (0, 1, 2) and (2, 1, 3).
        const S_VECTOR2 &position = m_pSpritePositionArray[nSprite];
        const S_VECTOR2 &anchor = m_pSpriteAnchorArray[nSprite];
        const S_VECTOR2 &size = m_pSpriteSizeArray[nSprite];
        const float flLeft = position.x - anchor.x;
        const float flTop = position.y - anchor.y;
        const float flRight = flLeft + size.x;
        const float flBottom = flTop + size.y;
        InstancedVertex *pQuad = &pScratch[nQueued * kQuadCorners];
        pQuad[0].flX = flLeft;
        pQuad[0].flY = flTop;
        pQuad[1].flX = flRight;
        pQuad[1].flY = flTop;
        pQuad[2].flX = flLeft;
        pQuad[2].flY = flBottom;
        pQuad[3].flX = flRight;
        pQuad[3].flY = flBottom;
        PackQuadUvColor(pQuad,
                        m_pSpriteUvOriginArray[nSprite],
                        m_pSpriteUvSizeArray[nSprite],
                        GetColorRed(nSprite),
                        GetColorGreen(nSprite),
                        GetColorBlue(nSprite),
                        nAlpha);
        ++nQueued;
    }
    if (nQueued == 0) {
        return;
    }

    // Point the arrays at the freshly-built scratch and issue one indexed draw for the whole batch
    // under the node's world matrix.
    pRenderer->SetGlEnableState(kEnableMatrixPalette, 0);
    pRenderer->SetGlClientState(kClientVertex, 1);
    pRenderer->SetVertexPointer(pScratch, 2, kVertexStride);
    pRenderer->SetGlClientState(kClientNormal, 0);
    pRenderer->SetGlClientState(kClientColor, 1);
    pRenderer->SetColorPointer(reinterpret_cast<unsigned char *>(pScratch) + kVertexColorOffset,
                               kVertexStride);
    BindPassTexture(pRenderer);
    pRenderer->SetGlClientState(kClientWeight, 0);
    pRenderer->SetGlClientState(kClientMatrixIndex, 0);
    pRenderer->SetMatrixMode(kMatrixModeModelView, GetWorldMatrix());
    pRenderer->BindIndexBuffer(m_dwIndexVbo);
    pRenderer->DrawIndexedPrimitives(kPrimitiveTriangles, nQueued * kIndicesPerSprite, nullptr);
}

} // namespace ne
