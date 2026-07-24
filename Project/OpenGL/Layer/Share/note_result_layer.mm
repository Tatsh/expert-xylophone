//
//  note_result_layer.mm
//  REFLEC BEAT plus
//
//  The note-result effect layer (NoteResultLayer). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_result_layer.h"

#include <cassert>

// The process-wide note-result effect layer, created lazily by shared().
static NoteResultLayer *g_pNoteResultLayer = nullptr; // @ghidraAddress 0x3df238

namespace {

// The layer's initial animation state and its default per-quad scale.
constexpr int kInitialState = 1;
constexpr float kInitialScale = 1.0f;

} // namespace

/** @ghidraAddress 0x189294 */
NoteResultLayer::NoteResultLayer() {
    m_pHandle = nullptr;
    m_pSprites = nullptr;
    m_nSpriteCount = 0;
    for (int nQuad = 0; nQuad < kPositionCount; ++nQuad) {
        m_aQuadPos[nQuad] = S_VECTOR2{};
        m_aQuads[nQuad] = ResultQuad{};
    }
    m_nState = kInitialState;
    m_bCreated = false;
    m_flScaleA = kInitialScale;
    m_flScaleB = kInitialScale;
}

/** @ghidraAddress 0x1892fc */
NoteResultLayer *NoteResultLayer::shared() {
    if (g_pNoteResultLayer == nullptr) {
        g_pNoteResultLayer = new NoteResultLayer();
    }
    return g_pNoteResultLayer;
}

/** @ghidraAddress 0x1895e8 */
void NoteResultLayer::Create(unsigned int nPos, int nJudge, int nNumber) {
    assert(static_cast<int>(nPos) >= 0 && nPos < kPositionCount);
    assert(nJudge >= 0 && nJudge < kJudgeTypeCount);

    ResultQuad &quad = m_aQuads[nPos];
    quad.bActive = true;
    quad.nJudge = nJudge;
    quad.flTimer = 0.0f;
    quad.nNumber = nNumber;
}
