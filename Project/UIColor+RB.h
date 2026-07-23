/** @file
 * @c UIColor palette shared across the whole UI of REFLEC BEAT plus. The binary builds a fixed
 * table of cached @c UIColor objects once at start-up (see @c InitializeUIColorPalette below) into
 * a run of global slots, and screens read those slots directly. This category recovers that table:
 * @c rbPaletteColorAtIndex: returns a palette entry, and @c RBPaletteIndex names each slot. The
 * first entry, @c RBPaletteIndexDimmingCover, is the 50%-translucent black cover that dims a
 * screen behind a modal; it is read broadly (the music view, popups, the store dialog, the news
 * HUD, and so on).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c UIColor(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 *
 * The binary exposes no named accessor for these colours: every screen reads the raw global slot
 * (originally @c DAT_1003cff88 through @c DAT_1003d0000, eight bytes apart). The palette is
 * modelled here as an ordered, once-built table behind @c rbPaletteColorAtIndex:, mirroring the
 * binary's own one-shot @c InitializeUIColorPalette (@ghidraAddress 0x5517c), which fills every
 * slot inside a single autorelease pool.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Named index of each entry in the shared @c UIColor palette.
 *
 * The order matches the global slots filled by @c InitializeUIColorPalette (@ghidraAddress
 * 0x5517c), from @c DAT_1003cff88 upward in eight-byte steps. Several colours recur across slots
 * because the binary stores the same colour in several places; the duplicate slots keep a
 * @c "…2" / @c "…3" suffix so the index count and ordering stay faithful to the binary.
 */
typedef NS_ENUM(NSUInteger, RBPaletteIndex) {
    RBPaletteIndexDimmingCover = 0, /*!< 50%-translucent black (0, 0, 0, 0.5). */
    RBPaletteIndexWhite = 1,        /*!< @c [UIColor whiteColor]. */
    RBPaletteIndexOpaqueBlack = 2,  /*!< Opaque black (0, 0, 0, 1.0). */
    RBPaletteIndexGreenGrass = 3,   /*!< Green grass (63, 167, 0, 1.0). */
    RBPaletteIndexMagenta = 4,      /*!< Magenta (254, 33, 248, 1.0). */
    RBPaletteIndexPurple = 5,       /*!< @c [UIColor purpleColor]. */
    RBPaletteIndexDarkGreen = 6,    /*!< Dark green (2, 111, 0, 1.0). */
    RBPaletteIndexLeafGreen = 7,    /*!< Leaf green (26, 151, 0, 1.0). */
    RBPaletteIndexGreenGrass2 = 8,  /*!< Green grass again; a duplicate of index 3. */
    RBPaletteIndexMagenta2 = 9,     /*!< Magenta again; a duplicate of index 4. */
    RBPaletteIndexLeafGreen2 = 10,  /*!< Leaf green again; a duplicate of index 7. */
    RBPaletteIndexSteelBlue = 11,   /*!< Steel blue (133, 173, 217, 1.0). */
    RBPaletteIndexLeafGreen3 = 12,  /*!< Leaf green again; a duplicate of index 7. */
    RBPaletteIndexSteelBlue2 = 13,  /*!< Steel blue again; a duplicate of index 11. */
    RBPaletteIndexGold = 14,        /*!< Gold (229, 183, 49, 1.0). */
    RBPaletteIndexSteelBlue3 = 15,  /*!< Steel blue again; a duplicate of index 11. */
};

/**
 * @brief Shared palette-colour accessor layered on @c UIColor.
 */
@interface UIColor (RB)

/**
 * @brief Return an entry of the shared UIColor palette.
 *
 * The palette is built once, on first access, exactly as @c InitializeUIColorPalette
 * (@ghidraAddress 0x5517c) fills the global slots, then reused for the lifetime of the process.
 * @param index The palette entry to return; see @c RBPaletteIndex.
 * @return The cached palette colour, or @c nil when @p index is out of range.
 * @ghidraAddress 0x5517c
 */
+ (nullable UIColor *)rbPaletteColorAtIndex:(RBPaletteIndex)index;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
