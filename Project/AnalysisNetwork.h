/** @file
 * Reconstructed interface for the Applilink advert SDK's @c AnalysisNetwork.
 *
 * @c AnalysisNetwork is the SDK-gated front door to the advert-analytics layer: a stateless class
 * (no ivars, a single class method) that guards the underlying @c AnalysisNetworkCore request
 * sender behind an @c ApplilinkConsts SDK-availability check. When the SDK may not be used it
 * short-circuits the caller's callback with a localised @c 1025 error; otherwise it delegates the
 * request to @c AnalysisNetworkCore. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The SDK-availability gate in front of the Applilink advert-analytics core.
 *
 * The class holds no state of its own; its single member is a class method.
 */
@interface AnalysisNetwork : NSObject

/**
 * @brief Post a result registration, first gating on Applilink SDK availability.
 *
 * When @c ApplilinkConsts @c canUseApplilinkSdk is @c NO the callback is invoked immediately with a
 * localised @c 1025 (SDK version not supported) error. Otherwise the request is delegated to
 * @c AnalysisNetworkCore @c postAnalysisDataWithResultId:callback:.
 * @param resultId The result identifier.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x213618
 */
+ (void)postAnalysisDataWithResultId:(nullable NSString *)resultId
                            callback:(nullable void (^)(NSError *_Nullable error))callback;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
