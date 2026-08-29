#import "pause_gauge_layer.h"

#include <cassert>

#import "RBUserSettingData.h"
#include "game_scene.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "soundeffectmanager.h"
#include "sprite_uv_table.h"
#include "touchmanager.h"

namespace {
constexpr int kSoundEffectPauseGaugeCharge = 3;
constexpr int kSoundEffectPauseConfirm = 1;

constexpr const char *kPartsTextureName = "00_texture/gm_parts2";

constexpr int kLaneSlotStride = 2;

constexpr int kLaneSlotGroup[PauseGaugeLayer::kLaneSlotCount] = {
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};

constexpr int kPartsSlot = 1;

constexpr int kStateLoad = 0;
constexpr int kStateShowMenu = 1;
constexpr int kStateExecShow = 2;
constexpr int kStateDie = 3;

constexpr int kStateLoaded = 1;

constexpr int kNoSelectedTouch = -1;
constexpr int kNoSelectedLane = 4;
} // namespace

/** @ghidraAddress 0x1508b4 */
PauseGaugeLayer::PauseGaugeLayer() {
    m_nState = 0;
    m_bCharging = false;
    m_nSelectedTouchId = kNoSelectedTouch;
    m_nSelectedLane = kNoSelectedLane;
    m_pTexture = nullptr;
    for (int nSlot = 0; nSlot < kSlotCount; ++nSlot) {
        m_apSprites[nSlot] = nullptr;
        m_aSlotCapacity[nSlot] = 0;
    }
    for (int nLane = 0; nLane < kLaneSlotCount; ++nLane) {
        const int nGroup = kLaneSlotGroup[nLane];
        m_aLaneSlotId[nLane] = m_aSlotCapacity[nGroup];
        m_aSlotCapacity[nGroup] += kLaneSlotStride;
    }
    LoadSprites();
}

/** @ghidraAddress 0x150994 */
void PauseGaugeLayer::LoadSprites() {
    m_nThema = RBUserSettingData.sharedInstance.thema;
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    for (int nSlot = 0; nSlot < kSlotCount; ++nSlot) {
        m_apSprites[nSlot] = ne::CreateSpriteInstancer(m_aSlotCapacity[nSlot]);
        m_apSprites[nSlot]->RegisterGlobal();
        m_apSprites[nSlot]->SetVisible(true);
        if (nSlot == kPartsSlot) {
            m_apSprites[nSlot]->SetRefCountedMember(m_pTexture);
        }
        m_apSprites[nSlot]->SetSpriteCount(0);
    }
    m_nState = kStateLoaded;
}

/**
 * @ghidraAddress 0x150a7c
 * @ghidraAddress 0x150b00
 */
PauseGaugeLayer::~PauseGaugeLayer() {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    for (ne::C_SPRITE_INSTANCING_2D *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            // The sprite nodes are owned by the scene graph; flag them for the scene walker.
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
}

PauseGaugeRectSize g_aPauseGaugeRectVariant[PauseGaugeLayer::kLaneCount]; // @ghidraAddress 0x3dbe90
PauseGaugeRectSize g_aPauseGaugeRectDefault[PauseGaugeLayer::kLaneCount]; // @ghidraAddress 0x3dbeb0

// @ghidraAddress 0x308fe0
const PauseGaugeSpriteLayout g_aPauseGaugeLayoutDefault[PauseGaugeLayer::kLaneSlotCount] = {
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, -75.0f, 36.0f, 9.0f, 76.0f, 18.0f, 453},
    {0.0f, 0.0f, 36.0f, 9.0f, 76.0f, 18.0f, 454},
    {0.0f, 75.0f, 36.0f, 9.0f, 76.0f, 18.0f, 455},
    {0.0f, 0.0f, 0.0f, 25.0f, 39.0f, 50.0f, 456},
    {0.0f, 0.0f, 0.0f, 25.0f, 39.0f, 50.0f, 457},
    {0.0f, 0.0f, 0.0f, 25.0f, 39.0f, 50.0f, 458},
    {0.0f, 0.0f, 0.0f, 25.0f, 1.0f, 50.0f, 459},
    {0.0f, 0.0f, 0.0f, 25.0f, 1.0f, 50.0f, 460},
    {0.0f, 0.0f, 0.0f, 25.0f, 1.0f, 50.0f, 461},
    {0.0f, -75.0f, 119.0f, 24.0f, 238.0f, 48.0f, 462},
    {0.0f, 0.0f, 119.0f, 24.0f, 238.0f, 48.0f, 463},
    {0.0f, 75.0f, 119.0f, 24.0f, 238.0f, 48.0f, 464},
};

