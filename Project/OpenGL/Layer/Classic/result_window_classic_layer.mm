#include "result_window_classic_layer.h"

#include <cassert>
#include <cmath>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "MusicData.h"
#import "RBViewController.h"
#include "ScoreTracker.h"
#import "TwitterImageCreater.h"
#include "classic_parts_data_table.h"
#import "deviceenvironment.h"
#include "engineglobals.h"
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

// The constructor's non-zero seeds: the fully-opaque sprite alpha, the touch id a region carries
// while nothing is tracking it, and the sound-effect handle meaning nothing is playing.
static constexpr unsigned int kFullAlpha = 255;
static constexpr int kNoTouchId = -1;
static constexpr int kNoSePlayHandle = -1;

// The Classic pad parts table (declared in classic_parts_data_table.h): zero-initialised here to
// match the binary's __common segment, filled at runtime.
PartsDataRecord g_aClassicPartsPad[kClassicPartsRecordBound] = {}; // @ghidraAddress 0x3d6650

// The Classic pad parts anchor table (declared in classic_parts_data_table.h): zero-initialised
// here to match the binary's __common segment, filled at runtime.
S_VECTOR2 g_aClassicPartsAnchorPad[kClassicPartsAnchorRecordCount] = {}; // @ghidraAddress 0x3d7cd0

// The Classic ribbon-trail vertex storage (declared in classic_parts_data_table.h):
// zero-initialised here to match the binary's __common segment, filled at runtime.
S_VECTOR2 g_aClassicTrailVertices[kTrailVertexTotal] = {}; // @ghidraAddress 0x3dd080

// The per-trail vertex counts, read-only data in the binary.
const int g_aClassicTrailVertexCounts[] = {19, 19, 19, 19}; // @ghidraAddress 0x304190

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

// The fixed landscape offsets the customize overlays add to their base positions. These are not
// standalone globals: 0x3d8058 through 0x3d8070 fall inside the anchor table based at 0x3d7cd0
// (indices 113 through 116), and the load-time initialiser is what fills them. They were previously
// modelled as four separate statics, which gave them their own zeroed storage and made both
// overlays add a null offset.
constexpr int kCustomizeOverlayLandscapeAnchor = 113; // 0x3d8058
constexpr int kNameplateBackingAnchor = 114;          // 0x3d8060
constexpr int kNameplateNameAnchor = 115;             // 0x3d8068
constexpr int kNameplateLevelAnchor = 116;            // 0x3d8070

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

// The shared UV-palette table (declared in classic_parts_data_table.h) the Classic result window
// indexes by a parts record's UV-palette index. Read-only ROM data transcribed from the binary;
// the entry count is set by the span up to the next table rather than by any bound in the code.
// @ghidraAddress 0x2f1b28
const UvPaletteEntry g_aClassicUvPalette[] = {
    {0.0f, 0.0f, 0.75f, 1.0f},
    {0.2890625f, 0.5410156f, 0.23632812f, 0.05859375f},
    {0.59375f, 0.53515625f, 0.08984375f, 0.037109375f},
    {0.001953125f, 0.18554688f, 0.26171875f, 0.0546875f},
    {0.001953125f, 0.18554688f, 0.26171875f, 0.0546875f},
    {0.001953125f, 0.2421875f, 0.26171875f, 0.0009765625f},
    {0.001953125f, 0.2421875f, 0.26171875f, 0.0009765625f},
    {0.001953125f, 0.2421875f, 0.26171875f, 0.013671875f},
    {0.001953125f, 0.2421875f, 0.26171875f, 0.013671875f},
    {0.45898438f, 0.46484375f, 0.0390625f, 0.0546875f},
    {0.50097656f, 0.46484375f, 0.0009765625f, 0.0546875f},
    {0.45898438f, 0.46484375f, 0.0390625f, 0.0546875f},
    {0.001953125f, 0.18554688f, 0.26171875f, 0.0546875f},
    {0.001953125f, 0.18554688f, 0.26171875f, 0.0546875f},
    {0.001953125f, 0.2421875f, 0.26171875f, 0.0009765625f},
    {0.001953125f, 0.2421875f, 0.26171875f, 0.0009765625f},
    {0.001953125f, 0.2421875f, 0.26171875f, 0.013671875f},
    {0.001953125f, 0.2421875f, 0.26171875f, 0.013671875f},
    {0.5058594f, 0.46484375f, 0.0390625f, 0.0546875f},
    {0.54785156f, 0.46484375f, 0.0009765625f, 0.0546875f},
    {0.5058594f, 0.46484375f, 0.0390625f, 0.0546875f},
    {0.6113281f, 0.57421875f, 0.005859375f, 0.005859375f},
    {0.5527344f, 0.46484375f, 0.0390625f, 0.0546875f},
    {0.59472656f, 0.46484375f, 0.0009765625f, 0.0546875f},
    {0.5527344f, 0.46484375f, 0.0390625f, 0.0546875f},
    {0.001953125f, 0.3203125f, 0.4921875f, 0.029296875f},
    {0.001953125f, 0.38378906f, 0.4921875f, 0.0009765625f},
    {0.001953125f, 0.3828125f, 0.4921875f, 0.01171875f},
    {0.001953125f, 0.3515625f, 0.4921875f, 0.029296875f},
    {0.001953125f, 0.38378906f, 0.4921875f, 0.0009765625f},
    {0.001953125f, 0.3828125f, 0.4921875f, 0.01171875f},
    {0.001953125f, 0.2578125f, 0.4921875f, 0.029296875f},
    {0.001953125f, 0.38378906f, 0.4921875f, 0.0009765625f},
    {0.001953125f, 0.3828125f, 0.4921875f, 0.01171875f},
    {0.001953125f, 0.2890625f, 0.4921875f, 0.029296875f},
    {0.001953125f, 0.38378906f, 0.4921875f, 0.0009765625f},
    {0.001953125f, 0.3828125f, 0.4921875f, 0.01171875f},
    {0.265625f, 0.19726562f, 0.037109375f, 0.01171875f},
    {0.3046875f, 0.19726562f, 0.037109375f, 0.01171875f},
    {0.34375f, 0.19726562f, 0.037109375f, 0.01171875f},
    {0.3828125f, 0.19726562f, 0.037109375f, 0.01171875f},
    {0.001953125f, 0.001953125f, 0.4921875f, 0.18164062f},
    {0.265625f, 0.18554688f, 0.0390625f, 0.009765625f},
    {0.30664062f, 0.18554688f, 0.048828125f, 0.009765625f},
    {0.35742188f, 0.18554688f, 0.037109375f, 0.009765625f},
    {0.6777344f, 0.22265625f, 0.048828125f, 0.009765625f},
    {0.39648438f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.40429688f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.41210938f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.41992188f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.42773438f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.43554688f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.44335938f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.45117188f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.45898438f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.46679688f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.47460938f, 0.18554688f, 0.009765625f, 0.0078125f},
    {0.47460938f, 0.18554688f, 0.009765625f, 0.0078125f},
    {0.47460938f, 0.18554688f, 0.009765625f, 0.0078125f},
    {0.47460938f, 0.18554688f, 0.009765625f, 0.0078125f},
    {0.47460938f, 0.18554688f, 0.009765625f, 0.0078125f},
    {0.47460938f, 0.18554688f, 0.009765625f, 0.0078125f},
    {0.39648438f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.40429688f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.41210938f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.41992188f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.42773438f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.43554688f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.44335938f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.45117188f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.45898438f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.46679688f, 0.18554688f, 0.005859375f, 0.0078125f},
    {0.484375f, 0.19433594f, 0.001953125f, 0.0078125f},
    {0.46679688f, 0.19433594f, 0.005859375f, 0.0078125f},
    {0.47460938f, 0.19433594f, 0.005859375f, 0.0078125f},
    {0.42236328f, 0.19726562f, 0.0009765625f, 0.01171875f},
    {0.42626953f, 0.19726562f, 0.0009765625f, 0.01171875f},
    {0.265625f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.28320312f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.30078125f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.31835938f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.3359375f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.35351562f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.37109375f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.38867188f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.40625f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.42382812f, 0.2109375f, 0.015625f, 0.017578125f},
    {0.265625f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.28320312f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.30078125f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.31835938f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.3359375f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.35351562f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.37109375f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.38867188f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.40625f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.42382812f, 0.23046875f, 0.015625f, 0.017578125f},
    {0.5859375f, 0.123046875f, 0.04296875f, 0.037109375f},
    {0.5410156f, 0.123046875f, 0.04296875f, 0.037109375f},
    {0.49609375f, 0.123046875f, 0.04296875f, 0.037109375f},
    {0.625f, 0.083984375f, 0.0625f, 0.037109375f},
    {0.5605469f, 0.083984375f, 0.0625f, 0.037109375f},
    {0.49609375f, 0.083984375f, 0.0625f, 0.037109375f},
    {0.6777344f, 0.16796875f, 0.0703125f, 0.052734375f},
    {0.140625f, 0.41992188f, 0.14648438f, 0.1796875f},
    {0.001953125f, 0.41992188f, 0.13671875f, 0.22851562f},
    {0.49609375f, 0.16210938f, 0.05078125f, 0.017578125f},
    {0.49609375f, 0.18164062f, 0.05078125f, 0.017578125f},
    {0.49609375f, 0.20117188f, 0.05078125f, 0.017578125f},
    {0.49609375f, 0.22070312f, 0.05078125f, 0.017578125f},
    {0.5488281f, 0.16210938f, 0.12695312f, 0.017578125f},
    {0.5488281f, 0.18164062f, 0.12695312f, 0.017578125f},
    {0.5488281f, 0.20117188f, 0.12695312f, 0.017578125f},
    {0.5488281f, 0.22070312f, 0.12695312f, 0.017578125f},
    {0.44140625f, 0.2109375f, 0.009765625f, 0.01171875f},
    {0.453125f, 0.2109375f, 0.009765625f, 0.01171875f},
    {0.46484375f, 0.2109375f, 0.009765625f, 0.01171875f},
    {0.4765625f, 0.2109375f, 0.009765625f, 0.01171875f},
    {0.44140625f, 0.22460938f, 0.009765625f, 0.01171875f},
    {0.453125f, 0.22460938f, 0.009765625f, 0.01171875f},
    {0.46484375f, 0.22460938f, 0.009765625f, 0.01171875f},
    {0.4765625f, 0.22460938f, 0.009765625f, 0.01171875f},
    {0.44140625f, 0.23828125f, 0.009765625f, 0.01171875f},
    {0.453125f, 0.23828125f, 0.009765625f, 0.01171875f},
    {0.46484375f, 0.23828125f, 0.005859375f, 0.01171875f},
    {0.4765625f, 0.23828125f, 0.009765625f, 0.01171875f},
    {0.43408203f, 0.19726562f, 0.0009765625f, 0.0048828125f},
    {0.43798828f, 0.19726562f, 0.0009765625f, 0.0048828125f},
    {0.44189453f, 0.19726562f, 0.0009765625f, 0.0048828125f},
    {0.44580078f, 0.19726562f, 0.0009765625f, 0.0048828125f},
    {0.44970703f, 0.19726562f, 0.0009765625f, 0.0048828125f},
    {0.45361328f, 0.19726562f, 0.0009765625f, 0.0048828125f},
    {0.001953125f, 0.39648438f, 0.45507812f, 0.021484375f},
    {0.49609375f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.515625f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.53515625f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.5546875f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.57421875f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.59375f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.61328125f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.6328125f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.65234375f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.671875f, 0.24023438f, 0.017578125f, 0.0234375f},
    {0.69140625f, 0.29101562f, 0.005859375f, 0.01953125f},
    {0.49609375f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.5136719f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.53125f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.5488281f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.56640625f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.5839844f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.6015625f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.6191406f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.63671875f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.6542969f, 0.29101562f, 0.015625f, 0.01953125f},
    {0.671875f, 0.29101562f, 0.017578125f, 0.01953125f},
    {0.49609375f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.515625f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.53515625f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.5546875f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.57421875f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.59375f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.61328125f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.6328125f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.65234375f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.671875f, 0.265625f, 0.017578125f, 0.0234375f},
    {0.69140625f, 0.3125f, 0.005859375f, 0.01953125f},
    {0.49609375f, 0.3125f, 0.015625f, 0.01953125f},
    {0.5136719f, 0.3125f, 0.015625f, 0.01953125f},
    {0.53125f, 0.3125f, 0.015625f, 0.01953125f},
    {0.5488281f, 0.3125f, 0.015625f, 0.01953125f},
    {0.56640625f, 0.3125f, 0.015625f, 0.01953125f},
    {0.5839844f, 0.3125f, 0.015625f, 0.01953125f},
    {0.6015625f, 0.3125f, 0.015625f, 0.01953125f},
    {0.6191406f, 0.3125f, 0.015625f, 0.01953125f},
    {0.63671875f, 0.3125f, 0.015625f, 0.01953125f},
    {0.6542969f, 0.3125f, 0.015625f, 0.01953125f},
    {0.671875f, 0.3125f, 0.017578125f, 0.01953125f},
    {0.49609375f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.5097656f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.5234375f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.5371094f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.55078125f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.5644531f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.578125f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.5917969f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.60546875f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.6191406f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.6328125f, 0.33398438f, 0.001953125f, 0.015625f},
    {0.49609375f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.5097656f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.5234375f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.5371094f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.55078125f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.5644531f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.578125f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.5917969f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.60546875f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.6191406f, 0.3515625f, 0.01171875f, 0.015625f},
    {0.63671875f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.6503906f, 0.33398438f, 0.01171875f, 0.015625f},
    {0.6640625f, 0.33398438f, 0.015625f, 0.01953125f},
    {0.6503906f, 0.04296875f, 0.033203125f, 0.029296875f},
    {0.6855469f, 0.04296875f, 0.02734375f, 0.029296875f},
    {0.71484375f, 0.04296875f, 0.033203125f, 0.029296875f},
    {0.6972656f, 0.07421875f, 0.05078125f, 0.029296875f},
    {0.6972656f, 0.10546875f, 0.05078125f, 0.029296875f},
    {0.6972656f, 0.13671875f, 0.05078125f, 0.029296875f},
    {0.6328125f, 0.35742188f, 0.041992188f, 0.0078125f},
    {0.5136719f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.53125f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.5488281f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.56640625f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.5839844f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.6015625f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.6191406f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.63671875f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.6542969f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.671875f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.49609375f, 0.3828125f, 0.015625f, 0.017578125f},
    {0.49609375f, 0.3671875f, 0.20703125f, 0.013671875f},
    {0.43017578f, 0.19726562f, 0.0009765625f, 0.01171875f},
    {0.59375f, 0.57421875f, 0.015625f, 0.021484375f},
    {0.52734375f, 0.53515625f, 0.06640625f, 0.06640625f},
    {0.2890625f, 0.43945312f, 0.16210938f, 0.017578125f},
    {0.2890625f, 0.41992188f, 0.16210938f, 0.017578125f},
    {0.2890625f, 0.45898438f, 0.16210938f, 0.017578125f},
    {0.2890625f, 0.47851562f, 0.16210938f, 0.017578125f},
    {0.2890625f, 0.49804688f, 0.16210938f, 0.017578125f},
    {0.2890625f, 0.5175781f, 0.16601562f, 0.021484375f},
    {0.140625f, 0.6015625f, 0.3125f, 0.05859375f},
    {0.45507812f, 0.6015625f, 0.125f, 0.05859375f},
    {0.140625f, 0.6015625f, 0.3125f, 0.05859375f},
    {0.001953125f, 0.6621094f, 0.375f, 0.05859375f},
    {0.001953125f, 0.6621094f, 0.375f, 0.05859375f},
    {0.6230469f, 0.40234375f, 0.123046875f, 0.029296875f},
    {0.45898438f, 0.40234375f, 0.16210938f, 0.029296875f},
    {0.45898438f, 0.43359375f, 0.25976562f, 0.029296875f},
    {0.49609375f, 0.001953125f, 0.103515625f, 0.0390625f},
    {0.6015625f, 0.001953125f, 0.1015625f, 0.0390625f},
    {0.49609375f, 0.04296875f, 0.13476562f, 0.0390625f},
};

