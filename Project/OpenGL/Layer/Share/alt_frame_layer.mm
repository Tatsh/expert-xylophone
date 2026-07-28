//
//  alt_frame_layer.mm
//  REFLEC BEAT plus
//
//  The alternate play-field frame layer (AltFrameLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "alt_frame_layer.h"

#include "alt_frame_marker_table.h"
#include "engineglobals.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

// The process-wide alternate-frame layer, created lazily by shared().
static AltFrameLayer *g_pAltFrameLayer = nullptr; // @ghidraAddress 0x3deda8

namespace {
// The frame type and mode the constructor seeds.
constexpr int kDefaultFrameType = 0x20;
constexpr int kDefaultFrameMode = 5;
// The batch index of the mesh instancer whose first slot carries the frame texture.
constexpr int kFrameMeshBatch = 2;
// The mesh's single textured slot.
constexpr int kFrameMeshSlot = 0;
// Halves a scaled dimension into a half-pixel UV centre.
constexpr float kUvHalf = 0.5f;
// The fully-opaque alpha endpoint the fade-in eases toward (a 0-to-255 alpha channel).
constexpr float kFrameAlphaOpaque = 255.0f;
} // namespace

/** @ghidraAddress 0x17a4a4 */
AltFrameLayer::AltFrameLayer() {
    m_nFrameType = kDefaultFrameType;
    m_nFrameMode = kDefaultFrameMode;
    // The sprite batches, counts, ready flag, and fade channel are zeroed by the member initialisers.
}

/** @ghidraAddress 0x17a4f8 */
AltFrameLayer *AltFrameLayer::shared() {
    if (g_pAltFrameLayer == nullptr) {
        // The binary allocates the raw 0x80-byte object and runs the constructor.
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
        // With no texture, zero the mesh slot's centre, size, UV origin, and UV size.
        pMesh->SetSpriteAnchor(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
        pMesh->SetSpriteSize(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
        pMesh->SetSpriteUvOrigin(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
        pMesh->SetSpriteUvSize(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
        return;
    }

    // The texture's source dimensions in points (its image size divided by the retina scale).
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
        // Advance the fade toward its end, clamping the elapsed time to the duration.
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
        // The fade is complete; only apply the final alpha once (on the frame the flag latches).
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

    // Keep the two overlay batches visible.
    m_apSprites[1]->SetVisible(true);
    m_apSprites[2]->SetVisible(true);
}

namespace {
// The frame-type thresholds that select the low/mid/high lane-count marker set.
constexpr int kFrameTypeMidThreshold = 7;
constexpr int kFrameTypeHighThreshold = 0xd;
// The highlight sprite-kind row the active-lane marker draws instead of its normal row, per set.
constexpr int kActiveLaneKind4 = 4;
constexpr int kActiveLaneKind6 = 6;
constexpr int kActiveLaneKind9 = 9;
} // namespace

/** @ghidraAddress 0x17a9d8 */
void AltFrameLayer::RenderMarkers() {
    // The play-field half-height (rounded toward zero) offsets every marker's base Y each frame.
    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;

    // Each batch's running slot index this frame.
    int aSlotIndex[kSpriteSlotCount] = {};
    for (int nMarker = 0; nMarker < m_nMarkerCount; ++nMarker) {
        // Select the layout and descriptor tables and the active-lane highlight kind by frame type,
        // bounding the marker index to the chosen set's record count.
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

        // The active-lane marker draws its highlight row; every other marker its own layout row.
        const int nKind = nMarker == m_nActiveLane ? nActiveKind : pLayout->nSpriteKind;
        const AltFrameSpriteDescriptor &descriptor = pDescriptors[nKind];

        ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[descriptor.nBatch];
        const int nSlot = aSlotIndex[descriptor.nBatch];
        pBatch->SetSpritePositionXY(
            nSlot, pLayout->flX, pLayout->flY + static_cast<float>(nHalfHeight));
        aSlotIndex[descriptor.nBatch] = nSlot + 1;
    }
}
