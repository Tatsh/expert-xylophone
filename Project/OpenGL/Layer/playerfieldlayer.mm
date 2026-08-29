#include "playerfieldlayer.h"

#include "Share/bg_layer.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

static PlayerFieldLayer *g_pPlayerFieldLayer = nullptr; // @ghidraAddress 0x3df2f0

namespace {

// @ghidraAddress 0x3ceaa8
constexpr const char *kTextureName = "00_texture/gm_parts2";

// @ghidraAddress 0x30ff40
constexpr PlayerFieldLayer::ScoreDigitGlyph kScoreGlyphsPad[] = {
    {0.0f, 37.0f, 46.0f, 74.0f, 111}, {0.0f, 37.0f, 46.0f, 74.0f, 112},
    {0.0f, 37.0f, 46.0f, 74.0f, 113}, {0.0f, 37.0f, 46.0f, 74.0f, 114},
    {0.0f, 37.0f, 46.0f, 74.0f, 115}, {0.0f, 37.0f, 46.0f, 74.0f, 116},
    {0.0f, 37.0f, 46.0f, 74.0f, 117}, {0.0f, 37.0f, 46.0f, 74.0f, 118},
    {0.0f, 37.0f, 46.0f, 74.0f, 119}, {0.0f, 37.0f, 46.0f, 74.0f, 120},
    {0.0f, 37.0f, 46.0f, 74.0f, 121}, {0.0f, 37.0f, 46.0f, 74.0f, 122},
    {0.0f, 37.0f, 46.0f, 74.0f, 123}, {0.0f, 37.0f, 46.0f, 74.0f, 124},
    {0.0f, 37.0f, 46.0f, 74.0f, 125}, {0.0f, 37.0f, 46.0f, 74.0f, 126},
    {0.0f, 37.0f, 46.0f, 74.0f, 127}, {0.0f, 37.0f, 46.0f, 74.0f, 128},
    {0.0f, 37.0f, 46.0f, 74.0f, 129}, {0.0f, 37.0f, 46.0f, 74.0f, 130}};
// @ghidraAddress 0x3100d0
constexpr PlayerFieldLayer::ScoreDigitGlyph kScoreGlyphsPhone[] = {
    {0.0f, 33.0f, 40.0f, 66.0f, 255}, {0.0f, 33.0f, 40.0f, 66.0f, 256},
    {0.0f, 33.0f, 40.0f, 66.0f, 257}, {0.0f, 33.0f, 40.0f, 66.0f, 258},
    {0.0f, 33.0f, 40.0f, 66.0f, 259}, {0.0f, 33.0f, 40.0f, 66.0f, 260},
    {0.0f, 33.0f, 40.0f, 66.0f, 261}, {0.0f, 33.0f, 40.0f, 66.0f, 262},
    {0.0f, 33.0f, 40.0f, 66.0f, 263}, {0.0f, 33.0f, 40.0f, 66.0f, 264},
    {0.0f, 33.0f, 40.0f, 66.0f, 265}, {0.0f, 33.0f, 40.0f, 66.0f, 266},
    {0.0f, 33.0f, 40.0f, 66.0f, 267}, {0.0f, 33.0f, 40.0f, 66.0f, 268},
    {0.0f, 33.0f, 40.0f, 66.0f, 269}, {0.0f, 33.0f, 40.0f, 66.0f, 270},
    {0.0f, 33.0f, 40.0f, 66.0f, 271}, {0.0f, 33.0f, 40.0f, 66.0f, 272},
    {0.0f, 33.0f, 40.0f, 66.0f, 273}, {0.0f, 33.0f, 40.0f, 66.0f, 274}};

// @ghidraAddress 0x30ff20
constexpr S_VECTOR2 kScoreBasePad[] = {{0.0f, -51.0f}, {0.0f, 51.0f}};
// @ghidraAddress 0x30ff30
constexpr S_VECTOR2 kScoreBasePhone[] = {{0.0f, -45.0f}, {0.0f, 45.0f}};

// A non-zero byte draws the string right-aligned and rotates each glyph a half-turn.
// @ghidraAddress 0x310260
constexpr unsigned char kScoreMirrorTable[] = {0, 0, 1, 0, 78, 50, 114, 98};

constexpr int kMaxScoreDigits = 6;
constexpr int kHighSideFontOffset = 10;
// @ghidraAddress 0x2fd000
constexpr float kTenthScale = 0.1f;
constexpr float kDigitSpacing = 2.0f;
// @ghidraAddress 0x2fe894
constexpr float kMirrorRotation = 3.1415927f;
// @ghidraAddress 0x2eed00
constexpr float kAlphaByteScale = 255.0f;

} // namespace

/** @ghidraAddress 0x18b7cc */
void PlayerFieldLayer::SetScoreDigitTarget(unsigned int uSide, int nValue, float flDuration) {
    ScoreDigitField &field = m_aScoreFields[uSide];
    field.nTarget = nValue;
    field.flFrom = field.flCurrent;
    field.flTo = static_cast<float>(nValue);
    field.flElapsed = 0.0f;
    field.flDuration = flDuration;
}

