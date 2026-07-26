//
//  play_task.mm
//  REFLEC BEAT plus
//
//  The gameplay task. Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values
//  are relative to the program image base.
//

#include "play_task.h"

#include <new>

#include "gamesystem.h"
#include "pause_gauge_layer.h"

// The initial state the constructor seeds; the state machine advances from here on the first frame.
static constexpr int kInitialState = 2;

/** @ghidraAddress 0x14a21c */
PlayTask::PlayTask() {
    // The UI-layer base constructor ran first and the compiler installed the vtable; seed the play
    // state (the base fields and the reserved sub-state are already zero-initialised).
    m_nState = 0;
    m_nPlayTime = 0;
    m_nInitialState = kInitialState;
}

/** @ghidraAddress 0x14b6e0 */
bool PlayTask::RefreshPauseGaugeAndGetActiveFlag() {
    if (!GameSystem::GetGameSystem()->GetPaused()) {
        // Not paused: release any charge and report gameplay active.
        if (m_pPauseGauge != nullptr) {
            m_pPauseGauge->ClearCharging();
        }
        return true;
    }
    // Paused: charge the gauge unless it is being held down, and report gameplay inactive.
    if (!m_bPauseGaugeHeld && m_pPauseGauge != nullptr) {
        m_pPauseGauge->SetCharging();
    }
    return false;
}

/** @ghidraAddress 0x12ee88 */
void PlayTask::GetInstance(PlayTask **ppOut) {
    if (*ppOut == nullptr) {
        PlayTask *pTask = new PlayTask();
        // Register the task in the engine's per-frame list at priority 1.
        pTask->InsertSorted(1);
        *ppOut = pTask;
    }
}
