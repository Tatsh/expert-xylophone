#include "playfieldlayerbase.h"

#import "RBUserSettingData.h"
#import "deviceenvironment.h"

/** @ghidraAddress 0x109d84 */
PlayFieldLayerBase::PlayFieldLayerBase() {
    // ::IsPad is the free device query; the member IsPad() accessor would shadow it here.
    m_bIsPad = ::IsPad();
    m_fIsHardwareType9 = GetIsHardwareType9Flag();
    m_nThema = static_cast<int>([RBUserSettingData sharedInstance].thema);
}

/** @ghidraAddress 0x109e04 */
void PlayFieldLayerBase::RefreshThema() {
    m_nThema = static_cast<int>([RBUserSettingData sharedInstance].thema);
}
