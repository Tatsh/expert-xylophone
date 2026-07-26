//
//  pause_gauge_layer.mm
//  REFLEC BEAT plus
//
//  The pause-gauge play-field layer (PauseGaugeLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#import "pause_gauge_layer.h"

#import "soundeffectmanager.h"

namespace {
// The themed sound-effect slot the pause gauge plays when it starts charging.
constexpr int kSoundEffectPauseGaugeCharge = 3;
} // namespace

/** @ghidraAddress 0x150e58 */
void PauseGaugeLayer::SetCharging() {
    // Only the first entry into the charging state plays the sound; later frames are a no-op.
    if (m_bCharging) {
        return;
    }
    m_bCharging = true;
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectPauseGaugeCharge);
}

/** @ghidraAddress 0x150e84 */
void PauseGaugeLayer::ClearCharging() {
    m_bCharging = false;
}
