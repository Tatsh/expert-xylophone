#include "limelight_theme_layer.h"

#include "../Share/bg_layer.h"
#include "ScoreTracker.h"
#include "curve.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

// The process-wide Limelight-theme layer, created lazily by shared().
static LimelightThemeLayer *g_pLimelightThemeLayer = nullptr; // @ghidraAddress 0x3dd380

namespace {

// The full-combo atlases the layer loads (@ghidraAddress 0x3ceaa8, 0x3ceaf0, and 0x3ceb00).
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";
constexpr const char *kWinTextureName = "00_texture/gm_win";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x305404).
constexpr unsigned int kSlotCapacities[] = {1, 100, 100, 2};

// The per-slot texture-field selector (@ghidraAddress 0x305414): the index into the layer's three
// texture fields for each textured slot. Slot 0 binds no texture, so its entry is unused.
constexpr int kSlotTextureField[] = {-1, 0, 1, 2};

// The slot that receives additive blend mode, and that mode's identifier.
constexpr int kAdditiveBlendSlot = 3;
constexpr int kAdditiveBlendMode = 1;

// The layer's layout size the constructor seeds.
constexpr float kLayoutWidth = 384.0f;
constexpr float kLayoutHeight = 680.0f;

// The grade-display defaults the constructor seeds: single-side, and both grade values four.
constexpr int kDefaultSideCount = 1;
constexpr int kGradeValueDefault = 4;

// The grade reveal-channel value that holds the display fully shown.
constexpr float kGradeChannelFull = 1.0f;

// The reveal clock's off-screen start value (a -500 immediate in the initialiser).
constexpr float kGradeClockStart = -500.0f;

// The reveal-clock threshold: shorter for a two-side display, longer for single-side or one record.
constexpr float kGradeRevealDurationDual = 3000.0f;
constexpr float kGradeRevealDurationSingle = 5000.0f;

// The base grade sprite's slot and kind, its reveal alpha-fade curve ({time, value} pairs at
// @ghidraAddress 0x305424), and the byte alpha scale (@ghidraAddress 0x2eed00).
constexpr unsigned int kGradeBaseSlot = 0;
constexpr unsigned int kGradeBaseKind = 0;
constexpr float kGradeRevealCurve[] = {-500.0f, 0.0f, -333.33334f, 0.75f};
constexpr int kGradeRevealCurvePairs = 2;
constexpr float kAlphaByteScale = 255.0f;

// The minimum rank (of the B/A/AA/AAA/AAAP ladder) that draws the rank glyphs rather than the
// high-rank badge.
constexpr int kMinRankGlyphs = 2;

} // namespace

/** @ghidraAddress 0x120630 */
LimelightThemeLayer::LimelightThemeLayer() {
    // The base constructor and the zero-initialised members clear the textures, sprites, counts, and
    // flags; the constructor then applies the layout size and the non-zero grade-display defaults.
    m_flWidth = kLayoutWidth;
    m_flHeight = kLayoutHeight;
    m_nSideCount = kDefaultSideCount;
    for (int &nValue : m_aGradeValues) {
        nValue = kGradeValueDefault;
    }
}

/** @ghidraAddress 0x1206c8 */
LimelightThemeLayer *LimelightThemeLayer::shared() {
    if (g_pLimelightThemeLayer == nullptr) {
        // The binary allocates the raw 0x98-byte object and runs the constructor, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pLimelightThemeLayer = new LimelightThemeLayer();
    }
    return g_pLimelightThemeLayer;
}

/** @ghidraAddress 0x120718 */
void LimelightThemeLayer::InitFullComboLayerTextures() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);
    m_pWinTexture = ne::C_TEXTURE::FindOrLoadCached(kWinTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pPartsTexture, m_pEffectTexture, m_pWinTexture};

    // Build one sprite instancer per slot, attach it under the background render object, and make it
    // visible. The first slot binds no texture; the rest bind their mapped atlas. Seed each slot's
    // sprite count and flag additive blend on the last slot.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        if (nSlot != 0) {
            pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        }
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (nSlot == kAdditiveBlendSlot) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x120900 */
void LimelightThemeLayer::StartGradeAnimation(float flDuration) {
    // Animate from the channel's current value down to zero over the duration.
    m_gradeChannel.SetStart(m_gradeChannel.GetCurrent());
    m_gradeChannel.SetEnd(0.0f);
    m_gradeChannel.SetDuration(flDuration);
    m_gradeChannel.SetElapsed(0.0f);
    // A non-positive duration snaps straight to zero.
    if (flDuration <= 0.0f) {
        m_gradeChannel.SetCurrent(0.0f);
    }
}

