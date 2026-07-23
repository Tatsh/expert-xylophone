/** @file
 * Reconstructed interface for the Applilink advert SDK's @c DestinationCore endpoint helper.
 *
 * @c DestinationCore is a stateless class that registers a click-through destination with the
 * Applilink advert server. Its single public class method assembles a parameter dictionary (the
 * @c ad system marker, a country code, and a return URL), merges the shared user-agent parameters
 * through @c ApplilinkUtilities, builds a @c GET request for @c /destination/regist.php through
 * @c ApplilinkWebAPI, and dispatches it through an @c ApplilinkURLConnection for which the class
 * itself acts as the (stubbed) @c ApplilinkURLConnectionDelegate. It holds no instance state and
 * defines no ivars. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

#import "ApplilinkURLConnection.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Stateless helper that registers a click-through destination with the Applilink server.
 *
 * The class conforms to @c ApplilinkURLConnectionDelegate so it can be passed as the connection
 * delegate for its own request; the shipped build leaves every delegate callback empty.
 */
@interface DestinationCore : NSObject <ApplilinkURLConnectionDelegate>

/**
 * @brief Register a click-through destination with the Applilink advert server.
 *
 * Builds a parameter dictionary containing the @c ad system marker, @p countryCode, and @p url,
 * merges the shared user-agent parameters, and posts a @c GET request to
 * @c /destination/regist.php (built from @c ApplilinkConsts baseUrlSsl) with a ten-second timeout.
 * The request runs through an @c ApplilinkURLConnection whose delegate is this class. The
 * @p delegate argument is accepted for API symmetry but ignored by the shipped build.
 * @param countryCode The country code registered as the @c country_code parameter.
 * @param url The return URL registered as the @c rturl parameter.
 * @param delegate The caller's delegate; ignored by the shipped build.
 * @ghidraAddress 0x220c20
 */
+ (void)destinationRegistWithCountryCode:(nullable NSString *)countryCode
                                     url:(nullable NSString *)url
                                delegate:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
