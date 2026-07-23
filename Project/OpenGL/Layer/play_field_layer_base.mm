#import "play_field_layer_base.h"

#import "../../RBUserSettingData.h"
#import "../../neEngineBridge.h"

/** @ghidraAddress 0x109d84 */
PlayFieldLayerBase *InitBaseLayer(PlayFieldLayerBase *pLayer) {
    pLayer->m_bFontVariant = static_cast<unsigned char>(IsPad());
    pLayer->m_fIsHardwareType9 = GetIsHardwareType9Flag();
    pLayer->m_nThema = static_cast<int>([RBUserSettingData sharedInstance].thema);
    return pLayer;
}
