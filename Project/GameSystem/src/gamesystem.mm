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
