/** @file
 * The "pastel" tutorial-popup manager singleton. It owns a single small piece of state: a four-slot
 * show-list of flags that records which stages of the pastel tutorial sequence have already been
 * displayed, together with the current pastel @c type. Callers ask @c -tryShow: whether a given
 * sequential stage may be shown; the manager gates each stage on all earlier stages having been
 * shown, marks the stage, and resets the later stages so the sequence always advances in order.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBPastelManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pastel tutorial-popup manager singleton.
 */
@interface RBPastelManager : NSObject

#pragma mark Singleton

/**
 * @brief The shared pastel-manager instance, created on first use.
 * @ghidraAddress 0x20a30
 * @return The shared @c RBPastelManager.
 */
+ (instancetype)getInstance;

#pragma mark Show sequence

/**
 * @brief Reset the show-list so every stage is once again marked as not yet shown.
 * @ghidraAddress 0x20afc
 */
- (void)allReset;
/**
 * @brief Attempt to show the pastel stage at @p tryShow, gating it on the earlier stages.
 *
 * When @p tryShow is zero the leading stage is forced shown and the remaining stages are cleared.
 * Otherwise the request is refused (returns @c NO) if any earlier stage @c [0, tryShow) has not yet
 * been shown; when the earlier stages are all shown, stage @p tryShow is marked shown, the trailing
 * stages are cleared, and the request is granted.
 * @ghidraAddress 0x20b0c
 * @param tryShow The zero-based stage index to attempt to show.
 * @return @c YES when the stage may be shown, @c NO when an earlier stage is still outstanding.
 */
- (BOOL)tryShow:(unsigned int)tryShow;

#pragma mark Properties

/**
 * @brief The current pastel type.
 * @ghidraAddress 0x20ba0 (getter)
 * @ghidraAddress 0x20bb0 (setter)
 */
@property(nonatomic, assign) unsigned int type;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
