/** @file
 * A collection-view cell that presents a single music entry in a grid. @c RBMusicGridLayout
 * registers this class as its decoration view.
 *
 * Speculative interface: only the class itself is declared here, which is all its current callers
 * need. Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicCell, image base
 * 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A grid cell presenting a single music entry.
 */
@interface RBMusicCell : UICollectionViewCell

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
