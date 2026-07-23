/** @file
 * The phone-layout terms-of-use detail view controller. It is an @c RBBaseViewController subclass
 * pushed onto the navigation stack by @c RBTermPhoneViewController when a term with a body (rather
 * than an external link) is selected. It builds a navigation-bar title label and a custom "back"
 * left bar-button item, downloads the selected term's body for the current region, and shows it in a
 * non-selectable text view. A loading spinner and an optional dimming overlay cover the content
 * during network activity.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBTermDetailPhoneViewController,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base. The class
 * adopts @c UIAlertViewDelegate (its @c class_ro_t protocol list).
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

@class Downloader;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout terms-of-use detail view controller presented on the navigation stack,
 * showing a single downloaded term's body.
 */
@interface RBTermDetailPhoneViewController : RBBaseViewController <UIAlertViewDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the detail controller: store the term identifier, allocate the term-body cache,
 * select the agreement view type, and build the navigation-bar title label and custom "back" left
 * bar-button item.
 * @param termID The identifier of the term whose body is shown.
 * @param title The title shown in the navigation bar.
 * @return The initialised controller, or @c nil.
 * @ghidraAddress 0x48508
 */
- (nullable instancetype)initWithID:(nullable NSString *)termID title:(nullable NSString *)title;

/**
 * @brief Save the last-read terms timestamp, and build the content (dimming overlay, loading
 * spinner, term-body container, and the body text view).
 * @ghidraAddress 0x488d0
 */
- (void)viewDidLoad;

#pragma mark Configuration

/**
 * @brief Configure the controller for the store terms viewer (sets @c viewType to the store value).
 * @ghidraAddress 0x4888c
 */
- (void)setViewTypeStore;

#pragma mark Networking

/**
 * @brief Start the loading spinner and download the selected term's body for the current region,
 * caching the parsed JSON response and presenting it.
 * @ghidraAddress 0x492e8
 */
- (void)loadDetail;

#pragma mark Presentation

/**
 * @brief Show the fetched term body: set the body text and font from the cached response, then fade
 * the body container in.
 * @ghidraAddress 0x49ac4
 */
- (void)showTermView;

#pragma mark Loading animation

/**
 * @brief Show the dimming overlay (when enabled) and start the loading spinner.
 * @ghidraAddress 0x49f7c
 */
- (void)startLoadAnimation;

/**
 * @brief Hide the dimming overlay (when enabled) and stop the loading spinner.
 * @ghidraAddress 0x4a07c
 */
- (void)endLoadAnimation;

#pragma mark Navigation

/**
 * @brief Handle the custom "back" bar-button tap: hide the navigation bar for the agreement view
 * type and pop the controller.
 * @param sender The tapped bar-button item.
 * @ghidraAddress 0x4a130
 */
- (void)pushBarBtnBack:(nullable id)sender;

/**
 * @brief Dismiss the controller without animation, hiding the navigation bar for the agreement view
 * type first.
 * @ghidraAddress 0x4a200
 */
- (void)forceClose;

#pragma mark Properties

/** @brief Whether this is the first terms request, gating the alert-driven dismiss. */
@property(assign, nonatomic) BOOL isFirstRequest;
/** @brief Whether a show or hide animation is currently running. */
@property(assign, nonatomic) BOOL isAnimating;
/** @brief Whether the dimming overlay is shown while loading. */
@property(assign, nonatomic) BOOL isUseGrayView;
/** @brief The view type: the agreement overlay (0) or the store terms viewer (1). */
@property(assign, nonatomic) int viewType;
/** @brief The reusable pool of term buttons. */
@property(strong, nonatomic, nullable) NSMutableArray *buttons;
/** @brief The identifier of the term whose body is shown. */
@property(strong, nonatomic, nullable) NSString *ID;
/** @brief The container view for the term's body. */
@property(assign, nonatomic, nullable) UIView *termView;
/** @brief The text view rendering the term's body. */
@property(assign, nonatomic, nullable) UITextView *termTextView;
/** @brief The parsed per-term body cache, keyed by the term id string. */
@property(strong, nonatomic, nullable) NSMutableDictionary *terms;
/** @brief The in-flight term-body download. */
@property(strong, nonatomic, nullable) Downloader *downloader;
/** @brief The dimming overlay covering the content while loading. */
@property(assign, nonatomic, nullable) UIView *grayView;
/** @brief The loading spinner shown during network activity. */
@property(assign, nonatomic, nullable) UIActivityIndicatorView *indicatorView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
