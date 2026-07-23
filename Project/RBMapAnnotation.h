/** @file
 * A map pin model. It is an @c MKAnnotation adopter that carries a coordinate, a title, a subtitle,
 * and the spot's model name so @c RBSearchMapView can pick the correct pin image and open the spot
 * in the system Maps app.
 *
 * This header declares only the surface that @c RBSearchMapView depends on; the class itself is not
 * yet fully reconstructed. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBMapAnnotation, image base 0x100000000). @ghidraAddress values are offsets relative to the
 * image base.
 */

#import <MapKit/MapKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A searchable-spot map pin.
 */
@interface RBMapAnnotation : NSObject <MKAnnotation>

/**
 * @brief Initialise a pin with its coordinate, title, subtitle, and model name.
 * @param coordinate The pin's map coordinate.
 * @param title The pin's title.
 * @param subtitle The pin's subtitle.
 * @param modelName The spot's model name, used to select the pin image.
 * @ghidraAddress 0xdf15c
 */
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                             Title:(nullable NSString *)title
                          SubTitle:(nullable NSString *)subtitle
                             Model:(nullable NSString *)modelName;

/**
 * @brief The pin's map coordinate.
 * @ghidraAddress 0xdf418 (getter)
 * @ghidraAddress 0xdf15c (setter)
 */
@property(assign, nonatomic) CLLocationCoordinate2D coordinate;

/**
 * @brief The pin's title.
 * @ghidraAddress 0xdf3e0 (getter)
 * @ghidraAddress 0xdf3f0 (setter)
 */
@property(strong, nonatomic, nullable) NSString *title;

/**
 * @brief The pin's subtitle.
 * @ghidraAddress 0xdf3fc (getter)
 * @ghidraAddress 0xdf40c (setter)
 */
@property(strong, nonatomic, nullable) NSString *subtitle;

/**
 * @brief The spot's model name, used to look up the pin image.
 * @ghidraAddress 0xdf398 (getter)
 * @ghidraAddress 0xdf3a8 (setter)
 */
@property(strong, nonatomic, nullable) NSString *modelName;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
