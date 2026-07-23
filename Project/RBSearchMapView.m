#import "RBSearchMapView.h"

#import "NSString+RB.h"
#import "NetworkUtil.h"
#import "RBMapAnnotation.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// Shared engine layout metrics and cached localised strings, referenced by their Ghidra names.
extern const double g_dLayoutMetricThirtyTwo;                     // @ghidraAddress 0x2ee9b0 (32.0)
extern const double g_dLayoutMetricSixty;                         // @ghidraAddress 0x2ee948 (60.0)
extern const double g_dNameImageMaxWidth;                         // @ghidraAddress 0x2fcfd8
extern const double g_dSliderRowHeightWide;                       // @ghidraAddress 0x2ee950
extern const double g_dRBWebViewGrayViewWhite;                    // @ghidraAddress 0x2ec708
extern const double g_dAudioManagerResumeFadeInTime;              // @ghidraAddress 0x2ec718 (0.3)
extern const double g_dMascotMessageMaxWidthPad;                  // @ghidraAddress 0x2ee930 (300.0)
extern const unsigned int g_dwAutoresizingMaskFlexibleAll;        // @ghidraAddress 0x310450
extern const unsigned int g_dwRBWebViewIndicatorAutoresizingMask; // @ghidraAddress 0x310460

// Asset names in the search image directory.
static NSString *const kSearchCancelImageName = @"06_search/sear_cancel";
static NSString *const kSearchDefaultPinImageName = @"06_search/sear_icon_d";

// Map annotation reuse and spot-detail Maps-app URL formats.
static NSString *const kSpotSubtitleFormat = @"営業時間: %@";
static NSString *const kMapsAppURLFormat = @"http://map.google.com/maps?q=%0.6f,%0.6f+(%@)";

// Spot-list request body format: the map centre and search range, all to six decimals.
static NSString *const kSpotListRequestFormat = @"lat=%.6f&long=%.6f&range=%.6f";

// JSON keys in the spot-list and campaign-master responses.
static NSString *const kJSONKeyGameCenterList = @"GameCenterList";
static NSString *const kJSONKeyID = @"ID";
static NSString *const kJSONKeyLat = @"Lat";
static NSString *const kJSONKeyLong = @"Long";
static NSString *const kJSONKeyName = @"Name";
static NSString *const kJSONKeyOpen = @"Open";
static NSString *const kJSONKeyModel = @"Model";
static NSString *const kJSONKeyVersion = @"Version";
static NSString *const kJSONKeyInfo = @"Info";
static NSString *const kJSONKeyMark = @"Mark";
static NSString *const kJSONKeyOrder = @"Order";
static NSString *const kJSONKeyImage = @"Image";
static NSString *const kJSONKeyImageObject = @"IMAGE_OBJECT";

// The bundle-version key checked against the campaign master's required version.
static NSString *const kBundleVersionKey = @"CFBundleVersion";

// Key path observed on the map's user location to learn when the first fix arrives.
static NSString *const kUserLocationKeyPath = @"location";

// Initial map region: Tokyo Station, framing roughly a one-kilometre box.
static const CLLocationDegrees kInitialCenterLatitude = 35.681382;
static const CLLocationDegrees kInitialCenterLongitude = 139.766084;
static const CLLocationDegrees kInitialSpanLatitudeDelta = 0.01004;
static const CLLocationDegrees kInitialSpanLongitudeDelta = 0.01159;

// The map rectangle for a region is widened by 60% of its span on each axis.
static const double kMapRectSpanScale = 0.6;

// The activity indicator, 32 points square, sits centred on the map with a rounded, dimmed
// backdrop. Its edge length reuses the shared 32-point layout metric.
static const CGFloat kIndicatorHalfInset = 16.0;
static const CGFloat kIndicatorBackdropWhite = 0.0;
static const CGFloat kIndicatorBackdropAlpha = 0.5;
static const CGFloat kIndicatorCornerRadius = 4.0;

