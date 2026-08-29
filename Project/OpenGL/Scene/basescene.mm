#include "basescene.h"

#include "deviceenvironment.h"

namespace rb {

/** @ghidraAddress 0x18bd9c */
BaseScene::BaseScene() {
    m_bIsPad = ::IsPad();
    m_bHardwareType9 = GetIsHardwareType9Flag();
}

} // namespace rb