// The glyph UV-palette table (declared in classic_parts_data_table.h) the Classic glyph dispatcher
// indexes by a glyph record's UV-palette index; distinct from the part palette above. Read-only
// ROM data transcribed from the binary, bounded the same way.
// @ghidraAddress 0x2f4dc8
const UvPaletteEntry g_aClassicGlyphUvPalette[] = {
    {0.0f, 0.0f, 1.0f, 1.0f},
    {0.37304688f, 0.625f, 0.111328125f, 0.078125f},
    {0.001953125f, 0.09375f, 0.017578125f, 0.03515625f},
    {0.01953125f, 0.09375f, 0.0f, 0.03515625f},
    {0.001953125f, 0.12890625f, 0.017578125f, 0.0f},
    {0.01953125f, 0.12890625f, 0.0f, 0.0f},
    {0.0234375f, 0.09375f, 0.017578125f, 0.03515625f},
    {0.041015625f, 0.09375f, 0.0f, 0.03515625f},
    {0.0234375f, 0.12890625f, 0.017578125f, 0.0f},
    {0.041015625f, 0.12890625f, 0.0f, 0.0f},
    {0.001953125f, 0.45703125f, 0.029296875f, 0.06640625f},
    {0.029296875f, 0.45703125f, 0.001953125f, 0.06640625f},
    {0.00390625f, 0.13671875f, 0.0f, 0.00390625f},
    {0.001953125f, 0.13671875f, 0.001953125f, 0.00390625f},
    {0.044921875f, 0.09375f, 0.09375f, 0.03125f},
    {0.15429688f, 0.09375f, 0.05859375f, 0.03125f},
    {0.21484375f, 0.09375f, 0.05078125f, 0.03125f},
    {0.044921875f, 0.12890625f, 0.3203125f, 0.03125f},
    {0.140625f, 0.09375f, 0.01171875f, 0.03125f},
    {0.421875f, 0.00390625f, 0.07421875f, 0.03125f},
    {0.421875f, 0.0390625f, 0.07421875f, 0.03125f},
    {0.421875f, 0.07421875f, 0.07421875f, 0.03125f},
    {0.34570312f, 0.00390625f, 0.07421875f, 0.03125f},
    {0.26757812f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.27734375f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.28710938f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.296875f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.30664062f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.31640625f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.32617188f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.3359375f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.34570312f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.35546875f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.36523438f, 0.09375f, 0.0078125f, 0.0234375f},
    {0.375f, 0.09375f, 0.01171875f, 0.0234375f},
    {0.38867188f, 0.09375f, 0.01171875f, 0.0234375f},
    {0.001953125f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.04296875f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.083984375f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.125f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.16601562f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.20703125f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.24804688f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.2890625f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.33007812f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.37109375f, 0.26171875f, 0.0390625f, 0.09375f},
    {0.3359375f, 0.359375f, 0.05078125f, 0.09375f},
    {0.29492188f, 0.359375f, 0.0390625f, 0.09375f},
    {0.2421875f, 0.359375f, 0.05078125f, 0.09375f},
    {0.16210938f, 0.359375f, 0.078125f, 0.09375f},
    {0.08203125f, 0.359375f, 0.078125f, 0.09375f},
    {0.001953125f, 0.359375f, 0.078125f, 0.09375f},
    {0.3671875f, 0.12890625f, 0.09765625f, 0.0234375f},
    {0.20703125f, 0.7109375f, 0.05078125f, 0.0390625f},
    {0.32617188f, 0.7109375f, 0.05078125f, 0.0390625f},
    {0.37890625f, 0.7109375f, 0.064453125f, 0.0390625f},
    {0.25976562f, 0.7109375f, 0.064453125f, 0.0390625f},
    {0.001953125f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.015625f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.029296875f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.04296875f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.056640625f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.0703125f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.083984375f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.09765625f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.111328125f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.125f, 0.75390625f, 0.01171875f, 0.03125f},
    {0.1484375f, 0.75390625f, 0.00390625f, 0.03125f},
    {0.13867188f, 0.75390625f, 0.0078125f, 0.03125f},
    {0.15429688f, 0.75390625f, 0.015625f, 0.03125f},
    {0.7167969f, 0.3984375f, 0.01171875f, 0.03125f},
    {0.001953125f, 0.7890625f, 0.05078125f, 0.03125f},
    {0.0546875f, 0.7890625f, 0.05078125f, 0.03125f},
    {0.107421875f, 0.7890625f, 0.05078125f, 0.03125f},
    {0.16015625f, 0.7890625f, 0.05078125f, 0.03125f},
    {0.21289062f, 0.7890625f, 0.0703125f, 0.03125f},
    {0.28515625f, 0.7890625f, 0.0703125f, 0.03125f},
    {0.35742188f, 0.7890625f, 0.05078125f, 0.03125f},
    {0.001953125f, 0.82421875f, 0.1171875f, 0.03125f},
    {0.12109375f, 0.82421875f, 0.1171875f, 0.03125f},
    {0.24023438f, 0.82421875f, 0.1171875f, 0.03125f},
    {0.359375f, 0.82421875f, 0.1171875f, 0.03125f},
    {0.001953125f, 0.859375f, 0.12890625f, 0.03125f},
    {0.1328125f, 0.859375f, 0.0703125f, 0.03125f},
    {0.20507812f, 0.859375f, 0.1796875f, 0.03125f},
    {0.01953125f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.037109375f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.0546875f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.072265625f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.08984375f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.107421875f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.125f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.14257812f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.16015625f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.17773438f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.001953125f, 0.7109375f, 0.015625f, 0.0390625f},
    {0.1953125f, 0.7109375f, 0.009765625f, 0.0390625f},
    {0.25f, 0.48828125f, 0.22265625f, 0.0390625f},
    {0.47851562f, 0.48828125f, 0.0f, 0.03125f},
    {0.45898438f, 0.53125f, 0.015625f, 0.04296875f},
    {0.49804688f, 0.00390625f, 0.12109375f, 0.2421875f},
    {0.484375f, 0.109375f, 0.01171875f, 0.0234375f},
    {0.171875f, 0.75390625f, 0.12890625f, 0.03125f},
    {0.30273438f, 0.75390625f, 0.1484375f, 0.03125f},
    {0.25f, 0.45703125f, 0.0625f, 0.02734375f},
    {0.203125f, 0.625f, 0.16796875f, 0.046875f},
    {0.001953125f, 0.001953125f, 0.33203125f, 0.080078125f},
    {0.23535156f, 0.89453125f, 0.0009765625f, 0.1015625f},
    {0.25f, 0.89453125f, 0.24023438f, 0.1015625f},
    {0.49316406f, 0.89453125f, 0.0009765625f, 0.1015625f},
    {0.38964844f, 0.359375f, 0.0f, 0.109375f},
    {0.39453125f, 0.359375f, 0.04296875f, 0.109375f},
    {0.4404297f, 0.359375f, 0.0f, 0.109375f},
    {0.4453125f, 0.2734375f, 0.046875f, 0.1953125f},
    {0.49023438f, 0.2734375f, 0.0009765625f, 0.1953125f},
    {0.001953125f, 0.89453125f, 0.2265625f, 0.0703125f},
    {0.001953125f, 0.1640625f, 0.140625f, 0.09375f},
    {0.14648438f, 0.1640625f, 0.13671875f, 0.09375f},
    {0.28515625f, 0.1640625f, 0.17773438f, 0.09375f},
    {0.001953125f, 0.53125f, 0.19921875f, 0.046875f},
    {0.203125f, 0.53125f, 0.21875f, 0.046875f},
    {0.203125f, 0.58203125f, 0.0859375f, 0.0390625f},
    {0.001953125f, 0.58203125f, 0.19921875f, 0.0390625f},
    {0.001953125f, 0.625f, 0.19921875f, 0.0390625f},
    {0.29101562f, 0.58203125f, 0.0859375f, 0.0390625f},
    {0.001953125f, 0.66796875f, 0.19921875f, 0.0390625f},
};

/** @ghidraAddress 0x115094 */
ResultWindowClassicLayer::ResultWindowClassicLayer() {
    // The base constructor and the zero-initialised members clear the layer; the binary writes
    // those zeroes out explicitly, so only the non-zero defaults remain here.
    m_nDefaultAlpha = kFullAlpha;
    for (GestureTouchRegion &region : m_aGestureRegions) {
        region.nTouchId = kNoTouchId;
    }
    m_nSliderTouchId = kNoTouchId;
    m_nRevealSeHandle = kNoSePlayHandle;
    m_bMainAssetSubState = true;

    // Each trail draws a fixed-length strip out of the shared vertex storage: the pointer table
    // at 0x3cf458 gives the four starts, one stride apart, and the count table gives each one's
    // length.
    for (int nTrail = 0; nTrail < kTrailCount; ++nTrail) {
        m_apTrails[nTrail] =
            new Polygon2dTrail(g_aClassicTrailVertexCounts[nTrail],
                               &g_aClassicTrailVertices[nTrail * kTrailVertexStride]);
    }
}

