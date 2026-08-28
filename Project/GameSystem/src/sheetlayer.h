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
     * @param fLeft The left margin.
     * @param fTop The top margin.
     * @param fRight The right margin.
     * @param fBottom The bottom margin.
     * @param pGameSystem The game system the margins are stored on.
     * @ghidraAddress 0x12f394
     */
    static void SetSheetLayerMargins(
        float fLeft, float fTop, float fRight, float fBottom, GameSystem *pGameSystem);
};
