#import "ApplilinkParameters.h"

@implementation ApplilinkParameters

#pragma mark Request configuration

- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(NSString *)adLocation
                  requestCode:(id)requestCode {
    _adModel = adModel;
    _adLocation = adLocation;
    _requestCode = requestCode;
}

- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(NSString *)adLocation
                verticalAlign:(int)verticalAlign
                  requestCode:(id)requestCode {
    _adModel = adModel;
    _adLocation = adLocation;
    // Yes, the binary never stores verticalAlign in this setter.
    _requestCode = requestCode;
}

@end
