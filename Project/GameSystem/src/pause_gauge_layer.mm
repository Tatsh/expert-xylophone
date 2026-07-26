//
//  pause_gauge_layer.mm
//  REFLEC BEAT plus
//
//  The pause-gauge play-field layer (PauseGaugeLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#import "pause_gauge_layer.h"

#import "RBUserSettingData.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "soundeffectmanager.h"

namespace {
// The themed sound-effect slot the pause gauge plays when it starts charging.
constexpr int kSoundEffectPauseGaugeCharge = 3;

// The pause-gauge parts atlas.
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";

// The number of sprite-slot ids the gauge distributes across the two slots (one gauge sprite plus
// its two side arrows per reachable lane).
constexpr int kLaneSlotStride = 2;

// The per-lane slot-group table: lane 0 uses the gauge slot, every other lane the parts slot.
constexpr int kLaneSlotGroup[PauseGaugeLayer::kLaneSlotCount] = {
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};

// The theme code for which the parts slot binds the shared parts atlas (the second, parts, slot).
constexpr int kPartsSlot = 1;

// The build state the sprite loader leaves the layer in.
constexpr int kStateLoaded = 1;

// The sentinels for "no menu item is being dragged" and "no menu lane is selected".
constexpr int kNoSelectedTouch = -1;
constexpr int kNoSelectedLane = 4;
} // namespace

