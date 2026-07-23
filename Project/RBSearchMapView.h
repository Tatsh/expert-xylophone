/** @file
 * The embedded treasure-map view. It is a @c UIView subclass wrapping an @c MKMapView that
 * @c RBSearchView hosts inside the search popup. It owns its own @c CLLocationManager, tracks the
 * user's location, downloads a spot list and campaign master from the game server, drops annotation
 * pins for nearby spots, and opens a tapped spot in the system Maps app. Tracking-state changes are
 * reported to a @c SearchMapViewDelegate.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBSearchMapView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "ImageDownloader.h"

@class RBMapAnnotation;

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
 * @brief A map view that tracks the user's location and shows searchable spots for the search
 * popup.
 */
@interface RBSearchMapView : UIView <MKMapViewDelegate,
                                     CLLocationManagerDelegate,
                                     DownloaderDelegate,
                                     ImageDownloaderDelegate,
                                     UIAlertViewDelegate>

/**
 * @brief Whether location services are enabled and the app is authorised to use them.
 * @ghidraAddress 0xdf6c4
 */
+ (BOOL)currentLocationEnabled;

/**
 * @brief The diagonal magnitude of a coordinate region's latitude span (used as a search radius).
 *
 * The binary derives this from the latitude delta alone: it is @c sqrt(2)·|latitudeDelta| and does
 * not read the longitude delta.
 * @param region The coordinate region to measure.
 * @ghidraAddress 0xdf634
 */
+ (double)rangeOfRegion:(MKCoordinateRegion)region;

/**
 * @brief Convert a coordinate region into an axis-aligned map rectangle, widened by a fixed factor.
 * @param region The coordinate region to convert.
 * @ghidraAddress 0xdf644
 */
+ (MKMapRect)mapRectForCoordinateRegion:(MKCoordinateRegion)region;

/**
 * @brief Build the map, indicator, message label, information overlay, and error label.
 * @ghidraAddress 0xdf768
 */
- (void)setupView;

/**
 * @brief Reset the map to its initial region (Tokyo Station) and fetch the campaign master.
 * @ghidraAddress 0xe496c
 */
- (void)initialView;

/**
 * @brief Fetch the campaign master over HTTP, replacing any in-flight request.
 * @ghidraAddress 0xe4a18
 */
- (void)getMaster;

/**
 * @brief Toggle the map's user-tracking mode, prompting for location authorisation when required.
 * @ghidraAddress 0xe1430
 */
- (void)toggleTrackingMode;

/**
 * @brief Centre the map on the user's current position when location is available.
 * @ghidraAddress 0xe0f4c
 */
- (void)pushCurrent;

/**
 * @brief Request the list of nearby spots for the given map region.
 * @param region The region whose spots are requested.
 * @ghidraAddress 0xe0cd4
 */
- (void)requestList:(MKCoordinateRegion)region;

/**
 * @brief Display an error message in the error label, fading it in when it was hidden.
 * @param message The error text to show.
 * @ghidraAddress 0xe0aa4
 */
- (void)showError:(nullable NSString *)message;

/**
 * @brief Increment the pending-request counter, starting the activity indicator on the first one.
 * @ghidraAddress 0xe503c
 */
- (void)addIndicator;

/**
 * @brief Decrement the pending-request counter, stopping the activity indicator on the last one.
 * @ghidraAddress 0xe50b4
 */
- (void)subIndicator;

/**
 * @brief Hide the spot-information overlay and request the spot list for the current region.
 * @param sender The control that sent the action.
 * @ghidraAddress 0xe4848
 */
- (void)selectHideInfo:(nullable id)sender;

/**
 * @brief Tear down the map when the search popup disappears.
 * @ghidraAddress 0xe4ba4
 */
- (void)viewDidDisappear;

/**
 * @brief The wrapped map view.
 * @ghidraAddress 0xe5160 (getter)
 * @ghidraAddress 0xe5170 (setter)
 */
@property(strong, nonatomic, nullable) MKMapView *mapView;

