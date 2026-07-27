//
//  note_glow_layer.mm
//  REFLEC BEAT plus
//
//  The note-glow effect layer (NoteGlowLayer). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_glow_layer.h"

namespace {
// The default scale pair the constructor seeds.
constexpr float kInitialScale = 1.0f;
} // namespace

// The process-wide note-glow layer, created lazily by shared().
static NoteGlowLayer *g_pNoteGlowLayer = nullptr; // @ghidraAddress 0x3deb40

/** @ghidraAddress 0x1769a8 */
NoteGlowLayer *NoteGlowLayer::shared() {
    if (g_pNoteGlowLayer == nullptr) {
        g_pNoteGlowLayer = new NoteGlowLayer();
    }
    return g_pNoteGlowLayer;
}

/** @ghidraAddress 0x176964 */
NoteGlowLayer::NoteGlowLayer() {
    // The base constructor and member initialisers clear the sprite header and count state; the
    // default scale pair seeds to one.
    m_aScale[0] = kInitialScale;
    m_aScale[1] = kInitialScale;
}
