#import "play_field_layer_base.h"

#import "../../RBUserSettingData.h"
#import "../../neEngineBridge.h"

/** @ghidraAddress 0x109d84 */
void PlayFieldLayerBase::InitBase() {
    m_bFontVariant = static_cast<unsigned char>(IsPad());
    m_fIsHardwareType9 = GetIsHardwareType9Flag();
    m_nThema = static_cast<int>([RBUserSettingData sharedInstance].thema);
}