// The loading-status message label geometry and font.
static const CGFloat kMessageLabelCenterY = 70.0;
static const CGFloat kMessageLabelFontSize = 18.0;
static const CGFloat kMessageLabelCornerRadius = 8.0;
static const CGFloat kMessageLabelHiddenAlpha = 0.0;
static const NSInteger kMessageLabelLineCount = 2;

// The spot-information overlay panel and its drop shadow. The dimmed backdrop reuses the shared
// fade-in alpha (@c g_dAudioManagerResumeFadeInTime).
static const CGFloat kInfoOverlaySize = 10.0;
static const CGFloat kInfoOverlayShadowRadius = 5.0;
static const CGFloat kInfoOverlayShadowOpacity = 1.0;

// The overlay's close button: 54-point vertical anchor, inset ten points from the top-right corner.
static const CGFloat kInfoCloseButtonAnchorY = 54.0;
static const CGFloat kInfoCloseButtonInset = 10.0;

// The error label geometry: the shared pad width (@c g_dMascotMessageMaxWidthPad) on pad, a fixed
// 350-point width on phone.
static const CGFloat kErrorLabelWidthPhone = 350.0;
static const CGFloat kErrorLabelCornerRadius = 8.0;
static const CGFloat kErrorLabelVisibleAlpha = 1.0;
// The error label's fade-in duration.
static const CGFloat kErrorLabelFadeInDuration = 0.3; // @ghidraAddress 0x3010a0

// A first-page dictionary capacity hint for the accumulating spot and model collections.
static const NSUInteger kSpotDictionaryCapacity = 64;

// A large sentinel so the first candidate model always wins the minimum-order comparison.
static const NSInteger kModelOrderSentinel = 0x7fffffff;

@implementation RBSearchMapView {
    // The number of in-flight requests; the activity indicator spins while it is positive.
    int m_IndicatorCount;
    // Whether the campaign master and its images have finished loading.
    BOOL m_LoadedMaster;
    BOOL m_LoadedImages;
    // The last map region the spot list was requested for.
    MKCoordinateRegion m_LastRegion;
    // Whether the view is currently a key-value observer of the map's user location.
    BOOL m_IsObservingLocation;
    // Whether the first user-location fix has already been observed.
    BOOL m_FirstLocationObserved;
}

#pragma mark - Class helpers

+ (BOOL)currentLocationEnabled {
    if (![CLLocationManager locationServicesEnabled]) {
        return NO;
    }
    if (![CLLocationManager respondsToSelector:@selector(authorizationStatus)]) {
        return YES;
    }
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if ([CLLocationManager instancesRespondToSelector:@selector(requestWhenInUseAuthorization)]) {
        return status == kCLAuthorizationStatusAuthorizedWhenInUse;
    }
    return status == kCLAuthorizationStatusAuthorizedAlways;
}

+ (double)rangeOfRegion:(MKCoordinateRegion)region {
    // The binary measures the diagonal from the latitude delta alone; it does not read the
    // longitude delta.
    double latitudeDelta = region.span.latitudeDelta;
    return sqrt(latitudeDelta * latitudeDelta + latitudeDelta * latitudeDelta);
}

+ (MKMapRect)mapRectForCoordinateRegion:(MKCoordinateRegion)region {
    double latitudeInset = region.span.latitudeDelta * kMapRectSpanScale;
    double longitudeInset = region.span.longitudeDelta * kMapRectSpanScale;
    double top = region.center.latitude - longitudeInset;
    MKMapPoint topLeft = MKMapPointForCoordinate(
        CLLocationCoordinate2DMake(region.center.latitude + latitudeInset, top));
    double bottom = region.center.latitude + longitudeInset;
    MKMapPoint bottomRight = MKMapPointForCoordinate(
        CLLocationCoordinate2DMake(region.center.latitude - latitudeInset, top));
    return MKMapRectMake(topLeft.x, top, fabs(bottomRight.x - topLeft.x), fabs(bottom - top));
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.dictSpot = [[NSMutableDictionary alloc] initWithCapacity:kSpotDictionaryCapacity];
        m_IsObservingLocation = NO;
        m_FirstLocationObserved = NO;
        m_LoadedMaster = NO;
        m_LoadedImages = NO;
        m_IndicatorCount = 0;
        [self setupView];
    }
    return self;
}

