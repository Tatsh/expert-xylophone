/**
 * @file
 * The erosion-mark score updater.
 *
 * This object drives the "please confirm your erosion-mark scores"
 * flow: it presents an editable basic/medium/hard score dialog (either a modern
 * @c UIAlertController with three text fields backed by wheel pickers, or a legacy
 * @c RBErosionMarkUpdaterScoreView plus @c UIAlertView fallback on pre-@c UIAlertController
 * systems), validates the entered values against the stored bounds, and writes the confirmed
 * scores back into the tune's @c ScoreData Core Data record.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBErosionMarkUpdater, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBViewController;
@class RBErosionMarkUpdaterAlertController;
@class RBErosionMarkUpdaterScoreView;
@class ScoreData;

NS_ASSUME_NONNULL_BEGIN

/**
 * Presents and applies the erosion-mark score correction dialog for the current tune.
 *
 * The object is used as a shared singleton driven by @c +updateCheckStart:. It acts as the
 * @c UITextFieldDelegate, @c UIPickerViewDataSource, @c UIPickerViewDelegate, and (on the legacy
 * path) @c UIAlertViewDelegate for the dialog it builds.
 */
@interface RBErosionMarkUpdater :
    NSObject <UITextFieldDelegate,
              UIPickerViewDataSource,
              UIPickerViewDelegate,
              UIAlertViewDelegate>

#pragma mark Entry point

/**
 * Class entry point: if the erosion mark still needs updating, build the shared updater,
 * bind it to a view controller, and open the score dialog.
 * @param viewController The view controller that hosts the dialog.
 * @ghidraAddress 0x142b4c
 */
+ (void)updateCheckStart:(nullable RBViewController *)viewController;

#pragma mark Setup

/**
 * Seed the shared updater with the stored basic, medium, and hard base scores, then build
 * and show the score-editing dialog.
 * @param basic The stored basic-difficulty score.
 * @param medium The stored medium-difficulty score.
 * @param hard The stored hard-difficulty score.
 * @ghidraAddress 0x142d4c
 */
- (void)updateStartBasic:(NSInteger)basic Medium:(NSInteger)medium Hard:(NSInteger)hard;

/**
 * Build the input toolbar, the three digit pickers, and the set-score, cancel, and confirm
 * alerts.
 * @ghidraAddress 0x142e08
 */
- (void)setupView;

#pragma mark Dialog

/**
 * Build the score-editing dialog: a text field per difficulty whose stored value differs
 * from the recorded score, each backed by its digit picker.
 * @ghidraAddress 0x144ffc
 */
- (void)createAlertSetScore;

/**
 * Build the cancel-confirmation alert (retry or discard the correction).
 * @ghidraAddress 0x146d3c
 */
- (void)createAlertCancel;

/**
 * Build the apply-confirmation alert (go back or write the correction).
 * @ghidraAddress 0x147134
 */
- (void)createAlertConfirm;

/**
 * Present the score-editing dialog and open the first field's picker.
 * @ghidraAddress 0x1474e4
 */
- (void)showAlertSetScore;

/**
 * Re-present the score-editing dialog carrying a validation message.
 * @param message The validation message to display.
 * @ghidraAddress 0x147868
 */
- (void)reshowAlertSetScore:(nullable NSString *)message;

/**
 * Present the cancel-confirmation alert.
 * @ghidraAddress 0x147af4
 */
- (void)showAlertCancel;

/**
 * Validate the entered scores and, when valid, present the apply-confirmation alert;
 * otherwise re-present the editor with the validation message.
 * @ghidraAddress 0x147c5c
 */
- (void)showAlertConfirm;

#pragma mark Editing

/**
 * Reset the currently active field back to its recorded base score and re-seed its picker.
 * @ghidraAddress 0x143d8c
 */
- (void)reset;

/**
 * Give first-responder focus to the first present field so its picker opens.
 * @ghidraAddress 0x143b8c
 */
- (void)pickerOpen;

/**
 * Resign first responder from every field, closing the pickers.
 * @ghidraAddress 0x143cc8
 */
- (void)pickerClose;

/**
 * Read the digits currently selected in one difficulty's picker into a single score value.
 * @param difficulty The difficulty index (0 basic, 1 medium, 2 hard).
 * @return The composed score, or 0 for an unknown difficulty.
 * @ghidraAddress 0x1433ec
 */
- (NSInteger)getPickerViewScore:(int)difficulty;

