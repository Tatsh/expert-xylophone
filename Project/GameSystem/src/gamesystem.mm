//
//  gamesystem.mm
//  REFLEC BEAT plus
//
//  The global game-system singleton (GameSystem). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "gamesystem.h"

#import <UIKit/UIKit.h>

#import "MusicData.h"
#include "deviceenvironment.h"
#include "engineglobals.h"
#include "neTexture.h"
#include "neTextureForiOS.h"

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

// The per-step zoom increment the tablet sheet scale adds per scale step (@ghidraAddress 0x2ec778).
constexpr double kTabletScaleStep = 0.1;

// The sheet margins: the phone left/right margin, the tablet left/right margin, and the shared
// top/bottom margin.
constexpr float kPhoneSheetMarginX = 24.0f;  // @ghidraAddress 0x41c00000
constexpr float kTabletSheetMarginX = 64.0f; // @ghidraAddress 0x2ef184
constexpr float kSheetMarginY = 22.0f;       // @ghidraAddress 0x41b00000

// The tablet sheet-position x and the notch inset subtracted from the field height for its y.
constexpr float kTabletSheetPosX = 640.0f;  // @ghidraAddress 0x44200000
constexpr int kTabletSheetPosYInset = 0x2c; // 44 points.

// The screen-dimension buckets the phone layout clamps the effective width/height to: the tall
// (4"/4.7") height and the narrow (3.5"/4") width, in points.
constexpr int kScreenTall = 0x238;   // 568.
constexpr int kScreenNarrow = 0x140; // 320.

// The phone sheet-position insets: the fixed x inset (48 points), and the two y insets summed into
// the scaled height (@ghidraAddress 0x2fedf4 = -48.0, 0x2fedf8 = -50.0).
constexpr int kPhoneSheetPosXInset = 0x30; // 48 points.
constexpr float kPhoneSheetPosYInsetA = -48.0f;
constexpr float kPhoneSheetPosYInsetB = -50.0f;

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

/** @ghidraAddress 0x12eee0 */
void GameSystem::LoadArtworkTexture(MusicData *pMusicData) {
    // Release any previously loaded artwork before loading the new one.
    if (m_pArtworkTexture != nullptr) {
        m_pArtworkTexture->Release();
        m_pArtworkTexture = nullptr;
    }
    if (pMusicData == nil) {
        return;
    }

    // On a retina screen, prefer the 2x jacket image; fall back to the 1x image when there is no 2x
    // data or the 2x load fails.
    if (UIScreen.mainScreen.scale > 1.0) {
        NSData *pData2x = [pMusicData artwork2xData];
        if (pData2x != nil) {
            m_pArtworkTexture = [neTextureForiOS LoadTexture:pData2x Scale:2.0];
        }
    }
    if (m_pArtworkTexture == nullptr) {
        NSData *pData = [pMusicData artworkData];
        if (pData != nil) {
            m_pArtworkTexture = [neTextureForiOS LoadTexture:pData Scale:1.0];
        }
    }
}

/** @ghidraAddress 0x12f054 */
void GameSystem::LoadMusicNameTexture(MusicData *pMusicData) {
    // Release any previously loaded music-name texture before loading the new one.
    if (m_pMusicNameTexture != nullptr) {
        m_pMusicNameTexture->Release();
        m_pMusicNameTexture = nullptr;
    }
    if (pMusicData == nil) {
        return;
    }

    // On a retina screen, prefer the 2x white-name image; fall back to the 1x image when there is
    // no 2x data or the 2x load fails.
    if (UIScreen.mainScreen.scale > 1.0) {
        NSData *pData2x = [pMusicData musicNameImageWhite2xData];
        if (pData2x != nil) {
            m_pMusicNameTexture = [neTextureForiOS LoadTexture:pData2x Scale:2.0];
        }
    }
    if (m_pMusicNameTexture == nullptr) {
        NSData *pData = [pMusicData musicNameImageWhiteData];
        if (pData != nil) {
            m_pMusicNameTexture = [neTextureForiOS LoadTexture:pData Scale:1.0];
        }
    }
}

