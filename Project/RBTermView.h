/** @file
 * The terms-of-service overlay popup. It is an @c RBMusicMenuPopupView subclass (popup type
 * @c RBMusicMenuPopupViewTypeTerms) presented over the music menu on the pad build. It downloads
 * the terms list from the server, lays a button per term into a scrolling list inside the popup's
 * content view, and — when a term is tapped — either opens its external URL or fetches and shows
 * the term body in a @c UITextView. A loading spinner and an optional dimming overlay cover the
 * content during network activity.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBTermView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base. The class adopts
 * @c UIAlertViewDelegate (its @c class_ro_t protocol list); it does @b not own or adopt
 * @c RBTermAgreeViewDelegate — that protocol belongs to the separate @c RBTermAgreeView class.
 */

#import <UIKit/UIKit.h>

#import "RBMusicMenuPopupView.h"

@class Downloader;
@class RBSettingView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The terms-of-service overlay popup presented over the music menu, showing a downloaded
 * list of terms and, on selection, each term's body or external link.
 */
@interface RBTermView : RBMusicMenuPopupView <UIAlertViewDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the terms popup, select the terms popup type, build its content, and start the
 * terms-list download.
 *
 * Calls through to @c super, selects @c RBMusicMenuPopupViewTypeTerms, clears the terms list,
 * allocates the term-body cache dictionary, builds the view, and marks it as the first request.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x110064
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the terms popup content: the gradation overlay, title label, dimming overlay,
 * loading spinner, the scrolling terms list, the terms body view and text view, and the back
 * button; then start the terms-list download.
 * @ghidraAddress 0x1101ac
 */
- (void)setupView;

/**
 * @brief Fade the popup out. For the agreement view type this defers to the base dismiss; for the
 * store view type it fades the popup and tears down the owning music-menu overlay.
 * @ghidraAddress 0x1116c4
 */
- (void)hideAnimation;

#pragma mark Configuration

/**
 * @brief Configure the popup for the store terms viewer (sets @c viewType to the store value).
 * @ghidraAddress 0x11019c
 */
- (void)setViewTypeStore;

#pragma mark Networking

/**
 * @brief Start the loading spinner and download the terms list for the current region, parsing the
 * JSON response into @c termsList.
 * @ghidraAddress 0x1118dc
 */
- (void)loadList;

/**
 * @brief Download the body of a single term identified by @p termID, caching the parsed response
 * in @c terms keyed by the term id string.
 * @param termID The term identifier whose detail should be fetched.
 * @ghidraAddress 0x11307c
 */
- (void)loadDetail:(nullable id)termID;

#pragma mark Presentation

/**
 * @brief Reveal the terms list: hide the term body, hide the back button, and lay a titled button
 * per term into the terms list scroll view, then fade the list in.
 * @ghidraAddress 0x112084
 */
- (void)showTermsList;

/**
 * @brief Show the body for the term identified by @p termID: set the title, load the cached body
 * text into the text view, and fade the body view in.
 * @param termID The term identifier whose body should be shown.
 * @ghidraAddress 0x113948
 */
- (void)showTermView:(nullable id)termID;

/**
 * @brief Handle a term-button tap: open the term's external URL if it has one, otherwise show its
 * cached body or fetch it.
 * @param sender The tapped term button.
 * @ghidraAddress 0x112c2c
 */
- (void)selectTerm:(nullable id)sender;

/**
 * @brief Set the popup title label to @p termsTitle, sized and centred over the title bar.
 * @param termsTitle The title text to display.
 * @ghidraAddress 0x114420
 */
- (void)setTermsTitle:(nullable id)termsTitle;

#pragma mark Loading animation

/**
 * @brief Show the dimming overlay (when enabled) and start the loading spinner.
 * @ghidraAddress 0x1142b8
 */
- (void)startLoadAnimation;

/**
 * @brief Hide the dimming overlay (when enabled) and stop the loading spinner.
 * @ghidraAddress 0x11436c
 */
- (void)endLoadAnimation;

#pragma mark Properties

/** @brief Whether this is the first terms request, gating the alert-driven dismiss. */
@property(assign, nonatomic) BOOL isFirstRequest;
/** @brief Whether a show or hide animation is currently running. */
@property(assign, nonatomic) BOOL isAnimating;
/** @brief The back button that returns from a term body to the terms list. */
@property(strong, nonatomic, nullable) UIButton *backButton;
/** @brief The popup title label. */
@property(strong, nonatomic, nullable) UILabel *titleView;
/** @brief The scroll view holding one button per term. */
@property(assign, nonatomic, nullable) UIScrollView *termsListView;
/** @brief The container view for a single term's body text. */
@property(assign, nonatomic, nullable) UIView *termView;
/** @brief The text view rendering a single term's body. */
@property(assign, nonatomic, nullable) UITextView *termTextView;
/** @brief The parsed per-term body cache, keyed by the term id string. */
@property(strong, nonatomic, nullable) NSMutableDictionary *terms;
/** @brief The in-flight terms list or detail download. */
@property(strong, nonatomic, nullable) Downloader *downloader;
/** @brief Whether the dimming overlay is shown while loading. */
@property(assign, nonatomic) BOOL isUseGrayView;
/** @brief The dimming overlay covering the content while loading. */
@property(assign, nonatomic, nullable) UIView *grayView;
/** @brief The loading spinner shown during network activity. */
@property(assign, nonatomic, nullable) UIActivityIndicatorView *indicatorView;
/** @brief The view type: the agreement overlay (0) or the store terms viewer (1). */
@property(assign, nonatomic) int viewType;
/** @brief The list of term descriptors downloaded from the server. */
@property(strong, nonatomic, nullable) NSArray *termsList;
/** @brief The settings view that owns and presents this popup, held weakly. */
@property(weak, nonatomic, nullable) RBSettingView *settingView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
