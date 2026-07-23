/** @file
 * Reconstructed interface for the Applilink advert SDK's @c ApplilinkWebAPI transport layer.
 *
 * @c ApplilinkWebAPI is the SDK's low-level HTTP transport: it assembles @c GET and @c POST
 * @c NSMutableURLRequest objects from a base URL and a parameter dictionary (percent-joining each
 * @c key=value pair and expanding array values into repeated @c key[]=value pairs), dispatches them
 * synchronously or asynchronously through @c NSURLConnection, applies a bounded timeout-retry
 * policy, parses the JSON response body with @c NSJSONSerialization, and maps transport and parse
 * failures onto @c ApplilinkNetworkError codes. A second response path parses the contents server's
 * newline-delimited body. The class carries a single retry counter as instance state; the remaining
 * behaviour is expressed through class methods that wrap a throwaway instance. Reconstructed from
 * Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Block invoked when an Applilink request finishes successfully.
 * @param request The request that was sent.
 * @param result The parsed response, an @c NSDictionary for the JSON path.
 */
typedef void (^ApplilinkWebAPIFinishedBlock)(id _Nullable request, id _Nullable result);

/**
 * @brief Block invoked when an Applilink request fails.
 * @param request The request that was sent.
 * @param error The failure, an @c NSError in the @c ApplilinkErrorDomain or @c NSURLErrorDomain
 * domain.
 */
typedef void (^ApplilinkWebAPIFailedBlock)(id _Nullable request, NSError *_Nullable error);

/**
 * @brief Applilink SDK HTTP transport, retry policy, and response parsing.
 */
@interface ApplilinkWebAPI : NSObject

/**
 * @brief Initialise the transport with a cleared retry counter.
 * @return The initialised instance.
 * @ghidraAddress 0x221128
 */
- (nullable instancetype)init;

/**
 * @brief The parameters common to every Applilink request.
 * @return An empty dictionary; the shipped build adds no common parameters.
 * @ghidraAddress 0x221184
 */
- (nullable NSDictionary *)commonParameters;

/**
 * @brief Build a request for a URL, method, parameters, timeout, and cache policy.
 *
 * The parameters are merged with @c commonParameters, then dispatched to
 * @c requestForGetWithURL:parameters: or @c requestForPostWithURL:parameters: depending on whether
 * @p method equals @c "POST". The HTTP method, timeout, and cache policy are then applied.
 * @param URL The base URL string.
 * @param method The HTTP method; @c "POST" selects the POST body path, anything else the GET query
 * path.
 * @param parameters The request parameters.
 * @param timeout The request timeout, in seconds.
 * @param cachePolicy The cache policy as a boxed @c NSNumber, or @c nil for the default policy.
 * @return The configured request.
 * @ghidraAddress 0x2211dc
 */
- (nullable NSMutableURLRequest *)requestWithURL:(nullable NSString *)URL
                                          method:(nullable NSString *)method
                                      parameters:(nullable NSDictionary *)parameters
                                         timeout:(float)timeout
                                     cachePolicy:(nullable NSNumber *)cachePolicy;

/**
 * @brief Build a @c GET request, appending the parameters to the URL as a query string.
 * @param URL The base URL string.
 * @param parameters The parameters to append.
 * @return The GET request.
 * @ghidraAddress 0x2213a4
 */
- (nullable NSMutableURLRequest *)requestForGetWithURL:(nullable NSString *)URL
                                            parameters:(nullable NSDictionary *)parameters;

/**
 * @brief Build a @c POST request, serialising the parameters into a form-encoded body.
 *
 * Each value is percent-joined into a @c key=value pair; an array value expands into repeated
 * @c key[]=value pairs. The pairs are joined with @c & and set as the request body with a
 * @c Content-Type of @c application/x-www-form-urlencoded.
 * @param URL The URL string.
 * @param parameters The parameters to serialise.
 * @return The POST request.
 * @ghidraAddress 0x221474
 */
- (nullable NSMutableURLRequest *)requestForPostWithURL:(nullable NSString *)URL
                                             parameters:(nullable NSDictionary *)parameters;

/**
 * @brief Send a request asynchronously with a bounded timeout-retry policy.
 *
 * The request is blocked while a session regeneration is in flight, short-circuited when it is
 * itself the session-regeneration request, then sent through @c NSURLConnection on the main queue.
 * On older operating-system versions, or when @p retry is set, a GCD timer re-issues the request up
 * to the retry cap. The completion handler parses the JSON body and invokes @p finishedBlock or
 * @p failedBlock.
 * @param URL The base URL string.
 * @param method The HTTP method.
 * @param parameters The request parameters.
 * @param userInfo Caller context passed back to the callback blocks.
 * @param tag A caller-supplied request tag.
 * @param cachePolicy The cache policy as a boxed @c NSNumber, or @c nil for the default policy.
 * @param timeout The request timeout, in seconds.
 * @param retry Whether the request participates in the timeout-retry policy.
 * @param finishedBlock The success callback.
 * @param failedBlock The failure callback.
 * @ghidraAddress 0x2218fc
 */
