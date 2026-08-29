#include "neDrawPolygon2D.h"

#include <cassert>

#include "matrixmath.h"
#include "neGLES.h"
#include "neRenderer.h"
#include "neTexture.h"
#import "s_vector2.h"

namespace ne {

namespace {

constexpr int kUnsetOffset = -1;

// @ghidraAddress 0x2eed04
constexpr float kTexcoordScaleU = 32767.0f;
// @ghidraAddress 0x2eed08
constexpr double kTexcoordScaleV = 32767.0;

// @ghidraAddress 0x2eecf0
constexpr int kDefaultTexParams[] = {0, 0, 7, 7};

// @ghidraAddress 0x2eed00
constexpr float kColorChannelMax = 255.0f;

constexpr int kMinDrawIndexCount = 2;

constexpr int kTextureParamCount = 4;

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
    kMatrixModeModelView = 0,
    kMatrixModePalette = 3,
};

enum {
    kBlendOne = 1,
    kBlendOneMinusSrcAlpha = 5,
};

enum {
    kBlendModeAlpha = 0,
    kBlendModeAdditive = 1,
};

} // namespace

/** @ghidraAddress 0x27374 */
C_DRAW_POLYGON_2D::C_DRAW_POLYGON_2D(unsigned int nDrawMode,
                                     unsigned int nVertexCount,
                                     unsigned int nVertexFormat,
                                     bool bVertexBufferExternal,
                                     unsigned int nIndexCount,
                                     bool bIndexBufferExternal) {
    m_nDrawMode = nDrawMode;
    m_nVertexFormat = nVertexFormat;
    m_nVertexCount = nVertexCount;
    m_nVertexStride = 0;
    m_nPositionOffset = kUnsetOffset;
    m_nColorOffset = kUnsetOffset;
    m_nTexcoordOffset = kUnsetOffset;
    m_nMatrixWeightOffset = kUnsetOffset;
    m_nMatrixIndexOffset = kUnsetOffset;
    m_nBoneComponentCount = 0;
    m_bVertexBufferExternal = bVertexBufferExternal;
    m_dwVertexVbo = 0;
    m_nIndexCount = nIndexCount;
    m_nDrawIndexCount = nIndexCount;
    m_bIndexBufferExternal = bIndexBufferExternal;
    m_dwIndexVbo = 0;
    m_flTranslateX = 0.0f;
    m_flTranslateY = 0.0f;
    m_flRotationZ = 0.0f;
    m_flScale = 1.0f;
    m_pBoneTranslate = nullptr;
    m_pBoneRotation = nullptr;
    m_pBoneScale = nullptr;
    m_nBlendMode = 0;
    m_aTexParams[0] = kDefaultTexParams[0];
    m_aTexParams[1] = kDefaultTexParams[1];
    m_aTexParams[2] = kDefaultTexParams[2];
    m_aTexParams[3] = kDefaultTexParams[3];
}

/** @ghidraAddress 0x27440 */
/** @ghidraAddress 0x27530 */
C_DRAW_POLYGON_2D::~C_DRAW_POLYGON_2D() {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    delete[] static_cast<unsigned char *>(m_pVertexArray);
    m_pVertexArray = nullptr;
    delete[] m_pColorArray;
    m_pColorArray = nullptr;
    delete[] m_pIndexArray;
    m_pIndexArray = nullptr;
    delete[] static_cast<void **>(m_pBoneTranslate);
    m_pBoneTranslate = nullptr;
    delete[] static_cast<float *>(m_pBoneRotation);
    m_pBoneRotation = nullptr;
    delete[] static_cast<float *>(m_pBoneScale);
    m_pBoneScale = nullptr;

    neGLESRenderer *pRenderer = neGLESRenderer::GetShared();
    if (!m_bVertexBufferExternal) {
        pRenderer->DeleteBuffer(m_dwVertexVbo);
    }
    if (!m_bIndexBufferExternal) {
        pRenderer->DeleteBuffer(m_dwIndexVbo);
    }
}