/** @ghidraAddress 0x1151fc */
ResultWindowClassicLayer *ResultWindowClassicLayer::shared() {
    if (g_pClassicResultLayer == nullptr) {
        // The binary allocates the raw 0x1c0-byte object and runs the constructor at 0x115094.
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

// The per-slot sprite-instancer capacities (@ghidraAddress 0x304170). Slot 1 (the parts atlas)
// holds the most sprites; the rest are small fixed banks.
constexpr unsigned int kSlotCapacities[] = {1, 400, 1, 1, 1, 2, 2, 0};

// The per-slot texture-field selector (@ghidraAddress 0x304150): the index (0 = background, 1 =
// parts) into the layer's two texture fields for each slot that binds a texture. A slot binds a
// texture only when it is one of the first two or the last (the middle slots share the atlas
// already bound by the batch they mirror).
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
// The fixed per-glyph advance and the centring bias RenderDecimalWithDotGlyph uses (the dot glyph
// is tucked two pixels tighter than a full advance).
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

    // Offset the leading coordinate by half or full viewport dimensions per the record's anchor
    // mode.
    ApplyAnchorOffset(record.nAnchorMode, &pOutRect->flX, &pOutRect->flY);
}

/** @ghidraAddress 0x115008 */
void ResultWindowClassicLayer::getCenterPosition_Phone(PhoneLayoutRect *pOutRect) const {
    // When the state flag is set the state record is copied verbatim, with no viewport anchoring.
    if (IsPad()) {
        *pOutRect = g_ClassicCenterPositionPhoneState;
        (void)GameSystem::GetGameSystem(); // The binary tail-calls the singleton getter and
                                           // discards it.
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
constexpr float kEffectDelayA = 150.0f;  // @ghidraAddress 0x2eedc8
constexpr float kEffectDelayC = 2600.0f; // @ghidraAddress 0x302d54
constexpr float kEffectDelayD = 2900.0f; // @ghidraAddress 0x302d58
constexpr int kTrailDuration = 500;
} // namespace

/** @ghidraAddress 0x1173d8 */
void ResultWindowClassicLayer::UpdateTouchAndPostTwitterShare() {
    // The result panel is interactive only once its reveal is complete and the screen fade is gone:
    // the panel alpha channel must read fully opaque and the fade overlay must be fully clear.
    const int nPanelAlpha =
        static_cast<int>(m_aScoreAnimChannels[kScoreChannel].GetCurrent() * kFullyOpaqueAlpha);
    const float flChannelC = m_aScoreAnimChannels[kEffectChannelC].GetCurrent();
    const float flFadeAlpha = FadeOverlayLayer::shared()->GetCurrentAlpha();

    UpdateGestureTouchTracking();

    m_aGestureRegions[0].bEnabled = nPanelAlpha == kFullyOpaqueAlpha && flFadeAlpha == 0.0f;
    if (flFadeAlpha != 0.0f ||
        static_cast<int>(flChannelC * static_cast<float>(nPanelAlpha)) != kFullyOpaqueAlpha) {
        // Not fully shown: disable the swipe regions, and the share region when Twitter is
        // available.
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
    // its item is the asset variant), build and load the asset texture, and bind it into the
    // preview slot. The binary discards this method's return value.
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

    // Resolve the asset's unlock entry (its category is the asset type, its item the variant),
    // build and load the asset texture, and bind it into the main asset slot. The binary discards
    // this method's return value.
    const LevelUnlockEntry *pEntry = LevelTables::GetLevelUnlockEntry(m_nMainAssetId);
    m_bMainAssetSubState = false;
    NSString *path = BuildCustomizeAssetPathString(pEntry->nCategory, pEntry->nItem);
    ne::C_TEXTURE *pTexture = ne::C_TEXTURE::FindOrLoadCached([path UTF8String]);
    // The binary binds and releases the texture unconditionally on the available path (no null
    // check, unlike the toggle helper).
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
    // Maps the reveal progress through the gained-experience span into the settled experience
    // ratio.
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
        // The reveal reached its target: latch it, show the next character texture, advance the
        // asset index, and either record the pending track index or begin the main-asset load.
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
                                                           float flScale) {
    // Advance the slide timer: forward (clamped to the duration) while the direction flag is set,
    // backward (clamped to zero) while it is clear. On reaching zero, kick off any queued
    // main-asset load and clear the queue sentinel.
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
    const float flAlphaBase = flProgress * flScale;
    const unsigned int nGroupAlpha =
        static_cast<unsigned int>(static_cast<int>(flAlphaBase * m_flMainAssetScale));

    if (IsPad()) {
        // The iPad overlay part draws at the base position shifted by the fixed landscape offset;
        // the same shifted position feeds the final scaled render.
        AddVector2(&renderPos, &g_aClassicPartsAnchorPad[kCustomizeOverlayLandscapeAnchor]);
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
                                                               float flScale) {
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
        // Fully grown: once the level-up voice finishes, fold the gained experience into the
        // running total and re-read the next level's threshold.
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
    const unsigned int nAlpha = static_cast<unsigned int>(static_cast<int>(flProgress * flScale));

    if (IsPad()) {
        // The iPad path draws the name and level glyphs at their landscape offsets.
        const unsigned int nNamePart =
            static_cast<unsigned int>(m_nCustomizeSubId) + kNameplateNamePartBase;
        S_VECTOR2 namePos = renderPos;
        AddVector2(&namePos, &g_aClassicPartsAnchorPad[kNameplateNameAnchor]);
        EmitPartSprite(0.0f, 1.0f, 1.0f, kNameplateGlyphSlot, nNamePart, namePos, nAlpha, false);

        S_VECTOR2 levelPos = renderPos;
        AddVector2(&levelPos, &g_aClassicPartsAnchorPad[kNameplateLevelAnchor]);
        EmitPartSprite(
            0.0f, 1.0f, 1.0f, kNameplateGlyphSlot, kNameplateLevelPart, levelPos, nAlpha, false);

        AddVector2(&renderPos, &g_aClassicPartsAnchorPad[kNameplateBackingAnchor]);
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

    // The separator record supplies the anchored base position and this sprite's scale and
    // rotation: its width field is the X scale, its height field is the rotation.
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
    // The alpha channel is the requested scale times the layer's default scale; the intensity is
    // the texture's scale factor truncated to a byte.
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
    // Each channel eases from its current shown value toward zero over the start time; a
    // non-positive start time snaps the target to zero immediately.
    for (FloatTween &channel : m_aScoreAnimChannels) {
        channel.SetFrom(channel.GetCurrent());
        channel.SetTo(0.0f);
        channel.SetDuration(flStartTime);
        channel.SetDelay(0.0f);
        channel.SetElapsed(0.0f);
        if (flStartTime <= 0.0f) {
            channel.SetCurrent(0.0f);
        }
    }

    // Reset the four ribbon trails, then clear the score-animation active flag.
    for (Polygon2dTrail *pTrail : m_apTrails) {
        pTrail->Reset();
    }
    m_bScoreAnimActive = false;
}

/** @ghidraAddress 0x116f90 */
void ResultWindowClassicLayer::StartResultScoreAnimations(float flStartTime) {
    // The score channel eases from its current shown value to one over the base start time; a
    // non-positive time snaps it to the final value immediately.
    FloatTween &scoreChannel = m_aScoreAnimChannels[kScoreChannel];
    scoreChannel.SetFrom(scoreChannel.GetCurrent());
    scoreChannel.SetTo(kScoreAnimShownTarget);
    scoreChannel.SetDuration(flStartTime);
    scoreChannel.SetDelay(0.0f);
    scoreChannel.SetElapsed(0.0f);
    if (flStartTime <= 0.0f) {
        scoreChannel.SetCurrent(kScoreAnimShownTarget);
    }

    // The first ribbon-trail pair starts at the base time.
    m_apTrails[0]->Start(kTrailDuration, static_cast<int>(flStartTime));
    m_apTrails[1]->Start(kTrailDuration, static_cast<int>(flStartTime));

    // Each effect channel eases from its current value to one over a fixed duration, its start
    // staggered past the base time by holding the delay in the elapsed slot.
    FloatTween &effectB = m_aScoreAnimChannels[kEffectChannelB];
    effectB.SetFrom(effectB.GetCurrent());
    effectB.SetTo(kScoreAnimShownTarget);
    effectB.SetDuration(kEffectDurationShort);
    effectB.SetDelay(flStartTime);
    effectB.SetElapsed(0.0f);

    FloatTween &effectA = m_aScoreAnimChannels[kEffectChannelA];
    effectA.SetFrom(effectA.GetCurrent());
    effectA.SetTo(kScoreAnimShownTarget);
    effectA.SetDuration(kEffectDurationLong);
    effectA.SetDelay(flStartTime + kEffectDelayA);
    effectA.SetElapsed(0.0f);

    // The second ribbon-trail pair is delayed past the base time.
    const int nDelayedTrailStart = static_cast<int>(flStartTime + kEffectDelayC);
    m_apTrails[2]->Start(kTrailDuration, nDelayedTrailStart);
    m_apTrails[3]->Start(kTrailDuration, nDelayedTrailStart);

    FloatTween &effectD = m_aScoreAnimChannels[kEffectChannelD];
    effectD.SetFrom(effectD.GetCurrent());
    effectD.SetTo(kScoreAnimShownTarget);
    effectD.SetDuration(kEffectDurationShort);
    effectD.SetDelay(flStartTime + kEffectDelayC);
    effectD.SetElapsed(0.0f);

    FloatTween &effectC = m_aScoreAnimChannels[kEffectChannelC];
    effectC.SetFrom(effectC.GetCurrent());
    effectC.SetTo(kScoreAnimShownTarget);
    effectC.SetDuration(kEffectDurationLong);
    effectC.SetDelay(flStartTime + kEffectDelayD);
    effectC.SetElapsed(0.0f);

    // Reset the reveal sound-effect handle to "none".
    m_nRevealSeHandle = -1;
}

/** @ghidraAddress 0x11541c */
void ResultWindowClassicLayer::ResetScoreDisplayState() {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    // A single-player game type (0 or 2) is offline; every other type is a networked play.
    m_nNetworkPlay = (pGameSystem->GetGameType() | 2) == 2 ? 0 : 1;

    // Clear the per-round display counters and reset every music-track index sentinel to -1.
    m_flResultElapsed = 0.0f;
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

    // When no customize swap is pending, kick off the main-asset load; otherwise consume the
    // pending flag and seed the resolved track index from the player level.
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
        m_aScoreAnimChannels[nChannel].Advance(flDeltaTime);
    }

    // Advance the signed slide/settle timer toward zero, at differing rates by sign, clamping on
    // the zero crossing.
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

namespace {
// The instancer slots the pad render path draws into. Slot 1 carries every part sprite; the rest
// carry a single quad each.
constexpr unsigned int kPadBackdropSlot = 0;
constexpr unsigned int kPadPartsSlot = 1;
constexpr unsigned int kPadJacketSlot = 2;
constexpr unsigned int kPadBannerSlotA = 3;
constexpr unsigned int kPadBannerSlotB = 4;

// The music-jacket quad's pixel size.
constexpr float kPadJacketSize = 180.0f;

// The three proportional-bar reference widths: the two sides' score-comparison bars
// (@ghidraAddress 0x302d60), the per-judgement rows (0x302d64), and the experience bar (0x302d68).
constexpr float kScoreCompareBarWidth = 160.0f;
constexpr float kJudgementBarWidth = 138.0f;
constexpr float kExperienceBarWidth = 210.0f;

// The two stat pages slide this far horizontally as they trade places.
constexpr float kPageSlideTravel = 20.0f;

// The level-up sparkle chase: the rotation counter's period (@ghidraAddress 0x302d6c), the phase
// step between consecutive sparkles (0x3010a0, held as a double in the binary), and their X travel.
constexpr float kSparkleCounterPeriod = 400.0f;
constexpr double kSparklePhaseStep = 0.3;
constexpr float kSparkleTravelX = 5.0f;

// The achievement-rate digits sit two pixels left of their anchor.
constexpr float kRateDigitNudgeX = -2.0f;

// A single-digit difficulty level shifts its digits left to stay centred.
constexpr float kLevelDigitNarrowShiftX = -6.0f;
constexpr int kLevelDigitWideThreshold = 9;

// The inter-glyph gaps the pad path's digit runs use.
constexpr float kDigitGapWide = 2.0f;
constexpr float kDigitGapNarrow = 1.0f;
constexpr float kDigitGapNone = 0.0f;

// The pad panel's part ids.
constexpr unsigned int kPartBackdrop = 0;
constexpr unsigned int kPartConfirmButton = 1;
constexpr unsigned int kPartShareButton = 2;
constexpr unsigned int kPartLaneMarker = 0x15;
constexpr unsigned int kPartJacketFrame = 0x29;
constexpr unsigned int kPartDifficultyBadgeBase = 0x2a;
constexpr unsigned int kPartScoreDeltaUp = 0x49;
constexpr unsigned int kPartScoreDeltaDown = 0x4a;
constexpr unsigned int kPartRankBadgeBase = 0x61;
constexpr unsigned int kPartFullComboBadge = 0x67;
constexpr unsigned int kPartRowIcon = 0x69;
// The judgement-bar family: the great, good, miss, maximum-combo, and rate bars are consecutive
// members, and the two animated rows index the family by the decoration frame instead.
constexpr unsigned int kPartBarFamilyBase = 0x7f;
constexpr unsigned int kPartBarGreat = kPartBarFamilyBase;
constexpr unsigned int kPartBarGood = kPartBarFamilyBase + 1;
constexpr unsigned int kPartBarMiss = kPartBarFamilyBase + 2;
constexpr unsigned int kPartBarMaxCombo = kPartBarFamilyBase + 3;
constexpr unsigned int kPartBarRate = kPartBarFamilyBase + 4;
constexpr unsigned int kPartRateMarker = 0x84;
constexpr unsigned int kPartRateBelowTarget = 0xc6;
constexpr unsigned int kPartRateAboveTarget = 0xc7;
constexpr unsigned int kPartClearRankBase = 0xc9;
constexpr unsigned int kPartExpSeparator = 0xc8;
constexpr unsigned int kPartExpLabel = 0xcf;
constexpr unsigned int kPartExpGainedLabel = 0xda;
constexpr unsigned int kPartExpBarBacking = 0xdb;
constexpr unsigned int kPartExpBar = 0xdc;
constexpr unsigned int kPartExpSparkle = 0xdd;
constexpr unsigned int kPartMatchOutcomeBase = 0xed;

// The glyph-bank bases the pad path's digit runs draw from.
constexpr unsigned int kGlyphLevelBase = 0x2e;
constexpr unsigned int kGlyphScoreBase = 0x3e;
constexpr unsigned int kGlyphRateTargetBase = 0xb1;
constexpr unsigned int kGlyphExpGainedBase = 0xd0;
constexpr unsigned int kGlyphExpThresholdBase = 0x72;

// The digit counts each run draws.
constexpr int kLevelDigitCount = 2;
constexpr int kScoreDigitCount = 4;
constexpr int kRateDigitCount = 4;
constexpr int kExpGainedDigitCount = 4;
constexpr int kExpThresholdDigitCount = 5;

// The multiplier that turns a unit-interval achievement rate into its displayed permille value
// (@ghidraAddress 0x2f8540).
constexpr float kAchievementRateScale = 1000.0f;

// The clear-rank badge family tops out at six tiers.
constexpr int kClearRankTierMax = 5;

// One frame-furniture emit: a part id, its anchor-bank slot, and its X scale (the mirrored halves
// of the frame draw at -1).
struct PadFramePart {
    unsigned int nPartId;
    int nAnchor;
    float flScaleX;
};

// The panel furniture that always draws at the body alpha, in the binary's emit order.
constexpr PadFramePart kPadFrameParts[] = {
    {3, 3, 1.0f},
    {4, 4, -1.0f},
    {5, 5, 1.0f},
    {6, 6, -1.0f},
    {7, 7, 1.0f},
    {8, 8, -1.0f},
    {9, 122, 1.0f},
    {10, 123, 1.0f},
    {11, 124, -1.0f},
    {0xea, 125, 1.0f},
};

// The panel furniture that draws at the panel alpha, above the backdrop.
constexpr PadFramePart kPadHeaderParts[] = {
    {0xe5, 117, 1.0f},
    {0xe6, 118, 1.0f},
    {0xe7, 119, -1.0f},
    {0xe8, 120, 1.0f},
    {0xe9, 121, -1.0f},
};

// The front stat page's frame, drawn straight from the anchor bank at the front-page alpha.
constexpr PadFramePart kFrontPageFrameParts[] = {
    {0x0c, 9, 1.0f},
    {0x0d, 10, -1.0f},
    {0x0e, 11, 1.0f},
    {0x0f, 12, -1.0f},
    {0x10, 13, 1.0f},
    {0x11, 14, -1.0f},
    {0x12, 126, 1.0f},
    {0x13, 127, 1.0f},
    {0x14, 128, -1.0f},
    {0xeb, 129, 1.0f},
    {0xea, 48, 1.0f},
};

// The back stat page's frame, drawn straight from the anchor bank at the back-page alpha.
constexpr PadFramePart kBackPageFrameParts[] = {
    {0x0c, 9, 1.0f},
    {0x0d, 10, -1.0f},
    {0x0e, 11, 1.0f},
    {0x0f, 12, -1.0f},
    {0x10, 13, 1.0f},
    {0x11, 14, -1.0f},
    {0x16, 126, 1.0f},
    {0x17, 127, 1.0f},
    {0x18, 128, -1.0f},
    {0xec, 130, 1.0f},
};

// The front page's slide-relative headings, and the back page's.
constexpr PadFramePart kFrontPageHeadings[] = {
    {0x19, 17, 1.0f}, {0x1a, 18, 1.0f}, {0x1b, 19, 1.0f}};
constexpr PadFramePart kFrontPageFooters[] = {{0x1c, 20, 1.0f}, {0x1d, 21, 1.0f}, {0x1e, 22, 1.0f}};
constexpr PadFramePart kBackPageHeadings[] = {{0x1f, 23, 1.0f}, {0x20, 24, 1.0f}, {0x21, 25, 1.0f}};
constexpr PadFramePart kBackPageFooters[] = {{0x22, 26, 1.0f}, {0x23, 27, 1.0f}, {0x24, 28, 1.0f}};

// The front page's decoration group: a static badge and the two frame-animated rosettes.
constexpr int kFrontPageBadgeAnchor = 49;
constexpr unsigned int kPartFrontPageBadge = 0x68;
constexpr int kFrontPageRosetteAnchorA = 50;
constexpr int kFrontPageRosetteAnchorB = 51;
constexpr unsigned int kPartRosetteBaseA = 0x6a;
constexpr unsigned int kPartRosetteBaseB = 0x6e;

// The two lane markers the single-player pass draws, each as a shadow and then a main pass.
constexpr int kLaneMarkerAnchors[] = {15, 16};
constexpr int kLaneMarkerCount = 2;

// The panel's fixed anchor-bank slots.
constexpr int kBackdropAnchor = 0;
constexpr int kConfirmButtonAnchor = 1;
constexpr int kShareButtonAnchor = 2;
constexpr int kJacketFrameAnchor = 29;
constexpr int kJacketAnchor = 30;
constexpr int kBannerAnchorA = 31;
constexpr int kBannerAnchorB = 32;
constexpr int kDifficultyBadgeAnchor = 33;
constexpr int kDifficultyLevelAnchor = 34;
constexpr int kTargetScoreAnchor = 36;
constexpr int kScoreDeltaSignAnchor = 37;
constexpr int kScoreDeltaAnchor = 38;
constexpr int kSide1LabelAnchor = 39;
constexpr int kSide1BarAnchor = 40;
constexpr int kSide1ScoreAnchor = 41;
constexpr int kSide0LabelAnchor = 42;
constexpr int kSide0BarAnchor = 43;
constexpr int kSide0ScoreAnchor = 44;
constexpr int kMatchOutcomeAnchor = 45;
constexpr int kRankBadgeAnchor = 46;
constexpr int kFullComboAnchor = 47;

// The rank/rate comparison group each side draws on the front page.
constexpr int kSide1RateMarkerAnchor = 86;
constexpr int kSide1RateLabelAnchor = 87;
constexpr int kSide0RateMarkerAnchor = 94;
constexpr int kSide0RateLabelAnchor = 95;

// The experience/level-up group on the back page.
constexpr int kExpLabelAnchor = 102;
constexpr int kExpGainedLabelAnchor = 103;
constexpr int kExpGainedAnchor = 104;
constexpr int kExpProgressAnchor = 105;
constexpr int kExpSeparatorAnchor = 106;
constexpr int kExpThresholdAnchor = 107;
constexpr int kExpBarBackingAnchor = 108;
constexpr int kExpBarAnchor = 109;
constexpr int kExpSparkleAnchors[] = {110, 111, 112};
constexpr int kExpSparkleCount = 3;

// The per-side judgement-row anchor bases: side 0's row starts at 0x45, side 1's at 0x34. Each row
// lays out seventeen consecutive slots from its base.
constexpr int kJudgementRowBase[ResultWindowClassicLayer::kSideCount] = {0x45, 0x34};

// The offsets of each field within a judgement row, from that row's base anchor.
enum JudgementRowSlot {
    kRowGroupIcon = 0x00,
    kRowSideLabel = 0x01,
    kRowJustDigits = 0x02,
    kRowJustBar = 0x03,
    kRowGreatDigits = 0x04,
    kRowGreatBar = 0x05,
    kRowGoodDigits = 0x06,
    kRowGoodBar = 0x07,
    kRowMissDigits = 0x08,
    kRowMissBar = 0x09,
    kRowJustReflecDigits = 0x0a,
    kRowJustReflecBar = 0x0b,
    kRowMaxComboDigits = 0x0c,
    kRowMaxComboBar = 0x0d,
    kRowScoreDigits = 0x0e,
    kRowRateDigits = 0x0f,
    kRowRateBar = 0x10,
};

// The anchor-bank slots one side's rank/achievement-rate comparison block draws into.
struct RankBlockAnchors {
    int nRateDigits;   // the side's achievement-rate digits, and its own rate-bank badge.
    int nTargetDigits; // the target rate's digits.
    int nCompareGlyph; // the above-or-below comparison glyph.
    int nDeltaDigits;  // the signed difference between the two.
    int nRankBadge;    // the clear-rank badge.
};
constexpr RankBlockAnchors kRankBlockAnchors[ResultWindowClassicLayer::kSideCount] = {
    {97, 98, 99, 100, 101},
    {89, 90, 91, 92, 93},
};

// Clamps a rate into the unit interval. The comparison order is the binary's, so a NaN rate falls
// through both tests and lands at zero.
inline float ClampRate(float flRate) {
    const float flCapped = (flRate > 1.0f) ? 1.0f : flRate;
    return (flRate >= 0.0f) ? flCapped : 0.0f;
}

// Offsets a copy of an anchor-bank entry by a page's horizontal slide.
inline S_VECTOR2 AnchorWithSlide(float flSlideX, int nAnchor) {
    S_VECTOR2 position{flSlideX, 0.0f};
    AddVector2(&position, &g_aClassicPartsAnchorPad[nAnchor]);
    return position;
}
} // namespace

/** @ghidraAddress 0x117b84 */
void ResultWindowClassicLayer::RenderResultScoreLayerActive(float flDeltaTime) {
    const unsigned int nPanelAlpha = static_cast<unsigned int>(
        m_aScoreAnimChannels[kScoreChannel].GetCurrent() * static_cast<float>(kFullyOpaqueAlpha));
    const float flBodyScale = m_aScoreAnimChannels[kEffectChannelA].GetCurrent();
    const float flShareScale = m_aScoreAnimChannels[kEffectChannelC].GetCurrent();

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    ScoreTracker *pTracker = ScoreTracker::shared();
    const unsigned int nPlayColor = static_cast<unsigned int>(pGameSystem->GetPlayColor());

    // Every slot restarts empty each frame, whether or not the panel draws.
    for (ne::C_SPRITE_INSTANCING_2D *pSlot : m_apSprites) {
        pSlot->SetSpriteCount(0);
    }

    if (nPanelAlpha == 0) {
        return;
    }

    const unsigned int nBodyAlpha =
        static_cast<unsigned int>(flBodyScale * static_cast<float>(nPanelAlpha));
    const unsigned int nShareAlpha =
        static_cast<unsigned int>(flShareScale * static_cast<float>(nPanelAlpha));

    // The backdrop and the header furniture draw at the panel alpha.
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPadBackdropSlot,
                   kPartBackdrop,
                   g_aClassicPartsAnchorPad[kBackdropAnchor],
                   nPanelAlpha,
                   false);
    for (const PadFramePart &part : kPadHeaderParts) {
        EmitPartSprite(0.0f,
                       part.flScaleX,
                       1.0f,
                       kPadPartsSlot,
                       part.nPartId,
                       g_aClassicPartsAnchorPad[part.nAnchor],
                       nPanelAlpha,
                       false);
    }

    // The confirm and share buttons dim while their own gesture region is held; the share button
    // only exists when the Twitter API is available.
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPadPartsSlot,
                   kPartConfirmButton,
                   g_aClassicPartsAnchorPad[kConfirmButtonAnchor],
                   nPanelAlpha,
                   m_aGestureRegions[0].bDown);
    if (m_bTwitterAvailable) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPadPartsSlot,
                       kPartShareButton,
                       g_aClassicPartsAnchorPad[kShareButtonAnchor],
                       nShareAlpha,
                       m_aGestureRegions[3].bDown);
    }

    for (const PadFramePart &part : kPadFrameParts) {
        EmitPartSprite(0.0f,
                       part.flScaleX,
                       1.0f,
                       kPadPartsSlot,
                       part.nPartId,
                       g_aClassicPartsAnchorPad[part.nAnchor],
                       nBodyAlpha,
                       false);
    }

    // The music jacket and the two banner slots.
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPadPartsSlot,
                   kPartJacketFrame,
                   g_aClassicPartsAnchorPad[kJacketFrameAnchor],
                   nBodyAlpha,
                   false);
    const S_VECTOR2 jacketSize{kPadJacketSize, kPadJacketSize};
    BlitInstancerTextureSlot(
        kPadJacketSlot, g_aClassicPartsAnchorPad[kJacketAnchor], jacketSize, nBodyAlpha);
    RenderSpriteInstancerSlotScaled(
        kPadBannerSlotA, g_aClassicPartsAnchorPad[kBannerAnchorA], nBodyAlpha);
    RenderSpriteInstancerSlotScaled(
        kPadBannerSlotB, g_aClassicPartsAnchorPad[kBannerAnchorB], nBodyAlpha);

    // The difficulty badge and its level digits; a single-digit level shifts left to stay centred.
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPadPartsSlot,
                   kPartDifficultyBadgeBase +
                       static_cast<unsigned int>(pGameSystem->GetDifficulty()),
                   g_aClassicPartsAnchorPad[kDifficultyBadgeAnchor],
                   nBodyAlpha,
                   false);
    const int nDifficultyLevel = pGameSystem->GetDifficultyLevel();
    S_VECTOR2 levelPos = g_aClassicPartsAnchorPad[kDifficultyLevelAnchor];
    if (nDifficultyLevel < kLevelDigitWideThreshold) {
        levelPos.x += kLevelDigitNarrowShiftX;
    }
    RenderDigitSequence(nDifficultyLevel + 1,
                        kLevelDigitCount,
                        &levelPos,
                        kGlyphLevelBase,
                        false,
                        false,
                        nBodyAlpha,
                        kDigitGapWide);

    // The target score and the signed distance from it.
    int nTargetScore = pGameSystem->GetTargetScore();
    if (nTargetScore < 0) {
        nTargetScore = 0;
    }
    int nScoreDelta = pTracker->GetPlayRecordCell(1, 0) - nTargetScore;
    RenderDigitSequence(nTargetScore,
                        kScoreDigitCount,
                        &g_aClassicPartsAnchorPad[kTargetScoreAnchor],
                        kGlyphScoreBase,
                        false,
                        true,
                        nBodyAlpha,
                        kDigitGapWide);
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPadPartsSlot,
                   nScoreDelta < 0 ? kPartScoreDeltaDown : kPartScoreDeltaUp,
                   g_aClassicPartsAnchorPad[kScoreDeltaSignAnchor],
                   nBodyAlpha,
                   false);
    if (nScoreDelta < 0) {
        nScoreDelta = -nScoreDelta;
    }
    RenderDigitSequence(nScoreDelta,
                        kScoreDigitCount,
                        &g_aClassicPartsAnchorPad[kScoreDeltaAnchor],
                        kGlyphScoreBase,
                        false,
                        true,
                        nBodyAlpha,
                        kDigitGapWide);

    // The two sides' score-comparison bars: the leading side's bar runs full width and the trailing
    // side's is scaled by their ratio; both are zero only when neither side scored.
    const int nSide1Score = pTracker->GetPlayRecordCell(1, 0);
    const int nSide0Score = pTracker->GetPlayRecordCell(0, 0);
    float flSide1Ratio = (nSide0Score != 0 || nSide1Score != 0) ? 1.0f : 0.0f;
    float flSide0Ratio = flSide1Ratio;
    if (nSide0Score < nSide1Score) {
        flSide1Ratio = 1.0f;
        flSide0Ratio = static_cast<float>(nSide0Score) / static_cast<float>(nSide1Score);
    }
    if (nSide1Score < nSide0Score) {
        flSide0Ratio = 1.0f;
        flSide1Ratio = static_cast<float>(nSide1Score) / static_cast<float>(nSide0Score);
    }

    // The play colour swaps which side owns which label, bar, and digit bank.
    const bool bColorSwapped = nPlayColor != 0;
    const unsigned int nSide1LabelPart = bColorSwapped ? 0x26 : 0x25;
    const unsigned int nSide0LabelPart = bColorSwapped ? 0x27 : 0x28;
    const unsigned int nSide1BarPart = bColorSwapped ? 0x4c : 0x4b;
    const unsigned int nSide0BarPart = bColorSwapped ? 0x4b : 0x4c;
    const unsigned int nSide1GlyphBase = bColorSwapped ? 0x57 : 0x4d;
    const unsigned int nSide0GlyphBase = bColorSwapped ? 0x4d : 0x57;

    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPadPartsSlot,
                   nSide1LabelPart,
                   g_aClassicPartsAnchorPad[kSide1LabelAnchor],
                   nBodyAlpha,
                   false);
    EmitPartSprite(0.0f,
                   flSide1Ratio * kScoreCompareBarWidth,
                   1.0f,
                   kPadPartsSlot,
                   nSide1BarPart,
                   g_aClassicPartsAnchorPad[kSide1BarAnchor],
                   nBodyAlpha,
                   false);
    RenderDigitSequence(nSide1Score,
                        kScoreDigitCount,
                        &g_aClassicPartsAnchorPad[kSide1ScoreAnchor],
                        nSide1GlyphBase,
                        false,
                        true,
                        nBodyAlpha,
                        kDigitGapNone);
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPadPartsSlot,
                   nSide0LabelPart,
                   g_aClassicPartsAnchorPad[kSide0LabelAnchor],
                   nBodyAlpha,
                   false);
    EmitPartSprite(0.0f,
                   flSide0Ratio * kScoreCompareBarWidth,
                   1.0f,
                   kPadPartsSlot,
                   nSide0BarPart,
                   g_aClassicPartsAnchorPad[kSide0BarAnchor],
                   nBodyAlpha,
                   false);
    RenderDigitSequence(nSide0Score,
                        kScoreDigitCount,
                        &g_aClassicPartsAnchorPad[kSide0ScoreAnchor],
                        nSide0GlyphBase,
                        false,
                        true,
                        nBodyAlpha,
                        kDigitGapNone);

    // The match-outcome and clear-rank badges, and the full-combo badge when the maximum combo
    // covers every note in the chart.
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPadPartsSlot,
                   kPartMatchOutcomeBase +
                       static_cast<unsigned int>(pTracker->GetPlayRecordField10(1)),
                   g_aClassicPartsAnchorPad[kMatchOutcomeAnchor],
                   nBodyAlpha,
                   false);
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPadPartsSlot,
                   kPartRankBadgeBase + static_cast<unsigned int>(pTracker->GetPlayRecordRank(1)),
                   g_aClassicPartsAnchorPad[kRankBadgeAnchor],
                   nBodyAlpha,
                   false);
    const int nTotalNotes = pTracker->GetTotalNotes();
    if (nTotalNotes == pTracker->GetPlayRecordCell(1, 2)) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPadPartsSlot,
                       kPartFullComboBadge,
                       g_aClassicPartsAnchorPad[kFullComboAnchor],
                       nBodyAlpha,
                       false);
    }

    // The stat area cross-fades between two horizontally sliding pages. The signed slide timer
    // drives both the alphas and the travel; a networked play leads with the opposite page, so the
    // two assignments are mirrored.
    const float flSlide = m_flSlideTimer;
    const float flSlideMagnitude = std::fabs(flSlide);
    float flFrontAlpha = 0.0f;
    float flBackAlpha = 0.0f;
    float flFrontSlideX = 0.0f;
    float flBackSlideX = 0.0f;
    if (m_nNetworkPlay == 1) {
        flBackAlpha = static_cast<float>(nShareAlpha) * flSlideMagnitude;
        flFrontAlpha = static_cast<float>(nShareAlpha) * (1.0f - flSlideMagnitude);
        flFrontSlideX = flSlide * -kPageSlideTravel;
        flBackSlideX =
            (1.0f - flSlideMagnitude) * (flSlide <= 0.0f ? -kPageSlideTravel : kPageSlideTravel);
    } else {
        flBackAlpha = static_cast<float>(nShareAlpha) * (1.0f - flSlideMagnitude);
        flFrontAlpha = static_cast<float>(nShareAlpha) * flSlideMagnitude;
        flBackSlideX = flSlide * -kPageSlideTravel;
        flFrontSlideX =
            (1.0f - flSlideMagnitude) * (flSlide > 0.0f ? kPageSlideTravel : -kPageSlideTravel);
    }
    const S_VECTOR2 backPageOrigin{flBackSlideX, 0.0f};
    const unsigned int nFrontAlpha = static_cast<unsigned int>(flFrontAlpha);

    // The front page's frame draws straight from the anchor bank; only its content slides.
    for (const PadFramePart &part : kFrontPageFrameParts) {
        EmitPartSprite(0.0f,
                       part.flScaleX,
                       1.0f,
                       kPadPartsSlot,
                       part.nPartId,
                       g_aClassicPartsAnchorPad[part.nAnchor],
                       nFrontAlpha,
                       false);
    }
    for (const PadFramePart &part : kFrontPageHeadings) {
        const S_VECTOR2 position = AnchorWithSlide(flFrontSlideX, part.nAnchor);
        EmitPartSprite(
            0.0f, part.flScaleX, 1.0f, kPadPartsSlot, part.nPartId, position, nFrontAlpha, false);
    }
    {
        const S_VECTOR2 badgePos = AnchorWithSlide(flFrontSlideX, kFrontPageBadgeAnchor);
        EmitPartSprite(
            0.0f, 1.0f, 1.0f, kPadPartsSlot, kPartFrontPageBadge, badgePos, nFrontAlpha, false);
        const S_VECTOR2 rosetteA = AnchorWithSlide(flFrontSlideX, kFrontPageRosetteAnchorA);
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPadPartsSlot,
                       kPartRosetteBaseA + static_cast<unsigned int>(m_nRotationFrame),
                       rosetteA,
                       nFrontAlpha,
                       false);
        const S_VECTOR2 rosetteB = AnchorWithSlide(flFrontSlideX, kFrontPageRosetteAnchorB);
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPadPartsSlot,
                       kPartRosetteBaseB + static_cast<unsigned int>(m_nRotationFrame),
                       rosetteB,
                       nFrontAlpha,
                       false);
    }

    // One judgement row per side: a digit column and a proportional bar for each counter. The just
    // and just-reflec bars index the bar family by the decoration frame, so they animate.
    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        const unsigned int uSide = static_cast<unsigned int>(nSide);
        const int nJust = pTracker->GetPlayRecordCell(uSide, 3);
        const int nGreat = pTracker->GetPlayRecordCell(uSide, 4);
        const int nGood = pTracker->GetPlayRecordCell(uSide, 5);
        const int nMiss = pTracker->GetPlayRecordCell(uSide, 6);
        const int nJustReflec = pTracker->GetPlayRecordCell(uSide, 7);
        const int nMaxCombo = pTracker->GetPlayRecordCell(uSide, 2);
        const int nScore = pTracker->GetPlayRecordCell(uSide, 0);
        const int nRowTotalNotes = pTracker->GetTotalNotes();
        const float flRate = pTracker->GetPlayRecordRate(uSide);

        // Side 0 reads the play colour's score slot; side 1 reads the other one.
        const int nScoreSlot =
            (nSide == 0) ? static_cast<int>(nPlayColor) : ((nPlayColor == 0) ? 1 : 0);
        const int nSideResultScore = m_aResultScores[nScoreSlot];

        const int nRowBase = kJudgementRowBase[nSide];
        const float flTotal = static_cast<float>(nRowTotalNotes);
        const unsigned int nAnimatedBar =
            kPartBarFamilyBase + static_cast<unsigned int>(m_nRotationFrame);

        S_VECTOR2 position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowGroupIcon);
        EmitPartSprite(0.0f, 1.0f, 1.0f, kPadPartsSlot, kPartRowIcon, position, nFrontAlpha, false);

        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowSideLabel);
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPadPartsSlot,
                       (nSide == 1) ? nSide1LabelPart : nSide0LabelPart,
                       position,
                       nFrontAlpha,
                       false);

        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowJustDigits);
        RenderScoreDigitsCompact(nJust, position, nFrontAlpha);
        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowJustBar);
        EmitPartSprite(0.0f,
                       (static_cast<float>(nJust) / flTotal) * kJudgementBarWidth,
                       1.0f,
                       kPadPartsSlot,
                       nAnimatedBar,
                       position,
                       nFrontAlpha,
                       false);

        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowGreatDigits);
        RenderScoreDigitsCompact(nGreat, position, nFrontAlpha);
        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowGreatBar);
        EmitPartSprite(0.0f,
                       (static_cast<float>(nGreat) / flTotal) * kJudgementBarWidth,
                       1.0f,
                       kPadPartsSlot,
                       kPartBarGreat,
                       position,
                       nFrontAlpha,
                       false);

        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowGoodDigits);
        RenderScoreDigitsCompact(nGood, position, nFrontAlpha);
        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowGoodBar);
        EmitPartSprite(0.0f,
                       (static_cast<float>(nGood) / flTotal) * kJudgementBarWidth,
                       1.0f,
                       kPadPartsSlot,
                       kPartBarGood,
                       position,
                       nFrontAlpha,
                       false);

        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowMissDigits);
        RenderScoreDigitsCompact(nMiss, position, nFrontAlpha);
        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowMissBar);
        EmitPartSprite(0.0f,
                       (static_cast<float>(nMiss) / flTotal) * kJudgementBarWidth,
                       1.0f,
                       kPadPartsSlot,
                       kPartBarMiss,
                       position,
                       nFrontAlpha,
                       false);

        // The just-reflec row measures against the side's seeded result score, not the note total.
        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowJustReflecDigits);
        RenderScoreDigitsWithDot(nJustReflec, nSideResultScore, position, nFrontAlpha);
        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowJustReflecBar);
        EmitPartSprite(0.0f,
                       (static_cast<float>(nJustReflec) / static_cast<float>(nSideResultScore)) *
                           kJudgementBarWidth,
                       1.0f,
                       kPadPartsSlot,
                       nAnimatedBar,
                       position,
                       nFrontAlpha,
                       false);

        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowMaxComboDigits);
        RenderScoreDigitsWithDot(nMaxCombo, nRowTotalNotes, position, nFrontAlpha);
        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowMaxComboBar);
        EmitPartSprite(0.0f,
                       (static_cast<float>(nMaxCombo) / flTotal) * kJudgementBarWidth,
                       1.0f,
                       kPadPartsSlot,
                       kPartBarMaxCombo,
                       position,
                       nFrontAlpha,
                       false);

        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowScoreDigits);
        RenderScoreDigitsCompact(nScore, position, nFrontAlpha);

        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowRateDigits);
        RenderScorePaddedWithDot(
            static_cast<int>(flRate * kAchievementRateScale), position, nFrontAlpha);
        position = AnchorWithSlide(flFrontSlideX, nRowBase + kRowRateBar);
        EmitPartSprite(0.0f,
                       flRate * kJudgementBarWidth,
                       1.0f,
                       kPadPartsSlot,
                       kPartBarRate,
                       position,
                       nFrontAlpha,
                       false);
    }

    for (const PadFramePart &part : kFrontPageFooters) {
        const S_VECTOR2 position = AnchorWithSlide(flFrontSlideX, part.nAnchor);
        EmitPartSprite(
            0.0f, part.flScaleX, 1.0f, kPadPartsSlot, part.nPartId, position, nFrontAlpha, false);
    }

    const unsigned int nBackAlpha = static_cast<unsigned int>(flBackAlpha);

    // Each side's achievement rate against the target rate: its own digits, the target's digits, an
    // above-or-below glyph, the signed difference, and the clear-rank badge.
    const auto RenderRankBlock = [&](int nSide) {
        S_VECTOR2 position;
        const unsigned int uSide = static_cast<unsigned int>(nSide);
        const float flRate = ClampRate(pTracker->GetPlayRecordRate(uSide));
        const float flTargetRate = ClampRate(pGameSystem->GetTargetAR());
        const int nRank = pTracker->GetPlayRecordRank(uSide);
        const int nRankTier = (nRank < kClearRankTierMax + 1) ? nRank : kClearRankTierMax;
        const RankBlockAnchors &anchors = kRankBlockAnchors[nSide];

        // A swapped play colour trades the two sides' rate banks and badges.
        const bool bSideOne = nSide == 1;
        const unsigned int nRateGlyphBase = (bSideOne == (nPlayColor != 0)) ? 0x9b : 0x85;
        const unsigned int nRateBadgePart = (bSideOne == (nPlayColor != 0)) ? 0xb0 : 0x9a;

        S_VECTOR2 rateDigitPos = AnchorWithSlide(flFrontSlideX, anchors.nRateDigits);
        S_VECTOR2 nudge{kRateDigitNudgeX, 0.0f};
        AddVector2(&rateDigitPos, &nudge);
        int nRateValue = static_cast<int>(flRate * kAchievementRateScale);
        RenderDigitSequence(nRateValue,
                            kRateDigitCount,
                            &rateDigitPos,
                            nRateGlyphBase,
                            true,
                            false,
                            nFrontAlpha,
                            kDigitGapWide);

        position = AnchorWithSlide(flFrontSlideX, anchors.nRateDigits);
        EmitPartSprite(
            0.0f, 1.0f, 1.0f, kPadPartsSlot, nRateBadgePart, position, nFrontAlpha, false);

        S_VECTOR2 targetPos = AnchorWithSlide(flFrontSlideX, anchors.nTargetDigits);
        const int nTargetValue = static_cast<int>(flTargetRate * kAchievementRateScale);
        RenderDigitSequence(nTargetValue,
                            kRateDigitCount,
                            &targetPos,
                            kGlyphRateTargetBase,
                            true,
                            false,
                            nFrontAlpha,
                            kDigitGapNarrow);

        // The delta position is resolved before the branch, as the binary does.
        S_VECTOR2 deltaPos = AnchorWithSlide(flFrontSlideX, anchors.nDeltaDigits);
        position = AnchorWithSlide(flFrontSlideX, anchors.nCompareGlyph);
        int nDelta = 0;
        if (flRate <= flTargetRate) {
            EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kPadPartsSlot,
                           kPartRateAboveTarget,
                           position,
                           nFrontAlpha,
                           false);
            nDelta = nTargetValue - nRateValue;
        } else {
            EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kPadPartsSlot,
                           kPartRateBelowTarget,
                           position,
                           nFrontAlpha,
                           false);
            nDelta = nRateValue - nTargetValue;
        }
        RenderDigitSequence(nDelta,
                            kRateDigitCount,
                            &deltaPos,
                            kGlyphRateTargetBase,
                            true,
                            false,
                            nFrontAlpha,
                            kDigitGapNarrow);

        const unsigned int nRankPart =
            (nRank < 0) ? kPartClearRankBase :
                          (kPartClearRankBase + static_cast<unsigned int>(nRankTier));
        position = AnchorWithSlide(flFrontSlideX, anchors.nRankBadge);
        EmitPartSprite(0.0f, 1.0f, 1.0f, kPadPartsSlot, nRankPart, position, nFrontAlpha, false);
    };

    // Side one leads with the rate marker, side zero with its label: the binary emits the pair in
    // the opposite order for each side.
    {
        S_VECTOR2 position = AnchorWithSlide(flFrontSlideX, kSide1RateMarkerAnchor);
        EmitPartSprite(
            0.0f, 1.0f, 1.0f, kPadPartsSlot, kPartRateMarker, position, nFrontAlpha, false);
        position = AnchorWithSlide(flFrontSlideX, kSide1RateLabelAnchor);
        EmitPartSprite(
            0.0f, 1.0f, 1.0f, kPadPartsSlot, nSide1LabelPart, position, nFrontAlpha, false);
    }
    RenderRankBlock(1);
    {
        S_VECTOR2 position = AnchorWithSlide(flFrontSlideX, kSide0RateLabelAnchor);
        EmitPartSprite(
            0.0f, 1.0f, 1.0f, kPadPartsSlot, nSide0LabelPart, position, nFrontAlpha, false);
        position = AnchorWithSlide(flFrontSlideX, kSide0RateMarkerAnchor);
        EmitPartSprite(
            0.0f, 1.0f, 1.0f, kPadPartsSlot, kPartRateMarker, position, nFrontAlpha, false);
    }
    RenderRankBlock(0);

    // The back page: its frame draws straight from the anchor bank, its content from the page
    // origin.
    for (const PadFramePart &part : kBackPageFrameParts) {
        EmitPartSprite(0.0f,
                       part.flScaleX,
                       1.0f,
                       kPadPartsSlot,
                       part.nPartId,
                       g_aClassicPartsAnchorPad[part.nAnchor],
                       nBackAlpha,
                       false);
    }
    for (const PadFramePart &part : kBackPageHeadings) {
        S_VECTOR2 position = backPageOrigin;
        AddVector2(&position, &g_aClassicPartsAnchorPad[part.nAnchor]);
        EmitPartSprite(
            0.0f, part.flScaleX, 1.0f, kPadPartsSlot, part.nPartId, position, nBackAlpha, false);
    }

    // The experience/level-up group.
    const int nDeltaFrames = static_cast<int>(flDeltaTime);
    const float flExpProgress = AdvanceCustomizeOverlayProgress(nDeltaFrames);
    int nExpThreshold = m_nExpThreshold;
    if (nExpThreshold < 0) {
        nExpThreshold = 0;
    }

    S_VECTOR2 position = backPageOrigin;
    AddVector2(&position, &g_aClassicPartsAnchorPad[kExpLabelAnchor]);
    EmitPartSprite(0.0f, 1.0f, 1.0f, kPadPartsSlot, kPartExpLabel, position, nBackAlpha, false);
    position = backPageOrigin;
    AddVector2(&position, &g_aClassicPartsAnchorPad[kExpGainedLabelAnchor]);
    EmitPartSprite(
        0.0f, 1.0f, 1.0f, kPadPartsSlot, kPartExpGainedLabel, position, nBackAlpha, false);

    // The gained-experience digits round-trip the field through a float, as the binary does.
    position = backPageOrigin;
    AddVector2(&position, &g_aClassicPartsAnchorPad[kExpGainedAnchor]);
    RenderDigitSequence(static_cast<int>(static_cast<float>(m_nGainedExp)),
                        kExpGainedDigitCount,
                        &position,
                        kGlyphExpGainedBase,
                        false,
                        true,
                        nBackAlpha,
                        kDigitGapWide);
    position = backPageOrigin;
    AddVector2(&position, &g_aClassicPartsAnchorPad[kExpProgressAnchor]);
    RenderDigitSequence(static_cast<int>(flExpProgress * static_cast<float>(nExpThreshold)),
                        kExpThresholdDigitCount,
                        &position,
                        kGlyphExpGainedBase,
                        false,
                        true,
                        nBackAlpha,
                        kDigitGapWide);
    position = backPageOrigin;
    AddVector2(&position, &g_aClassicPartsAnchorPad[kExpSeparatorAnchor]);
    EmitPartSprite(0.0f, 1.0f, 1.0f, kPadPartsSlot, kPartExpSeparator, position, nBackAlpha, false);
    position = backPageOrigin;
    AddVector2(&position, &g_aClassicPartsAnchorPad[kExpThresholdAnchor]);
    RenderDigitSequence(nExpThreshold,
                        kExpThresholdDigitCount,
                        &position,
                        kGlyphExpThresholdBase,
                        false,
                        true,
                        nBackAlpha,
                        kDigitGapNarrow);
    position = backPageOrigin;
    AddVector2(&position, &g_aClassicPartsAnchorPad[kExpBarBackingAnchor]);
    EmitPartSprite(
        0.0f, 1.0f, 1.0f, kPadPartsSlot, kPartExpBarBacking, position, nBackAlpha, false);
    position = backPageOrigin;
    AddVector2(&position, &g_aClassicPartsAnchorPad[kExpBarAnchor]);
    EmitPartSprite(0.0f,
                   flExpProgress * kExperienceBarWidth,
                   1.0f,
                   kPadPartsSlot,
                   kPartExpBar,
                   position,
                   nBackAlpha,
                   false);

    m_flResultElapsed += flDeltaTime;

    // Three sparkles chase along the experience bar while the main customize asset is shown. Each
    // trails the previous one by a fixed phase, wrapping back through zero, and the whole group
    // drifts right as the rotation counter runs.
    if (m_bMainAssetActive) {
        const float flPhase = static_cast<float>(m_nRotationCounterA) / kSparkleCounterPeriod;
        float flLevel = 1.0f - flPhase;
        const float flSparkleX = backPageOrigin.x + flPhase * kSparkleTravelX;
        for (int nSparkle = 0; nSparkle < kExpSparkleCount; ++nSparkle) {
            if (nSparkle != 0) {
                const float flStepped =
                    static_cast<float>(static_cast<double>(flLevel) + kSparklePhaseStep);
                flLevel = (flStepped > 1.0f) ? (flStepped - 1.0f) : flStepped;
            }
            S_VECTOR2 sparklePos{flSparkleX, backPageOrigin.y};
            AddVector2(&sparklePos, &g_aClassicPartsAnchorPad[kExpSparkleAnchors[nSparkle]]);
            EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kPadPartsSlot,
                           kPartExpSparkle,
                           sparklePos,
                           static_cast<unsigned int>(
                               static_cast<int>(static_cast<float>(nBackAlpha) * flLevel)),
                           false);
        }
    }

    RenderCustomizePhoneOverlay(nDeltaFrames, &backPageOrigin, static_cast<float>(nBackAlpha));

    for (const PadFramePart &part : kBackPageFooters) {
        S_VECTOR2 footerPos = backPageOrigin;
        AddVector2(&footerPos, &g_aClassicPartsAnchorPad[part.nAnchor]);
        EmitPartSprite(
            0.0f, part.flScaleX, 1.0f, kPadPartsSlot, part.nPartId, footerPos, nBackAlpha, false);
    }

    RenderCustomizeNameplateOverlay(nDeltaFrames, &backPageOrigin, static_cast<float>(nBackAlpha));

    // A single-player game draws the two lane markers twice: a half-intensity shadow pass at the
    // share alpha, then the main pass, whose two markers take the back and front page alphas.
    if ((pGameSystem->GetGameType() | 2) == 2) {
        for (int nMarker : kLaneMarkerAnchors) {
            S_VECTOR2 markerPos{};
            AddVector2(&markerPos, &g_aClassicPartsAnchorPad[nMarker]);
            EmitPartSprite(
                0.0f, 1.0f, 1.0f, kPadPartsSlot, kPartLaneMarker, markerPos, nShareAlpha, true);
        }
        const unsigned int aMarkerAlpha[] = {nBackAlpha, nFrontAlpha};
        for (int nMarker = 0; nMarker < kLaneMarkerCount; ++nMarker) {
            S_VECTOR2 markerPos{};
            AddVector2(&markerPos, &g_aClassicPartsAnchorPad[kLaneMarkerAnchors[nMarker]]);
            EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kPadPartsSlot,
                           kPartLaneMarker,
                           markerPos,
                           aMarkerAlpha[nMarker],
                           false);
        }
    }
}

