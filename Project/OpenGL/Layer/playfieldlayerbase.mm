#include "playfieldlayerbase.h"

#import "RBUserSettingData.h"
#import "deviceenvironment.h"

/** @ghidraAddress 0x109d84 */
PlayFieldLayerBase::PlayFieldLayerBase() {
    m_bFontVariant = static_cast<unsigned char>(IsPad());
    m_fIsHardwareType9 = GetIsHardwareType9Flag();
    m_nThema = static_cast<int>([RBUserSettingData sharedInstance].thema);
}

/** @ghidraAddress 0x109e04 */
void PlayFieldLayerBase::RefreshThema() {
    m_nThema = static_cast<int>([RBUserSettingData sharedInstance].thema);
}