- (void)dealloc {
    [self removeFromSuperview];
    if (m_IsObservingLocation) {
        [self.mapView.userLocation removeObserver:self forKeyPath:kUserLocationKeyPath];
        m_IsObservingLocation = NO;
    }
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView setShowsUserLocation:NO];
    self.mapView.delegate = nil;
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
    [self.listDownloader cancel];
    [self.masterDownloader cancel];
    if (self.imageDownloader) {
        [self.imageDownloader cancelDownload];
    }
}

#pragma mark - View construction

- (void)setupView {
    [self setBackgroundColor:[UIColor clearColor]];
    [self setAutoresizingMask:g_dwAutoresizingMaskFlexibleAll];

    if (!self.mapView) {
        MKMapView *map = [[MKMapView alloc] initWithFrame:self.bounds];
        if (map) {
            [map setAutoresizingMask:g_dwAutoresizingMaskFlexibleAll];
            [map setShowsUserLocation:YES];
            map.delegate = self;
            [self setMapView:map];
        }
    }
    [self addSubview:self.mapView];

    if (!self.indicator) {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [self setIndicator:spinner];
        [self.indicator
            setFrame:CGRectMake(self.mapView.frame.size.width * 0.5 - kIndicatorHalfInset,
                                self.mapView.frame.size.height * 0.5 - kIndicatorHalfInset,
                                g_dLayoutMetricThirtyTwo,
                                g_dLayoutMetricThirtyTwo)];
        [self.indicator setAutoresizingMask:g_dwRBWebViewIndicatorAutoresizingMask];
        [self.indicator setHidesWhenStopped:YES];
        [self.indicator setBackgroundColor:[UIColor colorWithWhite:kIndicatorBackdropWhite
                                                             alpha:kIndicatorBackdropAlpha]];
        [self.indicator.layer setCornerRadius:kIndicatorCornerRadius];
    }
    [self.mapView addSubview:self.indicator];

    if (!self.messageLabel) {
        UILabel *label = [[UILabel alloc]
            initWithFrame:CGRectMake(0, 0, g_dNameImageMaxWidth, g_dLayoutMetricSixty)];
        [label setBounds:CGRectMake(0, 0, g_dNameImageMaxWidth, g_dLayoutMetricSixty)];
        (void)self.mapView.bounds; // Yes, the binary reads this and discards it.
        [label setCenter:CGPointMake(g_dNameImageMaxWidth * 0.5, kMessageLabelCenterY)];
        [label setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleBottomMargin)];
        [label setOpaque:NO];
        [label setBackgroundColor:[UIColor colorWithWhite:kIndicatorBackdropWhite
                                                    alpha:g_dRBWebViewGrayViewWhite]];
        [label setFont:[UIFont boldSystemFontOfSize:kMessageLabelFontSize]];
        [label setNumberOfLines:kMessageLabelLineCount];
        [label setText:@"店舗を表示するには\n地図を拡大して下さい"];
        [label setTextColor:[UIColor whiteColor]];
        [label setTextAlignment:NSTextAlignmentCenter];
        [label.layer setCornerRadius:kMessageLabelCornerRadius];
        [label setAlpha:kMessageLabelHiddenAlpha];
        [self setMessageLabel:label];
    }
    [self.mapView addSubview:self.messageLabel];

    if (!self.infomationBaseView) {
        [self setInfomationBaseView:[[UIView alloc] init]];
        [self.infomationBaseView setBounds:self.bounds];
        [self.infomationBaseView
            setCenter:CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5)];
        [self.infomationBaseView
            setBackgroundColor:[UIColor colorWithWhite:kIndicatorBackdropWhite
                                                 alpha:g_dAudioManagerResumeFadeInTime]];
        [self.infomationBaseView setAutoresizingMask:g_dwAutoresizingMaskFlexibleAll];
    }
    [self addSubview:self.infomationBaseView];

    if (!self.infomationView) {
        [self setInfomationView:[[UIView alloc] init]];
        [self.infomationView setBounds:CGRectMake(0, 0, kInfoOverlaySize, kInfoOverlaySize)];
        [self.infomationView
            setCenter:CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5)];
        [self.infomationView setHidden:YES];
        [self.infomationView setAutoresizingMask:g_dwRBWebViewIndicatorAutoresizingMask];
        [self.infomationView.layer setShadowRadius:kInfoOverlayShadowRadius];
        [self.infomationView.layer setShadowColor:[UIColor blackColor].CGColor];
        [self.infomationView.layer setShadowOpacity:kInfoOverlayShadowOpacity];
        [self.infomationView.layer setShadowOffset:CGSizeZero];
    }
    [self.infomationBaseView addSubview:self.infomationView];

    if (!self.infomationImage) {
        [self setInfomationImage:[[UIImageView alloc] init]];
        [self.infomationImage setBounds:CGRectMake(0, 0, kInfoOverlaySize, kInfoOverlaySize)];
        [self.infomationImage setCenter:CGPointMake(self.infomationView.bounds.size.width * 0.5,
                                                    self.infomationView.bounds.size.height * 0.5)];
        [self.infomationImage setAutoresizingMask:g_dwRBWebViewIndicatorAutoresizingMask];
    }
    [self.infomationView addSubview:self.infomationImage];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *closeImage = [UIImage imageWithName:kSearchCancelImageName];
    [closeButton setImage:closeImage forState:UIControlStateNormal];
    [closeButton setBounds:CGRectMake(0, 0, kInfoCloseButtonAnchorY, kInfoCloseButtonAnchorY)];
    [closeButton setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin |
                                      UIViewAutoresizingFlexibleBottomMargin)];
    (void)self.infomationView.bounds; // Yes, the binary reads this and discards it.
    [closeButton setCenter:CGPointMake(self.infomationView.bounds.size.width -
                                           closeImage.size.width * 0.5 - kInfoCloseButtonInset,
                                       closeImage.size.height * 0.5 + kInfoCloseButtonInset)];
    [closeButton addTarget:self
                    action:@selector(selectHideInfo:)
          forControlEvents:UIControlEventTouchUpInside];
    [self.infomationView addSubview:closeButton];

    if (!self.errorLabel) {
        CGFloat errorWidth = (!IsPad()) ? g_dMascotMessageMaxWidthPad : kErrorLabelWidthPhone;
        UILabel *label =
            [[UILabel alloc] initWithFrame:CGRectMake(0, 0, errorWidth, g_dLayoutMetricSixty)];
        [label setBounds:CGRectMake(0, 0, errorWidth, g_dLayoutMetricSixty)];
        (void)self.mapView.bounds; // Yes, the binary reads this and discards it.
        [label setCenter:CGPointMake(errorWidth * 0.5,
                                     g_dLayoutMetricSixty * 0.5 + g_dSliderRowHeightWide)];
        [label setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleBottomMargin)];
        [label setOpaque:NO];
        [label setBackgroundColor:[UIColor colorWithWhite:kIndicatorBackdropWhite
                                                    alpha:g_dRBWebViewGrayViewWhite]];
        [label setFont:[UIFont boldSystemFontOfSize:kMessageLabelFontSize]];
        [label setNumberOfLines:kMessageLabelLineCount];
        [label setText:@""];
        [label setTextColor:[UIColor whiteColor]];
        [label setTextAlignment:NSTextAlignmentCenter];
        [label.layer setCornerRadius:kErrorLabelCornerRadius];
        [label setHidden:YES];
        [self setErrorLabel:label];
    }
    [self addSubview:self.errorLabel];
}

