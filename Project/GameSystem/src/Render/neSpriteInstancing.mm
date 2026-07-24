#include "neSpriteInstancing.h"

#include <cassert>

#import "neEngineBridge.h"
#include "neGLES.h"
#include "neTexture.h"

namespace ne {

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

} // namespace ne