namespace {
// The instancer slots the phone render path draws into.
constexpr unsigned int kPhoneBackdropSlot = 0;
constexpr unsigned int kPhoneGlyphSlot = 1;
constexpr unsigned int kPhoneJacketSlot = 2;
constexpr unsigned int kPhoneBannerSlotA = 3;
constexpr unsigned int kPhoneBannerSlotB = 4;

// The music-jacket quad's pixel size on the phone layout.
constexpr float kPhoneJacketSize = 82.0f;
// The banner slots draw at full intensity when the layer is in its landscape orientation.
constexpr unsigned int kBannerFullIntensity = 255;

// A nine-slice box insets its corner glyphs by this much, so each stretched edge loses twice it.
constexpr float kNineSliceCornerInset = 9.0f;
constexpr float kNineSliceEdgeTrim = kNineSliceCornerInset * 2.0f;

// The outer frame's stretch insets: the rail that spans the viewport, the header bar, and the caps
// at each end of the notch in the stats box's top edge.
constexpr float kFrameRailInset = 22.0f;
constexpr float kHeaderBarInset = 24.0f;
constexpr float kNotchCapInset = 15.0f;
constexpr float kNotchCapTrim = kNotchCapInset * 2.0f;

// The per-side stat header rotates a quarter turn in landscape and sits upright in portrait
// (@ghidraAddress 0x302d74 and 0x302d78).
constexpr float kSideHeaderRotationSide0 = -1.5707964f;
constexpr float kSideHeaderRotationSide1 = 1.5707964f;

// The phone experience bar's full width (@ghidraAddress 0x302d7c).
constexpr float kPhoneExperienceBarWidth = 112.0f;

// The phone panel's glyph codes.
constexpr unsigned int kPhoneGlyphBackdrop = 0;
constexpr unsigned int kPhoneGlyphShareButton = 1;
constexpr unsigned int kPhoneGlyphFrameCornerTop = 0x6a;
constexpr unsigned int kPhoneGlyphFrameEdgeA = 0x6b;
constexpr unsigned int kPhoneGlyphFrameEdgeB = 0x6c;
constexpr unsigned int kPhoneGlyphFrameEdgeC = 0x6d;
constexpr unsigned int kPhoneGlyphRailCap = 0x6e;
constexpr unsigned int kPhoneGlyphRailJoint = 0x6f;
constexpr unsigned int kPhoneGlyphRailSpan = 0x70;
constexpr unsigned int kPhoneGlyphHeaderCap = 0x71;
constexpr unsigned int kPhoneGlyphHeaderSpan = 0x72;
constexpr unsigned int kPhoneGlyphHeaderBadge = 0x73;
constexpr unsigned int kPhoneGlyphMusicTitle = 0xe;
constexpr unsigned int kPhoneGlyphScoreLabel = 0x12;
constexpr unsigned int kPhoneGlyphDifficultyBase = 0x13;
constexpr unsigned int kPhoneGlyphTargetLabel = 0xf;
constexpr unsigned int kPhoneGlyphScoreSeparator = 0x21;
constexpr unsigned int kPhoneGlyphDeltaUp = 0x22;
constexpr unsigned int kPhoneGlyphDeltaDown = 0x23;
constexpr unsigned int kPhoneGlyphJacketBadge = 0x10;
constexpr unsigned int kPhoneGlyphRankBase = 0x2e;
constexpr unsigned int kPhoneGlyphFullCombo = 0x34;
constexpr unsigned int kPhoneGlyphRankLabel = 0x11;
constexpr unsigned int kPhoneGlyphMatchOutcomeBase = 0x74;
constexpr unsigned int kPhoneGlyphStatsTab = 0x78;
constexpr unsigned int kPhoneGlyphExpTab = 0x77;
constexpr unsigned int kPhoneGlyphLaneMarker = 0x65;
constexpr unsigned int kPhoneGlyphExpSparkle = 0x63;
constexpr unsigned int kPhoneGlyphExpBar = 0x62;

// The glyph banks the phone path's number fields draw from.
constexpr unsigned int kPhoneGlyphBankTarget = 0x17;
constexpr unsigned int kPhoneGlyphBankScore = 0x24;
constexpr unsigned int kPhoneGlyphBankExpGained = 0x55;
constexpr unsigned int kPhoneGlyphBankExpThreshold = 0x39;

// The two nine-slice boxes the panel draws, each from a pair of phone position records. The glyph
// family runs corner, horizontal edge, vertical edge, centre from its base code.
constexpr unsigned int kNineSliceOuterBase = 2;
constexpr unsigned int kNineSliceInnerBase = 6;
constexpr int kOuterBoxPositionA = 1;
constexpr int kOuterBoxPositionB = 2;
constexpr int kInnerBoxPositionA = 3;
constexpr int kInnerBoxPositionB = 4;

// The notched stats box: its two corners plus the two ends of the notch in its top edge.
constexpr int kStatsBoxCornerA = 0x4d;
constexpr int kStatsBoxCornerB = 0x4e;
constexpr int kStatsBoxNotchStart = 0x4f;
constexpr int kStatsBoxNotchEnd = 0x50;
constexpr unsigned int kNotchCapGlyph = 10;
constexpr unsigned int kNotchSpanGlyph = 0xb;

// The phone position records the fixed panel furniture resolves from.
constexpr int kPhonePosBackdrop = 0;
constexpr int kPhonePosShareButton = 0x42;
constexpr int kPhonePosFrameCornerTop = 0x43;
constexpr int kPhonePosFrameEdgeA = 0x44;
constexpr int kPhonePosFrameEdgeB = 0x45;
constexpr int kPhonePosFrameEdgeC = 0x46;
constexpr int kPhonePosFrameEdgeBMirror = 0x47;
constexpr int kPhonePosFrameEdgeAMirror = 0x48;
constexpr int kPhonePosRailCap = 0x49;
constexpr int kPhonePosRailJoint = 0x4a;
constexpr int kPhonePosHeaderCap = 0x4b;
constexpr int kPhonePosHeaderBadge = 0x4c;
constexpr int kPhonePosJacket = 7;
constexpr int kPhonePosBannerA = 5;
constexpr int kPhonePosBannerB = 6;
constexpr int kPhonePosMusicTitle = 8;
constexpr int kPhonePosScoreLabel = 9;
constexpr int kPhonePosDifficulty = 10;
constexpr int kPhonePosTargetLabel = 0xb;
constexpr int kPhonePosTargetDigits = 0xc;
constexpr int kPhonePosScoreSeparator = 0xd;
constexpr int kPhonePosDeltaGlyph = 0xe;
constexpr int kPhonePosDeltaDigits = 0xf;
constexpr int kPhonePosScoreSeparatorMirror = 0x10;
constexpr int kPhonePosScoreDigits = 0x11;
constexpr int kPhonePosJacketBadge = 0x12;
constexpr int kPhonePosRankBadge = 0x13;
constexpr int kPhonePosFullCombo = 0x14;
constexpr int kPhonePosRankLabel = 0x15;
constexpr int kPhonePosMatchOutcome = 0x16;
constexpr int kPhonePosPageTabs = 0x51;
constexpr int kPhonePosLaneMarkerA = 0x40;
constexpr int kPhonePosLaneMarkerB = 0x41;

// The rotating decoration row above the stats: five frame-animated or fixed glyphs and their
// position records.
struct PhoneDecoration {
    unsigned int nCharCode; // the glyph code, or the animation base when bAnimated is set.
    int nPositionIndex;
    bool bAnimated; // whether the decoration frame index is added to the glyph code.
};
constexpr PhoneDecoration kPhoneDecorations[] = {
    {0x47, 0x17, true},
    {0x4b, 0x18, false},
    {0x4c, 0x19, false},
    {0x4d, 0x1a, false},
    {0x4e, 0x1b, true},
    {0x52, 0x1c, false},
    {0x53, 0x1d, false},
    {0x54, 0x1e, false},
};

// The exp page's fixed glyph row.
struct PhoneExpPart {
    unsigned int nCharCode;
    int nPositionIndex;
};
constexpr PhoneExpPart kPhoneExpParts[] = {
    {0x66, 0x31},
    {0x67, 0x32},
    {0x68, 0x33},
    {0x5f, 0x34},
    {0x60, 0x38},
    {0x61, 0x39},
};

// The separator glyphs drawn straight from the separator table, before the pages split. The two
// glyph codes are the thin and thick rules.
constexpr unsigned int kSeparatorRuleThin = 0xc;
constexpr unsigned int kSeparatorRuleThick = 0xd;
struct PhoneSeparator {
    int nIndex;
    unsigned int nCharCode;
};
constexpr PhoneSeparator kPanelSeparators[] = {
    {0, kSeparatorRuleThin},
    {1, kSeparatorRuleThin},
    {2, kSeparatorRuleThick},
    {3, kSeparatorRuleThick},
    {4, kSeparatorRuleThick},
    {5, kSeparatorRuleThick},
    {6, kSeparatorRuleThin},
    {7, kSeparatorRuleThin},
    {8, kSeparatorRuleThin},
    {9, kSeparatorRuleThin},
    {10, kSeparatorRuleThin},
    {11, kSeparatorRuleThin},
};

// The separator ranges the two pages carry, each drawn at its own page offset and alpha.
constexpr int kStatsSeparatorFirst = 0x0c;
constexpr int kStatsSeparatorLast = 0x27;
constexpr int kExpSeparatorFirst = 0x28;
constexpr int kExpSeparatorLast = 0x2d;

// Each side's stat row: a header glyph at its own position record, then eight value fields laid out
// from the row's base position record.
constexpr int kStatRowBase[ResultWindowClassicLayer::kSideCount] = {0x29, 0x20};
constexpr int kStatRowHeaderPosition[ResultWindowClassicLayer::kSideCount] = {0x28, 0x1f};
enum PhoneStatRowSlot {
    kPhoneRowJust = 0,
    kPhoneRowGreat = 1,
    kPhoneRowGood = 2,
    kPhoneRowMiss = 3,
    kPhoneRowJustReflec = 4,
    kPhoneRowMaxCombo = 5,
    kPhoneRowScore = 6,
    kPhoneRowRate = 7,
};

// The exp page's number fields and their position records.
constexpr int kPhonePosExpGained = 0x35;
constexpr int kPhonePosExpProgress = 0x36;
constexpr int kPhonePosExpThreshold = 0x37;
constexpr int kPhonePosExpBar = 0x3a;
constexpr int kPhonePosExpSparkle = 0x3b;

constexpr int kPhoneExpGainedDigitCount = 4;
constexpr int kPhoneExpThresholdDigitCount = 5;
constexpr int kPhoneScoreDigitCount = 4;
} // namespace

