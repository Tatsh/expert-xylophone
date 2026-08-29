#include "neSpriteInstancing.h"

#include <cassert>
#include <cstddef>
#include <cstring>

#include "matrixmath.h"
#include "neDebugLog.h"
#include "neGLES.h"
#include "neRender.h"
#include "neRenderer.h"
#include "neSpriteInstancing3D.h"
#include "neTexture.h"
#import "s_vector2.h"

namespace ne {

namespace {

// @ghidraAddress 0x2eed04
// @ghidraAddress 0x2eed08
constexpr double kUvPackScale = 32767.0;
// @ghidraAddress 0x2eed00
constexpr float kColorChannelMax = 255.0f;
constexpr int kQuadCorners = 4;
constexpr int kVertexStride = 0x10;
constexpr int kIndicesPerSprite = 6;
constexpr int kPrimitiveTriangles = 6;

enum {
    kEnableAlphaTest = 0,
    kEnableBlend = 1,
    kEnableStateResetMax = 0x21,
    kEnableTexture2d = 0x22,
    kEnableMatrixPalette = 0x23,
};

enum {
    kClientColor = 0,
    kClientMatrixIndex = 1,
    kClientNormal = 2,
    kClientTexCoord = 4,
    kClientVertex = 5,
    kClientWeight = 6,
};

enum {
    kBlendOne = 1,
    kBlendOneMinusSrcAlpha = 5,
};

enum {
    kMatrixModeModelView = 0,
    kMatrixModePalette = 3,
};

constexpr int kTextureParamCount = 4;

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

constexpr int kVertexUvOffset = 8;
constexpr int kVertexColorOffset = 0xc;

// V is flipped to the texture's top-left origin, and the colour channels are pre-scaled by the
// normalised alpha.
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

// The compiler emits this both inlined into the colour accessors and out-of-line.
/** @ghidraAddress 0x2f638 */
static void tempAssert(bool bCondition) {
    assert(bCondition);
}

namespace {

constexpr int kSpriteVertexCount = 4;
constexpr int kSpriteIndexCount = 6;

constexpr unsigned int kVertexScratchStride = 64;

// @ghidraAddress 0x2eecf0
constexpr int kScreenTexParams[] = {0, 0, 7, 7};

// The trailing padding bytes are left uninitialised, as the binary leaves them.
struct InitialSpriteVertex {
    float flConstantW;
    unsigned char nSpriteIndex;
};

constexpr int kTemplateVertexStride = static_cast<int>(sizeof(InitialSpriteVertex));
constexpr int kTemplateWeightOffset = static_cast<int>(offsetof(InitialSpriteVertex, flConstantW));
constexpr int kTemplateMatrixIndexOffset =
    static_cast<int>(offsetof(InitialSpriteVertex, nSpriteIndex));
constexpr int kTemplateComponentCount = 1;

} // namespace

/** @ghidraAddress 0x2f668 */
C_SPRITE_INSTANCING_2D::C_SPRITE_INSTANCING_2D(unsigned int nCapacity) {
    m_dwCapacity = nCapacity;

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

    neGLESRenderer *pRenderer = neGLESRenderer::GetShared();
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

    const int *pTexParams = kScreenTexParams;
    m_aTexParams[0] = pTexParams[0];
    m_aTexParams[1] = pTexParams[1];
    m_aTexParams[2] = pTexParams[2];
    m_aTexParams[3] = pTexParams[3];
}

/**
 * @ghidraAddress 0x30c80
 * @ghidraAddress 0x2f968
 * @ghidraAddress 0x2fa70
 */
C_SPRITE_INSTANCING_2D::~C_SPRITE_INSTANCING_2D() {
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
    // The binary never deletes m_dwArrayVbo, so do not add a matching DeleteBuffer.
    neGLESRenderer::GetShared()->DeleteBuffer(m_dwIndexVbo);
}

/** @ghidraAddress 0x30804 */
C_SPRITE_INSTANCING_2D *CreateSpriteInstancer(unsigned int nCapacity) {
    return new C_SPRITE_INSTANCING_2D(nCapacity);
}

/** @ghidraAddress 0x31834 */
C_SPRITE_INSTANCING_2D *CreateWorldSpriteBatch(unsigned int nCapacity) {
    return new C_SPRITE_INSTANCING_3D(nCapacity);
}

/** @ghidraAddress 0x317dc */
void C_SPRITE_INSTANCING_2D::SetRefCountedMember(C_TEXTURE *pTexture) {
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
unsigned int C_SPRITE_INSTANCING_2D::GetColorRed(int nIndex) const {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    return m_pSpriteColorArray[nIndex] & 0xff;
}

/** @ghidraAddress 0x31904 */
unsigned int C_SPRITE_INSTANCING_2D::GetColorGreen(int nIndex) const {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    return (m_pSpriteColorArray[nIndex] >> 8) & 0xff;
}

/** @ghidraAddress 0x31948 */
unsigned int C_SPRITE_INSTANCING_2D::GetColorBlue(int nIndex) const {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    return (m_pSpriteColorArray[nIndex] >> 16) & 0xff;
}

/** @ghidraAddress 0x3187c */
unsigned int C_SPRITE_INSTANCING_2D::GetColorAlpha(int nIndex) const {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    return (m_pSpriteColorArray[nIndex] >> 24) & 0xff;
}

/** @ghidraAddress 0x17b1c8 */
void C_SPRITE_INSTANCING_2D::SetColorAlpha(int nIndex, unsigned char nAlpha) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteColorArray[nIndex] =
        (m_pSpriteColorArray[nIndex] & 0x00ffffff) | (static_cast<unsigned int>(nAlpha) << 24);
}

/** @ghidraAddress 0x5a0c4 */
void C_SPRITE_INSTANCING_2D::SetSpritePosition(int nIndex, const S_VECTOR2 &position) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpritePositionArray[nIndex] = position;
}

/** @ghidraAddress 0x83c98 */
void C_SPRITE_INSTANCING_2D::SetSpritePositionXY(int nIndex, float x, float y) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpritePositionArray[nIndex] = S_VECTOR2{x, y};
}