/** @ghidraAddress 0x27568 */
void C_DRAW_POLYGON_2D::AllocateBuffers() {
    neGLESRenderer *pRenderer = neGLESRenderer::GetShared();
    unsigned int nStride = 0;
    m_nVertexStride = 0;

    if ((m_nVertexFormat & kVertexHasPosition) != 0) {
        nStride = 8;
        m_nVertexStride = 8;
        m_nPositionOffset = 0;
    }
    if ((m_nVertexFormat & kVertexHasTexcoord) != 0) {
        m_nTexcoordOffset = static_cast<int>(nStride);
        nStride |= 4;
        m_nVertexStride = static_cast<int>(nStride);
    }
    if ((m_nVertexFormat & kVertexHasColor) != 0) {
        m_nColorOffset = static_cast<int>(nStride);
        nStride += 4;
        m_nVertexStride = static_cast<int>(nStride);
        m_pColorArray = new S_RGBA[m_nVertexCount];
    }
    if ((m_nVertexFormat & kVertexHasSkin) != 0) {
        m_nBoneComponentCount = 3;
        m_nMatrixWeightOffset = static_cast<int>(nStride);
        m_nMatrixIndexOffset = static_cast<int>(nStride) + 0xc;
        nStride += 0xf;
        m_nVertexStride = static_cast<int>(nStride);
        const int nMaxUnits = pRenderer->GetMaxPaletteMatrices();
        auto **ppTranslate = new void *[nMaxUnits];
        for (int i = 0; i < nMaxUnits; ++i) {
            ppTranslate[i] = nullptr;
        }
        m_pBoneTranslate = ppTranslate;
        m_pBoneRotation = new float[nMaxUnits];
        m_pBoneScale = new float[nMaxUnits];
    }

    m_pVertexArray = new unsigned char[static_cast<unsigned int>(m_nVertexCount) * nStride];
    if (!m_bVertexBufferExternal) {
        pRenderer->GenBuffer(&m_dwVertexVbo);
        m_bVertexDirty = true;
    }

    m_pIndexArray = new unsigned short[static_cast<unsigned int>(m_nIndexCount)];
    if (!m_bIndexBufferExternal) {
        pRenderer->GenBuffer(&m_dwIndexVbo);
        m_bIndexDirty = true;
    }
}

/** @ghidraAddress 0x28290 */
C_DRAW_POLYGON_2D *CreatePolygon2dMesh(unsigned int nDrawMode,
                                       unsigned int nVertexCount,
                                       unsigned int nVertexFormat,
                                       bool bVertexBufferExternal,
                                       unsigned int nIndexCount,
                                       bool bIndexBufferExternal) {
    auto *pMesh = new C_DRAW_POLYGON_2D(nDrawMode,
                                        nVertexCount,
                                        nVertexFormat,
                                        bVertexBufferExternal,
                                        nIndexCount,
                                        bIndexBufferExternal);
    pMesh->AllocateBuffers();
    return pMesh;
}

/** @ghidraAddress 0x28328 */
void C_DRAW_POLYGON_2D::SetPos(int nIndex, S_VECTOR2 position) {
    if ((m_nVertexFormat & kVertexHasPosition) == 0) {
        return;
    }
    assert(nIndex >= 0 && nIndex < m_nVertexCount);
    auto *pVertex = static_cast<unsigned char *>(m_pVertexArray) +
                    (m_nPositionOffset + m_nVertexStride * nIndex);
    auto *pPosition = reinterpret_cast<float *>(pVertex);
    pPosition[0] = position.x;
    pPosition[1] = position.y;
    m_bVertexDirty = true;
}

/** @ghidraAddress 0x28320 */
void C_DRAW_POLYGON_2D::SetPosFromVec(int nIndex, const S_VECTOR2 *pPosition) {
    SetPos(nIndex, *pPosition);
}

/** @ghidraAddress 0x28470 */
void C_DRAW_POLYGON_2D::SetRGBA(int nIndex,
                                unsigned char nRed,
                                unsigned char nGreen,
                                unsigned char nBlue,
                                unsigned char nAlpha) {
    if ((m_nVertexFormat & kVertexHasColor) == 0) {
        return;
    }
    assert(nIndex >= 0 && nIndex < m_nVertexCount);
    m_pColorArray[nIndex] = S_RGBA{nRed, nGreen, nBlue, nAlpha};
    // The binary writes both dirty bytes together as a single halfword of 0x0101.
    m_bVertexDirty = true;
    m_bColorDirty = true;
}

