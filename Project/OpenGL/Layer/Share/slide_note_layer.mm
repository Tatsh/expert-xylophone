//
//  slide_note_layer.mm
//  REFLEC BEAT plus
//
//  The slide-note render layer (SlideNoteLayer). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "slide_note_layer.h"

// The process-wide slide-note layer, created lazily by shared().
static SlideNoteLayer *g_pSlideNoteLayer = nullptr; // @ghidraAddress 0x3dc658

// The number of active slide-note trails, shared with the trail animator.
int g_nActiveSlideTrailCount = 0; // @ghidraAddress 0x3dc650

namespace {
// The invalid-clock sentinel the layer starts with (no sample taken yet).
constexpr float kInvalidClock = -1.0f;
} // namespace

/** @ghidraAddress 0x95a18 */
SlideNoteLayer::SlideNoteLayer() {
    // The base constructor cached the device flags and theme; every trail record, sprite batch,
    // batch count, and the leading pointer start zero from their member initialisers, matching the
    // binary's field-by-field clears.
    m_bBuilt = false;
    m_flLastClock = kInvalidClock;
    g_nActiveSlideTrailCount = 0;
}

/** @ghidraAddress 0x95a90 */
SlideNoteLayer *SlideNoteLayer::shared() {
    if (g_pSlideNoteLayer == nullptr) {
        // The binary allocates the raw 0xe08-byte object and runs the constructor.
        g_pSlideNoteLayer = new SlideNoteLayer();
    }
    return g_pSlideNoteLayer;
}