// @ghidraAddress 0x308e74
const PauseGaugeSpriteLayout g_aPauseGaugeLayoutAltFrame[PauseGaugeLayer::kLaneSlotCount] = {
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, -88.0f, 168.0f, 33.0f, 336.0f, 66.0f, 252},
    {0.0f, 0.0f, 168.0f, 33.0f, 336.0f, 66.0f, 253},
    {0.0f, 88.0f, 168.0f, 33.0f, 336.0f, 66.0f, 254},
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
    {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0},
};

namespace {
constexpr PauseGaugeRectSize kPauseGaugeRectVariant = {336, 66};
constexpr PauseGaugeRectSize kPauseGaugeRectDefault = {220, 50};
} // namespace

// Runs from the binary's __mod_init_func table (the pointer at 0x358cd0); without the constructor
// attribute both rectangle tables stay zero and no pause-menu item can be tapped.
/** @ghidraAddress 0x15145c */
__attribute__((constructor)) void SeedPauseGaugeLayoutTable(void) {
    @autoreleasepool {
        for (int nLane = 0; nLane < PauseGaugeLayer::kLaneCount; ++nLane) {
            g_aPauseGaugeRectVariant[nLane] = kPauseGaugeRectVariant;
            g_aPauseGaugeRectDefault[nLane] = kPauseGaugeRectDefault;
        }
    }
}

namespace {
int HalfExtent(int nSize) {
    const int nRounded = nSize < 0 ? nSize + 1 : nSize;
    return nRounded >> 1;
}

bool AxisInRect(float flCoord, float flCenter, int nSize) {
    const float flLow = flCenter - static_cast<float>(HalfExtent(nSize));
    const float flHigh = static_cast<float>(nSize) + flLow;
    return flLow <= flCoord && flCoord <= flHigh;
}
} // namespace

/** @ghidraAddress 0x150e8c */
void PauseGaugeLayer::EmitSprite(float flFlip,
                                 unsigned int nSlotIndex,
                                 const S_VECTOR2 &position,
                                 unsigned int nColorRgb,
                                 unsigned int nAlpha) {
    if (nSlotIndex >= kLaneSlotCount) {
        return;
    }
    const PauseGaugeSpriteLayout &layout =
        IsPad() ? g_aPauseGaugeLayoutAltFrame[nSlotIndex] : g_aPauseGaugeLayoutDefault[nSlotIndex];
    ne::C_SPRITE_INSTANCING_2D *pSprite = m_apSprites[kLaneSlotGroup[nSlotIndex]];

    const int nIndex = pSprite->GetSpriteCount();
    if (nIndex >= static_cast<int>(pSprite->GetCapacity())) {
        return;
    }
    const SpriteUvEntry &uv = g_aSpriteUvTable[layout.nUvIndex];

    pSprite->SetSpritePosition(nIndex, position);
    pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
    if (nSlotIndex == 0) {
        GameSystem *pGameSystem = GameSystem::GetGameSystem();
        pSprite->SetSpriteSize(
            nIndex, S_VECTOR2{pGameSystem->GetViewportWidth(), pGameSystem->GetViewportHeight()});
    } else {
        pSprite->SetSpriteSize(nIndex, S_VECTOR2{layout.flSizeW, layout.flSizeH});
    }
    pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pSprite->SetSpriteColor(nIndex, nColorRgb, nColorRgb, nColorRgb, nAlpha);
    pSprite->SetSpriteScale(nIndex, flFlip, 1.0f);
    pSprite->SetSpriteCount(nIndex + 1);
}

/** @ghidraAddress 0x1512fc */
bool PauseGaugeLayer::CheckPointInRect(float flX, float flY, unsigned int nLaneIndex) const {
    const PauseGaugeRectSize &size =
        IsPad() ? g_aPauseGaugeRectVariant[nLaneIndex] : g_aPauseGaugeRectDefault[nLaneIndex];
    const PauseGaugeLaneGeometry &lane = m_aLaneGeometry[nLaneIndex];
    return AxisInRect(flX, lane.flCenterX, size.nWidth) &&
           AxisInRect(flY, lane.flCenterY, size.nHeight);
}

namespace {
constexpr unsigned int kSecondPlayerLane = 1;
constexpr unsigned int kArrowSlotBase = 4;
constexpr unsigned int kCenterSlotBase = 7;
constexpr unsigned int kSingleSlotBase = 1;
constexpr unsigned int kColetteSlotBase = 10;
constexpr float kArrowFlipLeft = 1.0f;
constexpr float kArrowFlipRight = -1.0f;
constexpr unsigned int kOpaqueAlpha = 0xff;
} // namespace

