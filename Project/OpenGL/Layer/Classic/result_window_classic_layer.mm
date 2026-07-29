#include "result_window_classic_layer.h"

#include <cassert>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "MusicData.h"
#import "RBViewController.h"
#include "ScoreTracker.h"
#import "TwitterImageCreater.h"
#include "classic_parts_data_table.h"
#import "deviceenvironment.h"
#include "engineruntime.h"
#include "fade_overlay_layer.h"
#include "float_tween.h"
#import "gamesystem.h"
#include "leveltables.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "polygon2d_trail.h"
#import "s_vector2.h"
#include "soundeffectmanager.h"
#include "touch_point.h"
#include "touchmanager.h"
#include "vectormath.h"

// The process-wide Classic result-window layer, created lazily by shared().
static ResultWindowClassicLayer *g_pClassicResultLayer = nullptr; // @ghidraAddress 0x3dd2f8

// The gesture hold-release timeout, in milliseconds (@ghidraAddress 0x302d5c), and the themed voice
// the release cue plays.
static constexpr float kGestureHoldTimeout = 3300.0f;
static constexpr int kGestureReleaseVoiceId = 7;

// The Classic pad parts table (declared in classic_parts_data_table.h): zero-initialised here to
// match the binary's __common segment, filled at runtime.
PartsDataRecord g_aClassicPartsPad[kClassicPartsRecordBound] = {}; // @ghidraAddress 0x3d6650

// The Classic pad parts anchor table (declared in classic_parts_data_table.h): zero-initialised
// here to match the binary's __common segment, filled at runtime.
S_VECTOR2 g_aClassicPartsAnchorPad[kClassicPartsAnchorRecordCount] = {}; // @ghidraAddress 0x3d7cd0

// The Classic colour-marker rectangles and their origin (declared in classic_parts_data_table.h):
// zero-initialised here to match the binary's __common segment, filled at runtime.
PhoneLayoutRect g_aClassicColorMarkerRects[kClassicColorMarkerRectCount] =
    {};                                    // @ghidraAddress 0x3dd080
S_VECTOR2 g_ClassicColorMarkerOrigin = {}; // @ghidraAddress 0x3dd2f0

// The Classic phone-layout position tables (declared in classic_parts_data_table.h):
// zero-initialised here to match the binary's __common segment, filled at runtime.
PhoneAnchorRecord g_aClassicPositionPhoneLandscape[kClassicPositionRecordCount] =
    {}; // @ghidraAddress 0x3d84c0
PhoneAnchorRecord g_aClassicPositionPhonePortrait[kClassicPositionRecordCount] =
    {}; // @ghidraAddress 0x3d80e8

// The Classic phone-layout separator tables (declared in classic_parts_data_table.h):
// zero-initialised here to match the binary's __common segment, filled at runtime.
PhoneLayoutRecord g_aClassicSeparatorPhonePortrait[kClassicSeparatorRecordCount] =
    {}; // @ghidraAddress 0x3d88a0
PhoneLayoutRecord g_aClassicSeparatorPhoneLandscape[kClassicSeparatorRecordCount] =
    {}; // @ghidraAddress 0x3d8c40

// The Classic phone-layout position-by-state tables. Their record count is not bounds-checked by
// the accessor; it is inferred as four from the gaps between the runtime-filled symbols
// (0x3d8fd8, 0x3d9030, 0x3d9080, each 0x50 = four 0x14-byte records apart).
constexpr int kClassicPositionByStateRecordCount = 4;
PhoneLayoutRecord g_aClassicPositionPhoneState[kClassicPositionByStateRecordCount] =
    {}; // @ghidraAddress 0x3d8fd8
PhoneLayoutRecord g_aClassicPositionPhoneStateLandscape[kClassicPositionByStateRecordCount] =
    {}; // @ghidraAddress 0x3d9080
PhoneLayoutRecord g_aClassicPositionPhoneStatePortrait[kClassicPositionByStateRecordCount] =
    {}; // @ghidraAddress 0x3d9030

// The single Classic phone-layout centre-position records (declared in classic_parts_data_table.h):
// zero-initialised here to match the binary's __common segment, filled at runtime.
PhoneLayoutRect g_ClassicCenterPositionPhoneState = {};     // @ghidraAddress 0x3d90d0
PhoneLayoutRect g_ClassicCenterPositionPhonePortrait = {};  // @ghidraAddress 0x3d90e0
PhoneLayoutRect g_ClassicCenterPositionPhoneLandscape = {}; // @ghidraAddress 0x3d90f0

// The fixed landscape offset the customize phone-overlay adds to its base position (zero-initialised
// in the binary's __common segment, filled at runtime).
static S_VECTOR2 g_classicCustomizeOverlayLandscapeOffset = {}; // @ghidraAddress 0x3d8058

// The fixed landscape offsets the customize nameplate-overlay adds to its base position for its name
// glyph, level glyph, and backing group (zero-initialised in __common, filled at runtime).
static S_VECTOR2 g_classicNameplateNameOffset = {};    // @ghidraAddress 0x3d8068
static S_VECTOR2 g_classicNameplateLevelOffset = {};   // @ghidraAddress 0x3d8070
static S_VECTOR2 g_classicNameplateBackingOffset = {}; // @ghidraAddress 0x3d8060

// The Classic phone parts table (@ghidraAddress 0x303580): static read-only sprite descriptors, one
// per result-window part, giving each part's placement offset, size, and UV-palette index.
const PartsDataRecord g_aClassicPartsPhone[kClassicPhonePartsRecordCount] = {
    {1, 0.0f, 0.0f, 1024.0f, 1024.0f, 0}, {1, 0.0f, 0.0f, 57.0f, 20.0f, 1},
    {1, 0.0f, 0.0f, 9.0f, 9.0f, 2},       {1, 0.0f, 0.0f, 1.0f, 9.0f, 3},
    {1, 0.0f, 0.0f, 9.0f, 1.0f, 4},       {1, 0.0f, 0.0f, 1.0f, 1.0f, 5},
    {1, 0.0f, 0.0f, 9.0f, 9.0f, 6},       {1, 0.0f, 0.0f, 1.0f, 9.0f, 7},
    {1, 0.0f, 0.0f, 9.0f, 1.0f, 8},       {1, 0.0f, 0.0f, 1.0f, 1.0f, 9},
    {1, 0.0f, 0.0f, 15.0f, 17.0f, 10},    {1, 0.0f, 0.0f, 1.0f, 17.0f, 11},
    {1, 0.0f, 0.0f, 1.0f, 1.0f, 12},      {1, 0.0f, 0.0f, 1.0f, 1.0f, 13},
    {1, 0.0f, 0.0f, 48.0f, 8.0f, 14},     {1, 0.0f, 0.0f, 30.0f, 8.0f, 15},
    {1, 0.0f, 0.0f, 26.0f, 8.0f, 16},     {1, 0.0f, 0.0f, 164.0f, 8.0f, 17},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 18},      {1, 0.0f, 0.0f, 38.0f, 8.0f, 19},
    {1, 0.0f, 0.0f, 38.0f, 8.0f, 20},     {1, 0.0f, 0.0f, 38.0f, 8.0f, 21},
    {1, 0.0f, 0.0f, 38.0f, 8.0f, 22},     {1, 0.0f, 0.0f, 4.0f, 6.0f, 23},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 24},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 25},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 26},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 27},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 28},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 29},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 30},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 31},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 32},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 33},
    {1, 0.0f, 0.0f, 6.0f, 6.0f, 34},      {1, 0.0f, 0.0f, 6.0f, 6.0f, 35},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 36},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 37},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 38},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 39},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 40},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 41},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 42},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 43},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 44},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 45},
    {1, 13.0f, 12.0f, 26.0f, 24.0f, 46},  {1, 10.0f, 12.0f, 20.0f, 24.0f, 47},
    {1, 13.0f, 12.0f, 26.0f, 24.0f, 48},  {1, 20.0f, 12.0f, 40.0f, 24.0f, 49},
    {1, 20.0f, 12.0f, 40.0f, 24.0f, 50},  {1, 20.0f, 12.0f, 40.0f, 24.0f, 51},
    {1, 0.0f, 0.0f, 50.0f, 6.0f, 52},     {1, 0.0f, 0.0f, 26.0f, 10.0f, 53},
    {1, 0.0f, 0.0f, 26.0f, 10.0f, 54},    {1, 0.0f, 0.0f, 33.0f, 10.0f, 55},
    {1, 0.0f, 0.0f, 33.0f, 10.0f, 56},    {1, 0.0f, 0.0f, 6.0f, 8.0f, 57},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 58},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 59},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 60},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 61},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 62},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 63},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 64},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 65},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 66},      {1, 0.0f, 0.0f, 2.0f, 8.0f, 67},
    {1, 0.0f, 0.0f, 4.0f, 8.0f, 68},      {1, 0.0f, 0.0f, 8.0f, 8.0f, 69},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 70},      {1, 13.0f, 4.0f, 26.0f, 8.0f, 71},
    {1, 13.0f, 4.0f, 26.0f, 8.0f, 72},    {1, 13.0f, 4.0f, 26.0f, 8.0f, 73},
    {1, 13.0f, 4.0f, 26.0f, 8.0f, 74},    {1, 18.0f, 4.0f, 36.0f, 8.0f, 75},
    {1, 18.0f, 4.0f, 36.0f, 8.0f, 76},    {1, 13.0f, 4.0f, 26.0f, 8.0f, 77},
    {1, 30.0f, 4.0f, 60.0f, 8.0f, 78},    {1, 30.0f, 4.0f, 60.0f, 8.0f, 79},
    {1, 30.0f, 4.0f, 60.0f, 8.0f, 80},    {1, 30.0f, 4.0f, 60.0f, 8.0f, 81},
    {1, 33.0f, 4.0f, 66.0f, 8.0f, 82},    {1, 18.0f, 4.0f, 36.0f, 8.0f, 83},
    {1, 46.0f, 4.0f, 92.0f, 8.0f, 84},    {1, 0.0f, 0.0f, 8.0f, 10.0f, 85},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 86},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 87},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 88},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 89},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 90},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 91},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 92},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 93},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 94},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 95},
    {1, 0.0f, 0.0f, 5.0f, 10.0f, 96},     {1, 0.0f, 0.0f, 114.0f, 10.0f, 97},
    {1, 0.0f, 0.0f, 1.0f, 8.0f, 98},      {1, 0.0f, 0.0f, 8.0f, 11.0f, 99},
    {1, 0.0f, 0.0f, 62.0f, 62.0f, 100},   {1, 3.0f, 3.0f, 6.0f, 6.0f, 101},
    {1, 0.0f, 0.0f, 66.0f, 8.0f, 102},    {1, 0.0f, 0.0f, 76.0f, 8.0f, 103},
    {1, 0.0f, 0.0f, 32.0f, 7.0f, 104},    {1, 0.0f, 0.0f, 86.0f, 12.0f, 105},
    {1, 0.0f, 0.0f, 170.0f, 20.0f, 106},  {1, 0.0f, 0.0f, 150.0f, 26.0f, 107},
    {1, 0.0f, 0.0f, 123.0f, 26.0f, 108},  {1, 0.0f, 0.0f, 150.0f, 26.0f, 109},
    {1, 0.0f, 0.0f, 1.0f, 28.0f, 110},    {1, 0.0f, 0.0f, 22.0f, 28.0f, 111},
    {1, 0.0f, 0.0f, 1.0f, 28.0f, 112},    {1, 0.0f, 0.0f, 24.0f, 50.0f, 113},
    {1, 0.0f, 0.0f, 1.0f, 50.0f, 114},    {1, 58.0f, 9.0f, 116.0f, 18.0f, 115},
    {1, 0.0f, 0.0f, 72.0f, 24.0f, 116},   {1, 0.0f, 0.0f, 70.0f, 24.0f, 117},
    {1, 0.0f, 0.0f, 94.0f, 24.0f, 118},   {1, 51.0f, 6.0f, 102.0f, 12.0f, 119},
    {1, 56.0f, 6.0f, 112.0f, 12.0f, 120}, {1, 22.0f, 5.0f, 44.0f, 10.0f, 121},
    {1, 51.0f, 5.0f, 102.0f, 10.0f, 122}, {1, 51.0f, 5.0f, 102.0f, 10.0f, 123},
    {1, 22.0f, 5.0f, 44.0f, 10.0f, 124},  {1, 51.0f, 5.0f, 102.0f, 10.0f, 125},
};

/** @ghidraAddress 0x1151fc */
ResultWindowClassicLayer *ResultWindowClassicLayer::shared() {
    if (g_pClassicResultLayer == nullptr) {
        // The binary allocates the raw 0x1c0-byte object and runs the colour-marker constructor
        // (0x115094), which seeds the transform vectors and four colour sub-objects; that
        // constructor's field initialisation is not yet reconstructed, so only the base is set up
        // here.
        g_pClassicResultLayer = new ResultWindowClassicLayer();
    }
    return g_pClassicResultLayer;
}

/** @ghidraAddress 0x114b78 */
const PartsDataRecord *ResultWindowClassicLayer::getPartsData(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kClassicPartsRecordBound);

    // The pad build reads the runtime-filled pad table; the phone build reads the static table.
    return IsPad() ? &g_aClassicPartsPad[nIndex] : &g_aClassicPartsPhone[nIndex];
}

/** @ghidraAddress 0x114c10 */
const PartsDataRecord *ResultWindowClassicLayer::getPartsData_Phone(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kClassicPhonePartsRecordCount);

    // This accessor always reads the static phone parts table.
    return &g_aClassicPartsPhone[nIndex];
}

namespace {

// The texture-name table entries the result window loads (@ghidraAddress 0x3cea80 and 0x3ceab0).
constexpr const char *kBackgroundTextureName = "00_texture/sel_bg";
constexpr const char *kPartsTextureName = "00_texture/result_parts";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x304170). Slot 1 (the parts atlas) holds
// the most sprites; the rest are small fixed banks.
constexpr unsigned int kSlotCapacities[] = {1, 400, 1, 1, 1, 2, 2, 0};

// The per-slot texture-field selector (@ghidraAddress 0x304150): the index (0 = background, 1 =
// parts) into the layer's two texture fields for each slot that binds a texture. A slot binds a
// texture only when it is one of the first two or the last (the middle slots share the atlas already
// bound by the batch they mirror).
constexpr int kSlotTextureField[] = {0, 1, 3, 3, 3, 3, 3, 0};

// The default sprite alpha and scale the builder seeds before creating the batches.
constexpr unsigned int kDefaultAlpha = 0xff;
constexpr float kDefaultScale = 1.0f;

// The slot range whose members do not bind a texture: slots kFirstUntexturedSlot through
// kFirstUntexturedSlot + kUntexturedSlotSpan - 1 (that is, slots 2 through 6).
constexpr int kFirstUntexturedSlot = 2;
constexpr int kUntexturedSlotSpan = 5;

} // namespace

namespace {

// The play-record cell ids the tweet reads per side.
constexpr unsigned int kCellScore = 0;
constexpr unsigned int kCellMaxCombo = 2;
constexpr unsigned int kCellJust = 3;
constexpr unsigned int kCellGreat = 4;
constexpr unsigned int kCellGood = 5;
constexpr unsigned int kCellMiss = 6;
constexpr unsigned int kCellJustReflec = 7;

// The two score columns (the local player and the rival) the share image draws.
constexpr int kShareSideCount = 2;

// The achievement rate is reported as a percentage: the stored rate times this scale.
constexpr float kSharePercentScale = 100.0f; // 1000.0 * 0.1, as the binary computes it.

// The themed sound effect fired when the share begins.
constexpr int kSoundEffectShare = 5;

// The default player name and the tweet body format (music name, side-one score and rate, and the
// App Store link), reproduced verbatim from the binary.
static NSString *const kSharePlayerName = @"なまえ";
static NSString *const kShareTweetFormat = @"%@をプレー！ Score:%d AR:%0.1f #rb_plus %@";
static NSString *const kShareStoreUrl =
    @"http://itunes.apple.com/jp/app/reflec-beat-plus/id472140433";

// Builds the classic result-screen Twitter share image from the current play result and posts it
// through the view controller. This variant uses the light (white) title and artist images. A free
// function that reads only the game-system, score-tracker, and app-delegate singletons.
// @ghidraAddress 0x117628
void PostResultToTwitter() {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectShare);

    RBViewController *pViewController = AppDelegate.appDelegate.viewController;
    if (pViewController == nil) {
        return;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    ScoreTracker *pTracker = ScoreTracker::shared();

    TwitterImageCreater *pCreater = [[TwitterImageCreater alloc] init];
    MusicData *pMusic = AppDelegate.appDelegate.musicData;
    pCreater.titleImage = pMusic.musicNameImageWhite;
    pCreater.artistImage = pMusic.artistNameImageWhite;
    pCreater.grade = pGameSystem->GetDifficulty();
    pCreater.level = pGameSystem->GetDifficultyLevel();
    pCreater.gameType = pGameSystem->GetGameType();
    pCreater.noteNum = pTracker->GetTotalNotes();

    for (int nSide = 0; nSide < kShareSideCount; ++nSide) {
        const unsigned int nUside = static_cast<unsigned int>(nSide);
        [pCreater setScore:pTracker->GetPlayRecordCell(nUside, kCellScore) Side:nSide];
        [pCreater setAR:pTracker->GetPlayRecordRate(nUside) Side:nSide];
        [pCreater setJustNum:pTracker->GetPlayRecordCell(nUside, kCellJust) Side:nSide];
        [pCreater setGreatNum:pTracker->GetPlayRecordCell(nUside, kCellGreat) Side:nSide];
        [pCreater setGoodNum:pTracker->GetPlayRecordCell(nUside, kCellGood) Side:nSide];
        [pCreater setMissNum:pTracker->GetPlayRecordCell(nUside, kCellMiss) Side:nSide];
        [pCreater setJustReflecNum:pTracker->GetPlayRecordCell(nUside, kCellJustReflec) Side:nSide];
        [pCreater setMaxComboNum:pTracker->GetPlayRecordCell(nUside, kCellMaxCombo) Side:nSide];
        [pCreater setName:kSharePlayerName Side:nSide];
    }

    // The tweet body reports the local player's (side one) score and percentage rate.
    MusicData *pTweetMusic = AppDelegate.appDelegate.musicData;
    NSString *musicName = pTweetMusic.musicName;
    const int nScore = pTracker->GetPlayRecordCell(1, kCellScore);
    const double flRate = static_cast<double>(pTracker->GetPlayRecordRate(1) * kSharePercentScale);
    NSString *tweet =
        [NSString stringWithFormat:kShareTweetFormat, musicName, nScore, flRate, kShareStoreUrl];
    [pViewController PostTwitter:pCreater Text:tweet];
}

} // namespace

namespace {

// The anchor modes that offset a base coordinate relative to the play-field viewport. Mode 0 (and
// any value outside this range) leaves the coordinate unshifted.
enum AnchorMode {
    kAnchorNone = 0,                // No offset.
    kAnchorHalfHeight = 1,          // y += viewportHeight / 2.
    kAnchorFullHeight = 2,          // y += viewportHeight.
    kAnchorHalfWidth = 3,           // x += viewportWidth / 2.
    kAnchorHalfWidthHalfHeight = 4, // x += viewportWidth / 2, y += viewportHeight / 2.
    kAnchorHalfWidthFullHeight = 5, // x += viewportWidth / 2, y += viewportHeight.
    kAnchorFullWidth = 6,           // x += viewportWidth.
    kAnchorFullWidthHalfHeight = 7, // x += viewportWidth, y += viewportHeight / 2.
    kAnchorFullWidthFullHeight = 8, // x += viewportWidth, y += viewportHeight.
};

// The part-id upper bound the sprite dispatcher ignores at or above.
constexpr unsigned int kPartIdBound = 0xf0;
// The sprite colour intensities for the main pass and the half-intensity shadow pass.
constexpr unsigned int kIntensityFull = 0xff;
constexpr unsigned int kIntensityShadow = 0x80;

// The glyph banks that carry special digit-sequence layout: the two score-column banks and the
// rating-column bank (which draw a paired glyph and shift the first glyph), plus the banks whose
// trailing '1' is kerned.
constexpr unsigned int kScoreColumnBankA = 0x85;
constexpr unsigned int kScoreColumnBankB = 0x9b;
constexpr unsigned int kRatingColumnBank = 0xb1;
constexpr unsigned int kKernBankPlus4A = 0x4d;
constexpr unsigned int kKernBankPlus4B = 0x57;
constexpr unsigned int kKernBankPlus2 = 0x72;
// The maximum number of digits RenderDigitSequence splits a value into.
constexpr int kMaxDigitCount = 6;

// The digit glyph bank RenderScoreDigitsCompact draws from, and the maximum digits it shows.
constexpr unsigned int kCompactDigitBank = 0x72;
constexpr int kCompactMaxDigits = 4;

// The character-code upper bound the glyph dispatcher ignores at or above.
constexpr unsigned int kCharCodeBound = 0x7e;

// The dot glyph character code drawn between the integer and fractional parts.
constexpr unsigned int kDotGlyph = 0x7d;

// The dot glyph part id RenderScorePaddedWithDot inserts after the ones digit, and its minimum
// digit count.
constexpr unsigned int kPaddedDotPart = 0x7c;
constexpr int kPaddedMinDigits = 2;

// The glyph character codes RenderDecimalWithDotGlyph draws: a leading glyph, the digit bank (its
// '0'), and the narrow dot glyph inserted after the ones digit. It shows at least two significant
// digits, out of a maximum of four.
constexpr unsigned int kDecimalLeadingGlyph = 0x45;
constexpr unsigned int kDecimalDigitBank = 0x39;
constexpr unsigned int kDecimalDotGlyph = 0x43;
constexpr int kDecimalMinDigits = 2;
constexpr int kDecimalMaxDigits = 4;
// The fixed per-glyph advance and the centring bias RenderDecimalWithDotGlyph uses (the dot glyph is
// tucked two pixels tighter than a full advance).
constexpr float kDecimalGlyphAdvance = 6.0f;
constexpr float kDecimalCenterBias = 2.0f;
constexpr float kDecimalDotAdvance = 2.0f;

// The glyph codes RenderRatioDigits draws: the digit bank (its '0') and the separator glyph placed
// between the numerator and denominator groups. It shows at least one significant digit per group,
// out of a maximum of four.
constexpr unsigned int kRatioDigitBank = 0x39;
constexpr unsigned int kRatioSeparatorGlyph = 0x46;
constexpr int kRatioMaxDigits = 4;
// RenderRatioDigits lays glyphs out on a fixed seven-pixel advance, drawing each digit six pixels
// left of the advancing cursor. Centring reserves the separator's nominal width plus a two-pixel
// bias; the cursor pre-steps a full advance before the separator and is tightened one extra pixel
// after it.
constexpr float kRatioGlyphAdvance = 7.0f;
constexpr float kRatioDigitInset = 6.0f;
constexpr float kRatioSeparatorWidth = 6.0f;
constexpr float kRatioCenterBias = 2.0f;
constexpr float kRatioSeparatorTighten = 1.0f;

// The digit bank RenderDigitRowSpacedByWidth draws from (its '0'), its maximum digit count, the
// nominal glyph width used to centre the run, and the extra pixel added to each glyph's own width
// when advancing.
constexpr unsigned int kRowDigitBank = 0x39;
constexpr int kRowMaxDigits = 4;
constexpr float kRowNominalGlyphWidth = 7.0f;
constexpr float kRowGlyphSpacing = 1.0f;

// Offsets a base coordinate by half or full viewport dimensions per the anchor mode, shared by the
// phone position accessors.
inline void ApplyAnchorOffset(int nAnchorMode, float *pX, float *pY) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flWidth = pGameSystem->GetViewportWidth();
    const float flHeight = pGameSystem->GetViewportHeight();
    switch (nAnchorMode) {
    case kAnchorHalfHeight:
        *pY += flHeight * 0.5f;
        break;
    case kAnchorFullHeight:
        *pY += flHeight;
        break;
    case kAnchorHalfWidth:
        *pX += flWidth * 0.5f;
        break;
    case kAnchorHalfWidthHalfHeight:
        *pX += flWidth * 0.5f;
        *pY += flHeight * 0.5f;
        break;
    case kAnchorHalfWidthFullHeight:
        *pX += flWidth * 0.5f;
        *pY += flHeight;
        break;
    case kAnchorFullWidth:
        *pX += flWidth;
        break;
    case kAnchorFullWidthHalfHeight:
        *pX += flWidth;
        *pY += flHeight * 0.5f;
        break;
    case kAnchorFullWidthFullHeight:
        *pX += flWidth;
        *pY += flHeight;
        break;
    default:
        break;
    }
}

} // namespace

/** @ghidraAddress 0x114c80 */
void ResultWindowClassicLayer::getPosition_Phone(int nIndex, S_VECTOR2 *pOutPosition) const {
    assert(nIndex >= 0 && nIndex < kClassicPositionRecordCount);

    // The orientation flag selects the portrait table; otherwise the landscape table is used.
    const PhoneAnchorRecord &record = m_bPortrait ? g_aClassicPositionPhonePortrait[nIndex] :
                                                    g_aClassicPositionPhoneLandscape[nIndex];
    pOutPosition->x = record.flX;
    pOutPosition->y = record.flY;

    // Offset the base coordinate by half or full viewport dimensions per the record's anchor mode.
    ApplyAnchorOffset(record.nAnchorMode, &pOutPosition->x, &pOutPosition->y);
}

/** @ghidraAddress 0x114e18 */
const PhoneLayoutRecord *ResultWindowClassicLayer::getSeparator_Phone(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kClassicSeparatorRecordCount);

    // The orientation flag selects the portrait table; otherwise the landscape table is used.
    return m_bPortrait ? &g_aClassicSeparatorPhonePortrait[nIndex] :
                         &g_aClassicSeparatorPhoneLandscape[nIndex];
}

/** @ghidraAddress 0x114e9c */
void ResultWindowClassicLayer::getPositionByState_Phone(int nIndex,
                                                        PhoneLayoutRect *pOutRect) const {
    // The iPad uses the state table; the phone uses its landscape or portrait table by orientation.
    const PhoneLayoutRecord &record =
        IsPad() ? g_aClassicPositionPhoneState[nIndex] :
                  (m_bPortrait ? g_aClassicPositionPhoneStatePortrait[nIndex] :
                                 g_aClassicPositionPhoneStateLandscape[nIndex]);
    pOutRect->flX = record.flX;
    pOutRect->flY = record.flY;
    pOutRect->flWidth = record.flWidth;
    pOutRect->flHeight = record.flHeight;

    // Offset the leading coordinate by half or full viewport dimensions per the record's anchor mode.
    ApplyAnchorOffset(record.nAnchorMode, &pOutRect->flX, &pOutRect->flY);
}

/** @ghidraAddress 0x115008 */
void ResultWindowClassicLayer::getCenterPosition_Phone(PhoneLayoutRect *pOutRect) const {
    // When the state flag is set the state record is copied verbatim, with no viewport anchoring.
    if (IsPad()) {
        *pOutRect = g_ClassicCenterPositionPhoneState;
        (void)GameSystem::
            GetGameSystem(); // The binary tail-calls the singleton getter and discards it.
        return;
    }

    // Otherwise the orientation flag selects the portrait or landscape record, and the leading
    // coordinate is shifted by half the viewport width and height.
    const PhoneLayoutRect &record =
        m_bPortrait ? g_ClassicCenterPositionPhonePortrait : g_ClassicCenterPositionPhoneLandscape;
    *pOutRect = record;
    ApplyAnchorOffset(kAnchorHalfWidthHalfHeight, &pOutRect->flX, &pOutRect->flY);
}

/** @ghidraAddress 0x1171a0 */
void ResultWindowClassicLayer::UpdateGestureTouchTracking() {
    // Only the first four regions are hit-box regions; the fifth is the drag slider handled
    // elsewhere.
    constexpr int kHitBoxRegionCount = 4;
    for (int nRegion = 0; nRegion < kHitBoxRegionCount; ++nRegion) {
        GestureTouchRegion &region = m_aGestureRegions[nRegion];

        // A disabled region drops any tracked touch and clears its flags.
        if (!region.bEnabled) {
            region.nTouchId = -1;
            region.bDown = false;
            region.bTapEdge = false;
            region.bEnabled = false;
        }

        TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
        if (region.nTouchId == -1) {
            // Unclaimed: latch the first freshly-pressed touch that lands inside the region's box.
            for (int nIndex = 0; nIndex < pTouchManager->GetActiveTouchCount(); ++nIndex) {
                TouchPoint *pTouch = pTouchManager->GetActiveTouch(nIndex);
                if (!pTouch->bIsNew) {
                    continue;
                }
                const float flX = static_cast<float>(pTouch->nCurrentX);
                const float flY = static_cast<float>(pTouch->nCurrentY);
                PhoneLayoutRect box{};
                getPositionByState_Phone(nRegion, &box);
                if (box.flX <= flX && flX <= box.flX + box.flWidth && box.flY <= flY &&
                    flY <= box.flY + box.flHeight) {
                    region.nTouchId = pTouch->nId;
                    region.bDown = true;
                    break;
                }
            }
        } else {
            // Claimed: track the held touch. Releasing it clears the region, latching the tap edge
            // when it lifted inside the box.
            TouchPoint *pTouch = pTouchManager->FindTouchById(region.nTouchId);
            if (pTouch == nullptr) {
                region.nTouchId = -1;
                region.bDown = false;
            } else {
                const float flX = static_cast<float>(pTouch->nCurrentX);
                const float flY = static_cast<float>(pTouch->nCurrentY);
                PhoneLayoutRect box{};
                getPositionByState_Phone(nRegion, &box);
                const bool bInside = box.flX <= flX && flX <= box.flX + box.flWidth &&
                                     box.flY <= flY && flY <= box.flY + box.flHeight;
                region.bDown = bInside;
                if (pTouch->bEnded) {
                    region.nTouchId = -1;
                    if (bInside) {
                        // The tap-edge latch also clears the down flag (a single halfword store).
                        region.bDown = false;
                        region.bTapEdge = true;
                    }
                }
            }
        }
    }
}

