/** @file
 * The phone-layout terms-of-use view controller. It is an @c RBBaseViewController subclass pushed
 * onto the navigation stack (from the store pack and note detail screens and from the music menu's
 * terms row on the phone build, where the pad build overlays @c RBTermView instead). It builds a
 * navigation-bar title label and a custom "back" left bar-button item, downloads the terms list for
 * the current region, lays one button per term into a scrolling list, and — when a term is tapped —
 * either opens its external URL or pushes an @c RBTermDetailPhoneViewController for the term body. A
 * loading spinner and an optional dimming overlay cover the content during network activity.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBTermPhoneViewController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base. The class adopts
 * @c UIAlertViewDelegate (its @c class_ro_t protocol list).
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

@class Downloader;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout terms-of-use view controller presented on the navigation stack, showing a
 * downloaded list of terms and, on selection, each term's body or external link.
 */
@interface RBTermPhoneViewController : RBBaseViewController <UIAlertViewDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the controller: allocate the term-body cache, select the agreement view type, and
 * build the navigation-bar title label and custom "back" left bar-button item.
 * @return The initialised controller, or @c nil.
 * @ghidraAddress 0x16f3a4
 */
- (nullable instancetype)init;

/**
 * @brief Save the last-read terms timestamp, build the content (dimming overlay, loading spinner,
 * terms list scroll view, and term-body container), and start the terms-list download.
 * @ghidraAddress 0x16f718
 */
- (void)viewDidLoad;

#pragma mark Configuration

/**
 * @brief Configure the controller for the store terms viewer (sets @c viewType to the store value).
 * @ghidraAddress 0x16f6d4
 */
- (void)setViewTypeStore;

#pragma mark Networking

/**
 * @brief If the terms list is already populated, reveal it; otherwise start the loading spinner and
 * download the terms list for the current region, parsing the JSON response into @c termsList.
 * @ghidraAddress 0x170020
 */
- (void)loadList;

#pragma mark Presentation

/**
 * @brief Reveal the terms list: hide the term body and lay a titled button per term into the terms
 * list scroll view, then fade the list in.
 * @ghidraAddress 0x170878
 */
- (void)showTermsList;

/**
 * @brief Handle a term-button tap: open the term's external URL if it has one, otherwise push the
 * term-detail controller for its body.
 * @param sender The tapped term button.
 * @ghidraAddress 0x1713dc
 */
- (void)selectTerm:(nullable id)sender;

#pragma mark Loading animation

/**
 * @brief Show the dimming overlay (when enabled) and start the loading spinner.
 * @ghidraAddress 0x1718f0
 */
- (void)startLoadAnimation;

/**
 * @brief Hide the dimming overlay (when enabled) and stop the loading spinner.
 * @ghidraAddress 0x1719f0
 */
- (void)endLoadAnimation;

#pragma mark Navigation

/**
 * @brief Handle the custom "back" bar-button tap: restore the navigation bar chrome for the current
 * view type (playing the cancel sound effect for the agreement type) and pop the controller.
 * @param sender The tapped bar-button item.
 * @ghidraAddress 0x171aa4
 */
- (void)pushBarBtnBack:(nullable id)sender;

/**
 * @brief Dismiss the controller without animation, restoring the navigation bar for the agreement
 * view type first.
 * @ghidraAddress 0x171c68
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
/** @brief The scroll view holding one button per term. */
@property(assign, nonatomic, nullable) UIScrollView *termsListView;
/** @brief The reusable pool of term buttons. */
@property(strong, nonatomic, nullable) NSMutableArray *buttons;
/** @brief The container view for a single term's body. */
@property(assign, nonatomic, nullable) UIView *termView;
/** @brief The list of term descriptors downloaded from the server. */
@property(strong, nonatomic, nullable) NSArray *termsList;
/** @brief The parsed per-term body cache, keyed by the term id string. */
@property(strong, nonatomic, nullable) NSMutableDictionary *terms;
/** @brief The in-flight terms list download. */
@property(strong, nonatomic, nullable) Downloader *downloader;
/** @brief The dimming overlay covering the content while loading. */
@property(assign, nonatomic, nullable) UIView *grayView;
/** @brief The loading spinner shown during network activity. */
@property(assign, nonatomic, nullable) UIActivityIndicatorView *indicatorView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