/** @ghidraAddress 0x18bd58 */
void ScoreDigitField::Advance(float flDeltaTime) {
    // Unlike the shared linear tween, this snaps the displayed value to the end once complete.
    if (flElapsed < flDuration) {
        float flNewElapsed = flElapsed + flDeltaTime;
        if (flNewElapsed >= flDuration) {
            flNewElapsed = flDuration;
        }
        flElapsed = flNewElapsed;
        flCurrent = flFrom + (flTo - flFrom) * flNewElapsed / flDuration;
    } else {
        flCurrent = flTo;
    }
}

/** @ghidraAddress 0x18b668 */
PlayerFieldLayer *PlayerFieldLayer::shared() {
    if (g_pPlayerFieldLayer == nullptr) {
        g_pPlayerFieldLayer = new PlayerFieldLayer();
    }
    return g_pPlayerFieldLayer;
}

/** @ghidraAddress 0x18b6fc */
void PlayerFieldLayer::CreateScoreNumberSpriteBatch() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    m_pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(m_nSpriteCount);

    m_bBuilt = true;
}

/** @ghidraAddress 0x18b784 */
void PlayerFieldLayer::StartScoreFadeIn(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(1.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(1.0f);
    }
}

/** @ghidraAddress 0x18b7ac */
void PlayerFieldLayer::StartScoreFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(0.0f);
    }
}

/** @ghidraAddress 0x18b7f4 */
void PlayerFieldLayer::SetScoreSideFlag(int nSide) {
    m_nScoreSideFlag = nSide;
}

/** @ghidraAddress 0x18b7fc */
void PlayerFieldLayer::SetScorePosition(float flValue, int nSide) {
    m_aScorePosition[nSide != 0 ? 1 : 0] = flValue;
}

/** @ghidraAddress 0x18b810 */
void PlayerFieldLayer::Update(float flDeltaTime) {
    m_nSpriteCount = 0;
    m_fadeChannel.Advance(flDeltaTime);

    const ScoreDigitGlyph *pGlyphs = IsPad() ? kScoreGlyphsPad : kScoreGlyphsPhone;
    const S_VECTOR2 *pBase = IsPad() ? kScoreBasePad : kScoreBasePhone;

    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) >> 1;

    for (int nSide = 0; nSide < PlayerFieldLayer::kSideCount; ++nSide) {
        int nSideId = GameSystem::GetGameSystem()->GetPlayColor();
        if (nSide != 1) {
            nSideId = nSideId == 0 ? 1 : 0;
        }
        const int nFontOffset = nSideId == 1 ? kHighSideFontOffset : 0;

        m_aScoreFields[nSide].Advance(flDeltaTime);
        int nValue = static_cast<int>(m_aScoreFields[nSide].flCurrent);
        int aDigits[kMaxScoreDigits];
        int nSignificant = 0;
        for (int i = 0; i < kMaxScoreDigits; ++i) {
            const int nDigit =
                nValue - static_cast<int>(static_cast<float>(nValue) * kTenthScale) * 10;
            aDigits[i] = nDigit;
            if (nDigit >= 1) {
                nSignificant = i + 1;
            }
            nValue = static_cast<int>(static_cast<float>(nValue) * kTenthScale);
        }
        const int nDrawCount = nSignificant != 0 ? nSignificant : 1;

        float flWidth = 0.0f;
        for (int i = 0; i < nDrawCount; ++i) {
            flWidth += pGlyphs[aDigits[i] + nFontOffset].flSizeW + kDigitSpacing;
        }

        const unsigned char nMirror =
            kScoreMirrorTable[nSide + static_cast<unsigned int>(m_nScoreSideFlag) * 2];
        S_VECTOR2 origin = pBase[nSide];
        origin.y += static_cast<float>(nHalfHeight);
        origin.x += nMirror != 0 ? flWidth * 0.5f : flWidth * -0.5f;
        const float flRotation = nMirror != 0 ? kMirrorRotation : 0.0f;

        const float flSidePos = m_aScorePosition[nSide];
        const int nAlpha =
            static_cast<int>(flSidePos * m_fadeChannel.GetCurrent() * kAlphaByteScale);
        for (int i = nDrawCount; i >= 1; --i) {
            const ScoreDigitGlyph &glyph = pGlyphs[aDigits[i - 1] + nFontOffset];
            EmitScoreDigitSprite(origin, nAlpha, glyph, flRotation, 1.0f);
            origin.x = nMirror != 0 ? origin.x - glyph.flSizeW - kDigitSpacing :
                                      origin.x + glyph.flSizeW + kDigitSpacing;
        }
    }

    m_pSprite->SetSpriteCount(m_nSpriteCount);
}

/** @ghidraAddress 0x18bc4c */
void PlayerFieldLayer::EmitScoreDigitSprite(const S_VECTOR2 &position,
                                            int nAlpha,
                                            const ScoreDigitGlyph &glyph,
                                            float flRotation,
                                            float flScale) {
    const SpriteUvEntry &uv = g_aSpriteUvTable[glyph.nUvIndex];
    const int nIndex = m_nSpriteCount;

    m_pSprite->SetSpritePositionXY(nIndex, position.x, position.y);
    m_pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{glyph.flAnchorX, glyph.flAnchorY});
    m_pSprite->SetSpriteSize(nIndex, S_VECTOR2{glyph.flSizeW, glyph.flSizeH});
    m_pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprite->SetSpriteRotation(nIndex, flRotation);
    m_pSprite->SetSpriteScale(nIndex, flScale, flScale);
    m_pSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, static_cast<unsigned int>(nAlpha));
    ++m_nSpriteCount;
}