namespace {
// The fully-opaque alpha level the panel-shown gate compares against.
constexpr int kFullyOpaqueAlpha = 255;
// The side-slider drag threshold, in pixels, past the touch's start X in either direction.
constexpr float kSliderDragThreshold = 30.0f;
// The slider's two settle-target directions.
constexpr float kSliderDirectionRight = 1.0f;
constexpr float kSliderDirectionLeft = -1.0f;
// The themed sound effect the slider toggle fires.
constexpr int kSliderToggleSoundEffect = 7;
} // namespace

/** @ghidraAddress 0x1173d8 */
void ResultWindowClassicLayer::UpdateTouchAndPostTwitterShare() {
    // The result panel is interactive only once its reveal is complete and the screen fade is gone:
    // the panel alpha channel must read fully opaque and the fade overlay must be fully clear.
    const int nPanelAlpha =
        static_cast<int>(m_aScoreAnimChannels[kScoreChannel].flCurrent * kFullyOpaqueAlpha);
    const float flChannelC = m_aScoreAnimChannels[kEffectChannelC].flCurrent;
    const float flFadeAlpha = FadeOverlayLayer::shared()->GetCurrentAlpha();

    UpdateGestureTouchTracking();

    m_aGestureRegions[0].bEnabled = nPanelAlpha == kFullyOpaqueAlpha && flFadeAlpha == 0.0f;
    if (flFadeAlpha != 0.0f ||
        static_cast<int>(flChannelC * static_cast<float>(nPanelAlpha)) != kFullyOpaqueAlpha) {
        // Not fully shown: disable the swipe regions, and the share region when Twitter is available.
        m_aGestureRegions[1].bEnabled = false;
        m_aGestureRegions[2].bEnabled = false;
        if (m_bTwitterAvailable) {
            m_aGestureRegions[3].bEnabled = false;
        }
        return;
    }

    // Fully shown: the swipe regions follow the device (their enable flag mirrors the is-pad flag),
    // and the share region follows Twitter availability.
    if (IsPad()) {
        m_aGestureRegions[1].bEnabled = true;
        m_aGestureRegions[2].bEnabled = true;
    }
    if (m_bTwitterAvailable) {
        m_aGestureRegions[3].bEnabled = true;
    }

    // Track a horizontal swipe over the centre box: claim a fresh touch inside it, then release it
    // as a left or right swipe once it moves past the drag threshold from its start X.
    TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
    if (m_nSliderTouchId == -1) {
        for (int nIndex = 0; nIndex < pTouchManager->GetActiveTouchCount(); ++nIndex) {
            TouchPoint *pTouch = pTouchManager->GetActiveTouch(nIndex);
            if (!pTouch->bIsNew) {
                continue;
            }
            const float flX = static_cast<float>(pTouch->nCurrentX);
            const float flY = static_cast<float>(pTouch->nCurrentY);
            PhoneLayoutRect box{};
            getCenterPosition_Phone(&box);
            if (box.flX <= flX && flX <= box.flX + box.flWidth && box.flY <= flY &&
                flY <= box.flY + box.flHeight) {
                m_nSliderTouchId = pTouch->nId;
                m_flSliderStartX = flX;
                break;
            }
        }
    } else {
        TouchPoint *pTouch = pTouchManager->FindTouchById(m_nSliderTouchId);
        if (pTouch == nullptr) {
            // The touch is gone: stop tracking.
            m_nSliderTouchId = -1;
        } else {
            const float flX = static_cast<float>(pTouch->nCurrentX);
            if (flX < m_flSliderStartX - kSliderDragThreshold) {
                m_aGestureRegions[2].bTapEdge = true; // A left swipe.
                m_nSliderTouchId = -1;
            } else if (flX > m_flSliderStartX + kSliderDragThreshold) {
                m_aGestureRegions[1].bTapEdge = true; // A right swipe.
                m_nSliderTouchId = -1;
            }
            // Within the drag deadzone the touch keeps tracking (its id is retained).
        }
    }

    // On a swipe in single-player, toggle the slider value and fire the toggle sound.
    if ((GameSystem::GetGameSystem()->GetGameType() | 2) == 2 &&
        (m_aGestureRegions[1].bTapEdge || m_aGestureRegions[2].bTapEdge)) {
        m_flSlideTimer =
            m_aGestureRegions[1].bTapEdge ? kSliderDirectionRight : kSliderDirectionLeft;
        m_aGestureRegions[1].bTapEdge = false;
        m_aGestureRegions[2].bTapEdge = false;
        m_nNetworkPlay = m_nNetworkPlay != 1; // The binary reuses this slot as the slider toggle.
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSliderToggleSoundEffect);
    }

    // On the share gesture, consume the edge and post the result to Twitter.
    if (m_bTwitterAvailable && m_aGestureRegions[3].bTapEdge) {
        m_aGestureRegions[3].bTapEdge = false;
        PostResultToTwitter();
    }
}

