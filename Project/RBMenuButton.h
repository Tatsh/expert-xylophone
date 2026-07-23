/** @file
 * A single image-based button on the music-menu footer: the settings, ranking, store, and the
 * three playlist-editing (add, delete, finish) buttons. Each wraps an inner @c UIButton whose
 * background and icon artwork are chosen by the button's type, and carries two overlay image views
 * that play a repeating flash effect to advertise unseen content.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMenuButton, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBMenuNewsTickerView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The kind of menu button, selecting its background and icon artwork.
 *
 * The raw value indexes the setup image-name table, so the order is significant.
 */
typedef NS_ENUM(NSInteger, RBMenuButtonType) {
    RBMenuButtonTypeSetting = 0,     /*!< The settings button. */
    RBMenuButtonTypeRank = 1,        /*!< The ranking button. */
    RBMenuButtonTypeStore = 2,       /*!< The store button. */
    RBMenuButtonTypePlaylistAdd = 3, /*!< The playlist add-song button. */
    RBMenuButtonTypePlaylistDel = 4, /*!< The playlist delete-song button. */
    RBMenuButtonTypePlaylistFin = 5, /*!< The playlist finish-editing button. */
};

/**
 * @brief An image-based music-menu footer button wrapping an inner @c UIButton with a flash-effect
 * overlay.
 */
@interface RBMenuButton : RBMenuNewsTickerView

/**
 * @brief Create the button for the given type and build its subviews.
 * @param type The button kind, selecting its background and icon artwork.
 * @return The initialised button, or @c nil.
 * @ghidraAddress 0x9d9fc
 */
- (nullable instancetype)initWithType:(RBMenuButtonType)type;

/**
 * @brief Build the inner button, its resizable background and icon images, and the flash-effect
 * overlay image views for the given type.
 * @param type The button kind, selecting its background and icon artwork.
 * @ghidraAddress 0x9dab4
 */
- (void)setupView:(RBMenuButtonType)type;

/**
 * @brief Show and start the repeating flash effect on the overlay image views.
 * @ghidraAddress 0x9e2b0
 */
- (void)setFlashEffect;

/**
 * @brief Hide and stop the flash effect on the overlay image views.
 * @ghidraAddress 0x9e3cc
 */
- (void)removeFlashEffect;

/**
 * @brief Enable or disable the inner button.
 * @param enabled Whether the inner button accepts touches.
 * @ghidraAddress 0x9e4e8
 */
- (void)setEnabled:(BOOL)enabled;

/**
 * @brief The inner button that renders the artwork and receives touches.
 */
@property(strong, nonatomic, nullable) UIButton *button;

/**
 * @brief The flash-effect background overlay, hidden until @c setFlashEffect is called.
 */
@property(strong, nonatomic, nullable) UIImageView *effectImageView;

/**
 * @brief The flash-effect icon overlay, centred over @c effectImageView and hidden until
 * @c setFlashEffect is called.
 */
@property(strong, nonatomic, nullable) UIImageView *effectTextImageView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