/**
 * Select the picker rows for one difficulty that spell out a score value.
 * @param difficulty The difficulty index (0 basic, 1 medium, 2 hard).
 * @param score The score whose digits to select.
 * @ghidraAddress 0x14370c
 */
- (void)setPickerViewScore:(int)difficulty score:(NSInteger)score;

#pragma mark Persistence

/**
 * Whether the erosion mark still needs updating: not yet updated and at least one stored
 * score matches its recorded base value.
 * @return @c YES when an update is still required.
 * @ghidraAddress 0x14451c
 */
- (BOOL)needUpdateScore;

/**
 * Fetch the tune's score record from Core Data.
 * @return The erosion-mark tune's score record.
 * @ghidraAddress 0x144820
 */
- (nullable ScoreData *)getScore;

/**
 * Write the edited scores into the tune's score record, refresh its tamper hash, persist
 * the context, and mark the erosion mark as updated.
 * @return @c YES when the save left no error behind, @c NO otherwise. The only caller discards it.
 * @ghidraAddress 0x1448d8
 */
- (BOOL)updateScore;

/**
 * Validate the edited scores against the stored bounds.
 * @return @c nil when the edits are unchanged or in range, otherwise the message to display.
 * @ghidraAddress 0x144080
 */
- (nullable NSString *)scoreValidate;

/**
 * Apply the correction: write the scores, tear down the dialog, and release the shared
 * updater.
 * @ghidraAddress 0x144418
 */
- (void)updatePerform;

/**
 * Discard the correction: tear down the dialog, mark the erosion mark as updated, and
 * release the shared updater.
 * @ghidraAddress 0x14445c
 */
- (void)updateCancel;

/**
 * Detach delegates, drop the pickers, toolbar, and alerts, and clear the shared score
 * bounds.
 * @ghidraAddress 0x144d38
 */
- (void)remove;

#pragma mark Properties

/** The view controller that hosts the dialog. */
@property(assign, nonatomic, nullable) RBViewController *viewController;
/** The layout scale applied to the legacy dialog on non-iPad displays. */
@property(assign, nonatomic) double displayRate;
/** The modern score-editing alert controller (present on @c UIAlertController systems). */
@property(strong, nonatomic, nullable) RBErosionMarkUpdaterAlertController *alertSetScoreController;
/** The modern cancel-confirmation alert controller. */
@property(strong, nonatomic, nullable) RBErosionMarkUpdaterAlertController *alertCancelController;
/** The modern apply-confirmation alert controller. */
@property(strong, nonatomic, nullable) RBErosionMarkUpdaterAlertController *alertConfirmController;
/** The legacy custom score-editing dialog view. */
@property(strong, nonatomic, nullable) RBErosionMarkUpdaterScoreView *alertSetScoreView;
/** The legacy cancel-confirmation alert view. */
@property(strong, nonatomic, nullable) UIAlertView *alertCancelView;
/** The legacy apply-confirmation alert view. */
@property(strong, nonatomic, nullable) UIAlertView *alertConfirmView;
/** The toolbar shown above the keyboard as the pickers' input accessory. */
@property(strong, nonatomic, nullable) UIToolbar *toolbar;
/** The digit picker for the basic difficulty. */
@property(strong, nonatomic, nullable) UIPickerView *basicPickerView;
/** The digit picker for the medium difficulty. */
@property(strong, nonatomic, nullable) UIPickerView *mediumPickerView;
/** The digit picker for the hard difficulty. */
@property(strong, nonatomic, nullable) UIPickerView *hardPickerView;
/** The basic-difficulty score field. */
@property(assign, nonatomic, nullable) UITextField *basicField;
/** The medium-difficulty score field. */
@property(assign, nonatomic, nullable) UITextField *mediumField;
/** The hard-difficulty score field. */
@property(assign, nonatomic, nullable) UITextField *hardField;
/** The difficulty index of the field currently being edited, or -1 for none. */
@property(assign, nonatomic) NSInteger activeFieldIndex;
/** The recorded basic-difficulty score to correct against. */
@property(assign, nonatomic) NSInteger baseBasicScore;
/** The edited basic-difficulty score. */
@property(assign, nonatomic) NSInteger editBasicScore;
/** The recorded medium-difficulty score to correct against. */
@property(assign, nonatomic) NSInteger baseMediumScore;
/** The edited medium-difficulty score. */
@property(assign, nonatomic) NSInteger editMediumScore;
/** The recorded hard-difficulty score to correct against. */
@property(assign, nonatomic) NSInteger baseHardScore;
/** The edited hard-difficulty score. */
@property(assign, nonatomic) NSInteger editHardScore;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
