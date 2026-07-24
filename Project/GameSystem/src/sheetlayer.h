/**
 * @file
 * The note-sheet-layer geometry helpers, @c SheetLayer.
 */

#pragma once

class GameSystem;

/**
 * The sheet-layer geometry helpers. Each takes the target GameSystem, so they are modelled as
 * static members of the sheet-layer helper class (its full type is not yet reconstructed).
 */
class SheetLayer {
public:
    /**
     * @brief Stores the sheet-layer margins on @p pGameSystem and recomputes the far corner.
     * @ghidraAddress 0x12f394
     */
    static void SetSheetLayerMargins(
        float fLeft, float fTop, float fRight, float fBottom, GameSystem *pGameSystem);
    /**
     * @brief Stores the sheet-layer corner radius on @p pGameSystem and recomputes the insets.
     * @ghidraAddress 0x12f3c4
     */
    static void SetSheetLayerRadius(float fRadius, GameSystem *pGameSystem);
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
