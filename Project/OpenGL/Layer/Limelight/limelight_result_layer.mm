#include "limelight_result_layer.h"

#include <cassert>
#include <cmath>

#include "../Classic/classic_parts_data_table.h"
#include "../Colette/phone_anchor_table.h"
#import "AppDelegate.h"
#import "MusicData.h"
#import "RBViewController.h"
#include "ScoreTracker.h"
#import "TwitterImageCreater.h"
#include "deviceenvironment.h"
#include "engineglobals.h"
#include "fade_overlay_layer.h"
#include "float_tween.h"
#import "gamesystem.h"
#include "limelight_parts_data_table.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "parts_data_table.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#include "touch_point.h"
#include "touchmanager.h"
#include "vectormath.h"

// The process-wide Limelight result-window layer, created lazily by shared().
static LimelightResultLayer *g_pLimelightResultLayer = nullptr; // @ghidraAddress 0x3de008

// The number of records in each Limelight phone-layout anchor-position table.
constexpr int kLimelightPhoneAnchorRecordCount = 88;

// The Limelight phone-layout anchor-position tables, zero-initialised in the binary's __common
// segment and filled at runtime by the result-layout-table initialisers; the orientation flag
// selects between them.
PhoneAnchorRecord
    g_aLimelightPhoneAnchorDefault[kLimelightPhoneAnchorRecordCount]; // @ghidraAddress 0x3dad10
PhoneAnchorRecord
    g_aLimelightPhoneAnchorPortrait[kLimelightPhoneAnchorRecordCount]; // @ghidraAddress 0x3db130

// The number of records in each Limelight phone-layout separator table.
constexpr int kLimelightSeparatorRecordCount = 52;

// The Limelight phone-layout separator tables (0x14-stride PhoneLayoutRecord), zero-initialised in
// the binary's __common segment and filled at runtime; the orientation flag selects between them.
PhoneLayoutRecord
    g_aLimelightSeparatorPhoneDefault[kLimelightSeparatorRecordCount]; // @ghidraAddress 0x3db550
PhoneLayoutRecord
    g_aLimelightSeparatorPhonePortrait[kLimelightSeparatorRecordCount]; // @ghidraAddress 0x3db960

// The number of records in each Limelight phone-layout by-state position table.
constexpr int kLimelightPositionByStateRecordCount = 4;

// The Limelight phone-layout by-state position tables (0x14-stride PhoneLayoutRecord): the state
// table (used on the iPad), and the portrait and default tables (selected by the orientation flag on
// the phone). Zero-initialised in the binary's __common segment and filled at runtime.
PhoneLayoutRecord
    g_aLimelightPositionPhoneState[kLimelightPositionByStateRecordCount]; // @ghidraAddress 0x3dbd70
PhoneLayoutRecord g_aLimelightPositionPhoneStatePortrait
    [kLimelightPositionByStateRecordCount]; // @ghidraAddress 0x3dbdc0
PhoneLayoutRecord g_aLimelightPositionPhoneStateDefault
    [kLimelightPositionByStateRecordCount]; // @ghidraAddress 0x3dbe10

// The single Limelight phone-layout centre-position records (16-byte PhoneLayoutRect, no anchor
// mode): the state record, and the portrait and default records (selected by the is-pad flag and
// orientation flags). Zero-initialised in the binary's __common segment and filled at runtime.
PhoneLayoutRect g_LimelightCenterPositionPhoneState = {};    // @ghidraAddress 0x3dbe60
PhoneLayoutRect g_LimelightCenterPositionPhonePortrait = {}; // @ghidraAddress 0x3dbe70
PhoneLayoutRect g_LimelightCenterPositionPhoneDefault = {};  // @ghidraAddress 0x3dbe80

// The Limelight phone parts anchor table (declared in limelight_parts_data_table.h):
// zero-initialised here to match the binary's __common segment, filled at runtime.
S_VECTOR2 g_aLimelightPartsAnchorPhone[kLimelightPartsAnchorRecordCount] =
    {}; // @ghidraAddress 0x3da8e8

// The Limelight colour-marker rectangles and their origin (declared in
// limelight_parts_data_table.h): zero-initialised here, filled at runtime.
PhoneLayoutRect g_aLimelightColorMarkerRects[kLimelightColorMarkerRectCount] =
    {};                                      // @ghidraAddress 0x3ddd90
S_VECTOR2 g_LimelightColorMarkerOrigin = {}; // @ghidraAddress 0x3de000

// The shared UV-palette table (declared in limelight_parts_data_table.h) the part emitters index
// by a parts record's UV-palette index. Read-only ROM data transcribed from the binary; the entry
// count is set by the span up to the next table rather than by any bound in the code.
// @ghidraAddress 0x2f2a28
const UvPaletteEntry g_aUvPalette[] = {
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
    {0.001953125f, 0.3203125f, 0.4921875f, 0.029296875f},
    {0.001953125f, 0.38378906f, 0.4921875f, 0.0009765625f},
    {0.001953125f, 0.3828125f, 0.4921875f, 0.01171875f},
    {0.001953125f, 0.3515625f, 0.4921875f, 0.029296875f},
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
    {0.001953125f, 0.6503906f, 0.54003906f, 0.05859375f},
    {0.001953125f, 0.71191406f, 0.021484375f, 0.0009765625f},
    {0.45898438f, 0.40234375f, 0.16210938f, 0.02734375f},
    {0.45898438f, 0.43164062f, 0.16210938f, 0.02734375f},
    {0.49609375f, 0.04296875f, 0.15234375f, 0.0390625f},
    {0.5625f, 0.001953125f, 0.15234375f, 0.0390625f},
    {0.49609375f, 0.001953125f, 0.064453125f, 0.04296875f},
    {0.265625f, 0.7519531f, 0.18945312f, 0.02734375f},
    {0.001953125f, 0.8613281f, 0.4921875f, 0.036132812f},
    {0.49609375f, 0.7519531f, 0.09765625f, 0.09765625f},
    {0.5957031f, 0.8183594f, 0.03125f, 0.03125f},
    {0.62890625f, 0.8183594f, 0.03125f, 0.03125f},
    {0.49609375f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.5371094f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.578125f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.6191406f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.66015625f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.7011719f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.7421875f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.7832031f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.82421875f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.8652344f, 0.87109375f, 0.0390625f, 0.046875f},
    {0.49609375f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.5292969f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.5625f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.5957031f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.62890625f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.6621094f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.6953125f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.7285156f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.76171875f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.7949219f, 0.9199219f, 0.03125f, 0.0390625f},
    {0.828125f, 0.9199219f, 0.0078125f, 0.0390625f},
    {0.001953125f, 0.82421875f, 0.4921875f, 0.036132812f},
    {0.001953125f, 0.9121094f, 0.14453125f, 0.021484375f},
    {0.1484375f, 0.9121094f, 0.14453125f, 0.021484375f},
    {0.001953125f, 0.9355469f, 0.14453125f, 0.021484375f},
    {0.1484375f, 0.9355469f, 0.14453125f, 0.021484375f},
    {0.29492188f, 0.9121094f, 0.01953125f, 0.01953125f},
    {0.53125f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.5488281f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.56640625f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.5839844f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.6015625f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.6191406f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.63671875f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.6542969f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.671875f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.6894531f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.70703125f, 0.8515625f, 0.00390625f, 0.017578125f},
    {0.49609375f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.5136719f, 0.8515625f, 0.015625f, 0.017578125f},
    {0.0029296875f, 0.9326172f, 0.0009765625f, 0.0009765625f},
};

// The Limelight glyph UV-palette table (declared in limelight_parts_data_table.h) the pad-glyph
// emitter indexes by a parts record's UV-palette index; distinct from the part palette above. Its
// 142 entries match kLimelightPadGlyphRecordBound.
// @ghidraAddress 0x2f55a8
const UvPaletteEntry g_aLimelightGlyphUvPalette[] = {
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
    {0.001953125f, 0.005859375f, 0.015625f, 0.001953125f},
    {0.01953125f, 0.00390625f, 0.1171875f, 0.0703125f},
    {0.13964844f, 0.00390625f, 0.0009765625f, 0.0703125f},
    {0.1484375f, 0.00390625f, 0.052734375f, 0.0703125f},
    {0.41210938f, 0.26171875f, 0.08203125f, 0.140625f},
    {0.3876953f, 0.859375f, 0.0009765625f, 0.140625f},
    {0.001953125f, 0.89453125f, 0.2265625f, 0.0625f},
    {0.001953125f, 0.1640625f, 0.1953125f, 0.09375f},
    {0.19921875f, 0.1640625f, 0.1953125f, 0.09375f},
    {0.39648438f, 0.1640625f, 0.06640625f, 0.09375f},
    {0.12109375f, 0.53125f, 0.1171875f, 0.046875f},
    {0.484375f, 0.109375f, 0.01171875f, 0.0234375f},
    {0.5019531f, 0.00390625f, 0.12890625f, 0.046875f},
    {0.69921875f, 0.0546875f, 0.1953125f, 0.046875f},
    {0.5019531f, 0.19921875f, 0.09765625f, 0.1953125f},
    {0.6015625f, 0.33203125f, 0.03125f, 0.0625f},
    {0.6347656f, 0.33203125f, 0.03125f, 0.0625f},
    {0.5019531f, 0.4375f, 0.0390625f, 0.09375f},
    {0.54296875f, 0.4375f, 0.0390625f, 0.09375f},
    {0.5839844f, 0.4375f, 0.0390625f, 0.09375f},
    {0.625f, 0.4375f, 0.0390625f, 0.09375f},
    {0.6660156f, 0.4375f, 0.0390625f, 0.09375f},
    {0.70703125f, 0.4375f, 0.0390625f, 0.09375f},
    {0.7480469f, 0.4375f, 0.0390625f, 0.09375f},
    {0.7890625f, 0.4375f, 0.0390625f, 0.09375f},
    {0.8300781f, 0.4375f, 0.0390625f, 0.09375f},
    {0.87109375f, 0.4375f, 0.0390625f, 0.09375f},
    {0.5019531f, 0.53515625f, 0.03125f, 0.078125f},
    {0.53515625f, 0.53515625f, 0.03125f, 0.078125f},
    {0.5683594f, 0.53515625f, 0.03125f, 0.078125f},
    {0.6015625f, 0.53515625f, 0.03125f, 0.078125f},
    {0.6347656f, 0.53515625f, 0.03125f, 0.078125f},
    {0.66796875f, 0.53515625f, 0.03125f, 0.078125f},
    {0.7011719f, 0.53515625f, 0.03125f, 0.078125f},
    {0.734375f, 0.53515625f, 0.03125f, 0.078125f},
    {0.7675781f, 0.53515625f, 0.03125f, 0.078125f},
    {0.80078125f, 0.53515625f, 0.03125f, 0.078125f},
    {0.8339844f, 0.53515625f, 0.0078125f, 0.078125f},
    {0.5019531f, 0.0546875f, 0.1953125f, 0.046875f},
    {0.5019531f, 0.10546875f, 0.14453125f, 0.04296875f},
    {0.6484375f, 0.10546875f, 0.14453125f, 0.04296875f},
    {0.5019531f, 0.15234375f, 0.14453125f, 0.04296875f},
    {0.6484375f, 0.15234375f, 0.14453125f, 0.04296875f},
    {0.7949219f, 0.10546875f, 0.01953125f, 0.0390625f},
    {0.5371094f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.5546875f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.5722656f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.58984375f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.6074219f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.625f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.6425781f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.66015625f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.6777344f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.6953125f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.5019531f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.51953125f, 0.3984375f, 0.015625f, 0.03515625f},
    {0.71191406f, 0.3984375f, 0.00390625f, 0.03515625f},
};

namespace {

// The atlases the result window loads (@ghidraAddress 0x3cea80 and 0x3ceab0).
constexpr const char *kBackgroundTextureName = "00_texture/sel_bg";
constexpr const char *kPartsTextureName = "00_texture/result_parts";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x308a60). Slot 1 (the parts atlas) holds
// the most sprites; the rest are small fixed banks.
constexpr unsigned int kSlotCapacities[] = {1, 400, 1, 1, 1, 2, 2, 1};

// The per-slot texture-field selector (@ghidraAddress 0x308a40): the field index (0 = background,
// 1 = parts, 2 = overlay) into the layer's three texture fields for each slot that binds a texture.
// A slot binds a texture only when it is one of the first two or the last; the middle slots share
// the atlas already bound by the batch they mirror.
constexpr int kSlotTextureField[] = {0, 1, 4, 4, 4, 4, 4, 2};

// The base scale the builder seeds before creating the batches.
constexpr float kBaseScale = 0.7f;

// The non-zero defaults the constructor seeds: the default part alpha, and the "none" sentinels for
// the current result step and each button's tracked touch id.
constexpr int kDefaultPartAlpha = 0xff;
constexpr int kNoStep = -1;
constexpr int kNoTouchId = -1;

// The slot range whose members do not bind a texture: slots kFirstUntexturedSlot through
// kFirstUntexturedSlot + kUntexturedSlotSpan - 1 (that is, slots 2 through 6).
constexpr int kFirstUntexturedSlot = 2;
constexpr int kUntexturedSlotSpan = 5;

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

// Builds the Limelight result-screen Twitter share image from the current play result and posts it
// through the view controller. This variant uses the dark (black) title and artist images. A free
// function that reads only the game-system, score-tracker, and app-delegate singletons.
// @ghidraAddress 0x124570
void PostResultToTwitterBlack() {
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectShare);

    RBViewController *pViewController = AppDelegate.appDelegate.viewController;
    if (pViewController == nil) {
        return;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    ScoreTracker *pTracker = ScoreTracker::shared();

    TwitterImageCreater *pCreater = [[TwitterImageCreater alloc] init];
    MusicData *pMusic = AppDelegate.appDelegate.musicData;
    pCreater.titleImage = pMusic.musicNameImageBlack;
    pCreater.artistImage = pMusic.artistNameImageBlack;
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

// Offsets a base coordinate by half or full viewport dimensions per the anchor mode.
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

/** @ghidraAddress 0x12abb4 */
LimelightResultLayer::LimelightResultLayer() {
    // The base constructor and the zero-initialised members clear the layer; the constructor then
    // seeds the non-zero defaults: the default part alpha, the current-step "none" sentinel, and each
    // button's "none" touch id.
    m_nDefaultAlpha = kDefaultPartAlpha;
    m_nCurrentStep = kNoStep;
    for (ResultButtonRecord &button : m_aButtons) {
        button.nTouchId = kNoTouchId;
    }
}

/** @ghidraAddress 0x123d54 */
LimelightResultLayer *LimelightResultLayer::shared() {
    if (g_pLimelightResultLayer == nullptr) {
        // The binary allocates the raw 0x170-byte object and runs its initialiser, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pLimelightResultLayer = new LimelightResultLayer();
    }
    return g_pLimelightResultLayer;
}

namespace {
// The Update timers' constants.
// The positive slide-timer divisor (the timer counts toward zero) (@ghidraAddress 0x2fd050 = -300).
constexpr float kSlideTimerRateDown = -300.0f;
// The negative slide-timer divisor (@ghidraAddress 0x2eedcc = 300).
constexpr float kSlideTimerRateUp = 300.0f;
// The decoration rotation counter wraps at this frame count (@ghidraAddress the 0xc0 modulus).
constexpr int kRotationWrap = 0xc0;
// The frames per decoration animation index (@ghidraAddress 0x2fcff8 = 48).
constexpr float kRotationFramesPerIndex = 48.0f;
// The last decoration animation frame index.
constexpr int kRotationFrameMax = 3;

// The five bonus channels' advance order the update uses (channels 2 and 3 are advanced swapped).
constexpr int kBonusAdvanceOrder[] = {0, 1, 3, 2, 4};
} // namespace

/** @ghidraAddress 0x12adac */
void LimelightResultLayer::Update(float flDeltaTime) {
    // Off an iPad, keep the portrait-orientation flag in sync with the viewport aspect.
    if (!IsPad()) {
        const float flWidth = GameSystem::GetGameSystem()->GetViewportWidth();
        const bool bPortrait = flWidth <= GameSystem::GetGameSystem()->GetViewportHeight();
        if (bPortrait != m_bPortrait) {
            m_bPortrait = bPortrait;
        }
    }

    // Advance the five bonus channels. The channel shares FloatTween's six-float layout and the binary
    // drives it through FloatTween::Advance, so advance each through that view.
    for (int nChannel : kBonusAdvanceOrder) {
        reinterpret_cast<FloatTween *>(&m_aBonusAnimChannels[nChannel])->Advance(flDeltaTime);
    }

    // Advance the signed slide/settle timer toward zero, at differing rates by sign, and clamp on the
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

    // Advance the decoration rotation counter (wrapping every 192 frames) and derive its frame index.
    int nCounter = static_cast<int>(static_cast<float>(m_nRotationCounter) + flDeltaTime);
    if (nCounter > kRotationWrap) {
        nCounter %= kRotationWrap;
    }
    m_nRotationCounter = nCounter;
    int nFrame = static_cast<int>(static_cast<float>(nCounter) / kRotationFramesPerIndex);
    if (nFrame < 0) {
        nFrame = 0;
    }
    if (nFrame > kRotationFrameMax) {
        nFrame = kRotationFrameMax;
    }
    m_nRotationFrame = nFrame;

    UpdateBonusSoundCueTimer(flDeltaTime);
    UpdatePhoneTouchAndShare();

    // Dispatch to the Limelight (iPad) or phone (portrait) render path.
    if (IsPad()) {
        RenderLimelightResultWindow();
    } else {
        RenderPhoneResultWindow();
    }
}

/** @ghidraAddress 0x12ab60 */
void LimelightResultLayer::InitializePhoneResultLayer() {
    m_nActive = 1;
    m_bBonusCueArmed = GameSystem::GetGameSystem()->IsNewRecord();
    m_flBonusCueTimer = 0.0f;
    m_bTwitterAvailable = [RBViewController hasTwitterAPI];
}

/** @ghidraAddress 0x123db0 */
void LimelightResultLayer::InitializePhoneSpriteInstancers() {
    if (m_bBuilt) {
        return;
    }

    m_nDefaultAlpha = 0;
    m_flBaseScale = kBaseScale;

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {
        m_pBackgroundTexture, m_pPartsTexture, m_pOverlayTexture};

    // Build one sprite instancer per slot, register it in the global scene tree, make it visible,
    // and clear its sprite count. The two edge slots bind a texture per the selector; the middle
    // slots (2 through 6) share the atlas of the batch they mirror, so they bind none here.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot] = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        m_apSprites[nSlot]->RegisterGlobal();
        m_apSprites[nSlot]->SetVisible(true);
        if (static_cast<unsigned int>(nSlot - kFirstUntexturedSlot) >= kUntexturedSlotSpan) {
            m_apSprites[nSlot]->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        }
        m_apSprites[nSlot]->SetSpriteCount(0);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x123e8c */
void LimelightResultLayer::SetPhoneInstancerTextureAndScale(unsigned int nPhoneIndex,
                                                            ne::C_TEXTURE *pTexture) {
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nPhoneIndex];
    if (pInstancer == nullptr) {
        return;
    }
    const int nCount = static_cast<int>(pInstancer->GetCapacity());
    pInstancer->SetRefCountedMember(pTexture);
    if (pTexture == nullptr || nCount < 1) {
        return;
    }

    // The image's point size (its pixels over the retina scale) and its fraction of the allocated
    // power-of-two texture.
    const float flPointWidth = static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetScale();
    const float flPointHeight =
        static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetScale();
    const S_VECTOR2 size{flPointWidth, flPointHeight};
    const S_VECTOR2 uvSize{static_cast<float>(pTexture->GetImageWidth()) /
                               static_cast<float>(pTexture->GetAllocWidth()),
                           static_cast<float>(pTexture->GetImageHeight()) /
                               static_cast<float>(pTexture->GetAllocHeight())};

    for (int nSlot = 0; nSlot < nCount; ++nSlot) {
        pInstancer->SetSpriteSize(nSlot, size);
        pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{0.0f, 0.0f});
        pInstancer->SetSpriteUvSize(nSlot, uvSize);
    }
}

/** @ghidraAddress 0x123838 */
PartsDataRecord *LimelightResultLayer::GetPartsData(unsigned int nIndex) {
    assert(static_cast<int>(nIndex) >= 0 && nIndex < kLimelightPartsRecordBound);

    // The pad branch reads the runtime-filled table and the phone branch the baked-in one. The two
    // globals' names read inverted against that: the table the pad branch selects is the one named
    // "Phone" (0x3d9100, filled by InitializePhoneResultLayoutTable) and the table the phone branch
    // selects is the one named "Pad" (0x307cf0, constant rodata). The selector below follows the
    // binary's `csel x0,x9,x8,ne`; the naming is left as landed rather than renamed here.
    return ::IsPad() ? &g_aLimelightPartsPhone[nIndex] : &g_aLimelightPartsPad[nIndex];
}

/** @ghidraAddress 0x1238d0 */
PartsDataRecord *LimelightResultLayer::getPartsData_Phone(int nIndex) {
    assert(nIndex >= 0 && nIndex < kLimelightPadGlyphRecordBound);

    // The pad parts table doubles as the phone glyph-metrics table.
    return &g_aLimelightPartsPad[nIndex];
}

/** @ghidraAddress 0x123940 */
void LimelightResultLayer::getPosition_Phone(int nIndex, S_VECTOR2 *pOutPosition) const {
    assert(nIndex >= 0 && nIndex < kLimelightPhoneAnchorRecordCount);

    // The orientation flag selects the portrait table; otherwise the default table is used.
    const PhoneAnchorRecord &record = m_bPortrait ? g_aLimelightPhoneAnchorPortrait[nIndex] :
                                                    g_aLimelightPhoneAnchorDefault[nIndex];
    pOutPosition->x = record.flX;
    pOutPosition->y = record.flY;

    // Offset the base coordinate by half or full viewport dimensions per the record's anchor mode.
    ApplyAnchorOffset(record.nAnchorMode, &pOutPosition->x, &pOutPosition->y);
}

/** @ghidraAddress 0x123b5c */
void LimelightResultLayer::getPositionByState_Phone(int nIndex, PhoneLayoutRect *pOutRect) const {
    // The iPad uses the state table; the phone uses its portrait or default table by orientation.
    const PhoneLayoutRecord &record =
        IsPad() ? g_aLimelightPositionPhoneState[nIndex] :
                  (m_bPortrait ? g_aLimelightPositionPhoneStatePortrait[nIndex] :
                                 g_aLimelightPositionPhoneStateDefault[nIndex]);
    pOutRect->flX = record.flX;
    pOutRect->flY = record.flY;
    pOutRect->flWidth = record.flWidth;
    pOutRect->flHeight = record.flHeight;

    // Offset the leading coordinate by half or full viewport dimensions per the record's anchor mode.
    ApplyAnchorOffset(record.nAnchorMode, &pOutRect->flX, &pOutRect->flY);
}

/** @ghidraAddress 0x123ad8 */
const PhoneLayoutRecord *LimelightResultLayer::getSeparator_Phone(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kLimelightSeparatorRecordCount);

    // The orientation flag selects the portrait table; otherwise the default table is used.
    return m_bPortrait ? &g_aLimelightSeparatorPhonePortrait[nIndex] :
                         &g_aLimelightSeparatorPhoneDefault[nIndex];
}

/** @ghidraAddress 0x129a64 */
void LimelightResultLayer::RenderPhoneSpriteFieldAligned(unsigned int nSlot,
                                                         unsigned int nSeparatorIndex,
                                                         unsigned int nPartIndex,
                                                         const S_VECTOR2 *pOffset,
                                                         unsigned int nAlpha) {
    if (nPartIndex >= static_cast<unsigned int>(kLimelightPadGlyphRecordBound) ||
        nSeparatorIndex >= static_cast<unsigned int>(kLimelightSeparatorRecordCount)) {
        return;
    }

    // The part's texture rectangle comes from the glyph UV palette, indexed by the part's frame.
    const PartsDataRecord &part = g_aLimelightPartsPad[nPartIndex];
    const UvPaletteEntry &uv = g_aLimelightGlyphUvPalette[part.nUvPaletteIndex];

    // The separator record supplies the base position, its viewport anchor mode, and (in its carried
    // width and height) the sprite's X scale and rotation.
    const PhoneLayoutRecord *pSeparator = getSeparator_Phone(static_cast<int>(nSeparatorIndex));

    float flAnchorX = 0.0f;
    float flAnchorY = 0.0f;
    ApplyAnchorOffset(pSeparator->nAnchorMode, &flAnchorX, &flAnchorY);

    const S_VECTOR2 position{flAnchorX + pSeparator->flX + pOffset->x,
                             flAnchorY + pSeparator->flY + pOffset->y};
    AppendSpriteToSlot(position,
                       S_VECTOR2{part.flX, part.flY},
                       S_VECTOR2{part.flWidth, part.flHeight},
                       S_VECTOR2{uv.flU, uv.flV},
                       S_VECTOR2{uv.flUvWidth, uv.flUvHeight},
                       pSeparator->flHeight,
                       S_VECTOR2{pSeparator->flWidth, 1.0f},
                       nSlot,
                       kDefaultPartAlpha,
                       nAlpha);
}

/** @ghidraAddress 0x123cc8 */
void LimelightResultLayer::getCenterPosition_Phone(PhoneLayoutRect *pOutRect) const {
    // When the state flag is set the state record is copied verbatim, with no viewport anchoring.
    if (IsPad()) {
        *pOutRect = g_LimelightCenterPositionPhoneState;
        (void)GameSystem::
            GetGameSystem(); // The binary tail-calls the singleton getter and discards it.
        return;
    }

    // Otherwise the orientation flag selects the portrait or default record, and the leading
    // coordinate is shifted by half the viewport width and height.
    const PhoneLayoutRect &record = m_bPortrait ? g_LimelightCenterPositionPhonePortrait :
                                                  g_LimelightCenterPositionPhoneDefault;
    *pOutRect = record;
    ApplyAnchorOffset(kAnchorHalfWidthHalfHeight, &pOutRect->flX, &pOutRect->flY);
}

/** @ghidraAddress 0x129f84 */
void LimelightResultLayer::EmitPhonePartWithOffset(unsigned int nSlot,
                                                   unsigned int nCharCode,
                                                   const S_VECTOR2 &position,
                                                   const S_VECTOR2 &offset,
                                                   unsigned int nAlpha,
                                                   bool bShadowPass,
                                                   float flRotation,
                                                   float flScaleX,
                                                   float flScaleY) {
    if (nCharCode >= kLimelightPadGlyphRecordBound) {
        return;
    }
    // The glyph metrics come from the pad parts table indexed by the character code; the texture
    // rectangle from the Limelight glyph UV palette. The sprite is placed at the position plus the
    // offset.
    const PartsDataRecord *pGlyph = &g_aLimelightPartsPad[nCharCode];
    const UvPaletteEntry &palette = g_aLimelightGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass ? 0x80 : 0xff;
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

/** @ghidraAddress 0x12a01c */
void LimelightResultLayer::RenderPhonePartWithOffset(unsigned int nSlot,
                                                     unsigned int nCharCode,
                                                     int nPositionIndex,
                                                     const S_VECTOR2 &offset,
                                                     unsigned int nAlpha,
                                                     bool bShadowPass,
                                                     float flRotation,
                                                     float flScaleX,
                                                     float flScaleY) {
    if (nCharCode >= kLimelightPadGlyphRecordBound) {
        return;
    }
    // Resolve the base position by index and add the offset.
    S_VECTOR2 position{};
    getPosition_Phone(nPositionIndex, &position);
    // The glyph metrics come from the pad parts table indexed by the character code; the texture
    // rectangle from the Limelight glyph UV palette.
    const PartsDataRecord *pGlyph = &g_aLimelightPartsPad[nCharCode];
    const UvPaletteEntry &palette = g_aLimelightGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bShadowPass ? 0x80 : 0xff;
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

/** @ghidraAddress 0x129c34 */
void LimelightResultLayer::EmitPhoneHalfScaleTexturedPart(unsigned int nSlot,
                                                          const S_VECTOR2 &position,
                                                          unsigned int nScale,
                                                          unsigned int nIntensity) {
    if (nSlot >= kSpriteSlotCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlot];
    if (pInstancer == nullptr) {
        return;
    }
    // The binary does not null-check the bound texture here.
    ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flTextureScale = pTexture->GetScale();
    // The quad is sized by the texture's scale factor and centred by anchoring at half its size.
    const S_VECTOR2 spriteSize{flImageWidth / flTextureScale, flImageHeight / flTextureScale};
    const S_VECTOR2 anchor{spriteSize.x * 0.5f, spriteSize.y * 0.5f};
    const S_VECTOR2 uvSize{flImageWidth / static_cast<float>(pTexture->GetAllocWidth()),
                           flImageHeight / static_cast<float>(pTexture->GetAllocHeight())};
    const unsigned int nAlpha =
        static_cast<unsigned int>(static_cast<float>(nScale) * m_flBaseScale);
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

namespace {

// The digit glyph bank RenderPhoneNumberDigitsRow draws from (its '0'), its maximum digit count, the
// nominal glyph width used to centre the run, and the extra pixel added to each glyph's own width
// when advancing. The glyphs draw into the parts slot.
constexpr unsigned int kPhoneRowGlyphSlot = 1;
constexpr unsigned int kPhoneRowDigitBank = 0x39;
constexpr int kPhoneRowMaxDigits = 4;
constexpr float kPhoneRowNominalGlyphWidth = 7.0f;
constexpr float kPhoneRowGlyphSpacing = 1.0f;

} // namespace

namespace {
// The total-score digit layout: the number of digit places, the minimum drawn, the ones-place and
// higher-place glyph banks, the marker glyph drawn below the ones digit, the marker's x and y
// offsets, the between-digit gap, the tenths scale, and the alpha-halving factor.
constexpr int kTotalScoreDigits = 7;
constexpr int kTotalScoreMinDigits = 2;
constexpr unsigned int kTotalScoreOnesBank = 0x71;
constexpr unsigned int kTotalScoreHighBank = 0x67;
constexpr unsigned int kTotalScoreMarkerGlyph = 0x7b;
constexpr float kTotalScoreMarkerOffsetX = -4.0f;
constexpr float kTotalScoreMarkerOffsetY = -20.0f;
constexpr float kTotalScoreDigitGap = -2.0f;
constexpr float kTotalScoreTenthsScale = 10.0f;
constexpr float kTotalScoreDimFactor = 0.5f;

// The paired ones-place glyph sits ten part ids above the digit-zero base.
constexpr unsigned int kPhonePairedGlyphOffset = 10;

// The multiplier digit layout: the digit count, the minimum drawn, the digit glyph bank, and the
// marker glyph drawn beside the ones digit. It shares the total-score tenths scale, gap, and dim
// factor.
constexpr int kMultiplierDigits = 3;
constexpr int kMultiplierMinDigits = 2;
constexpr unsigned int kMultiplierDigitBank = 0x81;
constexpr unsigned int kMultiplierMarkerGlyph = 0x8d;
} // namespace

/** @ghidraAddress 0x129d04 */
void LimelightResultLayer::RenderPhoneNumber(float flSpacing,
                                             int nValue,
                                             int nMaxDigits,
                                             const S_VECTOR2 *pPosition,
                                             const S_VECTOR2 *pOffset,
                                             unsigned int nBasePartId,
                                             unsigned int nFlags,
                                             int bPadZeros,
                                             unsigned int nAlpha) {
    // Split the value into up to nMaxDigits digits (ones first), tracking the significant count.
    int aDigits[3] = {};
    int nSignificant = 0;
    for (int i = 0; i < nMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i;
        }
        nValue /= 10;
    }
    // When only the ones place is significant and the show-zero flag is set, draw a second (zero)
    // digit as well. The digit slot is already zero from the split.
    const bool bShowZero = (nFlags & 1) != 0;
    if (nSignificant == 0 && bShowZero) {
        nSignificant = 1;
    }

    // Start at the base position plus the offset.
    S_VECTOR2 cursor = *pPosition;
    S_VECTOR2 offset = *pOffset;
    AddVector2(&cursor, &offset);

    // Draw each significant digit right to left, stepping the cursor left by the glyph's own width
    // less the spacing. When the paired flag is set, a second glyph ten ids up is drawn beside the
    // ones digit.
    const bool bPaired = (nFlags & 1) != 0;
    for (int i = 0; i <= nSignificant; ++i) {
        const unsigned int nGlyph = aDigits[i] + nBasePartId;
        cursor.x -= getPartsData_Phone(static_cast<int>(nGlyph))->flWidth;
        RenderPhoneResultSpriteById(1, nGlyph, cursor, nAlpha, 0, 0.0f, 1.0f, 1.0f);
        cursor.x -= flSpacing;
        if (i == 0 && bPaired) {
            const unsigned int nPaired = nBasePartId + kPhonePairedGlyphOffset;
            cursor.x -= getPartsData_Phone(static_cast<int>(nPaired))->flWidth;
            RenderPhoneResultSpriteById(1, nPaired, cursor, nAlpha, 0, 0.0f, 1.0f, 1.0f);
            cursor.x -= flSpacing;
        }
    }

    // Dim-pad the remaining leading positions with the base glyph.
    if (bPadZeros && nSignificant + 1 < nMaxDigits) {
        for (int nPad = (nMaxDigits - 1) - nSignificant; nPad != 0; --nPad) {
            cursor.x -= getPartsData_Phone(static_cast<int>(nBasePartId))->flWidth;
            RenderPhoneResultSpriteById(1, nBasePartId, cursor, nAlpha, 1, 0.0f, 1.0f, 1.0f);
            cursor.x -= flSpacing;
        }
    }
}

/** @ghidraAddress 0x12a760 */
void LimelightResultLayer::RenderPhoneMultiplierDigitSprites(float flMultiplier,
                                                             const S_VECTOR2 *pPosition,
                                                             unsigned int nAlpha) {
    // The multiplier is scaled to tenths and split into three digits (ones first).
    const int nValue = static_cast<int>(flMultiplier * kTotalScoreTenthsScale);
    int aDigits[kMultiplierDigits] = {};
    int nSignificant = 0;
    int nRemaining = nValue;
    for (int i = 0; i < kMultiplierDigits; ++i) {
        aDigits[i] = nRemaining % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nRemaining /= 10;
    }
    const int nDrawCount =
        nSignificant < kMultiplierMinDigits ? kMultiplierMinDigits : nSignificant;

    float flBaseline = pPosition->x;
    const float flPosY = pPosition->y;
    unsigned int nCurrentAlpha = nAlpha;
    for (int i = 0; i < kMultiplierDigits; ++i) {
        // Leading positions beyond the significant digits draw at half alpha.
        if (i == nDrawCount) {
            nCurrentAlpha = static_cast<unsigned int>(static_cast<float>(nCurrentAlpha & 0xff) *
                                                      kTotalScoreDimFactor);
        }
        const PartsDataRecord *pGlyph =
            getPartsData_Phone(static_cast<int>(aDigits[i] + kMultiplierDigitBank));
        const float flDrawX = flBaseline - pGlyph->flWidth;
        const float flDigitY = flPosY - pGlyph->flHeight;
        RenderPhoneResultSpriteById(1,
                                    aDigits[i] + kMultiplierDigitBank,
                                    S_VECTOR2{flDrawX, flDigitY},
                                    nCurrentAlpha & 0xff,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        flBaseline = flDrawX + kTotalScoreDigitGap;
        // The marker glyph is drawn at the post-advance baseline, beside the ones digit.
        if (i == 0) {
            RenderPhoneResultSpriteById(1,
                                        kMultiplierMarkerGlyph,
                                        S_VECTOR2{flBaseline, flDigitY},
                                        nCurrentAlpha & 0xff,
                                        0,
                                        0.0f,
                                        1.0f,
                                        1.0f);
        }
    }
}

/** @ghidraAddress 0x12a928 */
void LimelightResultLayer::RenderPhoneTotalScoreDigits(const S_VECTOR2 *pPosition,
                                                       unsigned int nAlpha) {
    // The total score is the sum of the five result-bonus values, scaled to tenths.
    const int nTotal = static_cast<int>((m_flExperienceBonus + m_flClearBonus + m_flMissBonus +
                                         m_flRankBonus + m_flFirstPlayBonus) *
                                        kTotalScoreTenthsScale);

    // Split into seven digits (ones first), tracking the significant count.
    int aDigits[kTotalScoreDigits] = {};
    int nSignificant = 0;
    int nRemaining = nTotal;
    for (int i = 0; i < kTotalScoreDigits; ++i) {
        aDigits[i] = nRemaining % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nRemaining /= 10;
    }
    const int nDrawCount =
        nSignificant < kTotalScoreMinDigits ? kTotalScoreMinDigits : nSignificant;

    float flCursorX = pPosition->x;
    const float flY = pPosition->y;
    unsigned int nCurrentAlpha = nAlpha;
    for (int i = 0; i < kTotalScoreDigits; ++i) {
        // The between-digit gap precedes every place after the ones digit.
        if (i != 0) {
            flCursorX += kTotalScoreDigitGap;
        }
        // Leading positions beyond the significant digits draw at half alpha.
        if (i == nDrawCount) {
            nCurrentAlpha = static_cast<unsigned int>(static_cast<float>(nCurrentAlpha & 0xff) *
                                                      kTotalScoreDimFactor);
        }
        const unsigned int nBank = i == 0 ? kTotalScoreOnesBank : kTotalScoreHighBank;
        const PartsDataRecord *pGlyph = getPartsData_Phone(static_cast<int>(aDigits[i] + nBank));
        flCursorX -= pGlyph->flWidth;
        RenderPhoneResultSpriteById(1,
                                    aDigits[i] + nBank,
                                    S_VECTOR2{flCursorX, flY - pGlyph->flHeight},
                                    nCurrentAlpha & 0xff,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        // A marker glyph sits below and just left of the ones digit.
        if (i == 0) {
            RenderPhoneResultSpriteById(
                1,
                kTotalScoreMarkerGlyph,
                S_VECTOR2{flCursorX + kTotalScoreMarkerOffsetX, flY + kTotalScoreMarkerOffsetY},
                nCurrentAlpha & 0xff,
                0,
                0.0f,
                1.0f,
                1.0f);
        }
    }
}

/** @ghidraAddress 0x12a11c */
void LimelightResultLayer::RenderPhoneNumberDigitsRow(int nValue,
                                                      const S_VECTOR2 *pPosition,
                                                      unsigned int nAlpha) {
    // Split the value into up to four digits (ones first), tracking the count of significant
    // digits, rendering at least one.
    int aDigits[kPhoneRowMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kPhoneRowMaxDigits; ++i) {
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
        static_cast<int>(static_cast<float>(nSignificant) * kPhoneRowNominalGlyphWidth);
    float flCursorX = pPosition->x + static_cast<float>(nHalfWidth) * 0.5f;
    const float flY = pPosition->y;

    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nGlyph = aDigits[i] + kPhoneRowDigitBank;
        const float flWidth =
            getPartsData_Phone(static_cast<int>(nGlyph))->flWidth + kPhoneRowGlyphSpacing;
        flCursorX -= flWidth;
        const S_VECTOR2 drawPos{flCursorX, flY};
        RenderPhoneResultSpriteById(
            kPhoneRowGlyphSlot, nGlyph, drawPos, nAlpha, 0, 0.0f, 1.0f, 1.0f);
    }
}

namespace {

// The percent-value glyph banks and layout: the parts slot, the digit bank ('0'), the leading
// percent marker glyph, the decimal-point glyph, the minimum digit count drawn, the fixed per-glyph
// advance, the extra centring pad, and the point's own advance.
constexpr unsigned int kPercentSlot = 1;
constexpr unsigned int kPercentDigitBank = 0x39;
constexpr unsigned int kPercentMarkerGlyph = 0x45;
constexpr unsigned int kPercentPointGlyph = 0x43;
constexpr int kPercentMinDigits = 2;
constexpr float kPercentGlyphAdvance = 6.0f;
constexpr float kPercentCentrePad = 2.0f;
constexpr float kPercentPointAdvance = 2.0f;

} // namespace

/** @ghidraAddress 0x12a50c */
void LimelightResultLayer::RenderPhonePercentValue(int nValue,
                                                   const S_VECTOR2 *pPosition,
                                                   unsigned int nAlpha) {
    // Split the value into up to four digits (ones first), tracking the significant-digit count.
    int aDigits[4] = {};
    int nSignificant = 0;
    for (int i = 0; i < 4; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    const int nDrawCount = nSignificant < kPercentMinDigits ? kPercentMinDigits : nSignificant;

    // Centre the run about the position: one advance per drawn digit plus the leading marker, rounded
    // and halved, then step left by one advance before the marker.
    const int nHalfWidth = static_cast<int>(
        static_cast<float>(nDrawCount + 1) * kPercentGlyphAdvance + kPercentCentrePad);
    float flCursorX = pPosition->x + static_cast<float>(nHalfWidth) * 0.5f - kPercentGlyphAdvance;
    const float flY = pPosition->y;

    // The leading percent marker.
    RenderPhoneResultSpriteById(
        kPercentSlot, kPercentMarkerGlyph, S_VECTOR2{flCursorX, flY}, nAlpha, 0, 0.0f, 1.0f, 1.0f);

    for (int i = 0; i < nDrawCount; ++i) {
        flCursorX -= kPercentGlyphAdvance;
        RenderPhoneResultSpriteById(kPercentSlot,
                                    aDigits[i] + kPercentDigitBank,
                                    S_VECTOR2{flCursorX, flY},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        // The decimal point follows the ones digit.
        if (i == 0) {
            flCursorX -= kPercentPointAdvance;
            RenderPhoneResultSpriteById(kPercentSlot,
                                        kPercentPointGlyph,
                                        S_VECTOR2{flCursorX, flY},
                                        nAlpha,
                                        0,
                                        0.0f,
                                        1.0f,
                                        1.0f);
        }
    }
}

namespace {

// The fraction glyph banks and layout: the parts slot, the digit bank ('0'), the separating slash
// glyph, the nominal per-digit width used to centre the run, the per-digit advance, the slash
// advance, and the centring pad.
constexpr unsigned int kFractionSlot = 1;
constexpr unsigned int kFractionDigitBank = 0x39;
constexpr unsigned int kFractionSlashGlyph = 0x46;
constexpr float kFractionNominalWidth = 7.0f;
constexpr float kFractionDigitInset = 6.0f;
constexpr float kFractionDigitAdvance = 7.0f;
constexpr float kFractionSlashInset = 7.0f;
constexpr float kFractionSlashAdvance = 1.0f;
constexpr float kFractionCentrePad = 2.0f;

// Splits a value into up to four digits (ones first) and returns the significant-digit count (at
// least one).
inline int SplitFractionDigits(int nValue, int (&aDigits)[4]) {
    int nSignificant = 0;
    for (int i = 0; i < 4; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    return nSignificant < 1 ? 1 : nSignificant;
}

} // namespace

/** @ghidraAddress 0x12a27c */
void LimelightResultLayer::RenderPhoneFraction(int nNumerator,
                                               int nDenominator,
                                               const S_VECTOR2 *pPosition,
                                               unsigned int nAlpha) {
    int aNumerator[4] = {};
    int aDenominator[4] = {};
    const int nNumCount = SplitFractionDigits(nNumerator, aNumerator);
    const int nDenCount = SplitFractionDigits(nDenominator, aDenominator);

    // Centre the run: the numerator and denominator digits at the nominal width, plus the slash's
    // advance and the centring pad, rounded and halved.
    const int nHalfWidth = static_cast<int>(static_cast<float>(nNumCount) * kFractionNominalWidth +
                                            static_cast<float>(nDenCount) * kFractionNominalWidth +
                                            kFractionDigitInset + kFractionCentrePad);
    float flCursorX = pPosition->x + static_cast<float>(nHalfWidth) * 0.5f;
    const float flY = pPosition->y;

    // The denominator digits, right to left.
    for (int i = 0; i < nDenCount; ++i) {
        RenderPhoneResultSpriteById(kFractionSlot,
                                    aDenominator[i] + kFractionDigitBank,
                                    S_VECTOR2{flCursorX - kFractionDigitInset, flY},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        flCursorX -= kFractionDigitAdvance;
    }

    // The separating slash: unlike a digit, its inset folds into the running cursor before the
    // slash's own one-pixel advance.
    flCursorX -= kFractionSlashInset;
    RenderPhoneResultSpriteById(
        kFractionSlot, kFractionSlashGlyph, S_VECTOR2{flCursorX, flY}, nAlpha, 0, 0.0f, 1.0f, 1.0f);
    flCursorX -= kFractionSlashAdvance;

    // The numerator digits, right to left.
    for (int i = 0; i < nNumCount; ++i) {
        RenderPhoneResultSpriteById(kFractionSlot,
                                    aNumerator[i] + kFractionDigitBank,
                                    S_VECTOR2{flCursorX - kFractionDigitInset, flY},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    1.0f,
                                    1.0f);
        flCursorX -= kFractionDigitAdvance;
    }
}

/** @ghidraAddress 0x12ac64 */
void LimelightResultLayer::AppendSpriteToSlot(const S_VECTOR2 &position,
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

/** @ghidraAddress 0x1299d8 */
void LimelightResultLayer::RenderPhoneResultSpriteById(unsigned int nSlot,
                                                       unsigned int nPartId,
                                                       const S_VECTOR2 &position,
                                                       unsigned int nAlpha,
                                                       bool bDimmed,
                                                       float flRotation,
                                                       float flScaleX,
                                                       float flScaleY) {
    if (nPartId >= kLimelightPadGlyphRecordBound) {
        return;
    }
    // The glyph metrics come from the pad parts table indexed by the part id; the texture rectangle
    // from the Limelight glyph UV palette.
    const PartsDataRecord *pGlyph = &g_aLimelightPartsPad[nPartId];
    const UvPaletteEntry &palette = g_aLimelightGlyphUvPalette[pGlyph->nUvPaletteIndex];
    const unsigned int nIntensity = bDimmed ? 0x80 : 0xff;
    AppendSpriteToSlot(position,
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

/** @ghidraAddress 0x12a6cc */
void LimelightResultLayer::EmitPhonePartAtAnchor(unsigned int nSlot,
                                                 unsigned int nPartId,
                                                 unsigned int nAnchorIndex,
                                                 const S_VECTOR2 *pOffset,
                                                 unsigned int nAlpha,
                                                 float flScaleX) {
    S_VECTOR2 position{};
    getPosition_Phone(static_cast<int>(nAnchorIndex), &position);
    S_VECTOR2 offset = *pOffset;
    AddVector2(&position, &offset);
    RenderPhoneResultSpriteById(nSlot, nPartId, position, nAlpha, false, 0.0f, flScaleX, 1.0f);
}

/** @ghidraAddress 0x126ab4 */
void LimelightResultLayer::EmitPartSprite(float flRotation,
                                          float flScaleX,
                                          float flScaleY,
                                          unsigned int nSlot,
                                          unsigned int nPartId,
                                          const S_VECTOR2 &position,
                                          unsigned int nAlpha,
                                          bool bShadowPass) {
    // Part id 0xff is the "no part" sentinel used to skip optional parts.
    if (nPartId >= 0xff) {
        return;
    }
    const PartsDataRecord *pRecord = GetPartsData(nPartId);
    const UvPaletteEntry &palette = g_aUvPalette[pRecord->nUvPaletteIndex];
    // The main pass draws at full intensity; the shadow pass darkens the quad to half intensity.
    const unsigned int nIntensity = bShadowPass ? 0x80 : 0xff;
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

namespace {

// The part id of the '0' digit glyph; digits 0 through 9 are parts kDigitZeroPart through
// kDigitZeroPart + 9.
constexpr unsigned int kDigitZeroPart = 0x69;
// The maximum number of decimal digits RenderDigits draws.
constexpr int kMaxDigits = 4;
// The instancer slot the parts atlas (including digit glyphs) draws into.
constexpr unsigned int kPartsSlot = 1;

// The maximum number of digits RenderNumber splits a value into (the binary's digit buffer holds
// six).
constexpr int kNumberMaxDigits = 6;
// The glyph-bank base part ids that carry special per-column layout handling: the two score-column
// banks, the rating-column bank, and the three banks whose trailing '1' is micro-nudged.
constexpr unsigned int kScoreColumnPartA = 0x7c;
constexpr unsigned int kScoreColumnPartB = 0x92;
constexpr unsigned int kRatingColumnPart = 0xa8;
constexpr unsigned int kNudgeBankPlus4A = 0x44;
constexpr unsigned int kNudgeBankPlus4B = 0x4e;
// The dim factor applied to the padded leading zeros (@ghidraAddress 0x2fd008).
constexpr float kPadZeroDimFactor = 0.7f;

} // namespace

/** @ghidraAddress 0x12705c */
void LimelightResultLayer::RenderDigits(int nValue,
                                        const S_VECTOR2 &position,
                                        unsigned int nAlpha) {
    // Split the value into up to four decimal digits (least-significant first), tracking how many
    // are significant; at least one digit is always drawn.
    int aDigits[kMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant == 0) {
        nSignificant = 1;
    }

    // Centre the run about the position using the zero-glyph's width as the nominal advance.
    const float flAdvance = GetPartsData(kDigitZeroPart)->flWidth;
    float flX = position.x + static_cast<float>(static_cast<int>(nSignificant * flAdvance)) * 0.5f;
    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nPart = kDigitZeroPart + aDigits[i];
        const float flGlyphWidth = GetPartsData(nPart)->flWidth;
        const S_VECTOR2 drawPos{flX - flGlyphWidth, position.y};
        EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nPart, drawPos, nAlpha, 0);
        flX -= flGlyphWidth;
    }
}

/** @ghidraAddress 0x126b78 */
void LimelightResultLayer::EmitTexturedPart(unsigned long nSlot,
                                            const S_VECTOR2 &position,
                                            const S_VECTOR2 &size,
                                            unsigned int nAlpha) {
    if (nSlot >= kSpriteSlotCount || m_apSprites[nSlot] == nullptr) {
        return;
    }
    ne::C_TEXTURE *pTexture = m_apSprites[nSlot]->GetBoundTexture();
    if (pTexture == nullptr) {
        return;
    }
    // The whole used image mapped within its power-of-two allocation.
    const S_VECTOR2 uvSize{static_cast<float>(pTexture->GetImageWidth()) /
                               static_cast<float>(pTexture->GetAllocWidth()),
                           static_cast<float>(pTexture->GetImageHeight()) /
                               static_cast<float>(pTexture->GetAllocHeight())};
    AppendSpriteToSlot(position,
                       S_VECTOR2{0.0f, 0.0f},
                       size,
                       S_VECTOR2{0.0f, 0.0f},
                       uvSize,
                       0.0f,
                       S_VECTOR2{1.0f, 1.0f},
                       static_cast<unsigned int>(nSlot),
                       0xff,
                       nAlpha);
}

/** @ghidraAddress 0x126c34 */
void LimelightResultLayer::EmitAutoUvPart(unsigned long nSlot,
                                          const S_VECTOR2 &position,
                                          unsigned int nBaseAlpha) {
    if (nSlot >= kSpriteSlotCount || m_apSprites[nSlot] == nullptr) {
        return;
    }
    ne::C_TEXTURE *pTexture = m_apSprites[nSlot]->GetBoundTexture();
    if (pTexture == nullptr) {
        return;
    }
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flScale = pTexture->GetScale();
    // The pixel size is the used image over its scale; the UV rectangle is the used fraction of the
    // power-of-two allocation.
    const S_VECTOR2 size{flImageWidth / flScale, flImageHeight / flScale};
    const S_VECTOR2 uvSize{flImageWidth / static_cast<float>(pTexture->GetAllocWidth()),
                           flImageHeight / static_cast<float>(pTexture->GetAllocHeight())};
    const auto nAlpha = static_cast<unsigned int>(static_cast<float>(nBaseAlpha) * m_flBaseScale);
    AppendSpriteToSlot(position,
                       S_VECTOR2{0.0f, 0.0f},
                       size,
                       S_VECTOR2{0.0f, 0.0f},
                       uvSize,
                       0.0f,
                       S_VECTOR2{1.0f, 1.0f},
                       static_cast<unsigned int>(nSlot),
                       static_cast<unsigned int>(m_nDefaultAlpha),
                       nAlpha);
}

/** @ghidraAddress 0x126cf8 */
void LimelightResultLayer::RenderNumber(float flSpacing,
                                        int nValue,
                                        int nMaxDigits,
                                        const S_VECTOR2 &position,
                                        unsigned int nBasePartId,
                                        bool bPaired,
                                        bool bPadZeros,
                                        unsigned int nAlpha) {
    // Split the value into up to nMaxDigits decimal digits (least-significant first), tracking the
    // index of the most-significant non-zero digit.
    int aDigits[kNumberMaxDigits] = {};
    int nMostSignificant = 0;
    for (int i = 0; i < nMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nMostSignificant = i;
        }
        nValue /= 10;
    }
    // An all-zero value still shows one digit when the show-zero flag is set.
    if (nMostSignificant == 0 && bPaired) {
        nMostSignificant = 1;
    }

    S_VECTOR2 drawPos{position.x, position.y};
    float flY = position.y;
    for (int i = 0; i <= nMostSignificant; ++i) {
        const float flColumnX = drawPos.x;
        const int nDigit = aDigits[i];
        unsigned int nPartId = nDigit + nBasePartId;

        // The score columns comma-shift their first glyph and raise their second.
        if (nBasePartId == kScoreColumnPartB || nBasePartId == kScoreColumnPartA) {
            if (i == 0 && bPaired) {
                nPartId = nBasePartId + 0xb + nDigit;
            } else if (i == 1 && bPaired) {
                flY -= 4.0f;
                drawPos.y = flY;
            }
        }
        // The rating column's first glyph (when paired) uses the comma-shifted bank.
        const bool bFirstPaired = (i == 0) && bPaired;
        if (nBasePartId == kRatingColumnPart && bFirstPaired) {
            nPartId = nBasePartId + 0xb + nDigit;
        }

        const PartsDataRecord *pRecord = GetPartsData(nPartId);
        drawPos.x = flColumnX - pRecord->flWidth;
        // Micro-nudge a trailing '1' to keep decimal columns aligned across the glyph banks.
        if (i == nMaxDigits - 1 && nDigit == 1) {
            if (nBasePartId < kScoreColumnPartA) {
                if (nBasePartId == kNudgeBankPlus4A || nBasePartId == kNudgeBankPlus4B) {
                    drawPos.x += 4.0f;
                } else if (nBasePartId == kDigitZeroPart) {
                    drawPos.x += 2.0f;
                }
            } else if (nBasePartId == kScoreColumnPartA || nBasePartId == kScoreColumnPartB) {
                drawPos.x += 6.0f;
            } else if (nBasePartId == kRatingColumnPart) {
                drawPos.x += 4.0f;
            }
        }

        float flNextX = drawPos.x;
        EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nPartId, drawPos, nAlpha, 0);
        flNextX -= flSpacing;
        // A paired column draws a second glyph ten ids up from the base.
        if (bFirstPaired) {
            drawPos.x = flNextX;
            const PartsDataRecord *pPaired = GetPartsData(nBasePartId + 10);
            flNextX -= pPaired->flWidth;
            if (nBasePartId == kRatingColumnPart) {
                flY -= 2.0f;
                drawPos.y = flY;
            }
            drawPos.x = flNextX;
            EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nBasePartId + 10, drawPos, nAlpha, 0);
            flNextX -= flSpacing;
        }
        drawPos.x = flNextX;
    }

    // Pad the remaining leading positions with dimmed grey zeros.
    if (bPadZeros && nMostSignificant + 1 < nMaxDigits) {
        const auto nDimAlpha =
            static_cast<unsigned int>(static_cast<float>(nAlpha) * kPadZeroDimFactor);
        for (int nRemaining = (nMaxDigits - 1) - nMostSignificant; nRemaining != 0; --nRemaining) {
            const PartsDataRecord *pRecord = GetPartsData(nBasePartId);
            drawPos.x -= pRecord->flWidth;
            EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nBasePartId, drawPos, nDimAlpha, 0);
            drawPos.x -= flSpacing;
        }
    }
}

namespace {

// The part id of the decimal-point glyph inserted by RenderPercentValue. The minimum drawn digit
// count this function also needs is kPercentMinDigits, declared with the rest of the percent-value
// layout constants above.
constexpr unsigned int kPointPart = 0x73;

} // namespace

/** @ghidraAddress 0x1274b0 */
void LimelightResultLayer::RenderPercentValue(int nValue,
                                              const S_VECTOR2 &position,
                                              unsigned int nAlpha) {
    // Split into up to four digits, tracking the significant count; at least two digits are drawn.
    int aDigits[kMaxDigits] = {};
    int nSignificant = 0;
    for (int i = 0; i < kMaxDigits; ++i) {
        aDigits[i] = nValue % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nValue /= 10;
    }
    if (nSignificant < kPercentMinDigits) {
        nSignificant = kPercentMinDigits;
    }

    float flX = position.x;
    for (int i = 0; i < nSignificant; ++i) {
        const unsigned int nPart = kDigitZeroPart + aDigits[i];
        const float flGlyphWidth = GetPartsData(nPart)->flWidth;
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       nPart,
                       S_VECTOR2{flX - flGlyphWidth, position.y},
                       nAlpha,
                       0);
        flX -= flGlyphWidth;
        // Insert the decimal point after the ones digit.
        if (i == 0) {
            const float flPointWidth = GetPartsData(kPointPart)->flWidth;
            EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kPartsSlot,
                           kPointPart,
                           S_VECTOR2{flX - flPointWidth, position.y},
                           nAlpha,
                           0);
            flX -= flPointWidth;
        }
    }
}

namespace {

// The part id of the slash glyph drawn between a fraction's denominator and numerator.
constexpr unsigned int kSlashPart = 0x74;

} // namespace

/** @ghidraAddress 0x1271f4 */
void LimelightResultLayer::RenderFraction(int nNumerator,
                                          int nDenominator,
                                          const S_VECTOR2 &position,
                                          unsigned int nAlpha) {
    // Split the numerator and denominator into up to four digits each, tracking their significant
    // counts (each at least one).
    int aNumerator[kMaxDigits] = {};
    int nNumeratorDigits = 0;
    for (int i = 0; i < kMaxDigits; ++i) {
        aNumerator[i] = nNumerator % 10;
        if (aNumerator[i] != 0) {
            nNumeratorDigits = i + 1;
        }
        nNumerator /= 10;
    }
    if (nNumeratorDigits == 0) {
        nNumeratorDigits = 1;
    }

    int aDenominator[kMaxDigits] = {};
    int nDenominatorDigits = 0;
    for (int i = 0; i < kMaxDigits; ++i) {
        aDenominator[i] = nDenominator % 10;
        if (aDenominator[i] != 0) {
            nDenominatorDigits = i + 1;
        }
        nDenominator /= 10;
    }
    if (nDenominatorDigits == 0) {
        nDenominatorDigits = 1;
    }

    // The digits and slash advance by the uniform zero-glyph width; the run is centred about the
    // position, with the slash and a one-pixel pad accounted for.
    const float flAdvance = GetPartsData(kDigitZeroPart)->flWidth;
    float flX = position.x + (static_cast<float>(static_cast<int>(nDenominatorDigits * flAdvance) +
                                                 static_cast<int>(nNumeratorDigits * flAdvance)) +
                              flAdvance + 2.0f) *
                                 0.5f;

    for (int i = 0; i < nDenominatorDigits; ++i) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       aDenominator[i] + kDigitZeroPart,
                       S_VECTOR2{flX - flAdvance, position.y},
                       nAlpha,
                       0);
        flX -= flAdvance;
    }

    flX -= flAdvance + 1.0f;
    EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, kSlashPart, S_VECTOR2{flX, position.y}, nAlpha, 0);
    flX -= 1.0f;

    for (int i = 0; i < nNumeratorDigits; ++i) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       aNumerator[i] + kDigitZeroPart,
                       S_VECTOR2{flX - flAdvance, position.y},
                       nAlpha,
                       0);
        flX -= flAdvance;
    }
}

namespace {

// The rating glyph bank's '0' part id, the rating decimal-point part id, and the per-glyph
// horizontal gap the rating value advances by beyond each glyph's width.
constexpr unsigned int kRatingDigitZeroPart = 0xf1;
constexpr unsigned int kRatingPointPart = 0xfb;
constexpr float kRatingGlyphGap = 4.0f;
// The number of digits the scaled rating value is split into, and the minimum drawn.
constexpr int kRatingDigits = 3;
constexpr int kRatingMinDigits = 2;
// The one-decimal scale applied to the rating value before it is split into digits.
constexpr float kRatingScale = 10.0f;

} // namespace

/** @ghidraAddress 0x127680 */
void LimelightResultLayer::RenderRatingValue(float flValue,
                                             const S_VECTOR2 &position,
                                             unsigned int nAlpha) {
    // Scale to one decimal place and split into up to three digits (least-significant first).
    int aDigits[kRatingDigits] = {};
    int nSignificant = 0;
    int nScaled = static_cast<int>(flValue * kRatingScale);
    for (int i = 0; i < kRatingDigits; ++i) {
        aDigits[i] = nScaled % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nScaled /= 10;
    }
    const int nDrawn = nSignificant > kRatingMinDigits ? nSignificant : kRatingMinDigits;

    float flX = position.x;
    int nDigit = 0;
    while (true) {
        // The fractional digit past the integer part is drawn at half alpha.
        if (nDigit == nDrawn) {
            nAlpha = static_cast<unsigned int>(static_cast<float>(nAlpha & 0xff) * 0.5f);
        }
        const int nValue = aDigits[nDigit];
        const PartsDataRecord *pRecord = GetPartsData(nValue + kRatingDigitZeroPart);
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       nValue + kRatingDigitZeroPart,
                       S_VECTOR2{flX - pRecord->flWidth, position.y - pRecord->flHeight},
                       nAlpha & 0xff,
                       0);
        flX -= pRecord->flWidth;
        if (nDigit == 0) {
            // Insert the decimal point after the ones digit, using its own advance and offset.
            const PartsDataRecord *pPoint = GetPartsData(kRatingPointPart);
            EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kPartsSlot,
                           kRatingPointPart,
                           S_VECTOR2{flX - pPoint->flWidth, position.y - pPoint->flHeight},
                           nAlpha & 0xff,
                           0);
            nDigit = 1;
        } else {
            ++nDigit;
            if (nDigit == kRatingDigits) {
                return;
            }
        }
        flX -= kRatingGlyphGap;
    }
}

namespace {

// The Limelight total-score digit layout: the ones-place and higher-place glyph banks, the
// separator glyph drawn beside the ones digit, the number of digit places, the minimum drawn, and
// the gap the cursor steps by between places.
constexpr unsigned int kPadTotalScoreOnesBank = 0xe1;
constexpr unsigned int kPadTotalScoreHighBank = 0xd7;
constexpr unsigned int kPadTotalScoreSeparatorPart = 0xeb;
constexpr int kPadTotalScoreDigits = 7;
constexpr int kPadTotalScoreMinDigits = 2;
constexpr float kPadTotalScoreDigitGap = 2.0f;
constexpr float kPadTotalScoreDimFactor = 0.5f;

} // namespace

/** @ghidraAddress 0x1278a0 */
void LimelightResultLayer::RenderLimelightTotalScore(const S_VECTOR2 *pPosition,
                                                     unsigned int nAlpha) {
    // The total is the sum of the five result-bonus values, scaled to tenths.
    const int nTotal = static_cast<int>((m_flExperienceBonus + m_flClearBonus + m_flMissBonus +
                                         m_flRankBonus + m_flFirstPlayBonus) *
                                        kTotalScoreTenthsScale);

    // Split into seven places (ones first), tracking the significant count.
    int aDigits[kPadTotalScoreDigits] = {};
    int nSignificant = 0;
    int nRemaining = nTotal;
    for (int i = 0; i < kPadTotalScoreDigits; ++i) {
        aDigits[i] = nRemaining % 10;
        if (aDigits[i] != 0) {
            nSignificant = i + 1;
        }
        nRemaining /= 10;
    }
    const int nDrawn =
        nSignificant < kPadTotalScoreMinDigits ? kPadTotalScoreMinDigits : nSignificant;

    float flX = pPosition->x;
    int nDigit = 0;
    while (true) {
        // Leading places beyond the significant digits draw at half alpha.
        if (nDigit == nDrawn) {
            nAlpha = static_cast<unsigned int>(static_cast<float>(nAlpha & 0xff) *
                                               kPadTotalScoreDimFactor);
        }
        const unsigned int nBank = nDigit == 0 ? kPadTotalScoreOnesBank : kPadTotalScoreHighBank;
        const unsigned int nPart = static_cast<unsigned int>(aDigits[nDigit]) + nBank;
        const PartsDataRecord *pRecord = GetPartsData(nPart);
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       nPart,
                       S_VECTOR2{flX - pRecord->flWidth, pPosition->y - pRecord->flHeight},
                       nAlpha & 0xff,
                       0);
        flX -= pRecord->flWidth;
        if (nDigit == 0) {
            // The separator sits beside the ones digit; the cursor does not step by its width, only
            // by the between-place gap.
            const PartsDataRecord *pSeparator = GetPartsData(kPadTotalScoreSeparatorPart);
            EmitPartSprite(
                0.0f,
                1.0f,
                1.0f,
                kPartsSlot,
                kPadTotalScoreSeparatorPart,
                S_VECTOR2{flX - pSeparator->flWidth, pPosition->y - pSeparator->flHeight},
                nAlpha & 0xff,
                0);
            flX -= kPadTotalScoreDigitGap;
            nDigit = 1;
        } else {
            ++nDigit;
            if (nDigit == kPadTotalScoreDigits) {
                return;
            }
        }
        flX -= kPadTotalScoreDigitGap;
    }
}

namespace {

// The time threshold, in frame-delta units, past which the bonus voice cue fires.
constexpr float kBonusCueThreshold = 3300.0f;
// The themed voice identifier played for the result bonus cue.
constexpr int kBonusCueVoiceId = 7;

} // namespace

/** @ghidraAddress 0x1240a8 */
void LimelightResultLayer::UpdateBonusSoundCueTimer(float flDeltaTime) {
    if (!m_bBonusCueArmed) {
        return;
    }
    m_flBonusCueTimer += flDeltaTime;
    if (m_flBonusCueTimer > kBonusCueThreshold) {
        m_bBonusCueArmed = false;
        SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kBonusCueVoiceId);
    }
}

/** @ghidraAddress 0x123da4 */
void LimelightResultLayer::ResetThemeSelectState() {
    // Clear the five result-bonus display values (the binary bulk-zeroes the 0x150..0x164 span).
    m_flExperienceBonus = 0.0f;
    m_flClearBonus = 0.0f;
    m_flMissBonus = 0.0f;
    m_flRankBonus = 0.0f;
    m_flFirstPlayBonus = 0.0f;
    RefreshThema();
}

/** @ghidraAddress 0x123f60 */
void LimelightResultLayer::SetupOpenTweenPhone(float flBaseTime) {
    // Every channel eases from its current shown value up to one.
    constexpr float kShown = 1.0f;
    // The later channels' fixed durations and the elapsed-time stagger offsets that cascade them in
    // (the stagger constants are at @ghidraAddress 0x2eedcc = 300 and 0x307a38 = 900).
    constexpr float kDuration200 = 200.0f;
    constexpr float kDuration300 = 300.0f;
    constexpr float kStagger300 = 300.0f;
    constexpr float kStagger900 = 900.0f;

    // Channel 0: the base channel, its duration the caller's base time; snaps to shown when the base
    // time is non-positive.
    ResultBonusAnimChannel &ch0 = m_aBonusAnimChannels[0];
    ch0.flStart = ch0.flCurrent;
    ch0.flTarget = kShown;
    ch0.flDuration = flBaseTime;
    ch0.flElapsed = 0.0f;
    ch0.flReserved = 0.0f;
    if (flBaseTime <= 0.0f) {
        ch0.flCurrent = kShown;
    }

    // Channel 2: a 200-unit fade whose elapsed time starts at the base time.
    ResultBonusAnimChannel &ch2 = m_aBonusAnimChannels[2];
    ch2.flStart = ch2.flCurrent;
    ch2.flTarget = kShown;
    ch2.flDuration = kDuration200;
    ch2.flElapsed = flBaseTime;
    ch2.flReserved = 0.0f;

    // Channel 1: a 300-unit fade staggered 300 units after the base time.
    ResultBonusAnimChannel &ch1 = m_aBonusAnimChannels[1];
    ch1.flStart = ch1.flCurrent;
    ch1.flTarget = kShown;
    ch1.flDuration = kDuration300;
    ch1.flElapsed = flBaseTime + kStagger300;
    ch1.flReserved = 0.0f;

    // Channel 4: a 200-unit fade staggered 900 units after the base time.
    ResultBonusAnimChannel &ch4 = m_aBonusAnimChannels[4];
    ch4.flStart = ch4.flCurrent;
    ch4.flTarget = kShown;
    ch4.flDuration = kDuration200;
    ch4.flElapsed = flBaseTime + kStagger900;
    ch4.flReserved = 0.0f;

    // Channel 3: a 300-unit fade staggered 900 units after the base time.
    ResultBonusAnimChannel &ch3 = m_aBonusAnimChannels[3];
    ch3.flStart = ch3.flCurrent;
    ch3.flTarget = kShown;
    ch3.flDuration = kDuration300;
    ch3.flElapsed = flBaseTime + kStagger900;
    ch3.flReserved = 0.0f;
}

/** @ghidraAddress 0x124000 */
void LimelightResultLayer::ResetResultBonusAnimations(float flStartTime) {
    // Each channel eases from its current shown value toward zero over the start time; a non-positive
    // start time snaps the target to zero immediately.
    for (ResultBonusAnimChannel &channel : m_aBonusAnimChannels) {
        channel.flStart = channel.flCurrent;
        channel.flTarget = 0.0f;
        channel.flDuration = flStartTime;
        channel.flElapsed = 0.0f;
        channel.flReserved = 0.0f;
        if (flStartTime <= 0.0f) {
            channel.flCurrent = 0.0f;
        }
    }
    m_bBonusCueArmed = false;
}

namespace {
// The overall pressed state published each frame while any touch is active, on release, or idle.
constexpr unsigned short kPressedActive = 1;
constexpr unsigned short kPressedReleased = 0x100;
constexpr unsigned short kPressedNone = 0;

// Whether a touch point lies inside a by-state anchor rectangle.
bool IsTouchInsideRect(float flX, float flY, const PhoneLayoutRect &rect) {
    return rect.flX <= flX && flX <= rect.flX + rect.flWidth && rect.flY <= flY &&
           flY <= rect.flY + rect.flHeight;
}
} // namespace

/** @ghidraAddress 0x12434c */
void LimelightResultLayer::UpdatePhonePartTouchStates() {
    for (int nButton = 0; nButton < kButtonCount; ++nButton) {
        ResultButtonRecord &button = m_aButtons[nButton];

        // First-use initialisation: mark the button unclaimed and clear its flags.
        if (!button.bInitialised) {
            button.nTouchId = kNoTouchId;
            button.bDown = false;
            button.bTapEdge = false;
            button.bInitialised = false;
        }

        TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
        if (button.nTouchId == kNoTouchId) {
            // Unclaimed: scan the active touches for one pressing inside the button's rectangle.
            for (int i = 0; i < pTouchManager->GetActiveTouchCount(); ++i) {
                TouchPoint *pTouch = pTouchManager->GetActiveTouch(i);
                if (!pTouch->bIsNew) {
                    continue;
                }
                PhoneLayoutRect rect{};
                getPositionByState_Phone(nButton, &rect);
                if (IsTouchInsideRect(static_cast<float>(pTouch->nCurrentX),
                                      static_cast<float>(pTouch->nCurrentY),
                                      rect)) {
                    button.nTouchId = pTouch->nId;
                    button.bDown = true;
                    break;
                }
            }
        } else {
            // Claimed: track the touch until it is released, latching a tap-edge on release inside.
            TouchPoint *pTouch = pTouchManager->FindTouchById(button.nTouchId);
            if (pTouch == nullptr) {
                button.nTouchId = kNoTouchId;
                button.bDown = false;
            } else {
                PhoneLayoutRect rect{};
                getPositionByState_Phone(nButton, &rect);
                const bool bInside = IsTouchInsideRect(static_cast<float>(pTouch->nCurrentX),
                                                       static_cast<float>(pTouch->nCurrentY),
                                                       rect);
                button.bDown = bInside;
                if (pTouch->bEnded) {
                    button.nTouchId = kNoTouchId;
                    if (bInside) {
                        // The click latch: pressed byte cleared, tap-edge byte set (flags = 0x100).
                        button.bDown = false;
                        button.bTapEdge = true;
                    }
                }
            }
        }
    }

    // Publish the overall pressed state: active while any touch exists, the just-released latch on
    // the frame the last touch ends, otherwise none.
    TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
    if (pTouchManager->GetActiveTouchCount() > 0) {
        m_nPressedState = kPressedActive;
    } else if (pTouchManager->GetActiveTouchCount() == 0 && m_nPressedState != 0) {
        m_nPressedState = kPressedReleased;
    } else {
        m_nPressedState = kPressedNone;
    }
}

namespace {
// The fully-opaque alpha level the panel-shown gate compares against.
constexpr int kFullyOpaqueAlpha = 255;
// The panel/effect alpha channels the interactivity gate reads.
constexpr int kPanelAlphaChannel = 0;
constexpr int kEffectAlphaChannel = 3;
// The result-panel gesture button indices: the panel gate, the two swipe buttons, and the share
// button.
constexpr int kButtonPanel = 0;
constexpr int kButtonSwipeRight = 1;
constexpr int kButtonSwipeLeft = 2;
constexpr int kButtonShare = 3;
// The side-slider drag threshold, in pixels, past the touch's start X in either direction.
constexpr float kSliderDragThreshold = 30.0f;
// The slider's two settle-target directions.
constexpr float kSliderDirectionRight = 1.0f;
constexpr float kSliderDirectionLeft = -1.0f;
// The themed sound effect the slider toggle fires.
constexpr int kSliderToggleSoundEffect = 7;
// The value the toggle target compares against.
constexpr int kToggleOn = 1;
} // namespace

/** @ghidraAddress 0x1240ec */
void LimelightResultLayer::UpdatePhoneTouchAndShare() {
    // The result panel is interactive only once its reveal is complete and the screen fade is gone.
    const int nPanelAlpha =
        static_cast<int>(m_aBonusAnimChannels[kPanelAlphaChannel].flCurrent * kFullyOpaqueAlpha);
    const float flChannelC = m_aBonusAnimChannels[kEffectAlphaChannel].flCurrent;
    const float flFadeAlpha = FadeOverlayLayer::shared()->GetCurrentAlpha();

    UpdatePhonePartTouchStates();

    m_aButtons[kButtonPanel].bInitialised = nPanelAlpha == kFullyOpaqueAlpha && flFadeAlpha == 0.0f;
    if (flFadeAlpha != 0.0f ||
        static_cast<int>(flChannelC * static_cast<float>(nPanelAlpha)) != kFullyOpaqueAlpha) {
        // Not fully shown: disable the swipe buttons, and the share button when Twitter is available.
        m_aButtons[kButtonSwipeRight].bInitialised = false;
        m_aButtons[kButtonSwipeLeft].bInitialised = false;
        if (m_bTwitterAvailable) {
            m_aButtons[kButtonShare].bInitialised = false;
        }
        return;
    }

    // Fully shown: enable the swipe buttons on an iPad and the share button when Twitter is available.
    if (IsPad()) {
        m_aButtons[kButtonSwipeRight].bInitialised = true;
        m_aButtons[kButtonSwipeLeft].bInitialised = true;
    }
    if (m_bTwitterAvailable) {
        m_aButtons[kButtonShare].bInitialised = true;
    }

    // Track a horizontal swipe over the centre box: claim a fresh touch inside it, then release it
    // as a left or right swipe once it moves past the drag threshold from its start X. The slider's
    // tracked touch id reuses the current-step slot.
    TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
    if (m_nCurrentStep == kNoStep) {
        for (int nIndex = 0; nIndex < pTouchManager->GetActiveTouchCount(); ++nIndex) {
            TouchPoint *pTouch = pTouchManager->GetActiveTouch(nIndex);
            if (!pTouch->bIsNew) {
                continue;
            }
            const float flX = static_cast<float>(pTouch->nCurrentX);
            const float flY = static_cast<float>(pTouch->nCurrentY);
            PhoneLayoutRect box{};
            getCenterPosition_Phone(&box);
            if (IsTouchInsideRect(flX, flY, box)) {
                m_nCurrentStep = pTouch->nId;
                m_flSliderStartX = flX;
                break;
            }
        }
    } else {
        TouchPoint *pTouch = pTouchManager->FindTouchById(m_nCurrentStep);
        if (pTouch == nullptr) {
            m_nCurrentStep = kNoStep;
        } else {
            const float flX = static_cast<float>(pTouch->nCurrentX);
            if (flX < m_flSliderStartX - kSliderDragThreshold) {
                m_aButtons[kButtonSwipeLeft].bTapEdge = true;
                m_nCurrentStep = kNoStep;
            } else if (flX > m_flSliderStartX + kSliderDragThreshold) {
                m_aButtons[kButtonSwipeRight].bTapEdge = true;
                m_nCurrentStep = kNoStep;
            }
            // Within the drag deadzone the touch keeps tracking (its id is retained).
        }
    }

    // On a swipe in single-player, toggle the slider value and fire the toggle sound.
    if ((GameSystem::GetGameSystem()->GetGameType() | 2) == 2) {
        if (!m_aButtons[kButtonSwipeRight].bTapEdge && !m_aButtons[kButtonSwipeLeft].bTapEdge) {
            m_bSliderSwiped = false;
        } else {
            m_flSlideTimer = m_aButtons[kButtonSwipeRight].bTapEdge ? kSliderDirectionRight :
                                                                      kSliderDirectionLeft;
            m_bSliderSwiped = true;
            m_aButtons[kButtonSwipeRight].bTapEdge = false;
            m_aButtons[kButtonSwipeLeft].bTapEdge = false;
            m_nActive = m_nActive != kToggleOn; // The binary reuses this slot as the slider toggle.
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSliderToggleSoundEffect);
        }
    }

    // On the share gesture, consume the edge and post the result to Twitter.
    if (m_bTwitterAvailable && m_aButtons[kButtonShare].bTapEdge) {
        m_aButtons[kButtonShare].bTapEdge = false;
        PostResultToTwitterBlack();
    }
}

namespace {

// The unit-interval-to-byte alpha scale (@ghidraAddress 0x2eed00).
constexpr float kAlphaScale = 255.0f;
// The clear-rate threshold separating the cleared and failed stamps (@ghidraAddress 0x2fd008).
constexpr float kClearRateThreshold = 0.7f;
// The clear rate is shown as tenths of a percent (@ghidraAddress 0x2f8540).
constexpr float kRateTenthsOfPercentScale = 1000.0f;
// The pixel width a full score gauge bar scales to (@ghidraAddress 0x302d60), and the width a full
// judgement-count bar scales to (@ghidraAddress 0x302d64).
constexpr float kScoreGaugeFullWidth = 160.0f;
constexpr float kJudgeGaugeFullWidth = 138.0f;
// The horizontal travel, in pixels, the two result pages slide by as they cross-fade.
constexpr float kPageSlideDistance = 20.0f;

// The instancer slots the iPad path draws into: the full-screen background, the music jacket, and
// the two character previews. Everything else goes to the shared parts slot.
constexpr unsigned int kBackgroundSlot = 0;
constexpr unsigned long kJacketSlot = 2;
constexpr unsigned long kPreviewLeftSlot = 3;
constexpr unsigned long kPreviewRightSlot = 4;
// The music jacket draws as a square of this pixel size.
constexpr float kJacketSize = 180.0f;

// The alpha channels the Limelight result window reads: the overall window fade, the panel fade,
// and the page fade the two sliding pages share.
constexpr int kChannelWindowFade = 0;
constexpr int kChannelPanelFade = 1;
constexpr int kChannelPageFade = 3;

// The result-window part ids drawn by the iPad path.
constexpr unsigned int kPartBackground = 0x00;
constexpr unsigned int kPartPanelBody = 0x01;
constexpr unsigned int kPartShareButton = 0x02;
constexpr unsigned int kPartPanelFrameFirst = 0x03; // 0x03 through 0x08: three mirrored pairs.
constexpr unsigned int kPartStatsFrameFirst = 0x0c; // 0x0c through 0x11: three mirrored pairs.
constexpr unsigned int kPartVersusMarker = 0x15;
constexpr unsigned int kPartStatsHeaderFirst = 0x16; // 0x16 through 0x18.
constexpr unsigned int kPartStatsFooterFirst = 0x19; // 0x19 through 0x1b.
constexpr unsigned int kPartSideOneGaugeLabelBase = 0x1c;
constexpr unsigned int kPartSideZeroGaugeLabelBase = 0x1e;
constexpr unsigned int kPartJacketFrame = 0x20;
constexpr unsigned int kPartDifficultyBadgeBase = 0x21;
constexpr unsigned int kPartDifficultyLevelBank = 0x25;
constexpr unsigned int kPartScoreBank = 0x35;
constexpr unsigned int kPartScoreAboveTarget = 0x40;
constexpr unsigned int kPartScoreBelowTarget = 0x41;
constexpr unsigned int kPartGaugeBarBase = 0x42;
constexpr unsigned int kPartSideScoreBankBase = 0x44;
// The two sides' score banks sit ten part ids apart, one per play colour.
constexpr unsigned int kPartSideScoreBankStride = 10;
constexpr unsigned int kPartRankBadgeBase = 0x58;
constexpr unsigned int kPartFullComboBadge = 0x5e;
constexpr unsigned int kPartStatsTitle = 0x5f;
constexpr unsigned int kPartStatsSideLabel = 0x60;
constexpr unsigned int kPartStatsDecorABase = 0x61; // Plus the decoration rotation frame.
constexpr unsigned int kPartStatsDecorBBase = 0x65; // Plus the decoration rotation frame.
constexpr unsigned int kPartJustGaugeBase = 0x76;   // Plus the decoration rotation frame.
constexpr unsigned int kPartGreatGauge = 0x76;
constexpr unsigned int kPartGoodGauge = 0x77;
constexpr unsigned int kPartMissGauge = 0x78;
constexpr unsigned int kPartComboGauge = 0x79;
constexpr unsigned int kPartRateGauge = 0x7a;
constexpr unsigned int kPartArPanelMark = 0x7b;
constexpr unsigned int kPartArSideBankBase = 0x7c;
// The AR columns' number banks and marks are also a play-colour pair, 0x16 part ids apart.
constexpr unsigned int kPartArSideBankStride = 0x16;
constexpr unsigned int kPartArSideMarkBase = 0x91;
constexpr unsigned int kPartArTargetBank = 0xa8;
constexpr unsigned int kPartArGradeBadgeBase = 0xc0;
constexpr unsigned int kPartArGradeBadgeMaxTier = 5;
constexpr unsigned int kPartArAheadMark = 0xbd;
constexpr unsigned int kPartArBehindMark = 0xbe;
constexpr unsigned int kPartHeaderTrimA = 0xc6;
constexpr unsigned int kPartHeaderTrimB = 0xc7;
constexpr unsigned int kPartHeaderTrimC = 0xc8;
constexpr unsigned int kPartStatsPageMark = 0xc9;
constexpr unsigned int kPartClearStamp = 0xca;
constexpr unsigned int kPartFailedStamp = 0xcb;
constexpr unsigned int kPartWinnerStamp = 0xcc;
constexpr unsigned int kPartBonusPageMark = 0xcd;
constexpr unsigned int kPartBonusHeaderFirst = 0xce; // 0xce through 0xd0.
constexpr unsigned int kPartBonusFooterFirst = 0xd1; // 0xd1 through 0xd3.
constexpr unsigned int kPartBonusTotalFirst = 0xd4;  // 0xd4 through 0xd6.
constexpr unsigned int kPartBonusRowFirst = 0xec;    // 0xec through 0xef, one per bonus row.
constexpr unsigned int kPartBonusRowMark = 0xf0;
constexpr unsigned int kPartBonusRowRule = 0xfc;
constexpr unsigned int kPartBonusTotalRule = 0xfd;
constexpr unsigned int kPartBonusRowValueMark = 0xfe;

// The winner stamp is placed at a fixed x, one row below the clear/failed stamp.
constexpr float kWinnerStampX = 524.0f;
constexpr float kWinnerStampYOffset = 18.0f;
// The AR number column is nudged left of its anchor.
constexpr float kArNumberNudgeX = -2.0f;

// The play record's trailing field holds the match outcome; this side won.
constexpr int kMatchOutcomeWin = 0;

// The parts-anchor slots the iPad result window positions its elements at. Each name is the sole
// element drawn at that slot; the table itself is filled at load time by
// InitializePhoneResultLayoutTable.
constexpr int kAnchorBackground = 1;
constexpr int kAnchorPanelBody = 2;
constexpr int kAnchorShareButton = 3;
constexpr int kAnchorPanelFrameFirst = 4;  // Six slots, one per panel frame part.
constexpr int kAnchorStatsFrameFirst = 10; // Six slots, one per stats frame part.
constexpr int kAnchorVersusMarkerFirst = 16;
constexpr int kAnchorStatsHeaderFirst = 18; // Three slots.
constexpr int kAnchorStatsFooterFirst = 21; // Three slots.
constexpr int kAnchorJacketFrame = 24;
constexpr int kAnchorJacket = 25;
constexpr int kAnchorPreviewLeft = 26;
constexpr int kAnchorPreviewRight = 27;
constexpr int kAnchorDifficultyBadge = 28;
constexpr int kAnchorDifficultyLevel = 29;
constexpr int kAnchorTargetScore = 31;
constexpr int kAnchorScoreCompareMark = 32;
constexpr int kAnchorScoreDifference = 33;
constexpr int kAnchorSideOneGaugeLabel = 34;
constexpr int kAnchorSideOneGaugeBar = 35;
constexpr int kAnchorSideOneScore = 36;
constexpr int kAnchorSideZeroGaugeLabel = 37;
constexpr int kAnchorSideZeroGaugeBar = 38;
constexpr int kAnchorSideZeroScore = 39;
constexpr int kAnchorClearStamp = 40;
constexpr int kAnchorRankBadge = 41;
constexpr int kAnchorFullComboBadge = 42;
constexpr int kAnchorStatsTitle = 44;
constexpr int kAnchorStatsDecorA = 45;
constexpr int kAnchorStatsDecorB = 46;
constexpr int kAnchorArPanelMarkOne = 81;
constexpr int kAnchorArSideLabelOne = 82;
constexpr int kAnchorHeaderTrimA = 97;
constexpr int kAnchorHeaderTrimB = 98;
constexpr int kAnchorHeaderTrimC = 99;
constexpr int kAnchorPageMark = 100;
constexpr int kAnchorBonusHeaderFirst = 101;   // Three slots.
constexpr int kAnchorBonusFooterFirst = 104;   // Three slots.
constexpr int kAnchorBonusRowFirst = 107;      // Four slots, one per bonus row.
constexpr int kAnchorBonusRowMarkFirst = 111;  // Four slots.
constexpr int kAnchorBonusRowRuleFirst = 115;  // Four slots.
constexpr int kAnchorBonusRowValueFirst = 123; // Four slots, paired with the rows.
constexpr int kAnchorBonusTotalFirst = 127;    // Three slots.
constexpr int kAnchorBonusTotalRule = 130;
constexpr int kAnchorBonusTotalValue = 131;
constexpr int kAnchorBonusTotalScore = 132;

// The four bonus rows draw their value from these anchors, in the binary's order: the clear, miss,
// rank, and first-play bonuses (the rank and miss anchors are swapped relative to the row order).
constexpr int kAnchorBonusValueClear = 119;
constexpr int kAnchorBonusValueMiss = 121;
constexpr int kAnchorBonusValueRank = 120;
constexpr int kAnchorBonusValueFirstPlay = 122;

// The number of frame parts in each mirrored frame run, and the number of bonus rows.
constexpr int kFramePartCount = 6;
constexpr int kBonusRowCount = 4;
constexpr int kStatsHeaderPartCount = 3;

// The per-side statistics rows: side 0's anchors sit this far above side 1's, and the row's columns
// are these offsets from the side's base slot.
constexpr int kStatsSideAnchorStride = 0x11;
constexpr int kStatsAnchorBase = 1;
constexpr int kStatsColumnSideLabel = 0x2e;
constexpr int kStatsColumnSideMark = 0x2f;
constexpr int kStatsColumnFirst = 0x30; // Then alternating value and gauge columns.

// The AR comparison block's anchor slots for one side.
struct ArComparisonAnchors {
    int nSideNumber;
    int nTargetNumber;
    int nCompareMark;
    int nDifference;
    int nGradeBadge;
};

constexpr ArComparisonAnchors kArAnchorsSideOne{84, 85, 86, 87, 88};
constexpr ArComparisonAnchors kArAnchorsSideZero{92, 93, 94, 95, 96};

// The AR panel mark and side label slots for side zero.
constexpr int kAnchorArPanelMarkZero = 89;
constexpr int kAnchorArSideLabelZero = 90;

// Clamps a rate to the unit interval the way the binary does: values above one saturate, and NaN or
// negative values fall to zero.
inline float ClampRateToUnit(float flRate) {
    const float flCapped = flRate > 1.0f ? 1.0f : flRate;
    return flRate >= 0.0f ? flCapped : 0.0f;
}

// The emit helpers below de-inline the shapes the binary repeats verbatim through the two sliding
// pages; each one seeds a fresh position vector from the page offset and adds the element's anchor,
// exactly as the binary's `stp` pair plus AddVector2 does.

// Emits one part at an anchor shifted right by the statistics page's slide offset.
inline void EmitOffsetPart(LimelightResultLayer *pLayer,
                           unsigned int nPartId,
                           int nAnchor,
                           float flOffsetX,
                           unsigned int nAlpha) {
    S_VECTOR2 position{flOffsetX, 0.0f};
    AddVector2(&position, &g_aLimelightPartsAnchorPhone[nAnchor]);
    pLayer->EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nPartId, position, nAlpha, 0);
}

// Emits a run of consecutive parts at consecutive anchors, all on the statistics page.
inline void EmitOffsetPartRun(LimelightResultLayer *pLayer,
                              unsigned int nFirstPart,
                              int nFirstAnchor,
                              int nCount,
                              float flOffsetX,
                              unsigned int nAlpha) {
    for (int i = 0; i < nCount; ++i) {
        EmitOffsetPart(
            pLayer, nFirstPart + static_cast<unsigned int>(i), nFirstAnchor + i, flOffsetX, nAlpha);
    }
}

// Emits one part at an anchor shifted by the bonus page's slide offset.
inline void EmitBonusPart(LimelightResultLayer *pLayer,
                          unsigned int nPartId,
                          int nAnchor,
                          const S_VECTOR2 &offset,
                          unsigned int nAlpha) {
    S_VECTOR2 position = offset;
    AddVector2(&position, &g_aLimelightPartsAnchorPhone[nAnchor]);
    pLayer->EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nPartId, position, nAlpha, 0);
}

// Draws one bonus row's rating value at an anchor shifted by the bonus page's slide offset.
inline void EmitBonusRatingValue(LimelightResultLayer *pLayer,
                                 int nAnchor,
                                 const S_VECTOR2 &offset,
                                 float flValue,
                                 unsigned int nAlpha) {
    S_VECTOR2 position = offset;
    AddVector2(&position, &g_aLimelightPartsAnchorPhone[nAnchor]);
    pLayer->RenderRatingValue(flValue, position, nAlpha);
}

// Emits the frame both sliding pages share: three mirrored part pairs at fixed anchors, plus the
// page's own marker. Neither is shifted by the page offset.
inline void
EmitPageFrame(LimelightResultLayer *pLayer, unsigned int nAlpha, unsigned int nPageMarkPart) {
    for (int i = 0; i < kFramePartCount; ++i) {
        pLayer->EmitPartSprite(0.0f,
                               (i % 2) == 0 ? 1.0f : -1.0f,
                               1.0f,
                               kPartsSlot,
                               kPartStatsFrameFirst + static_cast<unsigned int>(i),
                               g_aLimelightPartsAnchorPhone[kAnchorStatsFrameFirst + i],
                               nAlpha,
                               0);
    }
    pLayer->EmitPartSprite(0.0f,
                           1.0f,
                           1.0f,
                           kPartsSlot,
                           nPageMarkPart,
                           g_aLimelightPartsAnchorPhone[kAnchorPageMark],
                           nAlpha,
                           0);
}

// Draws one side's achievement-rate comparison: the side's rate, the target rate, an ahead or
// behind mark, the signed difference, and the grade badge. The binary emits this block twice, once
// per side, with only the anchors and the play-colour-selected banks differing.
inline void EmitArComparison(LimelightResultLayer *pLayer,
                             const ArComparisonAnchors &anchors,
                             unsigned int nSideNumberBank,
                             unsigned int nSideMarkPart,
                             float flSideRate,
                             float flTargetRate,
                             int nRank,
                             float flOffsetX,
                             unsigned int nAlpha) {
    const int nGradeTier = nRank < static_cast<int>(kPartArGradeBadgeMaxTier) + 1 ?
                               nRank :
                               static_cast<int>(kPartArGradeBadgeMaxTier);
    const int nSideTenths =
        static_cast<int>(ClampRateToUnit(flSideRate) * kRateTenthsOfPercentScale);
    const int nTargetTenths =
        static_cast<int>(ClampRateToUnit(flTargetRate) * kRateTenthsOfPercentScale);

    S_VECTOR2 cursor{flOffsetX, 0.0f};
    AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[anchors.nSideNumber]);
    S_VECTOR2 nudge{kArNumberNudgeX, 0.0f};
    AddVector2(&cursor, &nudge);
    pLayer->RenderNumber(2.0f, nSideTenths, 4, cursor, nSideNumberBank, true, false, nAlpha);

    S_VECTOR2 position{flOffsetX, 0.0f};
    AddVector2(&position, &g_aLimelightPartsAnchorPhone[anchors.nSideNumber]);
    pLayer->EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nSideMarkPart, position, nAlpha, 0);

    cursor = S_VECTOR2{flOffsetX, 0.0f};
    AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[anchors.nTargetNumber]);
    pLayer->RenderNumber(1.0f, nTargetTenths, 4, cursor, kPartArTargetBank, true, false, nAlpha);

    cursor = S_VECTOR2{flOffsetX, 0.0f};
    AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[anchors.nDifference]);
    position = S_VECTOR2{flOffsetX, 0.0f};
    AddVector2(&position, &g_aLimelightPartsAnchorPhone[anchors.nCompareMark]);

    // Behind the target draws the behind mark and the shortfall; at or above it draws the ahead
    // mark and the surplus.
    int nDifference = 0;
    if (ClampRateToUnit(flSideRate) <= ClampRateToUnit(flTargetRate)) {
        pLayer->EmitPartSprite(
            0.0f, 1.0f, 1.0f, kPartsSlot, kPartArBehindMark, position, nAlpha, 0);
        nDifference = nTargetTenths - nSideTenths;
    } else {
        pLayer->EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, kPartArAheadMark, position, nAlpha, 0);
        nDifference = nSideTenths - nTargetTenths;
    }
    pLayer->RenderNumber(1.0f, nDifference, 4, cursor, kPartArTargetBank, true, false, nAlpha);

    const unsigned int nBadge = nRank < 0 ?
                                    kPartArGradeBadgeBase :
                                    static_cast<unsigned int>(nGradeTier) + kPartArGradeBadgeBase;
    position = S_VECTOR2{flOffsetX, 0.0f};
    AddVector2(&position, &g_aLimelightPartsAnchorPhone[anchors.nGradeBadge]);
    pLayer->EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, nBadge, position, nAlpha, 0);
}

} // namespace

/** @ghidraAddress 0x124acc */
void LimelightResultLayer::RenderLimelightResultWindow() {
    const unsigned int nWindowAlpha =
        static_cast<unsigned int>(m_aBonusAnimChannels[kChannelWindowFade].flCurrent * kAlphaScale);
    const float flPanelFade = m_aBonusAnimChannels[kChannelPanelFade].flCurrent;
    const float flPageFade = m_aBonusAnimChannels[kChannelPageFade].flCurrent;
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    ScoreTracker *pTracker = ScoreTracker::shared();
    const unsigned int nPlayColor = static_cast<unsigned int>(pGameSystem->GetPlayColor());

    // Clear every instancer's sprite count before re-emitting this frame.
    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }
    if (nWindowAlpha == 0) {
        return;
    }

    const unsigned int nPanelAlpha =
        static_cast<unsigned int>(flPanelFade * static_cast<float>(nWindowAlpha));
    const unsigned int nPageAlpha =
        static_cast<unsigned int>(flPageFade * static_cast<float>(nWindowAlpha));

    // The window frame and the fixed panel furniture.
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kBackgroundSlot,
                   kPartBackground,
                   g_aLimelightPartsAnchorPhone[kAnchorBackground],
                   nWindowAlpha,
                   0);
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   kPartHeaderTrimA,
                   g_aLimelightPartsAnchorPhone[kAnchorHeaderTrimA],
                   nWindowAlpha,
                   0);
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   kPartHeaderTrimB,
                   g_aLimelightPartsAnchorPhone[kAnchorHeaderTrimB],
                   nWindowAlpha,
                   0);
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   kPartPanelBody,
                   g_aLimelightPartsAnchorPhone[kAnchorPanelBody],
                   nWindowAlpha,
                   m_aButtons[kButtonPanel].bDown);
    if (m_bTwitterAvailable) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       kPartShareButton,
                       g_aLimelightPartsAnchorPhone[kAnchorShareButton],
                       nPageAlpha,
                       m_aButtons[kButtonShare].bDown);
    }
    // The panel frame is three mirrored pairs: the odd part of each pair draws flipped in x.
    for (int i = 0; i < kFramePartCount; ++i) {
        EmitPartSprite(0.0f,
                       (i % 2) == 0 ? 1.0f : -1.0f,
                       1.0f,
                       kPartsSlot,
                       kPartPanelFrameFirst + static_cast<unsigned int>(i),
                       g_aLimelightPartsAnchorPhone[kAnchorPanelFrameFirst + i],
                       nPanelAlpha,
                       0);
    }
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   kPartHeaderTrimC,
                   g_aLimelightPartsAnchorPhone[kAnchorHeaderTrimC],
                   nPanelAlpha,
                   0);
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   kPartJacketFrame,
                   g_aLimelightPartsAnchorPhone[kAnchorJacketFrame],
                   nPanelAlpha,
                   0);
    EmitTexturedPart(kJacketSlot,
                     g_aLimelightPartsAnchorPhone[kAnchorJacket],
                     S_VECTOR2{kJacketSize, kJacketSize},
                     nPanelAlpha);
    EmitAutoUvPart(kPreviewLeftSlot, g_aLimelightPartsAnchorPhone[kAnchorPreviewLeft], nPanelAlpha);
    EmitAutoUvPart(
        kPreviewRightSlot, g_aLimelightPartsAnchorPhone[kAnchorPreviewRight], nPanelAlpha);
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   kPartDifficultyBadgeBase +
                       static_cast<unsigned int>(pGameSystem->GetDifficulty()),
                   g_aLimelightPartsAnchorPhone[kAnchorDifficultyBadge],
                   nPanelAlpha,
                   0);
    RenderNumber(2.0f,
                 pGameSystem->GetDifficultyLevel() + 1,
                 2,
                 g_aLimelightPartsAnchorPhone[kAnchorDifficultyLevel],
                 kPartDifficultyLevelBank,
                 false,
                 false,
                 nPanelAlpha);

    // The target score, and the signed distance this play landed from it.
    const int nTargetScore = pGameSystem->GetTargetScore() < 0 ? 0 : pGameSystem->GetTargetScore();
    int nScoreGap = pTracker->GetPlayRecordCell(1, kCellScore) - nTargetScore;
    RenderNumber(2.0f,
                 nTargetScore,
                 4,
                 g_aLimelightPartsAnchorPhone[kAnchorTargetScore],
                 kPartScoreBank,
                 false,
                 true,
                 nPanelAlpha);
    if (nScoreGap < 0) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       kPartScoreBelowTarget,
                       g_aLimelightPartsAnchorPhone[kAnchorScoreCompareMark],
                       nPanelAlpha,
                       0);
        nScoreGap = -nScoreGap;
    } else {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       kPartScoreAboveTarget,
                       g_aLimelightPartsAnchorPhone[kAnchorScoreCompareMark],
                       nPanelAlpha,
                       0);
    }
    RenderNumber(2.0f,
                 nScoreGap,
                 4,
                 g_aLimelightPartsAnchorPhone[kAnchorScoreDifference],
                 kPartScoreBank,
                 false,
                 true,
                 nPanelAlpha);

    // The two sides' score gauges, each scaled against the higher of the two scores.
    const int nSideOneScore = pTracker->GetPlayRecordCell(1, kCellScore);
    const int nSideZeroScore = pTracker->GetPlayRecordCell(0, kCellScore);
    float flSideOneBar = (nSideZeroScore != 0 || nSideOneScore != 0) ? 1.0f : 0.0f;
    float flSideZeroBar = flSideOneBar;
    if (nSideZeroScore < nSideOneScore) {
        flSideOneBar = 1.0f;
        flSideZeroBar = static_cast<float>(nSideZeroScore) / static_cast<float>(nSideOneScore);
    }
    if (nSideOneScore < nSideZeroScore) {
        flSideZeroBar = 1.0f;
        flSideOneBar = static_cast<float>(nSideOneScore) / static_cast<float>(nSideZeroScore);
    }

    // Side one carries the current play colour; side zero carries the other.
    const unsigned int nSideZeroColor = nPlayColor == 0 ? 1 : 0;
    const unsigned int nSideOneLabel = kPartSideOneGaugeLabelBase + nPlayColor;
    const unsigned int nSideZeroLabel = kPartSideZeroGaugeLabelBase + nSideZeroColor;
    const unsigned int nSideOneBarPart = kPartGaugeBarBase + nPlayColor;
    const unsigned int nSideZeroBarPart = kPartGaugeBarBase + nSideZeroColor;
    const unsigned int nSideOneScoreBank =
        kPartSideScoreBankBase + nPlayColor * kPartSideScoreBankStride;
    const unsigned int nSideZeroScoreBank =
        kPartSideScoreBankBase + nSideZeroColor * kPartSideScoreBankStride;

    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   nSideOneLabel,
                   g_aLimelightPartsAnchorPhone[kAnchorSideOneGaugeLabel],
                   nPanelAlpha,
                   0);
    EmitPartSprite(0.0f,
                   flSideOneBar * kScoreGaugeFullWidth,
                   1.0f,
                   kPartsSlot,
                   nSideOneBarPart,
                   g_aLimelightPartsAnchorPhone[kAnchorSideOneGaugeBar],
                   nPanelAlpha,
                   0);
    RenderNumber(0.0f,
                 nSideOneScore,
                 4,
                 g_aLimelightPartsAnchorPhone[kAnchorSideOneScore],
                 nSideOneScoreBank,
                 false,
                 true,
                 nPanelAlpha);
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   nSideZeroLabel,
                   g_aLimelightPartsAnchorPhone[kAnchorSideZeroGaugeLabel],
                   nPanelAlpha,
                   0);
    EmitPartSprite(0.0f,
                   flSideZeroBar * kScoreGaugeFullWidth,
                   1.0f,
                   kPartsSlot,
                   nSideZeroBarPart,
                   g_aLimelightPartsAnchorPhone[kAnchorSideZeroGaugeBar],
                   nPanelAlpha,
                   0);
    RenderNumber(0.0f,
                 nSideZeroScore,
                 4,
                 g_aLimelightPartsAnchorPhone[kAnchorSideZeroScore],
                 nSideZeroScoreBank,
                 false,
                 true,
                 nPanelAlpha);

    // The cleared or failed stamp, the winner stamp, the grade badge, and the full-combo badge.
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   pTracker->GetPlayRecordRate(1) < kClearRateThreshold ? kPartFailedStamp :
                                                                          kPartClearStamp,
                   g_aLimelightPartsAnchorPhone[kAnchorClearStamp],
                   nPanelAlpha,
                   0);
    if (pTracker->GetPlayRecordField10(1) == kMatchOutcomeWin) {
        EmitPartSprite(
            0.0f,
            1.0f,
            1.0f,
            kPartsSlot,
            kPartWinnerStamp,
            S_VECTOR2{kWinnerStampX,
                      g_aLimelightPartsAnchorPhone[kAnchorClearStamp].y + kWinnerStampYOffset},
            nPanelAlpha,
            0);
    }
    EmitPartSprite(0.0f,
                   1.0f,
                   1.0f,
                   kPartsSlot,
                   kPartRankBadgeBase + static_cast<unsigned int>(pTracker->GetPlayRecordRank(1)),
                   g_aLimelightPartsAnchorPhone[kAnchorRankBadge],
                   nPanelAlpha,
                   0);
    if (pTracker->GetTotalNotes() == pTracker->GetPlayRecordCell(1, kCellMaxCombo)) {
        EmitPartSprite(0.0f,
                       1.0f,
                       1.0f,
                       kPartsSlot,
                       kPartFullComboBadge,
                       g_aLimelightPartsAnchorPhone[kAnchorFullComboBadge],
                       nPanelAlpha,
                       0);
    }

    // The statistics and bonus pages cross-fade as the slide timer runs, each sliding in from its
    // own side. Which page leads depends on the panel's active flag.
    const float flSlide = m_flSlideTimer;
    const float flTransition = std::fabs(flSlide);
    const float flSlideSign = flSlide <= 0.0f ? -kPageSlideDistance : kPageSlideDistance;
    float flStatsOffsetX = 0.0f;
    S_VECTOR2 bonusOffset{0.0f, 0.0f};
    unsigned int nStatsAlpha = 0;
    unsigned int nBonusAlpha = 0;
    if (m_nActive == kToggleOn) {
        nBonusAlpha = static_cast<unsigned int>(static_cast<float>(nPageAlpha) * flTransition);
        nStatsAlpha =
            static_cast<unsigned int>(static_cast<float>(nPageAlpha) * (1.0f - flTransition));
        flStatsOffsetX = flSlide * -kPageSlideDistance;
        bonusOffset.x = (1.0f - flTransition) * flSlideSign;
    } else {
        nBonusAlpha =
            static_cast<unsigned int>(static_cast<float>(nPageAlpha) * (1.0f - flTransition));
        nStatsAlpha = static_cast<unsigned int>(static_cast<float>(nPageAlpha) * flTransition);
        bonusOffset.x = flSlide * -kPageSlideDistance;
        flStatsOffsetX =
            (1.0f - flTransition) * (flSlide > 0.0f ? kPageSlideDistance : -kPageSlideDistance);
    }

    EmitPageFrame(this, nStatsAlpha, kPartStatsPageMark);
    EmitOffsetPartRun(this,
                      kPartStatsHeaderFirst,
                      kAnchorStatsHeaderFirst,
                      kStatsHeaderPartCount,
                      flStatsOffsetX,
                      nStatsAlpha);
    EmitOffsetPart(this, kPartStatsTitle, kAnchorStatsTitle, flStatsOffsetX, nStatsAlpha);
    EmitOffsetPart(this,
                   kPartStatsDecorABase + static_cast<unsigned int>(m_nRotationFrame),
                   kAnchorStatsDecorA,
                   flStatsOffsetX,
                   nStatsAlpha);
    EmitOffsetPart(this,
                   kPartStatsDecorBBase + static_cast<unsigned int>(m_nRotationFrame),
                   kAnchorStatsDecorB,
                   flStatsOffsetX,
                   nStatsAlpha);

    // One statistics row per side: the judgement counts with their proportion gauges, the combo and
    // reflec fractions, the score, and the clear rate.
    for (unsigned int nSide = 0; nSide < static_cast<unsigned int>(ScoreTracker::kSideCount);
         ++nSide) {
        const int nJust = pTracker->GetPlayRecordCell(nSide, kCellJust);
        const int nGreat = pTracker->GetPlayRecordCell(nSide, kCellGreat);
        const int nGood = pTracker->GetPlayRecordCell(nSide, kCellGood);
        const int nMiss = pTracker->GetPlayRecordCell(nSide, kCellMiss);
        const int nJustReflec = pTracker->GetPlayRecordCell(nSide, kCellJustReflec);
        const int nMaxCombo = pTracker->GetPlayRecordCell(nSide, kCellMaxCombo);
        const int nScore = pTracker->GetPlayRecordCell(nSide, kCellScore);
        const int nTotalNotes = pTracker->GetTotalNotes();
        const float flRate = pTracker->GetPlayRecordRate(nSide);
        const float flTotalNotes = static_cast<float>(nTotalNotes);

        // The reflec quota is read from the score slot belonging to this row's play colour.
        const unsigned int nQuotaColor = nSide == 0 ? nPlayColor : (nPlayColor == 0 ? 1u : 0u);
        const int nReflecQuota = nQuotaColor == 0 ? m_nResultScore : m_nResultScoreHi;
        const int nRowBase = kStatsAnchorBase + (nSide == 0 ? kStatsSideAnchorStride : 0);

        EmitOffsetPart(this,
                       kPartStatsSideLabel,
                       nRowBase + kStatsColumnSideLabel,
                       flStatsOffsetX,
                       nStatsAlpha);
        EmitOffsetPart(this,
                       nSide == 1 ? nSideOneLabel : nSideZeroLabel,
                       nRowBase + kStatsColumnSideMark,
                       flStatsOffsetX,
                       nStatsAlpha);

        int nColumn = kStatsColumnFirst;
        const auto EmitValueAndGauge = [&](int nValue, unsigned int nGaugePart, float flFraction) {
            S_VECTOR2 cursor{flStatsOffsetX, 0.0f};
            AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[nRowBase + nColumn]);
            RenderDigits(nValue, cursor, nStatsAlpha);
            ++nColumn;
            cursor = S_VECTOR2{flStatsOffsetX, 0.0f};
            AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[nRowBase + nColumn]);
            EmitPartSprite(0.0f,
                           flFraction * kJudgeGaugeFullWidth,
                           1.0f,
                           kPartsSlot,
                           nGaugePart,
                           cursor,
                           nStatsAlpha,
                           0);
            ++nColumn;
        };

        EmitValueAndGauge(nJust,
                          kPartJustGaugeBase + static_cast<unsigned int>(m_nRotationFrame),
                          static_cast<float>(nJust) / flTotalNotes);
        EmitValueAndGauge(nGreat, kPartGreatGauge, static_cast<float>(nGreat) / flTotalNotes);
        EmitValueAndGauge(nGood, kPartGoodGauge, static_cast<float>(nGood) / flTotalNotes);
        EmitValueAndGauge(nMiss, kPartMissGauge, static_cast<float>(nMiss) / flTotalNotes);

        S_VECTOR2 cursor{flStatsOffsetX, 0.0f};
        AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[nRowBase + nColumn]);
        RenderFraction(nJustReflec, nReflecQuota, cursor, nStatsAlpha);
        ++nColumn;
        cursor = S_VECTOR2{flStatsOffsetX, 0.0f};
        AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[nRowBase + nColumn]);
        EmitPartSprite(0.0f,
                       (static_cast<float>(nJustReflec) / static_cast<float>(nReflecQuota)) *
                           kJudgeGaugeFullWidth,
                       1.0f,
                       kPartsSlot,
                       kPartJustGaugeBase + static_cast<unsigned int>(m_nRotationFrame),
                       cursor,
                       nStatsAlpha,
                       0);
        ++nColumn;

        cursor = S_VECTOR2{flStatsOffsetX, 0.0f};
        AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[nRowBase + nColumn]);
        RenderFraction(nMaxCombo, nTotalNotes, cursor, nStatsAlpha);
        ++nColumn;
        cursor = S_VECTOR2{flStatsOffsetX, 0.0f};
        AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[nRowBase + nColumn]);
        EmitPartSprite(0.0f,
                       (static_cast<float>(nMaxCombo) / flTotalNotes) * kJudgeGaugeFullWidth,
                       1.0f,
                       kPartsSlot,
                       kPartComboGauge,
                       cursor,
                       nStatsAlpha,
                       0);
        ++nColumn;

        cursor = S_VECTOR2{flStatsOffsetX, 0.0f};
        AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[nRowBase + nColumn]);
        RenderDigits(nScore, cursor, nStatsAlpha);
        ++nColumn;
        cursor = S_VECTOR2{flStatsOffsetX, 0.0f};
        AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[nRowBase + nColumn]);
        RenderPercentValue(
            static_cast<int>(flRate * kRateTenthsOfPercentScale), cursor, nStatsAlpha);
        ++nColumn;
        cursor = S_VECTOR2{flStatsOffsetX, 0.0f};
        AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[nRowBase + nColumn]);
        EmitPartSprite(0.0f,
                       flRate * kJudgeGaugeFullWidth,
                       1.0f,
                       kPartsSlot,
                       kPartRateGauge,
                       cursor,
                       nStatsAlpha,
                       0);
    }

    EmitOffsetPartRun(this,
                      kPartStatsFooterFirst,
                      kAnchorStatsFooterFirst,
                      kStatsHeaderPartCount,
                      flStatsOffsetX,
                      nStatsAlpha);
    EmitOffsetPart(this, kPartArPanelMark, kAnchorArPanelMarkOne, flStatsOffsetX, nStatsAlpha);
    EmitOffsetPart(this, nSideOneLabel, kAnchorArSideLabelOne, flStatsOffsetX, nStatsAlpha);
    EmitArComparison(this,
                     kArAnchorsSideOne,
                     kPartArSideBankBase + nPlayColor * kPartArSideBankStride,
                     kPartArSideMarkBase + nPlayColor * kPartArSideBankStride,
                     pTracker->GetPlayRecordRate(1),
                     pGameSystem->GetTargetAR(),
                     pTracker->GetPlayRecordRank(1),
                     flStatsOffsetX,
                     nStatsAlpha);
    EmitOffsetPart(this, nSideZeroLabel, kAnchorArSideLabelZero, flStatsOffsetX, nStatsAlpha);
    EmitOffsetPart(this, kPartArPanelMark, kAnchorArPanelMarkZero, flStatsOffsetX, nStatsAlpha);
    EmitArComparison(this,
                     kArAnchorsSideZero,
                     kPartArSideBankBase + nSideZeroColor * kPartArSideBankStride,
                     kPartArSideMarkBase + nSideZeroColor * kPartArSideBankStride,
                     pTracker->GetPlayRecordRate(0),
                     pGameSystem->GetTargetAR(),
                     pTracker->GetPlayRecordRank(0),
                     flStatsOffsetX,
                     nStatsAlpha);

    // The bonus breakdown page: the same frame, four bonus rows with their rating values, and the
    // grand total.
    EmitPageFrame(this, nBonusAlpha, kPartBonusPageMark);
    for (int i = 0; i < kStatsHeaderPartCount; ++i) {
        EmitBonusPart(this,
                      kPartBonusHeaderFirst + static_cast<unsigned int>(i),
                      kAnchorBonusHeaderFirst + i,
                      bonusOffset,
                      nBonusAlpha);
    }
    for (int i = 0; i < kBonusRowCount; ++i) {
        EmitBonusPart(this,
                      kPartBonusRowFirst + static_cast<unsigned int>(i),
                      kAnchorBonusRowFirst + i,
                      bonusOffset,
                      nBonusAlpha);
        EmitBonusPart(
            this, kPartBonusRowValueMark, kAnchorBonusRowValueFirst + i, bonusOffset, nBonusAlpha);
    }
    for (int i = 0; i < kBonusRowCount; ++i) {
        EmitBonusPart(
            this, kPartBonusRowMark, kAnchorBonusRowMarkFirst + i, bonusOffset, nBonusAlpha);
    }
    for (int i = 0; i < kBonusRowCount; ++i) {
        EmitBonusPart(
            this, kPartBonusRowRule, kAnchorBonusRowRuleFirst + i, bonusOffset, nBonusAlpha);
    }
    EmitBonusRatingValue(this, kAnchorBonusValueClear, bonusOffset, m_flClearBonus, nBonusAlpha);
    EmitBonusRatingValue(this, kAnchorBonusValueMiss, bonusOffset, m_flMissBonus, nBonusAlpha);
    EmitBonusRatingValue(this, kAnchorBonusValueRank, bonusOffset, m_flRankBonus, nBonusAlpha);
    EmitBonusRatingValue(
        this, kAnchorBonusValueFirstPlay, bonusOffset, m_flFirstPlayBonus, nBonusAlpha);
    for (int i = 0; i < kStatsHeaderPartCount; ++i) {
        EmitBonusPart(this,
                      kPartBonusFooterFirst + static_cast<unsigned int>(i),
                      kAnchorBonusFooterFirst + i,
                      bonusOffset,
                      nBonusAlpha);
    }
    EmitBonusPart(this, kPartBonusTotalRule, kAnchorBonusTotalRule, bonusOffset, nBonusAlpha);
    EmitBonusRatingValue(this,
                         kAnchorBonusTotalValue,
                         bonusOffset,
                         m_flClearBonus + m_flMissBonus + m_flRankBonus + m_flFirstPlayBonus,
                         nBonusAlpha);
    for (int i = 0; i < kStatsHeaderPartCount; ++i) {
        EmitBonusPart(this,
                      kPartBonusTotalFirst + static_cast<unsigned int>(i),
                      kAnchorBonusTotalFirst + i,
                      bonusOffset,
                      nBonusAlpha);
    }
    {
        S_VECTOR2 cursor = bonusOffset;
        AddVector2(&cursor, &g_aLimelightPartsAnchorPhone[kAnchorBonusTotalScore]);
        RenderLimelightTotalScore(&cursor, nBonusAlpha);
    }

    // In the versus game types the two page markers draw twice: once opaque over the share fade and
    // once at each page's own alpha.
    if ((pGameSystem->GetGameType() | 2) == 2) {
        for (int i = 0; i < 2; ++i) {
            S_VECTOR2 position{};
            AddVector2(&position, &g_aLimelightPartsAnchorPhone[kAnchorVersusMarkerFirst + i]);
            EmitPartSprite(
                0.0f, 1.0f, 1.0f, kPartsSlot, kPartVersusMarker, position, nPageAlpha, 1);
        }
        S_VECTOR2 position{};
        AddVector2(&position, &g_aLimelightPartsAnchorPhone[kAnchorVersusMarkerFirst]);
        EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, kPartVersusMarker, position, nBonusAlpha, 0);
        position = S_VECTOR2{};
        AddVector2(&position, &g_aLimelightPartsAnchorPhone[kAnchorVersusMarkerFirst + 1]);
        EmitPartSprite(0.0f, 1.0f, 1.0f, kPartsSlot, kPartVersusMarker, position, nStatsAlpha, 0);
    }
}

namespace {

// The phone result window's part ids.
constexpr unsigned int kPhonePartBackground = 0x00;
constexpr unsigned int kPhonePartShareButton = 0x01;
constexpr unsigned int kPhonePartBoxCorner = 0x02;
constexpr unsigned int kPhonePartBoxEdgeH = 0x03;
constexpr unsigned int kPhonePartBoxEdgeV = 0x04;
constexpr unsigned int kPhonePartBoxFill = 0x05;
constexpr unsigned int kPhonePartInnerCorner = 0x06;
constexpr unsigned int kPhonePartInnerEdgeH = 0x07;
constexpr unsigned int kPhonePartInnerEdgeV = 0x08;
constexpr unsigned int kPhonePartInnerFill = 0x09;
constexpr unsigned int kPhonePartBarCap = 0x0a;
constexpr unsigned int kPhonePartBarBody = 0x0b;
constexpr unsigned int kPhonePartSeparatorRule = 0x0c;
constexpr unsigned int kPhonePartSeparatorThick = 0x0d;
constexpr unsigned int kPhonePartJacketFrame = 0x0e;
constexpr unsigned int kPhonePartPreviewFrame = 0x10;
constexpr unsigned int kPhonePartClearLabel = 0x11;
constexpr unsigned int kPhonePartMusicLabel = 0x12;
constexpr unsigned int kPhonePartDifficultyBadgeBase = 0x13;
constexpr unsigned int kPhonePartTargetLabel = 0x0f;
constexpr unsigned int kPhonePartScoreBank = 0x17;
constexpr unsigned int kPhonePartScoreMark = 0x21;
constexpr unsigned int kPhonePartScoreAboveTarget = 0x22;
constexpr unsigned int kPhonePartScoreBelowTarget = 0x23;
constexpr unsigned int kPhonePartResultScoreBank = 0x24;
constexpr unsigned int kPhonePartRankBadgeBase = 0x2e;
constexpr unsigned int kPhonePartFullComboBadge = 0x34;
constexpr unsigned int kPhonePartSideOneLabelBase = 0x35;
constexpr unsigned int kPhonePartSideZeroLabelBase = 0x37;
constexpr unsigned int kPhonePartStatsDecorABase = 0x47; // Plus the decoration rotation frame.
constexpr unsigned int kPhonePartStatsHeaderB = 0x4b;
constexpr unsigned int kPhonePartStatsHeaderC = 0x4c;
constexpr unsigned int kPhonePartStatsHeaderD = 0x4d;
constexpr unsigned int kPhonePartStatsDecorBBase = 0x4e; // Plus the decoration rotation frame.
constexpr unsigned int kPhonePartStatsHeaderE = 0x52;
constexpr unsigned int kPhonePartStatsHeaderF = 0x53;
constexpr unsigned int kPhonePartStatsHeaderG = 0x54;
constexpr unsigned int kPhonePartSideRailTop = 0x55;
constexpr unsigned int kPhonePartSideRailMark = 0x56;
constexpr unsigned int kPhonePartHeaderBar = 0x57;
constexpr unsigned int kPhonePartHeaderBarCap = 0x58;
constexpr unsigned int kPhonePartFooterCap = 0x59;
constexpr unsigned int kPhonePartFooterBody = 0x5a;
constexpr unsigned int kPhonePartFooterMark = 0x5b;
constexpr unsigned int kPhonePartClearStamp = 0x5c;
constexpr unsigned int kPhonePartFailedStamp = 0x5d;
constexpr unsigned int kPhonePartWinnerStamp = 0x5e;
constexpr unsigned int kPhonePartStatsTitle = 0x5f;
constexpr unsigned int kPhonePartPageDot = 0x60;
constexpr unsigned int kPhonePartBonusTitle = 0x61;
constexpr unsigned int kPhonePartBonusHeader = 0x62;
constexpr unsigned int kPhonePartBonusTotalMark = 0x63;
constexpr unsigned int kPhonePartBonusFooterA = 0x64;
constexpr unsigned int kPhonePartBonusFooterB = 0x65;
constexpr unsigned int kPhonePartBonusFooterC = 0x66;
constexpr unsigned int kPhonePartBonusRowFirst = 0x7c; // 0x7c through 0x7f, one per bonus row.
constexpr unsigned int kPhonePartBonusRowMark = 0x80;
constexpr unsigned int kPhonePartBonusRowRule = 0x8b;
constexpr unsigned int kPhonePartBonusTotalRule = 0x8c;

// The phone anchor-position indices the window resolves through getPosition_Phone.
constexpr int kPhoneAnchorBackground = 0;
constexpr int kPhoneAnchorOuterBoxTopLeft = 1;
constexpr int kPhoneAnchorOuterBoxBottomRight = 2;
constexpr int kPhoneAnchorInnerBoxTopLeft = 3;
constexpr int kPhoneAnchorInnerBoxBottomRight = 4;
constexpr int kPhoneAnchorPreviewLeft = 5;
constexpr int kPhoneAnchorPreviewRight = 6;
constexpr int kPhoneAnchorJacket = 7;
constexpr int kPhoneAnchorJacketFrame = 8;
constexpr int kPhoneAnchorMusicLabel = 9;
constexpr int kPhoneAnchorDifficultyBadge = 10;
constexpr int kPhoneAnchorTargetLabel = 0x0b;
constexpr int kPhoneAnchorTargetScore = 0x0c;
constexpr int kPhoneAnchorScoreMarkLeft = 0x0d;
constexpr int kPhoneAnchorScoreCompareMark = 0x0e;
constexpr int kPhoneAnchorScoreDifference = 0x0f;
constexpr int kPhoneAnchorScoreMarkRight = 0x10;
constexpr int kPhoneAnchorResultScore = 0x11;
constexpr int kPhoneAnchorPreviewFrame = 0x12;
constexpr int kPhoneAnchorRankBadge = 0x13;
constexpr int kPhoneAnchorFullComboBadge = 0x14;
constexpr int kPhoneAnchorClearLabel = 0x15;
constexpr int kPhoneAnchorClearStamp = 0x16;
constexpr int kPhoneAnchorStatsDecorA = 0x17;
constexpr int kPhoneAnchorStatsHeaderB = 0x18;
constexpr int kPhoneAnchorStatsHeaderC = 0x19;
constexpr int kPhoneAnchorStatsHeaderD = 0x1a;
constexpr int kPhoneAnchorStatsDecorB = 0x1b;
constexpr int kPhoneAnchorStatsHeaderE = 0x1c;
constexpr int kPhoneAnchorStatsHeaderF = 0x1d;
constexpr int kPhoneAnchorStatsHeaderG = 0x1e;
constexpr int kPhoneAnchorSideOneLabel = 0x1f;
constexpr int kPhoneAnchorSideZeroLabel = 0x28;
constexpr int kPhoneAnchorShareButton = 0x31;
constexpr int kPhoneAnchorSideRailTop = 0x32;
constexpr int kPhoneAnchorSideRailMark = 0x33;
constexpr int kPhoneAnchorHeaderBarLeft = 0x34;
constexpr int kPhoneAnchorHeaderBarRight = 0x35;
constexpr int kPhoneAnchorFooter = 0x36;
constexpr int kPhoneAnchorFooterMark = 0x37;
constexpr int kPhoneAnchorWinnerStamp = 0x38;
constexpr int kPhoneAnchorStatsBoxTopLeft = 0x39;
constexpr int kPhoneAnchorStatsBoxBottomRight = 0x3a;
constexpr int kPhoneAnchorStatsBarLeft = 0x3b;
constexpr int kPhoneAnchorStatsBarRight = 0x3c;
constexpr int kPhoneAnchorStatsTitle = 0x3d;
constexpr int kPhoneAnchorPageDotStats = 0x3e;
constexpr int kPhoneAnchorPageDotBonus = 0x3f;
constexpr int kPhoneAnchorBonusHeader = 0x40;
constexpr int kPhoneAnchorBonusTotalMark = 0x41;
constexpr int kPhoneAnchorBonusRowFirst = 0x42;     // Four slots, one per bonus row.
constexpr int kPhoneAnchorBonusRowMarkFirst = 0x46; // Four slots.
constexpr int kPhoneAnchorBonusRowRuleFirst = 0x4a; // Four slots.
constexpr int kPhoneAnchorBonusValueClear = 0x4e;
constexpr int kPhoneAnchorBonusValueRank = 0x4f;
constexpr int kPhoneAnchorBonusValueMiss = 0x50;
constexpr int kPhoneAnchorBonusValueFirstPlay = 0x51;
constexpr int kPhoneAnchorBonusFooterA = 0x52;
constexpr int kPhoneAnchorBonusFooterB = 0x53;
constexpr int kPhoneAnchorBonusFooterC = 0x54;
constexpr int kPhoneAnchorBonusTotalRule = 0x55;
constexpr int kPhoneAnchorBonusTotalValue = 0x56;
constexpr int kPhoneAnchorBonusTotalScore = 0x57;

// The separator-record runs the window draws its rules from: the twelve panel rules, the
// twenty-eight statistics-table rules, and the six bonus-table rules.
constexpr unsigned int kPhoneSeparatorPanelFirst = 0;
constexpr unsigned int kPhoneSeparatorPanelThickFirst = 2;
constexpr unsigned int kPhoneSeparatorPanelThickCount = 4;
constexpr unsigned int kPhoneSeparatorPanelCount = 12;
constexpr unsigned int kPhoneSeparatorStatsFirst = 0x0c;
constexpr unsigned int kPhoneSeparatorStatsCount = 28;
constexpr unsigned int kPhoneSeparatorBonusFirst = 0x2e;
constexpr unsigned int kPhoneSeparatorBonusCount = 6;

// The statistics rows' anchor columns: side zero's row sits this far above side one's, and the
// eight columns follow the row's base slot.
constexpr int kPhoneStatsSideAnchorStride = 9;
constexpr int kPhoneStatsColumnFirst = 0x20;

// The nine-patch box inset: each corner occupies this many pixels, so the stretched edges span the
// box less twice the inset.
constexpr float kPhoneBoxInset = 9.0f;
constexpr float kPhoneBoxInsetTwice = 18.0f;
// The stats bar's end caps occupy this many pixels each.
constexpr float kPhoneBarCapInset = 15.0f;
constexpr float kPhoneBarCapInsetTwice = 30.0f;
// The footer band starts this far in from the panel's left edge and is mirrored about the viewport.
constexpr float kPhoneFooterInset = 42.0f;
// The music jacket draws as a square of this pixel size.
constexpr float kPhoneJacketSize = 82.0f;
// The side rail is drawn at twice the viewport height so it always spans the screen.
constexpr float kPhoneSideRailHeightScale = 2.0f;
// The two side labels stand on end off an iPhone: the rows read bottom-up on one side and top-down
// on the other (@ghidraAddress 0x302d74 and 0x302d78).
constexpr float kPhoneSideLabelRotationZero = -1.5707964f;
constexpr float kPhoneSideLabelRotationOne = 1.5707964f;

// The number of bonus rows the phone breakdown lists.
constexpr int kPhoneBonusRowCount = 4;

} // namespace

/** @ghidraAddress 0x127b04 */
void LimelightResultLayer::RenderPhoneResultWindow() {
    const unsigned int nWindowAlpha =
        static_cast<unsigned int>(m_aBonusAnimChannels[kChannelWindowFade].flCurrent * kAlphaScale);
    const float flPanelFade = m_aBonusAnimChannels[kChannelPanelFade].flCurrent;
    const float flPageFade = m_aBonusAnimChannels[kChannelPageFade].flCurrent;
    const float flTitleFade = m_aBonusAnimChannels[kBonusAnimCount - 1].flCurrent;
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    ScoreTracker *pTracker = ScoreTracker::shared();
    const unsigned int nPlayColor = static_cast<unsigned int>(pGameSystem->GetPlayColor());
    // The binary fetches the singleton a second time for the viewport reads.
    GameSystem *pViewport = GameSystem::GetGameSystem();
    S_VECTOR2 position{};

    // Clear every instancer's sprite count before re-emitting this frame.
    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }
    if (nWindowAlpha == 0) {
        return;
    }

    const unsigned int nPanelAlpha =
        static_cast<unsigned int>(flPanelFade * static_cast<float>(nWindowAlpha));

    // Draws one nine-patch box: four mirrored corners, two stretched horizontal edges, two
    // stretched vertical edges, and the stretched centre fill.
    const auto EmitNinePatch = [&](const S_VECTOR2 &topLeft,
                                   const S_VECTOR2 &bottomRight,
                                   unsigned int nCornerPart,
                                   unsigned int nEdgeHPart,
                                   unsigned int nEdgeVPart,
                                   unsigned int nFillPart,
                                   unsigned int nAlpha) {
        const float flInnerWidth = (bottomRight.x - topLeft.x) - kPhoneBoxInsetTwice;
        const float flInnerHeight = (bottomRight.y - topLeft.y) - kPhoneBoxInsetTwice;
        const float flInsetX = topLeft.x + kPhoneBoxInset;
        const float flInsetY = topLeft.y + kPhoneBoxInset;
        RenderPhoneResultSpriteById(kPartsSlot, nCornerPart, topLeft, nAlpha, 0, 0.0f, 1.0f, 1.0f);
        RenderPhoneResultSpriteById(kPartsSlot,
                                    nCornerPart,
                                    S_VECTOR2{bottomRight.x, topLeft.y},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    -1.0f,
                                    1.0f);
        RenderPhoneResultSpriteById(kPartsSlot,
                                    nCornerPart,
                                    S_VECTOR2{topLeft.x, bottomRight.y},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    1.0f,
                                    -1.0f);
        RenderPhoneResultSpriteById(
            kPartsSlot, nCornerPart, bottomRight, nAlpha, 0, 0.0f, -1.0f, -1.0f);
        RenderPhoneResultSpriteById(kPartsSlot,
                                    nEdgeHPart,
                                    S_VECTOR2{flInsetX, topLeft.y},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    flInnerWidth,
                                    1.0f);
        RenderPhoneResultSpriteById(kPartsSlot,
                                    nEdgeHPart,
                                    S_VECTOR2{flInsetX, bottomRight.y},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    flInnerWidth,
                                    -1.0f);
        RenderPhoneResultSpriteById(kPartsSlot,
                                    nEdgeVPart,
                                    S_VECTOR2{topLeft.x, flInsetY},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    1.0f,
                                    flInnerHeight);
        RenderPhoneResultSpriteById(kPartsSlot,
                                    nEdgeVPart,
                                    S_VECTOR2{bottomRight.x, flInsetY},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    -1.0f,
                                    flInnerHeight);
        RenderPhoneResultSpriteById(kPartsSlot,
                                    nFillPart,
                                    S_VECTOR2{flInsetX, flInsetY},
                                    nAlpha,
                                    0,
                                    0.0f,
                                    flInnerWidth,
                                    flInnerHeight);
    };

    // Resolves an anchor, shifts it by a page offset, and returns the result.
    const auto AnchorPlus = [&](int nAnchorIndex, const S_VECTOR2 &offset) {
        S_VECTOR2 result{};
        getPosition_Phone(nAnchorIndex, &result);
        S_VECTOR2 shift = offset;
        AddVector2(&result, &shift);
        return result;
    };

    // The full-screen backdrop, the side rail, and the header bar.
    getPosition_Phone(kPhoneAnchorBackground, &position);
    RenderPhoneResultSpriteById(
        kBackgroundSlot, kPhonePartBackground, position, nWindowAlpha, 0, 0.0f, 1.0f, 1.0f);
    getPosition_Phone(kPhoneAnchorSideRailTop, &position);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartSideRailTop,
                                position,
                                nWindowAlpha,
                                0,
                                0.0f,
                                1.0f,
                                pViewport->GetViewportHeight() * kPhoneSideRailHeightScale);
    getPosition_Phone(kPhoneAnchorSideRailMark, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartSideRailMark, position, nWindowAlpha, 0, 0.0f, 1.0f, 1.0f);

    S_VECTOR2 headerLeft{};
    S_VECTOR2 headerRight{};
    getPosition_Phone(kPhoneAnchorHeaderBarLeft, &headerLeft);
    getPosition_Phone(kPhoneAnchorHeaderBarRight, &headerRight);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartHeaderBar,
                                headerLeft,
                                nWindowAlpha,
                                0,
                                0.0f,
                                headerRight.x - headerLeft.x,
                                1.0f);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartHeaderBarCap, headerRight, nWindowAlpha, 0, 0.0f, 1.0f, 1.0f);

    // The footer band: a cap at each end, mirrored about the viewport, with a stretched body
    // between.
    S_VECTOR2 footer{};
    getPosition_Phone(kPhoneAnchorFooter, &footer);
    const float flFooterBodyX = footer.x + kPhoneFooterInset;
    const float flViewportWidth = pViewport->GetViewportWidth();
    const bool bPanelDown = m_aButtons[kButtonPanel].bDown;
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartFooterCap, footer, nWindowAlpha, bPanelDown, 0.0f, 1.0f, 1.0f);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartFooterBody,
                                S_VECTOR2{flFooterBodyX, footer.y},
                                nWindowAlpha,
                                bPanelDown,
                                0.0f,
                                flViewportWidth - (flFooterBodyX + flFooterBodyX),
                                1.0f);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartFooterCap,
                                S_VECTOR2{flViewportWidth - footer.x, footer.y},
                                nWindowAlpha,
                                bPanelDown,
                                0.0f,
                                -1.0f,
                                1.0f);
    getPosition_Phone(kPhoneAnchorFooterMark, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartFooterMark, position, nWindowAlpha, bPanelDown, 0.0f, 1.0f, 1.0f);
    if (m_bTwitterAvailable) {
        getPosition_Phone(kPhoneAnchorShareButton, &position);
        RenderPhoneResultSpriteById(kPartsSlot,
                                    kPhonePartShareButton,
                                    position,
                                    nWindowAlpha,
                                    m_aButtons[kButtonShare].bDown,
                                    0.0f,
                                    1.0f,
                                    1.0f);
    }

    // The outer panel box and the inner information box.
    S_VECTOR2 outerTopLeft{};
    S_VECTOR2 outerBottomRight{};
    getPosition_Phone(kPhoneAnchorOuterBoxTopLeft, &outerTopLeft);
    getPosition_Phone(kPhoneAnchorOuterBoxBottomRight, &outerBottomRight);
    EmitNinePatch(outerTopLeft,
                  outerBottomRight,
                  kPhonePartBoxCorner,
                  kPhonePartBoxEdgeH,
                  kPhonePartBoxEdgeV,
                  kPhonePartBoxFill,
                  nWindowAlpha);
    S_VECTOR2 innerTopLeft{};
    S_VECTOR2 innerBottomRight{};
    getPosition_Phone(kPhoneAnchorInnerBoxTopLeft, &innerTopLeft);
    getPosition_Phone(kPhoneAnchorInnerBoxBottomRight, &innerBottomRight);
    EmitNinePatch(innerTopLeft,
                  innerBottomRight,
                  kPhonePartInnerCorner,
                  kPhonePartInnerEdgeH,
                  kPhonePartInnerEdgeV,
                  kPhonePartInnerFill,
                  nPanelAlpha);

    // The twelve panel rules: the middle four are the thick variant.
    for (unsigned int i = 0; i < kPhoneSeparatorPanelCount; ++i) {
        const unsigned int nSeparator = kPhoneSeparatorPanelFirst + i;
        const bool bThick =
            nSeparator >= kPhoneSeparatorPanelThickFirst &&
            nSeparator < kPhoneSeparatorPanelThickFirst + kPhoneSeparatorPanelThickCount;
        S_VECTOR2 offset{};
        RenderPhoneSpriteFieldAligned(kPartsSlot,
                                      nSeparator,
                                      bThick ? kPhonePartSeparatorThick : kPhonePartSeparatorRule,
                                      &offset,
                                      nPanelAlpha);
    }

    // The music jacket and the two character previews. In portrait the previews come from the
    // captured half-scale image; otherwise they draw straight from their instancers.
    getPosition_Phone(kPhoneAnchorJacket, &position);
    EmitTexturedPart(
        kJacketSlot, position, S_VECTOR2{kPhoneJacketSize, kPhoneJacketSize}, nPanelAlpha);
    const bool bPortrait = m_bPortrait;
    getPosition_Phone(kPhoneAnchorPreviewLeft, &position);
    if (!bPortrait) {
        EmitAutoUvPart(kPreviewLeftSlot, position, nPanelAlpha);
        getPosition_Phone(kPhoneAnchorPreviewRight, &position);
        EmitAutoUvPart(kPreviewRightSlot, position, nPanelAlpha);
    } else {
        EmitPhoneHalfScaleTexturedPart(static_cast<unsigned int>(kPreviewLeftSlot),
                                       position,
                                       nPanelAlpha,
                                       static_cast<unsigned int>(m_nDefaultAlpha));
        getPosition_Phone(kPhoneAnchorPreviewRight, &position);
        EmitPhoneHalfScaleTexturedPart(static_cast<unsigned int>(kPreviewRightSlot),
                                       position,
                                       nPanelAlpha,
                                       static_cast<unsigned int>(m_nDefaultAlpha));
    }

    getPosition_Phone(kPhoneAnchorJacketFrame, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartJacketFrame, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    getPosition_Phone(kPhoneAnchorMusicLabel, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartMusicLabel, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    getPosition_Phone(kPhoneAnchorDifficultyBadge, &position);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartDifficultyBadgeBase +
                                    static_cast<unsigned int>(pGameSystem->GetDifficulty()),
                                position,
                                nPanelAlpha,
                                0,
                                0.0f,
                                1.0f,
                                1.0f);

    // The target score and the signed distance this play landed from it.
    const int nSideOneScore = pTracker->GetPlayRecordCell(1, kCellScore);
    getPosition_Phone(kPhoneAnchorTargetLabel, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartTargetLabel, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    const int nTargetScore = pGameSystem->GetTargetScore() < 0 ? 0 : pGameSystem->GetTargetScore();
    getPosition_Phone(kPhoneAnchorTargetScore, &position);
    S_VECTOR2 noOffset{};
    RenderPhoneNumber(
        1.0f, nTargetScore, 4, &position, &noOffset, kPhonePartScoreBank, 0, 1, nPanelAlpha);
    getPosition_Phone(kPhoneAnchorScoreMarkLeft, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartScoreMark, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    int nScoreGap = nSideOneScore - nTargetScore;
    getPosition_Phone(kPhoneAnchorScoreCompareMark, &position);
    if (nScoreGap < 0) {
        RenderPhoneResultSpriteById(
            kPartsSlot, kPhonePartScoreBelowTarget, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
        nScoreGap = -nScoreGap;
    } else {
        RenderPhoneResultSpriteById(
            kPartsSlot, kPhonePartScoreAboveTarget, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    }
    getPosition_Phone(kPhoneAnchorScoreDifference, &position);
    noOffset = S_VECTOR2{};
    RenderPhoneNumber(
        1.0f, nScoreGap, 4, &position, &noOffset, kPhonePartScoreBank, 0, 1, nPanelAlpha);
    getPosition_Phone(kPhoneAnchorScoreMarkRight, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartScoreMark, position, nPanelAlpha, 0, 0.0f, -1.0f, 1.0f);
    getPosition_Phone(kPhoneAnchorResultScore, &position);
    noOffset = S_VECTOR2{};
    RenderPhoneNumber(
        1.0f, nSideOneScore, 4, &position, &noOffset, kPhonePartResultScoreBank, 0, 1, nPanelAlpha);

    if (!m_bPortrait) {
        getPosition_Phone(kPhoneAnchorPreviewFrame, &position);
        RenderPhoneResultSpriteById(
            kPartsSlot, kPhonePartPreviewFrame, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    }
    getPosition_Phone(kPhoneAnchorRankBadge, &position);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartRankBadgeBase +
                                    static_cast<unsigned int>(pTracker->GetPlayRecordRank(1)),
                                position,
                                nPanelAlpha,
                                0,
                                0.0f,
                                1.0f,
                                1.0f);
    if (pTracker->GetTotalNotes() == pTracker->GetPlayRecordCell(1, kCellMaxCombo)) {
        getPosition_Phone(kPhoneAnchorFullComboBadge, &position);
        RenderPhoneResultSpriteById(
            kPartsSlot, kPhonePartFullComboBadge, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    }

    const unsigned int nPageAlpha =
        static_cast<unsigned int>(flPageFade * static_cast<float>(nWindowAlpha));
    getPosition_Phone(kPhoneAnchorClearLabel, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartClearLabel, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    getPosition_Phone(kPhoneAnchorClearStamp, &position);
    RenderPhoneResultSpriteById(kPartsSlot,
                                pTracker->GetPlayRecordRate(1) < kClearRateThreshold ?
                                    kPhonePartFailedStamp :
                                    kPhonePartClearStamp,
                                position,
                                nPanelAlpha,
                                0,
                                0.0f,
                                1.0f,
                                1.0f);
    if (pTracker->GetPlayRecordField10(1) == kMatchOutcomeWin) {
        getPosition_Phone(kPhoneAnchorWinnerStamp, &position);
        RenderPhoneResultSpriteById(
            kPartsSlot, kPhonePartWinnerStamp, position, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    }

    // The statistics box and the bar beneath it.
    S_VECTOR2 statsTopLeft{};
    S_VECTOR2 statsBottomRight{};
    S_VECTOR2 barLeft{};
    S_VECTOR2 barRight{};
    getPosition_Phone(kPhoneAnchorStatsBoxTopLeft, &statsTopLeft);
    getPosition_Phone(kPhoneAnchorStatsBoxBottomRight, &statsBottomRight);
    getPosition_Phone(kPhoneAnchorStatsBarLeft, &barLeft);
    getPosition_Phone(kPhoneAnchorStatsBarRight, &barRight);
    // The top edge is emitted before the corners here, unlike the two boxes above.
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartInnerEdgeH,
                                S_VECTOR2{statsTopLeft.x + kPhoneBoxInset, statsTopLeft.y},
                                nPanelAlpha,
                                0,
                                0.0f,
                                statsBottomRight.x - (statsTopLeft.x + kPhoneBoxInsetTwice),
                                1.0f);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartInnerCorner, statsTopLeft, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartInnerCorner,
                                S_VECTOR2{statsBottomRight.x, statsTopLeft.y},
                                nPanelAlpha,
                                0,
                                0.0f,
                                -1.0f,
                                1.0f);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartInnerCorner,
                                S_VECTOR2{statsTopLeft.x, statsBottomRight.y},
                                nPanelAlpha,
                                0,
                                0.0f,
                                1.0f,
                                -1.0f);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartInnerCorner, statsBottomRight, nPanelAlpha, 0, 0.0f, -1.0f, -1.0f);
    const float flStatsInnerWidth = (statsBottomRight.x - statsTopLeft.x) - kPhoneBoxInsetTwice;
    const float flStatsInnerHeight = (statsBottomRight.y - statsTopLeft.y) - kPhoneBoxInsetTwice;
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartInnerEdgeH,
                                S_VECTOR2{statsTopLeft.x + kPhoneBoxInset, statsBottomRight.y},
                                nPanelAlpha,
                                0,
                                0.0f,
                                flStatsInnerWidth,
                                -1.0f);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartInnerEdgeV,
                                S_VECTOR2{statsTopLeft.x, statsTopLeft.y + kPhoneBoxInset},
                                nPanelAlpha,
                                0,
                                0.0f,
                                1.0f,
                                flStatsInnerHeight);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartInnerEdgeV,
                                S_VECTOR2{statsBottomRight.x, statsTopLeft.y + kPhoneBoxInset},
                                nPanelAlpha,
                                0,
                                0.0f,
                                -1.0f,
                                flStatsInnerHeight);
    RenderPhoneResultSpriteById(
        kPartsSlot,
        kPhonePartInnerFill,
        S_VECTOR2{statsTopLeft.x + kPhoneBoxInset, statsTopLeft.y + kPhoneBoxInset},
        nPanelAlpha,
        0,
        0.0f,
        flStatsInnerWidth,
        flStatsInnerHeight);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartBarCap, barLeft, nPanelAlpha, 0, 0.0f, 1.0f, 1.0f);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartBarBody,
                                S_VECTOR2{barLeft.x + kPhoneBarCapInset, barLeft.y},
                                nPanelAlpha,
                                0,
                                0.0f,
                                (barRight.x - barLeft.x) - kPhoneBarCapInsetTwice,
                                1.0f);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartBarCap, barRight, nPanelAlpha, 0, 0.0f, -1.0f, 1.0f);

    // The statistics and bonus pages cross-fade as the slide timer runs, each sliding in from its
    // own side. Which page leads depends on the panel's active flag.
    const float flSlide = m_flSlideTimer;
    const float flTransition = std::fabs(flSlide);
    const float flRemaining = 1.0f - flTransition;
    const float flSlideSign = flSlide <= 0.0f ? -kPageSlideDistance : kPageSlideDistance;
    const float flAlphaRemaining = static_cast<float>(nPageAlpha) * flRemaining;
    const float flAlphaTransition = static_cast<float>(nPageAlpha) * flTransition;
    S_VECTOR2 statsOffset{};
    S_VECTOR2 bonusOffset{};
    float flStatsFraction = flTransition;
    float flStatsAlpha = flAlphaTransition;
    float flBonusAlpha = flAlphaRemaining;
    if (m_nActive == kToggleOn) {
        flStatsFraction = flRemaining;
        flStatsAlpha = flAlphaRemaining;
        flBonusAlpha = flAlphaTransition;
        statsOffset.x = flSlide * -kPageSlideDistance;
        bonusOffset.x = flRemaining * flSlideSign;
    } else {
        statsOffset.x = flRemaining * flSlideSign;
        bonusOffset.x = flSlide * -kPageSlideDistance;
    }
    const unsigned int nStatsAlpha = static_cast<unsigned int>(flStatsAlpha);
    const unsigned int nBonusAlpha = static_cast<unsigned int>(flBonusAlpha);

    // The statistics page: its title fades with the page's own share of the title channel.
    getPosition_Phone(kPhoneAnchorStatsTitle, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot,
        kPhonePartStatsTitle,
        position,
        static_cast<unsigned int>(static_cast<float>(nWindowAlpha) * flTitleFade * flStatsFraction),
        0,
        0.0f,
        1.0f,
        1.0f);
    for (unsigned int i = 0; i < kPhoneSeparatorStatsCount; ++i) {
        RenderPhoneSpriteFieldAligned(kPartsSlot,
                                      kPhoneSeparatorStatsFirst + i,
                                      kPhonePartSeparatorRule,
                                      &statsOffset,
                                      nStatsAlpha);
    }

    // The statistics table's column headings.
    const int aStatsHeaderAnchors[] = {kPhoneAnchorStatsDecorA,
                                       kPhoneAnchorStatsHeaderB,
                                       kPhoneAnchorStatsHeaderC,
                                       kPhoneAnchorStatsHeaderD,
                                       kPhoneAnchorStatsDecorB,
                                       kPhoneAnchorStatsHeaderE,
                                       kPhoneAnchorStatsHeaderF,
                                       kPhoneAnchorStatsHeaderG};
    const unsigned int aStatsHeaderParts[] = {
        kPhonePartStatsDecorABase + static_cast<unsigned int>(m_nRotationFrame),
        kPhonePartStatsHeaderB,
        kPhonePartStatsHeaderC,
        kPhonePartStatsHeaderD,
        kPhonePartStatsDecorBBase + static_cast<unsigned int>(m_nRotationFrame),
        kPhonePartStatsHeaderE,
        kPhonePartStatsHeaderF,
        kPhonePartStatsHeaderG};
    for (int i = 0; i < static_cast<int>(sizeof(aStatsHeaderAnchors) / sizeof(int)); ++i) {
        getPosition_Phone(aStatsHeaderAnchors[i], &position);
        EmitPhonePartWithOffset(kPartsSlot,
                                aStatsHeaderParts[i],
                                position,
                                statsOffset,
                                nStatsAlpha,
                                0,
                                0.0f,
                                1.0f,
                                1.0f);
    }

    // One statistics row per side, each a run of eight value columns.
    const unsigned int nSideOneLabel = kPhonePartSideOneLabelBase + nPlayColor;
    const unsigned int nSideZeroLabel = kPhonePartSideZeroLabelBase + (nPlayColor == 0 ? 1u : 0u);
    for (unsigned int nSide = 0; nSide < static_cast<unsigned int>(ScoreTracker::kSideCount);
         ++nSide) {
        const int nJust = pTracker->GetPlayRecordCell(nSide, kCellJust);
        const int nGreat = pTracker->GetPlayRecordCell(nSide, kCellGreat);
        const int nGood = pTracker->GetPlayRecordCell(nSide, kCellGood);
        const int nMiss = pTracker->GetPlayRecordCell(nSide, kCellMiss);
        const int nJustReflec = pTracker->GetPlayRecordCell(nSide, kCellJustReflec);
        const int nMaxCombo = pTracker->GetPlayRecordCell(nSide, kCellMaxCombo);
        const int nScore = pTracker->GetPlayRecordCell(nSide, kCellScore);
        const int nTotalNotes = pTracker->GetTotalNotes();
        const float flRate = pTracker->GetPlayRecordRate(nSide);

        // The reflec quota is read from the score slot belonging to this row's play colour.
        const unsigned int nQuotaColor = nSide == 0 ? nPlayColor : (nPlayColor == 0 ? 1u : 0u);
        const int nReflecQuota = nQuotaColor == 0 ? m_nResultScore : m_nResultScoreHi;
        const int nRowBase = nSide == 0 ? kPhoneStatsSideAnchorStride : 0;

        // Off an iPhone the side labels stand on end, mirrored between the two rows.
        const float flLabelRotation =
            m_bPortrait ? 0.0f :
                          (nSide == 1 ? kPhoneSideLabelRotationOne : kPhoneSideLabelRotationZero);
        RenderPhonePartWithOffset(kPartsSlot,
                                  nSide == 1 ? nSideOneLabel : nSideZeroLabel,
                                  nSide == 1 ? kPhoneAnchorSideOneLabel : kPhoneAnchorSideZeroLabel,
                                  statsOffset,
                                  nStatsAlpha,
                                  0,
                                  flLabelRotation,
                                  1.0f,
                                  1.0f);

        int nColumn = kPhoneStatsColumnFirst;
        S_VECTOR2 cursor = AnchorPlus(nRowBase + nColumn++, statsOffset);
        RenderPhoneNumberDigitsRow(nJust, &cursor, nStatsAlpha);
        cursor = AnchorPlus(nRowBase + nColumn++, statsOffset);
        RenderPhoneNumberDigitsRow(nGreat, &cursor, nStatsAlpha);
        cursor = AnchorPlus(nRowBase + nColumn++, statsOffset);
        RenderPhoneNumberDigitsRow(nGood, &cursor, nStatsAlpha);
        cursor = AnchorPlus(nRowBase + nColumn++, statsOffset);
        RenderPhoneNumberDigitsRow(nMiss, &cursor, nStatsAlpha);
        cursor = AnchorPlus(nRowBase + nColumn++, statsOffset);
        RenderPhoneFraction(nJustReflec, nReflecQuota, &cursor, nStatsAlpha);
        cursor = AnchorPlus(nRowBase + nColumn++, statsOffset);
        RenderPhoneFraction(nMaxCombo, nTotalNotes, &cursor, nStatsAlpha);
        cursor = AnchorPlus(nRowBase + nColumn++, statsOffset);
        RenderPhoneNumberDigitsRow(nScore, &cursor, nStatsAlpha);
        cursor = AnchorPlus(nRowBase + nColumn++, statsOffset);
        RenderPhonePercentValue(
            static_cast<int>(flRate * kRateTenthsOfPercentScale), &cursor, nStatsAlpha);
    }

    // The bonus breakdown page.
    getPosition_Phone(kPhoneAnchorStatsTitle, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartBonusTitle, position, nBonusAlpha, 0, 0.0f, 1.0f, 1.0f);
    for (unsigned int i = 0; i < kPhoneSeparatorBonusCount; ++i) {
        RenderPhoneSpriteFieldAligned(kPartsSlot,
                                      kPhoneSeparatorBonusFirst + i,
                                      kPhonePartSeparatorRule,
                                      &bonusOffset,
                                      nBonusAlpha);
    }
    EmitPhonePartAtAnchor(kPartsSlot,
                          kPhonePartBonusHeader,
                          kPhoneAnchorBonusHeader,
                          &bonusOffset,
                          nBonusAlpha,
                          1.0f);
    for (int i = 0; i < kPhoneBonusRowCount; ++i) {
        EmitPhonePartAtAnchor(kPartsSlot,
                              kPhonePartBonusRowFirst + static_cast<unsigned int>(i),
                              static_cast<unsigned int>(kPhoneAnchorBonusRowFirst + i),
                              &bonusOffset,
                              nBonusAlpha,
                              1.0f);
    }
    for (int i = 0; i < kPhoneBonusRowCount; ++i) {
        EmitPhonePartAtAnchor(kPartsSlot,
                              kPhonePartBonusRowMark,
                              static_cast<unsigned int>(kPhoneAnchorBonusRowMarkFirst + i),
                              &bonusOffset,
                              nBonusAlpha,
                              1.0f);
    }
    for (int i = 0; i < kPhoneBonusRowCount; ++i) {
        EmitPhonePartAtAnchor(kPartsSlot,
                              kPhonePartBonusRowRule,
                              static_cast<unsigned int>(kPhoneAnchorBonusRowRuleFirst + i),
                              &bonusOffset,
                              nBonusAlpha,
                              1.0f);
    }

    S_VECTOR2 bonusCursor = AnchorPlus(kPhoneAnchorBonusValueClear, bonusOffset);
    RenderPhoneMultiplierDigitSprites(m_flClearBonus, &bonusCursor, nBonusAlpha);
    bonusCursor = AnchorPlus(kPhoneAnchorBonusValueMiss, bonusOffset);
    RenderPhoneMultiplierDigitSprites(m_flMissBonus, &bonusCursor, nBonusAlpha);
    bonusCursor = AnchorPlus(kPhoneAnchorBonusValueRank, bonusOffset);
    RenderPhoneMultiplierDigitSprites(m_flRankBonus, &bonusCursor, nBonusAlpha);
    bonusCursor = AnchorPlus(kPhoneAnchorBonusValueFirstPlay, bonusOffset);
    RenderPhoneMultiplierDigitSprites(m_flFirstPlayBonus, &bonusCursor, nBonusAlpha);

    EmitPhonePartAtAnchor(kPartsSlot,
                          kPhonePartBonusTotalMark,
                          kPhoneAnchorBonusTotalMark,
                          &bonusOffset,
                          nBonusAlpha,
                          1.0f);
    EmitPhonePartAtAnchor(kPartsSlot,
                          kPhonePartBonusTotalRule,
                          kPhoneAnchorBonusTotalRule,
                          &bonusOffset,
                          nBonusAlpha,
                          1.0f);
    bonusCursor = AnchorPlus(kPhoneAnchorBonusTotalValue, bonusOffset);
    RenderPhoneMultiplierDigitSprites(m_flClearBonus + m_flMissBonus + m_flRankBonus +
                                          m_flFirstPlayBonus,
                                      &bonusCursor,
                                      nBonusAlpha);
    EmitPhonePartAtAnchor(kPartsSlot,
                          kPhonePartBonusFooterA,
                          kPhoneAnchorBonusFooterA,
                          &bonusOffset,
                          nBonusAlpha,
                          1.0f);
    EmitPhonePartAtAnchor(kPartsSlot,
                          kPhonePartBonusFooterB,
                          kPhoneAnchorBonusFooterB,
                          &bonusOffset,
                          nBonusAlpha,
                          1.0f);
    EmitPhonePartAtAnchor(kPartsSlot,
                          kPhonePartBonusFooterC,
                          kPhoneAnchorBonusFooterC,
                          &bonusOffset,
                          nBonusAlpha,
                          1.0f);
    bonusCursor = AnchorPlus(kPhoneAnchorBonusTotalScore, bonusOffset);
    RenderPhoneTotalScoreDigits(&bonusCursor, nBonusAlpha);

    // The two page dots: each lights (drawing through the dimmed pass) for the page it selects.
    getPosition_Phone(kPhoneAnchorPageDotStats, &position);
    RenderPhoneResultSpriteById(kPartsSlot,
                                kPhonePartPageDot,
                                position,
                                nPageAlpha,
                                m_nActive == kToggleOn,
                                0.0f,
                                1.0f,
                                1.0f);
    getPosition_Phone(kPhoneAnchorPageDotBonus, &position);
    RenderPhoneResultSpriteById(
        kPartsSlot, kPhonePartPageDot, position, nPageAlpha, m_nActive == 0, 0.0f, 1.0f, 1.0f);
}

// Seeds every Limelight phone result-screen layout table at load time, the twin of
// InitializeResultLayoutTable. Its address sits in the binary's __mod_init_func list (0x358cb0), so
// dyld runs it at image load; nothing calls it by name. The binary wraps the whole fill in an
// autorelease pool, then writes every field inline.
/** @ghidraAddress 0x12af9c */
__attribute__((constructor)) void InitializePhoneResultLayoutTable() {
    @autoreleasepool {
        g_aLimelightPartsPhone[0].nEnabled = 1;
        g_aLimelightPartsPhone[0].flX = 0.0f;
        g_aLimelightPartsPhone[0].flWidth = 768.0f;
        g_aLimelightPartsPhone[0].flHeight = static_cast<float>(g_nPlayfieldFieldHeight);
        g_aLimelightPartsPhone[0].nUvPaletteIndex = 0;
        g_aLimelightPartsPhone[1].nEnabled = 1;
        g_aLimelightPartsPhone[1].flX = 0.0f;
        g_aLimelightPartsPhone[1].flY = 0.0f;
        g_aLimelightPartsPhone[1].nUvPaletteIndex = 1;
        g_aLimelightPartsPhone[2].nEnabled = 1;
        g_aLimelightPartsPhone[2].flX = 0.0f;
        g_aLimelightPartsPhone[2].flY = 0.0f;
        g_aLimelightPartsPhone[2].flWidth = 92.0f;
        g_aLimelightPartsPhone[2].flHeight = 38.0f;
        g_aLimelightPartsPhone[2].nUvPaletteIndex = 2;
        g_aLimelightPartsPhone[3].nEnabled = 1;
        g_aLimelightPartsPhone[3].flX = 0.0f;
        g_aLimelightPartsPhone[3].flY = 0.0f;
        g_aLimelightPartsPhone[3].flWidth = 268.0f;
        g_aLimelightPartsPhone[3].flHeight = 56.0f;
        g_aLimelightPartsPhone[3].nUvPaletteIndex = 3;
        g_aLimelightPartsPhone[4].nEnabled = 1;
        g_aLimelightPartsPhone[4].nUvPaletteIndex = 4;
        g_aLimelightPartsPhone[5].nEnabled = 1;
        g_aLimelightPartsPhone[5].flX = 0.0f;
        g_aLimelightPartsPhone[5].flY = 0.0f;
        g_aLimelightPartsPhone[5].flWidth = 268.0f;
        g_aLimelightPartsPhone[5].flHeight = 198.0f;
        g_aLimelightPartsPhone[5].nUvPaletteIndex = 5;
        g_aLimelightPartsPhone[6].nEnabled = 1;
        g_aLimelightPartsPhone[6].flX = 0.0f;
        g_aLimelightPartsPhone[6].flY = 0.0f;
        g_aLimelightPartsPhone[6].flWidth = 268.0f;
        g_aLimelightPartsPhone[6].flHeight = 198.0f;
        g_aLimelightPartsPhone[6].nUvPaletteIndex = 6;
        g_aLimelightPartsPhone[7].nEnabled = 1;
        g_aLimelightPartsPhone[7].flX = 0.0f;
        g_aLimelightPartsPhone[7].flY = 0.0f;
        g_aLimelightPartsPhone[7].flWidth = 268.0f;
        g_aLimelightPartsPhone[7].flHeight = 14.0f;
        g_aLimelightPartsPhone[7].nUvPaletteIndex = 7;
        g_aLimelightPartsPhone[8].nEnabled = 1;
        g_aLimelightPartsPhone[8].nUvPaletteIndex = 8;
        g_aLimelightPartsPhone[9].nEnabled = 1;
        g_aLimelightPartsPhone[9].flX = 0.0f;
        g_aLimelightPartsPhone[9].flY = 0.0f;
        g_aLimelightPartsPhone[9].flWidth = 4e+01f;
        g_aLimelightPartsPhone[9].flHeight = 56.0f;
        g_aLimelightPartsPhone[9].nUvPaletteIndex = 9;
        g_aLimelightPartsPhone[10].nEnabled = 1;
        g_aLimelightPartsPhone[10].flX = 0.0f;
        g_aLimelightPartsPhone[10].flY = 0.0f;
        g_aLimelightPartsPhone[10].flWidth = 329.0f;
        g_aLimelightPartsPhone[10].flHeight = 56.0f;
        g_aLimelightPartsPhone[10].nUvPaletteIndex = 10;
        g_aLimelightPartsPhone[11].nEnabled = 1;
        g_aLimelightPartsPhone[11].nUvPaletteIndex = 11;
        g_aLimelightPartsPhone[12].nEnabled = 1;
        g_aLimelightPartsPhone[12].nUvPaletteIndex = 12;
        g_aLimelightPartsPhone[13].nEnabled = 1;
        g_aLimelightPartsPhone[13].flX = 0.0f;
        g_aLimelightPartsPhone[13].flY = 0.0f;
        g_aLimelightPartsPhone[13].flWidth = 268.0f;
        g_aLimelightPartsPhone[13].flHeight = 56.0f;
        g_aLimelightPartsPhone[13].nUvPaletteIndex = 13;
        g_aLimelightPartsPhone[14].nEnabled = 1;
        g_aLimelightPartsPhone[14].flX = 0.0f;
        g_aLimelightPartsPhone[14].flY = 0.0f;
        g_aLimelightPartsPhone[14].flWidth = 268.0f;
        g_aLimelightPartsPhone[14].flHeight = 464.0f;
        g_aLimelightPartsPhone[14].nUvPaletteIndex = 14;
        g_aLimelightPartsPhone[15].nEnabled = 1;
        g_aLimelightPartsPhone[15].nUvPaletteIndex = 15;
        g_aLimelightPartsPhone[16].nEnabled = 1;
        g_aLimelightPartsPhone[16].nUvPaletteIndex = 16;
        g_aLimelightPartsPhone[17].nEnabled = 1;
        g_aLimelightPartsPhone[17].nUvPaletteIndex = 17;
        g_aLimelightPartsPhone[18].nEnabled = 1;
        g_aLimelightPartsPhone[18].flX = 0.0f;
        g_aLimelightPartsPhone[18].flY = 0.0f;
        g_aLimelightPartsPhone[18].flWidth = 4e+01f;
        g_aLimelightPartsPhone[18].flHeight = 56.0f;
        g_aLimelightPartsPhone[18].nUvPaletteIndex = 18;
        g_aLimelightPartsPhone[19].nEnabled = 1;
        g_aLimelightPartsPhone[19].flX = 0.0f;
        g_aLimelightPartsPhone[19].flY = 0.0f;
        g_aLimelightPartsPhone[19].flWidth = 329.0f;
        g_aLimelightPartsPhone[19].flHeight = 56.5f;
        g_aLimelightPartsPhone[19].nUvPaletteIndex = 19;
        g_aLimelightPartsPhone[20].nEnabled = 1;
        g_aLimelightPartsPhone[20].nUvPaletteIndex = 20;
        g_aLimelightPartsPhone[21].nEnabled = 1;
        g_aLimelightPartsPhone[21].flX = 0.0f;
        g_aLimelightPartsPhone[21].flY = 0.0f;
        g_aLimelightPartsPhone[21].flWidth = 6.0f;
        g_aLimelightPartsPhone[21].flHeight = 6.0f;
        g_aLimelightPartsPhone[21].nUvPaletteIndex = 21;
        g_aLimelightPartsPhone[22].nEnabled = 1;
        g_aLimelightPartsPhone[22].flX = 0.0f;
        g_aLimelightPartsPhone[22].flY = 0.0f;
        g_aLimelightPartsPhone[22].flWidth = 504.0f;
        g_aLimelightPartsPhone[22].flHeight = 3e+01f;
        g_aLimelightPartsPhone[22].nUvPaletteIndex = 22;
        g_aLimelightPartsPhone[23].nEnabled = 1;
        g_aLimelightPartsPhone[23].flX = 0.0f;
        g_aLimelightPartsPhone[23].flY = 0.0f;
        g_aLimelightPartsPhone[23].flWidth = 504.0f;
        g_aLimelightPartsPhone[23].flHeight = 254.0f;
        g_aLimelightPartsPhone[23].nUvPaletteIndex = 23;
        g_aLimelightPartsPhone[24].nEnabled = 1;
        g_aLimelightPartsPhone[24].flX = 0.0f;
        g_aLimelightPartsPhone[24].flY = 0.0f;
        g_aLimelightPartsPhone[24].flWidth = 504.0f;
        g_aLimelightPartsPhone[24].flHeight = 12.0f;
        g_aLimelightPartsPhone[24].nUvPaletteIndex = 24;
        g_aLimelightPartsPhone[25].nEnabled = 1;
        g_aLimelightPartsPhone[25].nUvPaletteIndex = 25;
        g_aLimelightPartsPhone[26].nEnabled = 1;
        g_aLimelightPartsPhone[26].flX = 0.0f;
        g_aLimelightPartsPhone[26].flY = 0.0f;
        g_aLimelightPartsPhone[26].flWidth = 504.0f;
        g_aLimelightPartsPhone[26].flHeight = 82.0f;
        g_aLimelightPartsPhone[26].nUvPaletteIndex = 26;
        g_aLimelightPartsPhone[27].nEnabled = 1;
        g_aLimelightPartsPhone[27].nUvPaletteIndex = 27;
        g_aLimelightPartsPhone[28].nEnabled = 1;
        g_aLimelightPartsPhone[28].flX = 0.0f;
        g_aLimelightPartsPhone[28].flY = 0.0f;
        g_aLimelightPartsPhone[28].flWidth = 38.0f;
        g_aLimelightPartsPhone[28].flHeight = 12.0f;
        g_aLimelightPartsPhone[28].nUvPaletteIndex = 28;
        g_aLimelightPartsPhone[29].nEnabled = 1;
        g_aLimelightPartsPhone[29].flX = 0.0f;
        g_aLimelightPartsPhone[29].flY = 0.0f;
        g_aLimelightPartsPhone[29].flWidth = 38.0f;
        g_aLimelightPartsPhone[29].flHeight = 12.0f;
        g_aLimelightPartsPhone[29].nUvPaletteIndex = 29;
        g_aLimelightPartsPhone[30].nEnabled = 1;
        g_aLimelightPartsPhone[30].nUvPaletteIndex = 30;
        g_aLimelightPartsPhone[31].nEnabled = 1;
        g_aLimelightPartsPhone[31].nUvPaletteIndex = 31;
        g_aLimelightPartsPhone[32].nEnabled = 1;
        g_aLimelightPartsPhone[32].flX = 0.0f;
        g_aLimelightPartsPhone[32].flY = 0.0f;
        g_aLimelightPartsPhone[32].flWidth = 504.0f;
        g_aLimelightPartsPhone[32].flHeight = 186.0f;
        g_aLimelightPartsPhone[32].nUvPaletteIndex = 32;
        g_aLimelightPartsPhone[33].nEnabled = 1;
        g_aLimelightPartsPhone[33].flX = 0.0f;
        g_aLimelightPartsPhone[33].flY = 0.0f;
        g_aLimelightPartsPhone[33].flWidth = 4e+01f;
        g_aLimelightPartsPhone[33].flHeight = 1e+01f;
        g_aLimelightPartsPhone[33].nUvPaletteIndex = 33;
        g_aLimelightPartsPhone[34].nEnabled = 1;
        g_aLimelightPartsPhone[34].flX = 0.0f;
        g_aLimelightPartsPhone[34].flY = 0.0f;
        g_aLimelightPartsPhone[34].flWidth = 5e+01f;
        g_aLimelightPartsPhone[34].flHeight = 1e+01f;
        g_aLimelightPartsPhone[34].nUvPaletteIndex = 34;
        g_aLimelightPartsPhone[35].nEnabled = 1;
        g_aLimelightPartsPhone[35].flX = 0.0f;
        g_aLimelightPartsPhone[35].flY = 0.0f;
        g_aLimelightPartsPhone[35].flWidth = 38.0f;
        g_aLimelightPartsPhone[35].flHeight = 1e+01f;
        g_aLimelightPartsPhone[35].nUvPaletteIndex = 35;
        g_aLimelightPartsPhone[36].nEnabled = 1;
        g_aLimelightPartsPhone[36].flX = 0.0f;
        g_aLimelightPartsPhone[36].flY = 0.0f;
        g_aLimelightPartsPhone[36].flWidth = 5e+01f;
        g_aLimelightPartsPhone[36].flHeight = 1e+01f;
        g_aLimelightPartsPhone[36].nUvPaletteIndex = 36;
        g_aLimelightPartsPhone[37].nEnabled = 1;
        g_aLimelightPartsPhone[37].flX = 0.0f;
        g_aLimelightPartsPhone[37].flY = 0.0f;
        g_aLimelightPartsPhone[37].flWidth = 6.0f;
        g_aLimelightPartsPhone[37].flHeight = 8.0f;
        g_aLimelightPartsPhone[37].nUvPaletteIndex = 37;
        g_aLimelightPartsPhone[38].nEnabled = 1;
        g_aLimelightPartsPhone[38].flX = 0.0f;
        g_aLimelightPartsPhone[38].flY = 0.0f;
        g_aLimelightPartsPhone[38].flWidth = 6.0f;
        g_aLimelightPartsPhone[38].flHeight = 8.0f;
        g_aLimelightPartsPhone[38].nUvPaletteIndex = 38;
        g_aLimelightPartsPhone[39].nEnabled = 1;
        g_aLimelightPartsPhone[39].nUvPaletteIndex = 39;
        g_aLimelightPartsPhone[40].nEnabled = 1;
        g_aLimelightPartsPhone[40].nUvPaletteIndex = 40;
        g_aLimelightPartsPhone[41].nEnabled = 1;
        g_aLimelightPartsPhone[41].nUvPaletteIndex = 41;
        g_aLimelightPartsPhone[42].nEnabled = 1;
        g_aLimelightPartsPhone[42].flX = 0.0f;
        g_aLimelightPartsPhone[42].flY = 0.0f;
        g_aLimelightPartsPhone[42].flWidth = 6.0f;
        g_aLimelightPartsPhone[42].flHeight = 8.0f;
        g_aLimelightPartsPhone[42].nUvPaletteIndex = 42;
        g_aLimelightPartsPhone[43].nEnabled = 1;
        g_aLimelightPartsPhone[43].nUvPaletteIndex = 43;
        g_aLimelightPartsPhone[44].nEnabled = 1;
        g_aLimelightPartsPhone[44].nUvPaletteIndex = 44;
        g_aLimelightPartsPhone[45].nEnabled = 1;
        g_aLimelightPartsPhone[45].flX = 0.0f;
        g_aLimelightPartsPhone[45].flY = 0.0f;
        g_aLimelightPartsPhone[45].flWidth = 6.0f;
        g_aLimelightPartsPhone[45].flHeight = 8.0f;
        g_aLimelightPartsPhone[45].nUvPaletteIndex = 45;
        g_aLimelightPartsPhone[46].nEnabled = 1;
        g_aLimelightPartsPhone[46].nUvPaletteIndex = 46;
        g_aLimelightPartsPhone[47].nEnabled = 1;
        g_aLimelightPartsPhone[47].flX = 0.0f;
        g_aLimelightPartsPhone[47].flY = 0.0f;
        g_aLimelightPartsPhone[47].flWidth = 1e+01f;
        g_aLimelightPartsPhone[47].flHeight = 8.0f;
        g_aLimelightPartsPhone[47].nUvPaletteIndex = 47;
        g_aLimelightPartsPhone[48].nEnabled = 1;
        g_aLimelightPartsPhone[48].nUvPaletteIndex = 48;
        g_aLimelightPartsPhone[49].nEnabled = 1;
        g_aLimelightPartsPhone[49].nUvPaletteIndex = 49;
        g_aLimelightPartsPhone[50].nEnabled = 1;
        g_aLimelightPartsPhone[50].flX = 0.0f;
        g_aLimelightPartsPhone[50].flY = 0.0f;
        g_aLimelightPartsPhone[50].flWidth = 1e+01f;
        g_aLimelightPartsPhone[50].flHeight = 8.0f;
        g_aLimelightPartsPhone[50].nUvPaletteIndex = 50;
        g_aLimelightPartsPhone[51].nEnabled = 1;
        g_aLimelightPartsPhone[51].nUvPaletteIndex = 51;
        g_aLimelightPartsPhone[52].nEnabled = 1;
        g_aLimelightPartsPhone[52].nUvPaletteIndex = 52;
        g_aLimelightPartsPhone[53].nEnabled = 1;
        g_aLimelightPartsPhone[53].flX = 0.0f;
        g_aLimelightPartsPhone[53].flY = 0.0f;
        g_aLimelightPartsPhone[53].flWidth = 6.0f;
        g_aLimelightPartsPhone[53].flHeight = 8.0f;
        g_aLimelightPartsPhone[53].nUvPaletteIndex = 53;
        g_aLimelightPartsPhone[54].nEnabled = 1;
        g_aLimelightPartsPhone[54].nUvPaletteIndex = 54;
        g_aLimelightPartsPhone[55].nEnabled = 1;
        g_aLimelightPartsPhone[55].nUvPaletteIndex = 55;
        g_aLimelightPartsPhone[56].nEnabled = 1;
        g_aLimelightPartsPhone[56].nUvPaletteIndex = 56;
        g_aLimelightPartsPhone[57].nEnabled = 1;
        g_aLimelightPartsPhone[57].nUvPaletteIndex = 57;
        g_aLimelightPartsPhone[58].nEnabled = 1;
        g_aLimelightPartsPhone[58].flX = 0.0f;
        g_aLimelightPartsPhone[58].flY = 0.0f;
        g_aLimelightPartsPhone[58].flWidth = 6.0f;
        g_aLimelightPartsPhone[58].flHeight = 8.0f;
        g_aLimelightPartsPhone[58].nUvPaletteIndex = 58;
        g_aLimelightPartsPhone[59].nEnabled = 1;
        g_aLimelightPartsPhone[59].nUvPaletteIndex = 59;
        g_aLimelightPartsPhone[60].nEnabled = 1;
        g_aLimelightPartsPhone[60].nUvPaletteIndex = 60;
        g_aLimelightPartsPhone[61].nEnabled = 1;
        g_aLimelightPartsPhone[61].flX = 0.0f;
        g_aLimelightPartsPhone[61].flY = 0.0f;
        g_aLimelightPartsPhone[61].flWidth = 6.0f;
        g_aLimelightPartsPhone[61].flHeight = 8.0f;
        g_aLimelightPartsPhone[61].nUvPaletteIndex = 61;
        g_aLimelightPartsPhone[62].nEnabled = 1;
        g_aLimelightPartsPhone[62].nUvPaletteIndex = 62;
        g_aLimelightPartsPhone[63].nEnabled = 1;
        g_aLimelightPartsPhone[63].flX = 0.0f;
        g_aLimelightPartsPhone[63].flY = 0.0f;
        g_aLimelightPartsPhone[63].flWidth = 2.0f;
        g_aLimelightPartsPhone[63].flHeight = 8.0f;
        g_aLimelightPartsPhone[63].nUvPaletteIndex = 63;
        g_aLimelightPartsPhone[64].nEnabled = 1;
        g_aLimelightPartsPhone[64].nUvPaletteIndex = 64;
        g_aLimelightPartsPhone[65].nEnabled = 1;
        g_aLimelightPartsPhone[65].nUvPaletteIndex = 65;
        g_aLimelightPartsPhone[66].nEnabled = 1;
        g_aLimelightPartsPhone[66].flX = 0.0f;
        g_aLimelightPartsPhone[66].flY = 0.0f;
        g_aLimelightPartsPhone[66].flWidth = 1.0f;
        g_aLimelightPartsPhone[66].flHeight = 12.0f;
        g_aLimelightPartsPhone[66].nUvPaletteIndex = 66;
        g_aLimelightPartsPhone[67].nEnabled = 1;
        g_aLimelightPartsPhone[67].flX = 0.0f;
        g_aLimelightPartsPhone[67].flY = 0.0f;
        g_aLimelightPartsPhone[67].flWidth = 1.0f;
        g_aLimelightPartsPhone[67].flHeight = 12.0f;
        g_aLimelightPartsPhone[67].nUvPaletteIndex = 67;
        g_aLimelightPartsPhone[68].nEnabled = 1;
        g_aLimelightPartsPhone[68].flX = 0.0f;
        g_aLimelightPartsPhone[68].flY = 0.0f;
        g_aLimelightPartsPhone[68].flWidth = 16.0f;
        g_aLimelightPartsPhone[68].flHeight = 18.0f;
        g_aLimelightPartsPhone[68].nUvPaletteIndex = 68;
        g_aLimelightPartsPhone[69].nEnabled = 1;
        g_aLimelightPartsPhone[69].flX = 0.0f;
        g_aLimelightPartsPhone[69].flY = 0.0f;
        g_aLimelightPartsPhone[69].flWidth = 16.0f;
        g_aLimelightPartsPhone[69].flHeight = 18.0f;
        g_aLimelightPartsPhone[69].nUvPaletteIndex = 69;
        g_aLimelightPartsPhone[70].nEnabled = 1;
        g_aLimelightPartsPhone[70].nUvPaletteIndex = 70;
        g_aLimelightPartsPhone[71].nEnabled = 1;
        g_aLimelightPartsPhone[71].nUvPaletteIndex = 71;
        g_aLimelightPartsPhone[72].nEnabled = 1;
        g_aLimelightPartsPhone[72].nUvPaletteIndex = 72;
        g_aLimelightPartsPhone[73].nEnabled = 1;
        g_aLimelightPartsPhone[73].nUvPaletteIndex = 73;
        g_aLimelightPartsPhone[74].nEnabled = 1;
        g_aLimelightPartsPhone[74].flX = 0.0f;
        g_aLimelightPartsPhone[74].flY = 0.0f;
        g_aLimelightPartsPhone[74].flWidth = 16.0f;
        g_aLimelightPartsPhone[74].flHeight = 18.0f;
        g_aLimelightPartsPhone[74].nUvPaletteIndex = 74;
        g_aLimelightPartsPhone[75].nEnabled = 1;
        g_aLimelightPartsPhone[75].nUvPaletteIndex = 75;
        g_aLimelightPartsPhone[76].nEnabled = 1;
        g_aLimelightPartsPhone[76].nUvPaletteIndex = 76;
        g_aLimelightPartsPhone[77].nEnabled = 1;
        g_aLimelightPartsPhone[77].flX = 0.0f;
        g_aLimelightPartsPhone[77].flY = 0.0f;
        g_aLimelightPartsPhone[77].flWidth = 16.0f;
        g_aLimelightPartsPhone[77].flHeight = 18.0f;
        g_aLimelightPartsPhone[77].nUvPaletteIndex = 77;
        g_aLimelightPartsPhone[78].nEnabled = 1;
        g_aLimelightPartsPhone[78].nUvPaletteIndex = 78;
        g_aLimelightPartsPhone[79].nEnabled = 1;
        g_aLimelightPartsPhone[79].nUvPaletteIndex = 79;
        g_aLimelightPartsPhone[80].nEnabled = 1;
        g_aLimelightPartsPhone[80].nUvPaletteIndex = 80;
        g_aLimelightPartsPhone[81].nEnabled = 1;
        g_aLimelightPartsPhone[81].nUvPaletteIndex = 81;
        g_aLimelightPartsPhone[82].nEnabled = 1;
        g_aLimelightPartsPhone[82].flX = 0.0f;
        g_aLimelightPartsPhone[82].flY = 0.0f;
        g_aLimelightPartsPhone[82].flWidth = 16.0f;
        g_aLimelightPartsPhone[82].flHeight = 18.0f;
        g_aLimelightPartsPhone[82].nUvPaletteIndex = 82;
        g_aLimelightPartsPhone[83].nEnabled = 1;
        g_aLimelightPartsPhone[83].nUvPaletteIndex = 83;
        g_aLimelightPartsPhone[84].nEnabled = 1;
        g_aLimelightPartsPhone[84].nUvPaletteIndex = 84;
        g_aLimelightPartsPhone[85].nEnabled = 1;
        g_aLimelightPartsPhone[85].flX = 0.0f;
        g_aLimelightPartsPhone[85].flY = 0.0f;
        g_aLimelightPartsPhone[85].flWidth = 16.0f;
        g_aLimelightPartsPhone[85].flHeight = 18.0f;
        g_aLimelightPartsPhone[85].nUvPaletteIndex = 85;
        g_aLimelightPartsPhone[86].nEnabled = 1;
        g_aLimelightPartsPhone[86].nUvPaletteIndex = 86;
        g_aLimelightPartsPhone[87].nEnabled = 1;
        g_aLimelightPartsPhone[87].nUvPaletteIndex = 87;
        g_aLimelightPartsPhone[88].nEnabled = 1;
        g_aLimelightPartsPhone[88].flX = 22.0f;
        g_aLimelightPartsPhone[88].flY = 19.0f;
        g_aLimelightPartsPhone[88].flWidth = 44.0f;
        g_aLimelightPartsPhone[88].flHeight = 38.0f;
        g_aLimelightPartsPhone[88].nUvPaletteIndex = 88;
        g_aLimelightPartsPhone[89].nEnabled = 1;
        g_aLimelightPartsPhone[89].nUvPaletteIndex = 89;
        g_aLimelightPartsPhone[90].nEnabled = 1;
        g_aLimelightPartsPhone[90].flX = 22.0f;
        g_aLimelightPartsPhone[90].flY = 19.0f;
        g_aLimelightPartsPhone[90].flWidth = 44.0f;
        g_aLimelightPartsPhone[90].flHeight = 38.0f;
        g_aLimelightPartsPhone[90].nUvPaletteIndex = 90;
        g_aLimelightPartsPhone[91].nEnabled = 1;
        g_aLimelightPartsPhone[91].flX = 32.0f;
        g_aLimelightPartsPhone[91].flY = 19.0f;
        g_aLimelightPartsPhone[91].flWidth = 64.0f;
        g_aLimelightPartsPhone[91].flHeight = 38.0f;
        g_aLimelightPartsPhone[91].nUvPaletteIndex = 91;
        g_aLimelightPartsPhone[92].nEnabled = 1;
        g_aLimelightPartsPhone[92].nUvPaletteIndex = 92;
        g_aLimelightPartsPhone[93].nEnabled = 1;
        g_aLimelightPartsPhone[93].flX = 32.0f;
        g_aLimelightPartsPhone[93].flY = 19.0f;
        g_aLimelightPartsPhone[93].flWidth = 64.0f;
        g_aLimelightPartsPhone[93].flHeight = 38.0f;
        g_aLimelightPartsPhone[93].nUvPaletteIndex = 93;
        g_aLimelightPartsPhone[94].nEnabled = 1;
        g_aLimelightPartsPhone[94].flX = 36.0f;
        g_aLimelightPartsPhone[94].flY = 27.0f;
        g_aLimelightPartsPhone[94].flWidth = 72.0f;
        g_aLimelightPartsPhone[94].flHeight = 54.0f;
        g_aLimelightPartsPhone[94].nUvPaletteIndex = 94;
        g_aLimelightPartsPhone[95].nEnabled = 1;
        g_aLimelightPartsPhone[95].flX = 0.0f;
        g_aLimelightPartsPhone[95].flY = 0.0f;
        g_aLimelightPartsPhone[95].flWidth = 1.5e+02f;
        g_aLimelightPartsPhone[95].flHeight = 184.0f;
        g_aLimelightPartsPhone[95].nUvPaletteIndex = 95;
        g_aLimelightPartsPhone[96].nEnabled = 1;
        g_aLimelightPartsPhone[96].flX = 0.0f;
        g_aLimelightPartsPhone[96].flY = 0.0f;
        g_aLimelightPartsPhone[96].flWidth = 1.4e+02f;
        g_aLimelightPartsPhone[96].flHeight = 234.0f;
        g_aLimelightPartsPhone[96].nUvPaletteIndex = 96;
        g_aLimelightPartsPhone[97].nEnabled = 1;
        g_aLimelightPartsPhone[97].flX = 0.0f;
        g_aLimelightPartsPhone[97].flY = 0.0f;
        g_aLimelightPartsPhone[97].flWidth = 52.0f;
        g_aLimelightPartsPhone[97].flHeight = 18.0f;
        g_aLimelightPartsPhone[97].nUvPaletteIndex = 97;
        g_aLimelightPartsPhone[98].nEnabled = 1;
        g_aLimelightPartsPhone[98].flX = 0.0f;
        g_aLimelightPartsPhone[98].flY = 0.0f;
        g_aLimelightPartsPhone[98].flWidth = 52.0f;
        g_aLimelightPartsPhone[98].flHeight = 18.0f;
        g_aLimelightPartsPhone[98].nUvPaletteIndex = 98;
        g_aLimelightPartsPhone[99].nEnabled = 1;
        g_aLimelightPartsPhone[99].nUvPaletteIndex = 99;
        g_aLimelightPartsPhone[100].nEnabled = 1;
        g_aLimelightPartsPhone[100].nUvPaletteIndex = 100;
        g_aLimelightPartsPhone[101].nEnabled = 1;
        g_aLimelightPartsPhone[101].flX = 0.0f;
        g_aLimelightPartsPhone[101].flY = 0.0f;
        g_aLimelightPartsPhone[101].flWidth = 1.3e+02f;
        g_aLimelightPartsPhone[101].flHeight = 18.0f;
        g_aLimelightPartsPhone[101].nUvPaletteIndex = 101;
        g_aLimelightPartsPhone[102].nEnabled = 1;
        g_aLimelightPartsPhone[102].flX = 0.0f;
        g_aLimelightPartsPhone[102].flY = 0.0f;
        g_aLimelightPartsPhone[102].flWidth = 1.3e+02f;
        g_aLimelightPartsPhone[102].flHeight = 18.0f;
        g_aLimelightPartsPhone[102].nUvPaletteIndex = 102;
        g_aLimelightPartsPhone[103].nEnabled = 1;
        g_aLimelightPartsPhone[103].nUvPaletteIndex = 103;
        g_aLimelightPartsPhone[104].nEnabled = 1;
        g_aLimelightPartsPhone[104].nUvPaletteIndex = 104;
        g_aLimelightPartsPhone[105].nEnabled = 1;
        g_aLimelightPartsPhone[105].flX = 0.0f;
        g_aLimelightPartsPhone[105].flY = 0.0f;
        g_aLimelightPartsPhone[105].flWidth = 1e+01f;
        g_aLimelightPartsPhone[105].flHeight = 12.0f;
        g_aLimelightPartsPhone[105].nUvPaletteIndex = 105;
        g_aLimelightPartsPhone[106].nEnabled = 1;
        g_aLimelightPartsPhone[106].flX = 0.0f;
        g_aLimelightPartsPhone[106].flY = 0.0f;
        g_aLimelightPartsPhone[106].flWidth = 1e+01f;
        g_aLimelightPartsPhone[106].flHeight = 12.0f;
        g_aLimelightPartsPhone[106].nUvPaletteIndex = 106;
        g_aLimelightPartsPhone[107].nEnabled = 1;
        g_aLimelightPartsPhone[107].nUvPaletteIndex = 107;
        g_aLimelightPartsPhone[108].nEnabled = 1;
        g_aLimelightPartsPhone[108].nUvPaletteIndex = 108;
        g_aLimelightPartsPhone[109].nEnabled = 1;
        g_aLimelightPartsPhone[109].flX = 0.0f;
        g_aLimelightPartsPhone[109].flY = 0.0f;
        g_aLimelightPartsPhone[109].flWidth = 1e+01f;
        g_aLimelightPartsPhone[109].flHeight = 12.0f;
        g_aLimelightPartsPhone[109].nUvPaletteIndex = 109;
        g_aLimelightPartsPhone[110].nEnabled = 1;
        g_aLimelightPartsPhone[110].nUvPaletteIndex = 110;
        g_aLimelightPartsPhone[111].nEnabled = 1;
        g_aLimelightPartsPhone[111].nUvPaletteIndex = 111;
        g_aLimelightPartsPhone[112].nEnabled = 1;
        g_aLimelightPartsPhone[112].nUvPaletteIndex = 112;
        g_aLimelightPartsPhone[113].nEnabled = 1;
        g_aLimelightPartsPhone[113].nUvPaletteIndex = 113;
        g_aLimelightPartsPhone[114].nEnabled = 1;
        g_aLimelightPartsPhone[114].flX = 0.0f;
        g_aLimelightPartsPhone[114].flY = 0.0f;
        g_aLimelightPartsPhone[114].flWidth = 1e+01f;
        g_aLimelightPartsPhone[114].flHeight = 12.0f;
        g_aLimelightPartsPhone[114].nUvPaletteIndex = 114;
        g_aLimelightPartsPhone[115].nEnabled = 1;
        g_aLimelightPartsPhone[115].flX = 0.0f;
        g_aLimelightPartsPhone[115].flY = 0.0f;
        g_aLimelightPartsPhone[115].flWidth = 6.0f;
        g_aLimelightPartsPhone[115].flHeight = 12.0f;
        g_aLimelightPartsPhone[115].nUvPaletteIndex = 115;
        g_aLimelightPartsPhone[116].nEnabled = 1;
        g_aLimelightPartsPhone[116].nUvPaletteIndex = 116;
        g_aLimelightPartsPhone[117].nEnabled = 1;
        g_aLimelightPartsPhone[117].flX = 0.0f;
        g_aLimelightPartsPhone[117].flY = 0.0f;
        g_aLimelightPartsPhone[117].flWidth = 1.0f;
        g_aLimelightPartsPhone[117].flHeight = 5.0f;
        g_aLimelightPartsPhone[117].nUvPaletteIndex = 117;
        g_aLimelightPartsPhone[118].nEnabled = 1;
        g_aLimelightPartsPhone[118].flX = 0.0f;
        g_aLimelightPartsPhone[118].flY = 0.0f;
        g_aLimelightPartsPhone[118].flWidth = 1.0f;
        g_aLimelightPartsPhone[118].flHeight = 5.0f;
        g_aLimelightPartsPhone[118].nUvPaletteIndex = 118;
        g_aLimelightPartsPhone[119].nEnabled = 1;
        g_aLimelightPartsPhone[119].nUvPaletteIndex = 119;
        g_aLimelightPartsPhone[120].nEnabled = 1;
        g_aLimelightPartsPhone[120].nUvPaletteIndex = 120;
        g_aLimelightPartsPhone[121].nEnabled = 1;
        g_aLimelightPartsPhone[121].nUvPaletteIndex = 121;
        g_aLimelightPartsPhone[122].nEnabled = 1;
        g_aLimelightPartsPhone[122].flX = 0.0f;
        g_aLimelightPartsPhone[122].flY = 0.0f;
        g_aLimelightPartsPhone[122].flWidth = 1.0f;
        g_aLimelightPartsPhone[122].flHeight = 5.0f;
        g_aLimelightPartsPhone[122].nUvPaletteIndex = 122;
        g_aLimelightPartsPhone[123].nEnabled = 1;
        g_aLimelightPartsPhone[123].flX = 0.0f;
        g_aLimelightPartsPhone[123].flY = 0.0f;
        g_aLimelightPartsPhone[123].flWidth = 466.0f;
        g_aLimelightPartsPhone[123].flHeight = 22.0f;
        g_aLimelightPartsPhone[123].nUvPaletteIndex = 123;
        g_aLimelightPartsPhone[124].nEnabled = 1;
        g_aLimelightPartsPhone[124].flX = 0.0f;
        g_aLimelightPartsPhone[124].flY = 0.0f;
        g_aLimelightPartsPhone[124].flWidth = 18.0f;
        g_aLimelightPartsPhone[124].flHeight = 24.0f;
        g_aLimelightPartsPhone[124].nUvPaletteIndex = 124;
        g_aLimelightPartsPhone[125].nEnabled = 1;
        g_aLimelightPartsPhone[125].flX = 0.0f;
        g_aLimelightPartsPhone[125].flY = 0.0f;
        g_aLimelightPartsPhone[125].flWidth = 18.0f;
        g_aLimelightPartsPhone[125].flHeight = 24.0f;
        g_aLimelightPartsPhone[125].nUvPaletteIndex = 125;
        g_aLimelightPartsPhone[126].nEnabled = 1;
        g_aLimelightPartsPhone[126].nUvPaletteIndex = 126;
        g_aLimelightPartsPhone[127].nEnabled = 1;
        g_aLimelightPartsPhone[127].nUvPaletteIndex = 127;
        g_aLimelightPartsPhone[128].nEnabled = 1;
        g_aLimelightPartsPhone[128].nUvPaletteIndex = 128;
        g_aLimelightPartsPhone[129].nEnabled = 1;
        g_aLimelightPartsPhone[129].nUvPaletteIndex = 129;
        g_aLimelightPartsPhone[130].nEnabled = 1;
        g_aLimelightPartsPhone[130].flX = 0.0f;
        g_aLimelightPartsPhone[130].flY = 0.0f;
        g_aLimelightPartsPhone[130].flWidth = 18.0f;
        g_aLimelightPartsPhone[130].flHeight = 24.0f;
        g_aLimelightPartsPhone[130].nUvPaletteIndex = 130;
        g_aLimelightPartsPhone[131].nEnabled = 1;
        g_aLimelightPartsPhone[131].nUvPaletteIndex = 131;
        g_aLimelightPartsPhone[132].nEnabled = 1;
        g_aLimelightPartsPhone[132].nUvPaletteIndex = 132;
        g_aLimelightPartsPhone[133].nEnabled = 1;
        g_aLimelightPartsPhone[133].flX = 0.0f;
        g_aLimelightPartsPhone[133].flY = 0.0f;
        g_aLimelightPartsPhone[133].flWidth = 18.0f;
        g_aLimelightPartsPhone[133].flHeight = 24.0f;
        g_aLimelightPartsPhone[133].nUvPaletteIndex = 133;
        g_aLimelightPartsPhone[134].nEnabled = 1;
        g_aLimelightPartsPhone[134].flX = 0.0f;
        g_aLimelightPartsPhone[134].flY = 0.0f;
        g_aLimelightPartsPhone[134].flWidth = 6.0f;
        g_aLimelightPartsPhone[134].flHeight = 2e+01f;
        g_aLimelightPartsPhone[134].nUvPaletteIndex = 134;
        g_aLimelightPartsPhone[135].nEnabled = 1;
        g_aLimelightPartsPhone[135].flX = 0.0f;
        g_aLimelightPartsPhone[135].flY = 0.0f;
        g_aLimelightPartsPhone[135].flWidth = 16.0f;
        g_aLimelightPartsPhone[135].flHeight = 2e+01f;
        g_aLimelightPartsPhone[135].nUvPaletteIndex = 135;
        g_aLimelightPartsPhone[136].nEnabled = 1;
        g_aLimelightPartsPhone[136].nUvPaletteIndex = 136;
        g_aLimelightPartsPhone[137].nEnabled = 1;
        g_aLimelightPartsPhone[137].nUvPaletteIndex = 137;
        g_aLimelightPartsPhone[138].nEnabled = 1;
        g_aLimelightPartsPhone[138].flY = 0.0f;
        g_aLimelightPartsPhone[138].nUvPaletteIndex = 138;
        g_aLimelightPartsPhone[138].flHeight = 2e+01f;
        g_aLimelightPartsPhone[139].nEnabled = 1;
        g_aLimelightPartsPhone[139].nUvPaletteIndex = 139;
        g_aLimelightPartsPhone[138].flX = 0.0f;
        g_aLimelightPartsPhone[138].flWidth = 16.0f;
        g_aLimelightPartsPhone[140].nEnabled = 1;
        g_aLimelightPartsPhone[140].nUvPaletteIndex = 140;
        g_aLimelightPartsPhone[141].nUvPaletteIndex = 141;
        g_aLimelightPartsPhone[141].nEnabled = 1;
        g_aLimelightPartsPhone[141].flY = 0.0f;
        g_aLimelightPartsPhone[141].flHeight = 2e+01f;
        g_aLimelightPartsPhone[142].nEnabled = 1;
        g_aLimelightPartsPhone[142].nUvPaletteIndex = 142;
        g_aLimelightPartsPhone[141].flX = 0.0f;
        g_aLimelightPartsPhone[141].flWidth = 16.0f;
        g_aLimelightPartsPhone[143].nEnabled = 1;
        g_aLimelightPartsPhone[143].nUvPaletteIndex = 143;
        g_aLimelightPartsPhone[144].nEnabled = 1;
        g_aLimelightPartsPhone[144].nUvPaletteIndex = 144;
        g_aLimelightPartsPhone[145].nEnabled = 1;
        g_aLimelightPartsPhone[145].flX = 0.0f;
        g_aLimelightPartsPhone[145].flY = 0.0f;
        g_aLimelightPartsPhone[145].flWidth = 18.0f;
        g_aLimelightPartsPhone[145].flHeight = 2e+01f;
        g_aLimelightPartsPhone[145].nUvPaletteIndex = 145;
        g_aLimelightPartsPhone[146].nUvPaletteIndex = 146;
        g_aLimelightPartsPhone[146].nEnabled = 1;
        g_aLimelightPartsPhone[146].flY = 0.0f;
        g_aLimelightPartsPhone[146].flHeight = 24.0f;
        g_aLimelightPartsPhone[147].nEnabled = 1;
        g_aLimelightPartsPhone[147].nUvPaletteIndex = 147;
        g_aLimelightPartsPhone[146].flX = 0.0f;
        g_aLimelightPartsPhone[146].flWidth = 18.0f;
        g_aLimelightPartsPhone[148].nEnabled = 1;
        g_aLimelightPartsPhone[148].nUvPaletteIndex = 148;
        g_aLimelightPartsPhone[149].nUvPaletteIndex = 149;
        g_aLimelightPartsPhone[149].nEnabled = 1;
        g_aLimelightPartsPhone[149].flY = 0.0f;
        g_aLimelightPartsPhone[149].flHeight = 24.0f;
        g_aLimelightPartsPhone[150].nEnabled = 1;
        g_aLimelightPartsPhone[150].nUvPaletteIndex = 150;
        g_aLimelightPartsPhone[149].flX = 0.0f;
        g_aLimelightPartsPhone[149].flWidth = 18.0f;
        g_aLimelightPartsPhone[151].nEnabled = 1;
        g_aLimelightPartsPhone[151].nUvPaletteIndex = 151;
        g_aLimelightPartsPhone[152].nEnabled = 1;
        g_aLimelightPartsPhone[152].nUvPaletteIndex = 152;
        g_aLimelightPartsPhone[153].nEnabled = 1;
        g_aLimelightPartsPhone[153].nUvPaletteIndex = 153;
        g_aLimelightPartsPhone[154].nEnabled = 1;
        g_aLimelightPartsPhone[154].flX = 0.0f;
        g_aLimelightPartsPhone[154].flY = 0.0f;
        g_aLimelightPartsPhone[154].flWidth = 18.0f;
        g_aLimelightPartsPhone[154].flHeight = 24.0f;
        g_aLimelightPartsPhone[154].nUvPaletteIndex = 154;
        g_aLimelightPartsPhone[155].nEnabled = 1;
        g_aLimelightPartsPhone[155].nUvPaletteIndex = 155;
        g_aLimelightPartsPhone[156].nEnabled = 1;
        g_aLimelightPartsPhone[156].flX = 0.0f;
        g_aLimelightPartsPhone[156].flY = 0.0f;
        g_aLimelightPartsPhone[156].nUvPaletteIndex = 156;
        g_aLimelightPartsPhone[157].nEnabled = 1;
        g_aLimelightPartsPhone[157].flX = 0.0f;
        g_aLimelightPartsPhone[157].flY = 0.0f;
        g_aLimelightPartsPhone[157].flWidth = 16.0f;
        g_aLimelightPartsPhone[157].flHeight = 2e+01f;
        g_aLimelightPartsPhone[157].nUvPaletteIndex = 157;
        g_aLimelightPartsPhone[158].nEnabled = 1;
        g_aLimelightPartsPhone[158].nUvPaletteIndex = 158;
        g_aLimelightPartsPhone[159].nEnabled = 1;
        g_aLimelightPartsPhone[159].nUvPaletteIndex = 159;
        g_aLimelightPartsPhone[160].nEnabled = 1;
        g_aLimelightPartsPhone[160].nUvPaletteIndex = 160;
        g_aLimelightPartsPhone[161].nEnabled = 1;
        g_aLimelightPartsPhone[161].nUvPaletteIndex = 161;
        g_aLimelightPartsPhone[162].nEnabled = 1;
        g_aLimelightPartsPhone[162].flX = 0.0f;
        g_aLimelightPartsPhone[162].flY = 0.0f;
        g_aLimelightPartsPhone[162].flWidth = 16.0f;
        g_aLimelightPartsPhone[162].flHeight = 2e+01f;
        g_aLimelightPartsPhone[162].nUvPaletteIndex = 162;
        g_aLimelightPartsPhone[163].nEnabled = 1;
        g_aLimelightPartsPhone[163].nUvPaletteIndex = 163;
        g_aLimelightPartsPhone[164].nEnabled = 1;
        g_aLimelightPartsPhone[164].nUvPaletteIndex = 164;
        g_aLimelightPartsPhone[165].nEnabled = 1;
        g_aLimelightPartsPhone[165].flX = 0.0f;
        g_aLimelightPartsPhone[165].flY = 0.0f;
        g_aLimelightPartsPhone[165].flWidth = 16.0f;
        g_aLimelightPartsPhone[165].flHeight = 2e+01f;
        g_aLimelightPartsPhone[165].nUvPaletteIndex = 165;
        g_aLimelightPartsPhone[166].nEnabled = 1;
        g_aLimelightPartsPhone[166].nUvPaletteIndex = 166;
        g_aLimelightPartsPhone[167].nEnabled = 1;
        g_aLimelightPartsPhone[167].flX = 0.0f;
        g_aLimelightPartsPhone[167].flY = 0.0f;
        g_aLimelightPartsPhone[167].nUvPaletteIndex = 167;
        g_aLimelightPartsPhone[168].nEnabled = 1;
        g_aLimelightPartsPhone[168].flX = 0.0f;
        g_aLimelightPartsPhone[168].flY = 0.0f;
        g_aLimelightPartsPhone[168].flWidth = 12.0f;
        g_aLimelightPartsPhone[168].flHeight = 16.0f;
        g_aLimelightPartsPhone[168].nUvPaletteIndex = 168;
        g_aLimelightPartsPhone[169].nEnabled = 1;
        g_aLimelightPartsPhone[169].nUvPaletteIndex = 169;
        g_aLimelightPartsPhone[170].nEnabled = 1;
        g_aLimelightPartsPhone[170].flX = 0.0f;
        g_aLimelightPartsPhone[170].flY = 0.0f;
        g_aLimelightPartsPhone[170].flWidth = 12.0f;
        g_aLimelightPartsPhone[170].flHeight = 16.0f;
        g_aLimelightPartsPhone[170].nUvPaletteIndex = 170;
        g_aLimelightPartsPhone[171].nEnabled = 1;
        g_aLimelightPartsPhone[171].nUvPaletteIndex = 171;
        g_aLimelightPartsPhone[172].nEnabled = 1;
        g_aLimelightPartsPhone[172].nUvPaletteIndex = 172;
        g_aLimelightPartsPhone[173].nEnabled = 1;
        g_aLimelightPartsPhone[173].flX = 0.0f;
        g_aLimelightPartsPhone[173].flY = 0.0f;
        g_aLimelightPartsPhone[173].flWidth = 12.0f;
        g_aLimelightPartsPhone[173].flHeight = 16.0f;
        g_aLimelightPartsPhone[174].nEnabled = 1;
        g_aLimelightPartsPhone[173].nUvPaletteIndex = 173;
        g_aLimelightPartsPhone[175].nEnabled = 1;
        g_aLimelightPartsPhone[174].nUvPaletteIndex = 174;
        g_aLimelightPartsPhone[176].nEnabled = 1;
        g_aLimelightPartsPhone[175].nUvPaletteIndex = 175;
        g_aLimelightPartsPhone[177].nEnabled = 1;
        g_aLimelightPartsPhone[176].nUvPaletteIndex = 176;
        g_aLimelightPartsPhone[177].nUvPaletteIndex = 177;
        g_aLimelightPartsPhone[178].flY = 0.0f;
        g_aLimelightPartsPhone[179].nEnabled = 1;
        g_aLimelightPartsPhone[178].nUvPaletteIndex = 178;
        g_aLimelightPartsPhone[179].nUvPaletteIndex = 179;
        g_aLimelightPartsPhone[178].flWidth = 2.0f;
        g_aLimelightPartsPhone[180].nEnabled = 1;
        g_aLimelightPartsPhone[180].nUvPaletteIndex = 180;
        g_aLimelightPartsPhone[181].nUvPaletteIndex = 181;
        g_aLimelightPartsPhone[181].flY = 0.0f;
        g_aLimelightPartsPhone[182].nEnabled = 1;
        g_aLimelightPartsPhone[181].flWidth = 12.0f;
        g_aLimelightPartsPhone[183].nEnabled = 1;
        g_aLimelightPartsPhone[182].nUvPaletteIndex = 182;
        g_aLimelightPartsPhone[184].nEnabled = 1;
        g_aLimelightPartsPhone[183].nUvPaletteIndex = 183;
        g_aLimelightPartsPhone[184].nUvPaletteIndex = 184;
        g_aLimelightPartsPhone[178].nEnabled = 1;
        g_aLimelightPartsPhone[178].flHeight = 16.0f;
        g_aLimelightPartsPhone[181].nEnabled = 1;
        g_aLimelightPartsPhone[181].flHeight = 16.0f;
        g_aLimelightPartsPhone[185].nEnabled = 1;
        g_aLimelightPartsPhone[185].nUvPaletteIndex = 185;
        g_aLimelightPartsPhone[178].flX = 0.0f;
        g_aLimelightPartsPhone[181].flX = 0.0f;
        g_aLimelightPartsPhone[186].nEnabled = 1;
        g_aLimelightPartsPhone[187].nEnabled = 1;
        g_aLimelightPartsPhone[186].nUvPaletteIndex = 186;
        g_aLimelightPartsPhone[187].nUvPaletteIndex = 187;
        g_aLimelightPartsPhone[186].flX = 0.0f;
        g_aLimelightPartsPhone[188].nEnabled = 1;
        g_aLimelightPartsPhone[188].nUvPaletteIndex = 188;
        g_aLimelightPartsPhone[186].flY = 0.0f;
        g_aLimelightPartsPhone[186].flWidth = 12.0f;
        g_aLimelightPartsPhone[186].flHeight = 16.0f;
        g_aLimelightPartsPhone[189].nEnabled = 1;
        g_aLimelightPartsPhone[189].flX = 0.0f;
        g_aLimelightPartsPhone[189].flY = 0.0f;
        g_aLimelightPartsPhone[189].flWidth = 12.0f;
        g_aLimelightPartsPhone[189].flHeight = 16.0f;
        g_aLimelightPartsPhone[189].nUvPaletteIndex = 189;
        g_aLimelightPartsPhone[190].nEnabled = 1;
        g_aLimelightPartsPhone[190].nUvPaletteIndex = 190;
        g_aLimelightPartsPhone[191].nEnabled = 1;
        g_aLimelightPartsPhone[191].nUvPaletteIndex = 191;
        g_aLimelightPartsPhone[192].nEnabled = 1;
        g_aLimelightPartsPhone[192].flX = 17.0f;
        g_aLimelightPartsPhone[192].flY = 15.0f;
        g_aLimelightPartsPhone[192].flWidth = 34.0f;
        g_aLimelightPartsPhone[192].flHeight = 3e+01f;
        g_aLimelightPartsPhone[192].nUvPaletteIndex = 192;
        g_aLimelightPartsPhone[193].nEnabled = 1;
        g_aLimelightPartsPhone[193].flX = 14.0f;
        g_aLimelightPartsPhone[193].flY = 15.0f;
        g_aLimelightPartsPhone[193].flWidth = 28.0f;
        g_aLimelightPartsPhone[193].flHeight = 3e+01f;
        g_aLimelightPartsPhone[193].nUvPaletteIndex = 193;
        g_aLimelightPartsPhone[194].nEnabled = 1;
        g_aLimelightPartsPhone[194].flWidth = 34.0f;
        g_aLimelightPartsPhone[194].nUvPaletteIndex = 194;
        g_aLimelightPartsPhone[195].nEnabled = 1;
        g_aLimelightPartsPhone[195].flX = 26.0f;
        g_aLimelightPartsPhone[195].flY = 15.0f;
        g_aLimelightPartsPhone[195].flWidth = 52.0f;
        g_aLimelightPartsPhone[195].flHeight = 3e+01f;
        g_aLimelightPartsPhone[195].nUvPaletteIndex = 195;
        g_aLimelightPartsPhone[196].nEnabled = 1;
        g_aLimelightPartsPhone[196].nUvPaletteIndex = 196;
        g_aLimelightPartsPhone[194].flHeight = 3e+01f;
        g_aLimelightPartsPhone[197].flWidth = 52.0f;
        g_aLimelightPartsPhone[197].nUvPaletteIndex = 197;
        g_aLimelightPartsPhone[198].nEnabled = 1;
        g_aLimelightPartsPhone[198].flX = 0.0f;
        g_aLimelightPartsPhone[198].flY = 0.0f;
        g_aLimelightPartsPhone[198].flWidth = 553.0f;
        g_aLimelightPartsPhone[198].flHeight = 6e+01f;
        g_aLimelightPartsPhone[198].nUvPaletteIndex = 198;
        g_aLimelightPartsPhone[199].nEnabled = 1;
        g_aLimelightPartsPhone[199].flX = 0.0f;
        g_aLimelightPartsPhone[199].flY = 0.0f;
        g_aLimelightPartsPhone[199].flWidth = 22.0f;
        g_aLimelightPartsPhone[199].flHeight = 964.0f;
        g_aLimelightPartsPhone[199].nUvPaletteIndex = 199;
        g_aLimelightPartsPhone[200].nEnabled = 1;
        g_aLimelightPartsPhone[200].flX = 0.0f;
        g_aLimelightPartsPhone[200].flY = 0.0f;
        g_aLimelightPartsPhone[200].flWidth = 166.0f;
        g_aLimelightPartsPhone[200].flHeight = 28.0f;
        g_aLimelightPartsPhone[201].nEnabled = 1;
        g_aLimelightPartsPhone[200].nUvPaletteIndex = 200;
        g_aLimelightPartsPhone[201].nUvPaletteIndex = 201;
        g_aLimelightPartsPhone[202].flWidth = 156.0f;
        g_aLimelightPartsPhone[203].nEnabled = 1;
        g_aLimelightPartsPhone[203].flX = 0.0f;
        g_aLimelightPartsPhone[203].flY = 0.0f;
        g_aLimelightPartsPhone[202].nUvPaletteIndex = 202;
        g_aLimelightPartsPhone[203].flWidth = 156.0f;
        g_aLimelightPartsPhone[203].flHeight = 4e+01f;
        g_aLimelightPartsPhone[204].nEnabled = 1;
        g_aLimelightPartsPhone[204].flX = 0.0f;
        g_aLimelightPartsPhone[204].flY = 0.0f;
        g_aLimelightPartsPhone[203].nUvPaletteIndex = 203;
        g_aLimelightPartsPhone[204].flWidth = 33.0f;
        g_aLimelightPartsPhone[204].flHeight = 22.0f;
        g_aLimelightPartsPhone[206].nEnabled = 1;
        g_aLimelightPartsPhone[206].flX = 0.0f;
        g_aLimelightPartsPhone[206].flY = 0.0f;
        g_aLimelightPartsPhone[204].nUvPaletteIndex = 204;
        g_aLimelightPartsPhone[206].flWidth = 504.0f;
        g_aLimelightPartsPhone[206].flHeight = 37.0f;
        g_aLimelightPartsPhone[207].nEnabled = 1;
        g_aLimelightPartsPhone[207].flX = 0.0f;
        g_aLimelightPartsPhone[207].flY = 0.0f;
        g_aLimelightPartsPhone[205].flWidth = 194.0f;
        g_aLimelightPartsPhone[207].flWidth = 504.0f;
        g_aLimelightPartsPhone[207].flHeight = 1.4e+02f;
        g_aLimelightPartsPhone[205].flHeight = 28.0f;
        g_aLimelightPartsPhone[208].nEnabled = 1;
        g_aLimelightPartsPhone[205].nUvPaletteIndex = 205;
        g_aLimelightPartsPhone[209].nEnabled = 1;
        g_aLimelightPartsPhone[206].nUvPaletteIndex = 231;
        g_aLimelightPartsPhone[209].nUvPaletteIndex = 206;
        g_aLimelightPartsPhone[194].flX = 17.0f;
        g_aLimelightPartsPhone[210].flWidth = 504.0f;
        g_aLimelightPartsPhone[210].flHeight = 111.0f;
        g_aLimelightPartsPhone[194].flY = 15.0f;
        g_aLimelightPartsPhone[197].nEnabled = 1;
        g_aLimelightPartsPhone[207].nUvPaletteIndex = 23;
        g_aLimelightPartsPhone[210].nUvPaletteIndex = 23;
        g_aLimelightPartsPhone[211].nEnabled = 1;
        g_aLimelightPartsPhone[197].flX = 26.0f;
        g_aLimelightPartsPhone[197].flY = 15.0f;
        g_aLimelightPartsPhone[197].flHeight = 3e+01f;
        g_aLimelightPartsPhone[202].nEnabled = 1;
        g_aLimelightPartsPhone[205].nEnabled = 1;
        g_aLimelightPartsPhone[208].nUvPaletteIndex = 24;
        g_aLimelightPartsPhone[210].nEnabled = 1;
        g_aLimelightPartsPhone[211].nUvPaletteIndex = 24;
        g_aLimelightPartsPhone[212].nEnabled = 1;
        g_aLimelightPartsPhone[212].flX = 0.0f;
        g_aLimelightPartsPhone[212].flY = 0.0f;
        g_aLimelightPartsPhone[212].flWidth = 1e+02f;
        g_aLimelightPartsPhone[212].flHeight = 1e+02f;
        g_aLimelightPartsPhone[212].nUvPaletteIndex = 207;
        g_aLimelightPartsPhone[213].nEnabled = 1;
        g_aLimelightPartsPhone[213].nUvPaletteIndex = 208;
        g_aLimelightPartsPhone[214].nEnabled = 1;
        g_aLimelightPartsPhone[214].flX = 0.0f;
        g_aLimelightPartsPhone[214].flY = 0.0f;
        g_aLimelightPartsPhone[214].flWidth = 32.0f;
        g_aLimelightPartsPhone[214].flHeight = 32.0f;
        g_aLimelightPartsPhone[214].nUvPaletteIndex = 209;
        g_aLimelightPartsPhone[215].nEnabled = 1;
        g_aLimelightPartsPhone[215].flX = 0.0f;
        g_aLimelightPartsPhone[215].flY = 0.0f;
        g_aLimelightPartsPhone[215].flWidth = 4e+01f;
        g_aLimelightPartsPhone[215].flHeight = 48.0f;
        g_aLimelightPartsPhone[215].nUvPaletteIndex = 210;
        g_aLimelightPartsPhone[216].nEnabled = 1;
        g_aLimelightPartsPhone[216].nUvPaletteIndex = 211;
        g_aLimelightPartsPhone[217].nEnabled = 1;
        g_aLimelightPartsPhone[217].nUvPaletteIndex = 212;
        g_aLimelightPartsPhone[218].nEnabled = 1;
        g_aLimelightPartsPhone[218].nUvPaletteIndex = 213;
        g_aLimelightPartsPhone[219].nEnabled = 1;
        g_aLimelightPartsPhone[219].nUvPaletteIndex = 214;
        g_aLimelightPartsPhone[220].nEnabled = 1;
        g_aLimelightPartsPhone[220].nUvPaletteIndex = 215;
        g_aLimelightPartsPhone[221].nEnabled = 1;
        g_aLimelightPartsPhone[221].nUvPaletteIndex = 216;
        g_aLimelightPartsPhone[222].nEnabled = 1;
        g_aLimelightPartsPhone[222].nUvPaletteIndex = 217;
        g_aLimelightPartsPhone[223].nEnabled = 1;
        g_aLimelightPartsPhone[223].nUvPaletteIndex = 218;
        g_aLimelightPartsPhone[224].nEnabled = 1;
        g_aLimelightPartsPhone[224].nUvPaletteIndex = 219;
        g_aLimelightPartsPhone[225].nEnabled = 1;
        g_aLimelightPartsPhone[225].flX = 0.0f;
        g_aLimelightPartsPhone[225].flY = 0.0f;
        g_aLimelightPartsPhone[225].flWidth = 32.0f;
        g_aLimelightPartsPhone[225].flHeight = 4e+01f;
        g_aLimelightPartsPhone[225].nUvPaletteIndex = 220;
        g_aLimelightPartsPhone[226].nEnabled = 1;
        g_aLimelightPartsPhone[226].nUvPaletteIndex = 221;
        g_aLimelightPartsPhone[227].nEnabled = 1;
        g_aLimelightPartsPhone[227].nUvPaletteIndex = 222;
        g_aLimelightPartsPhone[228].nEnabled = 1;
        g_aLimelightPartsPhone[228].nUvPaletteIndex = 223;
        g_aLimelightPartsPhone[229].nEnabled = 1;
        g_aLimelightPartsPhone[229].nUvPaletteIndex = 224;
        g_aLimelightPartsPhone[230].nEnabled = 1;
        g_aLimelightPartsPhone[230].nUvPaletteIndex = 225;
        g_aLimelightPartsPhone[231].nEnabled = 1;
        g_aLimelightPartsPhone[231].nUvPaletteIndex = 226;
        g_aLimelightPartsPhone[232].nEnabled = 1;
        g_aLimelightPartsPhone[232].nUvPaletteIndex = 227;
        g_aLimelightPartsPhone[233].nEnabled = 1;
        g_aLimelightPartsPhone[233].nUvPaletteIndex = 228;
        g_aLimelightPartsPhone[234].nEnabled = 1;
        g_aLimelightPartsPhone[234].nUvPaletteIndex = 229;
        g_aLimelightPartsPhone[235].nEnabled = 1;
        g_aLimelightPartsPhone[235].flX = 0.0f;
        g_aLimelightPartsPhone[235].flY = 0.0f;
        g_aLimelightPartsPhone[235].flWidth = 8.0f;
        g_aLimelightPartsPhone[235].flHeight = 4e+01f;
        g_aLimelightPartsPhone[235].nUvPaletteIndex = 230;
        g_aLimelightPartsPhone[236].nEnabled = 1;
        g_aLimelightPartsPhone[236].flX = 0.0f;
        g_aLimelightPartsPhone[236].flY = 0.0f;
        g_aLimelightPartsPhone[236].flWidth = 148.0f;
        g_aLimelightPartsPhone[236].flHeight = 22.0f;
        g_aLimelightPartsPhone[236].nUvPaletteIndex = 232;
        g_aLimelightPartsPhone[237].nEnabled = 1;
        g_aLimelightPartsPhone[237].flWidth = 148.0f;
        g_aLimelightPartsPhone[237].flHeight = 22.0f;
        g_aLimelightPartsPhone[237].nUvPaletteIndex = 233;
        g_aLimelightPartsPhone[238].nEnabled = 1;
        g_aLimelightPartsPhone[238].nUvPaletteIndex = 234;
        g_aLimelightPartsPhone[239].nEnabled = 1;
        g_aLimelightPartsPhone[239].nUvPaletteIndex = 235;
        g_aLimelightPartsPhone[240].nEnabled = 1;
        g_aLimelightPartsPhone[240].flX = 0.0f;
        g_aLimelightPartsPhone[240].flY = 0.0f;
        g_aLimelightPartsPhone[240].flWidth = 2e+01f;
        g_aLimelightPartsPhone[240].flHeight = 2e+01f;
        g_aLimelightPartsPhone[240].nUvPaletteIndex = 236;
        g_aLimelightPartsPhone[241].nEnabled = 1;
        g_aLimelightPartsPhone[241].nUvPaletteIndex = 237;
        g_aLimelightPartsPhone[242].nEnabled = 1;
        g_aLimelightPartsPhone[242].flWidth = 16.0f;
        g_aLimelightPartsPhone[242].flHeight = 18.0f;
        g_aLimelightPartsPhone[242].nUvPaletteIndex = 238;
        g_aLimelightPartsPhone[243].nEnabled = 1;
        g_aLimelightPartsPhone[243].nUvPaletteIndex = 239;
        g_aLimelightPartsPhone[244].nEnabled = 1;
        g_aLimelightPartsPhone[244].nUvPaletteIndex = 240;
        g_aLimelightPartsPhone[245].nEnabled = 1;
        g_aLimelightPartsPhone[245].flWidth = 16.0f;
        g_aLimelightPartsPhone[245].flHeight = 18.0f;
        g_aLimelightPartsPhone[246].nEnabled = 1;
        g_aLimelightPartsPhone[245].nUvPaletteIndex = 241;
        g_aLimelightPartsPhone[247].nEnabled = 1;
        g_aLimelightPartsPhone[246].nUvPaletteIndex = 242;
        g_aLimelightPartsPhone[248].nEnabled = 1;
        g_aLimelightPartsPhone[247].nUvPaletteIndex = 243;
        g_aLimelightPartsPhone[249].nEnabled = 1;
        g_aLimelightPartsPhone[248].nUvPaletteIndex = 244;
        g_aLimelightPartsPhone[249].nUvPaletteIndex = 245;
        g_aLimelightPartsPhone[250].nEnabled = 1;
        g_aLimelightPartsPhone[250].flWidth = 16.0f;
        g_aLimelightPartsPhone[250].flHeight = 18.0f;
        g_aLimelightPartsPhone[250].nUvPaletteIndex = 246;
        g_aLimelightPartsPhone[251].nEnabled = 1;
        g_aLimelightPartsPhone[251].flX = 0.0f;
        g_aLimelightPartsPhone[251].flY = 0.0f;
        g_aLimelightPartsPhone[251].flWidth = 4.0f;
        g_aLimelightPartsPhone[251].flHeight = 18.0f;
        g_aLimelightPartsPhone[251].nUvPaletteIndex = 247;
        g_aLimelightPartsPhone[252].nEnabled = 1;
        g_aLimelightPartsPhone[252].nUvPaletteIndex = 248;
        g_aLimelightPartsPhone[253].nEnabled = 1;
        g_aLimelightPartsPhone[253].flWidth = 16.0f;
        g_aLimelightPartsPhone[253].flHeight = 18.0f;
        g_aLimelightPartsPhone[253].nUvPaletteIndex = 249;
        g_aLimelightPartsPhone[254].nEnabled = 1;
        g_aLimelightPartsPhone[254].flX = 0.0f;
        g_aLimelightPartsPhone[254].flY = 0.0f;
        g_aLimelightPartsPhone[254].flWidth = 462.0f;
        g_aLimelightPartsPhone[254].flHeight = 1.0f;
        g_aLimelightPartsPhone[254].nUvPaletteIndex = 250;
        g_aLimelightPartsAnchorPhone[2].x = 263.0f;
        g_aLimelightPartsAnchorPhone[2].y = 937.0f;
        const S_VECTOR2 savedAnchor = g_aLimelightPartsAnchorPhone[2];
        g_aLimelightPartsAnchorPhone[1].x = 0.0f;
        g_aLimelightPartsAnchorPhone[1].y = 0.0f;
        g_aLimelightPartsAnchorPhone[4].x = 116.0f;
        g_aLimelightPartsAnchorPhone[4].y = 86.0f;
        g_aLimelightPartsAnchorPhone[3].x = 567.0f;
        g_aLimelightPartsAnchorPhone[3].y = 914.0f;
        g_aLimelightPartsAnchorPhone[6].x = 116.0f;
        g_aLimelightPartsAnchorPhone[6].y = 142.0f;
        g_aLimelightPartsAnchorPhone[5].x = 652.0f;
        g_aLimelightPartsAnchorPhone[5].y = 86.0f;
        g_aLimelightPartsAnchorPhone[8].x = 116.0f;
        g_aLimelightPartsAnchorPhone[8].y = 3.4e+02f;
        g_aLimelightPartsAnchorPhone[7].x = 652.0f;
        g_aLimelightPartsAnchorPhone[7].y = 142.0f;
        g_aLimelightPartsAnchorPhone[10].x = 116.0f;
        g_aLimelightPartsAnchorPhone[10].y = 378.0f;
        g_aLimelightPartsAnchorPhone[9].x = 652.0f;
        g_aLimelightPartsAnchorPhone[9].y = 3.4e+02f;
        g_aLimelightPartsAnchorPhone[12].x = 116.0f;
        g_aLimelightPartsAnchorPhone[12].y = 434.0f;
        g_aLimelightPartsAnchorPhone[11].x = 652.0f;
        g_aLimelightPartsAnchorPhone[11].y = 378.0f;
        g_aLimelightPartsAnchorPhone[14].x = 116.0f;
        g_aLimelightPartsAnchorPhone[14].y = 898.0f;
        g_aLimelightPartsAnchorPhone[13].x = 652.0f;
        g_aLimelightPartsAnchorPhone[13].y = 434.0f;
        g_aLimelightPartsAnchorPhone[16].x = 374.0f;
        g_aLimelightPartsAnchorPhone[16].y = 892.0f;
        g_aLimelightPartsAnchorPhone[15].x = 652.0f;
        g_aLimelightPartsAnchorPhone[15].y = 898.0f;
        g_aLimelightPartsAnchorPhone[18].x = 132.0f;
        g_aLimelightPartsAnchorPhone[18].y = 448.0f;
        g_aLimelightPartsAnchorPhone[17].x = 3.9e+02f;
        g_aLimelightPartsAnchorPhone[17].y = 892.0f;
        g_aLimelightPartsAnchorPhone[20].x = 132.0f;
        g_aLimelightPartsAnchorPhone[20].y = 732.0f;
        g_aLimelightPartsAnchorPhone[19].x = 132.0f;
        g_aLimelightPartsAnchorPhone[19].y = 478.0f;
        g_aLimelightPartsAnchorPhone[22].x = 132.0f;
        g_aLimelightPartsAnchorPhone[22].y = 788.0f;
        g_aLimelightPartsAnchorPhone[21].x = 132.0f;
        g_aLimelightPartsAnchorPhone[21].y = 758.0f;
        g_aLimelightPartsAnchorPhone[24].x = 132.0f;
        g_aLimelightPartsAnchorPhone[24].y = 154.0f;
        g_aLimelightPartsAnchorPhone[23].x = 132.0f;
        g_aLimelightPartsAnchorPhone[23].y = 8.7e+02f;
        g_aLimelightPartsAnchorPhone[26].x = 358.0f;
        g_aLimelightPartsAnchorPhone[26].y = 155.0f;
        g_aLimelightPartsAnchorPhone[25].x = 137.0f;
        g_aLimelightPartsAnchorPhone[25].y = 157.0f;
        g_aLimelightPartsAnchorPhone[28].x = 4.2e+02f;
        g_aLimelightPartsAnchorPhone[28].y = 204.0f;
        g_aLimelightPartsAnchorPhone[27].x = 358.0f;
        g_aLimelightPartsAnchorPhone[27].y = 1.8e+02f;
        g_aLimelightPartsAnchorPhone[29].x = 612.0f;
        g_aLimelightPartsAnchorPhone[29].y = 204.0f;
        g_aLimelightPartsAnchorPhone[32].x = 5e+02f;
        g_aLimelightPartsAnchorPhone[32].y = 222.0f;
        g_aLimelightPartsAnchorPhone[31].x = 493.0f;
        g_aLimelightPartsAnchorPhone[31].y = 222.0f;
        g_aLimelightPartsAnchorPhone[34].x = 358.0f;
        g_aLimelightPartsAnchorPhone[34].y = 234.0f;
        g_aLimelightPartsAnchorPhone[33].x = 538.0f;
        g_aLimelightPartsAnchorPhone[33].y = 222.0f;
        g_aLimelightPartsAnchorPhone[36].x = 631.0f;
        g_aLimelightPartsAnchorPhone[36].y = 229.0f;
        g_aLimelightPartsAnchorPhone[35].x = 4e+02f;
        g_aLimelightPartsAnchorPhone[35].y = 234.0f;
        g_aLimelightPartsAnchorPhone[38].x = 4e+02f;
        g_aLimelightPartsAnchorPhone[38].y = 257.0f;
        g_aLimelightPartsAnchorPhone[37].x = 358.0f;
        g_aLimelightPartsAnchorPhone[37].y = 257.0f;
        g_aLimelightPartsAnchorPhone[40].x = 358.0f;
        g_aLimelightPartsAnchorPhone[40].y = 297.0f;
        g_aLimelightPartsAnchorPhone[39].x = 631.0f;
        g_aLimelightPartsAnchorPhone[39].y = 253.0f;
        g_aLimelightPartsAnchorPhone[42].x = 599.0f;
        g_aLimelightPartsAnchorPhone[42].y = 318.0f;
        g_aLimelightPartsAnchorPhone[41].x = 599.0f;
        g_aLimelightPartsAnchorPhone[41].y = 318.0f;
        g_aLimelightPartsAnchorPhone[44].x = 308.0f;
        g_aLimelightPartsAnchorPhone[44].y = 541.0f;
        g_aLimelightPartsAnchorPhone[43].x = 413.0f;
        g_aLimelightPartsAnchorPhone[43].y = 391.0f;
        g_aLimelightPartsAnchorPhone[46].x = 319.0f;
        g_aLimelightPartsAnchorPhone[46].y = 626.0f;
        g_aLimelightPartsAnchorPhone[45].x = 358.0f;
        g_aLimelightPartsAnchorPhone[45].y = 522.0f;
        g_aLimelightPartsAnchorPhone[48].x = 203.0f;
        g_aLimelightPartsAnchorPhone[48].y = 495.0f;
        g_aLimelightPartsAnchorPhone[47].x = 151.0f;
        g_aLimelightPartsAnchorPhone[47].y = 491.0f;
        g_aLimelightPartsAnchorPhone[49].x = 222.0f;
        g_aLimelightPartsAnchorPhone[49].y = 523.0f;
        g_aLimelightPartsAnchorPhone[51].x = 222.0f;
        g_aLimelightPartsAnchorPhone[51].y = 549.0f;
        g_aLimelightPartsAnchorPhone[53].x = 222.0f;
        g_aLimelightPartsAnchorPhone[53].y = 575.0f;
        g_aLimelightPartsAnchorPhone[55].x = 222.0f;
        g_aLimelightPartsAnchorPhone[55].y = 601.0f;
        g_aLimelightPartsAnchorPhone[57].x = 222.0f;
        g_aLimelightPartsAnchorPhone[57].y = 627.0f;
        g_aLimelightPartsAnchorPhone[59].x = 222.0f;
        g_aLimelightPartsAnchorPhone[59].y = 653.0f;
        g_aLimelightPartsAnchorPhone[61].x = 222.0f;
        g_aLimelightPartsAnchorPhone[61].y = 685.0f;
        g_aLimelightPartsAnchorPhone[64].x = 477.0f;
        g_aLimelightPartsAnchorPhone[64].y = 491.0f;
        g_aLimelightPartsAnchorPhone[63].x = 152.0f;
        g_aLimelightPartsAnchorPhone[63].y = 719.0f;
        g_aLimelightPartsAnchorPhone[66].x = 548.0f;
        g_aLimelightPartsAnchorPhone[66].y = 523.0f;
        g_aLimelightPartsAnchorPhone[65].x = 529.0f;
        g_aLimelightPartsAnchorPhone[65].y = 495.0f;
        g_aLimelightPartsAnchorPhone[68].x = 548.0f;
        g_aLimelightPartsAnchorPhone[68].y = 549.0f;
        g_aLimelightPartsAnchorPhone[67].x = 478.0f;
        g_aLimelightPartsAnchorPhone[67].y = 537.0f;
        g_aLimelightPhoneAnchorDefault[0].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[0].flY = 0.0f;
        g_aLimelightPhoneAnchorDefault[0].nAnchorMode = 0;
        g_aLimelightPhoneAnchorDefault[1].flX = 8.0f;
        g_aLimelightPhoneAnchorDefault[1].nAnchorMode = 1;
        g_aLimelightPhoneAnchorDefault[2].flX = 312.0f;
        g_aLimelightPhoneAnchorDefault[2].flY = 164.0f;
        g_aLimelightPhoneAnchorDefault[2].nAnchorMode = 1;
        g_aLimelightPhoneAnchorDefault[1].flY = -214.0f;
        g_aLimelightPhoneAnchorDefault[3].flY = -192.0f;
        g_aLimelightPhoneAnchorDefault[3].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[4].flY = -47.0f;
        g_aLimelightPhoneAnchorDefault[4].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[5].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[5].flY = -175.0f;
        g_aLimelightPhoneAnchorDefault[6].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[6].flY = -155.0f;
        g_aLimelightPhoneAnchorDefault[6].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[7].flX = -132.0f;
        g_aLimelightPhoneAnchorDefault[10].flX = 27.0f;
        g_aLimelightPhoneAnchorDefault[8].flY = -142.0f;
        g_aLimelightPhoneAnchorDefault[9].flY = -142.0f;
        g_aLimelightPhoneAnchorDefault[10].flY = -142.0f;
        g_aLimelightPhoneAnchorDefault[11].flY = -1.3e+02f;
        g_aLimelightPhoneAnchorDefault[3].flX = -141.0f;
        g_aLimelightPhoneAnchorDefault[4].flX = 141.0f;
        g_aLimelightPhoneAnchorDefault[5].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[14].flX = 2e+01f;
        g_aLimelightPhoneAnchorDefault[15].flX = 45.0f;
        g_aLimelightPhoneAnchorDefault[12].flX = 16.0f;
        g_aLimelightPhoneAnchorDefault[12].flY = -129.0f;
        g_aLimelightPhoneAnchorDefault[13].flY = -129.0f;
        g_aLimelightPhoneAnchorDefault[14].flY = -129.0f;
        g_aLimelightPhoneAnchorDefault[15].flY = -129.0f;
        g_aLimelightPhoneAnchorDefault[16].flY = -129.0f;
        g_aLimelightPhoneAnchorDefault[18].flY = -129.0f;
        g_aLimelightPhoneAnchorDefault[21].flY = -91.0f;
        g_aLimelightPhoneAnchorDefault[8].flX = -33.0f;
        g_aLimelightPhoneAnchorDefault[11].flX = -33.0f;
        g_aLimelightPhoneAnchorDefault[18].flX = -33.0f;
        g_aLimelightPhoneAnchorDefault[21].flX = -33.0f;
        g_aLimelightPhoneAnchorDefault[22].flX = -33.0f;
        g_aLimelightPhoneAnchorDefault[24].flY = 29.0f;
        g_aLimelightPhoneAnchorDefault[25].flY = 43.0f;
        g_aLimelightPhoneAnchorDefault[26].flY = 57.0f;
        g_aLimelightPhoneAnchorDefault[29].flY = 99.0f;
        g_aLimelightPhoneAnchorDefault[30].flY = 113.0f;
        g_aLimelightPhoneAnchorDefault[31].flX = -106.0f;
        g_aLimelightPhoneAnchorDefault[32].flX = -9e+01f;
        g_aLimelightPhoneAnchorDefault[33].flX = -9e+01f;
        g_aLimelightPhoneAnchorDefault[34].flX = -9e+01f;
        g_aLimelightPhoneAnchorDefault[35].flX = -9e+01f;
        g_aLimelightPhoneAnchorDefault[36].flX = -9e+01f;
        g_aLimelightPhoneAnchorDefault[37].flX = -9e+01f;
        g_aLimelightPhoneAnchorDefault[38].flX = -9e+01f;
        g_aLimelightPhoneAnchorDefault[39].flX = -9e+01f;
        g_aLimelightPhoneAnchorDefault[33].flY = 25.0f;
        g_aLimelightPhoneAnchorDefault[42].flY = 25.0f;
        g_aLimelightPhoneAnchorDefault[34].flY = 39.0f;
        g_aLimelightPhoneAnchorDefault[43].flY = 39.0f;
        g_aLimelightPhoneAnchorDefault[36].flY = 67.0f;
        g_aLimelightPhoneAnchorDefault[45].flY = 67.0f;
        g_aLimelightPhoneAnchorDefault[38].flY = 95.0f;
        g_aLimelightPhoneAnchorDefault[47].flY = 95.0f;
        g_aLimelightPhoneAnchorDefault[39].flY = 109.0f;
        g_aLimelightPhoneAnchorDefault[48].flY = 109.0f;
        g_aLimelightPhoneAnchorDefault[54].flX = -83.0f;
        g_aLimelightPhoneAnchorDefault[55].flY = -39.0f;
        g_aLimelightPhoneAnchorDefault[22].flY = -79.0f;
        g_aLimelightPhoneAnchorDefault[56].flY = -79.0f;
        g_aLimelightPhoneAnchorDefault[7].flY = -139.0f;
        g_aLimelightPhoneAnchorDefault[7].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[8].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[9].flX = 17.0f;
        g_aLimelightPhoneAnchorDefault[9].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[10].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[11].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[12].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[13].flX = 17.0f;
        g_aLimelightPhoneAnchorDefault[13].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[14].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[15].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[57].flX = -141.0f;
        g_aLimelightPhoneAnchorDefault[58].flY = 151.0f;
        g_aLimelightPhoneAnchorDefault[59].flX = -65.0f;
        g_aLimelightPhoneAnchorDefault[60].flX = 65.0f;
        g_aLimelightPhoneAnchorDefault[59].flY = -36.0f;
        g_aLimelightPhoneAnchorDefault[60].flY = -36.0f;
        g_aLimelightPhoneAnchorDefault[61].flY = -27.0f;
        g_aLimelightPhoneAnchorDefault[62].flY = 143.0f;
        g_aLimelightPhoneAnchorDefault[63].flY = 143.0f;
        g_aLimelightPhoneAnchorDefault[70].flX = 61.0f;
        g_aLimelightPhoneAnchorDefault[71].flX = 61.0f;
        g_aLimelightPhoneAnchorDefault[72].flX = 61.0f;
        g_aLimelightPhoneAnchorDefault[73].flX = 61.0f;
        g_aLimelightPhoneAnchorDefault[16].flX = 49.0f;
        g_aLimelightPhoneAnchorDefault[16].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[17].flX = 5e+01f;
        g_aLimelightPhoneAnchorDefault[66].flY = 2.0f;
        g_aLimelightPhoneAnchorDefault[70].flY = 2.0f;
        g_aLimelightPhoneAnchorDefault[74].flY = 2.0f;
        g_aLimelightPhoneAnchorDefault[17].flY = -119.0f;
        g_aLimelightPhoneAnchorDefault[17].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[67].flY = 17.0f;
        g_aLimelightPhoneAnchorDefault[71].flY = 17.0f;
        g_aLimelightPhoneAnchorDefault[75].flY = 17.0f;
        g_aLimelightPhoneAnchorDefault[69].flY = 47.0f;
        g_aLimelightPhoneAnchorDefault[73].flY = 47.0f;
        g_aLimelightPhoneAnchorDefault[77].flY = 47.0f;
        g_aLimelightPhoneAnchorDefault[18].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[19].flX = 105.0f;
        g_aLimelightPhoneAnchorDefault[81].flY = 56.0f;
        g_aLimelightPhoneAnchorDefault[82].flY = 86.0f;
        g_aLimelightPhoneAnchorDefault[83].flX = -62.0f;
        g_aLimelightPhoneAnchorDefault[83].flY = 1.2e+02f;
        g_aLimelightPhoneAnchorDefault[84].flY = 1.2e+02f;
        g_aLimelightPhoneAnchorDefault[40].flX = 78.0f;
        g_aLimelightPhoneAnchorDefault[74].flX = 78.0f;
        g_aLimelightPhoneAnchorDefault[75].flX = 78.0f;
        g_aLimelightPhoneAnchorDefault[76].flX = 78.0f;
        g_aLimelightPhoneAnchorDefault[77].flX = 78.0f;
        g_aLimelightPhoneAnchorDefault[85].flX = 78.0f;
        g_aLimelightPhoneAnchorDefault[27].flY = 71.0f;
        g_aLimelightPhoneAnchorDefault[65].flY = 71.0f;
        g_aLimelightPhoneAnchorDefault[85].flY = 71.0f;
        g_aLimelightPhoneAnchorDefault[78].flX = 115.0f;
        g_aLimelightPhoneAnchorDefault[79].flX = 115.0f;
        g_aLimelightPhoneAnchorDefault[80].flX = 115.0f;
        g_aLimelightPhoneAnchorDefault[81].flX = 115.0f;
        g_aLimelightPhoneAnchorDefault[86].flX = 115.0f;
        g_aLimelightPhoneAnchorDefault[86].flY = 8e+01f;
        g_aLimelightPhoneAnchorDefault[84].flX = 108.0f;
        g_aLimelightPhoneAnchorDefault[87].flX = 108.0f;
        g_aLimelightPhoneAnchorDefault[87].flY = 137.0f;
        g_aLimelightPhoneAnchorDefault[19].flY = -107.0f;
        g_aLimelightPhoneAnchorDefault[19].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[20].flX = 79.0f;
        g_aLimelightPhoneAnchorDefault[20].flY = -128.0f;
        g_aLimelightPhoneAnchorDefault[20].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[21].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[22].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[23].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[23].flY = 15.0f;
        g_aLimelightPhoneAnchorDefault[23].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[24].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[24].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[25].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[25].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[26].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[26].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[27].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[27].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[28].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[28].flY = 85.0f;
        g_aLimelightPhoneAnchorDefault[28].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[29].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[29].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[30].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[30].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[31].flY = -9.0f;
        g_aLimelightPhoneAnchorDefault[31].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[32].flY = 11.0f;
        g_aLimelightPhoneAnchorDefault[32].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[33].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[34].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[35].flY = 53.0f;
        g_aLimelightPhoneAnchorDefault[35].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[36].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[37].flY = 81.0f;
        g_aLimelightPhoneAnchorDefault[37].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[38].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[39].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[40].flY = -9.0f;
        g_aLimelightPhoneAnchorDefault[40].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[41].flX = 94.0f;
        g_aLimelightPhoneAnchorDefault[41].flY = 11.0f;
        g_aLimelightPhoneAnchorDefault[41].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[42].flX = 94.0f;
        g_aLimelightPhoneAnchorDefault[42].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[43].flX = 94.0f;
        g_aLimelightPhoneAnchorDefault[43].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[44].flX = 94.0f;
        g_aLimelightPhoneAnchorDefault[44].flY = 53.0f;
        g_aLimelightPhoneAnchorDefault[44].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[45].flX = 94.0f;
        g_aLimelightPhoneAnchorDefault[45].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[46].flX = 94.0f;
        g_aLimelightPhoneAnchorDefault[46].flY = 81.0f;
        g_aLimelightPhoneAnchorDefault[46].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[47].flX = 94.0f;
        g_aLimelightPhoneAnchorDefault[47].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[48].flX = 94.0f;
        g_aLimelightPhoneAnchorDefault[48].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[49].flX = 88.0f;
        g_aLimelightPhoneAnchorDefault[49].flY = 155.0f;
        g_aLimelightPhoneAnchorDefault[49].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[50].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[50].flY = 0.0f;
        g_aLimelightPhoneAnchorDefault[50].nAnchorMode = 0;
        g_aLimelightPhoneAnchorDefault[51].flX = 8.0f;
        g_aLimelightPhoneAnchorDefault[51].flY = 7.0f;
        g_aLimelightPhoneAnchorDefault[51].nAnchorMode = 0;
        g_aLimelightPhoneAnchorDefault[52].flX = 68.0f;
        g_aLimelightPhoneAnchorDefault[52].flY = 7.0f;
        g_aLimelightPhoneAnchorDefault[52].nAnchorMode = 0;
        g_aLimelightPhoneAnchorDefault[53].flX = 216.0f;
        g_aLimelightPhoneAnchorDefault[53].flY = 7.0f;
        g_aLimelightPhoneAnchorDefault[53].nAnchorMode = 0;
        g_aLimelightPhoneAnchorDefault[54].flY = -57.0f;
        g_aLimelightPhoneAnchorDefault[54].nAnchorMode = 5;
        g_aLimelightPhoneAnchorDefault[55].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[55].nAnchorMode = 5;
        g_aLimelightPhoneAnchorDefault[56].flX = 7e+01f;
        g_aLimelightPhoneAnchorDefault[56].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[57].flY = -41.0f;
        g_aLimelightPhoneAnchorDefault[57].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[58].flX = 141.0f;
        g_aLimelightPhoneAnchorDefault[58].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[59].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[60].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[61].flX = 0.0f;
        g_aLimelightPhoneAnchorDefault[61].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[62].flX = -6.0f;
        g_aLimelightPhoneAnchorDefault[62].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[63].flX = 5.0f;
        g_aLimelightPhoneAnchorDefault[63].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[64].flX = -117.0f;
        g_aLimelightPhoneAnchorDefault[64].flY = -15.0f;
        g_aLimelightPhoneAnchorDefault[64].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[65].flX = -117.0f;
        g_aLimelightPhoneAnchorDefault[65].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[66].flX = -117.0f;
        g_aLimelightPhoneAnchorDefault[66].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[67].flX = -117.0f;
        g_aLimelightPhoneAnchorDefault[67].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[68].flX = -117.0f;
        g_aLimelightPhoneAnchorDefault[68].flY = 32.0f;
        g_aLimelightPhoneAnchorDefault[68].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[69].flX = -117.0f;
        g_aLimelightPhoneAnchorDefault[69].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[70].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[71].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[72].flY = 32.0f;
        g_aLimelightPhoneAnchorDefault[72].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[73].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[74].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[75].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[76].flY = 32.0f;
        g_aLimelightPhoneAnchorDefault[76].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[77].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[78].flY = 11.0f;
        g_aLimelightPhoneAnchorDefault[78].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[79].flY = 26.0f;
        g_aLimelightPhoneAnchorDefault[79].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[80].flY = 41.0f;
        g_aLimelightPhoneAnchorDefault[80].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[81].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[82].flX = -128.0f;
        g_aLimelightPhoneAnchorDefault[82].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[83].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[84].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[85].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[86].nAnchorMode = 4;
        g_aLimelightPhoneAnchorDefault[87].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[1].flX = -227.0f;
        g_aLimelightPhoneAnchorPortrait[1].flY = 11.0f;
        g_aLimelightPhoneAnchorPortrait[2].flX = 226.0f;
        g_aLimelightPhoneAnchorPortrait[2].flY = 269.0f;
        g_aLimelightPhoneAnchorPortrait[1].nAnchorMode = 3;
        g_aLimelightPhoneAnchorPortrait[2].nAnchorMode = 3;
        g_aLimelightPhoneAnchorPortrait[3].flY = -128.0f;
        g_aLimelightPhoneAnchorPortrait[4].flY = -28.0f;
        g_aLimelightPhoneAnchorPortrait[5].flY = -123.0f;
        g_aLimelightPhoneAnchorPortrait[5].flX = -102.0f;
        g_aLimelightPhoneAnchorPortrait[6].flX = -102.0f;
        g_aLimelightPhoneAnchorPortrait[7].flX = -204.0f;
        g_aLimelightPhoneAnchorPortrait[9].flX = -51.0f;
        g_aLimelightPhoneAnchorPortrait[12].flX = 172.0f;
        g_aLimelightPhoneAnchorPortrait[13].flX = 173.0f;
        g_aLimelightPhoneAnchorPortrait[14].flX = 176.0f;
        g_aLimelightPhoneAnchorPortrait[15].flX = 201.0f;
        g_aLimelightPhoneAnchorPortrait[16].flX = 205.0f;
        g_aLimelightPhoneAnchorPortrait[17].flX = 204.0f;
        g_aLimelightPhoneAnchorPortrait[11].flX = 121.0f;
        g_aLimelightPhoneAnchorPortrait[18].flX = 121.0f;
        g_aLimelightPhoneAnchorPortrait[8].flY = -82.0f;
        g_aLimelightPhoneAnchorPortrait[9].flY = -82.0f;
        g_aLimelightPhoneAnchorPortrait[10].flX = -41.0f;
        g_aLimelightPhoneAnchorPortrait[10].flY = -82.0f;
        g_aLimelightPhoneAnchorPortrait[18].flY = -82.0f;
        g_aLimelightPhoneAnchorPortrait[19].flX = 181.0f;
        g_aLimelightPhoneAnchorPortrait[19].flY = -85.0f;
        g_aLimelightPhoneAnchorPortrait[20].flX = 155.0f;
        g_aLimelightPhoneAnchorPortrait[20].flY = -107.0f;
        g_aLimelightPhoneAnchorPortrait[11].flY = -7e+01f;
        g_aLimelightPhoneAnchorPortrait[21].flY = -7e+01f;
        g_aLimelightPhoneAnchorPortrait[6].flY = -101.0f;
        g_aLimelightPhoneAnchorPortrait[8].flX = -101.0f;
        g_aLimelightPhoneAnchorPortrait[21].flX = -101.0f;
        g_aLimelightPhoneAnchorPortrait[22].flX = -101.0f;
        g_aLimelightPhoneAnchorPortrait[25].flY = 3e+01f;
        g_aLimelightPhoneAnchorPortrait[26].flY = 41.0f;
        g_aLimelightPhoneAnchorPortrait[27].flY = 53.0f;
        g_aLimelightPhoneAnchorPortrait[29].flY = 74.0f;
        g_aLimelightPhoneAnchorPortrait[30].flY = 85.0f;
        g_aLimelightPhoneAnchorPortrait[31].flX = -2e+02f;
        g_aLimelightPhoneAnchorPortrait[32].flX = -1.2e+02f;
        g_aLimelightPhoneAnchorPortrait[33].flX = -1.2e+02f;
        g_aLimelightPhoneAnchorPortrait[34].flX = -1.2e+02f;
        g_aLimelightPhoneAnchorPortrait[35].flX = -1.2e+02f;
        g_aLimelightPhoneAnchorPortrait[36].flX = -1.2e+02f;
        g_aLimelightPhoneAnchorPortrait[37].flX = -1.2e+02f;
        g_aLimelightPhoneAnchorPortrait[38].flX = -1.2e+02f;
        g_aLimelightPhoneAnchorPortrait[39].flX = -1.2e+02f;
        g_aLimelightPhoneAnchorPortrait[40].flX = 2e+02f;
        g_aLimelightPhoneAnchorPortrait[40].flY = 35.0f;
        g_aLimelightPhoneAnchorPortrait[34].flY = 26.0f;
        g_aLimelightPhoneAnchorPortrait[43].flY = 26.0f;
        g_aLimelightPhoneAnchorPortrait[35].flY = 37.0f;
        g_aLimelightPhoneAnchorPortrait[44].flY = 37.0f;
        g_aLimelightPartsPhone[218].flHeight = 48.0f;
        g_aLimelightPartsPhone[221].flHeight = 48.0f;
        g_aLimelightPhoneAnchorPortrait[36].flY = 48.0f;
        g_aLimelightPhoneAnchorPortrait[45].flY = 48.0f;
        g_aLimelightPhoneAnchorPortrait[37].flY = 59.0f;
        g_aLimelightPhoneAnchorPortrait[46].flY = 59.0f;
        g_aLimelightPhoneAnchorPortrait[38].flY = 7e+01f;
        g_aLimelightPhoneAnchorPortrait[47].flY = 7e+01f;
        g_aLimelightPhoneAnchorPortrait[41].flX = 1.3e+02f;
        g_aLimelightPhoneAnchorPortrait[42].flX = 1.3e+02f;
        g_aLimelightPhoneAnchorPortrait[43].flX = 1.3e+02f;
        g_aLimelightPhoneAnchorPortrait[44].flX = 1.3e+02f;
        g_aLimelightPhoneAnchorPortrait[45].flX = 1.3e+02f;
        g_aLimelightPhoneAnchorPortrait[46].flX = 1.3e+02f;
        g_aLimelightPhoneAnchorPortrait[47].flX = 1.3e+02f;
        g_aLimelightPhoneAnchorPortrait[48].flX = 1.3e+02f;
        g_aLimelightPhoneAnchorPortrait[39].flY = 81.0f;
        g_aLimelightPhoneAnchorPortrait[48].flY = 81.0f;
        g_aLimelightPhoneAnchorPortrait[49].flY = 114.0f;
        g_aLimelightPhoneAnchorPortrait[23].flY = 8.0f;
        g_aLimelightPhoneAnchorPortrait[51].flX = 8.0f;
        g_aLimelightPhoneAnchorPortrait[52].flX = 68.0f;
        g_aLimelightPhoneAnchorPortrait[53].flX = 216.0f;
        g_aLimelightPhoneAnchorPortrait[51].flY = 7.0f;
        g_aLimelightPhoneAnchorPortrait[52].flY = 7.0f;
        g_aLimelightPhoneAnchorPortrait[53].flY = 7.0f;
        g_aLimelightPhoneAnchorPortrait[54].flX = -68.5f;
        g_aLimelightPhoneAnchorPortrait[55].flY = -19.0f;
        g_aLimelightPhoneAnchorPortrait[17].flY = -58.0f;
        g_aLimelightPhoneAnchorPortrait[22].flY = -58.0f;
        g_aLimelightPhoneAnchorPortrait[56].flY = -58.0f;
        g_aLimelightPhoneAnchorPortrait[3].flX = -214.0f;
        g_aLimelightPhoneAnchorPortrait[57].flX = -214.0f;
        g_aLimelightPhoneAnchorPortrait[57].flY = -22.0f;
        g_aLimelightPhoneAnchorPortrait[4].flX = 214.0f;
        g_aLimelightPhoneAnchorPortrait[58].flX = 214.0f;
        g_aLimelightPhoneAnchorPortrait[58].flY = 1.1e+02f;
        g_aLimelightPhoneAnchorPortrait[59].flX = -61.0f;
        g_aLimelightPhoneAnchorPortrait[60].flX = 69.0f;
        g_aLimelightPhoneAnchorPortrait[59].flY = -18.0f;
        g_aLimelightPhoneAnchorPortrait[60].flY = -18.0f;
        g_aLimelightPhoneAnchorPortrait[32].flY = 4.0f;
        g_aLimelightPhoneAnchorPortrait[41].flY = 4.0f;
        g_aLimelightPhoneAnchorPortrait[61].flX = 4.0f;
        g_aLimelightPhoneAnchorPortrait[61].flY = -9.0f;
        g_aLimelightPhoneAnchorPortrait[62].flX = -6.0f;
        g_aLimelightPhoneAnchorPortrait[63].flX = 5.0f;
        g_aLimelightPhoneAnchorPortrait[62].flY = 104.0f;
        g_aLimelightPhoneAnchorPortrait[63].flY = 104.0f;
        g_aLimelightPhoneAnchorPortrait[64].flY = -2.0f;
        g_aLimelightPhoneAnchorPortrait[64].flX = -197.0f;
        g_aLimelightPhoneAnchorPortrait[66].flX = -197.0f;
        g_aLimelightPhoneAnchorPortrait[68].flX = -197.0f;
        g_aLimelightPhoneAnchorPortrait[12].flY = -69.0f;
        g_aLimelightPhoneAnchorPortrait[13].flY = -69.0f;
        g_aLimelightPhoneAnchorPortrait[14].flY = -69.0f;
        g_aLimelightPhoneAnchorPortrait[15].flY = -69.0f;
        g_aLimelightPhoneAnchorPortrait[16].flY = -69.0f;
        g_aLimelightPhoneAnchorPortrait[70].flX = -69.0f;
        g_aLimelightPhoneAnchorPortrait[72].flX = -69.0f;
        g_aLimelightPhoneAnchorPortrait[71].flX = 141.0f;
        g_aLimelightPhoneAnchorPortrait[73].flX = 141.0f;
        g_aLimelightPhoneAnchorPortrait[66].flY = 1e+01f;
        g_aLimelightPhoneAnchorPortrait[67].flY = 1e+01f;
        g_aLimelightPhoneAnchorPortrait[70].flY = 1e+01f;
        g_aLimelightPhoneAnchorPortrait[71].flY = 1e+01f;
        g_aLimelightPhoneAnchorPortrait[74].flY = 1e+01f;
        g_aLimelightPhoneAnchorPortrait[75].flY = 1e+01f;
        g_aLimelightPhoneAnchorPortrait[68].flY = 23.0f;
        g_aLimelightPhoneAnchorPortrait[69].flY = 23.0f;
        g_aLimelightPhoneAnchorPortrait[72].flY = 23.0f;
        g_aLimelightPhoneAnchorPortrait[73].flY = 23.0f;
        g_aLimelightPhoneAnchorPortrait[76].flY = 23.0f;
        g_aLimelightPhoneAnchorPortrait[77].flY = 23.0f;
        g_aLimelightPhoneAnchorPortrait[24].flY = 19.0f;
        g_aLimelightPhoneAnchorPortrait[78].flY = 19.0f;
        g_aLimelightPhoneAnchorPortrait[79].flY = 19.0f;
        g_aLimelightPartsPhone[202].flHeight = 4e+01f;
        g_aLimelightPartsPhone[213].flWidth = 32.0f;
        g_aLimelightPartsPhone[213].flHeight = 32.0f;
        g_aLimelightPartsPhone[218].flWidth = 4e+01f;
        g_aLimelightPartsPhone[221].flWidth = 4e+01f;
        g_aLimelightPartsPhone[226].flWidth = 32.0f;
        g_aLimelightPartsPhone[226].flHeight = 4e+01f;
        g_aLimelightPartsPhone[229].flWidth = 32.0f;
        g_aLimelightPartsPhone[229].flHeight = 4e+01f;
        g_aLimelightPartsPhone[234].flWidth = 32.0f;
        g_aLimelightPartsPhone[234].flHeight = 4e+01f;
        g_aLimelightPartsAnchorPhone[70].x = 548.0f;
        g_aLimelightPartsAnchorPhone[70].y = 575.0f;
        g_aLimelightPartsAnchorPhone[69].x = 478.0f;
        g_aLimelightPartsAnchorPhone[69].y = 563.0f;
        g_aLimelightPartsAnchorPhone[72].x = 548.0f;
        g_aLimelightPartsAnchorPhone[72].y = 601.0f;
        g_aLimelightPartsAnchorPhone[71].x = 478.0f;
        g_aLimelightPartsAnchorPhone[71].y = 589.0f;
        g_aLimelightPartsAnchorPhone[74].x = 548.0f;
        g_aLimelightPartsAnchorPhone[74].y = 627.0f;
        g_aLimelightPartsAnchorPhone[73].x = 478.0f;
        g_aLimelightPartsAnchorPhone[73].y = 615.0f;
        g_aLimelightPhoneAnchorPortrait[0].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[0].flY = 0.0f;
        g_aLimelightPhoneAnchorPortrait[0].nAnchorMode = 0;
        g_aLimelightPhoneAnchorPortrait[3].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[4].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[5].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[6].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[7].flY = -119.0f;
        g_aLimelightPhoneAnchorPortrait[7].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[8].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[9].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[10].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[11].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[12].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[13].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[14].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[15].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[16].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[17].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[18].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[19].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[20].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[21].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[22].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[23].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[23].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[24].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[24].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[25].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[25].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[26].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[26].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[27].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[27].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[28].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[78].flX = -15.0f;
        g_aLimelightPhoneAnchorPortrait[80].flX = -15.0f;
        g_aLimelightPhoneAnchorPortrait[28].flY = 63.0f;
        g_aLimelightPhoneAnchorPortrait[28].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[29].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[29].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[30].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[30].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[31].flY = 64.0f;
        g_aLimelightPhoneAnchorPortrait[31].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[32].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[33].flY = 15.0f;
        g_aLimelightPhoneAnchorPortrait[33].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[34].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[35].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[36].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[37].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[38].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[39].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[40].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[41].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[42].flY = 15.0f;
        g_aLimelightPhoneAnchorPortrait[42].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[43].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[44].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[45].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[46].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[47].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[48].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[80].flY = 32.0f;
        g_aLimelightPhoneAnchorPortrait[81].flY = 32.0f;
        g_aLimelightPhoneAnchorPortrait[82].flX = -108.0f;
        g_aLimelightPhoneAnchorPortrait[49].flX = 1.6e+02f;
        g_aLimelightPhoneAnchorPortrait[49].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[50].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[50].flY = 0.0f;
        g_aLimelightPhoneAnchorPortrait[50].nAnchorMode = 0;
        g_aLimelightPhoneAnchorPortrait[51].nAnchorMode = 0;
        g_aLimelightPhoneAnchorPortrait[52].nAnchorMode = 0;
        g_aLimelightPhoneAnchorPortrait[53].nAnchorMode = 0;
        g_aLimelightPhoneAnchorPortrait[82].flY = 5e+01f;
        g_aLimelightPhoneAnchorPortrait[74].flX = -52.0f;
        g_aLimelightPhoneAnchorPortrait[76].flX = -52.0f;
        g_aLimelightPhoneAnchorPortrait[83].flX = -52.0f;
        g_aLimelightPhoneAnchorPortrait[83].flY = 84.0f;
        g_aLimelightPhoneAnchorPortrait[84].flY = 84.0f;
        g_aLimelightPhoneAnchorPortrait[75].flX = 158.0f;
        g_aLimelightPhoneAnchorPortrait[77].flX = 158.0f;
        g_aLimelightPhoneAnchorPortrait[85].flX = 158.0f;
        g_aLimelightPhoneAnchorPortrait[54].flY = -37.0f;
        g_aLimelightPhoneAnchorPortrait[54].nAnchorMode = 5;
        g_aLimelightPhoneAnchorPortrait[55].flX = 0.0f;
        g_aLimelightPhoneAnchorPortrait[55].nAnchorMode = 5;
        g_aLimelightPhoneAnchorPortrait[56].flX = 1.0f;
        g_aLimelightPhoneAnchorPortrait[56].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[57].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[58].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[59].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[60].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[61].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[62].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[63].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[64].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[65].flY = 4e+01f;
        g_aLimelightPhoneAnchorPortrait[85].flY = 4e+01f;
        g_aLimelightPhoneAnchorPortrait[79].flX = 195.0f;
        g_aLimelightPhoneAnchorPortrait[81].flX = 195.0f;
        g_aLimelightPhoneAnchorPortrait[86].flX = 195.0f;
        g_aLimelightPhoneAnchorPortrait[65].flX = 13.0f;
        g_aLimelightPhoneAnchorPortrait[65].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[66].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[67].flX = 13.0f;
        g_aLimelightPhoneAnchorPortrait[67].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[68].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[69].flX = 13.0f;
        g_aLimelightPhoneAnchorPortrait[69].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[70].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[71].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[72].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[73].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[74].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[75].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[76].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[77].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[78].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[79].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[80].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[81].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[82].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[83].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[86].flY = 49.0f;
        g_aLimelightPhoneAnchorPortrait[84].flX = 118.0f;
        g_aLimelightPhoneAnchorPortrait[84].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[85].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[86].nAnchorMode = 4;
        g_aLimelightPhoneAnchorPortrait[87].flX = 118.0f;
        g_aLimelightPhoneAnchorPortrait[87].flY = 101.0f;
        g_aLimelightPhoneAnchorPortrait[87].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[0].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[0].flY = -164.0f;
        g_aLimelightSeparatorPhoneDefault[1].flX = -42.0f;
        g_aLimelightSeparatorPhoneDefault[1].flY = -56.0f;
        g_aLimelightSeparatorPhoneDefault[1].flWidth = 83.0f;
        g_aLimelightSeparatorPhoneDefault[1].flHeight = 1.5707964f;
        g_aLimelightSeparatorPhoneDefault[3].flX = -49.0f;
        g_aLimelightSeparatorPhoneDefault[2].flX = -132.0f;
        g_aLimelightSeparatorPhoneDefault[2].flY = -1.4e+02f;
        g_aLimelightSeparatorPhoneDefault[2].flWidth = 1.0f;
        g_aLimelightSeparatorPhoneDefault[2].flHeight = -1.5707964f;
        g_aLimelightSeparatorPhoneDefault[3].flY = -139.0f;
        g_aLimelightSeparatorPhoneDefault[4].flX = -133.0f;
        g_aLimelightSeparatorPhoneDefault[4].flY = -57.0f;
        g_aLimelightSeparatorPhoneDefault[6].flY = -139.0f;
        g_aLimelightSeparatorPhoneDefault[6].flX = -5e+01f;
        g_aLimelightSeparatorPhoneDefault[9].flX = -5e+01f;
        g_aLimelightSeparatorPhoneDefault[0].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[1].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[2].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[3].flWidth = 1.0f;
        g_aLimelightSeparatorPhoneDefault[5].flX = -5e+01f;
        g_aLimelightSeparatorPhoneDefault[5].flY = -56.0f;
        g_aLimelightSeparatorPhoneDefault[5].flWidth = 1.0f;
        g_aLimelightSeparatorPhoneDefault[5].flHeight = 1.5707964f;
        g_aLimelightSeparatorPhoneDefault[7].flX = -132.0f;
        g_aLimelightSeparatorPhoneDefault[7].flY = -139.0f;
        g_aLimelightSeparatorPhoneDefault[7].flWidth = 82.0f;
        g_aLimelightSeparatorPhoneDefault[7].flHeight = -1.5707964f;
        g_aLimelightSeparatorPhoneDefault[8].flX = -132.0f;
        g_aLimelightSeparatorPhoneDefault[8].flY = -57.0f;
        g_aLimelightSeparatorPhoneDefault[9].flY = -57.0f;
        g_aLimelightSeparatorPhoneDefault[10].flX = -33.0f;
        g_aLimelightSeparatorPhoneDefault[10].flY = -132.0f;
        g_aLimelightSeparatorPhoneDefault[10].flWidth = 165.0f;
        g_aLimelightSeparatorPhoneDefault[10].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[11].flX = -33.0f;
        g_aLimelightSeparatorPhoneDefault[11].flY = -93.0f;
        g_aLimelightSeparatorPhoneDefault[11].flWidth = 165.0f;
        g_aLimelightSeparatorPhoneDefault[11].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[12].flX = -48.0f;
        g_aLimelightSeparatorPhoneDefault[12].flY = 21.0f;
        g_aLimelightSeparatorPhoneDefault[12].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[13].flX = -48.0f;
        g_aLimelightSeparatorPhoneDefault[13].flY = 35.0f;
        g_aLimelightSeparatorPhoneDefault[13].flWidth = 96.0f;
        g_aLimelightSeparatorPhoneDefault[13].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[14].flX = -48.0f;
        g_aLimelightSeparatorPhoneDefault[14].flY = 49.0f;
        g_aLimelightSeparatorPhoneDefault[14].flWidth = 96.0f;
        g_aLimelightSeparatorPhoneDefault[14].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[14].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[15].flX = -48.0f;
        g_aLimelightSeparatorPhoneDefault[15].flY = 63.0f;
        g_aLimelightSeparatorPhoneDefault[15].flWidth = 96.0f;
        g_aLimelightSeparatorPhoneDefault[15].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[16].flX = -48.0f;
        g_aLimelightSeparatorPhoneDefault[16].flY = 77.0f;
        g_aLimelightSeparatorPhoneDefault[16].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[17].flX = -48.0f;
        g_aLimelightSeparatorPhoneDefault[17].flY = 91.0f;
        g_aLimelightSeparatorPhoneDefault[17].flWidth = 96.0f;
        g_aLimelightSeparatorPhoneDefault[17].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[18].flX = -48.0f;
        g_aLimelightSeparatorPhoneDefault[18].flY = 105.0f;
        g_aLimelightSeparatorPhoneDefault[18].flWidth = 96.0f;
        g_aLimelightSeparatorPhoneDefault[18].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[19].flX = -48.0f;
        g_aLimelightSeparatorPhoneDefault[19].flY = 119.0f;
        g_aLimelightSeparatorPhoneDefault[19].flWidth = 96.0f;
        g_aLimelightSeparatorPhoneDefault[20].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[20].flY = -3.0f;
        g_aLimelightSeparatorPhoneDefault[20].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[21].flX = -78.0f;
        g_aLimelightSeparatorPhoneDefault[21].flY = -3.0f;
        g_aLimelightSeparatorPhoneDefault[21].flWidth = 23.0f;
        g_aLimelightSeparatorPhoneDefault[21].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[22].flY = 21.0f;
        g_aLimelightSeparatorPhoneDefault[22].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[23].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[23].flY = 35.0f;
        g_aLimelightSeparatorPhoneDefault[23].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[23].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[24].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[24].flY = 49.0f;
        g_aLimelightSeparatorPhoneDefault[26].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[26].flY = 77.0f;
        g_aLimelightSeparatorPhoneDefault[26].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[26].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[26].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[27].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[27].flY = 91.0f;
        g_aLimelightSeparatorPhoneDefault[27].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[27].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[28].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[28].flY = 105.0f;
        g_aLimelightSeparatorPhoneDefault[28].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[29].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[29].flY = 119.0f;
        g_aLimelightSeparatorPhoneDefault[29].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[29].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[30].flX = 55.0f;
        g_aLimelightSeparatorPhoneDefault[30].flY = -3.0f;
        g_aLimelightSeparatorPhoneDefault[30].flWidth = 21.0f;
        g_aLimelightSeparatorPhoneDefault[30].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[30].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[31].flX = 113.0f;
        g_aLimelightSeparatorPhoneDefault[31].flY = -3.0f;
        g_aLimelightSeparatorPhoneDefault[31].flWidth = 21.0f;
        g_aLimelightSeparatorPhoneDefault[31].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[32].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[33].flX = 55.0f;
        g_aLimelightSeparatorPhoneDefault[33].flY = 35.0f;
        g_aLimelightSeparatorPhoneDefault[33].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[33].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[36].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[37].flX = 55.0f;
        g_aLimelightSeparatorPhoneDefault[37].flY = 91.0f;
        g_aLimelightSeparatorPhoneDefault[37].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[37].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[35].flX = 55.0f;
        g_aLimelightSeparatorPhoneDefault[38].flX = 55.0f;
        g_aLimelightSeparatorPhoneDefault[22].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[25].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[32].flX = 55.0f;
        g_aLimelightSeparatorPhoneDefault[32].flY = 21.0f;
        g_aLimelightSeparatorPhoneDefault[35].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[38].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[38].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[39].flX = 55.0f;
        g_aLimelightSeparatorPhoneDefault[39].flY = 119.0f;
        g_aLimelightSeparatorPhoneDefault[39].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[39].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[22].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[25].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[41].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[41].flY = -12.0f;
        g_aLimelightSeparatorPhoneDefault[3].flHeight = 3.1415927f;
        g_aLimelightSeparatorPhoneDefault[3].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[4].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[5].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[6].flWidth = 82.0f;
        g_aLimelightSeparatorPhoneDefault[6].flHeight = 3.1415927f;
        g_aLimelightSeparatorPhoneDefault[6].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[7].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[8].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[9].flWidth = 82.0f;
        g_aLimelightSeparatorPhoneDefault[34].flX = 55.0f;
        g_aLimelightSeparatorPhoneDefault[34].flY = 49.0f;
        g_aLimelightSeparatorPhoneDefault[34].flWidth = 76.0f;
        g_aLimelightSeparatorPhoneDefault[34].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[36].flX = 55.0f;
        g_aLimelightSeparatorPhoneDefault[36].flY = 77.0f;
        g_aLimelightSeparatorPhoneDefault[40].flX = 88.0f;
        g_aLimelightSeparatorPhoneDefault[40].flY = -7.0f;
        g_aLimelightSeparatorPhoneDefault[41].flWidth = 94.0f;
        g_aLimelightSeparatorPhoneDefault[42].flX = 37.0f;
        g_aLimelightSeparatorPhoneDefault[42].flY = -12.0f;
        g_aLimelightSeparatorPhoneDefault[42].flWidth = 94.0f;
        g_aLimelightSeparatorPhoneDefault[42].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[42].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[43].flX = -131.0f;
        g_aLimelightSeparatorPhoneDefault[43].flY = 65.0f;
        g_aLimelightSeparatorPhoneDefault[43].flWidth = 89.0f;
        g_aLimelightSeparatorPhoneDefault[43].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[44].flX = 42.0f;
        g_aLimelightSeparatorPhoneDefault[44].flY = 65.0f;
        g_aLimelightSeparatorPhoneDefault[44].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[45].flX = -98.0f;
        g_aLimelightSeparatorPhoneDefault[45].flY = 105.0f;
        g_aLimelightSeparatorPhoneDefault[45].flWidth = 114.0f;
        g_aLimelightSeparatorPhoneDefault[45].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[46].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[47].flX = -117.0f;
        g_aLimelightSeparatorPhoneDefault[47].flY = 13.0f;
        g_aLimelightSeparatorPhoneDefault[47].flWidth = 233.0f;
        g_aLimelightSeparatorPhoneDefault[47].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[48].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[49].flX = -117.0f;
        g_aLimelightSeparatorPhoneDefault[49].flY = 43.0f;
        g_aLimelightSeparatorPhoneDefault[49].flWidth = 233.0f;
        g_aLimelightSeparatorPhoneDefault[49].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[9].flHeight = 1.5707964f;
        g_aLimelightSeparatorPhoneDefault[9].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[10].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[11].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[13].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[15].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[17].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[18].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[19].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[19].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[21].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[22].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[23].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[24].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[25].flY = 63.0f;
        g_aLimelightSeparatorPhoneDefault[25].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[25].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[27].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[29].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[31].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[33].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[34].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[35].flY = 63.0f;
        g_aLimelightSeparatorPhoneDefault[35].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[35].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[37].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[38].flY = 105.0f;
        g_aLimelightSeparatorPhoneDefault[38].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[39].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[40].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[41].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[41].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[43].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[45].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[46].flX = -117.0f;
        g_aLimelightSeparatorPhoneDefault[46].flY = -4.0f;
        g_aLimelightSeparatorPhoneDefault[46].flWidth = 1e+02f;
        g_aLimelightSeparatorPhoneDefault[46].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[47].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[48].flX = -117.0f;
        g_aLimelightSeparatorPhoneDefault[48].flY = 28.0f;
        g_aLimelightSeparatorPhoneDefault[49].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[50].flX = -117.0f;
        g_aLimelightSeparatorPhoneDefault[50].flY = 58.0f;
        g_aLimelightSeparatorPhoneDefault[50].flWidth = 233.0f;
        g_aLimelightSeparatorPhoneDefault[50].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[50].nAnchorMode = 4;
        g_aLimelightSeparatorPhoneDefault[51].flX = -117.0f;
        g_aLimelightSeparatorPhoneDefault[51].flY = 82.0f;
        g_aLimelightSeparatorPhoneDefault[51].flWidth = 233.0f;
        g_aLimelightSeparatorPhoneDefault[51].flHeight = 0.0f;
        g_aLimelightSeparatorPhoneDefault[51].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[3].flX = -121.0f;
        g_aLimelightPartsAnchorPhone[76].x = 548.0f;
        g_aLimelightPartsAnchorPhone[76].y = 653.0f;
        g_aLimelightPartsAnchorPhone[75].x = 478.0f;
        g_aLimelightPartsAnchorPhone[75].y = 641.0f;
        g_aLimelightPartsAnchorPhone[78].x = 548.0f;
        g_aLimelightPartsAnchorPhone[78].y = 685.0f;
        g_aLimelightPartsAnchorPhone[77].x = 478.0f;
        g_aLimelightPartsAnchorPhone[77].y = 667.0f;
        g_aLimelightSeparatorPhonePortrait[3].flWidth = 1.0f;
        g_aLimelightSeparatorPhonePortrait[3].flY = -119.0f;
        g_aLimelightSeparatorPhonePortrait[6].flY = -119.0f;
        g_aLimelightPartsAnchorPhone[80].x = 478.0f;
        g_aLimelightPartsAnchorPhone[80].y = 719.0f;
        g_aLimelightPartsAnchorPhone[79].x = 562.0f;
        g_aLimelightPartsAnchorPhone[79].y = 705.0f;
        g_aLimelightPartsAnchorPhone[82].x = 153.0f;
        g_aLimelightPartsAnchorPhone[82].y = 8.1e+02f;
        g_aLimelightPartsAnchorPhone[81].x = 151.0f;
        g_aLimelightPartsAnchorPhone[81].y = 805.0f;
        g_aLimelightSeparatorPhonePortrait[3].flHeight = 3.1415927f;
        g_aLimelightSeparatorPhonePortrait[6].flHeight = 3.1415927f;
        g_aLimelightSeparatorPhonePortrait[6].flX = -122.0f;
        g_aLimelightSeparatorPhonePortrait[9].flX = -122.0f;
        g_aLimelightSeparatorPhonePortrait[9].flY = -37.0f;
        g_aLimelightSeparatorPhonePortrait[6].flWidth = 82.0f;
        g_aLimelightSeparatorPhonePortrait[9].flWidth = 82.0f;
        g_aLimelightPartsPhone[202].flX = 0.0f;
        g_aLimelightPartsPhone[202].flY = 0.0f;
        g_aLimelightPartsAnchorPhone[84].x = 283.0f;
        g_aLimelightPartsAnchorPhone[84].y = 803.0f;
        g_aLimelightPartsAnchorPhone[83].x = 264.0f;
        g_aLimelightPartsAnchorPhone[83].y = 801.0f;
        g_aLimelightPartsAnchorPhone[86].x = 422.0f;
        g_aLimelightPartsAnchorPhone[86].y = 806.0f;
        g_aLimelightPartsAnchorPhone[85].x = 395.0f;
        g_aLimelightPartsAnchorPhone[85].y = 808.0f;
        g_aLimelightPartsAnchorPhone[88].x = 588.0f;
        g_aLimelightPartsAnchorPhone[88].y = 808.0f;
        g_aLimelightPartsAnchorPhone[87].x = 491.0f;
        g_aLimelightPartsAnchorPhone[87].y = 808.0f;
        g_aLimelightPartsAnchorPhone[90].x = 153.0f;
        g_aLimelightPartsAnchorPhone[90].y = 848.0f;
        g_aLimelightPartsAnchorPhone[89].x = 151.0f;
        g_aLimelightPartsAnchorPhone[89].y = 843.0f;
        g_aLimelightPartsAnchorPhone[92].x = 283.0f;
        g_aLimelightPartsAnchorPhone[92].y = 841.0f;
        g_aLimelightPartsAnchorPhone[91].x = 264.0f;
        g_aLimelightPartsAnchorPhone[91].y = 839.0f;
        g_aLimelightPartsAnchorPhone[94].x = 422.0f;
        g_aLimelightPartsAnchorPhone[94].y = 844.0f;
        g_aLimelightPartsAnchorPhone[93].x = 395.0f;
        g_aLimelightPartsAnchorPhone[93].y = 846.0f;
        g_aLimelightPartsAnchorPhone[96].x = 588.0f;
        g_aLimelightPartsAnchorPhone[96].y = 846.0f;
        g_aLimelightPartsAnchorPhone[95].x = 491.0f;
        g_aLimelightPartsAnchorPhone[95].y = 846.0f;
        g_aLimelightPartsAnchorPhone[98].x = 0.0f;
        g_aLimelightPartsAnchorPhone[98].y = 6e+01f;
        g_aLimelightPartsAnchorPhone[97].x = 0.0f;
        g_aLimelightPartsAnchorPhone[97].y = 0.0f;
        g_aLimelightPartsAnchorPhone[100].x = 302.0f;
        g_aLimelightPartsAnchorPhone[100].y = 399.0f;
        g_aLimelightPartsAnchorPhone[99].x = 302.0f;
        g_aLimelightPartsAnchorPhone[99].y = 107.0f;
        g_aLimelightPartsAnchorPhone[101].x = 132.0f;
        g_aLimelightPartsAnchorPhone[101].y = 474.0f;
        g_aLimelightPartsAnchorPhone[102].x = 132.0f;
        g_aLimelightPartsAnchorPhone[102].y = 5.1e+02f;
        g_aLimelightPartsAnchorPhone[104].x = 132.0f;
        g_aLimelightPartsAnchorPhone[104].y = 676.0f;
        g_aLimelightPartsAnchorPhone[103].x = 132.0f;
        g_aLimelightPartsAnchorPhone[103].y = 6.5e+02f;
        g_aLimelightPartsAnchorPhone[106].x = 132.0f;
        g_aLimelightPartsAnchorPhone[106].y = 823.0f;
        g_aLimelightPartsAnchorPhone[105].x = 132.0f;
        g_aLimelightPartsAnchorPhone[105].y = 712.0f;
        g_aLimelightPartsAnchorPhone[108].x = 151.0f;
        g_aLimelightPartsAnchorPhone[108].y = 555.0f;
        g_aLimelightPartsAnchorPhone[107].x = 151.0f;
        g_aLimelightPartsAnchorPhone[107].y = 525.0f;
        g_aLimelightPartsAnchorPhone[110].x = 151.0f;
        g_aLimelightPartsAnchorPhone[110].y = 615.0f;
        g_aLimelightPartsAnchorPhone[109].x = 151.0f;
        g_aLimelightPartsAnchorPhone[109].y = 585.0f;
        g_aLimelightSeparatorPhonePortrait[9].flHeight = 1.5707964f;
        g_aLimelightSeparatorPhonePortrait[12].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[13].flX = -53.0f;
        g_aLimelightSeparatorPhonePortrait[13].flY = 24.0f;
        g_aLimelightSeparatorPhonePortrait[13].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[13].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[14].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[15].flX = -53.0f;
        g_aLimelightSeparatorPhonePortrait[15].flY = 46.0f;
        g_aLimelightSeparatorPhonePortrait[15].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[15].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[16].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[17].flX = -53.0f;
        g_aLimelightSeparatorPhonePortrait[17].flY = 68.0f;
        g_aLimelightSeparatorPhonePortrait[17].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[17].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[19].flX = -53.0f;
        g_aLimelightSeparatorPhonePortrait[19].flY = 9e+01f;
        g_aLimelightSeparatorPhonePortrait[20].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[21].flX = -196.0f;
        g_aLimelightSeparatorPhonePortrait[21].flY = 34.0f;
        g_aLimelightSeparatorPhonePortrait[21].flWidth = 23.0f;
        g_aLimelightSeparatorPhonePortrait[21].flHeight = 1.5707964f;
        g_aLimelightSeparatorPhonePortrait[22].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[23].flX = -178.0f;
        g_aLimelightSeparatorPhonePortrait[23].flY = 24.0f;
        g_aLimelightSeparatorPhonePortrait[23].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[23].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[22].flX = -178.0f;
        g_aLimelightSeparatorPhonePortrait[25].flX = -178.0f;
        g_aLimelightSeparatorPhonePortrait[26].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[27].flX = -178.0f;
        g_aLimelightSeparatorPhonePortrait[27].flY = 68.0f;
        g_aLimelightSeparatorPhonePortrait[27].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[27].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[28].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[29].flX = -178.0f;
        g_aLimelightSeparatorPhonePortrait[29].flY = 9e+01f;
        g_aLimelightSeparatorPhonePortrait[29].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[29].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[30].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[31].flX = 195.0f;
        g_aLimelightSeparatorPhonePortrait[31].flY = 34.0f;
        g_aLimelightSeparatorPhonePortrait[31].flWidth = 23.0f;
        g_aLimelightSeparatorPhonePortrait[31].flHeight = 1.5707964f;
        g_aLimelightSeparatorPhonePortrait[32].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[33].flX = 73.0f;
        g_aLimelightSeparatorPhonePortrait[33].flY = 24.0f;
        g_aLimelightSeparatorPhonePortrait[33].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[33].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[36].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[37].flX = 73.0f;
        g_aLimelightSeparatorPhonePortrait[37].flY = 68.0f;
        g_aLimelightSeparatorPhonePortrait[37].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[37].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[35].flX = 73.0f;
        g_aLimelightSeparatorPhonePortrait[38].flX = 73.0f;
        g_aLimelightSeparatorPhonePortrait[38].flY = 79.0f;
        g_aLimelightPartsAnchorPhone[112].x = 509.0f;
        g_aLimelightPartsAnchorPhone[112].y = 554.0f;
        g_aLimelightPartsAnchorPhone[111].x = 509.0f;
        g_aLimelightPartsAnchorPhone[111].y = 524.0f;
        g_aLimelightSeparatorPhonePortrait[19].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[22].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[25].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[35].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[38].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[38].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[39].flX = 73.0f;
        g_aLimelightSeparatorPhonePortrait[39].flY = 9e+01f;
        g_aLimelightSeparatorPhonePortrait[39].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[39].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[41].flX = -202.0f;
        g_aLimelightSeparatorPhonePortrait[41].flY = 15.0f;
        g_aLimelightPartsAnchorPhone[114].x = 509.0f;
        g_aLimelightPartsAnchorPhone[114].y = 614.0f;
        g_aLimelightPartsAnchorPhone[113].x = 509.0f;
        g_aLimelightPartsAnchorPhone[113].y = 584.0f;
        g_aLimelightPartsAnchorPhone[116].x = 539.0f;
        g_aLimelightPartsAnchorPhone[116].y = 554.0f;
        g_aLimelightPartsAnchorPhone[115].x = 539.0f;
        g_aLimelightPartsAnchorPhone[115].y = 524.0f;
        g_aLimelightPartsAnchorPhone[118].x = 539.0f;
        g_aLimelightPartsAnchorPhone[118].y = 614.0f;
        g_aLimelightPartsAnchorPhone[117].x = 539.0f;
        g_aLimelightPartsAnchorPhone[117].y = 584.0f;
        g_aLimelightPartsAnchorPhone[120].x = 613.0f;
        g_aLimelightPartsAnchorPhone[120].y = 573.0f;
        g_aLimelightPartsAnchorPhone[119].x = 613.0f;
        g_aLimelightPartsAnchorPhone[119].y = 543.0f;
        g_aLimelightPartsAnchorPhone[122].x = 613.0f;
        g_aLimelightPartsAnchorPhone[122].y = 633.0f;
        g_aLimelightPartsAnchorPhone[121].x = 613.0f;
        g_aLimelightPartsAnchorPhone[121].y = 603.0f;
        g_aLimelightPartsAnchorPhone[124].x = 151.0f;
        g_aLimelightPartsAnchorPhone[124].y = 576.0f;
        g_aLimelightPartsAnchorPhone[123].x = 151.0f;
        g_aLimelightPartsAnchorPhone[123].y = 546.0f;
        g_aLimelightPartsAnchorPhone[126].x = 151.0f;
        g_aLimelightPartsAnchorPhone[126].y = 636.0f;
        g_aLimelightPartsAnchorPhone[125].x = 151.0f;
        g_aLimelightPartsAnchorPhone[125].y = 606.0f;
        g_aLimelightPartsAnchorPhone[128].x = 259.0f;
        g_aLimelightPartsAnchorPhone[128].y = 7.9e+02f;
        g_aLimelightPartsAnchorPhone[127].x = 1.5e+02f;
        g_aLimelightPartsAnchorPhone[127].y = 723.0f;
        g_aLimelightPartsAnchorPhone[130].x = 539.0f;
        g_aLimelightPartsAnchorPhone[130].y = 689.0f;
        g_aLimelightPartsAnchorPhone[129].x = 592.0f;
        g_aLimelightPartsAnchorPhone[129].y = 793.0f;
        g_aLimelightPartsAnchorPhone[132].x = 583.0f;
        g_aLimelightPartsAnchorPhone[132].y = 824.0f;
        g_aLimelightPartsAnchorPhone[131].x = 613.0f;
        g_aLimelightPartsAnchorPhone[131].y = 707.0f;
        g_aLimelightSeparatorPhonePortrait[0].flX = -102.0f;
        g_aLimelightSeparatorPhonePortrait[0].flY = -103.0f;
        g_aLimelightSeparatorPhonePortrait[1].flX = -112.0f;
        g_aLimelightSeparatorPhonePortrait[1].flY = -41.0f;
        g_aLimelightSeparatorPhonePortrait[1].flWidth = 83.0f;
        g_aLimelightSeparatorPhonePortrait[1].flHeight = 1.5707964f;
        g_aLimelightSeparatorPhonePortrait[2].flX = -204.0f;
        g_aLimelightSeparatorPhonePortrait[2].flY = -1.2e+02f;
        g_aLimelightSeparatorPhonePortrait[2].flWidth = 1.0f;
        g_aLimelightSeparatorPhonePortrait[2].flHeight = -1.5707964f;
        g_aLimelightSeparatorPhonePortrait[4].flX = -205.0f;
        g_aLimelightSeparatorPhonePortrait[4].flY = -37.0f;
        g_aLimelightSeparatorPhonePortrait[5].flX = -122.0f;
        g_aLimelightSeparatorPhonePortrait[5].flY = -36.0f;
        g_aLimelightSeparatorPhonePortrait[5].flWidth = 1.0f;
        g_aLimelightSeparatorPhonePortrait[5].flHeight = 1.5707964f;
        g_aLimelightSeparatorPhonePortrait[7].flX = -204.0f;
        g_aLimelightSeparatorPhonePortrait[7].flY = -119.0f;
        g_aLimelightSeparatorPhonePortrait[7].flWidth = 82.0f;
        g_aLimelightSeparatorPhonePortrait[7].flHeight = -1.5707964f;
        g_aLimelightSeparatorPhonePortrait[8].flX = -204.0f;
        g_aLimelightSeparatorPhonePortrait[8].flY = -37.0f;
        g_aLimelightSeparatorPhonePortrait[10].flX = -101.0f;
        g_aLimelightSeparatorPhonePortrait[10].flY = -72.0f;
        g_aLimelightSeparatorPhonePortrait[10].flWidth = 305.0f;
        g_aLimelightSeparatorPhonePortrait[10].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[11].flX = -101.0f;
        g_aLimelightSeparatorPhonePortrait[11].flY = -72.0f;
        g_aLimelightSeparatorPhonePortrait[11].flWidth = 0.0f;
        g_aLimelightSeparatorPhonePortrait[11].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[12].flX = -53.0f;
        g_aLimelightSeparatorPhonePortrait[12].flY = 13.0f;
        g_aLimelightSeparatorPhonePortrait[0].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[1].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[2].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[3].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[4].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[5].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[6].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[7].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[8].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[9].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[10].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[11].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[13].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[14].flX = -53.0f;
        g_aLimelightSeparatorPhonePortrait[14].flY = 35.0f;
        g_aLimelightSeparatorPhonePortrait[14].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[14].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[15].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[16].flX = -53.0f;
        g_aLimelightSeparatorPhonePortrait[16].flY = 57.0f;
        g_aLimelightSeparatorPhonePortrait[17].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[18].flX = -53.0f;
        g_aLimelightSeparatorPhonePortrait[18].flY = 79.0f;
        g_aLimelightSeparatorPhonePortrait[18].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[18].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[18].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[19].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[19].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[20].flX = -196.0f;
        g_aLimelightSeparatorPhonePortrait[20].flY = 9e+01f;
        g_aLimelightSeparatorPhonePortrait[21].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[22].flY = 13.0f;
        g_aLimelightSeparatorPhonePortrait[22].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[23].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[24].flX = -178.0f;
        g_aLimelightSeparatorPhonePortrait[24].flY = 35.0f;
        g_aLimelightSeparatorPhonePortrait[24].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[41].flWidth = 63.0f;
        g_aLimelightSeparatorPhonePortrait[42].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[43].flX = 2e+01f;
        g_aLimelightSeparatorPhonePortrait[43].flY = 15.0f;
        g_aLimelightSeparatorPhonePortrait[43].flWidth = 49.0f;
        g_aLimelightSeparatorPhonePortrait[43].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[44].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[45].flX = 2e+01f;
        g_aLimelightSeparatorPhonePortrait[45].flY = 61.0f;
        g_aLimelightSeparatorPhonePortrait[45].flWidth = 114.0f;
        g_aLimelightSeparatorPhonePortrait[45].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[46].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[47].flX = -197.0f;
        g_aLimelightSeparatorPhonePortrait[47].flY = 21.0f;
        g_aLimelightSeparatorPhonePortrait[47].flWidth = 183.0f;
        g_aLimelightSeparatorPhonePortrait[47].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[48].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[49].flX = -197.0f;
        g_aLimelightSeparatorPhonePortrait[49].flY = 34.0f;
        g_aLimelightSeparatorPhonePortrait[49].flWidth = 183.0f;
        g_aLimelightSeparatorPhonePortrait[49].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[25].flY = 46.0f;
        g_aLimelightSeparatorPhonePortrait[25].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[25].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[26].flX = -178.0f;
        g_aLimelightSeparatorPhonePortrait[26].flY = 57.0f;
        g_aLimelightSeparatorPhonePortrait[26].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[26].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[27].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[28].flX = -178.0f;
        g_aLimelightSeparatorPhonePortrait[28].flY = 79.0f;
        g_aLimelightSeparatorPhonePortrait[29].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[30].flX = 195.0f;
        g_aLimelightSeparatorPhonePortrait[30].flY = 9e+01f;
        g_aLimelightSeparatorPhonePortrait[30].flWidth = 23.0f;
        g_aLimelightSeparatorPhonePortrait[30].flHeight = 1.5707964f;
        g_aLimelightSeparatorPhonePortrait[31].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[32].flX = 73.0f;
        g_aLimelightSeparatorPhonePortrait[32].flY = 13.0f;
        g_aLimelightSeparatorPhonePortrait[33].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[34].flX = 73.0f;
        g_aLimelightSeparatorPhonePortrait[34].flY = 35.0f;
        g_aLimelightSeparatorPhonePortrait[34].flWidth = 105.0f;
        g_aLimelightSeparatorPhonePortrait[34].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[34].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[35].flY = 46.0f;
        g_aLimelightSeparatorPhonePortrait[35].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[35].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[36].flX = 73.0f;
        g_aLimelightSeparatorPhonePortrait[36].flY = 57.0f;
        g_aLimelightSeparatorPhonePortrait[37].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[38].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[39].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[40].flX = 8.0f;
        g_aLimelightSeparatorPhonePortrait[40].flY = 85.0f;
        g_aLimelightSeparatorPhonePortrait[40].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[41].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[41].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[42].flX = -66.0f;
        g_aLimelightSeparatorPhonePortrait[42].flY = 15.0f;
        g_aLimelightSeparatorPhonePortrait[42].flWidth = 63.0f;
        g_aLimelightSeparatorPhonePortrait[42].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[43].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[44].flX = 153.0f;
        g_aLimelightSeparatorPhonePortrait[44].flY = 15.0f;
        g_aLimelightSeparatorPhonePortrait[45].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[46].flX = -197.0f;
        g_aLimelightSeparatorPhonePortrait[46].flY = 9.0f;
        g_aLimelightSeparatorPhonePortrait[46].flWidth = 1e+02f;
        g_aLimelightSeparatorPhonePortrait[46].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[47].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[48].flX = 13.0f;
        g_aLimelightSeparatorPhonePortrait[48].flY = 21.0f;
        g_aLimelightSeparatorPhonePortrait[49].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[50].flX = 13.0f;
        g_aLimelightSeparatorPhonePortrait[50].flY = 34.0f;
        g_aLimelightSeparatorPhonePortrait[50].flWidth = 183.0f;
        g_aLimelightSeparatorPhonePortrait[50].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[50].nAnchorMode = 4;
        g_aLimelightSeparatorPhonePortrait[51].flX = 13.0f;
        g_aLimelightSeparatorPhonePortrait[51].flY = 51.0f;
        g_aLimelightSeparatorPhonePortrait[51].flWidth = 183.0f;
        g_aLimelightSeparatorPhonePortrait[51].flHeight = 0.0f;
        g_aLimelightSeparatorPhonePortrait[51].nAnchorMode = 4;
        g_aLimelightPartsAnchorPhone[2].x = 263.0f;
        g_aLimelightPartsAnchorPhone[2].y = 937.0f;
        g_aLimelightPositionPhoneState[0].flX = g_aLimelightPartsAnchorPhone[2].x;
        g_aLimelightPartsPhone[205].flX = 0.0f;
        g_aLimelightPartsPhone[205].flY = 0.0f;
        g_aLimelightPartsPhone[210].flX = 0.0f;
        g_aLimelightPartsPhone[210].flY = 0.0f;
        g_aLimelightPartsPhone[213].flX = 0.0f;
        g_aLimelightPartsPhone[213].flY = 0.0f;
        g_aLimelightPartsPhone[218].flX = 0.0f;
        g_aLimelightPartsPhone[218].flY = 0.0f;
        g_aLimelightPartsPhone[221].flX = 0.0f;
        g_aLimelightPartsPhone[221].flY = 0.0f;
        g_aLimelightPartsPhone[226].flX = 0.0f;
        g_aLimelightPartsPhone[226].flY = 0.0f;
        g_aLimelightPartsPhone[229].flX = 0.0f;
        g_aLimelightPartsPhone[229].flY = 0.0f;
        g_aLimelightPartsPhone[234].flX = 0.0f;
        g_aLimelightPartsPhone[234].flY = 0.0f;
        g_aLimelightPartsPhone[237].flX = 0.0f;
        g_aLimelightPartsPhone[237].flY = 0.0f;
        g_aLimelightPartsPhone[242].flX = 0.0f;
        g_aLimelightPartsPhone[242].flY = 0.0f;
        g_aLimelightPartsPhone[245].flX = 0.0f;
        g_aLimelightPartsPhone[245].flY = 0.0f;
        g_aLimelightPartsPhone[250].flX = 0.0f;
        g_aLimelightPartsPhone[250].flY = 0.0f;
        g_aLimelightPartsPhone[253].flX = 0.0f;
        g_aLimelightPartsPhone[253].flY = 0.0f;
        g_aLimelightPositionPhoneState[0].flY = g_aLimelightPartsAnchorPhone[2].y;
        g_aLimelightPartsPhone[1].flWidth = 242.0f;
        g_aLimelightPartsPhone[1].flHeight = 6e+01f;
        g_aLimelightPositionPhoneState[0].flWidth = g_aLimelightPartsPhone[1].flWidth;
        g_aLimelightPositionPhoneState[0].flHeight = g_aLimelightPartsPhone[1].flHeight;
        g_aLimelightPositionPhoneState[2].nAnchorMode = 0;
        g_aLimelightPositionPhoneState[3].flX = 589.0f;
        g_aLimelightPositionPhoneState[3].flY = 898.0f;
        g_aLimelightPositionPhoneState[3].flWidth = 64.0f;
        g_aLimelightPositionPhoneState[3].flHeight = 54.0f;
        g_aLimelightPositionPhoneState[3].nAnchorMode = 0;
        g_aLimelightPositionPhoneState[0].nAnchorMode = 0;
        g_aLimelightPositionPhoneState[1].flX = 108.0f;
        g_aLimelightPositionPhoneState[1].flY = 397.0f;
        g_aLimelightPositionPhoneState[1].flWidth = 54.0f;
        g_aLimelightPositionPhoneState[1].flHeight = 54.0f;
        g_aLimelightPositionPhoneState[1].nAnchorMode = 0;
        g_aLimelightPositionPhoneState[2].flX = 611.0f;
        g_aLimelightPositionPhoneState[2].flY = 397.0f;
        g_aLimelightPositionPhoneState[2].flWidth = 54.0f;
        g_aLimelightPositionPhoneState[2].flHeight = 54.0f;
        g_aLimelightPositionPhoneStatePortrait[2].nAnchorMode = 0;
        g_aLimelightPositionPhoneStatePortrait[3].flX = 88.0f;
        g_aLimelightPositionPhoneStatePortrait[3].flY = 144.0f;
        g_aLimelightPositionPhoneStatePortrait[3].flWidth = 46.0f;
        g_aLimelightPositionPhoneStatePortrait[0].flX = -83.0f;
        g_aLimelightPositionPhoneStatePortrait[0].flY = -67.0f;
        g_aLimelightPositionPhoneStatePortrait[0].nAnchorMode = 5;
        g_aLimelightPositionPhoneStatePortrait[1].nAnchorMode = 0;
        g_aLimelightPositionPhoneStatePortrait[3].flHeight = 44.0f;
        g_aLimelightPositionPhoneStatePortrait[3].nAnchorMode = 4;
        g_aLimelightPositionPhoneStateDefault[0].nAnchorMode = 5;
        g_aLimelightPositionPhoneStateDefault[3].flX = 1.6e+02f;
        g_aLimelightPositionPhoneStateDefault[3].flY = 103.0f;
        g_aLimelightPositionPhoneStateDefault[3].flWidth = 46.0f;
        g_aLimelightPositionPhoneStateDefault[0].flX = -70.5f;
        g_aLimelightPositionPhoneStateDefault[0].flY = -37.0f;
        g_aLimelightPositionPhoneStateDefault[1].nAnchorMode = 0;
        g_aLimelightPositionPhoneStateDefault[2].nAnchorMode = 0;
        g_aLimelightPositionPhoneStateDefault[3].flHeight = 44.0f;
        g_aLimelightPositionPhoneStateDefault[3].nAnchorMode = 4;
        g_aLimelightColorMarkerRects[0].flX = 179.0f;
        g_aLimelightColorMarkerRects[0].flY = 117.0f;
        g_aLimelightColorMarkerRects[1].flX = 123.0f;
        g_aLimelightColorMarkerRects[1].flY = 117.0f;
        g_aLimelightColorMarkerRects[2].flX = 121.0f;
        g_aLimelightColorMarkerRects[2].flY = 118.0f;
        g_aLimelightColorMarkerRects[3].flX = 119.0f;
        g_aLimelightColorMarkerRects[3].flY = 1.2e+02f;
        g_aLimelightColorMarkerRects[4].flX = 118.0f;
        g_aLimelightColorMarkerRects[4].flY = 122.0f;
        g_aLimelightColorMarkerRects[5].flX = 117.0f;
        g_aLimelightColorMarkerRects[5].flY = 347.0f;
        g_aLimelightColorMarkerRects[6].flX = 118.0f;
        g_aLimelightColorMarkerRects[6].flY = 349.0f;
        g_aLimelightColorMarkerRects[7].flX = 1.2e+02f;
        g_aLimelightColorMarkerRects[7].flY = 351.0f;
        g_aLimelightColorMarkerRects[8].flX = 122.0f;
        g_aLimelightColorMarkerRects[8].flY = 352.0f;
        g_aLimelightColorMarkerRects[9].flX = 384.0f;
        g_aLimelightColorMarkerRects[9].flY = 353.0f;
        g_aLimelightColorMarkerRects[10].flX = 589.0f;
        g_aLimelightColorMarkerRects[10].flY = 117.0f;
        g_aLimelightColorMarkerRects[11].flX = 646.0f;
        g_aLimelightColorMarkerRects[11].flY = 117.0f;
        g_aLimelightColorMarkerRects[12].flX = 648.0f;
        g_aLimelightColorMarkerRects[12].flY = 118.0f;
        g_aLimelightColorMarkerRects[13].flX = 6.5e+02f;
        g_aLimelightColorMarkerRects[13].flY = 1.2e+02f;
        g_aLimelightColorMarkerRects[14].flX = 651.0f;
        g_aLimelightColorMarkerRects[14].flY = 122.0f;
        g_aLimelightColorMarkerRects[15].flX = 652.0f;
        g_aLimelightColorMarkerRects[15].flY = 347.0f;
        g_aLimelightColorMarkerRects[16].flX = 651.0f;
        g_aLimelightColorMarkerRects[16].flY = 349.0f;
        g_aLimelightColorMarkerRects[17].flX = 649.0f;
        g_aLimelightColorMarkerRects[17].flY = 351.0f;
        g_aLimelightColorMarkerRects[18].flX = 647.0f;
        g_aLimelightColorMarkerRects[18].flY = 352.0f;
        g_aLimelightColorMarkerRects[19].flX = 384.0f;
        g_aLimelightColorMarkerRects[19].flY = 353.0f;
        g_aLimelightColorMarkerRects[20].flX = 179.0f;
        g_aLimelightColorMarkerRects[20].flY = 409.0f;
        g_aLimelightColorMarkerRects[21].flX = 123.0f;
        g_aLimelightColorMarkerRects[21].flY = 409.0f;
        g_aLimelightColorMarkerRects[22].flX = 121.0f;
        g_aLimelightColorMarkerRects[22].flY = 4.1e+02f;
        g_aLimelightColorMarkerRects[23].flX = 119.0f;
        g_aLimelightColorMarkerRects[23].flY = 412.0f;
        g_aLimelightColorMarkerRects[24].flX = 118.0f;
        g_aLimelightColorMarkerRects[24].flY = 414.0f;
        g_aLimelightColorMarkerRects[25].flX = 117.0f;
        g_aLimelightColorMarkerRects[25].flY = 904.0f;
        g_aLimelightColorMarkerRects[26].flX = 118.0f;
        g_aLimelightColorMarkerRects[26].flY = 906.0f;
        g_aLimelightColorMarkerRects[27].flX = 1.2e+02f;
        g_aLimelightColorMarkerRects[27].flY = 908.0f;
        g_aLimelightColorMarkerRects[28].flX = 122.0f;
        g_aLimelightColorMarkerRects[28].flY = 909.0f;
        g_aLimelightColorMarkerRects[29].flX = 384.0f;
        g_aLimelightColorMarkerRects[29].flY = 9.1e+02f;
        g_LimelightColorMarkerOrigin.x = 384.0f;
        g_LimelightColorMarkerOrigin.y = 9.1e+02f;
        g_aLimelightColorMarkerRects[30].flX = 589.0f;
        g_aLimelightColorMarkerRects[30].flY = 409.0f;
        g_aLimelightColorMarkerRects[31].flX = 646.0f;
        g_aLimelightColorMarkerRects[31].flY = 409.0f;
        g_aLimelightColorMarkerRects[32].flX = 648.0f;
        g_aLimelightColorMarkerRects[32].flY = 4.1e+02f;
        g_aLimelightColorMarkerRects[33].flX = 6.5e+02f;
        g_aLimelightColorMarkerRects[33].flY = 412.0f;
        g_aLimelightColorMarkerRects[34].flX = 651.0f;
        g_aLimelightColorMarkerRects[34].flY = 414.0f;
        g_aLimelightColorMarkerRects[35].flX = 652.0f;
        g_aLimelightColorMarkerRects[35].flY = 904.0f;
        g_aLimelightColorMarkerRects[36].flX = 651.0f;
        g_aLimelightColorMarkerRects[36].flY = 906.0f;
        g_aLimelightColorMarkerRects[37].flX = 649.0f;
        g_aLimelightColorMarkerRects[37].flY = 908.0f;
        g_aLimelightColorMarkerRects[38].flX = 647.0f;
        g_aLimelightColorMarkerRects[38].flY = 909.0f;
        g_LimelightCenterPositionPhoneState.flX = 119.0f;
        g_LimelightCenterPositionPhoneState.flY = 439.0f;
        g_LimelightCenterPositionPhonePortrait.flX = -141.0f;
        g_LimelightCenterPositionPhonePortrait.flY = -32.0f;
        g_LimelightCenterPositionPhoneDefault.flX = -214.0f;
        g_LimelightCenterPositionPhoneDefault.flY = -31.0f;
        g_aLimelightPartsPhone[1].flWidth = 242.0f;
        g_aLimelightPartsPhone[1].flHeight = 6e+01f;
        g_aLimelightPartsPhone[4].flX = g_aLimelightPartsPhone[3].flX;
        g_aLimelightPartsPhone[4].flWidth = g_aLimelightPartsPhone[3].flWidth;
        g_aLimelightPartsPhone[8].flX = g_aLimelightPartsPhone[7].flX;
        g_aLimelightPartsPhone[8].flWidth = g_aLimelightPartsPhone[7].flWidth;
        g_aLimelightPartsPhone[11].flX = g_aLimelightPartsPhone[9].flX;
        g_aLimelightPartsPhone[11].flWidth = g_aLimelightPartsPhone[9].flWidth;
        g_aLimelightPartsPhone[12].flX = g_aLimelightPartsPhone[3].flX;
        g_aLimelightPartsPhone[12].flWidth = g_aLimelightPartsPhone[3].flWidth;
        g_aLimelightPartsPhone[15].flX = g_aLimelightPartsPhone[14].flX;
        g_aLimelightPartsPhone[15].flWidth = g_aLimelightPartsPhone[14].flWidth;
        g_aLimelightPartsPhone[16].flX = g_aLimelightPartsPhone[7].flX;
        g_aLimelightPartsPhone[16].flWidth = g_aLimelightPartsPhone[7].flWidth;
        g_aLimelightPartsPhone[17].flX = g_aLimelightPartsPhone[7].flX;
        g_aLimelightPartsPhone[17].flWidth = g_aLimelightPartsPhone[7].flWidth;
        g_aLimelightPartsPhone[20].flX = g_aLimelightPartsPhone[9].flX;
        g_aLimelightPartsPhone[20].flWidth = g_aLimelightPartsPhone[9].flWidth;
        g_aLimelightPartsPhone[25].flX = g_aLimelightPartsPhone[22].flX;
        g_aLimelightPartsPhone[25].flWidth = g_aLimelightPartsPhone[22].flWidth;
        g_aLimelightPartsPhone[27].flX = g_aLimelightPartsPhone[24].flX;
        g_aLimelightPartsPhone[27].flWidth = g_aLimelightPartsPhone[24].flWidth;
        g_aLimelightPartsPhone[30].flX = g_aLimelightPartsPhone[28].flX;
        g_aLimelightPartsPhone[30].flWidth = g_aLimelightPartsPhone[28].flWidth;
        g_aLimelightPartsPhone[31].flX = g_aLimelightPartsPhone[28].flX;
        g_aLimelightPartsPhone[31].flWidth = g_aLimelightPartsPhone[28].flWidth;
        g_aLimelightPartsPhone[39].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[39].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[40].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[40].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[41].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[41].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[43].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[43].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[44].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[44].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[46].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[46].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[48].flX = g_aLimelightPartsPhone[47].flX;
        g_aLimelightPartsPhone[48].flWidth = g_aLimelightPartsPhone[47].flWidth;
        g_aLimelightPartsPhone[49].flX = g_aLimelightPartsPhone[47].flX;
        g_aLimelightPartsPhone[49].flWidth = g_aLimelightPartsPhone[47].flWidth;
        g_aLimelightPartsPhone[51].flX = g_aLimelightPartsPhone[47].flX;
        g_aLimelightPartsPhone[51].flWidth = g_aLimelightPartsPhone[47].flWidth;
        g_aLimelightPartsPhone[52].flX = g_aLimelightPartsPhone[47].flX;
        g_aLimelightPartsPhone[52].flWidth = g_aLimelightPartsPhone[47].flWidth;
        g_aLimelightPartsPhone[54].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[54].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[55].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[55].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[56].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[56].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[57].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[57].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[59].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[59].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[60].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[60].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[62].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[62].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[64].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[64].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[65].flX = g_aLimelightPartsPhone[38].flX;
        g_aLimelightPartsPhone[65].flWidth = g_aLimelightPartsPhone[38].flWidth;
        g_aLimelightPartsPhone[70].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[70].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[71].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[71].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[72].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[72].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[73].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[73].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[75].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[75].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[76].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[76].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[78].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[78].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[79].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[79].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[80].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[80].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[81].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[81].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[83].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[83].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[84].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[84].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[86].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[86].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[87].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[87].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[89].flX = g_aLimelightPartsPhone[88].flX;
        g_aLimelightPartsPhone[89].flWidth = g_aLimelightPartsPhone[88].flWidth;
        g_aLimelightPartsPhone[92].flX = g_aLimelightPartsPhone[91].flX;
        g_aLimelightPartsPhone[92].flWidth = g_aLimelightPartsPhone[91].flWidth;
        g_aLimelightPartsPhone[99].flX = g_aLimelightPartsPhone[97].flX;
        g_aLimelightPartsPhone[99].flWidth = g_aLimelightPartsPhone[97].flWidth;
        g_aLimelightPartsPhone[100].flX = g_aLimelightPartsPhone[97].flX;
        g_aLimelightPartsPhone[100].flWidth = g_aLimelightPartsPhone[97].flWidth;
        g_aLimelightPartsPhone[103].flX = g_aLimelightPartsPhone[102].flX;
        g_aLimelightPartsPhone[103].flWidth = g_aLimelightPartsPhone[102].flWidth;
        g_aLimelightPartsPhone[104].flX = g_aLimelightPartsPhone[102].flX;
        g_aLimelightPartsPhone[104].flWidth = g_aLimelightPartsPhone[102].flWidth;
        g_aLimelightPartsPhone[107].flX = g_aLimelightPartsPhone[105].flX;
        g_aLimelightPartsPhone[107].flWidth = g_aLimelightPartsPhone[105].flWidth;
        g_aLimelightPartsPhone[108].flX = g_aLimelightPartsPhone[105].flX;
        g_aLimelightPartsPhone[108].flWidth = g_aLimelightPartsPhone[105].flWidth;
        g_aLimelightPartsPhone[110].flX = g_aLimelightPartsPhone[105].flX;
        g_aLimelightPartsPhone[110].flWidth = g_aLimelightPartsPhone[105].flWidth;
        g_aLimelightPartsPhone[111].flX = g_aLimelightPartsPhone[105].flX;
        g_aLimelightPartsPhone[111].flWidth = g_aLimelightPartsPhone[105].flWidth;
        g_aLimelightPartsPhone[112].flX = g_aLimelightPartsPhone[105].flX;
        g_aLimelightPartsPhone[112].flWidth = g_aLimelightPartsPhone[105].flWidth;
        g_aLimelightPartsPhone[113].flX = g_aLimelightPartsPhone[105].flX;
        g_aLimelightPartsPhone[113].flWidth = g_aLimelightPartsPhone[105].flWidth;
        g_aLimelightPartsPhone[116].flX = g_aLimelightPartsPhone[105].flX;
        g_aLimelightPartsPhone[116].flWidth = g_aLimelightPartsPhone[105].flWidth;
        g_aLimelightPartsPhone[119].flX = g_aLimelightPartsPhone[118].flX;
        g_aLimelightPartsPhone[119].flWidth = g_aLimelightPartsPhone[118].flWidth;
        g_aLimelightPartsPhone[120].flX = g_aLimelightPartsPhone[118].flX;
        g_aLimelightPartsPhone[120].flWidth = g_aLimelightPartsPhone[118].flWidth;
        g_aLimelightPartsPhone[121].flX = g_aLimelightPartsPhone[118].flX;
        g_aLimelightPartsPhone[121].flWidth = g_aLimelightPartsPhone[118].flWidth;
        g_aLimelightPartsPhone[126].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[126].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[127].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[127].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[128].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[128].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[129].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[129].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[131].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[131].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[132].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[132].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[136].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[136].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[137].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[137].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[139].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[139].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[140].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[140].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[142].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[142].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[143].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[143].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[144].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[144].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[147].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[147].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[148].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[148].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[150].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[150].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[151].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[151].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[152].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[152].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[153].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[153].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[155].flX = g_aLimelightPartsPhone[124].flX;
        g_aLimelightPartsPhone[155].flWidth = g_aLimelightPartsPhone[124].flWidth;
        g_aLimelightPartsPhone[156].flWidth = g_aLimelightPartsPhone[134].flWidth;
        g_aLimelightPartsPhone[158].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[158].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[159].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[159].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[160].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[160].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[161].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[161].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[163].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[163].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[164].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[164].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[166].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[166].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[167].flWidth = g_aLimelightPartsPhone[145].flWidth;
        g_aLimelightPartsPhone[169].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[169].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[171].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[171].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[172].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[172].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[174].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[174].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[175].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[175].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[176].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[176].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[177].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[177].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[179].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[179].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[180].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[180].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[182].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[182].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[183].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[183].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[184].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[184].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[185].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[185].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[187].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[187].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[188].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[188].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[190].flX = g_aLimelightPartsPhone[168].flX;
        g_aLimelightPartsPhone[190].flWidth = g_aLimelightPartsPhone[168].flWidth;
        g_aLimelightPartsPhone[191].flX = g_aLimelightPartsPhone[135].flX;
        g_aLimelightPartsPhone[191].flWidth = g_aLimelightPartsPhone[135].flWidth;
        g_aLimelightPartsPhone[196].flX = g_aLimelightPartsPhone[195].flX;
        g_aLimelightPartsPhone[196].flWidth = g_aLimelightPartsPhone[195].flWidth;
        g_aLimelightPartsPhone[201].flX = g_aLimelightPartsPhone[200].flX;
        g_aLimelightPartsPhone[201].flWidth = g_aLimelightPartsPhone[200].flWidth;
        g_aLimelightPartsPhone[208].flX = g_aLimelightPartsPhone[24].flX;
        g_aLimelightPartsPhone[208].flWidth = g_aLimelightPartsPhone[24].flWidth;
        g_aLimelightPartsPhone[209].flX = g_aLimelightPartsPhone[206].flX;
        g_aLimelightPartsPhone[209].flWidth = g_aLimelightPartsPhone[206].flWidth;
        g_aLimelightPartsPhone[211].flX = g_aLimelightPartsPhone[24].flX;
        g_aLimelightPartsPhone[211].flWidth = g_aLimelightPartsPhone[24].flWidth;
        g_aLimelightPartsPhone[216].flX = g_aLimelightPartsPhone[215].flX;
        g_aLimelightPartsPhone[216].flWidth = g_aLimelightPartsPhone[215].flWidth;
        g_aLimelightPartsPhone[217].flX = g_aLimelightPartsPhone[215].flX;
        g_aLimelightPartsPhone[217].flWidth = g_aLimelightPartsPhone[215].flWidth;
        g_aLimelightPartsPhone[219].flX = g_aLimelightPartsPhone[215].flX;
        g_aLimelightPartsPhone[219].flWidth = g_aLimelightPartsPhone[215].flWidth;
        g_aLimelightPartsPhone[220].flX = g_aLimelightPartsPhone[215].flX;
        g_aLimelightPartsPhone[220].flWidth = g_aLimelightPartsPhone[215].flWidth;
        g_aLimelightPartsPhone[222].flX = g_aLimelightPartsPhone[215].flX;
        g_aLimelightPartsPhone[222].flWidth = g_aLimelightPartsPhone[215].flWidth;
        g_aLimelightPartsPhone[223].flX = g_aLimelightPartsPhone[215].flX;
        g_aLimelightPartsPhone[223].flWidth = g_aLimelightPartsPhone[215].flWidth;
        g_aLimelightPartsPhone[224].flX = g_aLimelightPartsPhone[215].flX;
        g_aLimelightPartsPhone[224].flWidth = g_aLimelightPartsPhone[215].flWidth;
        g_aLimelightPartsPhone[227].flX = g_aLimelightPartsPhone[225].flX;
        g_aLimelightPartsPhone[227].flWidth = g_aLimelightPartsPhone[225].flWidth;
        g_aLimelightPartsPhone[228].flX = g_aLimelightPartsPhone[225].flX;
        g_aLimelightPartsPhone[228].flWidth = g_aLimelightPartsPhone[225].flWidth;
        g_aLimelightPartsPhone[230].flX = g_aLimelightPartsPhone[225].flX;
        g_aLimelightPartsPhone[230].flWidth = g_aLimelightPartsPhone[225].flWidth;
        g_aLimelightPartsPhone[231].flX = g_aLimelightPartsPhone[225].flX;
        g_aLimelightPartsPhone[231].flWidth = g_aLimelightPartsPhone[225].flWidth;
        g_aLimelightPartsPhone[232].flX = g_aLimelightPartsPhone[225].flX;
        g_aLimelightPartsPhone[232].flWidth = g_aLimelightPartsPhone[225].flWidth;
        g_aLimelightPartsPhone[233].flX = g_aLimelightPartsPhone[225].flX;
        g_aLimelightPartsPhone[233].flWidth = g_aLimelightPartsPhone[225].flWidth;
        g_aLimelightPartsPhone[238].flX = g_aLimelightPartsPhone[236].flX;
        g_aLimelightPartsPhone[238].flWidth = g_aLimelightPartsPhone[236].flWidth;
        g_aLimelightPartsPhone[239].flX = g_aLimelightPartsPhone[236].flX;
        g_aLimelightPartsPhone[239].flWidth = g_aLimelightPartsPhone[236].flWidth;
        g_aLimelightPartsPhone[241].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[241].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[243].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[243].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[244].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[244].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[246].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[246].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[247].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[247].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[248].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[248].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[249].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[249].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsPhone[252].flX = g_aLimelightPartsPhone[68].flX;
        g_aLimelightPartsPhone[252].flWidth = g_aLimelightPartsPhone[68].flWidth;
        g_aLimelightPartsAnchorPhone[2] = savedAnchor;
        g_aLimelightPositionPhoneStatePortrait[1].flX = g_aLimelightPositionPhoneState[1].flX;
        g_aLimelightPositionPhoneStatePortrait[1].flWidth =
            g_aLimelightPositionPhoneState[1].flWidth;
        g_aLimelightPositionPhoneStatePortrait[2].flX = g_aLimelightPositionPhoneState[2].flX;
        g_aLimelightPositionPhoneStatePortrait[2].flWidth =
            g_aLimelightPositionPhoneState[2].flWidth;
        g_aLimelightPositionPhoneStateDefault[1].flX = g_aLimelightPositionPhoneState[1].flX;
        g_aLimelightPositionPhoneStateDefault[1].flWidth =
            g_aLimelightPositionPhoneState[1].flWidth;
        g_aLimelightPositionPhoneStateDefault[2].flX = g_aLimelightPositionPhoneState[2].flX;
        g_aLimelightPositionPhoneStateDefault[2].flWidth =
            g_aLimelightPositionPhoneState[2].flWidth;
    }
}