#pragma mark - Map region

- (void)initialView {
    MKCoordinateRegion region;
    region.center = CLLocationCoordinate2DMake(kInitialCenterLatitude, kInitialCenterLongitude);
    region.span = MKCoordinateSpanMake(kInitialSpanLatitudeDelta, kInitialSpanLongitudeDelta);
    [self.mapView setRegion:region animated:NO];
    [self getMaster];
}

- (void)pushCurrent {
    if ([RBSearchMapView currentLocationEnabled]) {
        [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate
                                 animated:YES];
    }
}

#pragma mark - Tracking

- (void)toggleTrackingMode {
    if (![CLLocationManager locationServicesEnabled]) {
        [UIAlertView showInfomation];
        return;
    }

    if ([CLLocationManager respondsToSelector:@selector(authorizationStatus)]) {
        BOOL respondsToRequest =
            [self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)];
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        BOOL authorized = respondsToRequest ?
                              (status == kCLAuthorizationStatusAuthorizedWhenInUse) :
                              (status == kCLAuthorizationStatusAuthorizedAlways);
        if (!authorized) {
            [UIAlertView showInfomation];
            return;
        }
    }

    if (![self.mapView respondsToSelector:@selector(setUserTrackingMode:animated:)]) {
        [self pushCurrent];
        return;
    }
    if (self.mapView.userTrackingMode == MKUserTrackingModeNone) {
        [self.mapView setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
    } else {
        [self.mapView setUserTrackingMode:MKUserTrackingModeNone animated:YES];
    }
}

