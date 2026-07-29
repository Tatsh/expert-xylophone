#include "full_combo_colette_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#include "../Share/sprite_uv_table.h"
#import "AudioManager.h"
#include "curve.h"
#include "engineglobals.h"
#include "full_combo_colette_sprite_table.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#include "vectormath.h"

// The process-wide Colette full-combo layer, created lazily by shared().
static FullComboColetteLayer *g_pFullComboColetteLayer = nullptr; // @ghidraAddress 0x3dc668

// The shared sprite-UV atlas the descriptor entries index by uvIndex.
extern const SpriteUvEntry g_aSpriteUvTable[]; // @ghidraAddress 0x2efcc8

// The Colette full-combo sprite-type descriptor table (declared in
// full_combo_colette_sprite_table.h): read-only ROM data transcribed from the binary at
// 0x3005f0, giving each type its batch group, anchor, size, and UV-table index.
const ColetteFullComboSpriteType g_aColetteFullComboSpriteTypes[kColetteFullComboSpriteTypeCount] =
    {
        {2, 23.0f, 23.5f, 46.0f, 47.0f, 63},    // 0
        {2, 19.5f, 23.0f, 39.0f, 46.0f, 93},    // 1
        {2, 19.0f, 23.0f, 38.0f, 46.0f, 94},    // 2
        {2, 18.5f, 23.0f, 37.0f, 46.0f, 95},    // 3
        {2, 18.5f, 23.0f, 37.0f, 46.0f, 96},    // 4
        {2, 21.0f, 23.0f, 42.0f, 46.0f, 97},    // 5
        {2, 21.0f, 23.0f, 42.0f, 46.0f, 98},    // 6
        {2, 22.5f, 23.0f, 45.0f, 46.0f, 99},    // 7
        {2, 20.0f, 23.0f, 40.0f, 46.0f, 100},   // 8
        {2, 21.0f, 23.0f, 42.0f, 46.0f, 101},   // 9
        {2, 7.0f, 23.0f, 14.0f, 46.0f, 102},    // 10
        {1, 32.0f, 106.0f, 64.0f, 106.0f, 106}, // 11
        {1, 32.0f, 106.0f, 64.0f, 106.0f, 106}, // 12
        {1, 32.0f, 106.0f, 64.0f, 106.0f, 107}, // 13
        {1, 32.0f, 106.0f, 64.0f, 106.0f, 107}, // 14
        {1, 50.0f, 50.0f, 100.0f, 100.0f, 92},  // 15
        {1, 50.0f, 50.0f, 100.0f, 100.0f, 92},  // 16
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 17
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 18
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 19
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 20
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 21
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 22
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 23
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 24
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 25
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 26
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 27
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 28
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 29
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 30
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 31
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 32
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 33
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 34
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 35
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 36
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 37
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 38
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 39
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 40
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 41
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 42
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 43
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 44
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 45
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 46
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 47
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 48
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 49
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 50
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 51
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 52
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 53
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 109},   // 54
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 55
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 56
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 57
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 58
        {1, 50.0f, 50.0f, 100.0f, 100.0f, 91},  // 59
        {1, 50.0f, 50.0f, 100.0f, 100.0f, 91},  // 60
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 61
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 62
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 63
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 64
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 65
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 66
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 67
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 68
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 104},   // 69
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 70
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 71
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 72
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 73
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 74
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 75
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 76
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 77
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 78
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 79
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 80
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 81
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 82
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 83
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 84
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 85
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 86
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 87
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 88
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 89
        {1, 23.0f, 23.5f, 46.0f, 47.0f, 105},   // 90
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 91
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 92
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 93
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 94
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 95
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 96
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 97
        {1, 20.0f, 20.0f, 40.0f, 40.0f, 108},   // 98
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 99
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 100
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 101
        {1, 23.0f, 22.0f, 46.0f, 44.0f, 110},   // 102
};

namespace {

// The layout size the constructor seeds.
constexpr float kLayoutWidth = 384.0f;
constexpr float kLayoutHeight = 1098.0f;

// The atlas the layer loads into all three of its texture fields (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x2ff050).
constexpr unsigned int kSlotCapacities[] = {32, 256, 32};

// The per-slot texture-field selector (@ghidraAddress 0x2ff05c): the index into the layer's three
// texture fields for each slot.
constexpr int kSlotTextureField[] = {0, 1, 2};

// The slot that receives additive blend mode, and that mode's identifier.
constexpr int kAdditiveBlendSlot = 1;
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x9b118 */
FullComboColetteLayer::FullComboColetteLayer() {
    // The base constructor runs first; the remaining state is already zero-cleared by the member
    // initialisers, so only the layout size is seeded here.
    m_flWidth = kLayoutWidth;
    m_flHeight = kLayoutHeight;
}

/** @ghidraAddress 0x9b18c */
FullComboColetteLayer *FullComboColetteLayer::shared() {
    if (g_pFullComboColetteLayer == nullptr) {
        // The binary allocates the raw 0x68-byte object and runs its initialiser, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pFullComboColetteLayer = new FullComboColetteLayer();
    }
    return g_pFullComboColetteLayer;
}

/** @ghidraAddress 0x9b1dc */
void FullComboColetteLayer::InitializeBackgroundSpriteLayers() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture0 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    m_pTexture1 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    m_pTexture2 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pTexture0, m_pTexture1, m_pTexture2};

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind its mapped atlas, clear its sprite count, put the middle slot in additive blend,
    // and enable each slot's two texture-environment parameters.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        m_apSprites[nSlot] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        pSprite->SetSpriteCount(0);
        if (nSlot == kAdditiveBlendSlot) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x9b2e4 */
