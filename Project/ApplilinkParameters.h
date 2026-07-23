/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c ApplilinkParameters request
 * object.
 *
 * The Applilink SDK ships as a closed third-party library, so only the initialiser and method that
 * @c RecommendNetwork messages are declared here. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An Applilink advert request descriptor.
 */
@interface ApplilinkParameters : NSObject

/**
 * @brief Populate the request with its advert model, location, and request code.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param requestCode The caller's request code.
 */
- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                  requestCode:(NSInteger)requestCode;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
