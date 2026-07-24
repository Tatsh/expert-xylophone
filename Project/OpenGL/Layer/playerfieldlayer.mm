#include "playerfieldlayer.h"

// The process-wide player-field layer, created lazily by shared().
static PlayerFieldLayer *g_pPlayerFieldLayer = nullptr; // @ghidraAddress 0x3df2f0

/** @ghidraAddress 0x18b668 */
PlayerFieldLayer *PlayerFieldLayer::shared() {
    if (g_pPlayerFieldLayer == nullptr) {
        // The binary allocates the raw object, runs the play-field base initialiser, then seeds the
        // presentation transform (identity scale) and zeroes the score-digit records;
        // value-initialisation covers the zeroing here.
        g_pPlayerFieldLayer = new PlayerFieldLayer();
    }
    return g_pPlayerFieldLayer;
}