/** @ghidraAddress 0x11a10c */
void ResultWindowClassicLayer::RenderResultScoreLayerIdle(float flDeltaTime) {
    const unsigned int nPanelAlpha = static_cast<unsigned int>(
        m_aScoreAnimChannels[kScoreChannel].GetCurrent() * static_cast<float>(kFullyOpaqueAlpha));
    const float flPanelAlpha = static_cast<float>(nPanelAlpha);
    const float flBodyScale = m_aScoreAnimChannels[kEffectChannelA].GetCurrent();
    const float flShareScale = m_aScoreAnimChannels[kEffectChannelC].GetCurrent();
    const float flTabScale = m_aScoreAnimChannels[kEffectChannelD].GetCurrent();

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    ScoreTracker *pTracker = ScoreTracker::shared();
    const unsigned int nPlayColor = static_cast<unsigned int>(pGameSystem->GetPlayColor());
    // The binary re-reads the game system for the viewport width the frame rails span.
    GameSystem *pViewportSystem = GameSystem::GetGameSystem();

    for (ne::C_SPRITE_INSTANCING_2D *pSlot : m_apSprites) {
        pSlot->SetSpriteCount(0);
    }

    if (nPanelAlpha == 0) {
        return;
    }

    const unsigned int nBodyAlpha = static_cast<unsigned int>(flBodyScale * flPanelAlpha);

    // Resolves a phone-layout position record.
    const auto PositionAt = [&](int nIndex) {
        S_VECTOR2 position{};
        getPosition_Phone(nIndex, &position);
        return position;
    };
    // Emits one glyph into the panel's glyph slot.
    const auto EmitGlyph = [&](unsigned int nCharCode,
                               const S_VECTOR2 &position,
                               unsigned int nAlpha,
                               bool bDimmed,
                               float flScaleX,
                               float flScaleY) {
        DispatchGlyphSpriteFromTable(
            kPhoneGlyphSlot, nCharCode, &position, nAlpha, bDimmed, 0.0f, flScaleX, flScaleY);
    };

    // The backdrop and the outer frame furniture.
    {
        const S_VECTOR2 backdrop = PositionAt(kPhonePosBackdrop);
        DispatchGlyphSpriteFromTable(kPhoneBackdropSlot,
                                     kPhoneGlyphBackdrop,
                                     &backdrop,
                                     nPanelAlpha,
                                     false,
                                     0.0f,
                                     1.0f,
                                     1.0f);
    }
    EmitGlyph(
        kPhoneGlyphFrameEdgeA, PositionAt(kPhonePosFrameEdgeA), nPanelAlpha, false, 1.0f, 1.0f);
    EmitGlyph(
        kPhoneGlyphFrameEdgeB, PositionAt(kPhonePosFrameEdgeB), nPanelAlpha, false, 1.0f, 1.0f);
    EmitGlyph(
        kPhoneGlyphFrameEdgeC, PositionAt(kPhonePosFrameEdgeC), nPanelAlpha, false, 1.0f, 1.0f);
    EmitGlyph(kPhoneGlyphFrameEdgeB,
              PositionAt(kPhonePosFrameEdgeBMirror),
              nPanelAlpha,
              false,
              -1.0f,
              1.0f);
    EmitGlyph(kPhoneGlyphFrameEdgeA,
              PositionAt(kPhonePosFrameEdgeAMirror),
              nPanelAlpha,
              false,
              1.0f,
              1.0f);
    EmitGlyph(kPhoneGlyphFrameCornerTop,
              PositionAt(kPhonePosFrameCornerTop),
              nPanelAlpha,
              false,
              1.0f,
              1.0f);

    // The rail across the panel: a cap and joint at each end, and a span stretched to the viewport.
    {
        const S_VECTOR2 railCap = PositionAt(kPhonePosRailCap);
        const S_VECTOR2 railJoint = PositionAt(kPhonePosRailJoint);
        const float flCapWidth = railJoint.x - railCap.x;
        const float flSpanStart = railJoint.x + kFrameRailInset;
        const float flViewportWidth = pViewportSystem->GetViewportWidth();
        EmitGlyph(kPhoneGlyphRailCap, railCap, nPanelAlpha, false, flCapWidth, 1.0f);
        EmitGlyph(kPhoneGlyphRailJoint, railJoint, nPanelAlpha, false, 1.0f, 1.0f);
        const S_VECTOR2 spanPos{flSpanStart, railJoint.y};
        EmitGlyph(kPhoneGlyphRailSpan,
                  spanPos,
                  nPanelAlpha,
                  false,
                  flViewportWidth + flSpanStart * -2.0f,
                  1.0f);
        const S_VECTOR2 mirrorPos{flViewportWidth - railJoint.x, railJoint.y};
        EmitGlyph(kPhoneGlyphRailJoint, mirrorPos, nPanelAlpha, false, -1.0f, 1.0f);
        EmitGlyph(kPhoneGlyphRailCap, mirrorPos, nPanelAlpha, false, flCapWidth, 1.0f);
    }

    // The header bar, dimmed while the confirm region is held.
    {
        const bool bConfirmDown = m_aGestureRegions[0].bDown;
        const S_VECTOR2 headerCap = PositionAt(kPhonePosHeaderCap);
        const float flBarStart = headerCap.x + kHeaderBarInset;
        const float flViewportWidth = pViewportSystem->GetViewportWidth();
        EmitGlyph(kPhoneGlyphHeaderCap, headerCap, nPanelAlpha, bConfirmDown, 1.0f, 1.0f);
        const S_VECTOR2 barPos{flBarStart, headerCap.y};
        EmitGlyph(kPhoneGlyphHeaderSpan,
                  barPos,
                  nPanelAlpha,
                  bConfirmDown,
                  flViewportWidth - (flBarStart + flBarStart),
                  1.0f);
        const S_VECTOR2 capMirror{flViewportWidth - headerCap.x, headerCap.y};
        EmitGlyph(kPhoneGlyphHeaderCap, capMirror, nPanelAlpha, bConfirmDown, -1.0f, 1.0f);
        EmitGlyph(kPhoneGlyphHeaderBadge,
                  PositionAt(kPhonePosHeaderBadge),
                  nPanelAlpha,
                  bConfirmDown,
                  1.0f,
                  1.0f);
    }
    if (m_bTwitterAvailable) {
        EmitGlyph(kPhoneGlyphShareButton,
                  PositionAt(kPhonePosShareButton),
                  nPanelAlpha,
                  m_aGestureRegions[3].bDown,
                  1.0f,
                  1.0f);
    }

    // A nine-slice box spanning two corner positions: four corners drawn by mirroring one glyph,
    // two stretched horizontal edges, two stretched vertical edges, and a stretched centre.
    const auto RenderNineSlice = [&](unsigned int nBaseCharCode,
                                     const S_VECTOR2 &cornerA,
                                     const S_VECTOR2 &cornerB,
                                     unsigned int nAlpha) {
        const unsigned int nCorner = nBaseCharCode;
        const unsigned int nEdgeH = nBaseCharCode + 1;
        const unsigned int nEdgeV = nBaseCharCode + 2;
        const unsigned int nCentre = nBaseCharCode + 3;

        EmitGlyph(nCorner, cornerA, nAlpha, false, 1.0f, 1.0f);
        const S_VECTOR2 topRight{cornerB.x, cornerA.y};
        EmitGlyph(nCorner, topRight, nAlpha, false, -1.0f, 1.0f);
        const S_VECTOR2 bottomLeft{cornerA.x, cornerB.y};
        EmitGlyph(nCorner, bottomLeft, nAlpha, false, 1.0f, -1.0f);
        EmitGlyph(nCorner, cornerB, nAlpha, false, -1.0f, -1.0f);

        const float flSpanX = (cornerB.x - cornerA.x) - kNineSliceEdgeTrim;
        const float flSpanY = (cornerB.y - cornerA.y) - kNineSliceEdgeTrim;
        const float flInsetX = cornerA.x + kNineSliceCornerInset;
        const S_VECTOR2 edgeTop{flInsetX, cornerA.y};
        EmitGlyph(nEdgeH, edgeTop, nAlpha, false, flSpanX, 1.0f);
        const S_VECTOR2 edgeBottom{flInsetX, cornerB.y};
        EmitGlyph(nEdgeH, edgeBottom, nAlpha, false, flSpanX, -1.0f);
        const float flInsetY = cornerA.y + kNineSliceCornerInset;
        const S_VECTOR2 edgeLeft{cornerA.x, flInsetY};
        EmitGlyph(nEdgeV, edgeLeft, nAlpha, false, 1.0f, flSpanY);
        const S_VECTOR2 edgeRight{cornerB.x, flInsetY};
        EmitGlyph(nEdgeV, edgeRight, nAlpha, false, -1.0f, flSpanY);
        const S_VECTOR2 centre{flInsetX, flInsetY};
        EmitGlyph(nCentre, centre, nAlpha, false, flSpanX, flSpanY);
    };

    RenderNineSlice(kNineSliceOuterBase,
                    PositionAt(kOuterBoxPositionA),
                    PositionAt(kOuterBoxPositionB),
                    nPanelAlpha);
    RenderNineSlice(kNineSliceInnerBase,
                    PositionAt(kInnerBoxPositionA),
                    PositionAt(kInnerBoxPositionB),
                    nBodyAlpha);

    for (const PhoneSeparator &separator : kPanelSeparators) {
        const S_VECTOR2 noOffset{};
        RenderGlyphAtSeparator(
            kPhoneGlyphSlot, separator.nIndex, separator.nCharCode, noOffset, nBodyAlpha);
    }

    // The music jacket and the two banner slots; the landscape orientation draws the banners
    // centred at full intensity instead of scaled.
    {
        const S_VECTOR2 jacketPos = PositionAt(kPhonePosJacket);
        const S_VECTOR2 jacketSize{kPhoneJacketSize, kPhoneJacketSize};
        BlitInstancerTextureSlot(kPhoneJacketSlot, jacketPos, jacketSize, nBodyAlpha);

        S_VECTOR2 bannerPos = PositionAt(kPhonePosBannerA);
        if (!m_bPortrait) {
            RenderSpriteInstancerSlotScaled(kPhoneBannerSlotA, bannerPos, nBodyAlpha);
            bannerPos = PositionAt(kPhonePosBannerB);
            RenderSpriteInstancerSlotScaled(kPhoneBannerSlotB, bannerPos, nBodyAlpha);
        } else {
            RenderSpriteInstancerSlotHalfScale(
                kPhoneBannerSlotA, bannerPos, nBodyAlpha, kBannerFullIntensity);
            bannerPos = PositionAt(kPhonePosBannerB);
            RenderSpriteInstancerSlotHalfScale(
                kPhoneBannerSlotB, bannerPos, nBodyAlpha, kBannerFullIntensity);
        }
    }

    // The music heading, difficulty badge, and the target/score comparison.
    EmitGlyph(
        kPhoneGlyphMusicTitle, PositionAt(kPhonePosMusicTitle), nBodyAlpha, false, 1.0f, 1.0f);
    EmitGlyph(
        kPhoneGlyphScoreLabel, PositionAt(kPhonePosScoreLabel), nBodyAlpha, false, 1.0f, 1.0f);
    EmitGlyph(kPhoneGlyphDifficultyBase + static_cast<unsigned int>(pGameSystem->GetDifficulty()),
              PositionAt(kPhonePosDifficulty),
              nBodyAlpha,
              false,
              1.0f,
              1.0f);

    const int nSideOneScore = pTracker->GetPlayRecordCell(1, 0);
    EmitGlyph(
        kPhoneGlyphTargetLabel, PositionAt(kPhonePosTargetLabel), nBodyAlpha, false, 1.0f, 1.0f);
    int nTargetScore = pGameSystem->GetTargetScore();
    if (nTargetScore < 0) {
        nTargetScore = 0;
    }
    {
        const S_VECTOR2 targetPos = PositionAt(kPhonePosTargetDigits);
        const S_VECTOR2 noOffset{};
        RenderNumberFieldWithPad(nTargetScore,
                                 kPhoneScoreDigitCount,
                                 targetPos,
                                 noOffset,
                                 kPhoneGlyphBankTarget,
                                 false,
                                 true,
                                 nBodyAlpha,
                                 1.0f);
    }
    EmitGlyph(kPhoneGlyphScoreSeparator,
              PositionAt(kPhonePosScoreSeparator),
              nBodyAlpha,
              false,
              1.0f,
              1.0f);

    int nScoreDelta = nSideOneScore - nTargetScore;
    {
        const S_VECTOR2 glyphPos = PositionAt(kPhonePosDeltaGlyph);
        EmitGlyph(nScoreDelta < 0 ? kPhoneGlyphDeltaDown : kPhoneGlyphDeltaUp,
                  glyphPos,
                  nBodyAlpha,
                  false,
                  1.0f,
                  1.0f);
        const S_VECTOR2 deltaPos = PositionAt(kPhonePosDeltaDigits);
        if (nScoreDelta < 0) {
            nScoreDelta = -nScoreDelta;
        }
        const S_VECTOR2 noOffset{};
        RenderNumberFieldWithPad(nScoreDelta,
                                 kPhoneScoreDigitCount,
                                 deltaPos,
                                 noOffset,
                                 kPhoneGlyphBankTarget,
                                 false,
                                 true,
                                 nBodyAlpha,
                                 1.0f);
    }
    EmitGlyph(kPhoneGlyphScoreSeparator,
              PositionAt(kPhonePosScoreSeparatorMirror),
              nBodyAlpha,
              false,
              -1.0f,
              1.0f);
    {
        const S_VECTOR2 scorePos = PositionAt(kPhonePosScoreDigits);
        const S_VECTOR2 noOffset{};
        RenderNumberFieldWithPad(nSideOneScore,
                                 kPhoneScoreDigitCount,
                                 scorePos,
                                 noOffset,
                                 kPhoneGlyphBankScore,
                                 false,
                                 true,
                                 nBodyAlpha,
                                 1.0f);
    }
    if (!m_bPortrait) {
        EmitGlyph(kPhoneGlyphJacketBadge,
                  PositionAt(kPhonePosJacketBadge),
                  nBodyAlpha,
                  false,
                  1.0f,
                  1.0f);
    }

    const unsigned int nShareAlpha = static_cast<unsigned int>(flShareScale * flPanelAlpha);

    // The clear-rank badge, the full-combo badge, and the match outcome.
    EmitGlyph(kPhoneGlyphRankBase + static_cast<unsigned int>(pTracker->GetPlayRecordRank(1)),
              PositionAt(kPhonePosRankBadge),
              nBodyAlpha,
              false,
              1.0f,
              1.0f);
    if (pTracker->GetTotalNotes() == pTracker->GetPlayRecordCell(1, 2)) {
        EmitGlyph(
            kPhoneGlyphFullCombo, PositionAt(kPhonePosFullCombo), nBodyAlpha, false, 1.0f, 1.0f);
    }
    EmitGlyph(kPhoneGlyphRankLabel, PositionAt(kPhonePosRankLabel), nBodyAlpha, false, 1.0f, 1.0f);
    EmitGlyph(kPhoneGlyphMatchOutcomeBase +
                  static_cast<unsigned int>(pTracker->GetPlayRecordField10(1)),
              PositionAt(kPhonePosMatchOutcome),
              nBodyAlpha,
              false,
              1.0f,
              1.0f);

    // The stats box: a nine-slice whose top edge is notched to make room for the page tabs, so its
    // top rail is drawn as two spans either side of the notch, with a capped bar bridging them.
    {
        const S_VECTOR2 cornerA = PositionAt(kStatsBoxCornerA);
        const S_VECTOR2 cornerB = PositionAt(kStatsBoxCornerB);
        const S_VECTOR2 notchStart = PositionAt(kStatsBoxNotchStart);
        const S_VECTOR2 notchEnd = PositionAt(kStatsBoxNotchEnd);

        const unsigned int nCorner = kNineSliceInnerBase;
        const unsigned int nEdgeH = kNineSliceInnerBase + 1;
        const unsigned int nEdgeV = kNineSliceInnerBase + 2;
        const unsigned int nCentre = kNineSliceInnerBase + 3;
        const float flInsetX = cornerA.x + kNineSliceCornerInset;

        const S_VECTOR2 topLeftSpan{flInsetX, cornerA.y};
        EmitGlyph(nEdgeH, topLeftSpan, nBodyAlpha, false, notchStart.x - flInsetX, 1.0f);
        const S_VECTOR2 topRightSpan{notchEnd.x, cornerA.y};
        EmitGlyph(nEdgeH,
                  topRightSpan,
                  nBodyAlpha,
                  false,
                  (cornerB.x - notchEnd.x) - kNineSliceCornerInset,
                  1.0f);

        EmitGlyph(nCorner, cornerA, nBodyAlpha, false, 1.0f, 1.0f);
        const S_VECTOR2 topRight{cornerB.x, cornerA.y};
        EmitGlyph(nCorner, topRight, nBodyAlpha, false, -1.0f, 1.0f);
        const S_VECTOR2 bottomLeft{cornerA.x, cornerB.y};
        EmitGlyph(nCorner, bottomLeft, nBodyAlpha, false, 1.0f, -1.0f);
        EmitGlyph(nCorner, cornerB, nBodyAlpha, false, -1.0f, -1.0f);

        const float flSpanX = (cornerB.x - cornerA.x) - kNineSliceEdgeTrim;
        const float flSpanY = (cornerB.y - cornerA.y) - kNineSliceEdgeTrim;
        const S_VECTOR2 edgeBottom{flInsetX, cornerB.y};
        EmitGlyph(nEdgeH, edgeBottom, nBodyAlpha, false, flSpanX, -1.0f);
        const float flInsetY = cornerA.y + kNineSliceCornerInset;
        const S_VECTOR2 edgeLeft{cornerA.x, flInsetY};
        EmitGlyph(nEdgeV, edgeLeft, nBodyAlpha, false, 1.0f, flSpanY);
        const S_VECTOR2 edgeRight{cornerB.x, flInsetY};
        EmitGlyph(nEdgeV, edgeRight, nBodyAlpha, false, -1.0f, flSpanY);
        const S_VECTOR2 centre{flInsetX, flInsetY};
        EmitGlyph(nCentre, centre, nBodyAlpha, false, flSpanX, flSpanY);

        // The bar bridging the notch, capped at each end.
        EmitGlyph(kNotchCapGlyph, notchStart, nBodyAlpha, false, 1.0f, 1.0f);
        const S_VECTOR2 notchSpan{notchStart.x + kNotchCapInset, notchStart.y};
        EmitGlyph(kNotchSpanGlyph,
                  notchSpan,
                  nBodyAlpha,
                  false,
                  (notchEnd.x - notchStart.x) - kNotchCapTrim,
                  1.0f);
        EmitGlyph(kNotchCapGlyph, notchEnd, nBodyAlpha, false, -1.0f, 1.0f);
    }

    // The stats and experience pages cross-fade as the signed slide timer runs, sliding
    // horizontally in opposite directions. A networked play leads with the opposite page, so the
    // assignments are mirrored. Each page also drives its own tab glyph, whose alpha comes from the
    // fifth channel rather than the body channel.
    const float flSlide = m_flSlideTimer;
    const float flSlideMagnitude = std::fabs(flSlide);
    const float flRemaining = 1.0f - flSlideMagnitude;
    const float flTabAlphaBase = flPanelAlpha * flTabScale;
    const float flSlideEdge = (flSlide <= 0.0f) ? -kPageSlideTravel : kPageSlideTravel;

    float flStatsAlpha = 0.0f;
    float flExpAlpha = 0.0f;
    float flStatsTabAlpha = 0.0f;
    float flExpTabAlpha = 0.0f;
    float flStatsSlideX = 0.0f;
    float flExpSlideX = 0.0f;
    if (m_nNetworkPlay == 1) {
        flStatsAlpha = static_cast<float>(nShareAlpha) * flRemaining;
        flExpAlpha = static_cast<float>(nShareAlpha) * flSlideMagnitude;
        flStatsTabAlpha = flTabAlphaBase * flRemaining;
        flExpTabAlpha = flTabAlphaBase * flSlideMagnitude;
        flStatsSlideX = flSlide * -kPageSlideTravel;
        flExpSlideX = flRemaining * flSlideEdge;
    } else {
        flStatsAlpha = static_cast<float>(nShareAlpha) * flSlideMagnitude;
        flExpAlpha = static_cast<float>(nShareAlpha) * flRemaining;
        flStatsTabAlpha = flTabAlphaBase * flSlideMagnitude;
        flExpTabAlpha = flTabAlphaBase * flRemaining;
        flStatsSlideX = flRemaining * flSlideEdge;
        flExpSlideX = flSlide * -kPageSlideTravel;
    }
    const S_VECTOR2 statsOffset{flStatsSlideX, 0.0f};
    const S_VECTOR2 expOffset{flExpSlideX, 0.0f};
    const unsigned int nStatsAlpha = static_cast<unsigned int>(flStatsAlpha);
    const unsigned int nExpAlpha = static_cast<unsigned int>(flExpAlpha);

    EmitGlyph(kPhoneGlyphStatsTab,
              PositionAt(kPhonePosPageTabs),
              static_cast<unsigned int>(static_cast<int>(flStatsTabAlpha)),
              false,
              1.0f,
              1.0f);

    for (int nSeparator = kStatsSeparatorFirst; nSeparator <= kStatsSeparatorLast; ++nSeparator) {
        RenderGlyphAtSeparator(
            kPhoneGlyphSlot, nSeparator, kSeparatorRuleThin, statsOffset, nStatsAlpha);
    }

    for (const PhoneDecoration &decoration : kPhoneDecorations) {
        const unsigned int nCharCode =
            decoration.bAnimated ?
                (decoration.nCharCode + static_cast<unsigned int>(m_nRotationFrame)) :
                decoration.nCharCode;
        const S_VECTOR2 position = PositionAt(decoration.nPositionIndex);
        RenderTableSpriteAtIndex(kPhoneGlyphSlot,
                                 nCharCode,
                                 position,
                                 statsOffset,
                                 nStatsAlpha,
                                 false,
                                 0.0f,
                                 1.0f,
                                 1.0f);
    }

    // One stat row per side: a rotated header glyph, then the judgement counts, the two ratios, the
    // score, and the achievement rate.
    const unsigned int nSide1HeaderGlyph = (nPlayColor != 0) ? 0x36 : 0x35;
    const unsigned int nSide0HeaderGlyph = (nPlayColor == 0) ? 0x38 : 0x37;
    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        const unsigned int uSide = static_cast<unsigned int>(nSide);
        const int nJust = pTracker->GetPlayRecordCell(uSide, 3);
        const int nGreat = pTracker->GetPlayRecordCell(uSide, 4);
        const int nGood = pTracker->GetPlayRecordCell(uSide, 5);
        const int nMiss = pTracker->GetPlayRecordCell(uSide, 6);
        const int nJustReflec = pTracker->GetPlayRecordCell(uSide, 7);
        const int nMaxCombo = pTracker->GetPlayRecordCell(uSide, 2);
        const int nScore = pTracker->GetPlayRecordCell(uSide, 0);
        const int nRowTotalNotes = pTracker->GetTotalNotes();
        const float flRate = pTracker->GetPlayRecordRate(uSide);

        const int nScoreSlot =
            (nSide == 0) ? static_cast<int>(nPlayColor) : ((nPlayColor == 0) ? 1 : 0);
        const int nSideResultScore = m_aResultScores[nScoreSlot];

        // The header sits upright in portrait and turns a quarter turn in landscape.
        const float flHeaderRotation =
            m_bPortrait ? 0.0f :
                          ((nSide == 1) ? kSideHeaderRotationSide1 : kSideHeaderRotationSide0);
        RenderTableSpriteWithOffset(kPhoneGlyphSlot,
                                    (nSide == 1) ? nSide1HeaderGlyph : nSide0HeaderGlyph,
                                    kStatRowHeaderPosition[nSide],
                                    statsOffset,
                                    nStatsAlpha,
                                    false,
                                    flHeaderRotation,
                                    1.0f,
                                    1.0f);

        const int nRowBase = kStatRowBase[nSide];
        // Each field's position is resolved from its record, then shifted by the page's slide.
        const auto RowPosition = [&](int nSlot) {
            S_VECTOR2 position = PositionAt(nRowBase + nSlot);
            S_VECTOR2 offset = statsOffset;
            AddVector2(&position, &offset);
            return position;
        };

        S_VECTOR2 position = RowPosition(kPhoneRowJust);
        RenderDigitRowSpacedByWidth(nJust, &position, nStatsAlpha);
        position = RowPosition(kPhoneRowGreat);
        RenderDigitRowSpacedByWidth(nGreat, &position, nStatsAlpha);
        position = RowPosition(kPhoneRowGood);
        RenderDigitRowSpacedByWidth(nGood, &position, nStatsAlpha);
        position = RowPosition(kPhoneRowMiss);
        RenderDigitRowSpacedByWidth(nMiss, &position, nStatsAlpha);
        position = RowPosition(kPhoneRowJustReflec);
        RenderRatioDigits(nJustReflec, nSideResultScore, &position, nStatsAlpha);
        position = RowPosition(kPhoneRowMaxCombo);
        RenderRatioDigits(nMaxCombo, nRowTotalNotes, &position, nStatsAlpha);
        position = RowPosition(kPhoneRowScore);
        RenderDigitRowSpacedByWidth(nScore, &position, nStatsAlpha);
        position = RowPosition(kPhoneRowRate);
        RenderDecimalWithDotGlyph(
            static_cast<int>(flRate * kAchievementRateScale), &position, nStatsAlpha);
    }

    EmitGlyph(kPhoneGlyphExpTab,
              PositionAt(kPhonePosPageTabs),
              static_cast<unsigned int>(static_cast<int>(flExpTabAlpha)),
              false,
              1.0f,
              1.0f);

    for (int nSeparator = kExpSeparatorFirst; nSeparator <= kExpSeparatorLast; ++nSeparator) {
        RenderGlyphAtSeparator(
            kPhoneGlyphSlot, nSeparator, kSeparatorRuleThin, expOffset, nExpAlpha);
    }
    for (const PhoneExpPart &part : kPhoneExpParts) {
        const S_VECTOR2 position = PositionAt(part.nPositionIndex);
        RenderTableSpriteAtIndex(kPhoneGlyphSlot,
                                 part.nCharCode,
                                 position,
                                 expOffset,
                                 nExpAlpha,
                                 false,
                                 0.0f,
                                 1.0f,
                                 1.0f);
    }

    m_flResultElapsed += flDeltaTime;

    // The gained-experience digits round-trip the field through a float, as the binary does.
    {
        const S_VECTOR2 gainedPos = PositionAt(kPhonePosExpGained);
        RenderNumberFieldWithPad(static_cast<int>(static_cast<float>(m_nGainedExp)),
                                 kPhoneExpGainedDigitCount,
                                 gainedPos,
                                 expOffset,
                                 kPhoneGlyphBankExpGained,
                                 false,
                                 true,
                                 nExpAlpha,
                                 1.0f);
    }

    const int nDeltaFrames = static_cast<int>(flDeltaTime);
    const float flExpProgress = AdvanceCustomizeOverlayProgress(nDeltaFrames);
    int nExpThreshold = m_nExpThreshold;
    if (nExpThreshold < 0) {
        nExpThreshold = 0;
    }
    {
        const S_VECTOR2 thresholdPos = PositionAt(kPhonePosExpThreshold);
        RenderNumberFieldWithPad(nExpThreshold,
                                 kPhoneExpThresholdDigitCount,
                                 thresholdPos,
                                 expOffset,
                                 kPhoneGlyphBankExpThreshold,
                                 false,
                                 true,
                                 nExpAlpha,
                                 0.0f);
        const S_VECTOR2 progressPos = PositionAt(kPhonePosExpProgress);
        RenderNumberFieldWithPad(
            static_cast<int>(flExpProgress * static_cast<float>(nExpThreshold)),
            kPhoneExpThresholdDigitCount,
            progressPos,
            expOffset,
            kPhoneGlyphBankExpGained,
            false,
            true,
            nExpAlpha,
            1.0f);
        const S_VECTOR2 barPos = PositionAt(kPhonePosExpBar);
        RenderTableSpriteAtIndex(kPhoneGlyphSlot,
                                 kPhoneGlyphExpBar,
                                 barPos,
                                 expOffset,
                                 nExpAlpha,
                                 false,
                                 0.0f,
                                 flExpProgress * kPhoneExperienceBarWidth,
                                 1.0f);
    }

    // A single sparkle chases along the experience bar while the main customize asset is shown.
    if (m_bMainAssetActive) {
        const float flPhase = static_cast<float>(m_nRotationCounterA) / kSparkleCounterPeriod;
        const S_VECTOR2 sparkleOffset{expOffset.x + flPhase * kSparkleTravelX, expOffset.y};
        const S_VECTOR2 sparklePos = PositionAt(kPhonePosExpSparkle);
        RenderTableSpriteAtIndex(
            kPhoneGlyphSlot,
            kPhoneGlyphExpSparkle,
            sparklePos,
            sparkleOffset,
            static_cast<unsigned int>(static_cast<int>(flExpAlpha * (1.0f - flPhase))),
            false,
            0.0f,
            1.0f,
            1.0f);
    }

    RenderCustomizePhoneOverlay(nDeltaFrames, &expOffset, flExpAlpha);
    RenderCustomizeNameplateOverlay(nDeltaFrames, &expOffset, flExpAlpha);

    // A single-player game draws the two lane markers twice: a half-intensity shadow pass at the
    // share alpha, then the main pass, whose two markers take the exp and stats page alphas.
    if ((pGameSystem->GetGameType() | 2) == 2) {
        EmitGlyph(
            kPhoneGlyphLaneMarker, PositionAt(kPhonePosLaneMarkerA), nShareAlpha, true, 1.0f, 1.0f);
        EmitGlyph(
            kPhoneGlyphLaneMarker, PositionAt(kPhonePosLaneMarkerB), nShareAlpha, true, 1.0f, 1.0f);
        EmitGlyph(
            kPhoneGlyphLaneMarker, PositionAt(kPhonePosLaneMarkerA), nExpAlpha, false, 1.0f, 1.0f);
        EmitGlyph(kPhoneGlyphLaneMarker,
                  PositionAt(kPhonePosLaneMarkerB),
                  nStatsAlpha,
                  false,
                  1.0f,
                  1.0f);
    }
}