/** @ghidraAddress 0x284f8 */
void C_DRAW_POLYGON_2D::SetVertexAlpha(int nIndex, unsigned char nAlpha) {
    if ((m_nVertexFormat & kVertexHasColor) == 0) {
        return;
    }
    assert(nIndex >= 0 && nIndex < m_nVertexCount);
    m_pColorArray[nIndex].nAlpha = nAlpha;
    // The binary writes both dirty bytes together as a single halfword of 0x0101.
    m_bVertexDirty = true;
    m_bColorDirty = true;
}

/** @ghidraAddress 0x283b4 */
void C_DRAW_POLYGON_2D::SetUV(int nIndex, float flU, float flV) {
    if ((m_nVertexFormat & kVertexHasTexcoord) == 0) {
        return;
    }
    assert(nIndex >= 0 && nIndex < m_nVertexCount);
    unsigned char *pVertex =
        static_cast<unsigned char *>(m_pVertexArray) + nIndex * m_nVertexStride + m_nTexcoordOffset;
    short *pTexcoord = reinterpret_cast<short *>(pVertex);
    pTexcoord[0] = static_cast<short>(flU * kTexcoordScaleU);
    pTexcoord[1] = static_cast<short>((1.0 - static_cast<double>(flV)) * kTexcoordScaleV);
    m_bVertexDirty = true;
}

/** @ghidraAddress 0x283ac */
void C_DRAW_POLYGON_2D::SetUVFromVec(int nIndex, const S_VECTOR2 *pUv) {
    SetUV(nIndex, pUv->x, pUv->y);
}

/** @ghidraAddress 0x2824c */
void C_DRAW_POLYGON_2D::SetTexture(C_TEXTURE *pTexture) {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    if (pTexture != nullptr) {
        pTexture->AddRef();
        m_pTexture = pTexture;
    }
}

/** @ghidraAddress 0x28578 */
void C_DRAW_POLYGON_2D::SetIndex(int nIndex, unsigned short wValue) {
    assert(nIndex >= 0 && nIndex < m_nIndexCount);
    m_pIndexArray[nIndex] = wValue;
    m_bIndexDirty = true;
}

void C_DRAW_POLYGON_2D::PremultiplyVertexColors() {
    auto *pVertexBytes = static_cast<unsigned char *>(m_pVertexArray);
    for (int nVertex = 0; nVertex < m_nVertexCount; ++nVertex) {
        const S_RGBA &source = m_pColorArray[nVertex];
        const float flNormAlpha = static_cast<float>(source.nAlpha) / kColorChannelMax;
        unsigned char *pDst = pVertexBytes + m_nColorOffset + m_nVertexStride * nVertex;
        pDst[0] = static_cast<unsigned char>(static_cast<int>(source.nRed * flNormAlpha));
        pDst[1] = static_cast<unsigned char>(static_cast<int>(source.nGreen * flNormAlpha));
        pDst[2] = static_cast<unsigned char>(static_cast<int>(source.nBlue * flNormAlpha));
        pDst[3] = source.nAlpha;
    }
}

void C_DRAW_POLYGON_2D::LoadBoneMatrices(neGLESRenderer *pRenderer) {
    const int nBoneCount = pRenderer->GetMaxPaletteMatrices();
    const auto *pTranslate = static_cast<const S_VECTOR2 *>(m_pBoneTranslate);
    const auto *pRotation = static_cast<const float *>(m_pBoneRotation);
    const auto *pScale = static_cast<const float *>(m_pBoneScale);
    for (int nBone = 0; nBone < nBoneCount; ++nBone) {
        float boneMatrix[16];
        MakeTranslationMatrix(boneMatrix, pTranslate[nBone].x, pTranslate[nBone].y, 0.0f);
        if (pRotation[nBone] != 0.0f) {
            float rotationMatrix[16];
            MakeRotationMatrixZ(-pRotation[nBone], rotationMatrix);
            MultiplyMatrixInPlace(boneMatrix, rotationMatrix);
        }
        if (pScale[nBone] != 1.0f) {
            float scaleMatrix[16];
            MakeScaleMatrix(scaleMatrix, pScale[nBone], pScale[nBone], 1.0f);
            MultiplyMatrixInPlace(boneMatrix, scaleMatrix);
        }
        pRenderer->SetCurrentPaletteMatrix(nBone);
        pRenderer->SetMatrixMode(kMatrixModePalette, boneMatrix);
    }
}

