#include "gamesystem.h"

#import <UIKit/UIKit.h>

#import "MusicData.h"
#include "deviceenvironment.h"
#include "engineglobals.h"
#include "neTexture.h"
#include "neTextureForiOS.h"

static GameSystem *g_pGameSystem = nullptr; // @ghidraAddress 0x3de010

namespace {

// One sixty-fourth.
constexpr float kSheetRadiusScale = 0.015625f;

constexpr float kDefaultScreenScale = 1.0f;
constexpr float kDefaultSheetRadius = 64.0f;
constexpr float kDefaultSheetRadiusHalf = 32.0f;
// The two-player (both-side) play-colour default.
constexpr int kDefaultPlayerColor = 2;
constexpr float kDefaultShotVolume = 1.0f;
constexpr float kDefaultBackgroundBrightness = 1.0f;
constexpr float kDefaultRivalAlpha = 1.0f;
constexpr float kDefaultPlayfieldScale = 2.0f;

constexpr double kTabletScaleStep = 0.1; // @ghidraAddress 0x2ec778

constexpr float kPhoneSheetMarginX = 24.0f;  // @ghidraAddress 0x41c00000
constexpr float kTabletSheetMarginX = 64.0f; // @ghidraAddress 0x2ef184
constexpr float kSheetMarginY = 22.0f;       // @ghidraAddress 0x41b00000

constexpr float kTabletSheetPosX = 640.0f;  // @ghidraAddress 0x44200000
constexpr int kTabletSheetPosYInset = 0x2c; // 44 points.

constexpr int kScreenTall = 0x238;   // 568.
constexpr int kScreenNarrow = 0x140; // 320.

constexpr int kPhoneSheetPosXInset = 0x30;      // 48 points.
constexpr float kPhoneSheetPosYInsetA = -48.0f; // @ghidraAddress 0x2fedf4
constexpr float kPhoneSheetPosYInsetB = -50.0f; // @ghidraAddress 0x2fedf8

} // namespace

GameSystem::GameSystem() {
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
        g_pGameSystem = new GameSystem();
    }
    return g_pGameSystem;
}

/** @ghidraAddress 0x12eee0 */
void GameSystem::LoadArtworkTexture(MusicData *pMusicData) {
    if (m_pArtworkTexture != nullptr) {
        m_pArtworkTexture->Release();
        m_pArtworkTexture = nullptr;
    }
    if (pMusicData == nil) {
        return;
    }

    if (UIScreen.mainScreen.scale > 1.0) {
        NSData *pData2x = [pMusicData artwork2xData];
        if (pData2x != nil) {
            m_pArtworkTexture = [neTextureForiOS LoadTexture:pData2x Scale:2.0f];
        }
    }
    if (m_pArtworkTexture == nullptr) {
        NSData *pData = [pMusicData artworkData];
        if (pData != nil) {
            m_pArtworkTexture = [neTextureForiOS LoadTexture:pData Scale:1.0f];
        }
    }
}

/** @ghidraAddress 0x12f054 */
void GameSystem::LoadMusicNameTexture(MusicData *pMusicData) {
    if (m_pMusicNameTexture != nullptr) {
        m_pMusicNameTexture->Release();
        m_pMusicNameTexture = nullptr;
    }
    if (pMusicData == nil) {
        return;
    }

    if (UIScreen.mainScreen.scale > 1.0) {
        NSData *pData2x = [pMusicData musicNameImageWhite2xData];
        if (pData2x != nil) {
            m_pMusicNameTexture = [neTextureForiOS LoadTexture:pData2x Scale:2.0f];
        }
    }
    if (m_pMusicNameTexture == nullptr) {
        NSData *pData = [pMusicData musicNameImageWhiteData];
        if (pData != nil) {
            m_pMusicNameTexture = [neTextureForiOS LoadTexture:pData Scale:1.0f];
        }
    }
}

/** @ghidraAddress 0x12f1c8 */
void GameSystem::LoadArtistNameTexture(MusicData *pMusicData) {
    if (m_pArtistNameTexture != nullptr) {
        m_pArtistNameTexture->Release();
        m_pArtistNameTexture = nullptr;
    }
    if (pMusicData == nil) {
        return;
    }

    if (UIScreen.mainScreen.scale > 1.0) {
        NSData *pData2x = [pMusicData artistNameImageWhite2xData];
        if (pData2x != nil) {
            m_pArtistNameTexture = [neTextureForiOS LoadTexture:pData2x Scale:2.0f];
        }
    }
    if (m_pArtistNameTexture == nullptr) {
        NSData *pData = [pMusicData artistNameImageWhiteData];
        if (pData != nil) {
            m_pArtistNameTexture = [neTextureForiOS LoadTexture:pData Scale:1.0f];
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
        m_flPlayfieldScale =
            static_cast<float>(static_cast<double>(nScaleStep) * kTabletScaleStep + 1.0);
        ComputePlayfieldLayoutY(m_flPlayfieldScale);

        S_VECTOR2 position{kTabletSheetPosX,
                           static_cast<float>(g_nPlayfieldFieldHeight - kTabletSheetPosYInset)};
        SetSheetLayerPosition(&position);
        SetSheetMargins(kTabletSheetMarginX, kSheetMarginY, kTabletSheetMarginX, kSheetMarginY);
        return;
    }

    m_flPlayfieldScale = 1.0f;
    ComputePlayfieldLayoutY(1.0f);

    // Each axis is clamped to the tall bucket independently; the orientation test then picks which
    // clamped pair to use.
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

    S_VECTOR2 position{static_cast<float>(nEffectiveHeight * 2 - kPhoneSheetPosXInset),
                       static_cast<float>(nEffectiveWidth * 2) * m_flPlayfieldScale +
                           kPhoneSheetPosYInsetA + kPhoneSheetPosYInsetB};
    SetSheetLayerPosition(&position);
}