void FullComboColetteLayer::CreateFullComboColette(unsigned int nColor) {
    assert(static_cast<int>(nColor) >= 0 && nColor < kColorCount);
    EffectRecord &effect = m_aEffects[nColor];
    effect.m_bActive = true;
    effect.m_flTimer = 0.0f;
    effect.m_bVoiceFired = false;
}

/** @ghidraAddress 0x9c264 */
void FullComboColetteLayer::CreateSprite(int nType,
                                         const S_VECTOR2 *pPosition,
                                         unsigned int nAlpha,
                                         float flScaleX,
                                         float flScaleY,
                                         float flRotation) {
    assert(nType >= 0);
    assert(nType < kColetteFullComboSpriteTypeCount);

    const ColetteFullComboSpriteType &spriteType = g_aColetteFullComboSpriteTypes[nType];
    const unsigned int nGroup = spriteType.nGroup;

    // Skip the sprite when the group's batch is already full.
    const int nIndex = m_aSpriteCounts[nGroup];
    if (nIndex >= static_cast<int>(kSlotCapacities[nGroup])) {
        return;
    }

    const SpriteUvEntry &uv = g_aSpriteUvTable[spriteType.nUvIndex];
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nGroup];

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{spriteType.flAnchorX, spriteType.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, spriteType.flSizeH});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    ++m_aSpriteCounts[nGroup];
}

/** @ghidraAddress 0x9b35c */
void FullComboColetteLayer::ClearEffectFlags() {
    for (EffectRecord &effect : m_aEffects) {
        effect.m_bActive = false;
    }
}

/** @ghidraAddress 0x9b378 */
bool FullComboColetteLayer::IsAnyEffectActive() const {
    for (const EffectRecord &effect : m_aEffects) {
        if (effect.m_bActive) {
            return true;
        }
    }
    return false;
}

// The number of frames the layer has run for, bumped once per frame that advanced the clock at all
// (@ghidraAddress 0x3dc660). Only the strobing fourth mote fan reads it.
static int g_nColetteFullComboFrameCount = 0;

