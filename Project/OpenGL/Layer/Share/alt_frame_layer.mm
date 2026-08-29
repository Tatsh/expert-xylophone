#include "alt_frame_layer.h"

#include "alt_frame_marker_table.h"
#include "engineglobals.h"
#include "frame_texture_table.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

static AltFrameLayer *g_pAltFrameLayer = nullptr; // @ghidraAddress 0x3deda8

static const char *const g_szGmParts2TextureKey = "00_texture/gm_parts2"; // @ghidraAddress 0x3ceaa8

namespace {
constexpr int kDefaultFrameType = 0x20;
constexpr int kDefaultFrameMode = 5;
constexpr int kFrameMeshBatch = 2;
constexpr int kFrameMeshSlot = 0;
constexpr float kUvHalf = 0.5f;
constexpr float kFrameAlphaOpaque = 255.0f;
} // namespace

/** @ghidraAddress 0x17a4a4 */
AltFrameLayer::AltFrameLayer() {
    m_nFrameType = kDefaultFrameType;
    m_nFrameMode = kDefaultFrameMode;
}

/** @ghidraAddress 0x17a4f8 */
AltFrameLayer *AltFrameLayer::shared() {
    if (g_pAltFrameLayer == nullptr) {
        g_pAltFrameLayer = new AltFrameLayer();
    }
    return g_pAltFrameLayer;
}