// Seeds every Classic result-screen layout table at load time. Nothing calls this by name: its
// address sits in the binary's __mod_init_func list (0x358ca8), so dyld runs it when the image
// loads. The binary wraps the whole fill in an autorelease pool, then writes every field inline.
// Only the play-field height below is not a constant.
/** @ghidraAddress 0x11c9b8 */
__attribute__((constructor)) void InitializeResultLayoutTable() {
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
        g_aClassicTrailVertices[0].x = 179.0f;
        g_aClassicTrailVertices[0].y = 117.0f;
        g_aClassicTrailVertices[2].x = 123.0f;
        g_aClassicTrailVertices[2].y = 117.0f;
        g_aClassicTrailVertices[4].x = 121.0f;
        g_aClassicTrailVertices[4].y = 118.0f;
        g_aClassicTrailVertices[6].x = 119.0f;
        g_aClassicTrailVertices[6].y = 1.2e+02f;
        g_aClassicTrailVertices[8].x = 118.0f;
        g_aClassicTrailVertices[8].y = 122.0f;
        g_aClassicTrailVertices[10].x = 117.0f;
        g_aClassicTrailVertices[10].y = 347.0f;
        g_aClassicTrailVertices[12].x = 118.0f;
        g_aClassicTrailVertices[12].y = 349.0f;
        g_aClassicTrailVertices[14].x = 1.2e+02f;
        g_aClassicTrailVertices[14].y = 351.0f;
        g_aClassicTrailVertices[16].x = 122.0f;
        g_aClassicTrailVertices[16].y = 352.0f;
        g_aClassicTrailVertices[18].x = 384.0f;
        g_aClassicTrailVertices[18].y = 353.0f;
        g_aClassicTrailVertices[20].x = 589.0f;
        g_aClassicTrailVertices[20].y = 117.0f;
        g_aClassicTrailVertices[22].x = 646.0f;
        g_aClassicTrailVertices[22].y = 117.0f;
        g_aClassicTrailVertices[24].x = 648.0f;
        g_aClassicTrailVertices[24].y = 118.0f;
        g_aClassicTrailVertices[26].x = 6.5e+02f;
        g_aClassicTrailVertices[26].y = 1.2e+02f;
        g_aClassicTrailVertices[28].x = 651.0f;
        g_aClassicTrailVertices[28].y = 122.0f;
        g_aClassicTrailVertices[30].x = 652.0f;
        g_aClassicTrailVertices[30].y = 347.0f;
        g_aClassicTrailVertices[32].x = 651.0f;
        g_aClassicTrailVertices[32].y = 349.0f;
        g_aClassicTrailVertices[34].x = 649.0f;
        g_aClassicTrailVertices[34].y = 351.0f;
        g_aClassicTrailVertices[36].x = 647.0f;
        g_aClassicTrailVertices[36].y = 352.0f;
        g_aClassicTrailVertices[38].x = 384.0f;
        g_aClassicTrailVertices[38].y = 353.0f;
        g_aClassicTrailVertices[40].x = 179.0f;
        g_aClassicTrailVertices[40].y = 409.0f;
        g_aClassicTrailVertices[42].x = 123.0f;
        g_aClassicTrailVertices[42].y = 409.0f;
        g_aClassicTrailVertices[44].x = 121.0f;
        g_aClassicTrailVertices[44].y = 4.1e+02f;
        g_aClassicTrailVertices[46].x = 119.0f;
        g_aClassicTrailVertices[46].y = 412.0f;
        g_aClassicTrailVertices[48].x = 118.0f;
        g_aClassicTrailVertices[48].y = 414.0f;
        g_aClassicTrailVertices[50].x = 117.0f;
        g_aClassicTrailVertices[50].y = 904.0f;
        g_aClassicTrailVertices[52].x = 118.0f;
        g_aClassicTrailVertices[52].y = 906.0f;
        g_aClassicTrailVertices[54].x = 1.2e+02f;
        g_aClassicTrailVertices[54].y = 908.0f;
        g_aClassicTrailVertices[56].x = 122.0f;
        g_aClassicTrailVertices[56].y = 909.0f;
        g_aClassicTrailVertices[58].x = 384.0f;
        g_aClassicTrailVertices[58].y = 9.1e+02f;
        g_aClassicTrailVertices[78].x = 384.0f;
        g_aClassicTrailVertices[78].y = 9.1e+02f;
        g_aClassicTrailVertices[60].x = 589.0f;
        g_aClassicTrailVertices[60].y = 409.0f;
        g_aClassicTrailVertices[62].x = 646.0f;
        g_aClassicTrailVertices[62].y = 409.0f;
        g_aClassicTrailVertices[64].x = 648.0f;
        g_aClassicTrailVertices[64].y = 4.1e+02f;
        g_aClassicTrailVertices[66].x = 6.5e+02f;
        g_aClassicTrailVertices[66].y = 412.0f;
        g_aClassicTrailVertices[68].x = 651.0f;
        g_aClassicTrailVertices[68].y = 414.0f;
        g_aClassicTrailVertices[70].x = 652.0f;
        g_aClassicTrailVertices[70].y = 904.0f;
        g_aClassicTrailVertices[72].x = 651.0f;
        g_aClassicTrailVertices[72].y = 906.0f;
        g_aClassicTrailVertices[74].x = 649.0f;
        g_aClassicTrailVertices[74].y = 908.0f;
        g_aClassicTrailVertices[76].x = 647.0f;
        g_aClassicTrailVertices[76].y = 909.0f;
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