/** @ghidraAddress 0x276e4 */
void C_DRAW_POLYGON_2D::Render() {
    if (static_cast<int>(m_nDrawIndexCount) < kMinDrawIndexCount) {
        return;
    }
    neGLESRenderer *pRenderer = neGLESRenderer::GetShared();
    SetCurrentCamera(pRenderer, g_pCurrentProjection);

    float *pLocal = GetLocalMatrix();
    MakeTranslationMatrix(pLocal, m_flTranslateX, m_flTranslateY, 0.0f);
    if (m_flRotationZ != 0.0f) {
        float rotationMatrix[16];
        MakeRotationMatrixZ(-m_flRotationZ, rotationMatrix);
        MultiplyMatrixInPlace(pLocal, rotationMatrix);
    }
    if (m_flScale != 1.0f) {
        float scaleMatrix[16];
        MakeScaleMatrix(scaleMatrix, m_flScale, m_flScale, 1.0f);
        MultiplyMatrixInPlace(pLocal, scaleMatrix);
    }
    float *pWorld = GetWorldMatrix();
    MultiplyMatrix4x4(pWorld, GetParent()->GetWorldMatrix(), pLocal);
    pRenderer->SetMatrixMode(kMatrixModeModelView, pWorld);

    const auto *pVertexBytes = static_cast<const unsigned char *>(m_pVertexArray);
    if (m_bVertexBufferExternal) {
        if (m_bColorDirty) {
            m_bColorDirty = false;
            PremultiplyVertexColors();
        }
        if ((m_nVertexFormat & kVertexHasPosition) != 0) {
            pRenderer->SetGlClientState(kClientVertex, 1);
            pRenderer->SetVertexPointer(pVertexBytes + m_nPositionOffset, 2, m_nVertexStride);
        } else {
            pRenderer->SetGlClientState(kClientVertex, 0);
        }
        pRenderer->SetGlClientState(kClientNormal, 0);
        if ((m_nVertexFormat & kVertexHasColor) != 0) {
            pRenderer->SetGlClientState(kClientColor, 1);
            pRenderer->SetColorPointer(pVertexBytes + m_nColorOffset, m_nVertexStride);
        } else {
            pRenderer->SetGlClientState(kClientColor, 0);
        }
        if (m_pTexture == nullptr) {
            pRenderer->SetGlClientState(kClientTexCoord, 0);
            pRenderer->SetGlEnableState(kEnableTexture2d, 0);
        } else {
            pRenderer->SetGlEnableState(kEnableTexture2d, 1);
            pRenderer->BindTexture2d(m_pTexture->GetGLHandle());
            pRenderer->SetGlClientState(kClientTexCoord, 1);
            pRenderer->SetTexCoordPointer(pVertexBytes + m_nTexcoordOffset, m_nVertexStride);
            for (int nParam = 0; nParam < kTextureParamCount; ++nParam) {
                m_pTexture->SetCachedTextureParameter(pRenderer, nParam, m_aTexParams[nParam]);
            }
        }
        if (m_nBoneComponentCount == 0) {
            pRenderer->SetGlClientState(kClientWeight, 0);
            pRenderer->SetGlClientState(kClientMatrixIndex, 0);
            pRenderer->SetGlEnableState(kEnableMatrixPalette, 0);
        } else {
            LoadBoneMatrices(pRenderer);
            pRenderer->SetGlEnableState(kEnableMatrixPalette, 1);
            pRenderer->SetGlClientState(kClientWeight, 1);
            pRenderer->SetWeightPointer(
                pVertexBytes + m_nMatrixWeightOffset, m_nBoneComponentCount, m_nVertexStride);
            pRenderer->SetGlClientState(kClientMatrixIndex, 1);
            pRenderer->SetMatrixIndexPointer(
                pVertexBytes + m_nMatrixIndexOffset, m_nBoneComponentCount, m_nVertexStride);
        }
    } else {
        pRenderer->BindArrayBuffer(m_dwVertexVbo);
        if (m_bVertexDirty) {
            m_bVertexDirty = false;
            if (m_bColorDirty) {
                m_bColorDirty = false;
                PremultiplyVertexColors();
            }
            pRenderer->UploadArrayBufferData(
                m_pVertexArray, m_nVertexStride * m_nVertexCount, m_bVertexBufferExternal);
        }
        if ((m_nVertexFormat & kVertexHasPosition) != 0) {
            pRenderer->SetGlClientState(kClientVertex, 1);
            pRenderer->ClearVertexPointer(m_nVertexStride, 2);
        } else {
            pRenderer->SetGlClientState(kClientVertex, 0);
        }
        pRenderer->SetGlClientState(kClientNormal, 0);
        if ((m_nVertexFormat & kVertexHasColor) != 0) {
            pRenderer->SetGlClientState(kClientColor, 1);
            pRenderer->ClearColorPointer(m_nVertexStride, m_nColorOffset, m_nColorOffset);
        } else {
            pRenderer->SetGlClientState(kClientColor, 0);
        }
        if ((m_nVertexFormat & kVertexHasTexcoord) != 0) {
            pRenderer->SetGlClientState(kClientTexCoord, 1);
            pRenderer->ClearTexCoordPointer(m_nVertexStride, m_nTexcoordOffset);
            if (m_pTexture != nullptr) {
                pRenderer->SetGlEnableState(kEnableTexture2d, 1);
                pRenderer->BindTexture2d(m_pTexture->GetGLHandle());
                for (int nParam = 0; nParam < kTextureParamCount; ++nParam) {
                    m_pTexture->SetCachedTextureParameter(pRenderer, nParam, m_aTexParams[nParam]);
                }
            } else {
                pRenderer->SetGlEnableState(kEnableTexture2d, 0);
            }
        } else {
            pRenderer->SetGlClientState(kClientTexCoord, 0);
            pRenderer->SetGlEnableState(kEnableTexture2d, 0);
        }
        if (m_nBoneComponentCount == 0) {
            pRenderer->SetGlClientState(kClientWeight, 0);
            pRenderer->SetGlClientState(kClientMatrixIndex, 0);
            pRenderer->SetGlEnableState(kEnableMatrixPalette, 0);
        } else {
            LoadBoneMatrices(pRenderer);
            pRenderer->SetGlEnableState(kEnableMatrixPalette, 1);
            pRenderer->SetGlClientState(kClientWeight, 1);
            pRenderer->ClearWeightPointer(
                m_nVertexStride, m_nBoneComponentCount, m_nMatrixWeightOffset);
            pRenderer->SetGlClientState(kClientMatrixIndex, 1);
            pRenderer->ClearMatrixIndexPointer(
                m_nVertexStride, m_nBoneComponentCount, m_nMatrixIndexOffset);
        }
    }

    pRenderer->SetGlEnableState(kEnableAlphaTest, 0);
    pRenderer->SetGlEnableState(kEnableBlend, 1);
    pRenderer->SetBlendFunc(
        kBlendOne, m_nBlendMode == kBlendModeAdditive ? kBlendOne : kBlendOneMinusSrcAlpha);
    for (int nState = kEnableBlend + 1; nState <= kEnableStateResetMax; ++nState) {
        pRenderer->SetGlEnableState(static_cast<unsigned int>(nState), 0);
    }

    if (m_bIndexBufferExternal) {
        pRenderer->BindIndexBuffer(0);
    } else {
        pRenderer->BindIndexBuffer(m_dwIndexVbo);
        if (m_bIndexDirty) {
            m_bIndexDirty = false;
            pRenderer->UploadIndexBufferData(
                m_pIndexArray, m_nIndexCount * sizeof(unsigned short), m_bIndexBufferExternal);
        }
    }
    pRenderer->DrawIndexedPrimitives(static_cast<int>(m_nDrawMode),
                                     static_cast<int>(m_nDrawIndexCount),
                                     m_bIndexBufferExternal ? m_pIndexArray : nullptr);
}

} // namespace ne
