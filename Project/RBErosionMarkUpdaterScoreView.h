#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A hand-rolled modal dialog used by @c RBErosionMarkUpdater on systems that predate
 * @c UIAlertController. It fades a rounded, shadowed panel over a translucent black backdrop; the
 * panel carries a title label, a message label, and two buttons whose targets and actions are
 * supplied by the delegate.
 *
 * @ghidraAddress 0x347115
 */
@interface RBErosionMarkUpdaterScoreView : UIView

/**
 * The layout scale applied to every child frame. The initialiser seeds it with 1.0 on iPad and the
 * shared translucent-alpha metric otherwise.
 *
 * @ghidraAddress 0x142920
 */
@property(nonatomic) double displayRate;

/**
 * The object that receives the button actions. The buttons target it with @c showAlertCancel and
 * @c showAlertConfirm, so in practice it is the owning @c RBErosionMarkUpdater.
 *
 * @ghidraAddress 0x142940
 */
@property(weak, nonatomic, nullable) id delegate;

/**
 * The rounded panel that holds the title label, the message label, and the buttons. It is the view
 * whose alpha the show and hide animations drive.
 *
 * @ghidraAddress 0x142960
 */
@property(assign, nonatomic, nullable) UIView *dialogView;

/**
 * The centred, bold title label at the top of the panel.
 *
 * @ghidraAddress 0x142980
 */
@property(assign, nonatomic, nullable) UILabel *titleLabel;

/**
 * The centred, red message label below the title.
 *
 * @ghidraAddress 0x1429a0
 */
@property(strong, nonatomic, nullable) UILabel *messageLabel;

/**
 * The left (cancel) button.
 *
 * @ghidraAddress 0x1429c0
 */
@property(assign, nonatomic, nullable) UIButton *leftButton;

/**
 * The right (confirm) button.
 *
 * @ghidraAddress 0x1429e0
 */
@property(assign, nonatomic, nullable) UIButton *rightButton;

/**
 * Builds the dialog hierarchy within @p frame and wires the buttons to @p delegate.
 *
 * @param frame The frame the dialog fills, normally the presenting view's bounds.
 * @param delegate The object messaged with the button actions.
 * @return The initialised dialog, or @c nil if @c super failed.
 * @ghidraAddress 0x1417e0
 */
- (nullable instancetype)initWithFrame:(CGRect)frame delegate:(nullable id)delegate;

/**
 * Fades the dialog panel in, then runs @p completion.
 *
 * @param completion An optional block invoked when the fade finishes.
 * @ghidraAddress 0x1424cc
 */
- (void)showAnimation:(nullable void (^)(void))completion;

/**
 * Fades the dialog panel out, then runs @p completion.
 *
 * @param completion An optional block invoked when the fade finishes.
 * @ghidraAddress 0x1426c0
 */
- (void)hideAnimation:(nullable void (^)(void))completion;

/**
 * Detaches the dialog: clears the delegate and removes the view from its superview.
 *
 * @ghidraAddress 0x1428b4
 */
- (void)remove;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