/** @ghidraAddress 0x17b054 */
void AltFrameLayer::StartFadeIn(float flDuration) {
    RenderMarkers();
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(kFrameAlphaOpaque);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(kFrameAlphaOpaque);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x17b0ac */
void AltFrameLayer::StartFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(0.0f);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x17aba8 */
void AltFrameLayer::SetFrameType(int nType) {
    if (m_nFrameType == nType) {
        return;
    }
    m_nFrameType = nType;
    m_bReady = false;
    BuildSprites();
}

/** @ghidraAddress 0x17aecc */
void AltFrameLayer::SetAltFrameTexture(ne::C_TEXTURE *pTexture) {
    ne::C_SPRITE_INSTANCING_2D *pMesh = m_apSprites[kFrameMeshBatch];
    if (pMesh == nullptr) {
        return;
    }
    pMesh->SetRefCountedMember(pTexture);

    if (pTexture == nullptr) {
        pMesh->SetSpriteAnchor(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
        pMesh->SetSpriteSize(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
        pMesh->SetSpriteUvOrigin(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
        pMesh->SetSpriteUvSize(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
        return;
    }

    const float flPointWidth = static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetScale();
    const float flPointHeight =
        static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetScale();

    pMesh->SetSpriteAnchor(
        kFrameMeshSlot,
        S_VECTOR2{static_cast<float>(static_cast<int>(flPointWidth * kUvHalf)),
                  static_cast<float>(static_cast<int>(flPointHeight * kUvHalf))});
    pMesh->SetSpriteSize(kFrameMeshSlot, S_VECTOR2{flPointWidth, flPointHeight});
    pMesh->SetSpriteUvOrigin(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
    pMesh->SetSpriteUvSize(
        kFrameMeshSlot,
        S_VECTOR2{static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetAllocWidth(),
                  static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetAllocHeight()});
}

/** @ghidraAddress 0x17b0d4 */
void AltFrameLayer::Process(float flDelta) {
    if (!m_bReady) {
        return;
    }

    const float flDuration = m_fadeChannel.GetDuration();
    bool bApply;
    if (flDuration > m_fadeChannel.GetElapsed()) {
        float flElapsed = m_fadeChannel.GetElapsed() + flDelta;
        if (flElapsed > flDuration) {
            flElapsed = flDuration;
        }
        m_fadeChannel.SetElapsed(flElapsed);
        const float flFraction = flDuration == 0.0f ? 1.0f : flElapsed / flDuration;
        m_fadeChannel.SetCurrent(m_fadeChannel.GetStart() +
                                 flFraction * (m_fadeChannel.GetEnd() - m_fadeChannel.GetStart()));
        bApply = true;
    } else {
        // Once complete, the final alpha is applied only on the frame the flag latches.
        bApply = m_bFadeDone;
    }

    if (bApply) {
        m_bFadeDone = false;
        const auto nAlpha =
            static_cast<unsigned char>(static_cast<int>(m_fadeChannel.GetCurrent()));
        for (int nBatch = 0; nBatch < kSpriteSlotCount; ++nBatch) {
            for (int nSlot = 0; nSlot < m_aSpriteCounts[nBatch]; ++nSlot) {
                m_apSprites[nBatch]->SetColorAlpha(nSlot, nAlpha);
            }
        }
    }

    m_apSprites[1]->SetVisible(true);
    m_apSprites[2]->SetVisible(true);
}

namespace {
constexpr int kFrameTypeMidThreshold = 7;
constexpr int kFrameTypeHighThreshold = 0xd;
constexpr int kActiveLaneKind4 = 4;
constexpr int kActiveLaneKind6 = 6;
constexpr int kActiveLaneKind9 = 9;
} // namespace

/** @ghidraAddress 0x17a9d8 */
void AltFrameLayer::RenderMarkers() {
    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;

    int aSlotIndex[kSpriteSlotCount] = {};
    for (int nMarker = 0; nMarker < m_nMarkerCount; ++nMarker) {
        const AltFrameMarkerLayout *pLayout = nullptr;
        const AltFrameSpriteDescriptor *pDescriptors = nullptr;
        int nActiveKind = 0;
        if (m_nFrameType < kFrameTypeMidThreshold) {
            if (nMarker >= kAltFrameMarkerCount4) {
                break;
            }
            pLayout = &g_aAltFrameMarker4[nMarker];
            pDescriptors = g_aAltFrameDescriptor4;
            nActiveKind = kActiveLaneKind4;
        } else if (m_nFrameType < kFrameTypeHighThreshold) {
            if (nMarker >= kAltFrameMarkerCount6) {
                break;
            }
            pLayout = &g_aAltFrameMarker6[nMarker];
            pDescriptors = g_aAltFrameDescriptor6;
            nActiveKind = kActiveLaneKind6;
        } else {
            if (nMarker >= kAltFrameMarkerCount9) {
                break;
            }
            pLayout = &g_aAltFrameMarker9[nMarker];
            pDescriptors = g_aAltFrameDescriptor9;
            nActiveKind = kActiveLaneKind9;
        }

        const int nKind = nMarker == m_nActiveLane ? nActiveKind : pLayout->nSpriteKind;
        const AltFrameSpriteDescriptor &descriptor = pDescriptors[nKind];

        ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[descriptor.nBatch];
        const int nSlot = aSlotIndex[descriptor.nBatch];
        pBatch->SetSpritePositionXY(
            nSlot, pLayout->flX, pLayout->flY + static_cast<float>(nHalfHeight));
        aSlotIndex[descriptor.nBatch] = nSlot + 1;
    }
}

namespace {
constexpr int kMeshBatch = 0;
constexpr unsigned int kHighlightColor = 0xffffff;
constexpr int kHighlightSlot = 0;
} // namespace

/** @ghidraAddress 0x17abc4 */
void AltFrameLayer::SetFrameMode(int nMode) {
    m_nFrameMode = nMode;

    const AltFrameMarkerLayout *pMarker = nullptr;
    const AltFrameSpriteDescriptor *pDescriptor = nullptr;
    if (m_nFrameType < kFrameTypeMidThreshold) {
        pMarker = &g_aAltFrameMarker4[m_nActiveLane];
        pDescriptor = &g_aAltFrameDescriptor4[nMode + kActiveLaneKind4];
    } else if (m_nFrameType < kFrameTypeHighThreshold) {
        pMarker = &g_aAltFrameMarker6[m_nActiveLane];
        pDescriptor = &g_aAltFrameDescriptor6[nMode + kActiveLaneKind6];
    } else {
        pMarker = &g_aAltFrameMarker9[m_nActiveLane];
        pDescriptor = &g_aAltFrameDescriptor9[nMode + kActiveLaneKind9];
    }

    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;

    const SpriteUvEntry *pUvTable;
    if (pDescriptor->nBatch != kMeshBatch) {
        pUvTable = g_aSpriteUvTable;
    } else if (m_nFrameType < kFrameTypeHighThreshold) {
        pUvTable = g_aAltFrameMeshUvMid;
    } else {
        pUvTable = g_aAltFrameMeshUvHigh;
    }
    const SpriteUvEntry &uv = pUvTable[pDescriptor->nUvFrameIndex];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[pDescriptor->nBatch];
    pBatch->SetSpritePosition(
        kHighlightSlot, S_VECTOR2{pMarker->flX, pMarker->flY + static_cast<float>(nHalfHeight)});
    pBatch->SetSpriteAnchor(kHighlightSlot,
                            S_VECTOR2{pDescriptor->flAnchorX, pDescriptor->flAnchorY});
    pBatch->SetSpriteSize(kHighlightSlot, S_VECTOR2{pDescriptor->flSizeX, pDescriptor->flSizeY});
    pBatch->SetSpriteUvOrigin(kHighlightSlot, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(kHighlightSlot, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteRotation(kHighlightSlot, pMarker->flRotation);
    pBatch->SetSpriteScale(kHighlightSlot, pMarker->flScaleX, pMarker->flScaleY);
    pBatch->SetSpriteColor(kHighlightSlot, kHighlightColor);
}

namespace {
constexpr int kAltFrameMarkerCount = 14;
constexpr int kOverlayBatchCapacity = 1;

constexpr int kActiveLane4 = 9;
constexpr int kActiveLane6 = 13;
constexpr int kActiveLane9 = 11;

constexpr int kFrameAtlasSlot = 0;
constexpr int kPartsAtlasSlot = 1;

// The third entry indexes past the two-entry texture array, as the shipped code does.
constexpr int kBatchTextureSlot[] = {0, 1, 3};

constexpr int kOverlayBatchFirst = 1;
constexpr int kOverlayBatchLast = 2;

constexpr int kFirstTintedFrameType = 7;
constexpr int kFirstWarmTintFrameType = 15;

constexpr unsigned int kWarmTintRed = 0x4e;
constexpr unsigned int kWarmTintGreen = 0x45;
constexpr unsigned int kWarmTintBlue = 0x3a;

constexpr unsigned int kChannelMax = 255;
constexpr unsigned int kInitialAlpha = 0;
} // namespace

/** @ghidraAddress 0x17a548 */
void AltFrameLayer::BuildSprites() {
    if (m_bReady) {
        return;
    }

    m_nMarkerCount = kAltFrameMarkerCount;

    // kDefaultFrameType is a sentinel meaning the frame the player has equipped.
    if (m_nFrameType == kDefaultFrameType) {
        m_nFrameType = GameSystem::GetGameSystem()->GetFrameType();
    }

    if (m_nFrameType < kFrameTypeMidThreshold) {
        m_nActiveLane = kActiveLane4;
    } else if (m_nFrameType < kFrameTypeHighThreshold) {
        m_nActiveLane = kActiveLane6;
    } else {
        m_nActiveLane = kActiveLane9;
    }

    m_anBatchCapacity[kMeshBatch] = m_nMarkerCount;
    for (int nBatch = kOverlayBatchFirst; nBatch <= kOverlayBatchLast; ++nBatch) {
        m_anBatchCapacity[nBatch] = kOverlayBatchCapacity;
    }

    // The sentinel survives only when the game system is unset, and the layer then keeps the
    // textures it already holds.
    if (m_nFrameType != kDefaultFrameType) {
        m_apTextures[kFrameAtlasSlot] =
            ne::C_TEXTURE::FindOrLoadCached(g_aFrameTextureNames[m_nFrameType]);
        m_apTextures[kPartsAtlasSlot] = ne::C_TEXTURE::FindOrLoadCached(g_szGmParts2TextureKey);
    }

    for (int nBatch = 0; nBatch < kSpriteSlotCount; ++nBatch) {
        if (m_apSprites[nBatch] == nullptr) {
            m_apSprites[nBatch] =
                ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_anBatchCapacity[nBatch]));
            m_apSprites[nBatch]->RegisterGlobal();
        }
        ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
        pBatch->SetVisible(true);

        // See kBatchTextureSlot for the last batch's out-of-bounds slot.
        const int nTextureSlot = kBatchTextureSlot[nBatch];
        ne::C_TEXTURE *pTexture =
            nTextureSlot < kTextureSlotCount ?
                m_apTextures[nTextureSlot] :
                reinterpret_cast<ne::C_TEXTURE *>(m_apSprites[nTextureSlot - kTextureSlotCount]);
        pBatch->SetRefCountedMember(pTexture);

        pBatch->SetSpriteCount(m_anBatchCapacity[nBatch]);
        m_aSpriteCounts[nBatch] = 0;
    }

    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;

    for (int nMarker = 0; nMarker < m_nMarkerCount; ++nMarker) {
        const AltFrameMarkerLayout *pLayout = nullptr;
        const AltFrameSpriteDescriptor *pDescriptors = nullptr;
        int nActiveKind = 0;
        if (m_nFrameType < kFrameTypeMidThreshold) {
            if (nMarker >= kAltFrameMarkerCount4) {
                break;
            }
            pLayout = &g_aAltFrameMarker4[nMarker];
            pDescriptors = g_aAltFrameDescriptor4;
            nActiveKind = kActiveLaneKind4;
        } else if (m_nFrameType < kFrameTypeHighThreshold) {
            if (nMarker >= kAltFrameMarkerCount6) {
                break;
            }
            pLayout = &g_aAltFrameMarker6[nMarker];
            pDescriptors = g_aAltFrameDescriptor6;
            nActiveKind = kActiveLaneKind6;
        } else {
            if (nMarker >= kAltFrameMarkerCount9) {
                break;
            }
            pLayout = &g_aAltFrameMarker9[nMarker];
            pDescriptors = g_aAltFrameDescriptor9;
            nActiveKind = kActiveLaneKind9;
        }

        const int nKind = nMarker == m_nActiveLane ? nActiveKind : pLayout->nSpriteKind;
        const AltFrameSpriteDescriptor &descriptor = pDescriptors[nKind];

        const SpriteUvEntry *pUvTable;
        if (descriptor.nBatch != kMeshBatch) {
            pUvTable = g_aSpriteUvTable;
        } else if (m_nFrameType < kFrameTypeHighThreshold) {
            pUvTable = g_aAltFrameMeshUvMid;
        } else {
            pUvTable = g_aAltFrameMeshUvHigh;
        }
        const SpriteUvEntry &uv = pUvTable[descriptor.nUvFrameIndex];

        ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[descriptor.nBatch];
        const int nSlot = m_aSpriteCounts[descriptor.nBatch];
        pBatch->SetSpritePositionXY(
            nSlot, pLayout->flX, pLayout->flY + static_cast<float>(nHalfHeight));
        if (nSlot == 0) {
        }
        pBatch->SetSpriteAnchor(nSlot, S_VECTOR2{descriptor.flAnchorX, descriptor.flAnchorY});
        pBatch->SetSpriteSize(nSlot, S_VECTOR2{descriptor.flSizeX, descriptor.flSizeY});
        pBatch->SetSpriteUvOrigin(nSlot, S_VECTOR2{uv.flOriginU, uv.flOriginV});
        pBatch->SetSpriteUvSize(nSlot, S_VECTOR2{uv.flSizeU, uv.flSizeV});
        pBatch->SetSpriteRotation(nSlot, pLayout->flRotation);
        pBatch->SetSpriteScale(nSlot, pLayout->flScaleX, pLayout->flScaleY);
        // The binary writes opaque white here, then immediately overwrites it with the tint below.
        pBatch->SetSpriteColor(nSlot, kChannelMax, kChannelMax, kChannelMax, kInitialAlpha);

        // The overlay sprites are darkened on the limelight and colette frames; the mesh sprite and
        // every classic frame stay white.
        unsigned int nRed = kChannelMax;
        unsigned int nGreen = kChannelMax;
        unsigned int nBlue = kChannelMax;
        if ((descriptor.nBatch >= kOverlayBatchFirst && descriptor.nBatch <= kOverlayBatchLast) &&
            m_nFrameType >= kFirstTintedFrameType) {
            if (m_nFrameType >= kFirstWarmTintFrameType) {
                nRed = kWarmTintRed;
                nGreen = kWarmTintGreen;
                nBlue = kWarmTintBlue;
            } else {
                nRed = 0;
                nGreen = 0;
                nBlue = 0;
            }
        }
        pBatch->SetSpriteColor(nSlot, nRed, nGreen, nBlue, kInitialAlpha);

        ++m_aSpriteCounts[descriptor.nBatch];
    }

    m_bReady = true;
}
