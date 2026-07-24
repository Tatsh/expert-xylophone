#include "bg_layer.h"

#include <cassert>

#import "neEngineBridge.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide background layer, created lazily by GetBackgroundLayer.
static BgLayer *g_pBackgroundLayer = nullptr; // @ghidraAddress 0x3de808

namespace {

// The background texture-name table (@ghidraAddress 0x3ce830). It is indexed by the background id
// for the main texture and by a theme-family slot (kClearEffect*Index) for the clear-effect
// overlay. Entries 28 and 29 are the same name in the binary.
constexpr const char *kBackgroundTextureNames[] = {
    "00_texture/gm_bg_classic_default",    // 0
    "00_texture/gm_bg_classic_bronze",     // 1
    "00_texture/gm_bg_classic_silver",     // 2
    "00_texture/gm_bg_classic_gold",       // 3
    "00_texture/gm_bg_classic_platinum",   // 4
    "00_texture/gm_bg_classic_black",      // 5
    "00_texture/gm_bg_limelight_default",  // 6
    "00_texture/gm_bg_limelight_yellow",   // 7
    "00_texture/gm_bg_limelight_blue",     // 8
    "00_texture/gm_bg_limelight_red",      // 9
    "00_texture/gm_bg_limelight_black",    // 10
    "00_texture/gm_bg_limelight_purple",   // 11
    "00_texture/gm_bg_limelight_copious1", // 12
    "00_texture/gm_bg_colette_allseasons", // 13
    "00_texture/gm_bg_colette_winter",     // 14
    "00_texture/gm_bg_colette_spring",     // 15
    "00_texture/gm_bg_colette_summer",     // 16
    "00_texture/gm_bg_colette_autumn",     // 17
    "00_texture/gm_bg_colette_green",      // 18
    "00_texture/gm_bg_colette_yellow",     // 19
    "00_texture/gm_bg_colette_blue",       // 20
    "00_texture/gm_bg_colette_red",        // 21
    "00_texture/gm_bg_colette_tentei",     // 22
    "00_texture/gm_bg_colette_spade",      // 23
    "00_texture/gm_bg_colette_heart",      // 24
    "00_texture/gm_bg_colette_club",       // 25
    "00_texture/gm_bg_colette_dia",        // 26
    "00_texture/gm_bg_colette_joker",      // 27
    "00_texture/gm_bg_clear_eff",          // 28
    "00_texture/gm_bg_clear_eff",          // 29
    "00_texture/gm_bg_limelight_copious2", // 30
    "00_texture/gm_bg_clear_eff_colette",  // 31
};

// The clear-effect overlay slots in the texture-name table, one per theme family.
constexpr int kClearEffectClassicIndex = 28;
constexpr int kClearEffectLimelightIndex = 29;
constexpr int kClearEffectCopiousIndex = 30;
constexpr int kClearEffectColetteIndex = 31;

// The background-id boundaries between the theme families.
constexpr int kLastClassicBackgroundId = 5;
constexpr int kLastLimelightBackgroundId = 11;
constexpr int kCopiousBackgroundId = 12;

// The per-axis pixel inset applied when sizing a batch: the background image trims a one-pixel
// border on every edge (two pixels per axis); the clear-effect overlay uses the whole image.
constexpr int kBackgroundInset = 2;
constexpr int kClearEffectInset = 0;

// The two theme modes that composite a clear-effect overlay over the background.
constexpr int kThemeClearEffectA = 1;
constexpr int kThemeClearEffectB = 2;

// The font variant whose assets are authored at half size and so drawn doubled.
constexpr unsigned char kDoubleScaleFontVariant = 0;

// Packed sprite colours (byte order red, green, blue, alpha): the root container's opaque black, and
// the white the background batches start at with zero alpha, which the fade fills in each frame.
constexpr unsigned int kOpaqueBlack = 0xff000000;
constexpr unsigned int kWhiteRgb = 0x00ffffff;

// The bit position of the alpha byte within a packed colour, and the 8-bit alpha scale the fade and
// brightness are multiplied by (@ghidraAddress 0x2eed00).
constexpr unsigned int kAlphaShift = 24;
constexpr float kAlphaScale = 255.0f;

// Chooses the clear-effect overlay texture name for a background id: the slot for its theme family.
const char *SelectClearEffectName(int nBackgroundId) {
    if (nBackgroundId <= kLastClassicBackgroundId) {
        return kBackgroundTextureNames[kClearEffectClassicIndex];
    }
    if (nBackgroundId <= kLastLimelightBackgroundId) {
        return kBackgroundTextureNames[kClearEffectLimelightIndex];
    }
    if (nBackgroundId == kCopiousBackgroundId) {
        return kBackgroundTextureNames[kClearEffectCopiousIndex];
    }
    return kBackgroundTextureNames[kClearEffectColetteIndex];
}

// Sizes a full-screen background sprite (index 0) from its bound texture: a quad centred vertically
// on the play-field's full-height layout Y, whose pixel size is the used-image region (inset by
// nInsetPixels per axis) divided by the texture's content scale and doubled on the primary screen
// variant, with UVs mapping that used region within the power-of-two allocation.
void ConfigureBackgroundSprite(ne::C_SPRITE_INSTANCING *pBatch,
                               ne::C_TEXTURE *pTexture,
                               int nInsetPixels,
                               bool bDoubleScale) {
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth() - nInsetPixels);
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight() - nInsetPixels);
    const float flScale = pTexture->GetScale();
    float flWidth = flImageWidth / flScale;
    float flHeight = flImageHeight / flScale;
    if (bDoubleScale) {
        flWidth += flWidth;
        flHeight += flHeight;
    }
    const float flCentreY = static_cast<float>(g_nPlayfieldFullHeightY / 2);
    pBatch->SetSpritePosition(0, S_VECTOR2{0.0f, flCentreY});
    pBatch->SetSpriteAnchor(0, S_VECTOR2{flWidth * 0.5f, flHeight * 0.5f});
    pBatch->SetSpriteSize(0, S_VECTOR2{flWidth, flHeight});
    pBatch->SetSpriteUvOrigin(0, S_VECTOR2{0.0f, 0.0f});
    pBatch->SetSpriteUvSize(
        0,
        S_VECTOR2{flImageWidth / static_cast<float>(pTexture->GetAllocWidth() - nInsetPixels),
                  flImageHeight / static_cast<float>(pTexture->GetAllocHeight() - nInsetPixels)});
    pBatch->SetSpriteColor(0, kWhiteRgb);
}

} // namespace