/** @ghidraAddress 0x12f1c8 */
void GameSystem::LoadArtistNameTexture(MusicData *pMusicData) {
    // Release any previously loaded artist-name texture before loading the new one.
    if (m_pArtistNameTexture != nullptr) {
        m_pArtistNameTexture->Release();
        m_pArtistNameTexture = nullptr;
    }
    if (pMusicData == nil) {
        return;
    }

    // On a retina screen, prefer the 2x artist-name image; fall back to the 1x image when there is
    // no 2x data or the 2x load fails.
    if (UIScreen.mainScreen.scale > 1.0) {
        NSData *pData2x = [pMusicData artistNameImageWhite2xData];
        if (pData2x != nil) {
            m_pArtistNameTexture = [neTextureForiOS LoadTexture:pData2x Scale:2.0];
        }
    }
    if (m_pArtistNameTexture == nullptr) {
        NSData *pData = [pMusicData artistNameImageWhiteData];
        if (pData != nil) {
            m_pArtistNameTexture = [neTextureForiOS LoadTexture:pData Scale:1.0];
        }
    }
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

/** @ghidraAddress 0x8ef60 */
void GameSystem::ConfigureSheetLayerForScreen(int nScaleStep) {
    if (IsPad()) {
        // Tablet: the sheet scale grows one zoom step at a time; the sheet is centred at a fixed x
        // and positioned just above the notch inset, with the wider variant left/right margin.
        m_flPlayfieldScale =
            static_cast<float>(static_cast<double>(nScaleStep) * kTabletScaleStep + 1.0);
        ComputePlayfieldLayoutY(m_flPlayfieldScale);

        S_VECTOR2 position{kTabletSheetPosX,
                           static_cast<float>(g_nPlayfieldFieldHeight - kTabletSheetPosYInset)};
        SetSheetLayerPosition(&position);
        SetSheetMargins(kTabletSheetMarginX, kSheetMarginY, kTabletSheetMarginX, kSheetMarginY);
        return;
    }

    // Phone: the sheet is drawn at unit scale.
    m_flPlayfieldScale = 1.0f;
    ComputePlayfieldLayoutY(1.0f);

    // Clamp the screen bounds into the supported point buckets. The width axis and the height axis
    // are each clamped to the tall bucket independently; the landscape/portrait comparison then
    // picks which clamped pair to use, so a portrait screen reads its long side as the "long"
    // dimension.
    const CGRect bounds = UIScreen.mainScreen.bounds;
    const int nWidth = static_cast<int>(bounds.size.width);
    const int nHeight = static_cast<int>(bounds.size.height);
    const int nWidthClampedLong = nWidth > kScreenTall ? kScreenTall : nWidth;
    const int nWidthClampedShort = nWidth > kScreenTall ? kScreenNarrow : nHeight;
    const int nHeightClampedLong = nHeight > kScreenTall ? kScreenTall : nHeight;
    const int nHeightClampedShort = nHeight > kScreenTall ? kScreenNarrow : nWidth;
    const bool bLandscape = bounds.size.width >= bounds.size.height;
    const int nEffectiveWidth = bLandscape ? nWidthClampedLong : nHeightClampedLong;
    const int nEffectiveHeight = bLandscape ? nWidthClampedShort : nHeightClampedShort;

    SetSheetMargins(kPhoneSheetMarginX, kSheetMarginY, kPhoneSheetMarginX, kSheetMarginY);

    // Centre the sheet: x spans the narrow dimension inset by 48 points; y is the tall dimension
    // scaled and shifted up by the two fixed insets.
    S_VECTOR2 position{static_cast<float>(nEffectiveHeight * 2 - kPhoneSheetPosXInset),
                       static_cast<float>(nEffectiveWidth * 2) * m_flPlayfieldScale +
                           kPhoneSheetPosYInsetA + kPhoneSheetPosYInsetB};
    SetSheetLayerPosition(&position);
}
