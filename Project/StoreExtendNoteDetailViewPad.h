/** @file
 * The pad note-detail overlay view, shown over a dimming cover to present a single extend note's
 * detail, sample, and purchase controls.
 *
 * Minimal interface; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteDetailViewPad,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StoreExtendNoteInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pad note-detail overlay view.
 */
@interface StoreExtendNoteDetailViewPad : UIView

/**
 * @brief The delegate that receives detail-view actions.
 */
@property(nonatomic, weak, nullable) id delegate;

/**
 * @brief Loads the given extend-note record into the detail view.
 * @param info The extend-note record to display.
 */
- (void)setInfo:(nullable StoreExtendNoteInfo *)info;
/**
 * @brief Reveals the loaded note's detail.
 */
- (void)showNoteInfo;
/**
 * @brief Clears the currently displayed note.
 */
- (void)removeNoteInfo;
/**
 * @brief Cancels any in-flight detail loading.
 */
- (void)cancelLoading;
/**
 * @brief Stops the sample-BGM playback.
 */
- (void)stopSample;
/**
 * @brief Sets the action button to its "installing" state.
 */
- (void)setButtonTextInstalling;
/**
 * @brief Sets the action button to its "installed" state.
 */
- (void)setButtonTextInstalled;
/**
 * @brief Refreshes the action button text from the current note's ownership state.
 */
- (void)selfCheckButtonText;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