/** @ghidraAddress 0x17278c */
ne::C_RENDER *BgLayer::GetBackgroundRenderObject() {
    if (!m_bBuilt) {
        InitializeBackgroundLayer();
    }
    // The binary asserts "m_RootSprite!=NULL" here before returning the root node.
    assert(m_pRootSprite != nullptr);
    return m_pRootSprite;
}

/** @ghidraAddress 0x17203c */
BgLayer *BgLayer::GetBackgroundLayer() {
    if (g_pBackgroundLayer == nullptr) {
        // Value-initialisation zeroes the layer; InitBase fills in the base fields and the factory
        // stamps the sprite capacity and the "no background selected" sentinel, matching the
        // binary's raw allocation plus explicit initialisation.
        BgLayer *pLayer = new BgLayer();
        pLayer->InitBase();
        pLayer->m_nSpriteCapacity = 1;
        pLayer->m_nBackgroundId = kNoBackground;
        g_pBackgroundLayer = pLayer;
    }
    return g_pBackgroundLayer;
}

/** @ghidraAddress 0x1720c4 */
void BgLayer::InitializeBackgroundLayer() {
    if (m_bBuilt) {
        return;
    }
    m_flBrightness = GameSystem::GetGameSystem()->GetBackgroundBrightness();

    // Load the background texture, and for the theme modes that use one the clear-effect overlay
    // texture, unless no background is selected.
    if (m_nBackgroundId != kNoBackground) {
        m_pBackgroundTexture =
            ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureNames[m_nBackgroundId]);
        if (GetThema() == kThemeClearEffectA || GetThema() == kThemeClearEffectB) {
            m_pClearEffectTexture =
                ne::C_TEXTURE::FindOrLoadCached(SelectClearEffectName(m_nBackgroundId));
        }
    }

    // Build the root container node once: a single degenerate (zero-size) opaque-black sprite whose
    // only role is to parent the background batches into the global scene tree.
    if (m_pRootSprite == nullptr) {
        m_pRootSprite = ne::CreateWorldSpriteBatch(1);
        m_pRootSprite->RegisterGlobal();
        m_pRootSprite->SetVisible(true);
        // The binary writes the root position twice; the first value is immediately overwritten by
        // (0, 0), which the degenerate container keeps.
        m_pRootSprite->SetSpritePosition(
            0, S_VECTOR2{0.0f, static_cast<float>(g_nPlayfieldFullHeightY / 2)});
        m_pRootSprite->SetSpritePosition(0, S_VECTOR2{0.0f, 0.0f});
        m_pRootSprite->SetSpriteAnchor(0, S_VECTOR2{0.0f, 0.0f});
        m_pRootSprite->SetSpriteSize(0, S_VECTOR2{0.0f, 0.0f});
        m_pRootSprite->SetSpriteUvOrigin(0, S_VECTOR2{0.0f, 0.0f});
        m_pRootSprite->SetSpriteUvSize(0, S_VECTOR2{0.0f, 0.0f});
        m_pRootSprite->SetSpriteColor(0, kOpaqueBlack);
        m_pRootSprite->SetSpriteCount(1);
    }

    // Build the background-image batch as a child of the root, then size its sprite from the bound
    // texture. SetRefCountedMember runs every time, so a deselected background releases its texture.
    if (m_pBackgroundBatch == nullptr) {
        m_pBackgroundBatch = ne::CreateWorldSpriteBatch(m_nSpriteCapacity);
        m_pRootSprite->AttachChild(m_pBackgroundBatch);
        m_pBackgroundBatch->SetVisible(true);
        m_pBackgroundBatch->SetSpriteCount(m_nSpriteCapacity);
    }
    m_pBackgroundBatch->SetRefCountedMember(m_pBackgroundTexture);
    if (ne::C_TEXTURE *pBound = m_pBackgroundBatch->GetBoundTexture()) {
        ConfigureBackgroundSprite(m_pBackgroundBatch,
                                  pBound,
                                  kBackgroundInset,
                                  GetFontVariant() == kDoubleScaleFontVariant);
    }

    // Build the clear-effect overlay batch as a child of the background batch, for the theme modes
    // that use one.
    if (GetThema() == kThemeClearEffectA || GetThema() == kThemeClearEffectB) {
        if (m_pClearEffectBatch == nullptr) {
            m_pClearEffectBatch = ne::CreateWorldSpriteBatch(m_nSpriteCapacity);
            m_pBackgroundBatch->AttachChild(m_pClearEffectBatch);
            m_pClearEffectBatch->SetVisible(true);
            m_pClearEffectBatch->SetSpriteCount(m_nSpriteCapacity);
        }
        m_pClearEffectBatch->SetRefCountedMember(m_pClearEffectTexture);
        if (ne::C_TEXTURE *pBound = m_pClearEffectBatch->GetBoundTexture()) {
            ConfigureBackgroundSprite(m_pClearEffectBatch,
                                      pBound,
                                      kClearEffectInset,
                                      GetFontVariant() == kDoubleScaleFontVariant);
        }
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x1727fc */
void BgLayer::StartBackgroundFadeIn(float flDuration) {
    RecentreBackgroundSprites();
    m_flFadeFrom = m_flFadeCurrent;
    m_flFadeTo = 1.0f;
    m_flFadeDuration = flDuration;
    m_flFadeElapsed = 0.0f;
    if (flDuration <= 0.0f) {
        m_flFadeCurrent = 1.0f;
        m_bColorDirty = true;
    }
}

/** @ghidraAddress 0x172914 */
void BgLayer::StartBackgroundFadeOut(float flDuration) {
    m_flFadeFrom = m_flFadeCurrent;
    m_flFadeTo = 0.0f;
    m_flFadeDuration = flDuration;
    m_flFadeElapsed = 0.0f;
    if (flDuration <= 0.0f) {
        m_flFadeCurrent = 0.0f;
        m_bColorDirty = true;
    }
}

/** @ghidraAddress 0x17293c */
void BgLayer::SetBackgroundBrightness(float flBrightness) {
    m_flBrightness = flBrightness;
    m_bColorDirty = true;
}

/** @ghidraAddress 0x17294c */
void BgLayer::ProcessBackgroundLayer(float flFrameDelta) {
    // Advance the main fade while it is running, clamping to its duration.
    if (m_flFadeElapsed < m_flFadeDuration) {
        float flElapsed = m_flFadeElapsed + flFrameDelta;
        if (flElapsed > m_flFadeDuration) {
            flElapsed = m_flFadeDuration;
        }
        m_flFadeElapsed = flElapsed;
        const float flProgress = (m_flFadeDuration == 0.0f) ? 1.0f : flElapsed / m_flFadeDuration;
        m_flFadeCurrent = m_flFadeFrom + flProgress * (m_flFadeTo - m_flFadeFrom);
        m_bColorDirty = true;
    }

    // Advance the free-running clock and, when the clear-effect fade is active, that fade too. With
    // no clear effect and nothing else dirtied, there is nothing to re-apply this frame.
    if (!m_bClearEffectActive) {
        m_flAnimTime += flFrameDelta;
        if (!m_bColorDirty) {
            return;
        }
    } else {
        m_flClearEffectElapsed += flFrameDelta;
        float flProgress = m_flClearEffectElapsed / m_flClearEffectDuration;
        if (flProgress > 1.0f) {
            flProgress = 1.0f;
        }
        m_flClearEffectCurrent = flProgress;
        m_bColorDirty = true;
        m_flAnimTime += flFrameDelta;
    }

    // Apply the faded, brightness-scaled alpha to the background batch (white RGB).
    const auto nBackgroundAlpha =
        static_cast<unsigned int>(m_flFadeCurrent * m_flBrightness * kAlphaScale);
    m_pBackgroundBatch->SetSpriteColor(0, (nBackgroundAlpha << kAlphaShift) | kWhiteRgb);

    GameSystem::GetGameSystem()->SetBackgroundFadeComplete(m_flFadeCurrent >= 1.0f);

    // Apply the clear-effect overlay's alpha for the theme modes that use it: transparent when the
    // fade is inactive, otherwise the faded, brightness-scaled alpha.
    if (GetThema() == kThemeClearEffectA || GetThema() == kThemeClearEffectB) {
        if (!m_bClearEffectActive) {
            m_pClearEffectBatch->SetSpriteColor(0, kWhiteRgb);
        } else {
            const auto nClearAlpha =
                static_cast<unsigned int>(m_flClearEffectCurrent * m_flBrightness * kAlphaScale);
            m_pClearEffectBatch->SetSpriteColor(0, (nClearAlpha << kAlphaShift) | kWhiteRgb);
        }
    }

    m_bColorDirty = false;
}

// The re-centre block inlined at the start of StartBackgroundFadeIn (0x1727fc), factored out here.
void BgLayer::RecentreBackgroundSprites() {
    const float flCentreY = static_cast<float>(g_nPlayfieldFullHeightY / 2);
    m_pRootSprite->SetSpritePosition(0, S_VECTOR2{0.0f, flCentreY});
    m_pBackgroundBatch->SetSpritePosition(0, S_VECTOR2{0.0f, flCentreY});
    // The clear-effect batch exists for any positive theme mode; re-centre it too when present.
    if (GetThema() > 0) {
        m_pClearEffectBatch->SetSpritePosition(0, S_VECTOR2{0.0f, flCentreY});
    }
}
