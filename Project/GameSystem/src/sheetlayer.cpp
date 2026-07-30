#include "sheetlayer.h"

#include "gamesystem.h"

// The corner radius is also kept pre-halved and pre-scaled, and the inset the sheet's position
// leaves once the radius is taken off it is kept both whole and halved, so the per-frame layout
// never divides. The scale is the 1/64 in the pool at 0x308a80.
constexpr float kSheetRadiusHalfScale = 0.5f;
constexpr float kSheetRadiusScale = 1.0f / 64.0f;

void GameSystem::SetSheetLayerRadius(float fRadius) {
    m_flSheetRadius = fRadius;
    m_flSheetRadiusHalf = fRadius * kSheetRadiusHalfScale;
    m_flSheetRadiusScaled = fRadius * kSheetRadiusScale;

    m_flSheetInsetX = m_flSheetPosX - fRadius;
    m_flSheetInsetY = m_flSheetPosY - fRadius;
    m_flSheetInsetHalfX = m_flSheetInsetX * kSheetRadiusHalfScale;
    m_flSheetInsetHalfY = m_flSheetInsetY * kSheetRadiusHalfScale;

    // The diameter is squared and kept so a hit test can compare squared distances without a
    // square root. The binary adds the radius to itself rather than multiplying by two.
    const float flDiameter = fRadius + fRadius;
    m_flSheetDiameterSq = flDiameter * flDiameter;
}