#pragma mark - Indicator

- (void)addIndicator {
    int previous = m_IndicatorCount;
    m_IndicatorCount = previous + 1;
    if (previous >= 0) {
        [self.indicator startAnimating];
    }
}

- (void)subIndicator {
    int previous = m_IndicatorCount;
    m_IndicatorCount = previous - 1;
    if (m_IndicatorCount == 0 || previous < 1) {
        [self.indicator stopAnimating];
    }
}

#pragma mark - Spot information overlay

- (void)selectHideInfo:(id)sender {
    [self.infomationBaseView setHidden:YES];
    [self.infomationImage setHidden:YES];
    [self.infomationView setHidden:YES];
    [self requestList:self.mapView.region];
}

#pragma mark - Networking

- (void)getMaster {
    m_LoadedMaster = NO;
    m_LoadedImages = NO;
    if (self.masterDownloader) {
        [self.masterDownloader cancel];
        [self setMasterDownloader:nil];
    }
    [self setMasterDownloader:[[Downloader alloc] initWithURL:[NetworkUtil searchMasterURL]
                                                         save:nil]];
    [self.masterDownloader startDownloadingWithDelegate:self];
    [self addIndicator];
}

- (void)requestList:(MKCoordinateRegion)region {
    if (!m_LoadedImages) {
        return;
    }
    NSString *body = [NSString stringWithFormat:kSpotListRequestFormat,
                                                region.center.latitude,
                                                region.center.longitude,
                                                [RBSearchMapView rangeOfRegion:region]];
    [self addIndicator];
    if (self.listDownloader) {
        [self.listDownloader cancel];
    }
    NSData *post = [body dataUsingEncoding:NSUTF8StringEncoding];
    [self setListDownloader:[[Downloader alloc] initWithURL:[NetworkUtil searchURL]
                                                       post:post
                                                contentType:nil]];
    m_LastRegion = region;
    [self.listDownloader startDownloadingWithDelegate:self];
}

- (void)showError:(NSString *)message {
    [self.errorLabel setText:message];
    if ([self.errorLabel isHidden]) {
        [self.errorLabel setAlpha:kMessageLabelHiddenAlpha];
        [self.errorLabel setHidden:NO];
        __weak RBSearchMapView *weakSelf = self;
        [UIView animateWithDuration:kErrorLabelFadeInDuration
                         animations:^{
                           /** @ghidraAddress 0xe0c68 */
                           [weakSelf.errorLabel setAlpha:kErrorLabelVisibleAlpha];
                         }];
    }
}

#pragma mark - Teardown

