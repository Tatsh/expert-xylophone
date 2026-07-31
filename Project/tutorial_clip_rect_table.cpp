//
//  tutorial_clip_rect_table.cpp
//  REFLEC BEAT plus
//
//  The tutorial artwork atlas clip-rectangle table (g_pTutorialClipRect), seeded at load time.
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#include <CoreGraphics/CoreGraphics.h>

// The per-texture-type source rectangles into the tutorial artwork atlas, read by
// -[RBMenuTutorialView getClipRect:]. Seeded once at load by SetupDialogLayoutCoordTable; the
// consumer views it read-only. @ghidraAddress 0x3de058
extern "C" CGRect g_pTutorialClipRect[34];
CGRect g_pTutorialClipRect[34] = {};

/**
 * @brief Seeds the tutorial artwork atlas clip-rectangle table with each texture type's source
 * rectangle (origin and size, in atlas pixels).
 *
 * A load-time constructor (registered in the module init-function list).
 * @ghidraAddress 0x1414e0
 */
__attribute__((constructor)) void SetupDialogLayoutCoordTable() {
    static const CGRect kClipRects[] = {
        {{2, 2}, {357, 52}},     {{2, 56}, {357, 52}},     {{2, 110}, {357, 52}},
        {{2, 164}, {357, 24}},   {{2, 190}, {357, 24}},    {{2, 216}, {357, 80}},
        {{2, 298}, {357, 80}},   {{2, 380}, {357, 80}},    {{2, 462}, {357, 80}},
        {{2, 544}, {357, 80}},   {{2, 626}, {357, 80}},    {{2, 708}, {357, 52}},
        {{2, 762}, {357, 52}},   {{2, 816}, {357, 24}},    {{2, 842}, {357, 24}},
        {{2, 868}, {357, 52}},   {{2, 922}, {357, 24}},    {{361, 2}, {357, 80}},
        {{361, 84}, {357, 52}},  {{361, 138}, {357, 52}},  {{361, 192}, {357, 80}},
        {{361, 274}, {136, 96}}, {{499, 274}, {48, 56}},   {{498, 332}, {24, 22}},
        {{525, 332}, {24, 22}},  {{551, 274}, {68, 72}},   {{621, 274}, {72, 136}},
        {{695, 274}, {72, 136}}, {{361, 412}, {398, 134}}, {{361, 548}, {430, 124}},
        {{551, 348}, {16, 16}},  {{567, 348}, {16, 16}},   {{551, 364}, {16, 16}},
        {{567, 364}, {16, 16}},
    };
    for (int i = 0; i < 34; ++i) {
        g_pTutorialClipRect[i] = kClipRects[i];
    }
}
