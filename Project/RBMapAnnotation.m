//
//  RBMapAnnotation.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBMapAnnotation).
//

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
        // The binary allocates a fresh string copy for each value before assigning it, even though
        // the title and subtitle properties are already copy and modelName is strong.
        self.title = [[NSString alloc] initWithString:title];
        self.subtitle = [[NSString alloc] initWithString:subtitle];
        self.modelName = [[NSString alloc] initWithString:modelName];
    }
    return self;
}

@end