- (void)viewDidDisappear {
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView setShowsUserLocation:NO];
    self.mapView.delegate = nil;
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager
    didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (![manager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        if (status == kCLAuthorizationStatusAuthorizedAlways && !m_FirstLocationObserved &&
            !m_IsObservingLocation) {
            [self.mapView.userLocation addObserver:self
                                        forKeyPath:kUserLocationKeyPath
                                           options:0
                                           context:nullptr];
            m_IsObservingLocation = YES;
        }
        return;
    }

    if (status == kCLAuthorizationStatusAuthorizedAlways ||
        status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        if (!m_FirstLocationObserved && !m_IsObservingLocation) {
            [self.mapView.userLocation addObserver:self
                                        forKeyPath:kUserLocationKeyPath
                                           options:0
                                           context:nullptr];
            m_IsObservingLocation = YES;
        }
        [self toggleTrackingMode];
    } else if (status == kCLAuthorizationStatusNotDetermined) {
        [manager requestWhenInUseAuthorization];
    }
}

#pragma mark - Key-value observing

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self.mapView.userLocation removeObserver:self forKeyPath:keyPath];
    m_IsObservingLocation = NO;
    m_FirstLocationObserved = YES;
}

#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
}

- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView {
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView {
}

- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error {
}

- (void)mapView:(MKMapView *)mapView
    didChangeUserTrackingMode:(MKUserTrackingMode)mode
                     animated:(BOOL)animated {
    if ([self.delegate respondsToSelector:@selector(didChangeUserTracking:)]) {
        [self.delegate didChangeUserTracking:mode != MKUserTrackingModeNone];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }

    NSString *reuseIdentifier = [(RBMapAnnotation *)annotation modelName];
    MKAnnotationView *view = [mapView dequeueReusableAnnotationViewWithIdentifier:reuseIdentifier];
    if (view) {
        [view setAnnotation:annotation];
        return view;
    }

    view = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    UIImage *pinImage = nil;
    NSNumber *modelIndex = self.modelNameForArrayIndex[reuseIdentifier];
    if (modelIndex && modelIndex.integerValue < (NSInteger)self.models.count) {
        pinImage = self.models[modelIndex.integerValue][kJSONKeyImageObject];
    }
    if (!pinImage) {
        pinImage = [UIImage imageWithName:kSearchDefaultPinImageName];
    }
    [view setImage:pinImage];
    [view setCenterOffset:CGPointMake(0, pinImage.size.height * -0.5)];
    [view setCalloutOffset:CGPointZero];
    [view setCanShowCallout:YES];
    [view setRightCalloutAccessoryView:[UIButton buttonWithType:UIButtonTypeDetailDisclosure]];
    return view;
}

- (void)mapView:(MKMapView *)mapView
                   annotationView:(MKAnnotationView *)view
    calloutAccessoryControlTapped:(UIControl *)control {
    NSString *url = [[NSString alloc] initWithFormat:kMapsAppURLFormat,
                                                     view.annotation.coordinate.latitude,
                                                     view.annotation.coordinate.longitude,
                                                     [view.annotation.title encodeURIComponent]];
    [self setMapURL:url];
    [UIAlertView showMapWithTitle:view.annotation.title delegate:self];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1 && self.mapURL) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.mapURL]];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
}

- (void)alertViewCancel:(UIAlertView *)alertView {
}

- (void)didPresentAlertView:(UIAlertView *)alertView {
    [UIAlertView
        setExclusiveTouchForView:[UIApplication sharedApplication]
                                     .keyWindow.rootViewController.presentedViewController.view];
}

#pragma mark - DownloaderDelegate

