/** @file
 * The application's main window. @c neWindow is a trivial @c UIWindow subclass that hosts the game
 * engine's render surface. It overrides the four touch-phase entry points with empty bodies so that
 * UIKit does not route touches through the normal responder chain: the engine's GL view reads input
 * directly, and the window itself must not forward or act on touches.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class neWindow, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The main window hosting the game engine's render surface.
 */
@interface neWindow : UIWindow

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
