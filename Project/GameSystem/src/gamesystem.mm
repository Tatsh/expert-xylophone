//
//  gamesystem.mm
//  REFLEC BEAT plus
//
//  The global game-system singleton (GameSystem). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "gamesystem.h"

// The process-wide game-system singleton, created lazily by GetGameSystem().
static GameSystem *g_pGameSystem = nullptr; // @ghidraAddress 0x3de010

namespace {

// The scale applied to the sheet radius to derive the scaled radius (one sixty-fourth).
constexpr float kSheetRadiusScale = 0.015625f;

// The non-zero field defaults the constructor seeds; every other field stays zero-initialised.
constexpr float kDefaultScreenScale = 1.0f;
constexpr float kDefaultSheetRadius = 64.0f;
constexpr float kDefaultSheetRadiusHalf = 32.0f;
// The two-player (both-side) play-colour default.
constexpr int kDefaultPlayerColor = 2;
constexpr float kDefaultShotVolume = 1.0f;
constexpr float kDefaultBackgroundBrightness = 1.0f;
constexpr float kDefaultRivalAlpha = 1.0f;
constexpr float kDefaultPlayfieldScale = 2.0f;

} // namespace

GameSystem::GameSystem() {
    // Only the non-zero defaults need seeding; the zero-initialised members cover the rest.
    m_flScreenScale = kDefaultScreenScale;
    m_flSheetRadius = kDefaultSheetRadius;
    m_flSheetRadiusHalf = kDefaultSheetRadiusHalf;
    m_nPlayerColor = kDefaultPlayerColor;
    m_flShotVolume = kDefaultShotVolume;
    m_flBackgroundBrightness = kDefaultBackgroundBrightness;
    m_flRivalAlpha = kDefaultRivalAlpha;
    m_flPlayfieldScale = kDefaultPlayfieldScale;
}

/** @ghidraAddress 0x12edb4 */
GameSystem *GameSystem::GetGameSystem() {
    if (g_pGameSystem == nullptr) {
        // The binary allocates the raw 0x140-byte object and runs the constructor inline.
        g_pGameSystem = new GameSystem();
    }
    return g_pGameSystem;
}

/** @ghidraAddress 0x12f33c */
void GameSystem::SetSheetLayerPosition(S_VECTOR2 *pPosition) {
    m_flSheetPosX = pPosition->x;
    m_flSheetPosY = pPosition->y;
    m_flSheetFarX = m_flSheetPosX + m_flSheetMarginLeft + m_flSheetMarginRight;
    m_flSheetFarY = m_flSheetPosY + m_flSheetMarginTop + m_flSheetMarginBottom;
    m_flSheetInsetX = m_flSheetPosX - m_flSheetRadius;
    m_flSheetInsetY = m_flSheetPosY - m_flSheetRadius;
    m_flSheetInsetHalfX = m_flSheetInsetX * 0.5f;
    m_flSheetInsetHalfY = m_flSheetInsetY * 0.5f;
}

/** @ghidraAddress 0x12f3c4 */
void GameSystem::SetSheetRadius(float flRadius) {
    m_flSheetRadius = flRadius;
    m_flSheetRadiusHalf = flRadius * 0.5f;
    m_flSheetRadiusScaled = flRadius * kSheetRadiusScale;
    m_flSheetInsetX = m_flSheetPosX - flRadius;
    m_flSheetInsetY = m_flSheetPosY - flRadius;
    m_flSheetInsetHalfX = m_flSheetInsetX * 0.5f;
    m_flSheetInsetHalfY = m_flSheetInsetY * 0.5f;
    // The squared sheet diameter, kept ready for radius-based hit tests.
    m_flSheetDiameterSq = (flRadius + flRadius) * (flRadius + flRadius);
}

/** @ghidraAddress 0x12f394 */
void GameSystem::SetSheetMargins(float flLeft, float flTop, float flRight, float flBottom) {
    m_flSheetMarginLeft = flLeft;
    m_flSheetMarginTop = flTop;
    m_flSheetMarginRight = flRight;
    m_flSheetMarginBottom = flBottom;
    m_flSheetFarX = m_flSheetPosX + flLeft + flRight;
    m_flSheetFarY = m_flSheetPosY + flTop + flBottom;
}