- (void)requestAsynchronousWithURL:(nullable NSString *)URL
                            method:(nullable NSString *)method
                        parameters:(nullable NSDictionary *)parameters
                          userInfo:(nullable id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(nullable NSNumber *)cachePolicy
                           timeout:(float)timeout
                             retry:(BOOL)retry
                     finishedBlock:(nullable ApplilinkWebAPIFinishedBlock)finishedBlock
                       failedBlock:(nullable ApplilinkWebAPIFailedBlock)failedBlock;

/**
 * @brief Send a request synchronously with a bounded timeout-retry loop and parse the JSON body.
 *
 * The request is sent through @c NSURLConnection with a ten-second timeout. Server errors in the
 * 400-599 range, and connection timeouts, are retried up to the retry cap; on final failure a
 * localised @c ApplilinkNetworkError is written to @p error. On success the parsed JSON object is
 * returned.
 * @param URL The base URL string.
 * @param method The HTTP method.
 * @param parameters The request parameters.
 * @param cachePolicy The cache policy as a boxed @c NSNumber, or @c nil for the default policy.
 * @param error On failure, the localised error; may be @c NULL.
 * @return The parsed JSON response, or @c nil on failure.
 * @ghidraAddress 0x222f38
 */
- (nullable id)requestSynchronousWithURL:(nullable NSString *)URL
                                  method:(nullable NSString *)method
                              parameters:(nullable NSDictionary *)parameters
                             cachePolicy:(nullable NSNumber *)cachePolicy
                                   error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Parse a contents-server response and dispatch the outcome.
 *
 * When @p request targets the reward contents server (the @c ApplilinkReward.appliURL default) and
 * @p data is non-empty, the newline-delimited body is parsed into a dictionary and delivered to
 * @p finishedBlock; a malformed or missing body delivers a localised @c ApplilinkNetworkError to
 * @p failedBlock.
 * @param response The contents-server response body.
 * @param request The request that was sent.
 * @param data The raw response data.
 * @param finishedBlock The success callback.
 * @param failedBlock The failure callback.
 * @return The value forwarded from the invoked callback, or @c nil.
 * @ghidraAddress 0x222928
 */
- (nullable id)responseFromContentsServer:(nullable id)response
                                  request:(nullable id)request
                                     data:(nullable NSData *)data
                            finishedBlock:(nullable ApplilinkWebAPIFinishedBlock)finishedBlock
                              failedBlock:(nullable ApplilinkWebAPIFailedBlock)failedBlock;

/**
 * @brief Whether this device's operating-system version supports the network-retry policy.
 * @return @c YES when the operating-system version is at least 6.0.
 * @ghidraAddress 0x2238c4
 */
- (BOOL)canUseNetworkRetry;

/**
 * @brief Convenience class factory for the asynchronous request.
 *
 * The work is dispatched to a global concurrent queue, where a throwaway instance sends the
 * request through the instance method of the same selector.
 * @ghidraAddress 0x2232d8
 */
+ (void)requestAsynchronousWithURL:(nullable NSString *)URL
                            method:(nullable NSString *)method
                        parameters:(nullable NSDictionary *)parameters
                          userInfo:(nullable id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(nullable NSNumber *)cachePolicy
                           timeout:(float)timeout
                             retry:(BOOL)retry
                     finishedBlock:(nullable ApplilinkWebAPIFinishedBlock)finishedBlock
                       failedBlock:(nullable ApplilinkWebAPIFailedBlock)failedBlock;

/**
 * @brief Convenience class factory for @c requestSynchronousWithURL:method:parameters:cachePolicy:
 * error:.
 * @return The parsed JSON response, or @c nil on failure.
 * @ghidraAddress 0x223604
 */
+ (nullable id)requestSynchronousWithURL:(nullable NSString *)URL
                                  method:(nullable NSString *)method
                              parameters:(nullable NSDictionary *)parameters
                             cachePolicy:(nullable NSNumber *)cachePolicy
                                   error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Convenience class factory for @c responseFromContentsServer:request:data:finishedBlock:
 * failedBlock:.
 * @return The value forwarded from the invoked callback, or @c nil.
 * @ghidraAddress 0x223704
 */
+ (nullable id)responseFromContentsServer:(nullable id)response
                                  request:(nullable id)request
                                     data:(nullable NSData *)data
                            finishedBlock:(nullable ApplilinkWebAPIFinishedBlock)finishedBlock
                              failedBlock:(nullable ApplilinkWebAPIFailedBlock)failedBlock;

/**
 * @brief Cancel the timeout-retry policy for outstanding requests.
 * @ghidraAddress 0x223818
 */
+ (void)retryCancel;

/**
 * @brief Arm or disarm the session-connection wait gate.
 *
 * When set, asynchronous requests block until the gate clears; the gate is auto-cleared after ten
 * seconds through @c calcelSessionConnection.
 * @param sessionConnectionWait @c YES to arm the gate, @c NO to clear it.
 * @ghidraAddress 0x223828
 */
+ (void)setSessionConnectionWait:(BOOL)sessionConnectionWait;

/**
 * @brief Clear the session-connection wait gate. The binary spells this selector
 * @c calcelSessionConnection without correcting the @c cancel typo.
 * @ghidraAddress 0x2238a4
 */
+ (void)calcelSessionConnection;

/**
 * @brief Set whether the session is established, gating the session-regeneration short circuit.
 * @param sessionStatus @c YES when the session is established.
 * @ghidraAddress 0x2238b4
 */
+ (void)setSessionStatus:(BOOL)sessionStatus;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