/** @ghidraAddress 0x151000 */
void PauseGaugeLayer::RenderForLane(unsigned int nLaneIndex) {
    if (nLaneIndex > 2) {
        return;
    }
    const PauseGaugeLaneGeometry &lane = m_aLaneGeometry[nLaneIndex];
    unsigned int nAlpha = lane.bDimmed ? 0x80 : kOpaqueAlpha;

    const int nThema = RBUserSettingData.sharedInstance.thema;
    // Limelight and Colette dim the Exit lane during a pastel bonus, matching HandleExit's refusal.
    unsigned int nLaneAlpha = nAlpha;
    if (nThema == RBUserSettingDataThemeLimelight || nThema == RBUserSettingDataThemeColette) {
        const bool bPastelBonus = GameSystem::GetGameSystem()->GetPastelBonusType() != 0;
        nLaneAlpha = (bPastelBonus && nLaneIndex == kSecondPlayerLane) ? 0x80 : nAlpha;
    }

    const S_VECTOR2 center{lane.flCenterX, lane.flCenterY};
    unsigned int nSingleSlotBase = kSingleSlotBase;

    if (!IsPad() && nThema != RBUserSettingDataThemeColette) {
        const unsigned int nArrowSlot = nLaneIndex + kArrowSlotBase;
        const int nGaugeWidth = g_aPauseGaugeRectDefault[nLaneIndex].nWidth;
        const int nHalfWidth = nGaugeWidth < 0 ? (nGaugeWidth + 1) >> 1 : nGaugeWidth >> 1;
        const float flCenterInset = g_aPauseGaugeLayoutDefault[nArrowSlot].flSizeW;
        nLaneAlpha &= 0xff;

        const S_VECTOR2 leftArrow{center.x - static_cast<float>(nHalfWidth), center.y};
        EmitSprite(kArrowFlipLeft, nArrowSlot, leftArrow, nLaneAlpha, kOpaqueAlpha);
        const S_VECTOR2 rightArrow{center.x + static_cast<float>(nHalfWidth), center.y};
        EmitSprite(kArrowFlipRight, nArrowSlot, rightArrow, nLaneAlpha, kOpaqueAlpha);
        const S_VECTOR2 centerPos{flCenterInset + (center.x - static_cast<float>(nHalfWidth)),
                                  center.y};
        EmitSprite(static_cast<float>(nGaugeWidth) + flCenterInset * -2.0f,
                   nLaneIndex + kCenterSlotBase,
                   centerPos,
                   nLaneAlpha,
                   kOpaqueAlpha);
        nSingleSlotBase = kSingleSlotBase;
    } else if (!IsPad()) {
        nSingleSlotBase = kColetteSlotBase;
    }

    nLaneAlpha &= 0xff;
    EmitSprite(1.0f, nLaneIndex + nSingleSlotBase, center, nLaneAlpha, kOpaqueAlpha);
}

/** @ghidraAddress 0x150ba8 */
void PauseGaugeLayer::ShowPauseMenu() {
    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }
    if (!m_bCharging) {
        return;
    }
    m_nState = 2;
    m_nSelectedTouchId = kNoSelectedTouch;
    m_nSelectedLane = kNoSelectedLane;
    for (LaneGeometry &lane : m_aLaneGeometry) {
        lane.bDimmed = false;
    }
    ExecShow();
}

/** @ghidraAddress 0x1513c4 */
void PauseGaugeLayer::HandleExit() {
    if ((m_nThema == RBUserSettingDataThemeLimelight ||
         m_nThema == RBUserSettingDataThemeColette) &&
        GameSystem::GetGameSystem()->GetPastelBonusType() != 0) {
        return;
    }
    rb::GameScene *pScene = GameSystem::GetGameSystem()->GetCurrentScene();
    if (pScene != nullptr) {
        pScene->EnterPauseExitState();
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectPauseConfirm);
}

/** @ghidraAddress 0x15139c */
void PauseGaugeLayer::HandleResume() {
    if (GameSystem::GetGameSystem()->GetCurrentScene() != nullptr) {
        rb::GameScene::ResumePlayTimerAndBgm();
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectPauseConfirm);
}

/** @ghidraAddress 0x151434 */
void PauseGaugeLayer::HandleMusicRelease() {
    rb::GameScene *pScene = GameSystem::GetGameSystem()->GetCurrentScene();
    if (pScene != nullptr) {
        pScene->EnterMusicReleaseState();
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectPauseConfirm);
}

