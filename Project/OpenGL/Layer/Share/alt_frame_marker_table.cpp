#include "alt_frame_marker_table.h"

#include <cmath>

#include "engineglobals.h"

// The alt-frame marker layout tables, seeded once at load by SeedAltFrameLayoutTable. They are
// mutable globals (zero-initialised here) rather than constants because their base Y values are
// derived from the play-field layout centre split at seed time.
AltFrameMarkerLayout g_aAltFrameMarker4[kAltFrameMarkerCount4] = {}; // @ghidraAddress 0x3dbec8
AltFrameMarkerLayout g_aAltFrameMarker6[kAltFrameMarkerCount6] = {}; // @ghidraAddress 0x3dbfb8
AltFrameMarkerLayout g_aAltFrameMarker9[kAltFrameMarkerCount9] = {}; // @ghidraAddress 0x3dc108

// The static sprite-descriptor tables (read-only ROM data), one per difficulty tier.
const AltFrameSpriteDescriptor g_aAltFrameDescriptor4[kAltFrameDescriptorCount4] = {
    {0, 0.0f, 0.0f, 73.0f, 511.0f, 0},
    {0, 0.0f, 0.0f, 73.0f, 511.0f, 1},
    {0, 0.0f, 0.0f, 622.0f, 22.0f, 4},
    {2, 128.0f, 16.0f, 256.0f, 32.0f, 0x67},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xf8},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xf9},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xfa},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xfb},
    {0, 0.0f, 0.0f, 11.0f, 240.0f, 2},
    {0, 0.0f, 0.0f, 10.0f, 100.0f, 3},
}; // @ghidraAddress 0x30ca98

const AltFrameSpriteDescriptor g_aAltFrameDescriptor6[kAltFrameDescriptorCount6] = {
    {0, 0.0f, 0.0f, 73.0f, 511.0f, 0},
    {0, 0.0f, 0.0f, 73.0f, 511.0f, 1},
    {0, 0.0f, 0.0f, 56.0f, 22.0f, 4},
    {0, 0.0f, 0.0f, 74.0f, 22.0f, 5},
    {0, 0.0f, 0.0f, 492.0f, 22.0f, 6},
    {2, 128.0f, 16.0f, 256.0f, 32.0f, 0x67},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xf8},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xf9},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xfa},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xfb},
    {0, 0.0f, 0.0f, 11.0f, 240.0f, 2},
    {0, 0.0f, 0.0f, 10.0f, 100.0f, 3},
}; // @ghidraAddress 0x30cb88

const AltFrameSpriteDescriptor g_aAltFrameDescriptor9[kAltFrameDescriptorCount9] = {
    {0, 0.0f, 0.0f, 73.0f, 511.0f, 0},
    {0, 0.0f, 0.0f, 73.0f, 511.0f, 1},
    {0, 0.0f, 0.0f, 73.0f, 511.0f, 2},
    {0, 0.0f, 0.0f, 73.0f, 511.0f, 3},
    {0, 0.0f, 0.0f, 22.0f, 311.0f, 6},
    {0, 0.0f, 0.0f, 22.0f, 311.0f, 7},
    {0, 0.0f, 0.0f, 22.0f, 311.0f, 8},
    {0, 0.0f, 0.0f, 22.0f, 311.0f, 9},
    {2, 128.0f, 16.0f, 256.0f, 32.0f, 0x67},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xf8},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xf9},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xfa},
    {1, 9.0f, 46.0f, 18.0f, 92.0f, 0xfb},
    {0, 0.0f, 0.0f, 11.0f, 240.0f, 4},
    {0, 0.0f, 0.0f, 14.0f, 100.0f, 5},
}; // @ghidraAddress 0x30cca8

// The alt-frame mesh (batch-0) UV atlases, one per lane-count tier. The first record is the empty
// zero rectangle (an unused frame). Read-only ROM data.
const SpriteUvEntry g_aAltFrameMeshUvMid[kAltFrameMeshUvCountMid] = {
    {0.0f, 0.0f, 0.28515625f, 0.9980469f},
    {0.30078125f, 0.0f, 0.28515625f, 0.9980469f},
    {0.82421875f, 0.0f, 0.04296875f, 0.46875f},
    {0.875f, 0.0f, 0.0390625f, 0.1953125f},
    {0.59765625f, 0.95703125f, 0.00390625f, 0.04296875f},
    {0.59765625f, 0.91015625f, 0.2890625f, 0.04296875f},
    {0.59765625f, 0.86328125f, 0.28125f, 0.04296875f},
}; // @ghidraAddress 0x2f19d8

const SpriteUvEntry g_aAltFrameMeshUvHigh[kAltFrameMeshUvCountHigh] = {
    {0.0f, 0.0f, 0.14257812f, 0.9980469f},
    {0.70703125f, 0.001953125f, 0.14257812f, 0.9980469f},
    {0.15039062f, 0.0f, 0.14257812f, 0.9980469f},
    {0.8574219f, 0.001953125f, 0.14257812f, 0.9980469f},
    {0.41210938f, 0.0f, 0.021484375f, 0.46875f},
    {0.4375f, 0.0f, 0.02734375f, 0.1953125f},
    {0.51953125f, 0.001953125f, 0.04296875f, 0.6074219f},
    {0.56640625f, 0.001953125f, 0.04296875f, 0.6074219f},
    {0.61328125f, 0.001953125f, 0.04296875f, 0.6074219f},
    {0.66015625f, 0.001953125f, 0.04296875f, 0.6074219f},
}; // @ghidraAddress 0x2f1a48