namespace {

// The number of play sides the effect can run on, one per player colour.
constexpr int kSideCount = 2;

// The frame time above which the frame counter advances (@ghidraAddress 0x2ee878). At a
// millisecond clock every real frame clears it, so the counter is effectively a frame tally.
constexpr double kFrameCountThreshold = 0.001;

// The animation clock past which an effect record retires (@ghidraAddress 0x2feff0), and the window
// inside which it fires its themed voice cue exactly once (@ghidraAddress 0x2feff4 and 0x2f8540).
// Unlike the Classic and Limelight layers this window is closed at both ends.
constexpr float kEffectDuration = 2000.0f;
constexpr float kVoiceCueClockMin = 500.0f;
constexpr float kVoiceCueClockMax = 1000.0f;

// The bias the letters and the banner sample their curves at (@ghidraAddress 0x2feff8).
constexpr float kLetterClockBias = -500.0f;

// The themed voice cue the effect announces itself with.
constexpr int kFullComboVoiceId = 9;

// The game types that leave the rival's side silent. The binary's bitwise test,
// (gameType | 2) == 2, admits exactly game types 0 and 2 — the single-player modes.
constexpr int kSinglePlayerGameTypeMask = 2;

// The game type whose letters mirror onto the other side.
constexpr int kVersusGameType = 1;

// The half-turn rotation a mirrored side takes, in radians (@ghidraAddress 0x2fe894), and the
// double-precision half turn the first mote fan adds to its curve-driven rotation
// (@ghidraAddress 0x2f85a0).
constexpr float kMirrorRotation = 3.1415927f;
constexpr double kMirrorRotationExact = 3.141592653589793;

// The unit-interval-to-byte alpha scale (@ghidraAddress 0x2eed00).
constexpr float kAlphaScale = 255.0f;

// The rotation each side's flare pair takes, indexed by whether the side is the local player's
// (@ghidraAddress 0x2ff068).
constexpr float kSideRotation[kSideCount] = {3.1415927f, 0.0f};

// The centred flare pair's screen position (@ghidraAddress 0x2f8550 and 0x2fefFC). The layer
// converts each to a layout-relative offset by subtracting its own size.
constexpr float kFlareScreenX = 384.0f;
constexpr float kFlareScreenY = 1105.0f;

// How far the letters' and banner's centre line is inset from each near lane row.
constexpr int kLetterRowInset = 232;

// The sprite count of each group, and the keyframe-pair counts of their curves.
constexpr int kFanACount = 2;
constexpr int kFanBCount = 9;
constexpr int kFanCCount = 21;
constexpr int kFanDCount = 12;
constexpr int kLetterCount = 10;
constexpr int kThreePointCurve = 3;
constexpr int kTwoPointCurve = 2;
constexpr int kFourPointCurve = 4;

// Each group's first sprite kind, indexed by side; every group's kind advances by one per sprite.
constexpr int kFanAKindBase[kSideCount] = {0x3b, 0xf};
constexpr int kFanBKindBase[kSideCount] = {0x3d, 0x11};
constexpr int kFanDKindBase[kSideCount] = {0x5b, 0x2f};
constexpr int kFlareBackKind[kSideCount] = {0xd, 0xb};
constexpr int kFlareFrontKind[kSideCount] = {0xe, 0xc};

// The fixed alpha the back flare draws at; it never fades.
constexpr unsigned int kFlareBackAlpha = 0x7f;

// The banner's sprite kind, and the offset added to the letter loop's counter to give its kind. The
// letter loop counts from -10 up to 0, so its kinds run 1 through 10 rather than 0 through 9.
constexpr int kBannerKind = 0;
constexpr int kLetterKindBias = 0xb;

// The strobe the fourth mote fan runs on: it draws for the first three frames of every six.
constexpr int kFanDStrobePeriod = 6;
constexpr int kFanDStrobeOnFrames = 3;

// Each mote fan's layout, as a screen X and the inset of its row above the near lane's bottom. The
// binary rebuilds these on the stack every frame from g_nPlayfieldNearRowBottom and
// g_nPlayfieldCentreSplit.
struct MoteLayout {
    float flScreenX;
    int nRowInset;
};

constexpr MoteLayout kFanALayout[kFanACount] = {{12.0f, 60}, {0.0f, 120}};

// Entries 4 and 5 sit on the 30-inset row, not the 60-inset one their neighbours use: the binary
// reuses the earlier row value there. Faithful, not a transcription slip.
constexpr MoteLayout kFanBLayout[kFanBCount] = {
    {-234.0f, 30},
    {-234.0f, 30},
    {-134.0f, 20},
    {-134.0f, 20},
    {-114.0f, 30},
    {-114.0f, 30},
    {216.0f, 60},
    {216.0f, 60},
    {-369.0f, 120},
};

constexpr MoteLayout kFanCLayout[kFanCCount] = {
    {30.0f, 90},   {30.0f, 90},    {10.0f, 100},   {10.0f, 100}, {216.0f, 50},  {216.0f, 50},
    {146.0f, 30},  {146.0f, 30},   {126.0f, 40},   {126.0f, 40}, {-34.0f, 60},  {-34.0f, 60},
    {-294.0f, 30}, {-294.0f, 30},  {266.0f, 30},   {266.0f, 30}, {-192.0f, 60}, {-192.0f, 60},
    {10.0f, 100},  {-384.0f, 120}, {-384.0f, 120},
};

constexpr MoteLayout kFanDLayout[kFanDCount] = {
    {-310.0f, 90},
    {-190.0f, 100},
    {70.0f, 50},
    {30.0f, 30},
    {300.0f, 40},
    {180.0f, 60},
    {-150.0f, 30},
    {-50.0f, 60},
    {-250.0f, 100},
    {260.0f, 120},
    {40.0f, 120},
    {0.0f, 120},
};

// The ten letters' offsets from the centre line (@ghidraAddress 0x2ff000). The binary copies this
// block into a guarded one-shot at 0x3dc670 before the letter loop reads it.
constexpr S_VECTOR2 kLetterOffsets[kLetterCount] = {
    {-203.0f, -10.0f},
    {-160.0f, -10.0f},
    {-119.0f, -10.0f},
    {-77.0f, -10.0f},
    {-14.0f, -10.0f},
    {30.0f, -10.0f},
    {77.0f, -10.0f},
    {124.0f, -10.0f},
    {168.0f, -10.0f},
    {198.0f, -10.0f},
};

// @ghidraAddress 0x2ff070
constexpr float kFanAScaleXPairs[][3 * 2] = {
    {0.0f, 0.0f, 166.66667f, -1.05f, 1000.0f, -1.4f},
    {0.0f, 0.0f, 166.66667f, 1.75f, 1000.0f, 3.15f},
};

// @ghidraAddress 0x2ff0a0
constexpr float kFanAScaleYPairs[][3 * 2] = {
    {0.0f, 0.0f, 166.66667f, -1.05f, 1000.0f, -0.931f},
    {0.0f, 0.0f, 166.66667f, 1.75f, 1000.0f, 2.1f},
};

// @ghidraAddress 0x2ff0d0
constexpr float kFanAAlphaPairs[][2 * 2] = {
    {0.0f, 1.0f, 1000.0f, 0.0f},
    {0.0f, 1.0f, 1000.0f, 0.0f},
};

// @ghidraAddress 0x2ff0f0
constexpr float kFanARotationPairs[][2 * 2] = {
    {0.0f, 0.0f, 1000.0f, 0.7853982f},
    {0.0f, 0.0f, 1000.0f, 0.7853982f},
};

// @ghidraAddress 0x2ff110
constexpr float kFanAOffsetXPairs[][2 * 2] = {
    {0.0f, 0.0f, 1000.0f, -70.0f},
    {0.0f, 0.0f, 1000.0f, 30.0f},
};

// @ghidraAddress 0x2ff130
constexpr float kFanAOffsetYPairs[][2 * 2] = {
    {0.0f, 0.0f, 1000.0f, -60.0f},
    {0.0f, 0.0f, 1000.0f, -40.0f},
};

// @ghidraAddress 0x2ff150
constexpr float kFanBScaleXPairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
};