/** @ghidraAddress 0x116808 */
void ResultWindowClassicLayer::AppendSpriteToSlot(const S_VECTOR2 &position,
                                                  const S_VECTOR2 &anchor,
                                                  const S_VECTOR2 &size,
                                                  const S_VECTOR2 &uvOrigin,
                                                  const S_VECTOR2 &uvSize,
                                                  float flRotation,
                                                  const S_VECTOR2 &scale,
                                                  unsigned int nSlot,
                                                  unsigned int nIntensity,
                                                  unsigned int nAlpha) {
    if (nSlot >= kSpriteSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    const int nSprite = pInstancer->GetSpriteCount();
    if (nSprite >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    pInstancer->SetSpritePosition(nSprite, position);
    pInstancer->SetSpriteAnchor(nSprite, anchor);
    pInstancer->SetSpriteSize(nSprite, size);
    pInstancer->SetSpriteUvOrigin(nSprite, uvOrigin);
    pInstancer->SetSpriteUvSize(nSprite, uvSize);
    pInstancer->SetSpriteRotation(nSprite, flRotation);
    pInstancer->SetSpriteScale(nSprite, scale.x, scale.y);
    pInstancer->SetSpriteColor(nSprite, nIntensity, nIntensity, nIntensity, nAlpha);
    pInstancer->SetSpriteCount(nSprite + 1);
}

/** @ghidraAddress 0x115864 */
void ResultWindowClassicLayer::EmitPartSprite(float flRotation,
                                              float flScaleX,
                                              float flScaleY,
                                              unsigned int nSlot,
                                              unsigned int nPartId,
                                              const S_VECTOR2 &position,
                                              unsigned int nAlpha,
                                              bool bShadowPass) {
    if (nPartId >= kPartIdBound) {
        return;
    }
    const PartsDataRecord *pRecord = getPartsData(static_cast<int>(nPartId));
    const UvPaletteEntry &palette = g_aClassicUvPalette[pRecord->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass ? kIntensityShadow : kIntensityFull;
    AppendSpriteToSlot(position,
                       S_VECTOR2{pRecord->flX, pRecord->flY},
                       S_VECTOR2{pRecord->flWidth, pRecord->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x115514 */
void ResultWindowClassicLayer::RenderDigitSequence(int nValue,
                                                   int nDigitCount,
                                                   const S_VECTOR2 *pOrigin,
                                                   unsigned int nGlyphBase,
                                                   bool bLeadingZero,
                                                   bool bPadRight,
                                                   unsigned int nAlpha,
                                                   float flSpacing) {
    // The glyphs draw into the parts slot at unit scale.
    constexpr unsigned int kGlyphSlot = 1;

    // Split the value into decimal digits (least-significant first), tracking the most-significant
    // non-zero digit.
    int aDigits[kMaxDigitCount] = {};
    int nMostSignificant = 0;
    for (int i = 0; i < nDigitCount; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nMostSignificant = i;
        }
        nValue /= 10;
    }
    // An all-zero value still shows one digit when the leading-zero flag is set.
    if (nMostSignificant == 0 && bLeadingZero) {
        nMostSignificant = 1;
    }

    S_VECTOR2 drawPos{pOrigin->x, pOrigin->y};
    float flY = pOrigin->y;
    for (int i = 0; i <= nMostSignificant; ++i) {
        const int nDigit = aDigits[i];
        unsigned int nPartId = nDigit + nGlyphBase;

        // The score columns comma-shift their first glyph and raise their second.
        if (nGlyphBase == kScoreColumnBankB || nGlyphBase == kScoreColumnBankA) {
            if (i == 0 && bLeadingZero) {
                nPartId = nGlyphBase + 0xb + nDigit;
            } else if (i == 1 && bLeadingZero) {
                flY -= 4.0f;
                drawPos.y = flY;
            }
        }
        const bool bFirstPaired = (i == 0) && bLeadingZero;
        if (nGlyphBase == kRatingColumnBank && bFirstPaired) {
            nPartId = nGlyphBase + 0xb + nDigit;
        }

        const PartsDataRecord *pRecord = getPartsData(static_cast<int>(nPartId));
        drawPos.x -= pRecord->flWidth;
        // Micro-nudge a trailing '1' to keep decimal columns aligned across the glyph banks.
        if (i == nDigitCount - 1 && nDigit == 1) {
            if (nGlyphBase < kScoreColumnBankA) {
                if (nGlyphBase == kKernBankPlus4A || nGlyphBase == kKernBankPlus4B) {
                    drawPos.x += 4.0f;
                } else if (nGlyphBase == kKernBankPlus2) {
                    drawPos.x += 2.0f;
                }
            } else if (nGlyphBase == kScoreColumnBankA || nGlyphBase == kScoreColumnBankB) {
                drawPos.x += 6.0f;
            } else if (nGlyphBase == kRatingColumnBank) {
                drawPos.x += 4.0f;
            }
        }

        EmitPartSprite(0.0f, 1.0f, 1.0f, kGlyphSlot, nPartId, drawPos, nAlpha, 0);
        drawPos.x -= flSpacing;
        // A paired column draws a second glyph ten ids up from the base.
        if (bFirstPaired) {
            const PartsDataRecord *pPaired = getPartsData(static_cast<int>(nGlyphBase + 10));
            drawPos.x -= pPaired->flWidth;
            if (nGlyphBase == kRatingColumnBank) {
                flY -= 2.0f;
                drawPos.y = flY;
            }
            EmitPartSprite(0.0f, 1.0f, 1.0f, kGlyphSlot, nGlyphBase + 10, drawPos, nAlpha, 0);
            drawPos.x -= flSpacing;
        }
    }

    // Pad the remaining leading positions with dimmed zeros.
    if (bPadRight && nMostSignificant + 1 < nDigitCount) {
        for (int nRemaining = (nDigitCount - 1) - nMostSignificant; nRemaining != 0; --nRemaining) {
            const PartsDataRecord *pRecord = getPartsData(static_cast<int>(nGlyphBase));
            drawPos.x -= pRecord->flWidth;
            EmitPartSprite(0.0f, 1.0f, 1.0f, kGlyphSlot, nGlyphBase, drawPos, nAlpha, 1);
            drawPos.x -= flSpacing;
        }
    }
}

/** @ghidraAddress 0x1161cc */
void ResultWindowClassicLayer::DispatchGlyphSpriteFromTable(unsigned int nSlot,
                                                            unsigned int nCharCode,
                                                            const S_VECTOR2 *pPosition,
                                                            unsigned int nAlpha,
                                                            bool bDimmed,
                                                            float flRotation,
                                                            float flScaleX,
                                                            float flScaleY) {
    if (nCharCode >= kCharCodeBound) {
        return;
    }
    // The glyph metrics come from the parts table indexed by the character code; the texture
    // rectangle from the glyph UV palette.
    const PartsDataRecord *pGlyph = &g_aClassicPartsPhone[nCharCode];
    const UvPaletteEntry &palette = g_aClassicGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bDimmed ? kIntensityShadow : kIntensityFull;
    AppendSpriteToSlot(*pPosition,
                       S_VECTOR2{pGlyph->flX, pGlyph->flY},
                       S_VECTOR2{pGlyph->flWidth, pGlyph->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x115ac0 */
void ResultWindowClassicLayer::RenderScoreDigitsWithDot(int nIntegerValue,
                                                        int nFractionValue,
                                                        const S_VECTOR2 &position,
                                                        unsigned int nAlpha) {
    constexpr unsigned int kGlyphSlot = 1;

    // Split the integer part into up to four digits (at least one significant).
    int aInteger[kCompactMaxDigits] = {};
    int nIntegerLen = 0;
    for (int i = 0; i < kCompactMaxDigits; ++i) {
        aInteger[i] = nIntegerValue % 10;
        if (aInteger[i] != 0) {
            nIntegerLen = i + 1;
        }
        nIntegerValue /= 10;
    }
    if (nIntegerLen == 0) {
        nIntegerLen = 1;
    }

    // The uniform advance is the zero glyph's width.
    const float flAdvance = getPartsData(static_cast<int>(kCompactDigitBank))->flWidth;

    // Split the fractional part likewise.
    int aFraction[kCompactMaxDigits] = {};
    int nFractionLen = 0;
    for (int i = 0; i < kCompactMaxDigits; ++i) {
        aFraction[i] = nFractionValue % 10;
        if (aFraction[i] != 0) {
            nFractionLen = i + 1;
        }
        nFractionValue /= 10;
    }
    if (nFractionLen == 0) {
        nFractionLen = 1;
    }

    // Centre the combined run (integer digits, the dot, and fraction digits) about the position.
    const float flRunWidth = static_cast<float>(static_cast<int>(nFractionLen * flAdvance) +
                                                static_cast<int>(nIntegerLen * flAdvance)) +
                             flAdvance + 2.0f;
    float flX = position.x + flRunWidth * 0.5f;

    // Emit the integer digits right to left.
    for (int i = 0; i < nIntegerLen; ++i) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kGlyphSlot,
                       aInteger[i] + kCompactDigitBank,
                       S_VECTOR2{flX - flAdvance, position.y},
                       nAlpha,
                       0);
        flX -= flAdvance;
    }

    // Emit the dot glyph, then step past it.
    flX -= flAdvance + 1.0f;
    EmitPartSprite(0.0f, 1.0f, 1.0f, kGlyphSlot, kDotGlyph, S_VECTOR2{flX, position.y}, nAlpha, 0);
    flX -= 1.0f;

    // Emit the fraction digits right to left.
    for (int i = 0; i < nFractionLen; ++i) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kGlyphSlot,
                       aFraction[i] + kCompactDigitBank,
                       S_VECTOR2{flX - flAdvance, position.y},
                       nAlpha,
                       0);
        flX -= flAdvance;
    }
}

// The customize preview draws into this sprite instancer slot.
static constexpr unsigned int kCustomizePreviewSlot = 6;

/** @ghidraAddress 0x11c5a0 */
void ResultWindowClassicLayer::ToggleCustomizeCharacterTexture(unsigned int nCharacterId) {
    // Already shown: hide the preview and remember the id to re-show on the next toggle.
    if (m_bCustomizePreviewShown) {
        m_bCustomizePreviewShown = false;
        m_nCustomizePendingId = static_cast<int>(nCharacterId);
        return;
    }

    // Show the preview: resolve the character's unlock entry (its category is cached as the sub-id,
    // its item is the asset variant), build and load the asset texture, and bind it into the preview
    // slot. The binary discards this method's return value.
    m_nCustomizeCharacterId = static_cast<int>(nCharacterId);
    m_bCustomizePreviewShown = true;
    LevelTables::GetInstance(); // The binary vends the singleton (lazy-init) before the lookup.
    const LevelUnlockEntry *pEntry = LevelTables::GetLevelUnlockEntry(m_nCustomizeCharacterId);
    m_nCustomizeSubId = pEntry->nCategory;
    NSString *path = BuildCustomizeAssetPathString(pEntry->nCategory, pEntry->nItem);
    ne::C_TEXTURE *pTexture = ne::C_TEXTURE::FindOrLoadCached([path UTF8String]);
    if (pTexture != nullptr) {
        SetInstancerTextureAndRefreshSlots(kCustomizePreviewSlot, pTexture);
        pTexture->Release();
    }
}

// The main customize asset draws into this sprite instancer slot.
static constexpr unsigned int kMainAssetSlot = 5;

/** @ghidraAddress 0x11c66c */
void ResultWindowClassicLayer::BeginCustomizeMainAsset(unsigned int nAssetId) {
    m_nMainAssetId = static_cast<int>(nAssetId);
    LevelTables::GetInstance(); // The binary vends the singleton (lazy-init) before the lookups.

    // The asset is available only when its level threshold is non-negative; otherwise clear the
    // active flags and show nothing.
    if (static_cast<int>(LevelTables::GetLevelExpThreshold(m_nMainAssetId)) < 0) {
        m_bCustomizePending = false;
        m_bMainAssetActive = false;
        return;
    }

    m_bMainAssetActive = true;
    m_bCustomizePending = true;
    m_flMainAssetScale = 1.0f;

    // Resolve the asset's unlock entry (its category is the asset type, its item the variant), build
    // and load the asset texture, and bind it into the main asset slot. The binary discards this
    // method's return value.
    const LevelUnlockEntry *pEntry = LevelTables::GetLevelUnlockEntry(m_nMainAssetId);
    m_bMainAssetSubState = false;
    NSString *path = BuildCustomizeAssetPathString(pEntry->nCategory, pEntry->nItem);
    ne::C_TEXTURE *pTexture = ne::C_TEXTURE::FindOrLoadCached([path UTF8String]);
    // The binary binds and releases the texture unconditionally on the available path (no null check,
    // unlike the toggle helper).
    SetInstancerTextureAndRefreshSlots(kMainAssetSlot, pTexture);
    pTexture->Release();
}

namespace {
// The experience-bar reveal animation constants.
// The reveal timer bias (@ghidraAddress 0x302d70 = -4200) and its normalising duration
// (@ghidraAddress 0x2ec6b0 = 100).
constexpr float kExpRevealTimerBias = -4200.0f;
constexpr float kExpRevealDuration = 100.0f;
// The looping reveal sound-effect slot.
constexpr int kExpRevealSoundSlot = 6;
// The "no sound-effect handle" sentinel.
constexpr int kNoSeHandle = -1;

// Clamps a value to the unit interval.
float ClampUnit(float flValue) {
    if (flValue < 0.0f) {
        return 0.0f;
    }
    if (flValue > 1.0f) {
        return 1.0f;
    }
    return flValue;
}
} // namespace

/** @ghidraAddress 0x1199fc */
float ResultWindowClassicLayer::AdvanceCustomizeOverlayProgress(int nDeltaFrames) {
    // Maps the reveal progress through the gained-experience span into the settled experience ratio.
    const auto mapExpRatio = [this](float flProgress) {
        return (flProgress * static_cast<float>(m_nGainedExp) + static_cast<float>(m_nPlayerExp) -
                static_cast<float>(m_nLevelUpStep)) /
               static_cast<float>(m_nExpThreshold);
    };

    if (m_bExpAnimSettled) {
        // Already settled: report the mapped ratio at the frozen timer, without advancing.
        const float flProgress =
            ClampUnit((m_flExpAnimTimer + kExpRevealTimerBias) / kExpRevealDuration);
        return ClampUnit(mapExpRatio(flProgress));
    }

    // Accumulate the frame delta and normalise the reveal progress.
    m_flExpAnimTimer += static_cast<float>(nDeltaFrames);
    float flProgress = (m_flExpAnimTimer + kExpRevealTimerBias) / kExpRevealDuration;
    if (flProgress < 0.0f) {
        flProgress = 0.0f;
    } else if (flProgress > 1.0f) {
        flProgress = 1.0f;
    }

    float flResult;
    const float flExpRatio = mapExpRatio(flProgress);
    if (flExpRatio < 0.0f) {
        flResult = 0.0f;
    } else if (flExpRatio >= 1.0f) {
        // The reveal reached its target: latch it, show the next character texture, advance the asset
        // index, and either record the pending track index or begin the main-asset load.
        m_bExpAnimSettled = true;
        ToggleCustomizeCharacterTexture(static_cast<unsigned int>(m_nMainAssetId));
        ++m_nMainAssetId;
        if (m_bCustomizePending) {
            m_bCustomizePending = false;
            m_nTrackIndexC = m_nMainAssetId;
        } else {
            BeginCustomizeMainAsset(static_cast<unsigned int>(m_nMainAssetId));
        }
        flResult = 1.0f;
    } else {
        // Mid-reveal: while the timer is inside the ramp and there is experience to gain, keep a
        // looping reveal sound effect playing (re-acquire it once the previous handle finishes).
        if (flProgress > 0.0f && flProgress < 1.0f && m_nGainedExp != 0) {
            SoundEffectManager *pManager = SoundEffectManager::GetInstance();
            if (m_nRevealSeHandle == kNoSeHandle ||
                !pManager->IsPlaying(static_cast<unsigned int>(m_nRevealSeHandle))) {
                m_nRevealSeHandle =
                    static_cast<int>(pManager->PlayThemedSoundEffect(kExpRevealSoundSlot));
            }
        }
        flResult = flExpRatio;
    }

    m_flMainAssetScale = 1.0f - flResult;
    return flResult;
}

namespace {
// The phone-overlay slide constants.
// The overlay slide duration (@ghidraAddress 0x2eedcc = 300).
constexpr float kPhoneOverlaySlideDuration = 300.0f;
// The upward Y travel applied to the overlay as it slides in (@ghidraAddress 0xc1a00000 = -20).
constexpr float kPhoneOverlaySlideOffsetY = -20.0f;
// The phone (portrait) overlay glyph slot, part id, and anchor-position index.
constexpr unsigned int kPhoneOverlaySlot = 7;
constexpr unsigned int kPhoneOverlayCharCode = 0x64;
constexpr int kPhoneOverlayPositionIndex = 0x3c;
// The iPad (landscape) overlay part id.
constexpr unsigned int kPadOverlayPartId = 0xde;
// The main customize asset instancer slot the scaled render targets.
constexpr unsigned int kMainAssetRenderSlot = 5;
} // namespace

/** @ghidraAddress 0x119be8 */
void ResultWindowClassicLayer::RenderCustomizePhoneOverlay(int nDeltaFrames,
                                                           const S_VECTOR2 *pBasePos,
                                                           unsigned int nScale) {
    // Advance the slide timer: forward (clamped to the duration) while the direction flag is set,
    // backward (clamped to zero) while it is clear. On reaching zero, kick off any queued main-asset
    // load and clear the queue sentinel.
    float flTimer;
    if (m_bCustomizePending) {
        flTimer = m_flPhoneOverlayTimer + static_cast<float>(nDeltaFrames);
        if (flTimer >= kPhoneOverlaySlideDuration) {
            flTimer = kPhoneOverlaySlideDuration;
        }
        m_flPhoneOverlayTimer = flTimer;
    } else {
        flTimer = m_flPhoneOverlayTimer - static_cast<float>(nDeltaFrames);
        m_flPhoneOverlayTimer = flTimer;
        if (flTimer <= 0.0f) {
            m_flPhoneOverlayTimer = 0.0f;
            flTimer = 0.0f;
            if (m_nTrackIndexC != -1) {
                BeginCustomizeMainAsset(static_cast<unsigned int>(m_nTrackIndexC));
                m_nTrackIndexC = -1;
            }
        }
    }

    // Normalise the slide progress to the unit interval.
    float flProgress = flTimer / kPhoneOverlaySlideDuration;
    if (flProgress < 0.0f) {
        flProgress = 0.0f;
    } else if (flProgress > 1.0f) {
        flProgress = 1.0f;
    }

    // The overlay eases upward as it appears; its base alpha scales with the progress.
    S_VECTOR2 renderPos{pBasePos->x, pBasePos->y + (1.0f - flProgress) * kPhoneOverlaySlideOffsetY};
    const float flAlphaBase = flProgress * static_cast<float>(nScale);
    const unsigned int nGroupAlpha =
        static_cast<unsigned int>(static_cast<int>(flAlphaBase * m_flMainAssetScale));

    if (IsPad()) {
        // The iPad overlay part draws at the base position shifted by the fixed landscape offset;
        // the same shifted position feeds the final scaled render.
        AddVector2(&renderPos, &g_classicCustomizeOverlayLandscapeOffset);
        EmitPartSprite(
            0.0f, 1.0f, 1.0f, kPhoneOverlaySlot, kPadOverlayPartId, renderPos, nGroupAlpha, false);
    } else {
        // The phone overlay glyph draws at its own anchor plus the eased position; the final scaled
        // render then uses the eased position shifted by the phone anchor.
        RenderSpriteWithPositionOffset(kPhoneOverlaySlot,
                                       kPhoneOverlayCharCode,
                                       kPhoneOverlayPositionIndex,
                                       renderPos,
                                       nGroupAlpha,
                                       1.0f);
        S_VECTOR2 anchorPos{};
        getPosition_Phone(kPhoneOverlayPositionIndex, &anchorPos);
        AddVector2(&renderPos, &anchorPos);
    }

    // The main-asset slot render at the eased position; its scale folds the group alpha and the
    // inverse main-asset scale.
    const unsigned int nRenderScale =
        static_cast<unsigned int>(static_cast<int>(flAlphaBase * (1.0f - m_flMainAssetScale)));
    RenderSpriteInstancerSlotScaled(kMainAssetRenderSlot, renderPos, nRenderScale);
}

namespace {
// The nameplate-overlay slide constants.
// The nameplate slide duration (@ghidraAddress 0x2feff4 = 500).
constexpr float kNameplateSlideDuration = 500.0f;
// The upward Y travel applied to the nameplate as it slides in (@ghidraAddress 0xc1a00000 = -20).
constexpr float kNameplateSlideOffsetY = -20.0f;
// The nameplate reveal-complete sound-effect slot and themed voice.
constexpr int kNameplateRevealSoundSlot = 9;
constexpr int kNameplateRevealVoiceId = 0xe;
// The customize asset texture instancer slot the nameplate swap targets.
constexpr unsigned int kNameplateAssetSlot = 6;
// The part-id and character-code bases the nameplate name/level glyphs draw from.
constexpr unsigned int kNameplateNamePartBase = 0xdf; // iPad name part = subId + this.
constexpr unsigned int kNameplateLevelPart = 0xe4;    // iPad level part.
constexpr unsigned int kNameplateNameCharBase = 0x79; // phone name char = subId + this.
constexpr int kNameplateNamePositionIndex = 0x3d;     // phone name anchor.
constexpr unsigned int kNameplateLevelChar = 0x69;    // phone level char.
constexpr int kNameplateLevelPositionIndex = 0x3e;    // phone level anchor.
constexpr int kNameplateBackingPositionIndex = 0x3f;  // phone backing anchor.
constexpr unsigned int kNameplateGlyphSlot = 1;       // the name/level glyph instancer slot.
} // namespace

/** @ghidraAddress 0x119db4 */
void ResultWindowClassicLayer::RenderCustomizeNameplateOverlay(int nDeltaFrames,
                                                               const S_VECTOR2 *pBasePos,
                                                               unsigned int nScale) {
    if (!m_bCustomizePreviewShown) {
        // Decay phase: run the timer down; on reaching zero, promote any queued asset id, swap the
        // displayed customize-character texture, and re-enter the grow phase.
        m_flNameplateTimer -= static_cast<float>(nDeltaFrames);
        if (m_flNameplateTimer <= 0.0f) {
            m_flNameplateTimer = 0.0f;
            if (m_nCustomizePendingId != -1) {
                m_nCustomizeCharacterId = m_nCustomizePendingId;
                m_nCustomizePendingId = -1;
                m_bCustomizePreviewShown = true;
                LevelTables::GetInstance();
                const LevelUnlockEntry *pEntry =
                    LevelTables::GetLevelUnlockEntry(m_nCustomizeCharacterId);
                m_nCustomizeSubId = pEntry->nCategory;
                NSString *path = BuildCustomizeAssetPathString(pEntry->nCategory, pEntry->nItem);
                ne::C_TEXTURE *pTexture = ne::C_TEXTURE::FindOrLoadCached([path UTF8String]);
                SetInstancerTextureAndRefreshSlots(kNameplateAssetSlot, pTexture);
                pTexture->Release();
            }
        }
    } else if (m_flNameplateTimer < kNameplateSlideDuration) {
        // Grow phase: run the timer up; on reaching the cap, fire the reveal jingle and voice.
        m_flNameplateTimer += static_cast<float>(nDeltaFrames);
        if (kNameplateSlideDuration <= m_flNameplateTimer) {
            m_flNameplateTimer = kNameplateSlideDuration;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kNameplateRevealSoundSlot);
            SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kNameplateRevealVoiceId);
        }
    } else if (m_bExpAnimSettled) {
        // Fully grown: once the level-up voice finishes, fold the gained experience into the running
        // total and re-read the next level's threshold.
        if (![AudioManager.sharedManager isPlayingVoice]) {
            m_bExpAnimSettled = false;
            LevelTables::GetInstance();
            m_nLevelUpStep += m_nGainedExp;
            m_nGainedExp = static_cast<int>(LevelTables::GetLevelExpThreshold(m_nPlayerLevel));
        }
    }

    // The eased slide progress, upward Y offset, and base position.
    float flProgress = m_flNameplateTimer / kNameplateSlideDuration;
    if (flProgress < 0.0f) {
        flProgress = 0.0f;
    } else if (flProgress > 1.0f) {
        flProgress = 1.0f;
    }
    S_VECTOR2 renderPos{pBasePos->x, pBasePos->y + (1.0f - flProgress) * kNameplateSlideOffsetY};
    const unsigned int nAlpha =
        static_cast<unsigned int>(static_cast<int>(flProgress * static_cast<float>(nScale)));

    if (IsPad()) {
        // The iPad path draws the name and level glyphs at their landscape offsets.
        const unsigned int nNamePart =
            static_cast<unsigned int>(m_nCustomizeSubId) + kNameplateNamePartBase;
        S_VECTOR2 namePos = renderPos;
        AddVector2(&namePos, &g_classicNameplateNameOffset);
        EmitPartSprite(0.0f, 1.0f, 1.0f, kNameplateGlyphSlot, nNamePart, namePos, nAlpha, false);

        S_VECTOR2 levelPos = renderPos;
        AddVector2(&levelPos, &g_classicNameplateLevelOffset);
        EmitPartSprite(
            0.0f, 1.0f, 1.0f, kNameplateGlyphSlot, kNameplateLevelPart, levelPos, nAlpha, false);

        AddVector2(&renderPos, &g_classicNameplateBackingOffset);
        // Yes, the binary passes the name part id (subId + 0xdf) as the scaled render's scale here.
        RenderSpriteInstancerSlotScaled(kNameplateAssetSlot, renderPos, nNamePart);
    } else {
        // The phone path draws the name and level glyphs at their anchor positions plus the eased
        // position, then the backing group at its anchor.
        const unsigned int nNameChar =
            static_cast<unsigned int>(m_nCustomizeSubId) + kNameplateNameCharBase;
        RenderSpriteWithPositionOffset(
            kNameplateGlyphSlot, nNameChar, kNameplateNamePositionIndex, renderPos, nAlpha, 1.0f);
        RenderSpriteWithPositionOffset(kNameplateGlyphSlot,
                                       kNameplateLevelChar,
                                       kNameplateLevelPositionIndex,
                                       renderPos,
                                       nAlpha,
                                       1.0f);
        S_VECTOR2 anchorPos{};
        getPosition_Phone(kNameplateBackingPositionIndex, &anchorPos);
        AddVector2(&renderPos, &anchorPos);
        RenderSpriteInstancerSlotScaled(kNameplateAssetSlot, renderPos, nAlpha);
    }
}

/** @ghidraAddress 0x115348 */
void ResultWindowClassicLayer::SetInstancerTextureAndRefreshSlots(unsigned int nSlot,
                                                                  ne::C_TEXTURE *pTexture) {
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    const int nCapacity = static_cast<int>(pInstancer->GetCapacity());
    pInstancer->SetRefCountedMember(pTexture);
    if (pTexture == nullptr) {
        return;
    }

    // Refresh every sprite slot to the newly bound texture's dimensions.
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flTextureScale = pTexture->GetScale();
    const S_VECTOR2 spriteSize{flImageWidth / flTextureScale, flImageHeight / flTextureScale};
    const S_VECTOR2 uvSize{flImageWidth / static_cast<float>(pTexture->GetAllocWidth()),
                           flImageHeight / static_cast<float>(pTexture->GetAllocHeight())};
    for (int nSprite = 0; nSprite < nCapacity; ++nSprite) {
        pInstancer->SetSpriteSize(nSprite, spriteSize);
        pInstancer->SetSpriteUvOrigin(nSprite, S_VECTOR2{});
        pInstancer->SetSpriteUvSize(nSprite, uvSize);
    }
}

/** @ghidraAddress 0x116dc0 */
void ResultWindowClassicLayer::RenderGlyphAtSeparator(unsigned int nSlot,
                                                      int nSepIndex,
                                                      unsigned int nCharCode,
                                                      const S_VECTOR2 &offset,
                                                      unsigned int nAlpha) {
    if (nCharCode >= kCharCodeBound) {
        return;
    }
    if (nSepIndex < 0 || nSepIndex >= kClassicSeparatorRecordCount) {
        return;
    }

    // The glyph metrics come from the phone parts table indexed by the character code; the texture
    // rectangle from the glyph UV palette.
    const PartsDataRecord *pGlyph = &g_aClassicPartsPhone[nCharCode];
    const UvPaletteEntry &palette = g_aClassicGlyphUvPalette[pGlyph->nUvPaletteIndex];

    // The separator record supplies the anchored base position and this sprite's scale and rotation:
    // its width field is the X scale, its height field is the rotation.
    const PhoneLayoutRecord *pSeparator = getSeparator_Phone(nSepIndex);
    float flAnchoredX = pSeparator->flX;
    float flAnchoredY = pSeparator->flY;
    ApplyAnchorOffset(pSeparator->nAnchorMode, &flAnchoredX, &flAnchoredY);

    AppendSpriteToSlot(S_VECTOR2{flAnchoredX + offset.x, flAnchoredY + offset.y},
                       S_VECTOR2{pGlyph->flX, pGlyph->flY},
                       S_VECTOR2{pGlyph->flWidth, pGlyph->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       pSeparator->flHeight,
                       S_VECTOR2{pSeparator->flWidth, 1.0f},
                       nSlot,
                       kIntensityFull,
                       nAlpha);
}

/** @ghidraAddress 0x116950 */
void ResultWindowClassicLayer::BlitInstancerTextureSlot(unsigned int nSlot,
                                                        const S_VECTOR2 &position,
                                                        const S_VECTOR2 &size,
                                                        unsigned int nAlpha) {
    if (nSlot >= kSpriteSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    const ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
    if (pTexture == nullptr) {
        return;
    }
    // The used UV region is the image size over the allocated power-of-two size.
    const S_VECTOR2 uvSize{static_cast<float>(pTexture->GetImageWidth()) /
                               static_cast<float>(pTexture->GetAllocWidth()),
                           static_cast<float>(pTexture->GetImageHeight()) /
                               static_cast<float>(pTexture->GetAllocHeight())};
    AppendSpriteToSlot(position,
                       S_VECTOR2{},
                       size,
                       S_VECTOR2{},
                       uvSize,
                       0.0f,
                       S_VECTOR2{1.0f, 1.0f},
                       nSlot,
                       kIntensityFull,
                       nAlpha);
}

/** @ghidraAddress 0x116a0c */
void ResultWindowClassicLayer::RenderSpriteInstancerSlotScaled(unsigned int nSlot,
                                                               const S_VECTOR2 &position,
                                                               unsigned int nScale) {
    if (nSlot >= kSpriteSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    const ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
    if (pTexture == nullptr) {
        return;
    }
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flTextureScale = pTexture->GetScale();
    // The quad is sized by the texture's own scale factor; the UV region is the used image area.
    const S_VECTOR2 spriteSize{flImageWidth / flTextureScale, flImageHeight / flTextureScale};
    const S_VECTOR2 uvSize{flImageWidth / static_cast<float>(pTexture->GetAllocWidth()),
                           flImageHeight / static_cast<float>(pTexture->GetAllocHeight())};
    // The alpha channel is the requested scale times the layer's default scale; the intensity is the
    // texture's scale factor truncated to a byte.
    const unsigned int nAlpha =
        static_cast<unsigned int>(static_cast<float>(nScale) * m_flDefaultScale);
    const unsigned int nIntensity = static_cast<unsigned int>(flTextureScale) & 0xff;
    AppendSpriteToSlot(position,
                       S_VECTOR2{},
                       spriteSize,
                       S_VECTOR2{},
                       uvSize,
                       0.0f,
                       S_VECTOR2{1.0f, 1.0f},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x116ad0 */
void ResultWindowClassicLayer::RenderSpriteInstancerSlotHalfScale(unsigned int nSlot,
                                                                  const S_VECTOR2 &position,
                                                                  unsigned int nAlpha,
                                                                  unsigned int nIntensity) {
    if (nSlot >= kSpriteSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    // Unlike the other blit helpers, the binary does not null-check the bound texture here.
    const ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flTextureScale = pTexture->GetScale();
    // The quad is sized by the texture's scale factor and centred by anchoring at half its size.
    const S_VECTOR2 spriteSize{flImageWidth / flTextureScale, flImageHeight / flTextureScale};
    const S_VECTOR2 anchor{spriteSize.x * 0.5f, spriteSize.y * 0.5f};
    const S_VECTOR2 uvSize{flImageWidth / static_cast<float>(pTexture->GetAllocWidth()),
                           flImageHeight / static_cast<float>(pTexture->GetAllocHeight())};
    AppendSpriteToSlot(position,
                       anchor,
                       spriteSize,
                       S_VECTOR2{},
                       uvSize,
                       0.0f,
                       S_VECTOR2{1.0f, 1.0f},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x116b94 */
void ResultWindowClassicLayer::RenderTableSpriteAtIndex(unsigned int nSlot,
                                                        unsigned int nCharCode,
                                                        const S_VECTOR2 &position,
                                                        const S_VECTOR2 &offset,
                                                        unsigned int nAlpha,
                                                        bool bShadowPass,
                                                        float flRotation,
                                                        float flScaleX,
                                                        float flScaleY) {
    if (nCharCode >= kCharCodeBound) {
        return;
    }
    // The glyph metrics come from the phone parts table indexed by the character code; the texture
    // rectangle from the glyph UV palette. The sprite is placed at the position plus the offset.
    const PartsDataRecord *pGlyph = &g_aClassicPartsPhone[nCharCode];
    const UvPaletteEntry &palette = g_aClassicGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass ? kIntensityShadow : kIntensityFull;
    AppendSpriteToSlot(S_VECTOR2{position.x + offset.x, position.y + offset.y},
                       S_VECTOR2{pGlyph->flX, pGlyph->flY},
                       S_VECTOR2{pGlyph->flWidth, pGlyph->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x116cc0 */
void ResultWindowClassicLayer::RenderTableSpriteWithOffset(unsigned int nSlot,
                                                           unsigned int nCharCode,
                                                           int nPositionIndex,
                                                           const S_VECTOR2 &offset,
                                                           unsigned int nAlpha,
                                                           bool bShadowPass,
                                                           float flRotation,
                                                           float flScaleX,
                                                           float flScaleY) {
    if (nCharCode >= kCharCodeBound) {
        return;
    }
    // Resolve the base position by index, then emit as RenderTableSpriteAtIndex does: phone glyph
    // metrics, glyph UV palette, placed at the resolved position plus the offset.
    S_VECTOR2 position{};
    getPosition_Phone(nPositionIndex, &position);
    const PartsDataRecord *pGlyph = &g_aClassicPartsPhone[nCharCode];
    const UvPaletteEntry &palette = g_aClassicGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass ? kIntensityShadow : kIntensityFull;
    AppendSpriteToSlot(S_VECTOR2{position.x + offset.x, position.y + offset.y},
                       S_VECTOR2{pGlyph->flX, pGlyph->flY},
                       S_VECTOR2{pGlyph->flWidth, pGlyph->flHeight},
                       S_VECTOR2{palette.flU, palette.flV},
                       S_VECTOR2{palette.flUvWidth, palette.flUvHeight},
                       flRotation,
                       S_VECTOR2{flScaleX, flScaleY},
                       nSlot,
                       nIntensity,
                       nAlpha);
}

/** @ghidraAddress 0x116c2c */
void ResultWindowClassicLayer::RenderSpriteWithPositionOffset(unsigned int nSlot,
                                                              unsigned int nCharCode,
                                                              int nPositionIndex,
                                                              const S_VECTOR2 &offset,
                                                              unsigned int nAlpha,
                                                              float flScaleX) {
    // Resolve the base position by index, add the offset, then dispatch the glyph X-scaled only.
    S_VECTOR2 position{};
    getPosition_Phone(nPositionIndex, &position);
    S_VECTOR2 offsetCopy{offset.x, offset.y};
    AddVector2(&position, &offsetCopy);
    DispatchGlyphSpriteFromTable(nSlot, nCharCode, &position, nAlpha, 0, 0.0f, flScaleX, 1.0f);
}

/** @ghidraAddress 0x1166a8 */
void ResultWindowClassicLayer::RenderDigitRowSpacedByWidth(int nValue,
                                                           const S_VECTOR2 *pPosition,
                                                           unsigned int nAlpha) {
    constexpr unsigned int kGlyphSlot = 1;

    // Split the value into up to four digits (ones first), tracking the count of significant
    // digits, rendering at least one.
    int aDigits[kRowMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kRowMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant == 0) {
        nSignificant = 1;
    }

    // Centre the run about the position using the nominal glyph width, then step left by each
    // glyph's own width (plus one pixel) as it is drawn.
    const int nHalfWidth =
        static_cast<int>(static_cast<float>(nSignificant) * kRowNominalGlyphWidth);
    float flCursorX = pPosition->x + static_cast<float>(nHalfWidth) * 0.5f;

    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nGlyph = aDigits[i] + kRowDigitBank;
        const float flWidth =
            getPartsData_Phone(static_cast<int>(nGlyph))->flWidth + kRowGlyphSpacing;
        flCursorX -= flWidth;
        S_VECTOR2 drawPos{flCursorX, pPosition->y};
        DispatchGlyphSpriteFromTable(kGlyphSlot, nGlyph, &drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
    }
}

/** @ghidraAddress 0x116258 */
void ResultWindowClassicLayer::RenderRatioDigits(int nNumerator,
                                                 int nDenominator,
                                                 const S_VECTOR2 *pPosition,
                                                 unsigned int nAlpha) {
    constexpr unsigned int kGlyphSlot = 1;

    // Split each value into up to four digits (ones first), tracking the count of significant
    // digits, rendering at least one per group.
    int aNumerator[kRatioMaxDigits] = {};
    int aDenominator[kRatioMaxDigits] = {};
    int nNumeratorSig = 0;
    int nDenominatorSig = 0;
    for (int i = 0; i < kRatioMaxDigits; ++i) {
        aNumerator[i] = nNumerator % 10;
        if (aNumerator[i] != 0) {
            nNumeratorSig = i + 1;
        }
        nNumerator /= 10;
    }
    if (nNumeratorSig == 0) {
        nNumeratorSig = 1;
    }
    for (int i = 0; i < kRatioMaxDigits; ++i) {
        aDenominator[i] = nDenominator % 10;
        if (aDenominator[i] != 0) {
            nDenominatorSig = i + 1;
        }
        nDenominator /= 10;
    }
    if (nDenominatorSig == 0) {
        nDenominatorSig = 1;
    }

    // Centre the combined run about the position: reserve one glyph advance per digit plus the
    // separator's nominal width and a two-pixel bias. The cursor starts at the centre and steps
    // left; the run is emitted right to left (denominator, separator, numerator).
    const int nNumeratorWidth =
        static_cast<int>(static_cast<float>(nNumeratorSig) * kRatioGlyphAdvance);
    const int nDenominatorWidth =
        static_cast<int>(static_cast<float>(nDenominatorSig) * kRatioGlyphAdvance);
    const float flHalfWidth = (static_cast<float>(nDenominatorWidth + nNumeratorWidth) +
                               kRatioSeparatorWidth + kRatioCenterBias) *
                              0.5f;
    float flCursorX = pPosition->x + flHalfWidth;

    // The denominator digits (rightmost group).
    for (int i = 0; i < nDenominatorSig; ++i) {
        const unsigned int nGlyph = aDenominator[i] + kRatioDigitBank;
        S_VECTOR2 drawPos{flCursorX - kRatioDigitInset, pPosition->y};
        DispatchGlyphSpriteFromTable(kGlyphSlot, nGlyph, &drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
        flCursorX -= kRatioGlyphAdvance;
    }

    // The separator glyph, pre-stepped a full advance and tightened one pixel afterwards.
    flCursorX -= kRatioGlyphAdvance;
    S_VECTOR2 separatorPos{flCursorX, pPosition->y};
    DispatchGlyphSpriteFromTable(
        kGlyphSlot, kRatioSeparatorGlyph, &separatorPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
    flCursorX -= kRatioSeparatorTighten;

    // The numerator digits (leftmost group).
    for (int i = 0; i < nNumeratorSig; ++i) {
        const unsigned int nGlyph = aNumerator[i] + kRatioDigitBank;
        S_VECTOR2 drawPos{flCursorX - kRatioDigitInset, pPosition->y};
        DispatchGlyphSpriteFromTable(kGlyphSlot, nGlyph, &drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
        flCursorX -= kRatioGlyphAdvance;
    }
}

/** @ghidraAddress 0x1164e8 */
void ResultWindowClassicLayer::RenderDecimalWithDotGlyph(int nValue,
                                                         const S_VECTOR2 *pPosition,
                                                         unsigned int nAlpha) {
    constexpr unsigned int kGlyphSlot = 1;

    // Split the value into up to four digits (ones first), tracking the count of significant
    // digits, and render at least two.
    int aDigits[kDecimalMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kDecimalMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant < kDecimalMinDigits) {
        nSignificant = kDecimalMinDigits;
    }

    // Centre the run (the leading glyph plus the significant digits) about the given position using
    // the fixed glyph advance, then start one advance to the left of the centre.
    const int nGlyphCount = nSignificant + 1;
    const int nHalfWidth = static_cast<int>(static_cast<float>(nGlyphCount) * kDecimalGlyphAdvance +
                                            kDecimalCenterBias);
    S_VECTOR2 drawPos{pPosition->x + static_cast<float>(nHalfWidth) * 0.5f, pPosition->y};

    drawPos.x -= kDecimalGlyphAdvance;
    DispatchGlyphSpriteFromTable(
        kGlyphSlot, kDecimalLeadingGlyph, &drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);

    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nGlyph = aDigits[i] + kDecimalDigitBank;
        drawPos.x -= kDecimalGlyphAdvance;
        DispatchGlyphSpriteFromTable(kGlyphSlot, nGlyph, &drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
        // The dot glyph is tucked in after the ones digit.
        if (i == 0) {
            drawPos.x -= kDecimalDotAdvance;
            DispatchGlyphSpriteFromTable(
                kGlyphSlot, kDecimalDotGlyph, &drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
        }
    }
}

/** @ghidraAddress 0x115f4c */
void ResultWindowClassicLayer::RenderNumberFieldWithPad(int nValue,
                                                        int nDigitCount,
                                                        const S_VECTOR2 &position,
                                                        const S_VECTOR2 &offset,
                                                        unsigned int nGlyphBase,
                                                        bool bLeadingZero,
                                                        bool bPadRight,
                                                        unsigned int nAlpha,
                                                        float flSpacing) {
    constexpr unsigned int kGlyphSlot = 1;

    // Split the value into up to nDigitCount digits, tracking the most-significant non-zero digit.
    int aDigits[kMaxDigitCount] = {};
    int nMostSignificant = 0;
    for (int i = 0; i < nDigitCount; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nMostSignificant = i;
        }
        nValue /= 10;
    }
    if (nMostSignificant == 0 && bLeadingZero) {
        nMostSignificant = 1;
    }

    // The run starts at the base position shifted by the offset.
    S_VECTOR2 drawPos{position.x, position.y};
    S_VECTOR2 offsetCopy{offset.x, offset.y};
    AddVector2(&drawPos, &offsetCopy);

    const unsigned int nPairedGlyph = nGlyphBase + 0xa;
    for (int i = 0; i <= nMostSignificant; ++i) {
        const unsigned int nGlyph = aDigits[i] + nGlyphBase;
        const float flGlyphWidth = getPartsData_Phone(static_cast<int>(nGlyph))->flWidth;
        drawPos.x -= flGlyphWidth;
        DispatchGlyphSpriteFromTable(kGlyphSlot, nGlyph, &drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
        drawPos.x -= flSpacing;
        // The first glyph draws a paired glyph ten codes up when the leading-zero flag is set.
        if (i == 0 && bLeadingZero) {
            const float flPairedWidth = getPartsData_Phone(static_cast<int>(nPairedGlyph))->flWidth;
            drawPos.x -= flPairedWidth;
            DispatchGlyphSpriteFromTable(
                kGlyphSlot, nPairedGlyph, &drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
            drawPos.x -= flSpacing;
        }
    }

    // Pad the remaining leading positions with dimmed glyphs.
    if (bPadRight && nMostSignificant + 1 < nDigitCount) {
        for (int nRemaining = (nDigitCount - 1) - nMostSignificant; nRemaining != 0; --nRemaining) {
            const float flGlyphWidth = getPartsData_Phone(static_cast<int>(nGlyphBase))->flWidth;
            drawPos.x -= flGlyphWidth;
            DispatchGlyphSpriteFromTable(
                kGlyphSlot, nGlyphBase, &drawPos, nAlpha, 1, 0.0f, 1.0f, 1.0f);
            drawPos.x -= flSpacing;
        }
    }
}

/** @ghidraAddress 0x115d7c */
void ResultWindowClassicLayer::RenderScorePaddedWithDot(int nValue,
                                                        const S_VECTOR2 &position,
                                                        unsigned int nAlpha) {
    constexpr unsigned int kGlyphSlot = 1;

    // Split the value into up to four digits, showing at least two.
    int aDigits[kCompactMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kCompactMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant < kPaddedMinDigits) {
        nSignificant = kPaddedMinDigits;
    }

    // Emit each digit right to left from the position, inserting the dot after the ones digit.
    float flX = position.x;
    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nPart = aDigits[i] + kCompactDigitBank;
        const float flGlyphWidth = getPartsData(static_cast<int>(nPart))->flWidth;
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kGlyphSlot,
                       nPart,
                       S_VECTOR2{flX - flGlyphWidth, position.y},
                       nAlpha,
                       0);
        flX -= flGlyphWidth;
        if (i == 0) {
            const float flDotWidth = getPartsData(static_cast<int>(kPaddedDotPart))->flWidth;
            EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kGlyphSlot,
                           kPaddedDotPart,
                           S_VECTOR2{flX - flDotWidth, position.y},
                           nAlpha,
                           0);
            flX -= flDotWidth;
        }
    }
}

/** @ghidraAddress 0x115928 */
void ResultWindowClassicLayer::RenderScoreDigitsCompact(int nValue,
                                                        const S_VECTOR2 &position,
                                                        unsigned int nAlpha) {
    constexpr unsigned int kGlyphSlot = 1;

    // Split the value into up to four digits, tracking the significant count (at least one).
    int aDigits[kCompactMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kCompactMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant == 0) {
        nSignificant = 1;
    }

    // Centre the run about the position using the zero glyph's width as the nominal advance.
    const float flAdvance = getPartsData(static_cast<int>(kCompactDigitBank))->flWidth;
    float flX = position.x + static_cast<float>(static_cast<int>(nSignificant * flAdvance)) * 0.5f;
    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nPart = aDigits[i] + kCompactDigitBank;
        const float flGlyphWidth = getPartsData(static_cast<int>(nPart))->flWidth;
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kGlyphSlot,
                       nPart,
                       S_VECTOR2{flX - flGlyphWidth, position.y},
                       nAlpha,
                       0);
        flX -= flGlyphWidth;
    }
}

/** @ghidraAddress 0x11524c */
void ResultWindowClassicLayer::InitSpriteSetsLazy() {
    if (m_bSpritesBuilt) {
        return;
    }

    m_nDefaultAlpha = kDefaultAlpha;
    m_flDefaultScale = kDefaultScale;

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pBackgroundTexture, m_pPartsTexture};

    // Build one sprite instancer per slot, register it in the global scene tree, make it visible,
    // and clear its sprite count. The two edge slots bind a texture per the selector; the middle
    // slots (2 through 6) share the atlas of the batch they mirror, so they bind none here. During
    // the first slot's setup, initialise the four ribbon trails.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot] = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        m_apSprites[nSlot]->RegisterGlobal();
        m_apSprites[nSlot]->SetVisible(true);
        if (static_cast<unsigned int>(nSlot - kFirstUntexturedSlot) >= kUntexturedSlotSpan) {
            m_apSprites[nSlot]->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        }
        m_apSprites[nSlot]->SetSpriteCount(0);
        if (nSlot == 0) {
            for (int nTrail = 0; nTrail < kTrailCount; ++nTrail) {
                m_apTrails[nTrail]->Init();
            }
        }
    }

    m_bSpritesBuilt = true;
}

/** @ghidraAddress 0x1170c0 */
void ResultWindowClassicLayer::ResetResultScoreAnimations(float flStartTime) {
    // Each channel eases from its current shown value toward zero over the start time; a non-positive
    // start time snaps the target to zero immediately.
    for (ResultBonusAnimChannel &channel : m_aScoreAnimChannels) {
        channel.flStart = channel.flCurrent;
        channel.flTarget = 0.0f;
        channel.flDuration = flStartTime;
        channel.flElapsed = 0.0f;
        channel.flReserved = 0.0f;
        if (flStartTime <= 0.0f) {
            channel.flCurrent = 0.0f;
        }
    }

    // Reset the four ribbon trails, then clear the score-animation active flag.
    for (Polygon2dTrail *pTrail : m_apTrails) {
        pTrail->Reset();
    }
    m_bScoreAnimActive = false;
}

// The score-animation channel indices, their fixed effect-channel durations, and the per-channel
// stagger delays past the base start time.
namespace {
constexpr int kScoreChannel = 0;
constexpr int kEffectChannelA = 1;
constexpr int kEffectChannelB = 2;
constexpr int kEffectChannelC = 3;
constexpr int kEffectChannelD = 4;
constexpr float kScoreAnimShownTarget = 1.0f;
constexpr float kEffectDurationShort = 200.0f;
constexpr float kEffectDurationLong = 300.0f;
constexpr float kEffectDelayA = 150.0f;  // @ghidraAddress 0x2eedcc
constexpr float kEffectDelayC = 2600.0f; // @ghidraAddress 0x302d54
constexpr float kEffectDelayD = 2900.0f; // @ghidraAddress 0x302d58
constexpr int kTrailDuration = 500;
} // namespace

/** @ghidraAddress 0x116f90 */
void ResultWindowClassicLayer::StartResultScoreAnimations(float flStartTime) {
    // The score channel eases from its current shown value to one over the base start time; a
    // non-positive time snaps it to the final value immediately.
    ResultBonusAnimChannel &scoreChannel = m_aScoreAnimChannels[kScoreChannel];
    scoreChannel.flStart = scoreChannel.flCurrent;
    scoreChannel.flTarget = kScoreAnimShownTarget;
    scoreChannel.flDuration = flStartTime;
    scoreChannel.flElapsed = 0.0f;
    scoreChannel.flReserved = 0.0f;
    if (flStartTime <= 0.0f) {
        scoreChannel.flCurrent = kScoreAnimShownTarget;
    }

    // The first ribbon-trail pair starts at the base time.
    m_apTrails[0]->Start(kTrailDuration, static_cast<int>(flStartTime));
    m_apTrails[1]->Start(kTrailDuration, static_cast<int>(flStartTime));

    // Each effect channel eases from its current value to one over a fixed duration, its start
    // staggered past the base time by holding the delay in the elapsed slot.
    ResultBonusAnimChannel &effectB = m_aScoreAnimChannels[kEffectChannelB];
    effectB.flStart = effectB.flCurrent;
    effectB.flTarget = kScoreAnimShownTarget;
    effectB.flDuration = kEffectDurationShort;
    effectB.flElapsed = flStartTime;
    effectB.flReserved = 0.0f;

    ResultBonusAnimChannel &effectA = m_aScoreAnimChannels[kEffectChannelA];
    effectA.flStart = effectA.flCurrent;
    effectA.flTarget = kScoreAnimShownTarget;
    effectA.flDuration = kEffectDurationLong;
    effectA.flElapsed = flStartTime + kEffectDelayA;
    effectA.flReserved = 0.0f;

    // The second ribbon-trail pair is delayed past the base time.
    const int nDelayedTrailStart = static_cast<int>(flStartTime + kEffectDelayC);
    m_apTrails[2]->Start(kTrailDuration, nDelayedTrailStart);
    m_apTrails[3]->Start(kTrailDuration, nDelayedTrailStart);

    ResultBonusAnimChannel &effectD = m_aScoreAnimChannels[kEffectChannelD];
    effectD.flStart = effectD.flCurrent;
    effectD.flTarget = kScoreAnimShownTarget;
    effectD.flDuration = kEffectDurationShort;
    effectD.flElapsed = flStartTime + kEffectDelayC;
    effectD.flReserved = 0.0f;

    ResultBonusAnimChannel &effectC = m_aScoreAnimChannels[kEffectChannelC];
    effectC.flStart = effectC.flCurrent;
    effectC.flTarget = kScoreAnimShownTarget;
    effectC.flDuration = kEffectDurationLong;
    effectC.flElapsed = flStartTime + kEffectDelayD;
    effectC.flReserved = 0.0f;

    // Reset the reveal sound-effect handle to "none".
    m_nRevealSeHandle = -1;
}

/** @ghidraAddress 0x11541c */
void ResultWindowClassicLayer::ResetScoreDisplayState() {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    // A single-player game type (0 or 2) is offline; every other type is a networked play.
    m_nNetworkPlay = (pGameSystem->GetGameType() | 2) == 2 ? 0 : 1;

    // Clear the per-round display counters and reset every music-track index sentinel to -1.
    m_nDisplayCounterA = 0;
    m_flExpAnimTimer = 0.0f;
    m_bExpAnimSettled = false;
    m_bCustomizePending = false;
    m_flPhoneOverlayTimer = 0.0f;
    m_nMainAssetId = -1;
    m_nTrackIndexC = -1;
    m_bCustomizePreviewShown = false;
    m_flNameplateTimer = 0.0f;
    m_nCustomizeCharacterId = -1;
    m_nCustomizePendingId = -1;
    m_nRevealSeHandle = -1;

    // Copy the player level and experience from the game system and resolve the level-up threshold.
    const int nLevel = pGameSystem->GetPlayerLevel();
    m_nPlayerLevel = nLevel;
    m_nPlayerExp = pGameSystem->GetPlayerExp();
    const unsigned int nThreshold = LevelTables::GetLevelExpThreshold(nLevel);
    m_nExpThreshold = static_cast<int>(nThreshold);
    m_nLevelUpStep = 0;
    if (static_cast<int>(nThreshold) < 0) {
        // The level cap has no threshold; no experience is gained toward the next level, and the
        // main customize asset is not shown.
        m_bMainAssetActive = false;
    } else {
        m_nGainedExp = pGameSystem->GetGainedExp();
    }

    // When no customize swap is pending, kick off the main-asset load; otherwise consume the pending
    // flag and seed the resolved track index from the player level.
    if (!m_bCustomizePending) {
        BeginCustomizeMainAsset(static_cast<unsigned int>(m_nPlayerLevel));
    } else {
        m_bCustomizePending = false;
        m_nTrackIndexC = m_nPlayerLevel;
    }

    // Arm the score/gesture-active flag from the result-bonus feature, reset the hold timer, and
    // record whether the Twitter share API is available.
    m_bScoreAnimActive = pGameSystem->IsNewRecord();
    m_flGestureHoldTimer = 0.0f;
    m_bTwitterAvailable = [RBViewController hasTwitterAPI];
}

/** @ghidraAddress 0x11738c */
void ResultWindowClassicLayer::UpdateGestureHoldTimer(float flDeltaTime) {
    if (!m_bScoreAnimActive) {
        return;
    }
    m_flGestureHoldTimer += flDeltaTime;
    if (m_flGestureHoldTimer > kGestureHoldTimeout) {
        m_bScoreAnimActive = false;
        SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kGestureReleaseVoiceId);
    }
}

namespace {
// The Update timers' constants.
// The positive slide-timer divisor (the timer counts toward zero) (@ghidraAddress 0x2fd050 = -300).
constexpr float kSlideTimerRateDown = -300.0f;
// The negative slide-timer divisor (@ghidraAddress 0x2eedcc = 300).
constexpr float kSlideTimerRateUp = 300.0f;
// The two decoration rotation counters' wrap periods.
constexpr int kRotationWrapA = 400;
constexpr int kRotationWrapB = 0xc0;
// The frames per decoration animation index (@ghidraAddress 0x2fcff8 = 48).
constexpr float kRotationFramesPerIndex = 48.0f;
// The last decoration animation frame index.
constexpr int kRotationFrameMax = 3;

// The five score channels' advance order the update uses (channels 2 and 3 are advanced swapped).
constexpr int kScoreAdvanceOrder[] = {0, 1, 3, 2, 4};
} // namespace

/** @ghidraAddress 0x11c1bc */
void ResultWindowClassicLayer::Update(float flDeltaTime) {
    // Off an iPad, keep the portrait-orientation flag in sync with the viewport aspect.
    if (!IsPad()) {
        const float flWidth = GameSystem::GetGameSystem()->GetViewportWidth();
        const bool bPortrait = flWidth <= GameSystem::GetGameSystem()->GetViewportHeight();
        if (bPortrait != m_bPortrait) {
            m_bPortrait = bPortrait;
        }
    }

    // Advance the five score/effect channels. Each shares FloatTween's six-float layout and the
    // binary drives it through FloatTween::Advance, so advance each through that view.
    for (int nChannel : kScoreAdvanceOrder) {
        reinterpret_cast<FloatTween *>(&m_aScoreAnimChannels[nChannel])->Advance(flDeltaTime);
    }

    // Advance the signed slide/settle timer toward zero, at differing rates by sign, clamping on the
    // zero crossing.
    if (m_flSlideTimer > 0.0f) {
        m_flSlideTimer += flDeltaTime / kSlideTimerRateDown;
        if (m_flSlideTimer < 0.0f) {
            m_flSlideTimer = 0.0f;
        }
    } else if (m_flSlideTimer < 0.0f) {
        m_flSlideTimer += flDeltaTime / kSlideTimerRateUp;
        if (m_flSlideTimer > 0.0f) {
            m_flSlideTimer = 0.0f;
        }
    }

    // The four ribbon trails: advance them on an iPad, hide their meshes otherwise.
    if (IsPad()) {
        const int nDelta = static_cast<int>(flDeltaTime);
        for (Polygon2dTrail *pTrail : m_apTrails) {
            pTrail->Update(nDelta);
        }
    } else {
        for (Polygon2dTrail *pTrail : m_apTrails) {
            pTrail->HideMesh();
        }
    }

    // Advance the two decoration rotation counters (the first wraps every 400 frames, the second
    // every 192) and derive the second's animation frame index.
    m_nRotationCounterA =
        static_cast<int>(static_cast<float>(m_nRotationCounterA) + flDeltaTime) % kRotationWrapA;
    int nCounterB = static_cast<int>(static_cast<float>(m_nRotationCounterB) + flDeltaTime);
    if (nCounterB > kRotationWrapB) {
        nCounterB %= kRotationWrapB;
    }
    m_nRotationCounterB = nCounterB;
    int nFrame = static_cast<int>(static_cast<float>(nCounterB) / kRotationFramesPerIndex);
    if (nFrame < 0) {
        nFrame = 0;
    }
    if (nFrame > kRotationFrameMax) {
        nFrame = kRotationFrameMax;
    }
    m_nRotationFrame = nFrame;

    UpdateGestureHoldTimer(flDeltaTime);
    UpdateTouchAndPostTwitterShare();

    // Dispatch to the iPad or phone render path.
    if (IsPad()) {
        RenderResultScoreLayerActive(flDeltaTime);
    } else {
        RenderResultScoreLayerIdle(flDeltaTime);
    }
}

/** @ghidraAddress 0x11c9b8 */
void InitializeResultLayoutTable() {
    // The binary wraps the whole fill in an autorelease pool, then writes every field of the
    // result-screen layout tables inline. Only the play-field height below is not a constant.
    @autoreleasepool {
        g_aClassicPartsPad[0].nEnabled = 1;
        g_aClassicPartsPad[0].flX = 0.0f;
        g_aClassicPartsPad[0].flWidth = 768.0f;
        g_aClassicPartsPad[0].flHeight = static_cast<float>(g_nPlayfieldFieldHeight);
        g_aClassicPartsPad[0].nUvPaletteIndex = 0;
        g_aClassicPartsPad[1].nEnabled = 1;
        g_aClassicPartsPad[1].flX = 0.0f;
        g_aClassicPartsPad[1].flY = 0.0f;
        g_aClassicPartsPad[1].nUvPaletteIndex = 1;
        g_aClassicPartsPad[2].nEnabled = 1;
        g_aClassicPartsPad[2].flX = 0.0f;
        g_aClassicPartsPad[2].flY = 0.0f;
        g_aClassicPartsPad[2].flWidth = 92.0f;
        g_aClassicPartsPad[2].flHeight = 38.0f;
        g_aClassicPartsPad[2].nUvPaletteIndex = 2;
        g_aClassicPartsPad[3].nEnabled = 1;
        g_aClassicPartsPad[3].flX = 0.0f;
        g_aClassicPartsPad[3].flY = 0.0f;
        g_aClassicPartsPad[3].flWidth = 268.0f;
        g_aClassicPartsPad[3].flHeight = 56.0f;
        g_aClassicPartsPad[3].nUvPaletteIndex = 3;
        g_aClassicPartsPad[4].nEnabled = 1;
        g_aClassicPartsPad[4].nUvPaletteIndex = 4;
        g_aClassicPartsPad[5].nEnabled = 1;
        g_aClassicPartsPad[5].flX = 0.0f;
        g_aClassicPartsPad[5].flY = 0.0f;
        g_aClassicPartsPad[5].flWidth = 268.0f;
        g_aClassicPartsPad[5].flHeight = 198.0f;
        g_aClassicPartsPad[5].nUvPaletteIndex = 5;
        g_aClassicPartsPad[6].nEnabled = 1;
        g_aClassicPartsPad[6].flX = 0.0f;
        g_aClassicPartsPad[6].flY = 0.0f;
        g_aClassicPartsPad[6].flWidth = 268.0f;
        g_aClassicPartsPad[6].flHeight = 198.0f;
        g_aClassicPartsPad[6].nUvPaletteIndex = 6;
        g_aClassicPartsPad[7].nEnabled = 1;
        g_aClassicPartsPad[7].flX = 0.0f;
        g_aClassicPartsPad[7].flY = 0.0f;
        g_aClassicPartsPad[7].flWidth = 268.0f;
        g_aClassicPartsPad[7].flHeight = 14.0f;
        g_aClassicPartsPad[7].nUvPaletteIndex = 7;
        g_aClassicPartsPad[8].nEnabled = 1;
        g_aClassicPartsPad[8].nUvPaletteIndex = 8;
        g_aClassicPartsPad[9].nEnabled = 1;
        g_aClassicPartsPad[9].flX = 0.0f;
        g_aClassicPartsPad[9].flY = 0.0f;
        g_aClassicPartsPad[9].flWidth = 4e+01f;
        g_aClassicPartsPad[9].flHeight = 56.0f;
        g_aClassicPartsPad[9].nUvPaletteIndex = 9;
        g_aClassicPartsPad[10].nEnabled = 1;
        g_aClassicPartsPad[10].flX = 0.0f;
        g_aClassicPartsPad[10].flY = 0.0f;
        g_aClassicPartsPad[10].flWidth = 329.0f;
        g_aClassicPartsPad[10].flHeight = 56.0f;
        g_aClassicPartsPad[10].nUvPaletteIndex = 10;
        g_aClassicPartsPad[11].nEnabled = 1;
        g_aClassicPartsPad[11].nUvPaletteIndex = 11;
        g_aClassicPartsPad[12].nEnabled = 1;
        g_aClassicPartsPad[12].nUvPaletteIndex = 12;
        g_aClassicPartsPad[13].nEnabled = 1;
        g_aClassicPartsPad[13].flX = 0.0f;
        g_aClassicPartsPad[13].flY = 0.0f;
        g_aClassicPartsPad[13].flWidth = 268.0f;
        g_aClassicPartsPad[13].flHeight = 56.0f;
        g_aClassicPartsPad[13].nUvPaletteIndex = 13;
        g_aClassicPartsPad[14].nEnabled = 1;
        g_aClassicPartsPad[14].flX = 0.0f;
        g_aClassicPartsPad[14].flY = 0.0f;
        g_aClassicPartsPad[14].flWidth = 268.0f;
        g_aClassicPartsPad[14].flHeight = 464.0f;
        g_aClassicPartsPad[14].nUvPaletteIndex = 14;
        g_aClassicPartsPad[15].nEnabled = 1;
        g_aClassicPartsPad[15].nUvPaletteIndex = 15;
        g_aClassicPartsPad[16].nEnabled = 1;
        g_aClassicPartsPad[16].nUvPaletteIndex = 16;
        g_aClassicPartsPad[17].nEnabled = 1;
        g_aClassicPartsPad[17].nUvPaletteIndex = 17;
        g_aClassicPartsPad[18].nEnabled = 1;
        g_aClassicPartsPad[18].flX = 0.0f;
        g_aClassicPartsPad[18].flY = 0.0f;
        g_aClassicPartsPad[18].flWidth = 4e+01f;
        g_aClassicPartsPad[18].flHeight = 56.0f;
        g_aClassicPartsPad[18].nUvPaletteIndex = 18;
        g_aClassicPartsPad[19].nEnabled = 1;
        g_aClassicPartsPad[19].flX = 0.0f;
        g_aClassicPartsPad[19].flY = 0.0f;
        g_aClassicPartsPad[19].flWidth = 329.0f;
        g_aClassicPartsPad[19].flHeight = 56.0f;
        g_aClassicPartsPad[19].nUvPaletteIndex = 19;
        g_aClassicPartsPad[20].nEnabled = 1;
        g_aClassicPartsPad[20].nUvPaletteIndex = 20;
        g_aClassicPartsPad[21].nEnabled = 1;
        g_aClassicPartsPad[21].flX = 0.0f;
        g_aClassicPartsPad[21].flY = 0.0f;
        g_aClassicPartsPad[21].flWidth = 6.0f;
        g_aClassicPartsPad[21].flHeight = 6.0f;
        g_aClassicPartsPad[21].nUvPaletteIndex = 21;
        g_aClassicPartsPad[22].nEnabled = 1;
        g_aClassicPartsPad[22].nUvPaletteIndex = 22;
        g_aClassicPartsPad[23].nEnabled = 1;
        g_aClassicPartsPad[23].nUvPaletteIndex = 23;
        g_aClassicPartsPad[24].nEnabled = 1;
        g_aClassicPartsPad[24].nUvPaletteIndex = 24;
        g_aClassicPartsPad[25].nEnabled = 1;
        g_aClassicPartsPad[25].flX = 0.0f;
        g_aClassicPartsPad[25].flY = 0.0f;
        g_aClassicPartsPad[25].flWidth = 504.0f;
        g_aClassicPartsPad[25].flHeight = 3e+01f;
        g_aClassicPartsPad[25].nUvPaletteIndex = 25;
        g_aClassicPartsPad[26].nEnabled = 1;
        g_aClassicPartsPad[26].flX = 0.0f;
        g_aClassicPartsPad[26].flY = 0.0f;
        g_aClassicPartsPad[26].flWidth = 504.0f;
        g_aClassicPartsPad[26].flHeight = 254.0f;
        g_aClassicPartsPad[26].nUvPaletteIndex = 26;
        g_aClassicPartsPad[27].nEnabled = 1;
        g_aClassicPartsPad[27].flX = 0.0f;
        g_aClassicPartsPad[27].flY = 0.0f;
        g_aClassicPartsPad[27].flWidth = 504.0f;
        g_aClassicPartsPad[27].flHeight = 12.0f;
        g_aClassicPartsPad[27].nUvPaletteIndex = 27;
        g_aClassicPartsPad[28].nEnabled = 1;
        g_aClassicPartsPad[28].nUvPaletteIndex = 28;
        g_aClassicPartsPad[29].nEnabled = 1;
        g_aClassicPartsPad[29].flX = 0.0f;
        g_aClassicPartsPad[29].flY = 0.0f;
        g_aClassicPartsPad[29].flWidth = 504.0f;
        g_aClassicPartsPad[29].flHeight = 82.0f;
        g_aClassicPartsPad[29].nUvPaletteIndex = 29;
        g_aClassicPartsPad[30].nEnabled = 1;
        g_aClassicPartsPad[30].nUvPaletteIndex = 30;
        g_aClassicPartsPad[31].nEnabled = 1;
        g_aClassicPartsPad[31].nUvPaletteIndex = 31;
        g_aClassicPartsPad[32].nEnabled = 1;
        g_aClassicPartsPad[32].flX = 0.0f;
        g_aClassicPartsPad[32].flY = 0.0f;
        g_aClassicPartsPad[32].flWidth = 504.0f;
        g_aClassicPartsPad[32].flHeight = 107.0f;
        g_aClassicPartsPad[32].nUvPaletteIndex = 32;
        g_aClassicPartsPad[33].nEnabled = 1;
        g_aClassicPartsPad[33].nUvPaletteIndex = 33;
        g_aClassicPartsPad[34].nEnabled = 1;
        g_aClassicPartsPad[34].flX = 0.0f;
        g_aClassicPartsPad[34].flY = 0.0f;
        g_aClassicPartsPad[34].flWidth = 504.0f;
        g_aClassicPartsPad[34].flHeight = 3e+01f;
        g_aClassicPartsPad[34].nUvPaletteIndex = 34;
        g_aClassicPartsPad[35].nEnabled = 1;
        g_aClassicPartsPad[35].nUvPaletteIndex = 35;
        g_aClassicPartsPad[36].nEnabled = 1;
        g_aClassicPartsPad[36].nUvPaletteIndex = 36;
        g_aClassicPartsPad[37].nEnabled = 1;
        g_aClassicPartsPad[37].flX = 0.0f;
        g_aClassicPartsPad[37].flY = 0.0f;
        g_aClassicPartsPad[37].flWidth = 38.0f;
        g_aClassicPartsPad[37].flHeight = 12.0f;
        g_aClassicPartsPad[37].nUvPaletteIndex = 37;
        g_aClassicPartsPad[38].nEnabled = 1;
        g_aClassicPartsPad[38].flX = 0.0f;
        g_aClassicPartsPad[38].flY = 0.0f;
        g_aClassicPartsPad[38].flWidth = 38.0f;
        g_aClassicPartsPad[38].flHeight = 12.0f;
        g_aClassicPartsPad[38].nUvPaletteIndex = 38;
        g_aClassicPartsPad[39].nEnabled = 1;
        g_aClassicPartsPad[39].nUvPaletteIndex = 39;
        g_aClassicPartsPad[40].nEnabled = 1;
        g_aClassicPartsPad[40].nUvPaletteIndex = 40;
        g_aClassicPartsPad[41].nEnabled = 1;
        g_aClassicPartsPad[41].flX = 0.0f;
        g_aClassicPartsPad[41].flY = 0.0f;
        g_aClassicPartsPad[41].flWidth = 504.0f;
        g_aClassicPartsPad[41].flHeight = 186.0f;
        g_aClassicPartsPad[41].nUvPaletteIndex = 41;
        g_aClassicPartsPad[42].nEnabled = 1;
        g_aClassicPartsPad[42].flX = 0.0f;
        g_aClassicPartsPad[42].flY = 0.0f;
        g_aClassicPartsPad[42].flWidth = 4e+01f;
        g_aClassicPartsPad[42].flHeight = 1e+01f;
        g_aClassicPartsPad[42].nUvPaletteIndex = 42;
        g_aClassicPartsPad[43].nEnabled = 1;
        g_aClassicPartsPad[43].flX = 0.0f;
        g_aClassicPartsPad[43].flY = 0.0f;
        g_aClassicPartsPad[43].flWidth = 5e+01f;
        g_aClassicPartsPad[43].flHeight = 1e+01f;
        g_aClassicPartsPad[43].nUvPaletteIndex = 43;
        g_aClassicPartsPad[44].nEnabled = 1;
        g_aClassicPartsPad[44].flX = 0.0f;
        g_aClassicPartsPad[44].flY = 0.0f;
        g_aClassicPartsPad[44].flWidth = 38.0f;
        g_aClassicPartsPad[44].flHeight = 1e+01f;
        g_aClassicPartsPad[44].nUvPaletteIndex = 44;
        g_aClassicPartsPad[45].nEnabled = 1;
        g_aClassicPartsPad[45].flX = 0.0f;
        g_aClassicPartsPad[45].flY = 0.0f;
        g_aClassicPartsPad[45].flWidth = 5e+01f;
        g_aClassicPartsPad[45].flHeight = 1e+01f;
        g_aClassicPartsPad[45].nUvPaletteIndex = 45;
        g_aClassicPartsPad[46].nEnabled = 1;
        g_aClassicPartsPad[46].flX = 0.0f;
        g_aClassicPartsPad[46].flY = 0.0f;
        g_aClassicPartsPad[46].flWidth = 6.0f;
        g_aClassicPartsPad[46].flHeight = 8.0f;
        g_aClassicPartsPad[46].nUvPaletteIndex = 46;
        g_aClassicPartsPad[47].nEnabled = 1;
        g_aClassicPartsPad[47].nUvPaletteIndex = 47;
        g_aClassicPartsPad[48].nEnabled = 1;
        g_aClassicPartsPad[48].nUvPaletteIndex = 48;
        g_aClassicPartsPad[49].nEnabled = 1;
        g_aClassicPartsPad[49].nUvPaletteIndex = 49;
        g_aClassicPartsPad[50].nEnabled = 1;
        g_aClassicPartsPad[50].flX = 0.0f;
        g_aClassicPartsPad[50].flY = 0.0f;
        g_aClassicPartsPad[50].flWidth = 6.0f;
        g_aClassicPartsPad[50].flHeight = 8.0f;
        g_aClassicPartsPad[50].nUvPaletteIndex = 50;
        g_aClassicPartsPad[51].nEnabled = 1;
        g_aClassicPartsPad[51].nUvPaletteIndex = 51;
        g_aClassicPartsPad[52].nEnabled = 1;
        g_aClassicPartsPad[52].nUvPaletteIndex = 52;
        g_aClassicPartsPad[53].nEnabled = 1;
        g_aClassicPartsPad[53].flX = 0.0f;
        g_aClassicPartsPad[53].flY = 0.0f;
        g_aClassicPartsPad[53].flWidth = 6.0f;
        g_aClassicPartsPad[53].flHeight = 8.0f;
        g_aClassicPartsPad[53].nUvPaletteIndex = 53;
        g_aClassicPartsPad[54].nEnabled = 1;
        g_aClassicPartsPad[54].nUvPaletteIndex = 54;
        g_aClassicPartsPad[55].nEnabled = 1;
        g_aClassicPartsPad[55].nUvPaletteIndex = 55;
        g_aClassicPartsPad[56].nEnabled = 1;
        g_aClassicPartsPad[56].flX = 0.0f;
        g_aClassicPartsPad[56].flY = 0.0f;
        g_aClassicPartsPad[56].flWidth = 1e+01f;
        g_aClassicPartsPad[56].flHeight = 8.0f;
        g_aClassicPartsPad[56].nUvPaletteIndex = 56;
        g_aClassicPartsPad[57].nEnabled = 1;
        g_aClassicPartsPad[57].nUvPaletteIndex = 57;
        g_aClassicPartsPad[58].nEnabled = 1;
        g_aClassicPartsPad[58].flX = 0.0f;
        g_aClassicPartsPad[58].flY = 0.0f;
        g_aClassicPartsPad[58].flWidth = 1e+01f;
        g_aClassicPartsPad[58].flHeight = 8.0f;
        g_aClassicPartsPad[58].nUvPaletteIndex = 58;
        g_aClassicPartsPad[59].nEnabled = 1;
        g_aClassicPartsPad[59].nUvPaletteIndex = 59;
        g_aClassicPartsPad[60].nEnabled = 1;
        g_aClassicPartsPad[60].nUvPaletteIndex = 60;
        g_aClassicPartsPad[61].nEnabled = 1;
        g_aClassicPartsPad[61].flX = 0.0f;
        g_aClassicPartsPad[61].flY = 0.0f;
        g_aClassicPartsPad[61].flWidth = 1e+01f;
        g_aClassicPartsPad[61].flHeight = 8.0f;
        g_aClassicPartsPad[61].nUvPaletteIndex = 61;
        g_aClassicPartsPad[62].nEnabled = 1;
        g_aClassicPartsPad[62].nUvPaletteIndex = 62;
        g_aClassicPartsPad[63].nEnabled = 1;
        g_aClassicPartsPad[63].nUvPaletteIndex = 63;
        g_aClassicPartsPad[64].nEnabled = 1;
        g_aClassicPartsPad[64].nUvPaletteIndex = 64;
        g_aClassicPartsPad[65].nEnabled = 1;
        g_aClassicPartsPad[65].nUvPaletteIndex = 65;
        g_aClassicPartsPad[66].nEnabled = 1;
        g_aClassicPartsPad[66].flX = 0.0f;
        g_aClassicPartsPad[66].flY = 0.0f;
        g_aClassicPartsPad[66].flWidth = 6.0f;
        g_aClassicPartsPad[66].flHeight = 8.0f;
        g_aClassicPartsPad[66].nUvPaletteIndex = 66;
        g_aClassicPartsPad[67].nEnabled = 1;
        g_aClassicPartsPad[67].nUvPaletteIndex = 67;
        g_aClassicPartsPad[68].nEnabled = 1;
        g_aClassicPartsPad[68].nUvPaletteIndex = 68;
        g_aClassicPartsPad[69].nEnabled = 1;
        g_aClassicPartsPad[69].flX = 0.0f;
        g_aClassicPartsPad[69].flY = 0.0f;
        g_aClassicPartsPad[69].flWidth = 6.0f;
        g_aClassicPartsPad[69].flHeight = 8.0f;
        g_aClassicPartsPad[69].nUvPaletteIndex = 69;
        g_aClassicPartsPad[70].nEnabled = 1;
        g_aClassicPartsPad[70].nUvPaletteIndex = 70;
        g_aClassicPartsPad[71].nEnabled = 1;
        g_aClassicPartsPad[71].nUvPaletteIndex = 71;
        g_aClassicPartsPad[72].nEnabled = 1;
        g_aClassicPartsPad[72].flX = 0.0f;
        g_aClassicPartsPad[72].flY = 0.0f;
        g_aClassicPartsPad[72].flWidth = 2.0f;
        g_aClassicPartsPad[72].flHeight = 8.0f;
        g_aClassicPartsPad[72].nUvPaletteIndex = 72;
        g_aClassicPartsPad[73].nEnabled = 1;
        g_aClassicPartsPad[73].nUvPaletteIndex = 73;
        g_aClassicPartsPad[74].nEnabled = 1;
        g_aClassicPartsPad[74].flX = 0.0f;
        g_aClassicPartsPad[74].flY = 0.0f;
        g_aClassicPartsPad[74].flWidth = 6.0f;
        g_aClassicPartsPad[74].flHeight = 8.0f;
        g_aClassicPartsPad[74].nUvPaletteIndex = 74;
        g_aClassicPartsPad[75].nEnabled = 1;
        g_aClassicPartsPad[75].flX = 0.0f;
        g_aClassicPartsPad[75].flY = 0.0f;
        g_aClassicPartsPad[75].flWidth = 1.0f;
        g_aClassicPartsPad[75].flHeight = 12.0f;
        g_aClassicPartsPad[75].nUvPaletteIndex = 75;
        g_aClassicPartsPad[76].nEnabled = 1;
        g_aClassicPartsPad[76].nUvPaletteIndex = 76;
        g_aClassicPartsPad[77].nEnabled = 1;
        g_aClassicPartsPad[77].flX = 0.0f;
        g_aClassicPartsPad[77].flY = 0.0f;
        g_aClassicPartsPad[77].flWidth = 16.0f;
        g_aClassicPartsPad[77].flHeight = 18.0f;
        g_aClassicPartsPad[77].nUvPaletteIndex = 77;
        g_aClassicPartsPad[78].nEnabled = 1;
        g_aClassicPartsPad[78].flX = 0.0f;
        g_aClassicPartsPad[78].flY = 0.0f;
        g_aClassicPartsPad[78].flWidth = 16.0f;
        g_aClassicPartsPad[78].flHeight = 18.0f;
        g_aClassicPartsPad[78].nUvPaletteIndex = 78;
        g_aClassicPartsPad[79].nEnabled = 1;
        g_aClassicPartsPad[79].nUvPaletteIndex = 79;
        g_aClassicPartsPad[80].nEnabled = 1;
        g_aClassicPartsPad[80].nUvPaletteIndex = 80;
        g_aClassicPartsPad[81].nEnabled = 1;
        g_aClassicPartsPad[81].nUvPaletteIndex = 81;
        g_aClassicPartsPad[82].nEnabled = 1;
        g_aClassicPartsPad[82].flX = 0.0f;
        g_aClassicPartsPad[82].flY = 0.0f;
        g_aClassicPartsPad[82].flWidth = 16.0f;
        g_aClassicPartsPad[82].flHeight = 18.0f;
        g_aClassicPartsPad[82].nUvPaletteIndex = 82;
        g_aClassicPartsPad[83].nEnabled = 1;
        g_aClassicPartsPad[83].nUvPaletteIndex = 83;
        g_aClassicPartsPad[84].nEnabled = 1;
        g_aClassicPartsPad[84].nUvPaletteIndex = 84;
        g_aClassicPartsPad[85].nEnabled = 1;
        g_aClassicPartsPad[85].flX = 0.0f;
        g_aClassicPartsPad[85].flY = 0.0f;
        g_aClassicPartsPad[85].flWidth = 16.0f;
        g_aClassicPartsPad[85].flHeight = 18.0f;
        g_aClassicPartsPad[85].nUvPaletteIndex = 85;
        g_aClassicPartsPad[86].nEnabled = 1;
        g_aClassicPartsPad[86].nUvPaletteIndex = 86;
        g_aClassicPartsPad[87].nEnabled = 1;
        g_aClassicPartsPad[87].nUvPaletteIndex = 87;
        g_aClassicPartsPad[88].nEnabled = 1;
        g_aClassicPartsPad[88].nUvPaletteIndex = 88;
        g_aClassicPartsPad[89].nEnabled = 1;
        g_aClassicPartsPad[89].nUvPaletteIndex = 89;
        g_aClassicPartsPad[90].nEnabled = 1;
        g_aClassicPartsPad[90].flX = 0.0f;
        g_aClassicPartsPad[90].flY = 0.0f;
        g_aClassicPartsPad[90].flWidth = 16.0f;
        g_aClassicPartsPad[90].flHeight = 18.0f;
        g_aClassicPartsPad[90].nUvPaletteIndex = 90;
        g_aClassicPartsPad[91].nEnabled = 1;
        g_aClassicPartsPad[91].nUvPaletteIndex = 91;
        g_aClassicPartsPad[92].nEnabled = 1;
        g_aClassicPartsPad[92].nUvPaletteIndex = 92;
        g_aClassicPartsPad[93].nEnabled = 1;
        g_aClassicPartsPad[93].flX = 0.0f;
        g_aClassicPartsPad[93].flY = 0.0f;
        g_aClassicPartsPad[93].flWidth = 16.0f;
        g_aClassicPartsPad[93].flHeight = 18.0f;
        g_aClassicPartsPad[93].nUvPaletteIndex = 93;
        g_aClassicPartsPad[94].nEnabled = 1;
        g_aClassicPartsPad[94].nUvPaletteIndex = 94;
        g_aClassicPartsPad[95].nEnabled = 1;
        g_aClassicPartsPad[95].nUvPaletteIndex = 95;
        g_aClassicPartsPad[96].nEnabled = 1;
        g_aClassicPartsPad[96].nUvPaletteIndex = 96;
        g_aClassicPartsPad[97].nEnabled = 1;
        g_aClassicPartsPad[97].flX = 22.0f;
        g_aClassicPartsPad[97].flY = 19.0f;
        g_aClassicPartsPad[97].flWidth = 44.0f;
        g_aClassicPartsPad[97].flHeight = 38.0f;
        g_aClassicPartsPad[97].nUvPaletteIndex = 97;
        g_aClassicPartsPad[98].nEnabled = 1;
        g_aClassicPartsPad[98].flX = 22.0f;
        g_aClassicPartsPad[98].flY = 19.0f;
        g_aClassicPartsPad[98].flWidth = 44.0f;
        g_aClassicPartsPad[98].flHeight = 38.0f;
        g_aClassicPartsPad[98].nUvPaletteIndex = 98;
        g_aClassicPartsPad[99].nEnabled = 1;
        g_aClassicPartsPad[99].nUvPaletteIndex = 99;
        g_aClassicPartsPad[100].nEnabled = 1;
        g_aClassicPartsPad[100].flX = 32.0f;
        g_aClassicPartsPad[100].flY = 19.0f;
        g_aClassicPartsPad[100].flWidth = 64.0f;
        g_aClassicPartsPad[100].flHeight = 38.0f;
        g_aClassicPartsPad[100].nUvPaletteIndex = 100;
        g_aClassicPartsPad[101].nEnabled = 1;
        g_aClassicPartsPad[101].flX = 32.0f;
        g_aClassicPartsPad[101].flY = 19.0f;
        g_aClassicPartsPad[101].flWidth = 64.0f;
        g_aClassicPartsPad[101].flHeight = 38.0f;
        g_aClassicPartsPad[101].nUvPaletteIndex = 101;
        g_aClassicPartsPad[102].nEnabled = 1;
        g_aClassicPartsPad[102].nUvPaletteIndex = 102;
        g_aClassicPartsPad[103].nEnabled = 1;
        g_aClassicPartsPad[103].flX = 36.0f;
        g_aClassicPartsPad[103].flY = 27.0f;
        g_aClassicPartsPad[103].flWidth = 72.0f;
        g_aClassicPartsPad[103].flHeight = 54.0f;
        g_aClassicPartsPad[103].nUvPaletteIndex = 103;
        g_aClassicPartsPad[104].nEnabled = 1;
        g_aClassicPartsPad[104].flX = 0.0f;
        g_aClassicPartsPad[104].flY = 0.0f;
        g_aClassicPartsPad[104].flWidth = 1.5e+02f;
        g_aClassicPartsPad[104].flHeight = 184.0f;
        g_aClassicPartsPad[104].nUvPaletteIndex = 104;
        g_aClassicPartsPad[105].nEnabled = 1;
        g_aClassicPartsPad[105].flX = 0.0f;
        g_aClassicPartsPad[105].flY = 0.0f;
        g_aClassicPartsPad[105].flWidth = 1.4e+02f;
        g_aClassicPartsPad[105].flHeight = 234.0f;
        g_aClassicPartsPad[105].nUvPaletteIndex = 105;
        g_aClassicPartsPad[106].nEnabled = 1;
        g_aClassicPartsPad[106].flX = 0.0f;
        g_aClassicPartsPad[106].flY = 0.0f;
        g_aClassicPartsPad[106].flWidth = 52.0f;
        g_aClassicPartsPad[106].flHeight = 18.0f;
        g_aClassicPartsPad[106].nUvPaletteIndex = 106;
        g_aClassicPartsPad[107].nEnabled = 1;
        g_aClassicPartsPad[107].flX = 0.0f;
        g_aClassicPartsPad[107].flY = 0.0f;
        g_aClassicPartsPad[107].flWidth = 52.0f;
        g_aClassicPartsPad[107].flHeight = 18.0f;
        g_aClassicPartsPad[107].nUvPaletteIndex = 107;
        g_aClassicPartsPad[108].nEnabled = 1;
        g_aClassicPartsPad[108].nUvPaletteIndex = 108;
        g_aClassicPartsPad[109].nEnabled = 1;
        g_aClassicPartsPad[109].flX = 0.0f;
        g_aClassicPartsPad[109].flY = 0.0f;
        g_aClassicPartsPad[109].flWidth = 52.0f;
        g_aClassicPartsPad[109].flHeight = 18.0f;
        g_aClassicPartsPad[109].nUvPaletteIndex = 109;
        g_aClassicPartsPad[110].nEnabled = 1;
        g_aClassicPartsPad[110].flX = 0.0f;
        g_aClassicPartsPad[110].flY = 0.0f;
        g_aClassicPartsPad[110].flWidth = 1.3e+02f;
        g_aClassicPartsPad[110].flHeight = 18.0f;
        g_aClassicPartsPad[110].nUvPaletteIndex = 110;
        g_aClassicPartsPad[111].nEnabled = 1;
        g_aClassicPartsPad[111].nUvPaletteIndex = 111;
        g_aClassicPartsPad[112].nEnabled = 1;
        g_aClassicPartsPad[112].nUvPaletteIndex = 112;
        g_aClassicPartsPad[113].nEnabled = 1;
        g_aClassicPartsPad[113].nUvPaletteIndex = 113;
        g_aClassicPartsPad[114].nEnabled = 1;
        g_aClassicPartsPad[114].flX = 0.0f;
        g_aClassicPartsPad[114].flY = 0.0f;
        g_aClassicPartsPad[114].flWidth = 1e+01f;
        g_aClassicPartsPad[114].flHeight = 12.0f;
        g_aClassicPartsPad[114].nUvPaletteIndex = 114;
        g_aClassicPartsPad[115].nEnabled = 1;
        g_aClassicPartsPad[115].flX = 0.0f;
        g_aClassicPartsPad[115].flY = 0.0f;
        g_aClassicPartsPad[115].flWidth = 1e+01f;
        g_aClassicPartsPad[115].flHeight = 12.0f;
        g_aClassicPartsPad[115].nUvPaletteIndex = 115;
        g_aClassicPartsPad[116].nEnabled = 1;
        g_aClassicPartsPad[116].nUvPaletteIndex = 116;
        g_aClassicPartsPad[117].nEnabled = 1;
        g_aClassicPartsPad[117].flX = 0.0f;
        g_aClassicPartsPad[117].flY = 0.0f;
        g_aClassicPartsPad[117].flWidth = 1e+01f;
        g_aClassicPartsPad[117].flHeight = 12.0f;
        g_aClassicPartsPad[117].nUvPaletteIndex = 117;
        g_aClassicPartsPad[118].nEnabled = 1;
        g_aClassicPartsPad[118].nUvPaletteIndex = 118;
        g_aClassicPartsPad[119].nEnabled = 1;
        g_aClassicPartsPad[119].nUvPaletteIndex = 119;
        g_aClassicPartsPad[120].nEnabled = 1;
        g_aClassicPartsPad[120].nUvPaletteIndex = 120;
        g_aClassicPartsPad[121].nEnabled = 1;
        g_aClassicPartsPad[121].nUvPaletteIndex = 121;
        g_aClassicPartsPad[122].nEnabled = 1;
        g_aClassicPartsPad[122].flX = 0.0f;
        g_aClassicPartsPad[122].flY = 0.0f;
        g_aClassicPartsPad[122].flWidth = 1e+01f;
        g_aClassicPartsPad[122].flHeight = 12.0f;
        g_aClassicPartsPad[122].nUvPaletteIndex = 122;
        g_aClassicPartsPad[123].nEnabled = 1;
        g_aClassicPartsPad[123].nUvPaletteIndex = 123;
        g_aClassicPartsPad[124].nEnabled = 1;
        g_aClassicPartsPad[124].flX = 0.0f;
        g_aClassicPartsPad[124].flY = 0.0f;
        g_aClassicPartsPad[124].flWidth = 6.0f;
        g_aClassicPartsPad[124].flHeight = 12.0f;
        g_aClassicPartsPad[124].nUvPaletteIndex = 124;
        g_aClassicPartsPad[125].nEnabled = 1;
        g_aClassicPartsPad[125].flX = 0.0f;
        g_aClassicPartsPad[125].flY = 0.0f;
        g_aClassicPartsPad[125].flWidth = 1e+01f;
        g_aClassicPartsPad[125].flHeight = 12.0f;
        g_aClassicPartsPad[125].nUvPaletteIndex = 125;
        g_aClassicPartsPad[126].nEnabled = 1;
        g_aClassicPartsPad[126].flX = 0.0f;
        g_aClassicPartsPad[126].flY = 0.0f;
        g_aClassicPartsPad[126].flWidth = 1.0f;
        g_aClassicPartsPad[126].flHeight = 5.0f;
        g_aClassicPartsPad[126].nUvPaletteIndex = 126;
        g_aClassicPartsPad[127].nEnabled = 1;
        g_aClassicPartsPad[127].nUvPaletteIndex = 127;
        g_aClassicPartsPad[128].nEnabled = 1;
        g_aClassicPartsPad[128].nUvPaletteIndex = 128;
        g_aClassicPartsPad[129].nEnabled = 1;
        g_aClassicPartsPad[129].nUvPaletteIndex = 129;
        g_aClassicPartsPad[130].nEnabled = 1;
        g_aClassicPartsPad[130].flX = 0.0f;
        g_aClassicPartsPad[130].flY = 0.0f;
        g_aClassicPartsPad[130].flWidth = 1.0f;
        g_aClassicPartsPad[130].flHeight = 5.0f;
        g_aClassicPartsPad[130].nUvPaletteIndex = 130;
        g_aClassicPartsPad[131].nEnabled = 1;
        g_aClassicPartsPad[131].nUvPaletteIndex = 131;
        g_aClassicPartsPad[132].nEnabled = 1;
        g_aClassicPartsPad[132].flX = 0.0f;
        g_aClassicPartsPad[132].flY = 0.0f;
        g_aClassicPartsPad[132].flWidth = 466.0f;
        g_aClassicPartsPad[132].flHeight = 22.0f;
        g_aClassicPartsPad[132].nUvPaletteIndex = 132;
        g_aClassicPartsPad[133].nEnabled = 1;
        g_aClassicPartsPad[133].flX = 0.0f;
        g_aClassicPartsPad[133].flY = 0.0f;
        g_aClassicPartsPad[133].flWidth = 18.0f;
        g_aClassicPartsPad[133].flHeight = 24.0f;
        g_aClassicPartsPad[133].nUvPaletteIndex = 133;
        g_aClassicPartsPad[134].nEnabled = 1;
        g_aClassicPartsPad[134].flX = 0.0f;
        g_aClassicPartsPad[134].flY = 0.0f;
        g_aClassicPartsPad[134].flWidth = 18.0f;
        g_aClassicPartsPad[134].flHeight = 24.0f;
        g_aClassicPartsPad[134].nUvPaletteIndex = 134;
        g_aClassicPartsPad[135].nEnabled = 1;
        g_aClassicPartsPad[135].nUvPaletteIndex = 135;
        g_aClassicPartsPad[136].nEnabled = 1;
        g_aClassicPartsPad[136].nUvPaletteIndex = 136;
        g_aClassicPartsPad[137].nEnabled = 1;
        g_aClassicPartsPad[137].nUvPaletteIndex = 137;
        g_aClassicPartsPad[138].nEnabled = 1;
        g_aClassicPartsPad[138].flX = 0.0f;
        g_aClassicPartsPad[138].flY = 0.0f;
        g_aClassicPartsPad[138].flWidth = 18.0f;
        g_aClassicPartsPad[138].flHeight = 24.0f;
        g_aClassicPartsPad[138].nUvPaletteIndex = 138;
        g_aClassicPartsPad[139].nEnabled = 1;
        g_aClassicPartsPad[139].nUvPaletteIndex = 139;
        g_aClassicPartsPad[140].nEnabled = 1;
        g_aClassicPartsPad[140].nUvPaletteIndex = 140;
        g_aClassicPartsPad[141].nEnabled = 1;
        g_aClassicPartsPad[141].flX = 0.0f;
        g_aClassicPartsPad[141].flY = 0.0f;
        g_aClassicPartsPad[141].flWidth = 18.0f;
        g_aClassicPartsPad[141].flHeight = 24.0f;
        g_aClassicPartsPad[141].nUvPaletteIndex = 141;
        g_aClassicPartsPad[142].nEnabled = 1;
        g_aClassicPartsPad[142].nUvPaletteIndex = 142;
        g_aClassicPartsPad[143].nEnabled = 1;
        g_aClassicPartsPad[143].flX = 0.0f;
        g_aClassicPartsPad[143].flY = 0.0f;
        g_aClassicPartsPad[143].flWidth = 6.0f;
        g_aClassicPartsPad[143].flHeight = 2e+01f;
        g_aClassicPartsPad[143].nUvPaletteIndex = 143;
        g_aClassicPartsPad[144].nEnabled = 1;
        g_aClassicPartsPad[144].flX = 0.0f;
        g_aClassicPartsPad[144].flY = 0.0f;
        g_aClassicPartsPad[144].flWidth = 16.0f;
        g_aClassicPartsPad[144].flHeight = 2e+01f;
        g_aClassicPartsPad[144].nUvPaletteIndex = 144;
        g_aClassicPartsPad[145].nEnabled = 1;
        g_aClassicPartsPad[145].nUvPaletteIndex = 145;
        g_aClassicPartsPad[146].nEnabled = 1;
        g_aClassicPartsPad[146].flX = 0.0f;
        g_aClassicPartsPad[146].flY = 0.0f;
        g_aClassicPartsPad[146].flWidth = 16.0f;
        g_aClassicPartsPad[146].flHeight = 2e+01f;
        g_aClassicPartsPad[146].nUvPaletteIndex = 146;
        g_aClassicPartsPad[147].nEnabled = 1;
        g_aClassicPartsPad[147].nUvPaletteIndex = 147;
        g_aClassicPartsPad[148].nEnabled = 1;
        g_aClassicPartsPad[148].nUvPaletteIndex = 148;
        g_aClassicPartsPad[149].nEnabled = 1;
        g_aClassicPartsPad[149].flX = 0.0f;
        g_aClassicPartsPad[149].flY = 0.0f;
        g_aClassicPartsPad[149].flWidth = 16.0f;
        g_aClassicPartsPad[149].flHeight = 2e+01f;
        g_aClassicPartsPad[149].nUvPaletteIndex = 149;
        g_aClassicPartsPad[150].nEnabled = 1;
        g_aClassicPartsPad[150].nUvPaletteIndex = 150;
        g_aClassicPartsPad[151].nEnabled = 1;
        g_aClassicPartsPad[151].nUvPaletteIndex = 151;
        g_aClassicPartsPad[152].nEnabled = 1;
        g_aClassicPartsPad[152].nUvPaletteIndex = 152;
        g_aClassicPartsPad[153].nEnabled = 1;
        g_aClassicPartsPad[153].nUvPaletteIndex = 153;
        g_aClassicPartsPad[154].nEnabled = 1;
        g_aClassicPartsPad[154].flX = 0.0f;
        g_aClassicPartsPad[154].flY = 0.0f;
        g_aClassicPartsPad[154].flWidth = 18.0f;
        g_aClassicPartsPad[154].flHeight = 2e+01f;
        g_aClassicPartsPad[154].nUvPaletteIndex = 154;
        g_aClassicPartsPad[155].nEnabled = 1;
        g_aClassicPartsPad[155].nUvPaletteIndex = 155;
        g_aClassicPartsPad[156].nEnabled = 1;
        g_aClassicPartsPad[156].nUvPaletteIndex = 156;
        g_aClassicPartsPad[157].nEnabled = 1;
        g_aClassicPartsPad[157].flX = 0.0f;
        g_aClassicPartsPad[157].flY = 0.0f;
        g_aClassicPartsPad[157].flWidth = 18.0f;
        g_aClassicPartsPad[157].flHeight = 24.0f;
        g_aClassicPartsPad[157].nUvPaletteIndex = 157;
        g_aClassicPartsPad[158].nEnabled = 1;
        g_aClassicPartsPad[158].nUvPaletteIndex = 158;
        g_aClassicPartsPad[159].nEnabled = 1;
        g_aClassicPartsPad[159].nUvPaletteIndex = 159;
        g_aClassicPartsPad[160].nEnabled = 1;
        g_aClassicPartsPad[160].nUvPaletteIndex = 160;
        g_aClassicPartsPad[161].nEnabled = 1;
        g_aClassicPartsPad[161].nUvPaletteIndex = 161;
        g_aClassicPartsPad[162].nEnabled = 1;
        g_aClassicPartsPad[162].flX = 0.0f;
        g_aClassicPartsPad[162].flY = 0.0f;
        g_aClassicPartsPad[162].flWidth = 18.0f;
        g_aClassicPartsPad[162].flHeight = 24.0f;
        g_aClassicPartsPad[162].nUvPaletteIndex = 162;
        g_aClassicPartsPad[163].nEnabled = 1;
        g_aClassicPartsPad[163].nUvPaletteIndex = 163;
        g_aClassicPartsPad[164].nEnabled = 1;
        g_aClassicPartsPad[164].nUvPaletteIndex = 164;
        g_aClassicPartsPad[165].nEnabled = 1;
        g_aClassicPartsPad[165].flX = 0.0f;
        g_aClassicPartsPad[165].flY = 0.0f;
        g_aClassicPartsPad[165].flWidth = 6.0f;
        g_aClassicPartsPad[165].flHeight = 2e+01f;
        g_aClassicPartsPad[165].nUvPaletteIndex = 165;
        g_aClassicPartsPad[166].nEnabled = 1;
        g_aClassicPartsPad[166].nUvPaletteIndex = 166;
        g_aClassicPartsPad[167].nEnabled = 1;
        g_aClassicPartsPad[167].nUvPaletteIndex = 167;
        g_aClassicPartsPad[168].nEnabled = 1;
        g_aClassicPartsPad[168].nUvPaletteIndex = 168;
        g_aClassicPartsPad[169].nEnabled = 1;
        g_aClassicPartsPad[169].nUvPaletteIndex = 169;
        g_aClassicPartsPad[170].nEnabled = 1;
        g_aClassicPartsPad[170].flX = 0.0f;
        g_aClassicPartsPad[170].flY = 0.0f;
        g_aClassicPartsPad[170].flWidth = 16.0f;
        g_aClassicPartsPad[170].flHeight = 2e+01f;
        g_aClassicPartsPad[170].nUvPaletteIndex = 170;
        g_aClassicPartsPad[171].nEnabled = 1;
        g_aClassicPartsPad[171].nUvPaletteIndex = 171;
        g_aClassicPartsPad[172].nEnabled = 1;
        g_aClassicPartsPad[172].nUvPaletteIndex = 172;
        g_aClassicPartsPad[173].nEnabled = 1;
        g_aClassicPartsPad[173].flX = 0.0f;
        g_aClassicPartsPad[173].flY = 0.0f;
        g_aClassicPartsPad[173].flWidth = 16.0f;
        g_aClassicPartsPad[173].flHeight = 2e+01f;
        g_aClassicPartsPad[173].nUvPaletteIndex = 173;
        g_aClassicPartsPad[174].nEnabled = 1;
        g_aClassicPartsPad[174].nUvPaletteIndex = 174;
        g_aClassicPartsPad[175].nEnabled = 1;
        g_aClassicPartsPad[175].nUvPaletteIndex = 175;
        g_aClassicPartsPad[176].nEnabled = 1;
        g_aClassicPartsPad[176].flX = 0.0f;
        g_aClassicPartsPad[176].flY = 0.0f;
        g_aClassicPartsPad[176].flWidth = 18.0f;
        g_aClassicPartsPad[176].flHeight = 2e+01f;
        g_aClassicPartsPad[176].nUvPaletteIndex = 176;
        g_aClassicPartsPad[177].nEnabled = 1;
        g_aClassicPartsPad[177].flX = 0.0f;
        g_aClassicPartsPad[177].flY = 0.0f;
        g_aClassicPartsPad[177].flWidth = 12.0f;
        g_aClassicPartsPad[177].flHeight = 16.0f;
        g_aClassicPartsPad[177].nUvPaletteIndex = 177;
        g_aClassicPartsPad[178].nEnabled = 1;
        g_aClassicPartsPad[178].flX = 0.0f;
        g_aClassicPartsPad[178].flY = 0.0f;
        g_aClassicPartsPad[178].flWidth = 12.0f;
        g_aClassicPartsPad[178].flHeight = 16.0f;
        g_aClassicPartsPad[179].nEnabled = 1;
        g_aClassicPartsPad[178].nUvPaletteIndex = 178;
        g_aClassicPartsPad[180].nEnabled = 1;
        g_aClassicPartsPad[179].nUvPaletteIndex = 179;
        g_aClassicPartsPad[180].nUvPaletteIndex = 180;
        g_aClassicPartsPad[181].nEnabled = 1;
        g_aClassicPartsPad[181].flWidth = 12.0f;
        g_aClassicPartsPad[181].flHeight = 16.0f;
        g_aClassicPartsPad[181].nUvPaletteIndex = 181;
        g_aClassicPartsPad[182].nEnabled = 1;
        g_aClassicPartsPad[182].nUvPaletteIndex = 182;
        g_aClassicPartsPad[183].nEnabled = 1;
        g_aClassicPartsPad[183].nUvPaletteIndex = 183;
        g_aClassicPartsPad[184].nEnabled = 1;
        g_aClassicPartsPad[184].nUvPaletteIndex = 184;
        g_aClassicPartsPad[185].nEnabled = 1;
        g_aClassicPartsPad[185].nUvPaletteIndex = 185;
        g_aClassicPartsPad[186].nEnabled = 1;
        g_aClassicPartsPad[186].flWidth = 12.0f;
        g_aClassicPartsPad[186].flHeight = 16.0f;
        g_aClassicPartsPad[186].nUvPaletteIndex = 186;
        g_aClassicPartsPad[187].nEnabled = 1;
        g_aClassicPartsPad[187].flX = 0.0f;
        g_aClassicPartsPad[187].flY = 0.0f;
        g_aClassicPartsPad[187].flWidth = 2.0f;
        g_aClassicPartsPad[187].flHeight = 16.0f;
        g_aClassicPartsPad[187].nUvPaletteIndex = 187;
        g_aClassicPartsPad[188].nEnabled = 1;
        g_aClassicPartsPad[188].nUvPaletteIndex = 188;
        g_aClassicPartsPad[189].nEnabled = 1;
        g_aClassicPartsPad[189].flWidth = 12.0f;
        g_aClassicPartsPad[189].flHeight = 16.0f;
        g_aClassicPartsPad[190].nEnabled = 1;
        g_aClassicPartsPad[189].nUvPaletteIndex = 189;
        g_aClassicPartsPad[191].nEnabled = 1;
        g_aClassicPartsPad[190].nUvPaletteIndex = 190;
        g_aClassicPartsPad[192].nEnabled = 1;
        g_aClassicPartsPad[191].nUvPaletteIndex = 191;
        g_aClassicPartsPad[193].nEnabled = 1;
        g_aClassicPartsPad[192].nUvPaletteIndex = 192;
        g_aClassicPartsPad[193].nUvPaletteIndex = 193;
        g_aClassicPartsPad[194].nEnabled = 1;
        g_aClassicPartsPad[194].flWidth = 12.0f;
        g_aClassicPartsPad[194].flHeight = 16.0f;
        g_aClassicPartsPad[194].nUvPaletteIndex = 194;
        g_aClassicPartsPad[195].nEnabled = 1;
        g_aClassicPartsPad[195].nUvPaletteIndex = 195;
        g_aClassicPartsPad[196].nEnabled = 1;
        g_aClassicPartsPad[196].nUvPaletteIndex = 196;
        g_aClassicPartsPad[197].nEnabled = 1;
        g_aClassicPartsPad[197].flWidth = 12.0f;
        g_aClassicPartsPad[197].flHeight = 16.0f;
        g_aClassicPartsPad[197].nUvPaletteIndex = 197;
        g_aClassicPartsPad[198].nEnabled = 1;
        g_aClassicPartsPad[198].nUvPaletteIndex = 198;
        g_aClassicPartsPad[199].nEnabled = 1;
        g_aClassicPartsPad[199].nUvPaletteIndex = 199;
        g_aClassicPartsPad[200].nEnabled = 1;
        g_aClassicPartsPad[201].nEnabled = 1;
        g_aClassicPartsPad[201].flX = 17.0f;
        g_aClassicPartsPad[201].flY = 15.0f;
        g_aClassicPartsPad[200].nUvPaletteIndex = 200;
        g_aClassicPartsPad[201].flWidth = 34.0f;
        g_aClassicPartsPad[201].flHeight = 3e+01f;
        g_aClassicPartsPad[201].nUvPaletteIndex = 201;
        g_aClassicPartsPad[202].nEnabled = 1;
        g_aClassicPartsPad[202].flX = 14.0f;
        g_aClassicPartsPad[202].nUvPaletteIndex = 202;
        g_aClassicPartsPad[203].nEnabled = 1;
        g_aClassicPartsPad[203].nUvPaletteIndex = 203;
        g_aClassicPartsPad[204].nEnabled = 1;
        g_aClassicPartsPad[204].flX = 26.0f;
        g_aClassicPartsPad[204].flY = 15.0f;
        g_aClassicPartsPad[204].flWidth = 52.0f;
        g_aClassicPartsPad[204].flHeight = 3e+01f;
        g_aClassicPartsPad[204].nUvPaletteIndex = 204;
        g_aClassicPartsPad[205].nEnabled = 1;
        g_aClassicPartsPad[205].flWidth = 52.0f;
        g_aClassicPartsPad[205].nUvPaletteIndex = 205;
        g_aClassicPartsPad[206].nEnabled = 1;
        g_aClassicPartsPad[206].nUvPaletteIndex = 206;
        g_aClassicPartsPad[207].nEnabled = 1;
        g_aClassicPartsPad[207].flX = 0.0f;
        g_aClassicPartsPad[207].flY = 0.0f;
        g_aClassicPartsPad[207].flWidth = 43.0f;
        g_aClassicPartsPad[207].flHeight = 8.0f;
        g_aClassicPartsPad[207].nUvPaletteIndex = 207;
        g_aClassicPartsPad[208].nEnabled = 1;
        g_aClassicPartsPad[208].nUvPaletteIndex = 208;
        g_aClassicPartsPad[209].nEnabled = 1;
        g_aClassicPartsPad[209].nUvPaletteIndex = 209;
        g_aClassicPartsPad[210].nEnabled = 1;
        g_aClassicPartsPad[210].flWidth = 16.0f;
        g_aClassicPartsPad[210].flHeight = 18.0f;
        g_aClassicPartsPad[210].nUvPaletteIndex = 210;
        g_aClassicPartsPad[211].nEnabled = 1;
        g_aClassicPartsPad[211].nUvPaletteIndex = 211;
        g_aClassicPartsPad[212].nEnabled = 1;
        g_aClassicPartsPad[212].nUvPaletteIndex = 212;
        g_aClassicPartsPad[213].nEnabled = 1;
        g_aClassicPartsPad[213].flWidth = 16.0f;
        g_aClassicPartsPad[213].flHeight = 18.0f;
        g_aClassicPartsPad[214].nEnabled = 1;
        g_aClassicPartsPad[213].nUvPaletteIndex = 213;
        g_aClassicPartsPad[215].nEnabled = 1;
        g_aClassicPartsPad[214].nUvPaletteIndex = 214;
        g_aClassicPartsPad[216].nEnabled = 1;
        g_aClassicPartsPad[215].nUvPaletteIndex = 215;
        g_aClassicPartsPad[217].nEnabled = 1;
        g_aClassicPartsPad[216].nUvPaletteIndex = 216;
        g_aClassicPartsPad[217].nUvPaletteIndex = 217;
        g_aClassicPartsPad[218].nEnabled = 1;
        g_aClassicPartsPad[218].flWidth = 16.0f;
        g_aClassicPartsPad[218].flHeight = 18.0f;
        g_aClassicPartsPad[218].nUvPaletteIndex = 218;
        g_aClassicPartsPad[219].nEnabled = 1;
        g_aClassicPartsPad[219].flX = 0.0f;
        g_aClassicPartsPad[219].flY = 0.0f;
        g_aClassicPartsPad[219].flWidth = 212.0f;
        g_aClassicPartsPad[219].flHeight = 14.0f;
        g_aClassicPartsPad[219].nUvPaletteIndex = 219;
        g_aClassicPartsPad[220].nEnabled = 1;
        g_aClassicPartsPad[220].nUvPaletteIndex = 220;
        g_aClassicPartsPad[221].nEnabled = 1;
        g_aClassicPartsPad[221].flWidth = 16.0f;
        g_aClassicPartsPad[221].flHeight = 22.0f;
        g_aClassicPartsPad[221].nUvPaletteIndex = 221;
        g_aClassicPartsPad[222].nEnabled = 1;
        g_aClassicPartsPad[222].flX = 0.0f;
        g_aClassicPartsPad[222].flY = 0.0f;
        g_aClassicPartsPad[222].flWidth = 62.0f;
        g_aClassicPartsPad[222].flHeight = 62.0f;
        g_aClassicPartsPad[222].nUvPaletteIndex = 222;
        g_aClassicPartsPad[223].nEnabled = 1;
        g_aClassicPartsPad[223].flX = 0.0f;
        g_aClassicPartsPad[223].flY = 0.0f;
        g_aClassicPartsPad[223].flWidth = 166.0f;
        g_aClassicPartsPad[223].flHeight = 18.0f;
        g_aClassicPartsPad[223].nUvPaletteIndex = 223;
        g_aClassicPartsPad[224].nEnabled = 1;
        g_aClassicPartsPad[224].nUvPaletteIndex = 224;
        g_aClassicPartsPad[225].nEnabled = 1;
        g_aClassicPartsPad[225].nUvPaletteIndex = 225;
        g_aClassicPartsPad[226].nEnabled = 1;
        g_aClassicPartsPad[226].flWidth = 166.0f;
        g_aClassicPartsPad[226].flHeight = 18.0f;
        g_aClassicPartsPad[226].nUvPaletteIndex = 226;
        g_aClassicPartsPad[227].nEnabled = 1;
        g_aClassicPartsPad[228].nEnabled = 1;
        g_aClassicPartsPad[228].flX = 0.0f;
        g_aClassicPartsPad[228].flY = 0.0f;
        g_aClassicPartsPad[227].nUvPaletteIndex = 227;
        g_aClassicPartsPad[228].flWidth = 1.7e+02f;
        g_aClassicPartsPad[228].flHeight = 22.0f;
        g_aClassicPartsPad[228].nUvPaletteIndex = 228;
        g_aClassicPartsPad[229].nEnabled = 1;
        g_aClassicPartsPad[229].flWidth = 3.2e+02f;
        g_aClassicPartsPad[229].flHeight = 6e+01f;
        g_aClassicPartsPad[229].nUvPaletteIndex = 229;
        g_aClassicPartsPad[230].nEnabled = 1;
        g_aClassicPartsPad[230].flX = 0.0f;
        g_aClassicPartsPad[230].flY = 0.0f;
        g_aClassicPartsPad[230].flWidth = 128.0f;
        g_aClassicPartsPad[230].flHeight = 6e+01f;
        g_aClassicPartsPad[230].nUvPaletteIndex = 230;
        g_aClassicPartsPad[231].nEnabled = 1;
        g_aClassicPartsPad[231].flX = 0.0f;
        g_aClassicPartsPad[231].flY = 0.0f;
        g_aClassicPartsPad[231].flWidth = 3.2e+02f;
        g_aClassicPartsPad[231].flHeight = 6e+01f;
        g_aClassicPartsPad[231].nUvPaletteIndex = 231;
        g_aClassicPartsPad[232].nEnabled = 1;
        g_aClassicPartsPad[232].flX = 0.0f;
        g_aClassicPartsPad[232].flY = 0.0f;
        g_aClassicPartsPad[232].flWidth = 384.0f;
        g_aClassicPartsPad[232].flHeight = 6e+01f;
        g_aClassicPartsPad[232].nUvPaletteIndex = 232;
        g_aClassicPartsPad[233].nEnabled = 1;
        g_aClassicPartsPad[233].nUvPaletteIndex = 233;
        g_aClassicPartsPad[234].nEnabled = 1;
        g_aClassicPartsPad[234].flWidth = 126.0f;
        g_aClassicPartsPad[234].nUvPaletteIndex = 234;
        g_aClassicPartsPad[235].nEnabled = 1;
        g_aClassicPartsPad[235].flX = 0.0f;
        g_aClassicPartsPad[235].flY = 0.0f;
        g_aClassicPartsPad[235].flWidth = 166.0f;
        g_aClassicPartsPad[235].flHeight = 3e+01f;
        g_aClassicPartsPad[235].nUvPaletteIndex = 235;
        g_aClassicPartsPad[236].nEnabled = 1;
        g_aClassicPartsPad[236].flX = 0.0f;
        g_aClassicPartsPad[236].flY = 0.0f;
        g_aClassicPartsPad[236].flWidth = 266.0f;
        g_aClassicPartsPad[236].flHeight = 3e+01f;
        g_aClassicPartsPad[236].nUvPaletteIndex = 236;
        g_aClassicPartsPad[237].nEnabled = 1;
        g_aClassicPartsPad[237].flWidth = 106.0f;
        g_aClassicPartsPad[237].flHeight = 4e+01f;
        g_aClassicPartsPad[237].nUvPaletteIndex = 237;
        g_aClassicPartsPad[238].nEnabled = 1;
        g_aClassicPartsPad[238].flX = 0.0f;
        g_aClassicPartsPad[238].flY = 0.0f;
        g_aClassicPartsPad[238].flWidth = 104.0f;
        g_aClassicPartsPad[238].flHeight = 4e+01f;
        g_aClassicPartsPad[238].nUvPaletteIndex = 238;
        g_aClassicPartsPad[239].nEnabled = 1;
        g_aClassicPartsPad[239].flX = 0.0f;
        g_aClassicPartsPad[239].flY = 0.0f;
        g_aClassicPartsPad[239].flWidth = 138.0f;
        g_aClassicPartsPad[239].flHeight = 4e+01f;
        g_aClassicPartsPad[239].nUvPaletteIndex = 239;
        g_aClassicPartsAnchorPad[1].x = 263.0f;
        g_aClassicPartsAnchorPad[1].y = 937.0f;
        const S_VECTOR2 savedAnchor = g_aClassicPartsAnchorPad[1];
        g_aClassicPartsAnchorPad[0].x = 0.0f;
        g_aClassicPartsAnchorPad[0].y = 0.0f;
        g_aClassicPartsAnchorPad[3].x = 116.0f;
        g_aClassicPartsAnchorPad[3].y = 86.0f;
        g_aClassicPartsAnchorPad[2].x = 567.0f;
        g_aClassicPartsAnchorPad[2].y = 914.0f;
        g_aClassicPartsAnchorPad[5].x = 116.0f;
        g_aClassicPartsAnchorPad[5].y = 142.0f;
        g_aClassicPartsAnchorPad[4].x = 652.0f;
        g_aClassicPartsAnchorPad[4].y = 86.0f;
        g_aClassicPartsAnchorPad[7].x = 116.0f;
        g_aClassicPartsAnchorPad[7].y = 3.4e+02f;
        g_aClassicPartsAnchorPad[6].x = 652.0f;
        g_aClassicPartsAnchorPad[6].y = 142.0f;
        g_aClassicPartsAnchorPad[9].x = 116.0f;
        g_aClassicPartsAnchorPad[9].y = 378.0f;
        g_aClassicPartsAnchorPad[8].x = 652.0f;
        g_aClassicPartsAnchorPad[8].y = 3.4e+02f;
        g_aClassicPartsAnchorPad[11].x = 116.0f;
        g_aClassicPartsAnchorPad[11].y = 434.0f;
        g_aClassicPartsAnchorPad[10].x = 652.0f;
        g_aClassicPartsAnchorPad[10].y = 378.0f;
        g_aClassicPartsAnchorPad[13].x = 116.0f;
        g_aClassicPartsAnchorPad[13].y = 898.0f;
        g_aClassicPartsAnchorPad[12].x = 652.0f;
        g_aClassicPartsAnchorPad[12].y = 434.0f;
        g_aClassicPartsAnchorPad[15].x = 374.0f;
        g_aClassicPartsAnchorPad[15].y = 892.0f;
        g_aClassicPartsAnchorPad[14].x = 652.0f;
        g_aClassicPartsAnchorPad[14].y = 898.0f;
        g_aClassicPartsAnchorPad[17].x = 132.0f;
        g_aClassicPartsAnchorPad[17].y = 448.0f;
        g_aClassicPartsAnchorPad[16].x = 3.9e+02f;
        g_aClassicPartsAnchorPad[16].y = 892.0f;
        g_aClassicPartsAnchorPad[19].x = 132.0f;
        g_aClassicPartsAnchorPad[19].y = 732.0f;
        g_aClassicPartsAnchorPad[18].x = 132.0f;
        g_aClassicPartsAnchorPad[18].y = 478.0f;
        g_aClassicPartsAnchorPad[21].x = 132.0f;
        g_aClassicPartsAnchorPad[21].y = 788.0f;
        g_aClassicPartsAnchorPad[20].x = 132.0f;
        g_aClassicPartsAnchorPad[20].y = 758.0f;
        g_aClassicPartsAnchorPad[23].x = 132.0f;
        g_aClassicPartsAnchorPad[23].y = 488.0f;
        g_aClassicPartsAnchorPad[22].x = 132.0f;
        g_aClassicPartsAnchorPad[22].y = 8.7e+02f;
        g_aClassicPartsAnchorPad[25].x = 132.0f;
        g_aClassicPartsAnchorPad[25].y = 625.0f;
        g_aClassicPartsAnchorPad[24].x = 132.0f;
        g_aClassicPartsAnchorPad[24].y = 518.0f;
        g_aClassicPartsAnchorPad[27].x = 132.0f;
        g_aClassicPartsAnchorPad[27].y = 713.0f;
        g_aClassicPartsAnchorPad[26].x = 132.0f;
        g_aClassicPartsAnchorPad[26].y = 683.0f;
        g_aClassicPartsAnchorPad[29].x = 132.0f;
        g_aClassicPartsAnchorPad[29].y = 154.0f;
        g_aClassicPartsAnchorPad[28].x = 132.0f;
        g_aClassicPartsAnchorPad[28].y = 8.2e+02f;
        g_aClassicPartsAnchorPad[31].x = 358.0f;
        g_aClassicPartsAnchorPad[31].y = 155.0f;
        g_aClassicPartsAnchorPad[30].x = 137.0f;
        g_aClassicPartsAnchorPad[30].y = 157.0f;
        g_aClassicPartsAnchorPad[33].x = 4.2e+02f;
        g_aClassicPartsAnchorPad[33].y = 204.0f;
        g_aClassicPartsAnchorPad[32].x = 358.0f;
        g_aClassicPartsAnchorPad[32].y = 1.8e+02f;
        g_aClassicPartsAnchorPad[34].x = 619.0f;
        g_aClassicPartsAnchorPad[34].y = 204.0f;
        g_aClassicPartsAnchorPad[37].x = 5e+02f;
        g_aClassicPartsAnchorPad[37].y = 222.0f;
        g_aClassicPartsAnchorPad[36].x = 493.0f;
        g_aClassicPartsAnchorPad[36].y = 222.0f;
        g_aClassicPartsAnchorPad[39].x = 358.0f;
        g_aClassicPartsAnchorPad[39].y = 234.0f;
        g_aClassicPartsAnchorPad[38].x = 538.0f;
        g_aClassicPartsAnchorPad[38].y = 222.0f;
        g_aClassicPartsAnchorPad[41].x = 631.0f;
        g_aClassicPartsAnchorPad[41].y = 229.0f;
        g_aClassicPartsAnchorPad[40].x = 4e+02f;
        g_aClassicPartsAnchorPad[40].y = 234.0f;
        g_aClassicPartsAnchorPad[43].x = 4e+02f;
        g_aClassicPartsAnchorPad[43].y = 257.0f;
        g_aClassicPartsAnchorPad[42].x = 358.0f;
        g_aClassicPartsAnchorPad[42].y = 257.0f;
        g_aClassicPartsAnchorPad[45].x = 358.0f;
        g_aClassicPartsAnchorPad[45].y = 297.0f;
        g_aClassicPartsAnchorPad[44].x = 631.0f;
        g_aClassicPartsAnchorPad[44].y = 253.0f;
        g_aClassicPartsAnchorPad[47].x = 599.0f;
        g_aClassicPartsAnchorPad[47].y = 318.0f;
        g_aClassicPartsAnchorPad[46].x = 599.0f;
        g_aClassicPartsAnchorPad[46].y = 318.0f;
        g_aClassicPartsAnchorPad[49].x = 308.0f;
        g_aClassicPartsAnchorPad[49].y = 541.0f;
        g_aClassicPartsAnchorPad[48].x = 413.0f;
        g_aClassicPartsAnchorPad[48].y = 391.0f;
        g_aClassicPartsAnchorPad[51].x = 319.0f;
        g_aClassicPartsAnchorPad[51].y = 626.0f;
        g_aClassicPartsAnchorPad[50].x = 358.0f;
        g_aClassicPartsAnchorPad[50].y = 522.0f;
        g_aClassicPartsAnchorPad[53].x = 203.0f;
        g_aClassicPartsAnchorPad[53].y = 495.0f;
        g_aClassicPartsAnchorPad[52].x = 151.0f;
        g_aClassicPartsAnchorPad[52].y = 491.0f;
        g_aClassicPartsAnchorPad[54].x = 222.0f;
        g_aClassicPartsAnchorPad[54].y = 523.0f;
        g_aClassicPartsAnchorPad[56].x = 222.0f;
        g_aClassicPartsAnchorPad[56].y = 549.0f;
        g_aClassicPartsAnchorPad[58].x = 222.0f;
        g_aClassicPartsAnchorPad[58].y = 575.0f;
        g_aClassicPartsAnchorPad[60].x = 222.0f;
        g_aClassicPartsAnchorPad[60].y = 601.0f;
        g_aClassicPartsAnchorPad[62].x = 222.0f;
        g_aClassicPartsAnchorPad[62].y = 627.0f;
        g_aClassicPartsAnchorPad[64].x = 222.0f;
        g_aClassicPartsAnchorPad[64].y = 653.0f;
        g_aClassicPartsAnchorPad[130].x = 252.0f;
        g_aClassicPartsAnchorPad[130].y = 391.0f;
        g_aClassicPositionPhonePortrait[0].flX = 0.0f;
        g_aClassicPositionPhonePortrait[0].flY = 0.0f;
        g_aClassicPositionPhonePortrait[0].nAnchorMode = 0;
        g_aClassicPositionPhonePortrait[1].flX = 8.0f;
        g_aClassicPositionPhonePortrait[1].flY = -214.0f;
        g_aClassicPositionPhonePortrait[1].nAnchorMode = 1;
        g_aClassicPositionPhonePortrait[2].flX = 312.0f;
        g_aClassicPositionPhonePortrait[2].flY = 164.0f;
        g_aClassicPositionPhonePortrait[2].nAnchorMode = 1;
        g_aClassicPositionPhonePortrait[3].flX = -141.0f;
        g_aClassicPositionPhonePortrait[3].flY = -192.0f;
        g_aClassicPositionPhonePortrait[4].flY = -47.0f;
        g_aClassicPositionPhonePortrait[5].flY = -175.0f;
        g_aClassicPositionPhonePortrait[6].flY = -155.0f;
        g_aClassicPositionPhonePortrait[7].flX = -132.0f;
        g_aClassicPositionPhonePortrait[10].flX = 27.0f;
        g_aClassicPositionPhonePortrait[8].flY = -142.0f;
        g_aClassicPositionPhonePortrait[9].flY = -142.0f;
        g_aClassicPositionPhonePortrait[10].flY = -142.0f;
        g_aClassicPositionPhonePortrait[11].flY = -1.3e+02f;
        g_aClassicPositionPhonePortrait[3].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[4].flX = 141.0f;
        g_aClassicPositionPhonePortrait[4].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[5].flX = 0.0f;
        g_aClassicPositionPhonePortrait[5].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[6].flX = 0.0f;
        g_aClassicPositionPhonePortrait[6].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[7].flY = -139.0f;
        g_aClassicPositionPhonePortrait[7].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[14].flX = 2e+01f;
        g_aClassicPositionPhonePortrait[15].flX = 45.0f;
        g_aClassicPositionPhonePortrait[16].flX = 49.0f;
        g_aClassicPositionPhonePortrait[8].flX = -33.0f;
        g_aClassicPositionPhonePortrait[8].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[17].flX = 5e+01f;
        g_aClassicPositionPhonePortrait[12].flX = 16.0f;
        g_aClassicPositionPhonePortrait[12].flY = -129.0f;
        g_aClassicPositionPhonePortrait[13].flY = -129.0f;
        g_aClassicPositionPhonePortrait[14].flY = -129.0f;
        g_aClassicPositionPhonePortrait[15].flY = -129.0f;
        g_aClassicPositionPhonePortrait[16].flY = -129.0f;
        g_aClassicPositionPhonePortrait[18].flY = -129.0f;
        g_aClassicPositionPhonePortrait[21].flY = -91.0f;
        g_aClassicPositionPhonePortrait[22].flY = -79.0f;
        g_aClassicPositionPhonePortrait[24].flY = 29.0f;
        g_aClassicPositionPhonePortrait[29].flY = 99.0f;
        g_aClassicPositionPhonePortrait[30].flY = 113.0f;
        g_aClassicPositionPhonePortrait[32].flX = -9e+01f;
        g_aClassicPositionPhonePortrait[33].flX = -9e+01f;
        g_aClassicPositionPhonePortrait[34].flX = -9e+01f;
        g_aClassicPositionPhonePortrait[35].flX = -9e+01f;
        g_aClassicPositionPhonePortrait[36].flX = -9e+01f;
        g_aClassicPositionPhonePortrait[37].flX = -9e+01f;
        g_aClassicPositionPhonePortrait[38].flX = -9e+01f;
        g_aClassicPositionPhonePortrait[39].flX = -9e+01f;
        g_aClassicPositionPhonePortrait[40].flX = 78.0f;
        g_aClassicPositionPhonePortrait[31].flY = -9.0f;
        g_aClassicPositionPhonePortrait[40].flY = -9.0f;
        g_aClassicPositionPhonePortrait[33].flY = 25.0f;
        g_aClassicPositionPhonePortrait[42].flY = 25.0f;
        g_aClassicPositionPhonePortrait[36].flY = 67.0f;
        g_aClassicPositionPhonePortrait[45].flY = 67.0f;
        g_aClassicPositionPhonePortrait[38].flY = 95.0f;
        g_aClassicPositionPhonePortrait[47].flY = 95.0f;
        g_aClassicPositionPhonePortrait[39].flY = 109.0f;
        g_aClassicPositionPhonePortrait[48].flY = 109.0f;
        g_aClassicPositionPhonePortrait[9].flX = 17.0f;
        g_aClassicPositionPhonePortrait[9].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[10].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[11].flX = -33.0f;
        g_aClassicPositionPhonePortrait[11].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[12].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[13].flX = 17.0f;
        g_aClassicPositionPhonePortrait[13].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[14].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[15].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[16].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[17].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[18].flX = -33.0f;
        g_aClassicPositionPhonePortrait[21].flX = -33.0f;
        g_aClassicPositionPhonePortrait[22].flX = -33.0f;
        g_aClassicPositionPhonePortrait[49].flX = -33.0f;
        g_aClassicPositionPhonePortrait[49].flY = -15.0f;
        g_aClassicPositionPhonePortrait[50].flX = -38.0f;
        g_aClassicPositionPhonePortrait[50].flY = 62.0f;
        g_aClassicPositionPhonePortrait[17].flY = -119.0f;
        g_aClassicPositionPhonePortrait[51].flY = 12.0f;
        g_aClassicPositionPhonePortrait[52].flX = -64.0f;
        g_aClassicPositionPhonePortrait[18].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[19].flX = 105.0f;
        g_aClassicPositionPhonePortrait[52].flY = 1e+01f;
        g_aClassicPositionPhonePortrait[53].flY = 1e+01f;
        g_aClassicPositionPhonePortrait[53].flX = -2e+01f;
        g_aClassicPositionPhonePortrait[54].flX = -2e+01f;
        g_aClassicPositionPhonePortrait[19].flY = -107.0f;
        g_aClassicPositionPhonePortrait[19].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[55].flX = 17.0f;
        g_aClassicPositionPhonePortrait[56].flX = -19.0f;
        g_aClassicPositionPhonePortrait[20].flX = 79.0f;
        g_aClassicPositionPhonePortrait[54].flY = 24.0f;
        g_aClassicPositionPhonePortrait[56].flY = 24.0f;
        g_aClassicPositionPhonePortrait[51].flX = -98.0f;
        g_aClassicPositionPhonePortrait[57].flX = -98.0f;
        g_aClassicPositionPhonePortrait[34].flY = 39.0f;
        g_aClassicPositionPhonePortrait[43].flY = 39.0f;
        g_aClassicPositionPhonePortrait[57].flY = 39.0f;
        g_aClassicPositionPhonePortrait[58].flX = -97.0f;
        g_aClassicPositionPhonePortrait[20].flY = -128.0f;
        g_aClassicPositionPhonePortrait[20].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[21].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[22].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[23].flX = 0.0f;
        g_aClassicPositionPhonePortrait[23].flY = 15.0f;
        g_aClassicPositionPhonePortrait[23].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[24].flX = 0.0f;
        g_aClassicPositionPhonePortrait[24].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[25].flX = 0.0f;
        g_aClassicPositionPhonePortrait[58].flY = 4e+01f;
        g_aClassicPositionPhonePortrait[25].flY = 43.0f;
        g_aClassicPositionPhonePortrait[25].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[26].flX = 0.0f;
        g_aClassicPositionPhonePortrait[59].flY = 22.0f;
        g_aClassicPositionPhonePortrait[60].flX = 42.0f;
        g_aClassicPositionPhonePortrait[60].flY = -3.0f;
        g_aClassicPositionPhonePortrait[62].flX = -92.0f;
        g_aClassicPositionPhonePortrait[62].flY = 108.0f;
        g_aClassicPositionPhonePortrait[64].flX = -5.0f;
        g_aClassicPositionPhonePortrait[65].flX = 7.0f;
        g_aClassicPositionPhonePortrait[64].flY = 135.0f;
        g_aClassicPositionPhonePortrait[65].flY = 135.0f;
        g_aClassicPositionPhonePortrait[74].flX = 8e+01f;
        g_aClassicPositionPhonePortrait[75].flX = 83.0f;
        g_aClassicPositionPhonePortrait[76].flY = -32.0f;
        g_aClassicPositionPhonePortrait[26].flY = 57.0f;
        g_aClassicPositionPhonePortrait[26].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[27].flX = 0.0f;
        g_aClassicPositionPhonePortrait[77].flX = -141.0f;
        g_aClassicPositionPhonePortrait[27].flY = 71.0f;
        g_aClassicPositionPhonePortrait[27].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[28].flX = 0.0f;
        g_aClassicPositionPhonePortrait[78].flX = 141.0f;
        g_aClassicPositionPhonePortrait[78].flY = 151.0f;
        g_aClassicPositionPhonePortrait[79].flX = -65.0f;
        g_aClassicPositionPhonePortrait[80].flX = 65.0f;
        g_aClassicPositionPhonePortrait[79].flY = -39.0f;
        g_aClassicPositionPhonePortrait[80].flY = -39.0f;
        g_aClassicPositionPhonePortrait[77].flY = -31.0f;
        g_aClassicPositionPhonePortrait[81].flY = -31.0f;
        g_aClassicPositionPhonePortrait[28].flY = 85.0f;
        g_aClassicPositionPhonePortrait[28].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[29].flX = 0.0f;
        g_aClassicPositionPhonePortrait[29].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[30].flX = 0.0f;
        g_aClassicPositionPhonePortrait[30].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[31].flX = -106.0f;
        g_aClassicPositionPhonePortrait[31].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[32].flY = 11.0f;
        g_aClassicPositionPhonePortrait[32].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[33].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[34].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[35].flY = 53.0f;
        g_aClassicPositionPhonePortrait[35].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[36].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[37].flY = 81.0f;
        g_aClassicPositionPhonePortrait[37].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[38].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[39].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[40].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[41].flX = 94.0f;
        g_aClassicPositionPhonePortrait[41].flY = 11.0f;
        g_aClassicPositionPhonePortrait[41].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[42].flX = 94.0f;
        g_aClassicPositionPhonePortrait[42].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[43].flX = 94.0f;
        g_aClassicPositionPhonePortrait[43].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[44].flX = 94.0f;
        g_aClassicPositionPhonePortrait[44].flY = 53.0f;
        g_aClassicPositionPhonePortrait[44].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[45].flX = 94.0f;
        g_aClassicPositionPhonePortrait[45].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[46].flX = 94.0f;
        g_aClassicPositionPhonePortrait[46].flY = 81.0f;
        g_aClassicPositionPhonePortrait[46].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[47].flX = 94.0f;
        g_aClassicPositionPhonePortrait[47].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[48].flX = 94.0f;
        g_aClassicPositionPhonePortrait[48].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[49].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[50].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[51].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[52].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[53].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[54].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[55].flY = 26.0f;
        g_aClassicPositionPhonePortrait[55].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[56].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[57].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[58].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[59].flX = 3e+01f;
        g_aClassicPositionPhonePortrait[59].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[60].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[61].flX = -41.0f;
        g_aClassicPositionPhonePortrait[61].flY = 97.0f;
        g_aClassicPositionPhonePortrait[61].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[62].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[63].flX = 43.0f;
        g_aClassicPositionPhonePortrait[63].flY = 76.0f;
        g_aClassicPositionPhonePortrait[63].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[64].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[65].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[66].flX = 88.0f;
        g_aClassicPositionPhonePortrait[66].flY = 155.0f;
        g_aClassicPositionPhonePortrait[66].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[67].flX = -85.0f;
        g_aClassicPositionPhonePortrait[67].flY = 3.0f;
        g_aClassicPositionPhonePortrait[67].nAnchorMode = 3;
        g_aClassicPositionPhonePortrait[68].flX = -348.0f;
        g_aClassicPositionPhonePortrait[68].flY = 0.0f;
        g_aClassicPositionPhonePortrait[68].nAnchorMode = 3;
        g_aClassicPositionPhonePortrait[69].flX = -198.0f;
        g_aClassicPositionPhonePortrait[69].flY = 0.0f;
        g_aClassicPositionPhonePortrait[69].nAnchorMode = 3;
        g_aClassicPositionPhonePortrait[70].flX = -75.0f;
        g_aClassicPositionPhonePortrait[70].flY = 0.0f;
        g_aClassicPositionPhonePortrait[70].nAnchorMode = 3;
        g_aClassicPositionPhonePortrait[71].flX = 198.0f;
        g_aClassicPositionPhonePortrait[71].flY = 0.0f;
        g_aClassicPositionPhonePortrait[71].nAnchorMode = 3;
        g_aClassicPositionPhonePortrait[72].flX = 198.0f;
        g_aClassicPositionPhonePortrait[72].flY = 0.0f;
        g_aClassicPositionPhonePortrait[72].nAnchorMode = 3;
        g_aClassicPositionPhonePortrait[73].flX = 0.0f;
        g_aClassicPositionPhonePortrait[73].flY = -28.0f;
        g_aClassicPositionPhonePortrait[73].nAnchorMode = 2;
        g_aClassicPositionPhonePortrait[74].flY = -28.0f;
        g_aClassicPositionPhonePortrait[74].nAnchorMode = 2;
        g_aClassicPositionPhonePortrait[75].flY = -57.0f;
        g_aClassicPositionPhonePortrait[75].nAnchorMode = 2;
        g_aClassicPositionPhonePortrait[76].flX = 0.0f;
        g_aClassicPositionPhonePortrait[76].nAnchorMode = 5;
        g_aClassicPositionPhonePortrait[77].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[78].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[79].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[80].nAnchorMode = 4;
        g_aClassicPositionPhonePortrait[81].flX = 0.0f;
        g_aClassicPositionPhonePortrait[81].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[1].flX = -227.0f;
        g_aClassicPositionPhoneLandscape[2].flX = 226.0f;
        g_aClassicPositionPhoneLandscape[2].flY = 269.0f;
        g_aClassicPositionPhoneLandscape[3].flY = -128.0f;
        g_aClassicPositionPhoneLandscape[5].flX = -102.0f;
        g_aClassicPositionPhoneLandscape[6].flX = -102.0f;
        g_aClassicPositionPhoneLandscape[7].flX = -204.0f;
        g_aClassicPositionPhoneLandscape[9].flX = -51.0f;
        g_aClassicPositionPhoneLandscape[10].flX = -41.0f;
        g_aClassicPositionPhoneLandscape[12].flX = 172.0f;
        g_aClassicPositionPhoneLandscape[13].flX = 173.0f;
        g_aClassicPositionPhoneLandscape[14].flX = 176.0f;
        g_aClassicPositionPhoneLandscape[15].flX = 201.0f;
        g_aClassicPositionPhoneLandscape[16].flX = 205.0f;
        g_aClassicPositionPhoneLandscape[12].flY = -69.0f;
        g_aClassicPositionPhoneLandscape[13].flY = -69.0f;
        g_aClassicPositionPhoneLandscape[14].flY = -69.0f;
        g_aClassicPositionPhoneLandscape[15].flY = -69.0f;
        g_aClassicPositionPhoneLandscape[16].flY = -69.0f;
        g_aClassicPositionPhoneLandscape[17].flX = 204.0f;
        g_aClassicPositionPhoneLandscape[11].flX = 121.0f;
        g_aClassicPositionPhoneLandscape[18].flX = 121.0f;
        g_aClassicPositionPhoneLandscape[8].flY = -82.0f;
        g_aClassicPositionPhoneLandscape[9].flY = -82.0f;
        g_aClassicPositionPhoneLandscape[10].flY = -82.0f;
        g_aClassicPositionPhoneLandscape[18].flY = -82.0f;
        g_aClassicPositionPhoneLandscape[19].flX = 181.0f;
        g_aClassicPositionPhoneLandscape[20].flX = 155.0f;
        g_aClassicPositionPhoneLandscape[20].flY = -107.0f;
        g_aClassicPositionPhoneLandscape[11].flY = -7e+01f;
        g_aClassicPositionPhoneLandscape[21].flY = -7e+01f;
        g_aClassicPositionPhoneLandscape[6].flY = -101.0f;
        g_aClassicPositionPhoneLandscape[8].flX = -101.0f;
        g_aClassicPositionPhoneLandscape[21].flX = -101.0f;
        g_aClassicPositionPhoneLandscape[22].flX = -101.0f;
        g_aClassicPositionPhoneLandscape[17].flY = -58.0f;
        g_aClassicPositionPhoneLandscape[22].flY = -58.0f;
        g_aClassicPositionPhoneLandscape[23].flY = 8.0f;
        g_aClassicPositionPhoneLandscape[24].flY = 19.0f;
        g_aClassicPartsPad[202].flHeight = 3e+01f;
        g_aClassicPartsPad[205].flHeight = 3e+01f;
        g_aClassicPartsPad[234].flHeight = 3e+01f;
        g_aClassicPositionPhoneLandscape[25].flY = 3e+01f;
        g_aClassicPositionPhoneLandscape[29].flY = 74.0f;
        g_aClassicPositionPhoneLandscape[30].flY = 85.0f;
        g_aClassicPositionPhoneLandscape[32].flX = -1.2e+02f;
        g_aClassicPositionPhoneLandscape[33].flX = -1.2e+02f;
        g_aClassicPositionPhoneLandscape[34].flX = -1.2e+02f;
        g_aClassicPositionPhoneLandscape[35].flX = -1.2e+02f;
        g_aClassicPositionPhoneLandscape[36].flX = -1.2e+02f;
        g_aClassicPositionPhoneLandscape[37].flX = -1.2e+02f;
        g_aClassicPositionPhoneLandscape[38].flX = -1.2e+02f;
        g_aClassicPositionPhoneLandscape[39].flX = -1.2e+02f;
        g_aClassicPositionPhoneLandscape[40].flX = 2e+02f;
        g_aClassicPositionPhoneLandscape[40].flY = 35.0f;
        g_aClassicPositionPhoneLandscape[35].flY = 37.0f;
        g_aClassicPositionPhoneLandscape[44].flY = 37.0f;
        g_aClassicPositionPhoneLandscape[36].flY = 48.0f;
        g_aClassicPositionPhoneLandscape[45].flY = 48.0f;
        g_aClassicPositionPhoneLandscape[37].flY = 59.0f;
        g_aClassicPositionPhoneLandscape[46].flY = 59.0f;
        g_aClassicPositionPhoneLandscape[41].flX = 1.3e+02f;
        g_aClassicPositionPhoneLandscape[42].flX = 1.3e+02f;
        g_aClassicPositionPhoneLandscape[43].flX = 1.3e+02f;
        g_aClassicPositionPhoneLandscape[44].flX = 1.3e+02f;
        g_aClassicPositionPhoneLandscape[45].flX = 1.3e+02f;
        g_aClassicPositionPhoneLandscape[46].flX = 1.3e+02f;
        g_aClassicPositionPhoneLandscape[47].flX = 1.3e+02f;
        g_aClassicPositionPhoneLandscape[48].flX = 1.3e+02f;
        g_aClassicPositionPhoneLandscape[39].flY = 81.0f;
        g_aClassicPositionPhoneLandscape[48].flY = 81.0f;
        g_aClassicPositionPhoneLandscape[49].flX = -136.0f;
        g_aClassicPositionPhoneLandscape[1].flY = 11.0f;
        g_aClassicPositionPhoneLandscape[49].flY = 11.0f;
        g_aClassicPositionPhoneLandscape[50].flY = 11.0f;
        g_aClassicPositionPhoneLandscape[51].flY = 43.0f;
        g_aClassicPositionPhoneLandscape[52].flX = -167.0f;
        g_aClassicPositionPhoneLandscape[26].flY = 41.0f;
        g_aClassicPositionPhoneLandscape[52].flY = 41.0f;
        g_aClassicPositionPhoneLandscape[53].flY = 41.0f;
        g_aClassicPositionPhoneLandscape[5].flY = -123.0f;
        g_aClassicPositionPhoneLandscape[53].flX = -123.0f;
        g_aClassicPositionPhoneLandscape[54].flX = -123.0f;
        g_aClassicPositionPhoneLandscape[55].flX = -86.0f;
        g_aClassicPositionPhoneLandscape[51].flX = -201.0f;
        g_aClassicPositionPhoneLandscape[57].flX = -201.0f;
        g_aClassicPositionPhoneLandscape[38].flY = 7e+01f;
        g_aClassicPositionPhoneLandscape[47].flY = 7e+01f;
        g_aClassicPositionPhoneLandscape[57].flY = 7e+01f;
        g_aClassicPositionPhoneLandscape[31].flX = -2e+02f;
        g_aClassicPositionPhoneLandscape[58].flX = -2e+02f;
        g_aClassicPositionPhoneLandscape[58].flY = 71.0f;
        g_aClassicPositionPhoneLandscape[59].flX = -73.0f;
        g_aClassicPositionPhoneLandscape[61].flX = 77.0f;
        g_aClassicPositionPhoneLandscape[27].flY = 53.0f;
        g_aClassicPositionPhoneLandscape[59].flY = 53.0f;
        g_aClassicPositionPhoneLandscape[61].flY = 53.0f;
        g_aClassicPartsPad[205].flX = 26.0f;
        g_aClassicPositionPhoneLandscape[34].flY = 26.0f;
        g_aClassicPositionPhoneLandscape[43].flY = 26.0f;
        g_aClassicPositionPhoneLandscape[62].flX = 26.0f;
        g_aClassicPositionPhoneLandscape[63].flX = 145.0f;
        g_aClassicPartsPad[202].flWidth = 28.0f;
        g_aClassicPositionPhoneLandscape[60].flY = 28.0f;
        g_aClassicPositionPhoneLandscape[63].flY = 28.0f;
        g_aClassicPositionPhoneLandscape[64].flX = -6.0f;
        g_aClassicPositionPhoneLandscape[65].flX = 5.0f;
        g_aClassicPositionPhoneLandscape[64].flY = 97.0f;
        g_aClassicPositionPhoneLandscape[65].flY = 97.0f;
        g_aClassicPositionPhoneLandscape[66].flY = 114.0f;
        g_aClassicPositionPhoneLandscape[19].flY = -85.0f;
        g_aClassicPositionPhoneLandscape[67].flX = -85.0f;
        g_aClassicPositionPhoneLandscape[67].flY = 3.0f;
        g_aClassicPositionPhoneLandscape[68].flX = -348.0f;
        g_aClassicPartsAnchorPad[66].x = 222.0f;
        g_aClassicPartsAnchorPad[66].y = 685.0f;
        g_aClassicPartsAnchorPad[69].x = 477.0f;
        g_aClassicPartsAnchorPad[69].y = 491.0f;
        g_aClassicPartsAnchorPad[68].x = 152.0f;
        g_aClassicPartsAnchorPad[68].y = 719.0f;
        g_aClassicPartsAnchorPad[71].x = 548.0f;
        g_aClassicPartsAnchorPad[71].y = 523.0f;
        g_aClassicPartsAnchorPad[70].x = 529.0f;
        g_aClassicPartsAnchorPad[70].y = 495.0f;
        g_aClassicPositionPhoneLandscape[0].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[0].flY = 0.0f;
        g_aClassicPositionPhoneLandscape[0].nAnchorMode = 0;
        g_aClassicPositionPhoneLandscape[1].nAnchorMode = 3;
        g_aClassicPositionPhoneLandscape[2].nAnchorMode = 3;
        g_aClassicPositionPhoneLandscape[3].flX = -214.0f;
        g_aClassicPositionPhoneLandscape[69].flX = -198.0f;
        g_aClassicPositionPhoneLandscape[3].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[4].flX = 214.0f;
        g_aClassicPositionPhoneLandscape[4].flY = -28.0f;
        g_aClassicPositionPhoneLandscape[4].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[5].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[6].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[7].flY = -119.0f;
        g_aClassicPositionPhoneLandscape[7].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[8].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[9].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[10].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[11].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[12].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[13].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[14].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[15].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[16].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[17].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[18].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[19].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[20].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[21].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[22].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[23].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[23].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[24].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[24].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[25].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[25].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[26].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[26].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[27].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[27].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[28].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[70].flX = -75.0f;
        g_aClassicPositionPhoneLandscape[28].flY = 63.0f;
        g_aClassicPositionPhoneLandscape[28].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[29].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[29].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[30].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[30].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[31].flY = 64.0f;
        g_aClassicPositionPhoneLandscape[31].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[71].flX = 198.0f;
        g_aClassicPositionPhoneLandscape[72].flX = 198.0f;
        g_aClassicPositionPhoneLandscape[32].flY = 4.0f;
        g_aClassicPositionPhoneLandscape[32].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[33].flY = 15.0f;
        g_aClassicPositionPhoneLandscape[33].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[34].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[35].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[36].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[37].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[38].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[39].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[40].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[41].flY = 4.0f;
        g_aClassicPositionPhoneLandscape[41].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[42].flY = 15.0f;
        g_aClassicPositionPhoneLandscape[42].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[43].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[44].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[45].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[46].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[47].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[48].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[49].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[67].nAnchorMode = 3;
        g_aClassicPositionPhoneLandscape[68].nAnchorMode = 3;
        g_aClassicPositionPhoneLandscape[69].nAnchorMode = 3;
        g_aClassicPositionPhoneLandscape[70].nAnchorMode = 3;
        g_aClassicPositionPhoneLandscape[71].nAnchorMode = 3;
        g_aClassicPositionPhoneLandscape[72].nAnchorMode = 3;
        g_aClassicPositionPhoneLandscape[50].flX = 73.0f;
        g_aClassicPositionPhoneLandscape[50].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[51].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[52].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[53].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[73].nAnchorMode = 2;
        g_aClassicPositionPhoneLandscape[54].flY = 55.0f;
        g_aClassicPositionPhoneLandscape[54].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[55].flY = 57.0f;
        g_aClassicPositionPhoneLandscape[55].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[74].flX = -106.0f;
        g_aClassicPositionPhoneLandscape[73].flY = -24.0f;
        g_aClassicPositionPhoneLandscape[74].flY = -24.0f;
        g_aClassicPositionPhoneLandscape[75].flX = -103.0f;
        g_aClassicPositionPhoneLandscape[56].flX = -122.0f;
        g_aClassicPositionPhoneLandscape[56].flY = 55.0f;
        g_aClassicPositionPhoneLandscape[56].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[57].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[58].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[59].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[76].flY = -28.0f;
        g_aClassicPositionPhoneLandscape[60].flX = -61.0f;
        g_aClassicPositionPhoneLandscape[60].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[61].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[62].flY = 64.0f;
        g_aClassicPositionPhoneLandscape[62].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[63].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[64].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[65].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[77].flX = -214.0f;
        g_aClassicPositionPhoneLandscape[66].flX = 1.6e+02f;
        g_aClassicPositionPhoneLandscape[66].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[68].flY = 0.0f;
        g_aClassicPositionPhoneLandscape[69].flY = 0.0f;
        g_aClassicPositionPhoneLandscape[70].flY = 0.0f;
        g_aClassicPositionPhoneLandscape[71].flY = 0.0f;
        g_aClassicPositionPhoneLandscape[72].flY = 0.0f;
        g_aClassicPositionPhoneLandscape[73].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[74].nAnchorMode = 5;
        g_aClassicPositionPhoneLandscape[78].flX = 214.0f;
        g_aClassicPositionPhoneLandscape[78].flY = 1.1e+02f;
        g_aClassicPositionPhoneLandscape[75].flY = -53.0f;
        g_aClassicPositionPhoneLandscape[75].nAnchorMode = 5;
        g_aClassicPositionPhoneLandscape[76].flX = 0.0f;
        g_aClassicPositionPhoneLandscape[76].nAnchorMode = 5;
        g_aClassicPositionPhoneLandscape[79].flX = -61.0f;
        g_aClassicPositionPhoneLandscape[80].flX = 69.0f;
        g_aClassicPositionPhoneLandscape[79].flY = -21.0f;
        g_aClassicPositionPhoneLandscape[80].flY = -21.0f;
        g_aClassicPositionPhoneLandscape[77].flY = -12.0f;
        g_aClassicPositionPhoneLandscape[77].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[78].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[79].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[80].nAnchorMode = 4;
        g_aClassicPositionPhoneLandscape[81].flX = 4.0f;
        g_aClassicPositionPhoneLandscape[81].flY = -13.0f;
        g_aClassicPositionPhoneLandscape[81].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[0].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[0].flY = -164.0f;
        g_aClassicSeparatorPhonePortrait[1].flX = -42.0f;
        g_aClassicSeparatorPhonePortrait[1].flY = -56.0f;
        g_aClassicSeparatorPhonePortrait[1].flWidth = 83.0f;
        g_aClassicSeparatorPhonePortrait[1].flHeight = 1.5707964f;
        g_aClassicSeparatorPhonePortrait[3].flX = -49.0f;
        g_aClassicSeparatorPhonePortrait[2].flX = -132.0f;
        g_aClassicSeparatorPhonePortrait[2].flY = -1.4e+02f;
        g_aClassicSeparatorPhonePortrait[2].flWidth = 1.0f;
        g_aClassicSeparatorPhonePortrait[2].flHeight = -1.5707964f;
        g_aClassicSeparatorPhonePortrait[3].flY = -139.0f;
        g_aClassicSeparatorPhonePortrait[4].flX = -133.0f;
        g_aClassicSeparatorPhonePortrait[4].flY = -57.0f;
        g_aClassicSeparatorPhonePortrait[6].flY = -139.0f;
        g_aClassicSeparatorPhonePortrait[6].flX = -5e+01f;
        g_aClassicSeparatorPhonePortrait[9].flX = -5e+01f;
        g_aClassicPartsPad[181].flX = 0.0f;
        g_aClassicSeparatorPhonePortrait[5].flX = -5e+01f;
        g_aClassicSeparatorPhonePortrait[5].flY = -56.0f;
        g_aClassicSeparatorPhonePortrait[5].flWidth = 1.0f;
        g_aClassicSeparatorPhonePortrait[5].flHeight = 1.5707964f;
        g_aClassicSeparatorPhonePortrait[7].flX = -132.0f;
        g_aClassicSeparatorPhonePortrait[7].flY = -139.0f;
        g_aClassicSeparatorPhonePortrait[7].flWidth = 82.0f;
        g_aClassicSeparatorPhonePortrait[7].flHeight = -1.5707964f;
        g_aClassicSeparatorPhonePortrait[8].flX = -132.0f;
        g_aClassicSeparatorPhonePortrait[8].flY = -57.0f;
        g_aClassicSeparatorPhonePortrait[9].flY = -57.0f;
        g_aClassicSeparatorPhonePortrait[10].flX = -33.0f;
        g_aClassicSeparatorPhonePortrait[10].flY = -132.0f;
        g_aClassicSeparatorPhonePortrait[10].flWidth = 165.0f;
        g_aClassicSeparatorPhonePortrait[10].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[11].flX = -33.0f;
        g_aClassicSeparatorPhonePortrait[11].flY = -93.0f;
        g_aClassicSeparatorPhonePortrait[11].flWidth = 165.0f;
        g_aClassicSeparatorPhonePortrait[11].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[12].flX = -48.0f;
        g_aClassicSeparatorPhonePortrait[12].flY = 21.0f;
        g_aClassicSeparatorPhonePortrait[12].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[13].flX = -48.0f;
        g_aClassicSeparatorPhonePortrait[13].flY = 35.0f;
        g_aClassicSeparatorPhonePortrait[13].flWidth = 96.0f;
        g_aClassicSeparatorPhonePortrait[13].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[14].flX = -48.0f;
        g_aClassicSeparatorPhonePortrait[14].flY = 49.0f;
        g_aClassicSeparatorPhonePortrait[14].flWidth = 96.0f;
        g_aClassicSeparatorPhonePortrait[14].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[14].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[15].flX = -48.0f;
        g_aClassicSeparatorPhonePortrait[15].flY = 63.0f;
        g_aClassicSeparatorPhonePortrait[15].flWidth = 96.0f;
        g_aClassicSeparatorPhonePortrait[15].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[16].flX = -48.0f;
        g_aClassicSeparatorPhonePortrait[16].flY = 77.0f;
        g_aClassicSeparatorPhonePortrait[16].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[17].flX = -48.0f;
        g_aClassicSeparatorPhonePortrait[17].flY = 91.0f;
        g_aClassicSeparatorPhonePortrait[17].flWidth = 96.0f;
        g_aClassicSeparatorPhonePortrait[17].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[18].flX = -48.0f;
        g_aClassicSeparatorPhonePortrait[18].flY = 105.0f;
        g_aClassicSeparatorPhonePortrait[18].flWidth = 96.0f;
        g_aClassicSeparatorPhonePortrait[18].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[19].flX = -48.0f;
        g_aClassicSeparatorPhonePortrait[19].flY = 119.0f;
        g_aClassicSeparatorPhonePortrait[19].flWidth = 96.0f;
        g_aClassicSeparatorPhonePortrait[20].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[20].flY = -3.0f;
        g_aClassicSeparatorPhonePortrait[20].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[21].flX = -78.0f;
        g_aClassicSeparatorPhonePortrait[21].flY = -3.0f;
        g_aClassicSeparatorPhonePortrait[21].flWidth = 23.0f;
        g_aClassicSeparatorPhonePortrait[21].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[22].flY = 21.0f;
        g_aClassicSeparatorPhonePortrait[22].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[23].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[23].flY = 35.0f;
        g_aClassicSeparatorPhonePortrait[23].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[23].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[24].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[24].flY = 49.0f;
        g_aClassicSeparatorPhonePortrait[26].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[26].flY = 77.0f;
        g_aClassicSeparatorPhonePortrait[26].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[26].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[26].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[27].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[27].flY = 91.0f;
        g_aClassicSeparatorPhonePortrait[27].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[27].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[28].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[28].flY = 105.0f;
        g_aClassicSeparatorPhonePortrait[28].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[29].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[29].flY = 119.0f;
        g_aClassicSeparatorPhonePortrait[29].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[29].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[30].flX = 55.0f;
        g_aClassicSeparatorPhonePortrait[30].flY = -3.0f;
        g_aClassicSeparatorPhonePortrait[30].flWidth = 21.0f;
        g_aClassicSeparatorPhonePortrait[30].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[30].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[31].flX = 113.0f;
        g_aClassicSeparatorPhonePortrait[31].flY = -3.0f;
        g_aClassicSeparatorPhonePortrait[31].flWidth = 21.0f;
        g_aClassicSeparatorPhonePortrait[31].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[32].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[33].flX = 55.0f;
        g_aClassicSeparatorPhonePortrait[33].flY = 35.0f;
        g_aClassicSeparatorPhonePortrait[33].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[33].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[36].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[37].flX = 55.0f;
        g_aClassicSeparatorPhonePortrait[37].flY = 91.0f;
        g_aClassicSeparatorPhonePortrait[37].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[37].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[35].flX = 55.0f;
        g_aClassicSeparatorPhonePortrait[38].flX = 55.0f;
        g_aClassicPartsPad[181].flY = 0.0f;
        g_aClassicSeparatorPhonePortrait[0].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[1].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[2].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[3].flWidth = 1.0f;
        g_aClassicSeparatorPhonePortrait[22].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[25].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[32].flX = 55.0f;
        g_aClassicSeparatorPhonePortrait[32].flY = 21.0f;
        g_aClassicSeparatorPhonePortrait[35].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[38].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[38].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[39].flX = 55.0f;
        g_aClassicSeparatorPhonePortrait[39].flY = 119.0f;
        g_aClassicSeparatorPhonePortrait[39].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[39].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[22].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[25].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[41].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[3].flHeight = 3.1415927f;
        g_aClassicSeparatorPhonePortrait[3].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[4].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[5].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[6].flWidth = 82.0f;
        g_aClassicSeparatorPhonePortrait[6].flHeight = 3.1415927f;
        g_aClassicSeparatorPhonePortrait[6].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[7].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[8].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[9].flWidth = 82.0f;
        g_aClassicSeparatorPhonePortrait[41].flY = -12.0f;
        g_aClassicSeparatorPhonePortrait[9].flHeight = 1.5707964f;
        g_aClassicSeparatorPhonePortrait[9].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[10].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[11].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[13].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[15].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[17].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[18].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[19].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[19].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[21].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[22].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[23].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[24].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[25].flY = 63.0f;
        g_aClassicSeparatorPhonePortrait[25].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[25].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[27].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[29].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[31].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[33].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[34].flX = 55.0f;
        g_aClassicSeparatorPhonePortrait[34].flY = 49.0f;
        g_aClassicSeparatorPhonePortrait[34].flWidth = 76.0f;
        g_aClassicSeparatorPhonePortrait[34].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[34].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[35].flY = 63.0f;
        g_aClassicSeparatorPhonePortrait[35].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[35].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[36].flX = 55.0f;
        g_aClassicSeparatorPhonePortrait[36].flY = 77.0f;
        g_aClassicSeparatorPhonePortrait[37].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[38].flY = 105.0f;
        g_aClassicSeparatorPhonePortrait[38].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[39].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[40].flX = 88.0f;
        g_aClassicSeparatorPhonePortrait[40].flY = -7.0f;
        g_aClassicSeparatorPhonePortrait[40].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[41].flWidth = 94.0f;
        g_aClassicSeparatorPhonePortrait[41].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[41].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[42].flX = 37.0f;
        g_aClassicSeparatorPhonePortrait[42].flY = -12.0f;
        g_aClassicSeparatorPhonePortrait[42].flWidth = 94.0f;
        g_aClassicSeparatorPhonePortrait[42].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[42].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[43].flX = -131.0f;
        g_aClassicSeparatorPhonePortrait[43].flY = 65.0f;
        g_aClassicSeparatorPhonePortrait[43].flWidth = 89.0f;
        g_aClassicSeparatorPhonePortrait[43].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[43].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[44].flX = 42.0f;
        g_aClassicSeparatorPhonePortrait[44].flY = 65.0f;
        g_aClassicSeparatorPhonePortrait[44].nAnchorMode = 4;
        g_aClassicSeparatorPhonePortrait[45].flX = -98.0f;
        g_aClassicSeparatorPhonePortrait[45].flY = 105.0f;
        g_aClassicSeparatorPhonePortrait[45].flWidth = 114.0f;
        g_aClassicSeparatorPhonePortrait[45].flHeight = 0.0f;
        g_aClassicSeparatorPhonePortrait[45].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[3].flX = -121.0f;
        g_aClassicPartsAnchorPad[73].x = 548.0f;
        g_aClassicPartsAnchorPad[73].y = 549.0f;
        g_aClassicPartsAnchorPad[72].x = 478.0f;
        g_aClassicPartsAnchorPad[72].y = 537.0f;
        g_aClassicPartsAnchorPad[75].x = 548.0f;
        g_aClassicPartsAnchorPad[75].y = 575.0f;
        g_aClassicPartsAnchorPad[74].x = 478.0f;
        g_aClassicPartsAnchorPad[74].y = 563.0f;
        g_aClassicSeparatorPhoneLandscape[3].flWidth = 1.0f;
        g_aClassicSeparatorPhoneLandscape[3].flY = -119.0f;
        g_aClassicSeparatorPhoneLandscape[6].flY = -119.0f;
        g_aClassicPartsAnchorPad[77].x = 548.0f;
        g_aClassicPartsAnchorPad[77].y = 601.0f;
        g_aClassicPartsAnchorPad[76].x = 478.0f;
        g_aClassicPartsAnchorPad[76].y = 589.0f;
        g_aClassicPartsAnchorPad[79].x = 548.0f;
        g_aClassicPartsAnchorPad[79].y = 627.0f;
        g_aClassicPartsAnchorPad[78].x = 478.0f;
        g_aClassicPartsAnchorPad[78].y = 615.0f;
        g_aClassicSeparatorPhoneLandscape[3].flHeight = 3.1415927f;
        g_aClassicSeparatorPhoneLandscape[6].flHeight = 3.1415927f;
        g_aClassicSeparatorPhoneLandscape[6].flX = -122.0f;
        g_aClassicSeparatorPhoneLandscape[9].flX = -122.0f;
        g_aClassicSeparatorPhoneLandscape[9].flY = -37.0f;
        g_aClassicSeparatorPhoneLandscape[6].flWidth = 82.0f;
        g_aClassicSeparatorPhoneLandscape[9].flWidth = 82.0f;
        g_aClassicPartsAnchorPad[81].x = 548.0f;
        g_aClassicPartsAnchorPad[81].y = 653.0f;
        g_aClassicPartsAnchorPad[80].x = 478.0f;
        g_aClassicPartsAnchorPad[80].y = 641.0f;
        g_aClassicPartsAnchorPad[83].x = 548.0f;
        g_aClassicPartsAnchorPad[83].y = 685.0f;
        g_aClassicPartsAnchorPad[82].x = 478.0f;
        g_aClassicPartsAnchorPad[82].y = 667.0f;
        g_aClassicPartsAnchorPad[85].x = 478.0f;
        g_aClassicPartsAnchorPad[85].y = 719.0f;
        g_aClassicPartsAnchorPad[84].x = 562.0f;
        g_aClassicPartsAnchorPad[84].y = 705.0f;
        g_aClassicPartsAnchorPad[87].x = 153.0f;
        g_aClassicPartsAnchorPad[87].y = 8.1e+02f;
        g_aClassicPartsAnchorPad[86].x = 151.0f;
        g_aClassicPartsAnchorPad[86].y = 805.0f;
        g_aClassicPartsAnchorPad[88].x = 264.0f;
        g_aClassicPartsAnchorPad[88].y = 801.0f;
        g_aClassicPartsAnchorPad[89].x = 283.0f;
        g_aClassicPartsAnchorPad[89].y = 803.0f;
        g_aClassicPartsAnchorPad[91].x = 422.0f;
        g_aClassicPartsAnchorPad[91].y = 806.0f;
        g_aClassicPartsAnchorPad[90].x = 395.0f;
        g_aClassicPartsAnchorPad[90].y = 808.0f;
        g_aClassicSeparatorPhoneLandscape[9].flHeight = 1.5707964f;
        g_aClassicSeparatorPhoneLandscape[12].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[13].flX = -53.0f;
        g_aClassicSeparatorPhoneLandscape[13].flY = 24.0f;
        g_aClassicSeparatorPhoneLandscape[13].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[13].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[14].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[15].flX = -53.0f;
        g_aClassicSeparatorPhoneLandscape[15].flY = 46.0f;
        g_aClassicSeparatorPhoneLandscape[15].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[15].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[16].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[17].flX = -53.0f;
        g_aClassicSeparatorPhoneLandscape[17].flY = 68.0f;
        g_aClassicSeparatorPhoneLandscape[17].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[17].flHeight = 0.0f;
        g_aClassicPartsAnchorPad[93].x = 588.0f;
        g_aClassicPartsAnchorPad[93].y = 808.0f;
        g_aClassicPartsAnchorPad[92].x = 491.0f;
        g_aClassicPartsAnchorPad[92].y = 808.0f;
        g_aClassicPartsAnchorPad[95].x = 153.0f;
        g_aClassicPartsAnchorPad[95].y = 848.0f;
        g_aClassicPartsAnchorPad[94].x = 151.0f;
        g_aClassicPartsAnchorPad[94].y = 843.0f;
        g_aClassicPartsAnchorPad[97].x = 283.0f;
        g_aClassicPartsAnchorPad[97].y = 841.0f;
        g_aClassicPartsAnchorPad[96].x = 264.0f;
        g_aClassicPartsAnchorPad[96].y = 839.0f;
        g_aClassicPartsAnchorPad[99].x = 422.0f;
        g_aClassicPartsAnchorPad[99].y = 844.0f;
        g_aClassicPartsAnchorPad[98].x = 395.0f;
        g_aClassicPartsAnchorPad[98].y = 846.0f;
        g_aClassicPartsAnchorPad[101].x = 588.0f;
        g_aClassicPartsAnchorPad[101].y = 846.0f;
        g_aClassicPartsAnchorPad[100].x = 491.0f;
        g_aClassicPartsAnchorPad[100].y = 846.0f;
        g_aClassicPartsAnchorPad[103].x = 262.0f;
        g_aClassicPartsAnchorPad[103].y = 537.0f;
        g_aClassicPartsAnchorPad[102].x = 207.0f;
        g_aClassicPartsAnchorPad[102].y = 544.0f;
        g_aClassicPartsAnchorPad[105].x = 3.5e+02f;
        g_aClassicPartsAnchorPad[105].y = 564.0f;
        g_aClassicPartsAnchorPad[104].x = 3.5e+02f;
        g_aClassicPartsAnchorPad[104].y = 537.0f;
        g_aClassicPartsAnchorPad[107].x = 416.0f;
        g_aClassicPartsAnchorPad[107].y = 5.7e+02f;
        g_aClassicPartsAnchorPad[106].x = 3.5e+02f;
        g_aClassicPartsAnchorPad[106].y = 564.0f;
        g_aClassicSeparatorPhoneLandscape[19].flX = -53.0f;
        g_aClassicSeparatorPhoneLandscape[19].flY = 9e+01f;
        g_aClassicSeparatorPhoneLandscape[20].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[21].flX = -196.0f;
        g_aClassicSeparatorPhoneLandscape[21].flY = 34.0f;
        g_aClassicSeparatorPhoneLandscape[21].flWidth = 23.0f;
        g_aClassicSeparatorPhoneLandscape[21].flHeight = 1.5707964f;
        g_aClassicSeparatorPhoneLandscape[22].flY = 13.0f;
        g_aClassicSeparatorPhoneLandscape[22].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[23].flX = -178.0f;
        g_aClassicSeparatorPhoneLandscape[23].flY = 24.0f;
        g_aClassicSeparatorPhoneLandscape[23].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[23].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[22].flX = -178.0f;
        g_aClassicSeparatorPhoneLandscape[25].flX = -178.0f;
        g_aClassicSeparatorPhoneLandscape[26].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[27].flX = -178.0f;
        g_aClassicSeparatorPhoneLandscape[27].flY = 68.0f;
        g_aClassicSeparatorPhoneLandscape[27].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[27].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[28].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[29].flX = -178.0f;
        g_aClassicSeparatorPhoneLandscape[29].flY = 9e+01f;
        g_aClassicSeparatorPhoneLandscape[29].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[29].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[30].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[31].flX = 195.0f;
        g_aClassicSeparatorPhoneLandscape[31].flY = 34.0f;
        g_aClassicSeparatorPhoneLandscape[31].flWidth = 23.0f;
        g_aClassicSeparatorPhoneLandscape[31].flHeight = 1.5707964f;
        g_aClassicSeparatorPhoneLandscape[32].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[33].flX = 73.0f;
        g_aClassicSeparatorPhoneLandscape[33].flY = 24.0f;
        g_aClassicSeparatorPhoneLandscape[33].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[33].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[36].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[37].flX = 73.0f;
        g_aClassicSeparatorPhoneLandscape[37].flY = 68.0f;
        g_aClassicSeparatorPhoneLandscape[37].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[37].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[35].flX = 73.0f;
        g_aClassicSeparatorPhoneLandscape[38].flX = 73.0f;
        g_aClassicSeparatorPhoneLandscape[38].flY = 79.0f;
        g_aClassicPartsAnchorPad[109].x = 208.0f;
        g_aClassicPartsAnchorPad[109].y = 595.0f;
        g_aClassicPartsAnchorPad[108].x = 207.0f;
        g_aClassicPartsAnchorPad[108].y = 594.0f;
        g_aClassicSeparatorPhoneLandscape[19].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[22].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[25].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[35].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[38].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[38].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[39].flX = 73.0f;
        g_aClassicSeparatorPhoneLandscape[39].flY = 9e+01f;
        g_aClassicSeparatorPhoneLandscape[39].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[39].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[41].flX = -202.0f;
        g_aClassicPartsAnchorPad[111].x = 453.0f;
        g_aClassicPartsAnchorPad[111].y = 561.0f;
        g_aClassicPartsAnchorPad[110].x = 445.0f;
        g_aClassicPartsAnchorPad[110].y = 561.0f;
        g_aClassicPartsAnchorPad[113].x = 503.0f;
        g_aClassicPartsAnchorPad[113].y = 539.0f;
        g_aClassicPartsAnchorPad[112].x = 461.0f;
        g_aClassicPartsAnchorPad[112].y = 561.0f;
        g_aClassicPartsAnchorPad[115].x = 334.0f;
        g_aClassicPartsAnchorPad[115].y = 746.0f;
        g_aClassicPartsAnchorPad[114].x = 255.0f;
        g_aClassicPartsAnchorPad[114].y = 733.0f;
        g_aClassicPartsAnchorPad[117].x = 0.0f;
        g_aClassicPartsAnchorPad[117].y = 0.0f;
        g_aClassicPartsAnchorPad[116].x = 334.0f;
        g_aClassicPartsAnchorPad[116].y = 767.0f;
        g_aClassicPartsAnchorPad[119].x = 768.0f;
        g_aClassicPartsAnchorPad[119].y = 0.0f;
        g_aClassicPartsAnchorPad[118].x = 3.2e+02f;
        g_aClassicPartsAnchorPad[118].y = 0.0f;
        g_aClassicPartsAnchorPad[121].x = 768.0f;
        g_aClassicPartsAnchorPad[121].y = 964.0f;
        g_aClassicPartsAnchorPad[120].x = 0.0f;
        g_aClassicPartsAnchorPad[120].y = 964.0f;
        g_aClassicPartsAnchorPad[123].x = 219.0f;
        g_aClassicPartsAnchorPad[123].y = 86.0f;
        g_aClassicPartsAnchorPad[122].x = 179.0f;
        g_aClassicPartsAnchorPad[122].y = 86.0f;
        g_aClassicPartsAnchorPad[125].x = 321.0f;
        g_aClassicPartsAnchorPad[125].y = 99.0f;
        g_aClassicPartsAnchorPad[124].x = 588.0f;
        g_aClassicPartsAnchorPad[124].y = 86.0f;
        g_aClassicPartsAnchorPad[127].x = 219.0f;
        g_aClassicPartsAnchorPad[127].y = 378.0f;
        g_aClassicPartsAnchorPad[126].x = 179.0f;
        g_aClassicPartsAnchorPad[126].y = 378.0f;
        g_aClassicPartsAnchorPad[129].x = 238.0f;
        g_aClassicPartsAnchorPad[129].y = 391.0f;
        g_aClassicPartsAnchorPad[128].x = 588.0f;
        g_aClassicPartsAnchorPad[128].y = 378.0f;
        g_aClassicSeparatorPhoneLandscape[0].flX = -102.0f;
        g_aClassicSeparatorPhoneLandscape[0].flY = -103.0f;
        g_aClassicSeparatorPhoneLandscape[1].flX = -112.0f;
        g_aClassicSeparatorPhoneLandscape[1].flY = -41.0f;
        g_aClassicSeparatorPhoneLandscape[1].flWidth = 83.0f;
        g_aClassicSeparatorPhoneLandscape[1].flHeight = 1.5707964f;
        g_aClassicSeparatorPhoneLandscape[2].flX = -204.0f;
        g_aClassicSeparatorPhoneLandscape[2].flY = -1.2e+02f;
        g_aClassicSeparatorPhoneLandscape[2].flWidth = 1.0f;
        g_aClassicSeparatorPhoneLandscape[2].flHeight = -1.5707964f;
        g_aClassicSeparatorPhoneLandscape[4].flX = -205.0f;
        g_aClassicSeparatorPhoneLandscape[4].flY = -37.0f;
        g_aClassicSeparatorPhoneLandscape[5].flX = -122.0f;
        g_aClassicSeparatorPhoneLandscape[5].flY = -36.0f;
        g_aClassicSeparatorPhoneLandscape[5].flWidth = 1.0f;
        g_aClassicSeparatorPhoneLandscape[5].flHeight = 1.5707964f;
        g_aClassicSeparatorPhoneLandscape[7].flX = -204.0f;
        g_aClassicSeparatorPhoneLandscape[7].flY = -119.0f;
        g_aClassicSeparatorPhoneLandscape[7].flWidth = 82.0f;
        g_aClassicSeparatorPhoneLandscape[7].flHeight = -1.5707964f;
        g_aClassicSeparatorPhoneLandscape[8].flX = -204.0f;
        g_aClassicSeparatorPhoneLandscape[8].flY = -37.0f;
        g_aClassicSeparatorPhoneLandscape[10].flX = -101.0f;
        g_aClassicSeparatorPhoneLandscape[10].flY = -72.0f;
        g_aClassicSeparatorPhoneLandscape[10].flWidth = 305.0f;
        g_aClassicSeparatorPhoneLandscape[10].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[11].flX = -101.0f;
        g_aClassicSeparatorPhoneLandscape[11].flY = -72.0f;
        g_aClassicSeparatorPhoneLandscape[11].flWidth = 0.0f;
        g_aClassicSeparatorPhoneLandscape[11].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[12].flX = -53.0f;
        g_aClassicSeparatorPhoneLandscape[12].flY = 13.0f;
        g_aClassicSeparatorPhoneLandscape[14].flX = -53.0f;
        g_aClassicSeparatorPhoneLandscape[14].flY = 35.0f;
        g_aClassicSeparatorPhoneLandscape[14].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[14].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[16].flX = -53.0f;
        g_aClassicSeparatorPhoneLandscape[16].flY = 57.0f;
        g_aClassicSeparatorPhoneLandscape[18].flX = -53.0f;
        g_aClassicSeparatorPhoneLandscape[18].flY = 79.0f;
        g_aClassicSeparatorPhoneLandscape[18].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[18].flHeight = 0.0f;
        g_aClassicPartsPad[202].flY = 15.0f;
        g_aClassicPartsPad[205].flY = 15.0f;
        g_aClassicSeparatorPhoneLandscape[0].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[1].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[2].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[3].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[4].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[5].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[6].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[7].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[8].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[9].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[10].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[11].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[13].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[15].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[17].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[18].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[19].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[19].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[20].flX = -196.0f;
        g_aClassicSeparatorPhoneLandscape[20].flY = 9e+01f;
        g_aClassicSeparatorPhoneLandscape[21].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[22].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[23].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[24].flX = -178.0f;
        g_aClassicSeparatorPhoneLandscape[24].flY = 35.0f;
        g_aClassicSeparatorPhoneLandscape[24].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[41].flY = 15.0f;
        g_aClassicSeparatorPhoneLandscape[25].flY = 46.0f;
        g_aClassicSeparatorPhoneLandscape[25].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[25].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[26].flX = -178.0f;
        g_aClassicSeparatorPhoneLandscape[26].flY = 57.0f;
        g_aClassicSeparatorPhoneLandscape[26].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[26].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[27].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[28].flX = -178.0f;
        g_aClassicSeparatorPhoneLandscape[28].flY = 79.0f;
        g_aClassicSeparatorPhoneLandscape[29].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[30].flX = 195.0f;
        g_aClassicSeparatorPhoneLandscape[30].flY = 9e+01f;
        g_aClassicSeparatorPhoneLandscape[30].flWidth = 23.0f;
        g_aClassicSeparatorPhoneLandscape[30].flHeight = 1.5707964f;
        g_aClassicSeparatorPhoneLandscape[31].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[32].flX = 73.0f;
        g_aClassicSeparatorPhoneLandscape[32].flY = 13.0f;
        g_aClassicSeparatorPhoneLandscape[33].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[34].flX = 73.0f;
        g_aClassicSeparatorPhoneLandscape[34].flY = 35.0f;
        g_aClassicSeparatorPhoneLandscape[34].flWidth = 105.0f;
        g_aClassicSeparatorPhoneLandscape[34].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[34].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[35].flY = 46.0f;
        g_aClassicSeparatorPhoneLandscape[35].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[35].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[36].flX = 73.0f;
        g_aClassicSeparatorPhoneLandscape[36].flY = 57.0f;
        g_aClassicSeparatorPhoneLandscape[37].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[38].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[39].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[40].flX = 8.0f;
        g_aClassicSeparatorPhoneLandscape[40].flY = 85.0f;
        g_aClassicSeparatorPhoneLandscape[40].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[41].flWidth = 63.0f;
        g_aClassicSeparatorPhoneLandscape[41].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[41].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[42].flX = -66.0f;
        g_aClassicSeparatorPhoneLandscape[42].flY = 15.0f;
        g_aClassicSeparatorPhoneLandscape[42].flWidth = 63.0f;
        g_aClassicSeparatorPhoneLandscape[42].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[42].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[43].flX = 2e+01f;
        g_aClassicSeparatorPhoneLandscape[43].flY = 15.0f;
        g_aClassicSeparatorPhoneLandscape[43].flWidth = 49.0f;
        g_aClassicSeparatorPhoneLandscape[43].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[43].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[44].flX = 153.0f;
        g_aClassicSeparatorPhoneLandscape[44].flY = 15.0f;
        g_aClassicSeparatorPhoneLandscape[44].nAnchorMode = 4;
        g_aClassicSeparatorPhoneLandscape[45].flX = 2e+01f;
        g_aClassicSeparatorPhoneLandscape[45].flY = 61.0f;
        g_aClassicSeparatorPhoneLandscape[45].flWidth = 114.0f;
        g_aClassicSeparatorPhoneLandscape[45].flHeight = 0.0f;
        g_aClassicSeparatorPhoneLandscape[45].nAnchorMode = 4;
        g_aClassicPartsAnchorPad[1].x = 263.0f;
        g_aClassicPartsAnchorPad[1].y = 937.0f;
        g_aClassicPositionPhoneState[0].flX = g_aClassicPartsAnchorPad[1].x;
        g_aClassicPartsPad[186].flX = 0.0f;
        g_aClassicPartsPad[186].flY = 0.0f;
        g_aClassicPartsPad[189].flX = 0.0f;
        g_aClassicPartsPad[189].flY = 0.0f;
        g_aClassicPartsPad[194].flX = 0.0f;
        g_aClassicPartsPad[194].flY = 0.0f;
        g_aClassicPartsPad[197].flX = 0.0f;
        g_aClassicPartsPad[197].flY = 0.0f;
        g_aClassicPartsPad[210].flX = 0.0f;
        g_aClassicPartsPad[210].flY = 0.0f;
        g_aClassicPartsPad[213].flX = 0.0f;
        g_aClassicPartsPad[213].flY = 0.0f;
        g_aClassicPartsPad[218].flX = 0.0f;
        g_aClassicPartsPad[218].flY = 0.0f;
        g_aClassicPartsPad[221].flX = 0.0f;
        g_aClassicPartsPad[221].flY = 0.0f;
        g_aClassicPartsPad[226].flX = 0.0f;
        g_aClassicPartsPad[226].flY = 0.0f;
        g_aClassicPartsPad[229].flX = 0.0f;
        g_aClassicPartsPad[229].flY = 0.0f;
        g_aClassicPartsPad[234].flX = 0.0f;
        g_aClassicPartsPad[234].flY = 0.0f;
        g_aClassicPartsPad[237].flX = 0.0f;
        g_aClassicPartsPad[237].flY = 0.0f;
        g_aClassicPositionPhoneState[0].flY = g_aClassicPartsAnchorPad[1].y;
        g_aClassicPartsPad[1].flWidth = 242.0f;
        g_aClassicPartsPad[1].flHeight = 6e+01f;
        g_aClassicPositionPhoneState[0].flWidth = g_aClassicPartsPad[1].flWidth;
        g_aClassicPositionPhoneState[0].flHeight = g_aClassicPartsPad[1].flHeight;
        g_aClassicPositionPhoneState[2].nAnchorMode = 0;
        g_aClassicPositionPhoneState[3].flX = 589.0f;
        g_aClassicPositionPhoneState[3].flY = 898.0f;
        g_aClassicPositionPhoneState[3].flWidth = 64.0f;
        g_aClassicPositionPhoneState[3].flHeight = 54.0f;
        g_aClassicPositionPhoneState[3].nAnchorMode = 0;
        g_aClassicPositionPhoneState[0].nAnchorMode = 0;
        g_aClassicPositionPhoneState[1].flX = 108.0f;
        g_aClassicPositionPhoneState[1].flY = 397.0f;
        g_aClassicPositionPhoneState[1].flWidth = 54.0f;
        g_aClassicPositionPhoneState[1].flHeight = 54.0f;
        g_aClassicPositionPhoneState[1].nAnchorMode = 0;
        g_aClassicPositionPhoneState[2].flX = 611.0f;
        g_aClassicPositionPhoneState[2].flY = 397.0f;
        g_aClassicPositionPhoneState[2].flWidth = 54.0f;
        g_aClassicPositionPhoneState[2].flHeight = 54.0f;
        g_aClassicPositionPhoneStatePortrait[2].nAnchorMode = 0;
        g_aClassicPositionPhoneStatePortrait[3].flX = 88.0f;
        g_aClassicPositionPhoneStatePortrait[3].flY = 144.0f;
        g_aClassicPositionPhoneStatePortrait[3].flWidth = 46.0f;
        g_aClassicPositionPhoneStatePortrait[0].flX = -88.0f;
        g_aClassicPositionPhoneStatePortrait[0].flY = -48.0f;
        g_aClassicPositionPhoneStatePortrait[0].nAnchorMode = 5;
        g_aClassicPositionPhoneStatePortrait[1].nAnchorMode = 0;
        g_aClassicPositionPhoneStatePortrait[3].flHeight = 44.0f;
        g_aClassicPositionPhoneStatePortrait[3].nAnchorMode = 4;
        g_aClassicPositionPhoneStateLandscape[0].nAnchorMode = 5;
        g_aClassicPositionPhoneStateLandscape[3].flX = 1.6e+02f;
        g_aClassicPositionPhoneStateLandscape[3].flY = 103.0f;
        g_aClassicPositionPhoneStateLandscape[3].flWidth = 57.0f;
        g_aClassicPositionPhoneStateLandscape[0].flX = -85.0f;
        g_aClassicPositionPhoneStateLandscape[0].flY = -42.0f;
        g_aClassicPositionPhoneStateLandscape[1].nAnchorMode = 0;
        g_aClassicPositionPhoneStateLandscape[2].nAnchorMode = 0;
        g_aClassicPositionPhoneStateLandscape[3].flHeight = 44.0f;
        g_aClassicPositionPhoneStateLandscape[3].nAnchorMode = 4;
        g_aClassicColorMarkerRects[0].flX = 179.0f;
        g_aClassicColorMarkerRects[0].flY = 117.0f;
        g_aClassicColorMarkerRects[1].flX = 123.0f;
        g_aClassicColorMarkerRects[1].flY = 117.0f;
        g_aClassicColorMarkerRects[2].flX = 121.0f;
        g_aClassicColorMarkerRects[2].flY = 118.0f;
        g_aClassicColorMarkerRects[3].flX = 119.0f;
        g_aClassicColorMarkerRects[3].flY = 1.2e+02f;
        g_aClassicColorMarkerRects[4].flX = 118.0f;
        g_aClassicColorMarkerRects[4].flY = 122.0f;
        g_aClassicColorMarkerRects[5].flX = 117.0f;
        g_aClassicColorMarkerRects[5].flY = 347.0f;
        g_aClassicColorMarkerRects[6].flX = 118.0f;
        g_aClassicColorMarkerRects[6].flY = 349.0f;
        g_aClassicColorMarkerRects[7].flX = 1.2e+02f;
        g_aClassicColorMarkerRects[7].flY = 351.0f;
        g_aClassicColorMarkerRects[8].flX = 122.0f;
        g_aClassicColorMarkerRects[8].flY = 352.0f;
        g_aClassicColorMarkerRects[9].flX = 384.0f;
        g_aClassicColorMarkerRects[9].flY = 353.0f;
        g_aClassicColorMarkerRects[10].flX = 589.0f;
        g_aClassicColorMarkerRects[10].flY = 117.0f;
        g_aClassicColorMarkerRects[11].flX = 646.0f;
        g_aClassicColorMarkerRects[11].flY = 117.0f;
        g_aClassicColorMarkerRects[12].flX = 648.0f;
        g_aClassicColorMarkerRects[12].flY = 118.0f;
        g_aClassicColorMarkerRects[13].flX = 6.5e+02f;
        g_aClassicColorMarkerRects[13].flY = 1.2e+02f;
        g_aClassicColorMarkerRects[14].flX = 651.0f;
        g_aClassicColorMarkerRects[14].flY = 122.0f;
        g_aClassicColorMarkerRects[15].flX = 652.0f;
        g_aClassicColorMarkerRects[15].flY = 347.0f;
        g_aClassicColorMarkerRects[16].flX = 651.0f;
        g_aClassicColorMarkerRects[16].flY = 349.0f;
        g_aClassicColorMarkerRects[17].flX = 649.0f;
        g_aClassicColorMarkerRects[17].flY = 351.0f;
        g_aClassicColorMarkerRects[18].flX = 647.0f;
        g_aClassicColorMarkerRects[18].flY = 352.0f;
        g_aClassicColorMarkerRects[19].flX = 384.0f;
        g_aClassicColorMarkerRects[19].flY = 353.0f;
        g_aClassicColorMarkerRects[20].flX = 179.0f;
        g_aClassicColorMarkerRects[20].flY = 409.0f;
        g_aClassicColorMarkerRects[21].flX = 123.0f;
        g_aClassicColorMarkerRects[21].flY = 409.0f;
        g_aClassicColorMarkerRects[22].flX = 121.0f;
        g_aClassicColorMarkerRects[22].flY = 4.1e+02f;
        g_aClassicColorMarkerRects[23].flX = 119.0f;
        g_aClassicColorMarkerRects[23].flY = 412.0f;
        g_aClassicColorMarkerRects[24].flX = 118.0f;
        g_aClassicColorMarkerRects[24].flY = 414.0f;
        g_aClassicColorMarkerRects[25].flX = 117.0f;
        g_aClassicColorMarkerRects[25].flY = 904.0f;
        g_aClassicColorMarkerRects[26].flX = 118.0f;
        g_aClassicColorMarkerRects[26].flY = 906.0f;
        g_aClassicColorMarkerRects[27].flX = 1.2e+02f;
        g_aClassicColorMarkerRects[27].flY = 908.0f;
        g_aClassicColorMarkerRects[28].flX = 122.0f;
        g_aClassicColorMarkerRects[28].flY = 909.0f;
        g_aClassicColorMarkerRects[29].flX = 384.0f;
        g_aClassicColorMarkerRects[29].flY = 9.1e+02f;
        g_ClassicColorMarkerOrigin.x = 384.0f;
        g_ClassicColorMarkerOrigin.y = 9.1e+02f;
        g_aClassicColorMarkerRects[30].flX = 589.0f;
        g_aClassicColorMarkerRects[30].flY = 409.0f;
        g_aClassicColorMarkerRects[31].flX = 646.0f;
        g_aClassicColorMarkerRects[31].flY = 409.0f;
        g_aClassicColorMarkerRects[32].flX = 648.0f;
        g_aClassicColorMarkerRects[32].flY = 4.1e+02f;
        g_aClassicColorMarkerRects[33].flX = 6.5e+02f;
        g_aClassicColorMarkerRects[33].flY = 412.0f;
        g_aClassicColorMarkerRects[34].flX = 651.0f;
        g_aClassicColorMarkerRects[34].flY = 414.0f;
        g_aClassicColorMarkerRects[35].flX = 652.0f;
        g_aClassicColorMarkerRects[35].flY = 904.0f;
        g_aClassicColorMarkerRects[36].flX = 651.0f;
        g_aClassicColorMarkerRects[36].flY = 906.0f;
        g_aClassicColorMarkerRects[37].flX = 649.0f;
        g_aClassicColorMarkerRects[37].flY = 908.0f;
        g_aClassicColorMarkerRects[38].flX = 647.0f;
        g_aClassicColorMarkerRects[38].flY = 909.0f;
        g_ClassicCenterPositionPhoneState.flX = 119.0f;
        g_ClassicCenterPositionPhoneState.flY = 439.0f;
        g_ClassicCenterPositionPhonePortrait.flX = -141.0f;
        g_ClassicCenterPositionPhonePortrait.flY = -32.0f;
        g_ClassicCenterPositionPhoneLandscape.flX = -214.0f;
        g_ClassicCenterPositionPhoneLandscape.flY = -31.0f;
        g_aClassicPartsPad[1].flWidth = 242.0f;
        g_aClassicPartsPad[1].flHeight = 6e+01f;
        g_aClassicPartsPad[4].flX = g_aClassicPartsPad[3].flX;
        g_aClassicPartsPad[4].flWidth = g_aClassicPartsPad[3].flWidth;
        g_aClassicPartsPad[8].flX = g_aClassicPartsPad[7].flX;
        g_aClassicPartsPad[8].flWidth = g_aClassicPartsPad[7].flWidth;
        g_aClassicPartsPad[11].flX = g_aClassicPartsPad[9].flX;
        g_aClassicPartsPad[11].flWidth = g_aClassicPartsPad[9].flWidth;
        g_aClassicPartsPad[12].flX = g_aClassicPartsPad[3].flX;
        g_aClassicPartsPad[12].flWidth = g_aClassicPartsPad[3].flWidth;
        g_aClassicPartsPad[15].flX = g_aClassicPartsPad[14].flX;
        g_aClassicPartsPad[15].flWidth = g_aClassicPartsPad[14].flWidth;
        g_aClassicPartsPad[16].flX = g_aClassicPartsPad[7].flX;
        g_aClassicPartsPad[16].flWidth = g_aClassicPartsPad[7].flWidth;
        g_aClassicPartsPad[17].flX = g_aClassicPartsPad[7].flX;
        g_aClassicPartsPad[17].flWidth = g_aClassicPartsPad[7].flWidth;
        g_aClassicPartsPad[20].flX = g_aClassicPartsPad[9].flX;
        g_aClassicPartsPad[20].flWidth = g_aClassicPartsPad[9].flWidth;
        g_aClassicPartsPad[22].flX = g_aClassicPartsPad[9].flX;
        g_aClassicPartsPad[22].flWidth = g_aClassicPartsPad[9].flWidth;
        g_aClassicPartsPad[23].flX = g_aClassicPartsPad[19].flX;
        g_aClassicPartsPad[23].flWidth = g_aClassicPartsPad[19].flWidth;
        g_aClassicPartsPad[24].flX = g_aClassicPartsPad[9].flX;
        g_aClassicPartsPad[24].flWidth = g_aClassicPartsPad[9].flWidth;
        g_aClassicPartsPad[28].flX = g_aClassicPartsPad[25].flX;
        g_aClassicPartsPad[28].flWidth = g_aClassicPartsPad[25].flWidth;
        g_aClassicPartsPad[30].flX = g_aClassicPartsPad[27].flX;
        g_aClassicPartsPad[30].flWidth = g_aClassicPartsPad[27].flWidth;
        g_aClassicPartsPad[31].flX = g_aClassicPartsPad[25].flX;
        g_aClassicPartsPad[31].flWidth = g_aClassicPartsPad[25].flWidth;
        g_aClassicPartsPad[33].flX = g_aClassicPartsPad[27].flX;
        g_aClassicPartsPad[33].flWidth = g_aClassicPartsPad[27].flWidth;
        g_aClassicPartsPad[35].flX = g_aClassicPartsPad[32].flX;
        g_aClassicPartsPad[35].flWidth = g_aClassicPartsPad[32].flWidth;
        g_aClassicPartsPad[36].flX = g_aClassicPartsPad[27].flX;
        g_aClassicPartsPad[36].flWidth = g_aClassicPartsPad[27].flWidth;
        g_aClassicPartsPad[39].flX = g_aClassicPartsPad[38].flX;
        g_aClassicPartsPad[39].flWidth = g_aClassicPartsPad[38].flWidth;
        g_aClassicPartsPad[40].flX = g_aClassicPartsPad[38].flX;
        g_aClassicPartsPad[40].flWidth = g_aClassicPartsPad[38].flWidth;
        g_aClassicPartsPad[47].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[47].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[48].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[48].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[49].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[49].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[51].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[51].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[52].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[52].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[54].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[54].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[55].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[55].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[57].flX = g_aClassicPartsPad[56].flX;
        g_aClassicPartsPad[57].flWidth = g_aClassicPartsPad[56].flWidth;
        g_aClassicPartsPad[59].flX = g_aClassicPartsPad[56].flX;
        g_aClassicPartsPad[59].flWidth = g_aClassicPartsPad[56].flWidth;
        g_aClassicPartsPad[60].flX = g_aClassicPartsPad[56].flX;
        g_aClassicPartsPad[60].flWidth = g_aClassicPartsPad[56].flWidth;
        g_aClassicPartsPad[62].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[62].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[63].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[63].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[64].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[64].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[65].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[65].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[67].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[67].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[68].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[68].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[70].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[70].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[71].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[71].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[73].flX = g_aClassicPartsPad[46].flX;
        g_aClassicPartsPad[73].flWidth = g_aClassicPartsPad[46].flWidth;
        g_aClassicPartsPad[76].flX = g_aClassicPartsPad[75].flX;
        g_aClassicPartsPad[76].flWidth = g_aClassicPartsPad[75].flWidth;
        g_aClassicPartsPad[79].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[79].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[80].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[80].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[81].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[81].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[83].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[83].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[84].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[84].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[86].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[86].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[87].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[87].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[88].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[88].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[89].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[89].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[91].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[91].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[92].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[92].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[94].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[94].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[95].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[95].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[96].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[96].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[99].flX = g_aClassicPartsPad[97].flX;
        g_aClassicPartsPad[99].flWidth = g_aClassicPartsPad[97].flWidth;
        g_aClassicPartsPad[102].flX = g_aClassicPartsPad[100].flX;
        g_aClassicPartsPad[102].flWidth = g_aClassicPartsPad[100].flWidth;
        g_aClassicPartsPad[108].flX = g_aClassicPartsPad[107].flX;
        g_aClassicPartsPad[108].flWidth = g_aClassicPartsPad[107].flWidth;
        g_aClassicPartsPad[111].flX = g_aClassicPartsPad[110].flX;
        g_aClassicPartsPad[111].flWidth = g_aClassicPartsPad[110].flWidth;
        g_aClassicPartsPad[112].flX = g_aClassicPartsPad[110].flX;
        g_aClassicPartsPad[112].flWidth = g_aClassicPartsPad[110].flWidth;
        g_aClassicPartsPad[113].flX = g_aClassicPartsPad[110].flX;
        g_aClassicPartsPad[113].flWidth = g_aClassicPartsPad[110].flWidth;
        g_aClassicPartsPad[116].flX = g_aClassicPartsPad[115].flX;
        g_aClassicPartsPad[116].flWidth = g_aClassicPartsPad[115].flWidth;
        g_aClassicPartsPad[118].flX = g_aClassicPartsPad[115].flX;
        g_aClassicPartsPad[118].flWidth = g_aClassicPartsPad[115].flWidth;
        g_aClassicPartsPad[119].flX = g_aClassicPartsPad[115].flX;
        g_aClassicPartsPad[119].flWidth = g_aClassicPartsPad[115].flWidth;
        g_aClassicPartsPad[120].flX = g_aClassicPartsPad[115].flX;
        g_aClassicPartsPad[120].flWidth = g_aClassicPartsPad[115].flWidth;
        g_aClassicPartsPad[121].flX = g_aClassicPartsPad[115].flX;
        g_aClassicPartsPad[121].flWidth = g_aClassicPartsPad[115].flWidth;
        g_aClassicPartsPad[123].flX = g_aClassicPartsPad[115].flX;
        g_aClassicPartsPad[123].flWidth = g_aClassicPartsPad[115].flWidth;
        g_aClassicPartsPad[127].flX = g_aClassicPartsPad[126].flX;
        g_aClassicPartsPad[127].flWidth = g_aClassicPartsPad[126].flWidth;
        g_aClassicPartsPad[128].flX = g_aClassicPartsPad[126].flX;
        g_aClassicPartsPad[128].flWidth = g_aClassicPartsPad[126].flWidth;
        g_aClassicPartsPad[129].flX = g_aClassicPartsPad[126].flX;
        g_aClassicPartsPad[129].flWidth = g_aClassicPartsPad[126].flWidth;
        g_aClassicPartsPad[131].flX = g_aClassicPartsPad[126].flX;
        g_aClassicPartsPad[131].flWidth = g_aClassicPartsPad[126].flWidth;
        g_aClassicPartsPad[135].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[135].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[136].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[136].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[137].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[137].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[139].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[139].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[140].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[140].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[142].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[142].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[145].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[145].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[147].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[147].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[148].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[148].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[150].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[150].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[151].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[151].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[152].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[152].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[153].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[153].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[155].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[155].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[156].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[156].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[158].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[158].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[159].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[159].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[160].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[160].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[161].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[161].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[163].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[163].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[164].flX = g_aClassicPartsPad[134].flX;
        g_aClassicPartsPad[164].flWidth = g_aClassicPartsPad[134].flWidth;
        g_aClassicPartsPad[166].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[166].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[167].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[167].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[168].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[168].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[169].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[169].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[171].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[171].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[172].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[172].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[174].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[174].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[175].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[175].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[179].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[179].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[180].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[180].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[182].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[182].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[183].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[183].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[184].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[184].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[185].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[185].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[188].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[188].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[190].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[190].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[191].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[191].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[192].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[192].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[193].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[193].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[195].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[195].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[196].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[196].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[198].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[198].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[199].flX = g_aClassicPartsPad[177].flX;
        g_aClassicPartsPad[199].flWidth = g_aClassicPartsPad[177].flWidth;
        g_aClassicPartsPad[200].flX = g_aClassicPartsPad[144].flX;
        g_aClassicPartsPad[200].flWidth = g_aClassicPartsPad[144].flWidth;
        g_aClassicPartsPad[203].flX = g_aClassicPartsPad[201].flX;
        g_aClassicPartsPad[203].flWidth = g_aClassicPartsPad[201].flWidth;
        g_aClassicPartsPad[206].flX = g_aClassicPartsPad[204].flX;
        g_aClassicPartsPad[206].flWidth = g_aClassicPartsPad[204].flWidth;
        g_aClassicPartsPad[208].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[208].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[209].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[209].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[211].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[211].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[212].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[212].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[214].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[214].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[215].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[215].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[216].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[216].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[217].flX = g_aClassicPartsPad[78].flX;
        g_aClassicPartsPad[217].flWidth = g_aClassicPartsPad[78].flWidth;
        g_aClassicPartsPad[220].flX = g_aClassicPartsPad[75].flX;
        g_aClassicPartsPad[220].flWidth = g_aClassicPartsPad[75].flWidth;
        g_aClassicPartsPad[224].flX = g_aClassicPartsPad[223].flX;
        g_aClassicPartsPad[224].flWidth = g_aClassicPartsPad[223].flWidth;
        g_aClassicPartsPad[225].flX = g_aClassicPartsPad[223].flX;
        g_aClassicPartsPad[225].flWidth = g_aClassicPartsPad[223].flWidth;
        g_aClassicPartsPad[227].flX = g_aClassicPartsPad[223].flX;
        g_aClassicPartsPad[227].flWidth = g_aClassicPartsPad[223].flWidth;
        g_aClassicPartsPad[233].flX = g_aClassicPartsPad[232].flX;
        g_aClassicPartsPad[233].flWidth = g_aClassicPartsPad[232].flWidth;
        g_aClassicPartsAnchorPad[1] = savedAnchor;
        g_aClassicPositionPhoneStatePortrait[1].flX = g_aClassicPositionPhoneState[1].flX;
        g_aClassicPositionPhoneStatePortrait[1].flWidth = g_aClassicPositionPhoneState[1].flWidth;
        g_aClassicPositionPhoneStatePortrait[2].flX = g_aClassicPositionPhoneState[2].flX;
        g_aClassicPositionPhoneStatePortrait[2].flWidth = g_aClassicPositionPhoneState[2].flWidth;
        g_aClassicPositionPhoneStateLandscape[1].flX = g_aClassicPositionPhoneState[1].flX;
        g_aClassicPositionPhoneStateLandscape[1].flWidth = g_aClassicPositionPhoneState[1].flWidth;
        g_aClassicPositionPhoneStateLandscape[2].flX = g_aClassicPositionPhoneState[2].flX;
        g_aClassicPositionPhoneStateLandscape[2].flWidth = g_aClassicPositionPhoneState[2].flWidth;
    }
}