/** @ghidraAddress 0x189c14 */
void C_SPRITE_INSTANCING_2D::SetVertexPosition(int nSlot, const S_VECTOR2 &position) {
    tempAssert(nSlot >= 0 && nSlot < static_cast<int>(m_dwCapacity));
    m_pSpritePositionArray[nSlot] = position;
}

/** @ghidraAddress 0x180b04 */
void C_SPRITE_INSTANCING_2D::SetSpritePositionX(int nIndex, float x) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpritePositionArray[nIndex].x = x;
}

/** @ghidraAddress 0x180ab4 */
void C_SPRITE_INSTANCING_2D::SetSpritePositionY(int nIndex, float y) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpritePositionArray[nIndex].y = y;
}

/** @ghidraAddress 0x59fbc */
void C_SPRITE_INSTANCING_2D::SetSpriteSize(int nIndex, const S_VECTOR2 &size) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteSizeArray[nIndex] = size;
}

/** @ghidraAddress 0x59f64 */
void C_SPRITE_INSTANCING_2D::SetSpriteAnchor(int nIndex, const S_VECTOR2 &anchor) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteAnchorArray[nIndex] = anchor;
}

/** @ghidraAddress 0x5a014 */
void C_SPRITE_INSTANCING_2D::SetSpriteUvOrigin(int nIndex, const S_VECTOR2 &uvOrigin) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteUvOriginArray[nIndex] = uvOrigin;
}

/** @ghidraAddress 0x5a06c */
void C_SPRITE_INSTANCING_2D::SetSpriteUvSize(int nIndex, const S_VECTOR2 &uvSize) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteUvSizeArray[nIndex] = uvSize;
}

/** @ghidraAddress 0x5a174 */
void C_SPRITE_INSTANCING_2D::SetSpriteRotation(int nIndex, float flRotation) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteRotationArray[nIndex] = flRotation;
}

/** @ghidraAddress 0x5a11c */
void C_SPRITE_INSTANCING_2D::SetSpriteScale(int nIndex, float flScaleX, float flScaleY) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteScaleXArray[nIndex] = flScaleX;
    m_pSpriteScaleYArray[nIndex] = flScaleY;
}

/** @ghidraAddress 0x5a1c0 */
void C_SPRITE_INSTANCING_2D::SetSpriteColor(
    int nIndex, unsigned int nRed, unsigned int nGreen, unsigned int nBlue, unsigned int nAlpha) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteColorArray[nIndex] =
        (nRed & 0xff) | ((nGreen & 0xff) << 8) | ((nBlue & 0xff) << 16) | (nAlpha << 24);
}

void C_SPRITE_INSTANCING_2D::SetSpriteColor(int nIndex, unsigned int nColor) {
    tempAssert(nIndex >= 0 && nIndex < static_cast<int>(m_dwCapacity));
    m_pSpriteColorArray[nIndex] = nColor;
}

