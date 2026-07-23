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
    // The binary does not store verticalAlign in this setter; only the model, location, and request
    // code are written.
    _requestCode = requestCode;
}

@end
