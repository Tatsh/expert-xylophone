#include "neDrawPolygon2D.h"

#include <cassert>

#include "matrixmath.h"
#include "neGLES.h"
#include "neTexture.h"
#import "s_vector2.h"

namespace ne {

namespace {

// The sentinel stored in an unset per-vertex attribute offset.
constexpr int kUnsetOffset = -1;

// The default texture-sampler parameters (min filter, mag filter, s wrap, t wrap) the constructor
// seeds (@ghidraAddress 0x2eecf0).
constexpr int kDefaultTexParams[] = {0, 0, 7, 7};

// The divisor normalising an 8-bit colour channel to the [0, 1] alpha weight (@ghidraAddress
// 0x2eed00).
constexpr float kColorChannelMax = 255.0f;

// The minimum draw index count below which the mesh is skipped (fewer than one triangle).
constexpr int kMinDrawIndexCount = 2;

// The number of sampler parameters re-applied to a bound texture each draw.
constexpr int kTextureParamCount = 4;

// The neIGLES render-capability indices the pass touches by name; every capability from
// kEnableAlphaTest + 1 through kEnableStateResetMax is force-disabled by the reset loop.
enum {
    kEnableAlphaTest = 0,        // GL_ALPHA_TEST: disabled.
    kEnableBlend = 1,            // GL_BLEND: enabled for the draw.
    kEnableStateResetMax = 0x21, // The last general capability cleared by the reset loop.
    kEnableTexture2d = 0x22,     // GL_TEXTURE_2D: on only when the mesh has a texture.
    kEnableMatrixPalette = 0x23, // GL_MATRIX_PALETTE_OES: on only for a skinned mesh.
};

// The neIGLES vertex-array client-state indices the pass toggles.
enum {
    kClientColor = 0,       // The colour array.
    kClientMatrixIndex = 1, // The palette matrix-index array.
    kClientNormal = 2,      // The normal array (always off here).
    kClientTexCoord = 4,    // The texture-coordinate array.
    kClientVertex = 5,      // The position array.
    kClientWeight = 6,      // The skinning weight array.
};

// The neIGLES matrix modes used: the model-view matrix and the per-instance palette matrix.
enum {
    kMatrixModeModelView = 0,
    kMatrixModePalette = 3,
};

// The neIGLES blend factors: the source is always GL_ONE; the destination is GL_ONE for the
// additive blend mode (1) or GL_ONE_MINUS_SRC_ALPHA for the default alpha blend (0).
enum {
    kBlendOne = 1,
    kBlendOneMinusSrcAlpha = 5,
};

// The mesh blend modes selecting the destination blend factor.
enum {
    kBlendModeAlpha = 0,
    kBlendModeAdditive = 1,
};

} // namespace

/** @ghidraAddress 0x27374 */
C_DRAW_POLYGON_2D::C_DRAW_POLYGON_2D(unsigned int nDrawMode,
                                     unsigned int nVertexCount,
                                     unsigned int nVertexFormat,
                                     unsigned char bVertexBufferExternal,
                                     unsigned int nIndexCount,
                                     unsigned char bIndexBufferExternal) {
    // The base C_RENDER constructor and the derived vtable are installed by the compiler.
    m_nDrawMode = nDrawMode;
    m_nVertexFormat = nVertexFormat;
    m_nVertexCount = nVertexCount;
    m_nVertexStride = 0;
    // The per-vertex attribute offsets start unset; the buffer allocator derives the real ones.
    m_nPositionOffset = kUnsetOffset;
    m_nColorOffset = kUnsetOffset;
    m_nTexcoordOffset = kUnsetOffset;
    m_nMatrixWeightOffset = kUnsetOffset;
    m_nMatrixIndexOffset = kUnsetOffset;
    m_nBoneComponentCount = 0;
    m_bVertexBufferExternal = bVertexBufferExternal != 0;
    m_dwVertexVbo = 0;
    m_nIndexCount = nIndexCount;
    m_nDrawIndexCount = nIndexCount;
    m_bIndexBufferExternal = bIndexBufferExternal != 0;
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

/** @ghidraAddress 0x27568 */
void C_DRAW_POLYGON_2D::AllocateBuffers() {
    neGLESRenderer *pRenderer = GetGlRenderer();
    unsigned int nStride = 0;
    m_nVertexStride = 0;

    // Build the interleaved vertex stride and per-attribute byte offsets from the format bits.
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
        const int nMaxUnits = pRenderer->GetMaxVertexUnits();
        auto **ppTranslate = new void *[nMaxUnits];
        for (int i = 0; i < nMaxUnits; ++i) {
            ppTranslate[i] = nullptr;
        }
        m_pBoneTranslate = ppTranslate;
        m_pBoneRotation = new float[nMaxUnits];
        m_pBoneScale = new float[nMaxUnits];
    }

    // Allocate the interleaved vertex buffer; gen a GL vertex VBO and mark dirty unless caller-owned.
    m_pVertexArray = new unsigned char[static_cast<unsigned int>(m_nVertexCount) * nStride];
    if (!m_bVertexBufferExternal) {
        pRenderer->GenBuffer(&m_dwVertexVbo);
        m_bVertexDirty = true;
    }

    // Allocate the 16-bit index buffer; gen a GL index VBO and mark dirty unless caller-owned.
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
                                       unsigned char bVertexBufferExternal,
                                       unsigned int nIndexCount,
                                       unsigned char bIndexBufferExternal) {
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

/** @ghidraAddress 0x28578 */
void C_DRAW_POLYGON_2D::SetIndex(int nIndex, unsigned short wValue) {
    assert(nIndex >= 0 && nIndex < m_nIndexCount);
    m_pIndexArray[nIndex] = wValue;
    m_bIndexDirty = true;
}

void C_DRAW_POLYGON_2D::PremultiplyVertexColors() {
    // Each source colour in m_pColorArray is premultiplied by its own alpha (normalised by 255) and
    // written into the interleaved vertex buffer's colour slot; the alpha byte is stored unscaled.
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
    // One palette matrix per supported vertex unit: translate to the bone's position, then apply
    // its rotation and scale about that origin.
    const int nBoneCount = pRenderer->GetMaxPaletteMatrices();
    const auto *pTranslate = static_cast<const S_VECTOR2 *>(m_pBoneTranslate);
    const auto *pRotation = static_cast<const float *>(m_pBoneRotation);
    const auto *pScale = static_cast<const float *>(m_pBoneScale);
    for (int nBone = 0; nBone < nBoneCount; ++nBone) {
        float boneMatrix[16];
        MakeTranslationMatrix(boneMatrix, pTranslate[nBone].x, pTranslate[nBone].y, 0.0f);
        if (pRotation[nBone] != 0.0f) {
            float rotationMatrix[16];
            MakeRotationMatrixZ(rotationMatrix, -pRotation[nBone]);
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
    // A mesh with fewer than one triangle's worth of indices draws nothing.
    if (static_cast<int>(m_nDrawIndexCount) < kMinDrawIndexCount) {
        return;
    }
    neGLESRenderer *pRenderer = GetGlRenderer();
    SetCurrentCamera(pRenderer, g_pCurrentProjection);

    // Build the model matrix (translate, then optional Z rotation and uniform scale) and compose it
    // under the parent's world matrix. Unlike the 3D renderer there is no separate compose step.
    float *pLocal = GetLocalMatrix();
    MakeTranslationMatrix(pLocal, m_flTranslateX, m_flTranslateY, 0.0f);
    if (m_flRotationZ != 0.0f) {
        float rotationMatrix[16];
        MakeRotationMatrixZ(rotationMatrix, -m_flRotationZ);
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
        // Externally-owned buffer: the vertex data already lives in client memory, so the attribute
        // pointers reference it directly. Refresh premultiplied colours when the colour is dirty.
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
                UpdateTextureParameterIfChanged(
                    m_pTexture, pRenderer, nParam, m_aTexParams[nParam]);
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
        // Internally-owned VBO: (re)upload the vertex data on first draw, then reset the attribute
        // pointers to the bound buffer's defaults (the Clear* helpers).
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
                    UpdateTextureParameterIfChanged(
                        m_pTexture, pRenderer, nParam, m_aTexParams[nParam]);
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
            pRenderer->ClearWeightPointer(m_nVertexStride, m_nBoneComponentCount);
            pRenderer->SetGlClientState(kClientMatrixIndex, 1);
            pRenderer->ClearMatrixIndexPointer(m_nVertexStride, m_nBoneComponentCount);
        }
    }

    // Reset the remaining render state: enable blending with the mesh's blend mode and force every
    // other capability off.
    pRenderer->SetGlEnableState(kEnableAlphaTest, 0);
    pRenderer->SetGlEnableState(kEnableBlend, 1);
    pRenderer->SetBlendFunc(
        kBlendOne, m_nBlendMode == kBlendModeAdditive ? kBlendOne : kBlendOneMinusSrcAlpha);
    for (int nState = kEnableBlend + 1; nState <= kEnableStateResetMax; ++nState) {
        pRenderer->SetGlEnableState(static_cast<unsigned int>(nState), 0);
    }

    // Bind the index buffer (uploading it on first draw for an internally-owned VBO) and issue the
    // indexed draw.
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
    pRenderer->DrawIndexedPrimitives(
        static_cast<int>(m_nDrawMode), static_cast<int>(m_nDrawIndexCount), m_pIndexArray);
}

} // namespace ne