// @ghidraAddress 0x2ff228
constexpr float kFanBScaleYPairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
};

// @ghidraAddress 0x2ff300
constexpr float kFanBAlphaPairs[][3 * 2] = {
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 1000.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 1000.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 1.0f, 483.33334f, 0.0f, 1000.0f, 0.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 916.6667f, 0.0f},
    {400.0f, 1.0f, 566.6667f, 0.0f, 1000.0f, 0.0f},
    {233.33333f, 0.0f, 250.0f, 1.0f, 750.0f, 0.0f},
};

// @ghidraAddress 0x2ff3d8
constexpr float kFanBOffsetYPairs[][3 * 2] = {
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {0.0f, 0.0f, 166.66667f, -20.0f, 666.6667f, -40.0f},
    {0.0f, 0.0f, 166.66667f, -20.0f, 666.6667f, -40.0f},
    {250.0f, 0.0f, 416.66666f, -30.0f, 916.6667f, -60.0f},
    {250.0f, 0.0f, 416.66666f, -30.0f, 916.6667f, -60.0f},
    {250.0f, 0.0f, 416.66666f, -30.0f, 916.6667f, -60.0f},
};

// @ghidraAddress 0x2ff4b0
constexpr float kFanCScaleXPairs[][3 * 2] = {
    {166.66667f, 0.0f, 833.3333f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {366.66666f, 0.0f, 533.3333f, 0.3f, 1033.3334f, 0.4f},
    {366.66666f, 0.0f, 533.3333f, 0.3f, 1033.3334f, 0.4f},
    {283.33334f, 0.0f, 450.0f, 0.3f, 950.0f, 0.4f},
    {283.33334f, 0.0f, 450.0f, 0.3f, 950.0f, 0.4f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

// @ghidraAddress 0x2ff6a8
constexpr float kFanCScaleYPairs[][3 * 2] = {
    {166.66667f, 0.0f, 833.3333f, 0.5f, 833.3333f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 833.3333f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {366.66666f, 0.0f, 533.3333f, 0.3f, 1033.3334f, 0.4f},
    {366.66666f, 0.0f, 533.3333f, 0.3f, 1033.3334f, 0.4f},
    {283.33334f, 0.0f, 450.0f, 0.3f, 950.0f, 0.4f},
    {283.33334f, 0.0f, 450.0f, 0.3f, 950.0f, 0.4f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

// @ghidraAddress 0x2ff8a0
constexpr float kFanCAlphaPairs[][3 * 2] = {
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {316.66666f, 1.0f, 483.33334f, 0.0f, 483.33334f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {316.66666f, 1.0f, 650.0f, 0.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 1.0f, 483.33334f, 0.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 1.0f, 483.33334f, 0.0f, 483.33334f, 0.0f},
    {516.6667f, 0.0f, 533.3333f, 1.0f, 1033.3334f, 0.0f},
    {516.6667f, 1.0f, 683.3333f, 0.0f, 683.3333f, 0.0f},
    {433.33334f, 0.0f, 450.0f, 1.0f, 950.0f, 0.0f},
    {433.33334f, 1.0f, 600.0f, 0.0f, 600.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 1.0f, 650.0f, 0.0f, 650.0f, 0.0f},
    {233.33333f, 1.0f, 400.0f, 0.0f, 400.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {316.66666f, 1.0f, 566.6667f, 0.0f, 566.6667f, 0.0f},
};

// @ghidraAddress 0x2ffa98
constexpr float kFanCOffsetYPairs[][3 * 2] = {
    {166.66667f, 0.0f, 333.33334f, -7.5f, 833.3333f, -30.0f},
    {166.66667f, 0.0f, 333.33334f, -7.5f, 833.3333f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {166.66667f, 0.0f, 333.33334f, -25.0f, 833.3333f, -40.0f},
    {166.66667f, 0.0f, 333.33334f, -25.0f, 833.3333f, -40.0f},
    {0.0f, 0.0f, 166.66667f, -20.0f, 666.6667f, -40.0f},
    {0.0f, 0.0f, 166.66667f, -20.0f, 666.6667f, -40.0f},
    {0.0f, 0.0f, 166.66667f, 0.0f, 666.6667f, -20.0f},
    {0.0f, 0.0f, 166.66667f, 0.0f, 666.6667f, -20.0f},
    {366.66666f, 0.0f, 533.3333f, -30.0f, 1033.3334f, -60.0f},
    {366.66666f, 0.0f, 533.3333f, -30.0f, 1033.3334f, -60.0f},
    {283.33334f, 0.0f, 450.0f, -30.0f, 950.0f, -60.0f},
    {283.33334f, 0.0f, 450.0f, -30.0f, 950.0f, -60.0f},
    {333.33334f, 0.0f, 500.0f, -30.0f, 1000.0f, -60.0f},
    {333.33334f, 0.0f, 500.0f, -30.0f, 1000.0f, -60.0f},
    {83.333336f, 0.0f, 250.0f, 0.0f, 750.0f, -20.0f},
    {166.66667f, 0.0f, 333.33334f, -50.0f, 833.3333f, -80.0f},
    {166.66667f, 0.0f, 333.33334f, -50.0f, 833.3333f, -80.0f},
};

// @ghidraAddress 0x2ffc90
constexpr float kFanDScaleXPairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

// @ghidraAddress 0x2ffdb0
constexpr float kFanDScaleYPairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1000.0f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

// @ghidraAddress 0x2ffed0
constexpr float kFanDAlphaPairs[][3 * 2] = {
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 916.6667f, 0.0f},
    {233.33333f, 0.0f, 250.0f, 1.0f, 750.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
};

// @ghidraAddress 0x2ffff0
constexpr float kFanDOffsetYPairs[][3 * 2] = {
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 500.0f, -7.5f, 1000.0f, -30.0f},
    {166.66667f, 0.0f, 333.33334f, -7.5f, 833.3333f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {333.33334f, 0.0f, 1000.0f, -30.0f, 1000.0f, -30.0f},
    {166.66667f, 0.0f, 333.33334f, -25.0f, 833.3333f, -50.0f},
    {0.0f, 0.0f, 166.66667f, -50.0f, 666.6667f, -70.0f},
    {0.0f, 0.0f, 166.66667f, -50.0f, 666.6667f, -70.0f},
    {333.33334f, 0.0f, 500.0f, -30.0f, 1000.0f, -60.0f},
    {250.0f, 0.0f, 416.66666f, -30.0f, 916.6667f, -60.0f},
    {83.333336f, 0.0f, 250.0f, -30.0f, 750.0f, -50.0f},
    {166.66667f, 0.0f, 333.33334f, -50.0f, 833.3333f, -80.0f},
};

// @ghidraAddress 0x300110
constexpr float kFlareBackScaleXPairs[] = {0.0f, 5.0f, 133.33333f, 5.0f, 1250.0f, 0.0f};

// @ghidraAddress 0x300128
constexpr float kFlareBackScaleYPairs[] = {0.0f, 0.0f, 133.33333f, 3.0f, 1250.0f, 7.0f};

// @ghidraAddress 0x300140
constexpr float kFlareFrontAlphaPairs[] = {500.0f, 1.0f, 1250.0f, 0.0f};

// @ghidraAddress 0x300150
constexpr float kFlareFrontScaleXPairs[] = {
    0.0f,
    15.0f,
    133.33333f,
    15.0f,
    500.0f,
    15.0f,
    1250.0f,
    12.0f,
};

// @ghidraAddress 0x300170
constexpr float kFlareFrontScaleYPairs[] = {
    0.0f,
    0.0f,
    133.33333f,
    3.0f,
    500.0f,
    3.0f,
    1250.0f,
    0.0f,
};

// @ghidraAddress 0x300190
constexpr float kLetterScalePairs[][4 * 2] = {
    {450.0f, 0.0f, 616.6667f, 1.1f, 700.0f, 1.0f, 783.3333f, 1.05f},
    {400.0f, 0.0f, 566.6667f, 1.1f, 650.0f, 1.0f, 733.3333f, 1.05f},
    {350.0f, 0.0f, 516.6667f, 1.1f, 600.0f, 1.0f, 683.3333f, 1.05f},
    {300.0f, 0.0f, 466.66666f, 1.1f, 550.0f, 1.0f, 633.3333f, 1.05f},
    {250.0f, 0.0f, 416.66666f, 1.1f, 500.0f, 1.0f, 583.3333f, 1.05f},
    {250.0f, 0.0f, 416.66666f, 1.1f, 500.0f, 1.0f, 583.3333f, 1.05f},
    {300.0f, 0.0f, 466.66666f, 1.1f, 550.0f, 1.0f, 633.3333f, 1.05f},
    {350.0f, 0.0f, 516.6667f, 1.1f, 600.0f, 1.0f, 683.3333f, 1.05f},
    {400.0f, 0.0f, 566.6667f, 1.1f, 650.0f, 1.0f, 733.3333f, 1.05f},
    {450.0f, 0.0f, 616.6667f, 1.1f, 700.0f, 1.0f, 783.3333f, 1.05f},
};

// @ghidraAddress 0x300460
constexpr float kLetterAlphaPairs[][4 * 2] = {
    {450.0f, 0.0f, 700.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {400.0f, 0.0f, 650.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {350.0f, 0.0f, 600.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {300.0f, 0.0f, 550.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {250.0f, 0.0f, 500.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {250.0f, 0.0f, 500.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {300.0f, 0.0f, 550.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {350.0f, 0.0f, 600.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {400.0f, 0.0f, 650.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {450.0f, 0.0f, 700.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
};

// @ghidraAddress 0x3005a0
constexpr float kBannerScaleXPairs[] = {0.0f, 0.0f, 166.66667f, 1.5f, 250.0f, 1.0f, 500.0f, 5.0f};

// @ghidraAddress 0x3005c0
constexpr float kBannerScaleYPairs[] = {0.0f, 0.0f, 166.66667f, 1.5f, 250.0f, 1.0f, 500.0f, 1.5f};

// @ghidraAddress 0x3005e0
constexpr float kBannerAlphaPairs[] = {250.0f, 1.0f, 500.0f, 0.0f};

// The truncation the binary applies before handing a curve value to CreateSprite.
inline unsigned int ScaleToAlpha(float flValue) {
    return static_cast<unsigned int>(static_cast<int>(flValue * kAlphaScale));
}

// Each mote fan's row sits a fixed inset above the near lane's bottom, shifted by the field's
// centre split.
inline float MoteRowY(int nRowInset) {
    return static_cast<float>((g_nPlayfieldNearRowBottom - nRowInset) - g_nPlayfieldCentreSplit);
}

} // namespace

/** @ghidraAddress 0x9b3a8 */
void FullComboColetteLayer::Update(float flDelta) {
    m_aSpriteCounts[0] = 0;
    m_aSpriteCounts[1] = 0;
    m_aSpriteCounts[2] = 0;

    // With nothing playing the layer clears the instancers outright and leaves. Neither the Classic
    // nor the Limelight layer has this early out.
    if (!IsAnyEffectActive()) {
        for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
            m_apSprites[nSlot]->SetSpriteCount(0);
        }
        return;
    }

    if (static_cast<double>(flDelta) > kFrameCountThreshold) {
        ++g_nColetteFullComboFrameCount;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        EffectRecord &effect = m_aEffects[nSide];
        if (!effect.m_bActive) {
            continue;
        }

        effect.m_flTimer += flDelta;
        const float flClock = effect.m_flTimer;
        if (flClock > kEffectDuration) {
            // The record retires here but still draws in full on the frame that retires it.
            effect.m_bActive = false;
        }

        // Announce the full combo once, inside a half-second window. The rival's side stays silent
        // in the single-player modes. Like the Limelight layer, this one does not first check
        // whether a voice is already playing.
        if (!effect.m_bVoiceFired && flClock > kVoiceCueClockMin && flClock < kVoiceCueClockMax) {
            effect.m_bVoiceFired = true;
            const int nRivalSide = (pGameSystem->GetPlayColor() == 0) ? 1 : 0;
            const bool bSilent =
                nSide == nRivalSide && (pGameSystem->GetGameType() | kSinglePlayerGameTypeMask) ==
                                           kSinglePlayerGameTypeMask;
            if (!bSilent) {
                AudioManager *pAudio = AudioManager.sharedManager;
                [pAudio releaseVoice];
                SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kFullComboVoiceId);
            }
        }

        const int nPlayColor = pGameSystem->GetPlayColor();

        // Each lane row sits on the near lane's slope, scaled by the sheet's half inset. The binary
        // re-reads the game system on every iteration of this two-element loop.
        const float aRowSlope[kSideCount] = {g_flPlayfieldNearLaneSlope,
                                             g_flPlayfieldNearLaneSlopeNeg};
        float aRowBaseY[kSideCount] = {};
        for (int nRow = 0; nRow < kSideCount; ++nRow) {
            aRowBaseY[nRow] = aRowSlope[nRow] * GameSystem::GetGameSystem()->GetSheetInsetHalfY();
        }
        const int nGameType = GameSystem::GetGameSystem()->GetGameType();

        const bool bOwnSide = nPlayColor == nSide;
        const float flRowBaseY = aRowBaseY[bOwnSide ? 1 : 0];

        // The first mote fan is the only one that carries its own horizontal offset and a
        // curve-driven rotation. On the rival's side the whole offset position is point-reflected
        // and the rotation takes an extra half turn, computed at double precision.
        for (int nMote = 0; nMote < kFanACount; ++nMote) {
            const float flScaleX =
                CalculateCurveInterpolation(kFanAScaleXPairs[nMote], kThreePointCurve, flClock);
            const float flScaleY =
                CalculateCurveInterpolation(kFanAScaleYPairs[nMote], kThreePointCurve, flClock);
            const float flAlpha =
                CalculateCurveInterpolation(kFanAAlphaPairs[nMote], kTwoPointCurve, flClock);
            float flRotation =
                CalculateCurveInterpolation(kFanARotationPairs[nMote], kTwoPointCurve, flClock);
            const float flOffsetX =
                CalculateCurveInterpolation(kFanAOffsetXPairs[nMote], kTwoPointCurve, flClock);
            const float flOffsetY =
                CalculateCurveInterpolation(kFanAOffsetYPairs[nMote], kTwoPointCurve, flClock);

            const float flBaseX = kFanALayout[nMote].flScreenX;
            const float flBaseY = MoteRowY(kFanALayout[nMote].nRowInset);
            S_VECTOR2 position{flBaseX + flOffsetX, flBaseY + flOffsetY};
            if (!bOwnSide) {
                flRotation =
                    static_cast<float>(static_cast<double>(flRotation) + kMirrorRotationExact);
                position = S_VECTOR2{-flBaseX - flOffsetX, -flBaseY - flOffsetY};
            }
            CreateSprite(kFanAKindBase[nSide] + nMote,
                         &position,
                         ScaleToAlpha(flAlpha),
                         flScaleX,
                         flScaleY,
                         flRotation);
        }

        // The remaining three fans share one shape: each mote rises along its own vertical offset
        // curve from a fixed screen position, and the rival's side is point-reflected and turned a
        // half turn.
        const auto EmitMoteFan = [&](const MoteLayout *pLayout,
                                     int nCount,
                                     int nKindBase,
                                     const float (*pScaleX)[kThreePointCurve * 2],
                                     const float (*pScaleY)[kThreePointCurve * 2],
                                     const float (*pAlpha)[kThreePointCurve * 2],
                                     const float (*pOffsetY)[kThreePointCurve * 2]) {
            for (int nMote = 0; nMote < nCount; ++nMote) {
                const float flScaleX =
                    CalculateCurveInterpolation(pScaleX[nMote], kThreePointCurve, flClock);
                const float flScaleY =
                    CalculateCurveInterpolation(pScaleY[nMote], kThreePointCurve, flClock);
                const float flAlpha =
                    CalculateCurveInterpolation(pAlpha[nMote], kThreePointCurve, flClock);
                const float flOffsetY =
                    CalculateCurveInterpolation(pOffsetY[nMote], kThreePointCurve, flClock);

                const float flBaseX = pLayout[nMote].flScreenX;
                const float flBaseY = MoteRowY(pLayout[nMote].nRowInset);
                const S_VECTOR2 position = bOwnSide ? S_VECTOR2{flBaseX, flBaseY + flOffsetY} :
                                                      S_VECTOR2{-flBaseX, -flBaseY - flOffsetY};
                const float flRotation = bOwnSide ? 0.0f : kMirrorRotation;
                CreateSprite(nKindBase + nMote,
                             &position,
                             ScaleToAlpha(flAlpha),
                             flScaleX,
                             flScaleY,
                             flRotation);
            }
        };

        EmitMoteFan(kFanBLayout,
                    kFanBCount,
                    kFanBKindBase[nSide],
                    kFanBScaleXPairs,
                    kFanBScaleYPairs,
                    kFanBAlphaPairs,
                    kFanBOffsetYPairs);

        // The third fan reuses the first fan's kind base rather than continuing from the second's.
        // The binary seeds that register once, before the first fan, and never refreshes it. The
        // descriptor table shows the intent was to continue: it holds runs of exactly 2, 9, 21, and
        // 12 identical entries at kinds 59, 61, 70, and 91, which tile perfectly only if this fan
        // starts at 70. It starts at 59. Faithful to the binary, not a reconstruction slip.
        EmitMoteFan(kFanCLayout,
                    kFanCCount,
                    kFanAKindBase[nSide],
                    kFanCScaleXPairs,
                    kFanCScaleYPairs,
                    kFanCAlphaPairs,
                    kFanCOffsetYPairs);

        // The fourth fan strobes: it draws for the first three frames of every six.
        if (g_nColetteFullComboFrameCount % kFanDStrobePeriod < kFanDStrobeOnFrames) {
            EmitMoteFan(kFanDLayout,
                        kFanDCount,
                        kFanDKindBase[nSide],
                        kFanDScaleXPairs,
                        kFanDScaleYPairs,
                        kFanDAlphaPairs,
                        kFanDOffsetYPairs);
        }

        // The centred flare pair. The back flare holds a fixed alpha and only animates its scale;
        // the front flare fades on its own curve.
        const float flFlareOffsetY = kFlareScreenY - m_flHeight;
        const float flFlareX = kFlareScreenX - m_flWidth;
        const float flFlareRotation = kSideRotation[bOwnSide ? 1 : 0];

        const float flBackScaleX =
            CalculateCurveInterpolation(kFlareBackScaleXPairs, kThreePointCurve, flClock);
        const float flBackScaleY =
            CalculateCurveInterpolation(kFlareBackScaleYPairs, kThreePointCurve, flClock);
        // Only the back flare mirrors its X. Both land on zero because the screen X equals the
        // layer's own width, so the difference never shows; the asymmetry is the binary's.
        S_VECTOR2 backPosition{bOwnSide ? flFlareX : -flFlareX,
                               flRowBaseY + (bOwnSide ? flFlareOffsetY : -flFlareOffsetY)};
        CreateSprite(kFlareBackKind[nSide],
                     &backPosition,
                     kFlareBackAlpha,
                     flBackScaleX,
                     flBackScaleY,
                     flFlareRotation);

        const float flFrontAlpha =
            CalculateCurveInterpolation(kFlareFrontAlphaPairs, kTwoPointCurve, flClock);
        const float flFrontScaleX =
            CalculateCurveInterpolation(kFlareFrontScaleXPairs, kFourPointCurve, flClock);
        const float flFrontScaleY =
            CalculateCurveInterpolation(kFlareFrontScaleYPairs, kFourPointCurve, flClock);
        S_VECTOR2 frontPosition{flFlareX,
                                flRowBaseY + (bOwnSide ? flFlareOffsetY : -flFlareOffsetY)};
        CreateSprite(kFlareFrontKind[nSide],
                     &frontPosition,
                     ScaleToAlpha(flFrontAlpha),
                     flFrontScaleX,
                     flFrontScaleY,
                     flFlareRotation);

        // The letters and the banner hang off a centre line that spans both near lane rows, inset
        // from each and shifted by the field's centre split, and they run half a second behind the
        // mote fans. They mirror only in the versus game type.
        const S_VECTOR2 aCentreBase[kSideCount] = {
            {0.0f,
             static_cast<float>((g_nPlayfieldNearRowTop + kLetterRowInset) -
                                g_nPlayfieldCentreSplit)},
            {0.0f,
             static_cast<float>((g_nPlayfieldNearRowBottom - kLetterRowInset) -
                                g_nPlayfieldCentreSplit)},
        };
        const float flLetterClock = flClock + kLetterClockBias;
        const bool bLetterMirrored = nGameType == kVersusGameType && !bOwnSide;
        const float flLetterRotation = bLetterMirrored ? kMirrorRotation : 0.0f;
        const S_VECTOR2 centreBase = aCentreBase[bOwnSide ? 1 : 0];

        // The FULLCOMBO! letters. The binary counts its loop from -10 up to 0 and adds 11, so the
        // kinds run 1 through 10 rather than 0 through 9.
        for (int nLetter = 0; nLetter < kLetterCount; ++nLetter) {
            const float flScale = CalculateCurveInterpolation(
                kLetterScalePairs[nLetter], kFourPointCurve, flLetterClock);
            const float flAlpha = CalculateCurveInterpolation(
                kLetterAlphaPairs[nLetter], kFourPointCurve, flLetterClock);
            S_VECTOR2 position = centreBase;
            S_VECTOR2 offset = kLetterOffsets[nLetter];
            if (bLetterMirrored) {
                SubtractVector2(&position, &offset);
            } else {
                AddVector2(&position, &offset);
            }
            CreateSprite((nLetter - kLetterCount) + kLetterKindBias,
                         &position,
                         ScaleToAlpha(flAlpha),
                         flScale,
                         flScale,
                         flLetterRotation);
        }

        // The banner behind them, combined with a zero offset the binary still runs through the
        // vector helpers.
        const float flBannerScaleX =
            CalculateCurveInterpolation(kBannerScaleXPairs, kFourPointCurve, flLetterClock);
        const float flBannerScaleY =
            CalculateCurveInterpolation(kBannerScaleYPairs, kFourPointCurve, flLetterClock);
        const float flBannerAlpha =
            CalculateCurveInterpolation(kBannerAlphaPairs, kTwoPointCurve, flLetterClock);
        S_VECTOR2 bannerPosition = centreBase;
        S_VECTOR2 bannerOffset{};
        if (bLetterMirrored) {
            SubtractVector2(&bannerPosition, &bannerOffset);
        } else {
            AddVector2(&bannerPosition, &bannerOffset);
        }
        CreateSprite(kBannerKind,
                     &bannerPosition,
                     ScaleToAlpha(flBannerAlpha),
                     flBannerScaleX,
                     flBannerScaleY,
                     flLetterRotation);
    }

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot]->SetSpriteCount(m_aSpriteCounts[nSlot]);
    }
}
