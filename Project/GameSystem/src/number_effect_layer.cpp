//
//  number_effect_layer.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. Pure C++.
//

#include "number_effect_layer.h"

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

namespace {
// The gm_parts2 atlas the number glyphs draw from.
constexpr const char *kAtlasTextureName = "00_texture/gm_parts2";

// The device-dependent transform block the instancer builder seeds into @c m_aTransform. The phone
// (non-pad) uses a mirror offset and the pad width; the pad uses its own shipped offsets
// (@ghidraAddress 0x30fb00 = -103.0, 0x30fb08 = 206.0, 0x30fb0c = 96.0).
constexpr float kMirrorOffset = -6.0f;    // 0xc0c00000
constexpr float kTransformPadX = -103.0f; // @ghidraAddress 0x30fb00
constexpr float kTransformPadZ = 206.0f;  // @ghidraAddress 0x30fb08
constexpr float kTransformPhoneZ = 96.0f; // @ghidraAddress 0x30fb0c
constexpr float kTransformPadW = 7.0f;    // 0x40e00000

// The four instancer capacities (@ghidraAddress 0x30fb70): three of one, one of two.
constexpr int kBatchCapacity[] = {1, 1, 1, 2};

// The viewport width past which the wide-screen layout is used (@ghidraAddress 0x2f8558).
constexpr float kWideScreenSplit = 320.0f;

// The number of anchored elements and wide-layout variant rows.
constexpr int kAnchorElementCount = 4;
constexpr int kWideVariantCount = 2;

// The viewport-relative gravity applied to a base offset (from the anchor gravity tables). The
// offset moves the anchor to the named viewport edge or centre; the top-left case adds nothing (the
// base offset is already absolute).
enum AnchorGravity {
    kGravityBottomCentre = 0, // Offset by half the viewport width and the full height.
    kGravityTopCentre = 1,    // Offset by half the viewport width.
    kGravityTopLeft = 2,      // No offset (the base offset is absolute).
    kGravityTopRight = 3,     // Offset by the full viewport width.
    kGravityLeftCentre = 4,   // Offset by half the viewport height.
};

// The portrait-layout base offsets and per-element gravities (only the first two elements are set;
// the remainder are zero).
constexpr S_VECTOR2 kPortraitAnchor[kAnchorElementCount] = {
    {0.0f, -69.0f}, {132.0f, 63.0f}, {0.0f, 0.0f}, {0.0f, 0.0f}};
constexpr int kPortraitGravity[kAnchorElementCount] = {
    kGravityBottomCentre, kGravityTopLeft, kGravityTopLeft, kGravityTopCentre};

// The landscape-layout base offsets and per-element gravities, per wide-layout variant row.
constexpr S_VECTOR2 kLandscapeAnchor[kWideVariantCount][kAnchorElementCount] = {
    {{29.0f, -13.0f}, {-128.0f, -13.0f}, {0.0f, 31.0f}, {0.0f, 0.0f}},
    {{31.0f, -12.0f}, {-126.0f, -12.0f}, {73.0f, 12.0f}, {-73.0f, 12.0f}},
};
constexpr int kLandscapeGravity[kWideVariantCount][kAnchorElementCount] = {
    {kGravityBottomCentre, kGravityBottomCentre, kGravityTopCentre, kGravityTopCentre},
    {kGravityBottomCentre, kGravityBottomCentre, kGravityTopLeft, kGravityTopRight},
};
} // namespace

// The fully-opaque alpha the fade-in eases toward (a 0-to-255 alpha channel).
namespace {
constexpr float kOpaqueAlpha = 255.0f;

// One number-glyph element descriptor: its anchor, size, and index into the shared sprite-UV table.
struct NumberElementDescriptor {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    int nUvIndex;
};

// The number-glyph element descriptors for the landscape and portrait layouts (@ghidraAddress
// 0x30fbd0 landscape, 0x30fb80 portrait).
constexpr NumberElementDescriptor kLandscapeElements[] = {
    {124.0f, 10.0f, 248.0f, 20.0f, 0x175},
    {2.0f, 6.0f, 4.0f, 12.0f, 0x176},
    {25.0f, 10.0f, 50.0f, 20.0f, 0x177},
    {70.0f, 9.0f, 140.0f, 18.0f, 0x178},
};
constexpr NumberElementDescriptor kPortraitElements[] = {
    {178.0f, 25.0f, 356.0f, 50.0f, 0xf4},
    {2.0f, 7.0f, 4.0f, 12.0f, 0xf5},
    {50.0f, 16.0f, 100.0f, 32.0f, 0xf6},
    {70.0f, 9.0f, 140.0f, 18.0f, 0xf7},
};
} // namespace

/** @ghidraAddress 0x189ef0 */
void NumberEffectLayer::AdvanceFadeInterp(float flDeltaTime) {
    if (m_fadeChannel.GetElapsed() >= m_fadeChannel.GetDuration()) {
        return;
    }
    m_fadeChannel.Advance(flDeltaTime);
    m_bFadeActive = true;
}