/**
 * @brief The spinner shown while requests are in flight.
 * @ghidraAddress 0xe51a8 (getter)
 * @ghidraAddress 0xe51b8 (setter)
 */
@property(strong, nonatomic, nullable) UIActivityIndicatorView *indicator;

/**
 * @brief The loading-status message label centred over the map.
 * @ghidraAddress 0xe51f0 (getter)
 * @ghidraAddress 0xe5200 (setter)
 */
@property(strong, nonatomic, nullable) UILabel *messageLabel;

/**
 * @brief The error label shown along the bottom of the map.
 * @ghidraAddress 0xe5238 (getter)
 * @ghidraAddress 0xe5248 (setter)
 */
@property(strong, nonatomic, nullable) UILabel *errorLabel;

/**
 * @brief The dimmed backdrop behind the spot-information overlay.
 * @ghidraAddress 0xe5280 (getter)
 * @ghidraAddress 0xe5290 (setter)
 */
@property(strong, nonatomic, nullable) UIView *infomationBaseView;

/**
 * @brief The spot-information overlay panel.
 * @ghidraAddress 0xe52c8 (getter)
 * @ghidraAddress 0xe52d8 (setter)
 */
@property(strong, nonatomic, nullable) UIView *infomationView;

/**
 * @brief The image shown inside the spot-information overlay.
 * @ghidraAddress 0xe5310 (getter)
 * @ghidraAddress 0xe5320 (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *infomationImage;

/**
 * @brief The location manager owned by the view, used to request authorisation.
 * @ghidraAddress 0xe5358 (getter)
 * @ghidraAddress 0xe5368 (setter)
 */
@property(strong, nonatomic, nullable) CLLocationManager *locationManager;

/**
 * @brief The in-flight campaign-master download.
 * @ghidraAddress 0xe53a0 (getter)
 * @ghidraAddress 0xe53b0 (setter)
 */
@property(strong, nonatomic, nullable) Downloader *masterDownloader;

/**
 * @brief The in-flight spot-list download.
 * @ghidraAddress 0xe53e8 (getter)
 * @ghidraAddress 0xe53f8 (setter)
 */
@property(strong, nonatomic, nullable) Downloader *listDownloader;

/**
 * @brief The in-flight campaign-image download.
 * @ghidraAddress 0xe5430 (getter)
 * @ghidraAddress 0xe5440 (setter)
 */
@property(strong, nonatomic, nullable) ImageDownloader *imageDownloader;

/**
 * @brief Cached annotations keyed by spot identifier, so a spot is not dropped twice.
 * @ghidraAddress 0xe5478 (getter)
 * @ghidraAddress 0xe5488 (setter)
 */
@property(strong, nonatomic, nullable) NSMutableDictionary *dictSpot;

/**
 * @brief The Maps-app URL for the currently selected spot.
 * @ghidraAddress 0xe54c0 (getter)
 * @ghidraAddress 0xe54d0 (setter)
 */
@property(strong, nonatomic, nullable) NSString *mapURL;

/**
 * @brief The parsed campaign-master information dictionary.
 * @ghidraAddress 0xe5508 (getter)
 * @ghidraAddress 0xe5518 (setter)
 */
@property(strong, nonatomic, nullable) NSMutableDictionary *info;

/**
 * @brief The parsed campaign model list.
 * @ghidraAddress 0xe5550 (getter)
 * @ghidraAddress 0xe5560 (setter)
 */
@property(strong, nonatomic, nullable) NSMutableArray *models;

/**
 * @brief A map from spot model name to its index in @c models.
 * @ghidraAddress 0xe5598 (getter)
 * @ghidraAddress 0xe55a8 (setter)
 */
@property(strong, nonatomic, nullable) NSMutableDictionary *modelNameForArrayIndex;

/**
 * @brief The tracking-change delegate, held weakly.
 * @ghidraAddress 0xe512c (getter)
 * @ghidraAddress 0xe514c (setter)
 */
@property(weak, nonatomic, nullable) id<SearchMapViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
