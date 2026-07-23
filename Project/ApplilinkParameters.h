/** @file
 * Reconstructed interface for the Applilink advert SDK's @c ApplilinkParameters request object.
 *
 * @c ApplilinkParameters is the request-parameters model KONAMI's Applilink advert SDK passes
 * around: it carries the advert model, advert location, vertical alignment, and request code for a
 * single advert request, and is handed back to the caller's delegate on a failure. Reconstructed
 * from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An Applilink advert request descriptor.
 */
@interface ApplilinkParameters : NSObject

/**
 * @brief The advert-model identifier for the request.
 */
@property(nonatomic, assign) int adModel;

/**
 * @brief The advert-location identifier for the request.
 */
@property(nonatomic, strong, nullable) NSString *adLocation;

/**
 * @brief The vertical alignment for the request.
 */
@property(nonatomic, assign) int verticalAlign;

/**
 * @brief The caller's request code for the request.
 *
 * The runtime metadata types this as an untyped object and the synthesised accessor copies it, so
 * it is modelled as an untyped @c copy property.
 */
@property(nonatomic, copy, nullable) id requestCode;

/**
 * @brief Populate the request with its advert model, location, and request code.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param requestCode The caller's request code.
 * @ghidraAddress 0x23676c
 */
- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                  requestCode:(nullable id)requestCode;

/**
 * @brief Populate the request with its advert model, location, vertical alignment, and request
 * code.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical alignment.
 * @param requestCode The caller's request code.
 * @ghidraAddress 0x2367f8
 */
- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                verticalAlign:(int)verticalAlign
                  requestCode:(nullable id)requestCode;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