namespace {

// The marker X columns and the rotation of a sideways marker (@ghidraAddress 0x3fc90fdb = PI/2).
constexpr float kColLeftEdge = -384.0f;
constexpr float kColRightEdge = 364.0f;
constexpr float kColLeftInner = -311.0f;
constexpr float kColRightInner = 311.0f;
constexpr float kColLeftMid = -346.0f;
constexpr float kColRightMid = 346.0f;
constexpr float kColLeftClose = -375.0f;
constexpr float kColNarrowInner = 181.0f;
constexpr float kColNarrowOuter = 237.0f;
constexpr float kColCentre = 0.0f;
const float kRotSideways = static_cast<float>(M_PI_2);

} // namespace

/**
 * Seeds the three alt-frame marker layout tables (low/mid/high lane counts) with each
 * marker's sprite-kind, base position, rotation, and scale.
 *
 * A load-time constructor: the base Y values are relative to the play-field layout centre split as
 * it stands when the seeder runs.
 * @ghidraAddress 0x17b218
 */
__attribute__((constructor)) void SeedAltFrameLayoutTable() {
    const float flSplit = static_cast<float>(g_nPlayfieldCentreSplit);
    const float flY1 = 1.0f - flSplit;
    const float flY1023 = 1023.0f - flSplit;
    const float flY0 = -flSplit;
    const float flY1024 = 1024.0f - flSplit;
    const float flY391 = 391.0f - flSplit;
    const float flY512 = 512.0f - flSplit;
    const float flY461 = 461.0f - flSplit;
    const float flY1002 = 1002.0f - flSplit;

    g_aAltFrameMarker4[0] = {0, kColLeftEdge, flY1, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker4[1] = {0, kColLeftEdge, flY1023, 0.0f, 1.0f, -1.0f};
    g_aAltFrameMarker4[2] = {1, kColRightInner, flY1, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker4[3] = {1, kColRightInner, flY1023, 0.0f, 1.0f, -1.0f};
    g_aAltFrameMarker4[4] = {2, kColLeftInner, flY0, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker4[5] = {2, kColLeftInner, flY1024, 0.0f, 1.0f, -1.0f};
    g_aAltFrameMarker4[6] = {8, kColLeftClose, flY391, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker4[7] = {3, kColLeftMid, flY512, kRotSideways, 1.0f, 1.0f};
    g_aAltFrameMarker4[8] = {9, kColRightEdge, flY461, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker4[9] = {4, kColRightMid, flY512, 0.0f, 1.0f, 1.0f};

    g_aAltFrameMarker6[0] = {0, kColLeftEdge, flY1, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker6[1] = {0, kColLeftEdge, flY1023, 0.0f, 1.0f, -1.0f};
    g_aAltFrameMarker6[2] = {1, kColRightInner, flY1, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker6[3] = {1, kColRightInner, flY1023, 0.0f, 1.0f, -1.0f};
    g_aAltFrameMarker6[4] = {2, kColNarrowInner, flY0, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker6[5] = {3, kColNarrowOuter, flY0, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker6[6] = {4, kColLeftInner, flY0, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker6[7] = {2, kColNarrowInner, flY1024, 0.0f, 1.0f, -1.0f};
    g_aAltFrameMarker6[8] = {3, kColNarrowOuter, flY1024, 0.0f, 1.0f, -1.0f};
    g_aAltFrameMarker6[9] = {4, kColLeftInner, flY1024, 0.0f, 1.0f, -1.0f};
    g_aAltFrameMarker6[10] = {10, kColLeftClose, flY391, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker6[11] = {5, kColLeftMid, flY512, kRotSideways, 1.0f, 1.0f};
    g_aAltFrameMarker6[12] = {11, kColRightEdge, flY461, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker6[13] = {6, kColRightMid, flY512, 0.0f, 1.0f, 1.0f};

    g_aAltFrameMarker9[0] = {0, kColLeftEdge, flY1, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker9[1] = {1, kColLeftEdge, flY512, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker9[2] = {2, kColRightInner, flY1, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker9[3] = {3, kColRightInner, flY512, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker9[4] = {4, kColCentre, flY0, -kRotSideways, 1.0f, 1.0f};
    g_aAltFrameMarker9[5] = {5, kColRightInner, flY0, -kRotSideways, 1.0f, 1.0f};
    g_aAltFrameMarker9[6] = {6, kColCentre, flY1002, -kRotSideways, 1.0f, 1.0f};
    g_aAltFrameMarker9[7] = {7, kColRightInner, flY1002, -kRotSideways, 1.0f, 1.0f};
    g_aAltFrameMarker9[8] = {13, kColLeftClose, flY391, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker9[9] = {8, kColLeftMid, flY512, kRotSideways, 1.0f, 1.0f};
    g_aAltFrameMarker9[10] = {14, kColRightEdge, flY461, 0.0f, 1.0f, 1.0f};
    g_aAltFrameMarker9[11] = {9, kColRightMid, flY512, 0.0f, 1.0f, 1.0f};
}