// Parse the spot-list response into annotations and drop those inside the current map rectangle.
- (void)handleListDownloadFinished:(Downloader *)downloader {
    id json = [downloader getDataInJSON];
    if (json) {
        NSMutableArray *annotations = [NSMutableArray arrayWithCapacity:0];
        id spotList = json[kJSONKeyGameCenterList];
        if ([spotList isKindOfClass:[NSArray class]]) {
            MKMapRect visibleRect =
                [RBSearchMapView mapRectForCoordinateRegion:self.mapView.region];
            for (id spotEntry in spotList) {
                if (![spotEntry isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                id spotID = spotEntry[kJSONKeyID];
                id latitude = spotEntry[kJSONKeyLat];
                id longitude = spotEntry[kJSONKeyLong];
                id name = spotEntry[kJSONKeyName];
                id openHours = spotEntry[kJSONKeyOpen];
                id modelNames = spotEntry[kJSONKeyModel];
                if (![spotID isKindOfClass:[NSNumber class]] ||
                    ![latitude isKindOfClass:[NSNumber class]] ||
                    ![longitude isKindOfClass:[NSNumber class]] ||
                    ![name isKindOfClass:[NSString class]] ||
                    ![openHours isKindOfClass:[NSString class]] ||
                    ![modelNames isKindOfClass:[NSArray class]]) {
                    continue;
                }
                if (self.dictSpot[spotID] || [modelNames count] == 0) {
                    continue;
                }

                // Pick the model whose master-list order is lowest, defaulting to the first.
                NSString *pinModelName = nil;
                NSInteger bestOrder = kModelOrderSentinel;
                for (id modelName in modelNames) {
                    if (![modelName isKindOfClass:[NSString class]]) {
                        continue;
                    }
                    if (!pinModelName) {
                        pinModelName = modelName;
                    }
                    NSNumber *order = self.modelNameForArrayIndex[modelName];
                    if (order && order.integerValue < bestOrder) {
                        bestOrder = order.integerValue;
                        pinModelName = modelName;
                    }
                }

                CLLocationCoordinate2D coordinate =
                    CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);
                RBMapAnnotation *annotation = [[RBMapAnnotation alloc]
                    initWithCoordinate:coordinate
                                 Title:name
                              SubTitle:[NSString stringWithFormat:kSpotSubtitleFormat, openHours]
                                 Model:pinModelName];
                self.dictSpot[spotID] = annotation;
                if (MKMapRectContainsPoint(visibleRect, MKMapPointForCoordinate(coordinate))) {
                    [annotations addObject:annotation];
                }
            }
        }
        if (annotations.count) {
            [self.mapView addAnnotations:annotations];
        }
    }
    [self setListDownloader:nil];
}

// Parse the campaign-master response: version-gate, build the model list, and kick off image loads.
- (void)handleMasterDownloadFinished:(Downloader *)downloader {
    id json = [downloader getDataInJSON];
    if (!json) {
        [self showError:g_pLocalizedServerConnectFailed];
        return;
    }

    id requiredVersion = json[kJSONKeyVersion];
    if (![requiredVersion isKindOfClass:[NSString class]]) {
        [self showError:g_pLocalizedServerConnectFailed];
        return;
    }

    NSString *bundleVersion = [NSBundle mainBundle].infoDictionary[kBundleVersionKey];
    if (!bundleVersion ||
        (requiredVersion && [bundleVersion compare:requiredVersion
                                           options:NSNumericSearch] == NSOrderedAscending)) {
        [self showError:g_pLocalizedSearchVersionMismatch];
        return;
    }

    id infoImage = json[kJSONKeyInfo];
    id markList = json[kJSONKeyMark];
    if (![infoImage isKindOfClass:[NSString class]] || ![markList isKindOfClass:[NSArray class]]) {
        [self showError:g_pLocalizedServerConnectFailed];
        return;
    }

    [self setInfo:[[NSMutableDictionary alloc] initWithCapacity:0]];
    self.info[kJSONKeyImage] = [NSString stringWithString:infoImage];
    [self setModels:[[NSMutableArray alloc] initWithCapacity:0]];
    for (id markEntry in markList) {
        if (![markEntry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        id order = markEntry[kJSONKeyOrder];
        id model = markEntry[kJSONKeyModel];
        id name = markEntry[kJSONKeyName];
        id image = markEntry[kJSONKeyImage];
        if ([order isKindOfClass:[NSString class]] && [model isKindOfClass:[NSString class]] &&
            [name isKindOfClass:[NSString class]] && [image isKindOfClass:[NSString class]]) {
            [self.models addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:order,
                                                                                     kJSONKeyOrder,
                                                                                     model,
                                                                                     kJSONKeyModel,
                                                                                     name,
                                                                                     kJSONKeyName,
                                                                                     image,
                                                                                     kJSONKeyImage,
                                                                                     nil]];
        }
    }

    [self setModelNameForArrayIndex:[[NSMutableDictionary alloc] initWithCapacity:0]];
    for (NSInteger i = 0; i < (NSInteger)self.models.count; ++i) {
        id model = self.models[i][kJSONKeyModel];
        self.modelNameForArrayIndex[@(i)] = model;
    }

    if (self.imageDownloader) {
        [self.imageDownloader cancelDownload];
    }
    NSString *infoImageURL = self.info[kJSONKeyImage];
    if (!infoImageURL || [infoImageURL length] == 0) {
        [self showError:g_pLocalizedServerNoData];
    } else {
        ImageDownloader *loader = [[ImageDownloader alloc] init];
        loader.delegate = self;
        loader.imageURL = infoImageURL;
        [self setImageDownloader:loader];
        [self.imageDownloader startDownload];
        [self addIndicator];
    }
    m_LoadedMaster = YES;
}

- (void)downloaderFinished:(Downloader *)downloader {
    if (self.listDownloader == downloader) {
        [self handleListDownloadFinished:downloader];
    } else if (self.masterDownloader == downloader) {
        [self handleMasterDownloadFinished:downloader];
    }
    [self subIndicator];
}

- (void)downloaderError:(Downloader *)downloader {
    if (self.listDownloader == downloader) {
        [self setListDownloader:nil];
    } else if (self.masterDownloader == downloader) {
        [self showError:g_pLocalizedServerConnectFailed];
    }
    [self subIndicator];
}

#pragma mark - ImageDownloaderDelegate

// Start downloading the info image (when @p imageURL is a model image URL) or the given URL.
- (void)startNextImageDownloadForURL:(NSString *)imageURL {
    if (self.imageDownloader) {
        [self.imageDownloader cancelDownload];
    }
    ImageDownloader *loader = [[ImageDownloader alloc] init];
    loader.delegate = self;
    loader.imageURL = imageURL;
    [self setImageDownloader:loader];
    [self.imageDownloader startDownload];
    [self addIndicator];
}

// Reveal the info overlay sized to the downloaded info image.
- (void)presentInfomationImage:(UIImage *)image {
    [self.infomationImage setImage:image];
    [self.infomationImage setBounds:CGRectMake(0, 0, image.size.width, image.size.height)];
    [self.infomationImage setHidden:NO];
    [self.infomationView setBounds:CGRectMake(0, 0, image.size.width, image.size.height)];
    [self.infomationView setHidden:NO];
}

- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UIImage *image = [downloader getImage];
    NSString *imageURL = downloader.imageURL;
    if (!image) {
        [self setImageDownloader:nil];
        [self showError:g_pLocalizedServerConnectFailed];
        [self subIndicator];
        return;
    }

    if ([self.info[kJSONKeyImage] isEqual:imageURL]) {
        self.info[kJSONKeyImageObject] = image;
    } else {
        for (NSMutableDictionary *model in self.models) {
            if ([model[kJSONKeyImage] isEqual:imageURL]) {
                model[kJSONKeyImageObject] = image;
                break;
            }
        }
    }
    [self setImageDownloader:nil];

    if (!self.info[kJSONKeyImageObject]) {
        [self startNextImageDownloadForURL:self.info[kJSONKeyImage]];
    } else {
        for (NSMutableDictionary *model in self.models) {
            if (!model[kJSONKeyImageObject]) {
                [self startNextImageDownloadForURL:model[kJSONKeyImage]];
                [self subIndicator];
                return;
            }
        }
        m_LoadedImages = YES;
        [self presentInfomationImage:self.info[kJSONKeyImageObject]];
    }
    [self subIndicator];
}

- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    [self setImageDownloader:nil];
    [self showError:g_pLocalizedServerConnectFailed];
    [self subIndicator];
}

@end