/** @ghidraAddress 0x189e98 */
void NumberEffectLayer::StartFadeIn(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(kOpaqueAlpha);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    // A non-positive duration snaps straight to opaque and marks the fade done.
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(kOpaqueAlpha);
        m_bFadeActive = true;
    }
}

/** @ghidraAddress 0x189ec8 */
void NumberEffectLayer::StartFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    // A non-positive duration snaps straight to transparent and marks the fade done.
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(0.0f);
        m_bFadeActive = true;
    }
}

/** @ghidraAddress 0x18a7a8 */
void NumberEffectLayer::SetBrightness(float flValue) {
    if (flValue < 0.0f) {
        flValue = 0.0f;
    } else if (flValue > 1.0f) {
        flValue = 1.0f;
    }
    m_flBrightness = flValue;
}

/** @ghidraAddress 0x18a2d4 */
void NumberEffectLayer::ComputeAnchorPos(unsigned int nElement, S_VECTOR2 *pOut) const {
    // The iPad uses the portrait table; the phone uses the wide-variant landscape row.
    int nGravity;
    if (IsPad()) {
        *pOut = kPortraitAnchor[nElement];
        nGravity = kPortraitGravity[nElement];
    } else {
        const int nVariant = m_bWideScreen ? 1 : 0;
        *pOut = kLandscapeAnchor[nVariant][nElement];
        nGravity = kLandscapeGravity[nVariant][nElement];
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flWidth = pGameSystem->GetViewportWidth();
    const float flHeight = pGameSystem->GetViewportHeight();
    switch (nGravity) {
    case kGravityBottomCentre:
        pOut->x += flWidth * 0.5f;
        pOut->y += flHeight;
        break;
    case kGravityTopCentre:
        pOut->x += flWidth * 0.5f;
        break;
    case kGravityTopRight:
        pOut->x += flWidth;
        break;
    case kGravityLeftCentre:
        pOut->y += flHeight * 0.5f;
        break;
    case kGravityTopLeft:
    default:
        break;
    }
}

/** @ghidraAddress 0x18a674 */
void NumberEffectLayer::EmitNumberSprite(
    float flX, float flY, unsigned int nBatch, unsigned int nDescIndex, unsigned int nColour) {
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    const int nIndex = pBatch->GetSpriteCount();
    if (nIndex >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    // The portrait (pad) layout uses its own element table; the phone uses the landscape table.
    const NumberElementDescriptor &element =
        IsPad() ? kPortraitElements[nDescIndex] : kLandscapeElements[nDescIndex];
    const SpriteUvEntry &uv = g_aSpriteUvTable[element.nUvIndex];
    const auto nAlpha = static_cast<unsigned int>(static_cast<int>(m_fadeChannel.GetCurrent()));

    pBatch->SetSpritePosition(nIndex, S_VECTOR2{flX, flY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{element.flSizeW, element.flSizeH});
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{element.flAnchorX, element.flAnchorY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteColor(nIndex, nColour, nColour, nColour, nAlpha);
    pBatch->SetSpriteCount(nIndex + 1);
}

// The process-wide number-effect layer, created lazily by shared().
static NumberEffectLayer *g_pNumberEffectLayer = nullptr; // @ghidraAddress 0x3df240

/** @ghidraAddress 0x189ce0 */
NumberEffectLayer *NumberEffectLayer::shared() {
    if (g_pNumberEffectLayer == nullptr) {
        g_pNumberEffectLayer = new NumberEffectLayer();
    }
    return g_pNumberEffectLayer;
}

/** @ghidraAddress 0x189d50 */
void NumberEffectLayer::FreeInstance() {
    if (g_pNumberEffectLayer != nullptr) {
        delete g_pNumberEffectLayer;
        g_pNumberEffectLayer = nullptr;
    }
}

/** @ghidraAddress 0x189c70 */
NumberEffectLayer::~NumberEffectLayer() {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    // Each live instancer is flagged for deletion by the scene tree and detached from the layer.
    for (ne::C_SPRITE_INSTANCING_2D *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
}

/** @ghidraAddress 0x189d9c */
void NumberEffectLayer::CreateSpriteInstancers() {
    if (m_bBuilt) {
        return;
    }

    // Seed the device-dependent transform block: the phone mirrors, the pad uses its own offsets.
    if (IsPad()) {
        m_aTransform[0] = kTransformPadX;
        m_aTransform[1] = kMirrorOffset;
        m_aTransform[2] = kTransformPadZ;
        m_aTransform[3] = kTransformPadW;
    } else {
        m_aTransform[0] = kMirrorOffset;
        m_aTransform[1] = 0.0f;
        m_aTransform[2] = kTransformPhoneZ;
        m_aTransform[3] = 0.0f;
    }

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
    // The binary fetches the background layer and its render object here but discards both; the
    // instancers register directly into the global scene tree instead.
    (void)BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    for (int i = 0; i < kBatchCount; ++i) {
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateSpriteInstancer(static_cast<unsigned int>(kBatchCapacity[i]));
        m_apSprites[i] = pSprite;
        pSprite->RegisterGlobal();
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
    }

    // The wide-screen layout is used once the viewport is wider than the split threshold.
    m_bWideScreen = GameSystem::GetGameSystem()->GetViewportWidth() > kWideScreenSplit;
}
