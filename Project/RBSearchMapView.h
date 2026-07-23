/** @file
 * The embedded treasure-map view. It is a @c UIView subclass wrapping an @c MKMapView that
 * @c RBSearchView hosts inside the search popup; it tracks the user's location and reports
 * tracking-state changes to its delegate.
 *
 * This header declares only the surface that @c RBSearchView depends on; the class itself is not yet
 * fully reconstructed. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBSearchMapView, image base 0x100000000). @ghidraAddress values are offsets relative to the
 * image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Delegate protocol through which @c RBSearchMapView reports user-tracking changes.
 */
@protocol SearchMapViewDelegate <NSObject>

/**
 * @brief Called when the map's user-tracking state changes.
 * @param tracking Whether the map is now tracking the user's position.
 * @ghidraAddress 0xe6f94 (RBSearchView implementation)
 */
- (void)didChangeUserTracking:(BOOL)tracking;

@end

/**
 * @brief A map view that tracks the user's location for the search popup.
 */
@interface RBSearchMapView : UIView

/**
 * @brief Reset the map to its initial view.
 * @ghidraAddress 0xe496c
 */
- (void)initialView;

/**
 * @brief Toggle the map's user-tracking mode, prompting for location authorisation when required.
 * @ghidraAddress 0xe1430
 */
- (void)toggleTrackingMode;

/**
 * @brief Tear down the map when the search popup disappears.
 * @ghidraAddress 0xe4ba4
 */
- (void)viewDidDisappear;

/**
 * @brief The tracking-change delegate, held weakly.
 */
@property(weak, nonatomic, nullable) id<SearchMapViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