void C_SPRITE_INSTANCING_2D::ResetRenderState(neGLESRenderer *pRenderer) {
    pRenderer->SetGlEnableState(kEnableAlphaTest, 0);
    pRenderer->SetGlEnableState(kEnableBlend, 1);
    for (int nState = kEnableBlend + 1; nState <= kEnableStateResetMax; ++nState) {
        pRenderer->SetGlEnableState(static_cast<unsigned int>(nState), 0);
    }
}

void C_SPRITE_INSTANCING_2D::BindPassTexture(neGLESRenderer *pRenderer) {
    if (m_pTexture == nullptr) {
        pRenderer->SetGlEnableState(kEnableTexture2d, 0);
        pRenderer->SetGlClientState(kClientTexCoord, 0);
        return;
    }
    pRenderer->SetGlEnableState(kEnableTexture2d, 1);
    pRenderer->BindTexture2d(m_pTexture->GetGLHandle());
    pRenderer->SetGlClientState(kClientTexCoord, 1);
    auto *pScratch = static_cast<unsigned char *>(m_pVertexScratch);
    pRenderer->SetTexCoordPointer(pScratch + kVertexUvOffset, kVertexStride);
    for (int nParam = 0; nParam < kTextureParamCount; ++nParam) {
        m_pTexture->SetCachedTextureParameter(pRenderer, nParam, m_aTexParams[nParam]);
    }
}

/** @ghidraAddress 0x2faa8 */
void C_SPRITE_INSTANCING_2D::DebugSnapshot() {
    NE_DBG(if (g_nDebugSnapshotFrame != 0 && g_nDebugFrameCounter == g_nDebugSnapshotFrame &&
               m_nSpriteCount > 0) {
        for (int nSprite = 0; nSprite < m_nSpriteCount; ++nSprite) {
            neDebugLog("snapshot batch=%p n=%d/%d pos=(%.2f,%.2f) anchor=(%.2f,%.2f) "
                       "size=(%.2f,%.2f) scale=(%.4f,%.4f) rot=%.4f uv=(%.5f,%.5f)+(%.5f,%.5f) "
                       "rgba=%08x tex=%p",
                       static_cast<const void *>(this),
                       nSprite,
                       m_nSpriteCount,
                       static_cast<double>(m_pSpritePositionArray[nSprite].x),
                       static_cast<double>(m_pSpritePositionArray[nSprite].y),
                       static_cast<double>(m_pSpriteAnchorArray[nSprite].x),
                       static_cast<double>(m_pSpriteAnchorArray[nSprite].y),
                       static_cast<double>(m_pSpriteSizeArray[nSprite].x),
                       static_cast<double>(m_pSpriteSizeArray[nSprite].y),
                       static_cast<double>(m_pSpriteScaleXArray[nSprite]),
                       static_cast<double>(m_pSpriteScaleYArray[nSprite]),
                       static_cast<double>(m_pSpriteRotationArray[nSprite]),
                       static_cast<double>(m_pSpriteUvOriginArray[nSprite].x),
                       static_cast<double>(m_pSpriteUvOriginArray[nSprite].y),
                       static_cast<double>(m_pSpriteUvSizeArray[nSprite].x),
                       static_cast<double>(m_pSpriteUvSizeArray[nSprite].y),
                       m_pSpriteColorArray[nSprite],
                       static_cast<const void *>(m_pTexture));
        }
    });
}

