/** @file
 * The base music-menu popup view. It is a @c UIControl subclass that builds a themed, framed popup
 * (a title bar, a background panel, an optional gradation overlay, and a rounded content view)
 * sized for the current theme and font variant. The concrete popups — the credits, how-to-play,
 * customize, theme, search, ranking, information, and terms popups — subclass it, select a popup
 * type through @c setMusicMenuPopupViewType:, and lay their own content out inside @c contentView.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMusicMenuPopupView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBMenuView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The popup variant selected by @c setMusicMenuPopupViewType:, choosing the title-bar and
 * background artwork the base @c setupView lays out.
 */
typedef NS_ENUM(NSInteger, RBMusicMenuPopupViewType) {
    RBMusicMenuPopupViewTypeHowTo = 0,       /*!< How-to-play popup (the default variant). */
    RBMusicMenuPopupViewTypeCustomize = 1,   /*!< Customize popup. */
    RBMusicMenuPopupViewTypeTheme = 2,       /*!< Theme-selection popup. */
    RBMusicMenuPopupViewTypeCredits = 3,     /*!< Staff-credits popup. */
    RBMusicMenuPopupViewTypeSearch = 4,      /*!< Search popup. */
    RBMusicMenuPopupViewTypeRanking = 5,     /*!< Ranking popup. */
    RBMusicMenuPopupViewTypeTutorial = 6,    /*!< Tutorial popup. */
    RBMusicMenuPopupViewTypeInformation = 7, /*!< Information popup. */
    RBMusicMenuPopupViewTypeApplilink = 8,   /*!< Applilink popup. */
    RBMusicMenuPopupViewTypeTerms = 9,       /*!< Terms-of-service popup. */
};

/**
 * @brief Base popup view presented over the music-menu screen, framed and themed for the current
 * theme and font variant.
 */
@interface RBMusicMenuPopupView : UIControl

/**
 * @brief Create the popup with the given frame.
 *
 * Calls through to @c super, selects the how-to-play (default) popup type, and marks the control as
 * exclusively touched.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x19ebfc
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the popup chrome: the base panel, the background artwork for the selected popup
 * type, the optional gradation overlay, the rounded content view, and the title bar.
 *
 * The geometry depends on the current theme and font variant; subclasses call through to @c super
 * and then add their own content to @c contentView.
 * @ghidraAddress 0x19ec8c
 */
- (void)setupView;

/**
 * @brief Fade the popup in, marking it animating for the duration of the transition.
 * @ghidraAddress 0x19ff1c
 */
- (void)showAnimation;

/**
 * @brief Fade the popup out with the cancel sound effect, then remove it and hide the owning music
 * menu.
 * @ghidraAddress 0x1a0090
 */
- (void)hideAnimation;

/**
 * @brief Touch-up handler that dismisses the popup.
 * @param sender The control that sent the action.
 * @ghidraAddress 0x1a027c
 */
- (void)tap:(nullable id)sender;

/**
 * @brief The popup variant, selecting the title-bar and background artwork.
 */
@property(assign, nonatomic) RBMusicMenuPopupViewType musicMenuPopupViewType;

/**
 * @brief The music menu that owns and presents this popup.
 */
@property(weak, nonatomic, nullable) RBMenuView *musicMenuView;

/**
 * @brief The background-panel image view behind the content.
 */
@property(assign, nonatomic, nullable) UIImageView *backgroundImageView;

/**
 * @brief The base panel that hosts the background, gradation, content, and title views.
 */
@property(strong, nonatomic, nullable) UIView *baseView;

/**
 * @brief The rounded, clipped content view into which subclasses lay their own content.
 */
@property(strong, nonatomic, nullable) UIView *contentView;

/**
 * @brief The optional gradation overlay drawn over the content for the customize and theme popups.
 */
@property(strong, nonatomic, nullable) UIImageView *gradationImageView;

/**
 * @brief The title-bar image view at the top of the base panel.
 */
@property(strong, nonatomic, nullable) UIImageView *titleImageView;

/**
 * @brief Whether a show or hide animation is currently running.
 */
@property(assign, nonatomic) BOOL animating;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