/** @ghidraAddress 0x1508b4 */
PauseGaugeLayer::PauseGaugeLayer() {
    // The UI-layer base constructor ran first and the compiler installed the task dispatch vtable.
    m_nState = 0;
    m_bCharging = false;
    m_nSelectedTouchId = kNoSelectedTouch;
    m_nSelectedLane = kNoSelectedLane;
    m_pTexture = nullptr;
    for (int nSlot = 0; nSlot < kSlotCount; ++nSlot) {
        m_apSprites[nSlot] = nullptr;
        m_aSlotCapacity[nSlot] = 0;
    }
    // Give each lane the next free pair of sprite indices within its slot group.
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
        // The parts slot binds the shared parts atlas; the gauge slot leaves its texture unset.
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
    for (ne::C_SPRITE_INSTANCING *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            // The sprite nodes are owned by the scene graph; flag them for the scene walker.
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
}

// The per-lane gauge rectangle sizes, seeded by SeedPauseGaugeLayoutTable.
PauseGaugeRectSize g_aPauseGaugeRectVariant[PauseGaugeLayer::kLaneCount]; // @ghidraAddress 0x3dbe90
PauseGaugeRectSize g_aPauseGaugeRectDefault[PauseGaugeLayer::kLaneCount]; // @ghidraAddress 0x3dbeb0

namespace {
// The gauge rectangle sizes each device layout uses for every lane: the font-variant device draws
// a 336x66 rectangle, every other device a 220x50 one.
constexpr PauseGaugeRectSize kPauseGaugeRectVariant = {336, 66};
constexpr PauseGaugeRectSize kPauseGaugeRectDefault = {220, 50};
} // namespace

/** @ghidraAddress 0x15145c */
void SeedPauseGaugeLayoutTable(void) {
    @autoreleasepool {
        for (int nLane = 0; nLane < PauseGaugeLayer::kLaneCount; ++nLane) {
            g_aPauseGaugeRectVariant[nLane] = kPauseGaugeRectVariant;
            g_aPauseGaugeRectDefault[nLane] = kPauseGaugeRectDefault;
        }
    }
}

namespace {
// Rounds a rectangle dimension toward zero before halving it, matching the binary's
// (n < 0 ? n + 1 : n) >> 1 half-extent computation for a signed size.
int HalfExtent(int nSize) {
    const int nRounded = nSize < 0 ? nSize + 1 : nSize;
    return nRounded >> 1;
}

// Tests whether a coordinate lies within [center - halfExtent, center - halfExtent + size].
bool AxisInRect(float flCoord, float flCenter, int nSize) {
    const float flLow = flCenter - static_cast<float>(HalfExtent(nSize));
    const float flHigh = static_cast<float>(nSize) + flLow;
    return flLow <= flCoord && flCoord <= flHigh;
}
} // namespace

namespace {
// One UV-table record (the shared sprite UV atlas at 0x2efcc8, 16-byte stride): the UV origin and
// UV size, indexed by a layout record's UV index.
struct SpriteUvEntry {
    float flOriginU = {};
    float flOriginV = {};
    float flSizeU = {};
    float flSizeV = {};
};
} // namespace

// The shared sprite UV atlas the layout records index. Read-only data embedded in the binary.
extern const SpriteUvEntry g_aSpriteUvTable[]; // @ghidraAddress 0x2efcc8

/** @ghidraAddress 0x150e8c */
void PauseGaugeLayer::EmitSprite(float flFlip,
                                 unsigned int nSlotIndex,
                                 const S_VECTOR2 &position,
                                 unsigned int nColorRgb,
                                 unsigned int nAlpha) {
    // Only the reachable lanes have a layout record.
    if (nSlotIndex >= kLaneSlotCount) {
        return;
    }
    // The alt-frame device uses its own layout table.
    const PauseGaugeSpriteLayout &layout = IsFontVariant() ?
                                               g_aPauseGaugeLayoutAltFrame[nSlotIndex] :
                                               g_aPauseGaugeLayoutDefault[nSlotIndex];
    ne::C_SPRITE_INSTANCING *pSprite = m_apSprites[kLaneSlotGroup[nSlotIndex]];

    // Claim the next free sprite in the instancer, if any remain.
    const int nIndex = pSprite->GetSpriteCount();
    if (nIndex >= static_cast<int>(pSprite->GetCapacity())) {
        return;
    }
    const SpriteUvEntry &uv = g_aSpriteUvTable[layout.nUvIndex];

    pSprite->SetSpritePosition(nIndex, position);
    pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
    // The gauge slot (0) sizes itself to the whole play-field viewport; the others use the record.
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
    const PauseGaugeRectSize &size = IsFontVariant() ? g_aPauseGaugeRectVariant[nLaneIndex] :
                                                       g_aPauseGaugeRectDefault[nLaneIndex];
    const PauseGaugeLaneGeometry &lane = m_aLaneGeometry[nLaneIndex];
    return AxisInRect(flX, lane.flCenterX, size.nWidth) &&
           AxisInRect(flY, lane.flCenterY, size.nHeight);
}

namespace {
// The two-player lane whose gauge dims when no pastel bonus is active on the Limelight/Colette
// themes, and the slot-index bases the arrow and single-sprite emits use.
constexpr unsigned int kSecondPlayerLane = 1;
constexpr unsigned int kArrowSlotBase = 4;    // left/right arrow slot = lane + 4.
constexpr unsigned int kCenterSlotBase = 7;   // centre element slot = lane + 7.
constexpr unsigned int kSingleSlotBase = 1;   // single-sprite slot (main frame) = lane + 1.
constexpr unsigned int kColetteSlotBase = 10; // single-sprite slot (Colette) = lane + 10.
// The horizontal flip factors for the left and right arrows.
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
    // Dimmed lanes draw at half alpha.
    unsigned int nAlpha = lane.bDimmed ? 0x80 : kOpaqueAlpha;

    const int nThema = RBUserSettingData.sharedInstance.thema;
    // The Limelight and Colette themes dim the 2P lane unless a pastel bonus is active.
    unsigned int nLaneAlpha = nAlpha;
    if (nThema == RBUserSettingDataThemeLimelight || nThema == RBUserSettingDataThemeColette) {
        const bool bPastelBonus = GameSystem::GetGameSystem()->GetPastelBonusType() != 0;
        nLaneAlpha = (bPastelBonus || nLaneIndex != kSecondPlayerLane) ? nAlpha : 0x80;
    }

    const S_VECTOR2 center{lane.flCenterX, lane.flCenterY};
    unsigned int nSingleSlotBase = kSingleSlotBase;

    // On the main frame with a non-Colette theme, the gauge is a left arrow, a right arrow, and a
    // centre element; the alt frame and the Colette theme draw a single sprite instead.
    if (!IsFontVariant() && nThema != RBUserSettingDataThemeColette) {
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
    } else if (!IsFontVariant()) {
        // The Colette theme on the main frame draws a single sprite at its own slot base.
        nSingleSlotBase = kColetteSlotBase;
    }

    nLaneAlpha &= 0xff;
    EmitSprite(1.0f, nLaneIndex + nSingleSlotBase, center, nLaneAlpha, kOpaqueAlpha);
}

/** @ghidraAddress 0x150ba8 */
void PauseGaugeLayer::ShowPauseMenu() {
    // Reset every instancer's live sprite count before (re-)emitting.
    for (ne::C_SPRITE_INSTANCING *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }
    // The menu only opens once the gauge has fully charged.
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

/** @ghidraAddress 0x1508b0 */
void PauseGaugeLayer::OnFrame(void *pFrameArg) {
    (void)pFrameArg; // The pause gauge does no per-frame work; its sprites are rendered externally.
}

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
