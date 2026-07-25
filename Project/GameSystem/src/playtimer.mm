#import "playtimer.h"

// The engine play-timing singleton, created on first use by PlayTimer::shared.
PlayTimer *g_pPlayTimer = nullptr; // @ghidraAddress 0x3de020

/** @ghidraAddress 0x131868 */
PlayTimer *PlayTimer::shared() {
    if (g_pPlayTimer == nullptr) {
        // The binary allocates the raw 0x40-byte object and zeroes the timing, OS-tier, and paused
        // fields; the zero-initialising members below reproduce that.
        g_pPlayTimer = new PlayTimer();
    }
    return g_pPlayTimer;
}