namespace {
constexpr unsigned int kMenuItemResume = 0;
constexpr unsigned int kMenuItemExit = 1;
constexpr unsigned int kMenuItemRelease = 2;
constexpr unsigned int kMenuItemCount = 3;
constexpr unsigned int kBackgroundSlot = 0;
constexpr unsigned int kBackgroundAlpha = 0xb2;
} // namespace

/** @ghidraAddress 0x150bfc */
void PauseGaugeLayer::ExecShow() {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flWidth = pGameSystem->GetViewportWidth();
    const float flHeight = pGameSystem->GetViewportHeight();

    // The menu items occupy layout records 1 through 3, one per lane.
    const PauseGaugeSpriteLayout *pLayout =
        IsPad() ? g_aPauseGaugeLayoutAltFrame : g_aPauseGaugeLayoutDefault;
    for (unsigned int nLane = 0; nLane < kMenuItemCount; ++nLane) {
        const PauseGaugeSpriteLayout &item = pLayout[nLane + 1];
        m_aLaneGeometry[nLane].flCenterX = flWidth * 0.5f + item.flOffsetX;
        m_aLaneGeometry[nLane].flCenterY = flHeight * 0.5f + item.flOffsetY;
    }

    TouchManager *pTouches = TouchManager::FetchSharedSingleton();
    if (m_nSelectedTouchId == kNoSelectedTouch) {
        const int nActive = pTouches->GetActiveTouchCount();
        for (int nSlot = 0; nSlot < nActive; ++nSlot) {
            TouchPoint *pTouch = pTouches->GetActiveTouch(nSlot);
            if (!pTouch->bIsNew) {
                continue;
            }
            for (unsigned int nLane = 0; nLane < kMenuItemCount; ++nLane) {
                if (CheckPointInRect(static_cast<float>(pTouch->nBeginX),
                                     static_cast<float>(pTouch->nBeginY),
                                     nLane)) {
                    m_nSelectedTouchId = pTouch->nId;
                    m_nSelectedLane = static_cast<int>(nLane);
                    break;
                }
            }
            if (m_nSelectedTouchId != kNoSelectedTouch) {
                break;
            }
        }
    }
    // Sequential rather than an else: acquisition falls into the drag block on the same frame.
    if (m_nSelectedTouchId != kNoSelectedTouch) {
        TouchPoint *pTouch = pTouches->FindTouchById(m_nSelectedTouchId);
        if (pTouch == nullptr) {
            m_nSelectedTouchId = kNoSelectedTouch;
            m_aLaneGeometry[static_cast<unsigned int>(m_nSelectedLane)].bDimmed = false;
            m_nSelectedLane = kNoSelectedLane;
        } else {
            const unsigned int nLane = static_cast<unsigned int>(m_nSelectedLane);
            const bool bInside = CheckPointInRect(static_cast<float>(pTouch->nCurrentX),
                                                  static_cast<float>(pTouch->nCurrentY),
                                                  nLane);
            bool bHighlight = false;
            if (bInside) {
                if (pTouch->bEnded) {
                    if (nLane == kMenuItemRelease) {
                        HandleMusicRelease();
                    } else if (nLane == kMenuItemExit) {
                        HandleExit();
                    } else {
                        assert(nLane == kMenuItemResume);
                        HandleResume();
                    }
                } else {
                    bHighlight = true;
                }
            }
            m_aLaneGeometry[nLane].bDimmed = bHighlight;
        }
    }

    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }
    const S_VECTOR2 origin{0.0f, 0.0f};
    EmitSprite(1.0f, kBackgroundSlot, origin, 0, kBackgroundAlpha);
    RenderForLane(0);
    RenderForLane(1);
    RenderForLane(2);

    if (!m_bCharging) {
        m_nState = 1;
    }
}

/** @ghidraAddress 0x150b38 */
void PauseGaugeLayer::OnFrame(int nElapsedMs) {
    (void)nElapsedMs; // The state machine ignores the frame delta; 0x150b38 never reads x1.
    switch (m_nState) {
    case kStateLoad:
        LoadSprites();
        return;
    case kStateShowMenu:
        ShowPauseMenu();
        return;
    case kStateExecShow:
        ExecShow();
        return;
    case kStateDie:
        MarkDead();
        return;
    default:
        assert(0);
    }
}

/** @ghidraAddress 0x150e58 */
void PauseGaugeLayer::SetCharging() {
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