/** @ghidraAddress 0x120a74 */
void LimelightThemeLayer::AdvanceGradeChannel(float flDeltaTime) {
    m_gradeChannel.Advance(flDeltaTime);
}

/** @ghidraAddress 0x120920 */
void LimelightThemeLayer::UpdateGradeDisplay(float flDeltaTime) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flCachedViewportWidth = pGameSystem->GetViewportWidth();
    m_flCachedViewportHeight = pGameSystem->GetViewportHeight();
    m_aSpriteCounts[0] = 0;
    m_aSpriteCounts[1] = 0;
    m_aSpriteCounts[2] = 0;
    m_aSpriteCounts[3] = 0;

    AdvanceGradeChannel(flDeltaTime);

    if (m_bGradeVisible) {
        // Run the reveal clock while the display is showing, and stop it once it passes the reveal
        // duration.
        if (m_bGradeClockActive) {
            m_flGradeRevealClock += flDeltaTime;
        }
        if (m_flGradeRevealClock >= m_flGradeRevealDuration) {
            m_bGradeClockActive = false;
        }
        // The base grade sprite fades in over the reveal, scaled by the reveal channel's value.
        const float flReveal = CalculateCurveInterpolation(
            kGradeRevealCurve, kGradeRevealCurvePairs, m_flGradeRevealClock);
        S_VECTOR2 basePos{0.0f, 0.0f};
        EmitGradeSpriteSlot(
            1.0f,
            1.0f,
            0.0f,
            kGradeBaseKind,
            &basePos,
            static_cast<unsigned int>(flReveal * m_gradeChannel.GetCurrent() * kAlphaByteScale));

        // Per side (the first only when single-side), draw the grade meter for a zero grade, then the
        // high-rank badge for a rank below AA or the rank glyphs otherwise.
        for (int nSide = 0; nSide < kSideCount; ++nSide) {
            // Side 0 is skipped only when the side count is zero.
            if (m_nSideCount == 0 && nSide == 0) {
                continue;
            }
            const int nGrade = m_aGradeValues[nSide];
            const int nRank =
                ScoreTracker::shared()->GetPlayRecordRank(static_cast<unsigned int>(nSide));
            if (nGrade == 0) {
                RenderGradeMeterSprite(static_cast<unsigned int>(nSide));
            }
            if (nRank < kMinRankGlyphs) {
                RenderGradeHighRankBadge(nSide);
            } else {
                RenderGradeRankGlyphs(nSide);
            }
        }
    }

    // Publish each slot's live count to its instancer.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot]->SetSpriteCount(m_aSpriteCounts[nSlot]);
    }
}

/** @ghidraAddress 0x1208c4 */
void LimelightThemeLayer::InitializeGradeValuesFromTracker() {
    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        m_aGradeValues[nSide] =
            ScoreTracker::shared()->GetPlayRecordField10(static_cast<unsigned int>(nSide));
    }
}

/** @ghidraAddress 0x120844 */
void LimelightThemeLayer::InitializeGradeDisplayState() {
    // Seed the reveal channel to hold a full value, park the clock off-screen, arm the display, and
    // fill the per-side grade values.
    m_gradeChannel.SetStart(kGradeChannelFull);
    m_gradeChannel.SetEnd(kGradeChannelFull);
    m_gradeChannel.SetDuration(0.0f);
    m_gradeChannel.SetElapsed(0.0f);
    m_gradeChannel.SetCurrent(kGradeChannelFull);
    m_flGradeRevealClock = kGradeClockStart;
    m_bGradeVisible = true;
    m_bGradeClockActive = true;
    m_bGradeArmed = true;
    InitializeGradeValuesFromTracker();

    // The reveal runs longer for a single-side display or when the second side has no records.
    m_flGradeRevealDuration = kGradeRevealDurationDual;
    if (m_nSideCount == 1 || m_aGradeValues[1] == 0) {
        m_flGradeRevealDuration = kGradeRevealDurationSingle;
    }
}
