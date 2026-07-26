//
//  number_effect_layer.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. Pure C++.
//

#include "number_effect_layer.h"

#include "gamesystem.h"

namespace {
// The scroll-offset value the full-just-reflec challenge mode uses instead of zero.
constexpr float kChallengeScrollOffset = 5.0f;

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

/** @ghidraAddress 0x189ef0 */
void NumberEffectLayer::AdvanceFadeInterp(float flDeltaTime) {
    if (m_fadeChannel.GetElapsed() >= m_fadeChannel.GetDuration()) {
        return;
    }
    m_fadeChannel.Advance(flDeltaTime);
    m_bFadeActive = true;
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

/** @ghidraAddress 0x18a988 */
void NumberEffectLayer::ResetOffsets() {
    // Each offset clears to zero, except in the full-just-reflec challenge mode which seeds five.
    const float flReset =
        GameSystem::GetGameSystem()->GetFullJustReflec() ? kChallengeScrollOffset : 0.0f;
    for (ScrollOffset &offset : m_aScrollOffset) {
        offset = ScrollOffset{};
        offset.flOffset = flReset;
    }
}

/** @ghidraAddress 0x18a2d4 */
void NumberEffectLayer::ComputeAnchorPos(unsigned int nElement, S_VECTOR2 *pOut) const {
    // The base offset and gravity come from the portrait table, or the wide-variant landscape row.
    int nGravity;
    if (m_bPortrait) {
        *pOut = kPortraitAnchor[nElement];
        nGravity = kPortraitGravity[nElement];
    } else {
        *pOut = kLandscapeAnchor[m_nWideVariant][nElement];
        nGravity = kLandscapeGravity[m_nWideVariant][nElement];
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flWidth = pGameSystem->GetViewportWidth();
    const float flHeight = pGameSystem->GetViewportHeight();
    switch (nGravity) {
    case kGravityCenterBoth:
        pOut->x += flWidth * 0.5f;
        pOut->y += flHeight;
        break;
    case kGravityCenterX:
        pOut->x += flWidth * 0.5f;
        break;
    case kGravityRightEdge:
        pOut->x += flWidth;
        break;
    case kGravityCenterY:
        pOut->y += flHeight * 0.5f;
        break;
    default:
        break;
    }
}
