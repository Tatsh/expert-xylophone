//
//  UIColor+RB.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (category UIColor(RB)). Verified against
//  the arm64 disassembly of InitializeUIColorPalette (@0x5517c): the routine pushes an autorelease
//  pool, fills sixteen global colour slots (originally DAT_1003cff88 through DAT_1003d0000, eight
//  bytes apart) via colorWithRed:green:blue:alpha:, whiteColor, and purpleColor, then pops the
//  pool.
//  The decompiler dropped the arguments of the first and third slots because their components are
//  register-zeroed (movi v0/v1/v2, #0); the disassembly shows the dimming cover takes alpha 0.5
//  (fmov d3, 0x3fe0000000000000 at @0x55158) and the opaque black takes alpha 1.0
//  (fmov d8, 0x3ff0000000000000 at @0x551a4). Every red, green, and blue component is an exact
//  eight-bit value over 255, read from the double constants at DAT_1002ef5e8 upward and confirmed
//  by reading that memory. Several colours recur under more than one slot, matching the binary.
//
//  The binary has no named accessor for these colours: each screen reads the raw global slot
//  directly. The palette is modelled here as an ordered table built once behind
//  +rbPaletteColorAtIndex:, mirroring the binary's single-shot InitializeUIColorPalette.
//

#import "UIColor+RB.h"

// The RGB component constants, each an exact eight-bit value over 255, read from the double
// constants at DAT_1002ef5e8 upward. The names mirror the renamed Ghidra globals
// (g_PaletteColor<Name><Channel>).

// Green grass (63, 167, 0). @ghidraAddress 0x2ef5e8, 0x2ef5f0
static const CGFloat kPaletteColorGreenGrassRed = 63.0 / 255.0;
static const CGFloat kPaletteColorGreenGrassGreen = 167.0 / 255.0;

// Magenta (254, 33, 248). @ghidraAddress 0x2ef5f8, 0x2ef600, 0x2ef608
static const CGFloat kPaletteColorMagentaRed = 254.0 / 255.0;
static const CGFloat kPaletteColorMagentaGreen = 33.0 / 255.0;
static const CGFloat kPaletteColorMagentaBlue = 248.0 / 255.0;

// Dark green (2, 111, 0). @ghidraAddress 0x2ef610, 0x2ef618
static const CGFloat kPaletteColorDarkGreenRed = 2.0 / 255.0;
static const CGFloat kPaletteColorDarkGreenGreen = 111.0 / 255.0;

// Leaf green (26, 151, 0). @ghidraAddress 0x2ef620, 0x2ef628
static const CGFloat kPaletteColorLeafGreenRed = 26.0 / 255.0;
static const CGFloat kPaletteColorLeafGreenGreen = 151.0 / 255.0;

// Steel blue (133, 173, 217). @ghidraAddress 0x2ef630, 0x2ef638, 0x2ef640
static const CGFloat kPaletteColorSteelBlueRed = 133.0 / 255.0;
static const CGFloat kPaletteColorSteelBlueGreen = 173.0 / 255.0;
static const CGFloat kPaletteColorSteelBlueBlue = 217.0 / 255.0;

// Gold (229, 183, 49). @ghidraAddress 0x2ef648, 0x2ef650, 0x2ef658
static const CGFloat kPaletteColorGoldRed = 229.0 / 255.0;
static const CGFloat kPaletteColorGoldGreen = 183.0 / 255.0;
static const CGFloat kPaletteColorGoldBlue = 49.0 / 255.0;

// The absent channel of a colour whose red, green, or blue is register-zeroed in the binary, and
// the opaque and half alphas.
static const CGFloat kPaletteChannelZero = 0.0;
static const CGFloat kPaletteAlphaOpaque = 1.0;
static const CGFloat kPaletteDimmingCoverAlpha = 0.5;

@implementation UIColor (RB)

+ (nullable UIColor *)rbPaletteColorAtIndex:(RBPaletteIndex)index {
    static NSArray<UIColor *> *palette = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x5517c */
      UIColor *greenGrass = [UIColor colorWithRed:kPaletteColorGreenGrassRed
                                            green:kPaletteColorGreenGrassGreen
                                             blue:kPaletteChannelZero
                                            alpha:kPaletteAlphaOpaque];
      UIColor *magenta = [UIColor colorWithRed:kPaletteColorMagentaRed
                                         green:kPaletteColorMagentaGreen
                                          blue:kPaletteColorMagentaBlue
                                         alpha:kPaletteAlphaOpaque];
      UIColor *leafGreen = [UIColor colorWithRed:kPaletteColorLeafGreenRed
                                           green:kPaletteColorLeafGreenGreen
                                            blue:kPaletteChannelZero
                                           alpha:kPaletteAlphaOpaque];
      UIColor *steelBlue = [UIColor colorWithRed:kPaletteColorSteelBlueRed
                                           green:kPaletteColorSteelBlueGreen
                                            blue:kPaletteColorSteelBlueBlue
                                           alpha:kPaletteAlphaOpaque];
      palette = @[
          // The modal-dimming cover: 50%-translucent black. @ghidraAddress DAT_1003cff88
          [UIColor colorWithRed:kPaletteChannelZero
                          green:kPaletteChannelZero
                           blue:kPaletteChannelZero
                          alpha:kPaletteDimmingCoverAlpha],
          [UIColor whiteColor], // @ghidraAddress DAT_1003cff90
          // Opaque black. @ghidraAddress DAT_1003cff98
          [UIColor colorWithRed:kPaletteChannelZero
                          green:kPaletteChannelZero
                           blue:kPaletteChannelZero
                          alpha:kPaletteAlphaOpaque],
          greenGrass,            // @ghidraAddress DAT_1003cffa0
          magenta,               // @ghidraAddress DAT_1003cffa8
          [UIColor purpleColor], // @ghidraAddress DAT_1003cffb0
          // Dark green. @ghidraAddress DAT_1003cffb8
          [UIColor colorWithRed:kPaletteColorDarkGreenRed
                          green:kPaletteColorDarkGreenGreen
                           blue:kPaletteChannelZero
                          alpha:kPaletteAlphaOpaque],
          leafGreen,  // @ghidraAddress DAT_1003cffc0
          greenGrass, // @ghidraAddress DAT_1003cffc8 (a duplicate of index 3)
          magenta,    // @ghidraAddress DAT_1003cffd0 (a duplicate of index 4)
          leafGreen,  // @ghidraAddress DAT_1003cffd8 (a duplicate of index 7)
          steelBlue,  // @ghidraAddress DAT_1003cffe0
          leafGreen,  // @ghidraAddress DAT_1003cffe8 (a duplicate of index 7)
          steelBlue,  // @ghidraAddress DAT_1003cfff0 (a duplicate of index 11)
          // Gold. @ghidraAddress DAT_1003cfff8
          [UIColor colorWithRed:kPaletteColorGoldRed
                          green:kPaletteColorGoldGreen
                           blue:kPaletteColorGoldBlue
                          alpha:kPaletteAlphaOpaque],
          steelBlue, // @ghidraAddress DAT_1003d0000 (a duplicate of index 11)
      ];
    });
    if (index >= palette.count) {
        return nil;
    }
    return palette[index];
}

@end
