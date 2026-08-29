#import "RBMapAnnotation.h"

@implementation RBMapAnnotation

#pragma mark - Lifecycle

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                             Title:(NSString *)title
                          SubTitle:(NSString *)subtitle
                             Model:(NSString *)modelName {
    /** @ghidraAddress 0xdf15c */
    self = [super init];
    if (self) {
        self.coordinate = coordinate;
        // The binary copies each string again even though the properties already copy.
        self.title = [[NSString alloc] initWithString:title];
        self.subtitle = [[NSString alloc] initWithString:subtitle];
        self.modelName = [[NSString alloc] initWithString:modelName];
    }
    return self;
}

@end