void C_SPRITE_INSTANCING_2D::Render() {
    DebugSnapshot();
    neGLESRenderer *pRenderer = neGLESRenderer::GetShared();
    const int nMaxPerBatch = pRenderer->GetMaxPaletteMatrices();
    SetMatrixIdentity(GetLocalMatrix());

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

void C_SPRITE_INSTANCING_2D::RenderWithMatrices(neGLESRenderer *pRenderer, int nMaxPerBatch) {
    EmitMatrixSprites(pRenderer, nMaxPerBatch, GetParent()->GetWorldMatrix());
}

void C_SPRITE_INSTANCING_2D::EmitMatrixSprites(neGLESRenderer *pRenderer,
                                               int nMaxPerBatch,
                                               const float *pComposeMatrix) {
    auto *pScratch = static_cast<InstancedVertex *>(m_pVertexScratch);
    // The explicit unbind is the binary's (0x310cc): the client pointers below only take effect
    // with no array buffer bound.
    pRenderer->BindArrayBuffer(0);
#ifdef ENABLE_PATCHES
    // Without GL_OES_matrix_palette, or with no array buffer bound, the weight and matrix-index
    // arrays would be enabled with NULL pointers and the draw would fault.
    const bool bMatrixPalette = pRenderer->HasMatrixPalette() && m_dwArrayVbo != 0;
#else
    constexpr bool bMatrixPalette = true;
#endif
    pRenderer->SetGlEnableState(kEnableMatrixPalette, bMatrixPalette ? 1 : 0);
    pRenderer->SetGlClientState(kClientVertex, 1);
    pRenderer->SetVertexPointer(pScratch, 2, kVertexStride);
    pRenderer->SetGlClientState(kClientNormal, 0);
    pRenderer->SetGlClientState(kClientColor, 1);
    pRenderer->SetColorPointer(reinterpret_cast<unsigned char *>(pScratch) + kVertexColorOffset,
                               kVertexStride);
    BindPassTexture(pRenderer);
    pRenderer->BindArrayBuffer(m_dwArrayVbo);
    if (bMatrixPalette) {
        pRenderer->SetGlClientState(kClientWeight, 1);
        pRenderer->ClearWeightPointer(
            kTemplateVertexStride, kTemplateComponentCount, kTemplateWeightOffset);
        pRenderer->SetGlClientState(kClientMatrixIndex, 1);
        pRenderer->ClearMatrixIndexPointer(
            kTemplateVertexStride, kTemplateComponentCount, kTemplateMatrixIndexOffset);
    } else {
        pRenderer->SetGlClientState(kClientWeight, 0);
        pRenderer->SetGlClientState(kClientMatrixIndex, 0);
        float identity[16];
        SetMatrixIdentity(identity);
        pRenderer->SetMatrixMode(kMatrixModeModelView, identity);
    }

    int nQueued = 0;
    for (int nSprite = 0; nSprite < m_nSpriteCount; ++nSprite) {
        const unsigned int nAlpha = GetColorAlpha(nSprite);
        if (nAlpha == 0) {
            continue;
        }

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

        float spriteMatrix[16];
        BuildSpriteMatrix(nSprite, spriteMatrix);
        if (bMatrixPalette) {
            pRenderer->SetCurrentPaletteMatrix(nQueued);
            ComposeMatrices(spriteMatrix, const_cast<float *>(pComposeMatrix));
            pRenderer->SetMatrixMode(kMatrixModePalette, spriteMatrix);
        } else {
            // Apply what the palette matrix would have applied, per corner, on the CPU.
            ComposeMatrices(spriteMatrix, const_cast<float *>(pComposeMatrix));
            for (int nCorner = 0; nCorner < kQuadCorners; ++nCorner) {
                float aCorner[] = {pQuad[nCorner].flX, pQuad[nCorner].flY, 0.0f, 1.0f};
                float aWorld[4];
                MultiplyVector4ByMatrix(aWorld, aCorner, spriteMatrix);
                pQuad[nCorner].flX = aWorld[0];
                pQuad[nCorner].flY = aWorld[1];
            }
        }

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

void C_SPRITE_INSTANCING_2D::BuildSpriteMatrix(int nSprite, float *pOutMatrix) {
    const S_VECTOR2 &position = m_pSpritePositionArray[nSprite];
    const S_VECTOR2 &anchor = m_pSpriteAnchorArray[nSprite];
    const float flRotation = m_pSpriteRotationArray[nSprite];
    const float flScaleX = m_pSpriteScaleXArray[nSprite];
    const float flScaleY = m_pSpriteScaleYArray[nSprite];
    const bool bNoRotation = flRotation == 0.0f;
    const bool bUnitScale = flScaleX == 1.0f && flScaleY == 1.0f;

    // The binary takes the short path only when rotation is zero and both scales are one (0x3160c,
    // 0x3161c, 0x3162c); a scaled-but-unrotated sprite goes through the general arm at 0x3167c.
    if (bNoRotation && bUnitScale) {
        MakeTranslationMatrix(pOutMatrix, position.x - anchor.x, position.y - anchor.y, 0.0f);
        return;
    }

    // The anchor is multiplied by the scale, by the fnmul pair at 0x316f4 and 0x316fc.
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

void C_SPRITE_INSTANCING_2D::RenderAxisAligned(neGLESRenderer *pRenderer) {
    auto *pScratch = static_cast<InstancedVertex *>(m_pVertexScratch);
    int nQueued = 0;
    for (int nSprite = 0; nSprite < m_nSpriteCount; ++nSprite) {
        const unsigned int nAlpha = GetColorAlpha(nSprite);
        if (nAlpha == 0) {
            continue;
        }

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
