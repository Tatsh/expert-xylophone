/** @file
 * Reconstructed interface for the KONAMI Applilink SDK's @c ApplilinkURLConnection HTTP request
 * wrapper.
 *
 * @c ApplilinkURLConnection is a thin asynchronous @c NSURLConnection wrapper used throughout the
 * Applilink reward-network SDK (for example by @c ApplilinkWebAPI, @c ApplilinkNetwork, and
 * @c DestinationCore) to run a single @c NSURLRequest and forward the outcome to an
 * @c ApplilinkURLConnectionDelegate. It accumulates the response body in an @c NSMutableData, decodes
 * it as a UTF-8 string on completion, and dispatches success, failure, and redirect notifications to
 * its (weakly-held) delegate. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Outcome callbacks for an @c ApplilinkURLConnection request.
 *
 * Every method is optional: the connection sends each one only after confirming the delegate
 * responds to it.
 */
@protocol ApplilinkURLConnectionDelegate <NSObject>

@optional

/**
 * @brief Sent when the request finished loading, delivering the response body decoded as UTF-8.
 * @param response The response body decoded as a UTF-8 string.
 */
- (void)finishLoadWithResponse:(nullable NSString *)response;

/**
 * @brief Sent when the request failed.
 * @param error The failure error reported by the underlying connection.
 */
- (void)failLoadWithError:(nullable NSError *)error;

/**
 * @brief Sent when the connection is about to follow a redirect.
 * @param request The redirect request the connection is about to send.
 * @return @c YES to intercept the redirect and finish the load without following it, @c NO to let the
 * redirect proceed.
 */
- (BOOL)redirectStartLoad:(nullable NSURLRequest *)request;

@end

/**
 * @brief Asynchronous @c NSURLConnection wrapper that accumulates a response body and forwards the
 * outcome to an @c ApplilinkURLConnectionDelegate.
 */
@interface ApplilinkURLConnection : NSObject <NSURLConnectionDataDelegate>

/**
 * @brief The delegate that receives the request outcome. Held weakly to avoid a retain cycle.
 */
@property(weak, nonatomic, nullable) id<ApplilinkURLConnectionDelegate> connectionDelegate;

/**
 * @brief The response body accumulated so far.
 */
@property(strong, nonatomic, nullable) NSMutableData *receivedData;

/**
 * @brief The most recent response received for the request.
 */
@property(strong, nonatomic, nullable) NSURLResponse *responseData;

/**
 * @brief Initialise the connection wrapper.
 * @return The initialised instance.
 * @ghidraAddress 0x207150
 */
- (instancetype)init;

/**
 * @brief Start the given request, forwarding its outcome to the delegate.
 *
 * The delegate is stored weakly, a new @c NSURLConnection is created and started immediately, and a
 * fresh @c receivedData buffer is allocated when the connection is created successfully.
 * @param request The request to send.
 * @param delegate The delegate to notify of the outcome.
 * @ghidraAddress 0x20718c
 */
- (void)loadRequestWithRequest:(nullable NSURLRequest *)request
                      delegate:(nullable id<ApplilinkURLConnectionDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
