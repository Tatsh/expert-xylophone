#include "sheetlayer.h"

#include "gamesystem.h"

constexpr float kSheetRadiusHalfScale = 0.5f;
constexpr float kSheetRadiusScale = 1.0f / 64.0f; // @ghidraAddress 0x308a80

void GameSystem::SetSheetLayerMargins(float fLeft, float fTop, float fRight, float fBottom) {
    m_flSheetMarginLeft = fLeft;
    m_flSheetMarginTop = fTop;
    m_flSheetMarginRight = fRight;
    m_flSheetMarginBottom = fBottom;

    m_flSheetFarX = m_flSheetPosX + fLeft + fRight;
    m_flSheetFarY = m_flSheetPosY + fTop + fBottom;
}

void GameSystem::SetSheetLayerRadius(float fRadius) {
    m_flSheetRadius = fRadius;
    m_flSheetRadiusHalf = fRadius * kSheetRadiusHalfScale;
    m_flSheetRadiusScaled = fRadius * kSheetRadiusScale;

    m_flSheetInsetX = m_flSheetPosX - fRadius;
    m_flSheetInsetY = m_flSheetPosY - fRadius;
    m_flSheetInsetHalfX = m_flSheetInsetX * kSheetRadiusHalfScale;
    m_flSheetInsetHalfY = m_flSheetInsetY * kSheetRadiusHalfScale;

    const float flDiameter = fRadius + fRadius;
    m_flSheetDiameterSq = flDiameter * flDiameter;
}
