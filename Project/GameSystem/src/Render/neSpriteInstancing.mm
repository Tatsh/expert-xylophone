#include "neSpriteInstancing.h"

#import "neEngineBridge.h"
#include "neTexture.h"

namespace ne {

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
    m_pSpriteTexCoordArray = new S_VECTOR2[nCapacity];
    m_pSpriteTexSizeArray = new S_VECTOR2[nCapacity];
    m_pSpriteCentreArray = new S_VECTOR2[nCapacity];
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

} // namespace ne
