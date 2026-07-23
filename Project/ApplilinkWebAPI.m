#import "ApplilinkWebAPI.h"

#import <UIKit/UIKit.h>

#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUtilities.h"

// HTTP method that selects the form-encoded POST body path; any other value uses the GET query.
static NSString *const kApplilinkWebAPIPostMethod = @"POST";

// Form-encoding constants for the POST body.
static NSString *const kApplilinkWebAPIContentTypeHeaderField = @"Content-Type";
static NSString *const kApplilinkWebAPIFormURLEncodedContentType =
    @"application/x-www-form-urlencoded";
static NSString *const kApplilinkWebAPIQueryPairFormat = @"%@=%@";
static NSString *const kApplilinkWebAPIQueryArrayPairFormat = @"%@[]=%@";
static NSString *const kApplilinkWebAPIQueryPairSeparator = @"&";

// Endpoint whose presence in a request URL marks it as the session-regeneration request; that
// request is short-circuited rather than blocked on the session gate.
static NSString *const kApplilinkWebAPISessionRegeneratePath = @"/app/auth/sessionRegenerate.php";

// NSUserDefaults key holding the reward contents-server URL, matched to recognise a contents-server
// response.
static NSString *const kApplilinkWebAPIRewardAppliURLKey = @"ApplilinkReward.appliURL";

// Keys used when building the session-regeneration short-circuit result and the contents-server
// error user-info dictionaries.
static NSString *const kApplilinkWebAPIStatusKey = @"status";
static NSString *const kApplilinkWebAPIErrorCodeKey = @"error_code";
static NSString *const kApplilinkWebAPIResponseKey = @"response";

// Contents-server first-line status values.
static NSString *const kApplilinkWebAPIContentsStatusOK = @"1";
static NSString *const kApplilinkWebAPIContentsStatusMalformed = @"2";

// Format that renders a numeric HTTP status code into the error user-info string.
static NSString *const kApplilinkWebAPIStatusCodeFormat = @"%ld";

// GCD queue label for the asynchronous request timer.
static const char *const kApplilinkWebAPIQueueLabel = "requestAsynchronousWithURL";

// Applilink network error codes delivered on the various failure paths. These are the raw integers
// the binary passes to +[ApplilinkNetworkError localizedApplilinkErrorWithCode:].
enum {
    kApplilinkNetworkErrorCodeConnectionFailed = 1003,
    kApplilinkNetworkErrorCodeContentsMalformed = 1006,
    kApplilinkNetworkErrorCodeContentsUnavailable = 1007,
    kApplilinkNetworkErrorCodeTimeout = 1027,
    kApplilinkNetworkErrorCodeJSONUnavailable = 1025,
    kApplilinkNetworkErrorCodeMalformedJSON = 1000,
};

// Session-regeneration success payload: the reward server that has already granted a session
// receives a synthesised result with this reward point total.
static const NSInteger kApplilinkWebAPISessionRegenerateResult = 100000000;

// Retry policy: the request is attempted at most twice before the counter is forced to the cap.
enum {
    kApplilinkWebAPIRetryCap = 2,
};

// HTTP status codes in the 4xx and 5xx server-error ranges are retried.
enum {
    kApplilinkWebAPIServerErrorStatusBase4xx = 400,
    kApplilinkWebAPIServerErrorStatusBase5xx = 500,
    kApplilinkWebAPIServerErrorStatusSpan = 100,
};

// Synchronous request timeout, in seconds.
static const float kApplilinkWebAPISynchronousTimeout = 10.0f;

// Interval, in seconds, that an asynchronous request sleeps while polling the session gate.
static const NSTimeInterval kApplilinkWebAPISessionWaitPollInterval = 0.1;

// Extra seconds added to the retry timer beyond the request's own timeout.
static const double kApplilinkWebAPIRetryTimerSlack = 2.0;

// Minimum operating-system version that supports the network-retry policy.
static const float kApplilinkWebAPIRetryMinimumOSVersion = 6.0f;

// Delay, in seconds, before the armed session gate auto-clears.
static const NSTimeInterval kApplilinkWebAPISessionConnectionWaitTimeout = 10.0;

// Session state shared by every ApplilinkWebAPI request.
//
// @ghidraAddress 0x3df698 -init sets this, +retryCancel clears it.
static BOOL g_bApplilinkWebAPIRetryActive;
// @ghidraAddress 0x3df699 +setSessionConnectionWait: sets it, +calcelSessionConnection clears it.
static BOOL g_bApplilinkWebAPISessionConnectionWait;
// @ghidraAddress 0x3df69a +setSessionStatus: sets it; gates the session-regeneration short circuit.
static BOOL g_bApplilinkWebAPISessionStatus;

@implementation ApplilinkWebAPI {
    // The binary keeps this as a plain, non-property @c int ivar without an underscore.
    int retryCount;
}

#pragma mark Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        retryCount = 0;
        g_bApplilinkWebAPIRetryActive = YES;
    }
    return self;
}

- (void)dealloc {
    // The binary defines -dealloc as a bare super chain; under ARC the runtime inserts that chain,
    // so the body is empty.
}

#pragma mark Request building

- (NSDictionary *)commonParameters {
    return @{};
}

- (NSMutableURLRequest *)requestWithURL:(NSString *)URL
                                 method:(NSString *)method
                             parameters:(NSDictionary *)parameters
                                timeout:(float)timeout
                            cachePolicy:(NSNumber *)cachePolicy {
    NSDictionary *merged = [ApplilinkUtilities joinDictionary:parameters
                                               withDictionary:[self commonParameters]];
    NSMutableURLRequest *request;
    if ([kApplilinkWebAPIPostMethod isEqualToString:method]) {
        request = [self requestForPostWithURL:URL parameters:merged];
    } else {
        request = [self requestForGetWithURL:URL parameters:merged];
    }
    [request setHTTPMethod:method];
    [request setTimeoutInterval:timeout];
    NSURLRequestCachePolicy policy = NSURLRequestReloadIgnoringLocalCacheData;
    if (cachePolicy) {
        policy = (NSURLRequestCachePolicy)cachePolicy.intValue;
    }
    [request setCachePolicy:policy];
    return request;
}

- (NSMutableURLRequest *)requestForGetWithURL:(NSString *)URL
                                   parameters:(NSDictionary *)parameters {
    NSString *urlString = [ApplilinkUtilities appendParametersToURL:URL parameters:parameters];
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
}

- (NSMutableURLRequest *)requestForPostWithURL:(NSString *)URL
                                    parameters:(NSDictionary *)parameters {
    NSMutableArray<NSString *> *pairs = [NSMutableArray array];
    for (id key in [parameters allKeys]) {
        id value = parameters[key];
        if ([value isKindOfClass:[NSArray class]]) {
            for (NSUInteger index = 0; index < [value count]; ++index) {
                [pairs addObject:[NSString stringWithFormat:kApplilinkWebAPIQueryArrayPairFormat,
                                                            key,
                                                            value[index]]];
            }
        } else {
            [pairs addObject:[NSString stringWithFormat:kApplilinkWebAPIQueryPairFormat,
                                                        key,
                                                        parameters[key]]];
        }
    }
    NSString *body = [pairs componentsJoinedByString:kApplilinkWebAPIQueryPairSeparator];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]];
    [request addValue:kApplilinkWebAPIFormURLEncodedContentType
        forHTTPHeaderField:kApplilinkWebAPIContentTypeHeaderField];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    return request;
}

#pragma mark Asynchronous transport

- (void)requestAsynchronousWithURL:(NSString *)URL
                            method:(NSString *)method
                        parameters:(NSDictionary *)parameters
                          userInfo:(id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(NSNumber *)cachePolicy
                           timeout:(float)timeout
                             retry:(BOOL)retry
                     finishedBlock:(ApplilinkWebAPIFinishedBlock)finishedBlock
                       failedBlock:(ApplilinkWebAPIFailedBlock)failedBlock {
    NSMutableURLRequest *request = [self requestWithURL:URL
                                                 method:method
                                             parameters:parameters
                                                timeout:timeout
                                            cachePolicy:cachePolicy];
    if (!retry) {
        retryCount = kApplilinkWebAPIRetryCap;
    }
    while (g_bApplilinkWebAPISessionConnectionWait) {
        [NSThread sleepForTimeInterval:kApplilinkWebAPISessionWaitPollInterval];
    }
    NSString *sessionRegenerateURL = [[ApplilinkConsts baseUrlSsl]
        stringByAppendingString:kApplilinkWebAPISessionRegeneratePath];
    if ([URL rangeOfString:sessionRegenerateURL].location != NSNotFound) {
        if (g_bApplilinkWebAPISessionStatus) {
            NSDictionary *result = @{
                kApplilinkWebAPIStatusKey : @YES,
                kApplilinkWebAPIErrorCodeKey : @(kApplilinkWebAPISessionRegenerateResult),
            };
            if (finishedBlock) {
                finishedBlock(request, result);
            }
            return;
        }
        [ApplilinkWebAPI setSessionConnectionWait:YES];
    }

    __block dispatch_source_t timerSource = nil;
    __block BOOL finished = NO;
    if (![self canUseNetworkRetry] || retry) {
        dispatch_queue_t timerQueue =
            dispatch_queue_create(kApplilinkWebAPIQueueLabel, DISPATCH_QUEUE_SERIAL);
        timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, timerQueue);
        dispatch_source_set_timer(
            timerSource,
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(timeout * NSEC_PER_SEC + kApplilinkWebAPIRetryTimerSlack)),
            DISPATCH_TIME_FOREVER,
            NSEC_PER_SEC);
        dispatch_source_set_event_handler(timerSource, ^{
          /** @ghidraAddress 0x221f9c */
          if (![self canUseNetworkRetry] || !g_bApplilinkWebAPIRetryActive) {
              retryCount = kApplilinkWebAPIRetryCap;
          }
          if (timerSource) {
              dispatch_source_cancel(timerSource);
          }
          if (finished) {
              return;
          }
          if (retryCount > 1) {
              ++retryCount;
              NSError *timeoutError = [NSError
                  errorWithDomain:NSURLErrorDomain
                             code:NSURLErrorTimedOut
                         userInfo:@{
                             NSLocalizedDescriptionKey : [ApplilinkNetworkError
                                 localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeTimeout]
                                 .localizedDescription
                         }];
              if (failedBlock) {
                  failedBlock(userInfo, timeoutError);
              }
              return;
          }
          [self requestAsynchronousWithURL:URL
                                    method:method
                                parameters:parameters
                                  userInfo:userInfo
                                       tag:tag
                               cachePolicy:cachePolicy
                                   timeout:timeout
                                     retry:retry
                             finishedBlock:finishedBlock
                               failedBlock:failedBlock];
          ++retryCount;
        });
        dispatch_source_set_cancel_handler(timerSource, ^{
          /** @ghidraAddress 0x222284 */
          timerSource = nil;
        });
        dispatch_resume(timerSource);
    }

    [NSURLConnection
        sendAsynchronousRequest:request
                          queue:[NSOperationQueue mainQueue]
              completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                /** @ghidraAddress 0x22234c */
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (retryCount > kApplilinkWebAPIRetryCap &&
                    [UIDevice currentDevice].systemVersion.floatValue <
                        kApplilinkWebAPIRetryMinimumOSVersion) {
                    return;
                }
                NSInteger status = httpResponse.statusCode;
                // The binary tests the 4xx/5xx ranges with an unsigned subtraction, so a status
                // below the range wraps large and is correctly excluded.
                BOOL isServerError =
                    ((NSUInteger)(status - kApplilinkWebAPIServerErrorStatusBase4xx) <
                     kApplilinkWebAPIServerErrorStatusSpan) ||
                    ((NSUInteger)(status - kApplilinkWebAPIServerErrorStatusBase5xx) <
                     kApplilinkWebAPIServerErrorStatusSpan);
                if (!error && !isServerError) {
                    finished = YES;
                    [self responseFromContentsServer:request
                                             request:userInfo
                                                data:data
                                       finishedBlock:finishedBlock
                                         failedBlock:failedBlock];
                    Class serialization = NSClassFromString(@"NSJSONSerialization");
                    if (!serialization) {
                        if (failedBlock) {
                            failedBlock(userInfo,
                                        [ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:
                                                kApplilinkNetworkErrorCodeContentsUnavailable]);
                        }
                        return;
                    }
                    NSError *parseError = nil;
                    id parsed = [serialization JSONObjectWithData:data
                                                          options:NSJSONReadingMutableContainers
                                                            error:&parseError];
                    if (!parseError) {
                        if (![parsed isKindOfClass:[NSDictionary class]]) {
                            if (failedBlock) {
                                failedBlock(userInfo,
                                            [ApplilinkNetworkError
                                                localizedApplilinkErrorWithCode:
                                                    kApplilinkNetworkErrorCodeContentsMalformed]);
                            }
                            return;
                        }
                        if (finishedBlock) {
                            finishedBlock(userInfo, parsed);
                        }
                    } else if (failedBlock) {
                        failedBlock(userInfo, parseError);
                    }
                    return;
                }
                if (error.code == NSURLErrorTimedOut) {
                    if ([UIDevice currentDevice].systemVersion.floatValue >=
                            kApplilinkWebAPIRetryMinimumOSVersion &&
                        !retry) {
                        NSError *timeoutError =
                            [NSError errorWithDomain:NSURLErrorDomain
                                                code:NSURLErrorTimedOut
                                            userInfo:@{
                                                NSLocalizedDescriptionKey : [ApplilinkNetworkError
                                                    localizedApplilinkErrorWithCode:
                                                        kApplilinkNetworkErrorCodeTimeout]
                                                    .localizedDescription
                                            }];
                        if (failedBlock) {
                            failedBlock(userInfo, timeoutError);
                        }
                    }
                    return;
                }
                finished = YES;
                NSError *reportedError = error;
                if (!reportedError) {
                    reportedError = [ApplilinkNetworkError
                        localizedApplilinkErrorWithCode:
                            kApplilinkNetworkErrorCodeContentsUnavailable
                                               userInfo:@{
                                                   kApplilinkWebAPIStatusKey : [NSString
                                                       stringWithFormat:
                                                           kApplilinkWebAPIStatusCodeFormat,
                                                           (long)status]
                                               }];
                }
                if (failedBlock) {
                    failedBlock(userInfo, reportedError);
                }
              }];
}

#pragma mark Synchronous transport

- (id)requestSynchronousWithURL:(NSString *)URL
                         method:(NSString *)method
                     parameters:(NSDictionary *)parameters
                    cachePolicy:(NSNumber *)cachePolicy
                          error:(NSError **)error {
    NSMutableURLRequest *request = [self requestWithURL:URL
                                                 method:method
                                             parameters:parameters
                                                timeout:kApplilinkWebAPISynchronousTimeout
                                            cachePolicy:cachePolicy];
    retryCount = 0;
    NSData *data = nil;
    NSHTTPURLResponse *response = nil;
    for (;;) {
        response = nil;
        NSError *connectionError = nil;
        data = [NSURLConnection sendSynchronousRequest:request
                                     returningResponse:&response
                                                 error:&connectionError];
        NSInteger status = response.statusCode;
        // The binary tests the 4xx/5xx ranges with an unsigned subtraction, so a status below the
        // range wraps large and is correctly excluded.
        BOOL isServerError = ((NSUInteger)(status - kApplilinkWebAPIServerErrorStatusBase4xx) <
                              kApplilinkWebAPIServerErrorStatusSpan) ||
                             ((NSUInteger)(status - kApplilinkWebAPIServerErrorStatusBase5xx) <
                              kApplilinkWebAPIServerErrorStatusSpan);
        if (!connectionError && !isServerError) {
            if (!data) {
                if (!error) {
                    return nil;
                }
                *error = [ApplilinkNetworkError
                    localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeConnectionFailed];
                return nil;
            }
            break;
        }
        if (retryCount > 1 || connectionError.code != NSURLErrorTimedOut) {
            if (!error) {
                return nil;
            }
            *error = connectionError;
            return nil;
        }
        [NSThread sleepForTimeInterval:(NSTimeInterval)(retryCount * 2 + 2)];
        int attempted = retryCount;
        retryCount = attempted + 1;
        if (attempted >= kApplilinkWebAPIRetryCap) {
            break;
        }
    }

    Class serialization = NSClassFromString(@"NSJSONSerialization");
    if (!serialization) {
        if (error) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeJSONUnavailable];
        }
        return nil;
    }
    NSError *parseError = nil;
    id parsed = [serialization JSONObjectWithData:data
                                          options:NSJSONReadingMutableContainers
                                            error:&parseError];
    if (!parseError) {
        if (parsed) {
            return parsed;
        }
        if (error) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeMalformedJSON];
        }
    } else if (error) {
        *error = parseError;
    }
    return nil;
}

#pragma mark Contents-server transport

- (id)responseFromContentsServer:(id)response
                         request:(id)request
                            data:(NSData *)data
                   finishedBlock:(ApplilinkWebAPIFinishedBlock)finishedBlock
                     failedBlock:(ApplilinkWebAPIFailedBlock)failedBlock {
    NSString *appliURL =
        [[NSUserDefaults standardUserDefaults] objectForKey:kApplilinkWebAPIRewardAppliURLKey];
    if (![response isEqualToString:appliURL]) {
        return response;
    }
    if (data.length == 0) {
        NSError *connectionError = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeConnectionFailed];
        if (failedBlock) {
            failedBlock(request, connectionError);
        }
        return response;
    }

    // The body is line-delimited: line 0 carries the status field and is captured into
    // @c firstLine, and every later line is appended into the accumulator string.
    __block int lineIndex = 0;
    __block NSString *firstLine = nil;
    NSMutableString *accumulator = [[NSMutableString alloc] init];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
      /** @ghidraAddress 0x222dcc */
      if (lineIndex != 0) {
          [accumulator appendString:line];
      } else {
          firstLine = [[NSString alloc] initWithString:line];
      }
      ++lineIndex;
    }];

    if ([firstLine isEqualToString:kApplilinkWebAPIContentsStatusOK]) {
        id result = [accumulator dataUsingEncoding:NSUTF8StringEncoding];
        if (finishedBlock) {
            finishedBlock(request, result);
        }
        return response;
    }
    NSDictionary *userInfo = @{kApplilinkWebAPIResponseKey : firstLine};
    NSInteger code = [firstLine isEqualToString:kApplilinkWebAPIContentsStatusMalformed] ?
                         kApplilinkNetworkErrorCodeContentsMalformed :
                         kApplilinkNetworkErrorCodeContentsUnavailable;
    NSError *bodyError = [ApplilinkNetworkError localizedApplilinkErrorWithCode:code
                                                                       userInfo:userInfo];
    if (failedBlock) {
        failedBlock(request, bodyError);
    }
    return response;
}

#pragma mark Capability

- (BOOL)canUseNetworkRetry {
    return
        [UIDevice currentDevice].systemVersion.floatValue >= kApplilinkWebAPIRetryMinimumOSVersion;
}

#pragma mark Class factories

+ (void)requestAsynchronousWithURL:(NSString *)URL
                            method:(NSString *)method
                        parameters:(NSDictionary *)parameters
                          userInfo:(id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(NSNumber *)cachePolicy
                           timeout:(float)timeout
                             retry:(BOOL)retry
                     finishedBlock:(ApplilinkWebAPIFinishedBlock)finishedBlock
                       failedBlock:(ApplilinkWebAPIFailedBlock)failedBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0x2234d0 */
      [[[ApplilinkWebAPI alloc] init] requestAsynchronousWithURL:URL
                                                          method:method
                                                      parameters:parameters
                                                        userInfo:userInfo
                                                             tag:tag
                                                     cachePolicy:cachePolicy
                                                         timeout:timeout
                                                           retry:retry
                                                   finishedBlock:finishedBlock
                                                     failedBlock:failedBlock];
    });
}

+ (id)requestSynchronousWithURL:(NSString *)URL
                         method:(NSString *)method
                     parameters:(NSDictionary *)parameters
                    cachePolicy:(NSNumber *)cachePolicy
                          error:(NSError **)error {
    return [[[ApplilinkWebAPI alloc] init] requestSynchronousWithURL:URL
                                                              method:method
                                                          parameters:parameters
                                                         cachePolicy:cachePolicy
                                                               error:error];
}

+ (id)responseFromContentsServer:(id)response
                         request:(id)request
                            data:(NSData *)data
                   finishedBlock:(ApplilinkWebAPIFinishedBlock)finishedBlock
                     failedBlock:(ApplilinkWebAPIFailedBlock)failedBlock {
    return [[[ApplilinkWebAPI alloc] init] responseFromContentsServer:response
                                                              request:request
                                                                 data:data
                                                        finishedBlock:finishedBlock
                                                          failedBlock:failedBlock];
}

#pragma mark Session and retry control

+ (void)retryCancel {
    g_bApplilinkWebAPIRetryActive = NO;
}

+ (void)setSessionConnectionWait:(BOOL)sessionConnectionWait {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    g_bApplilinkWebAPISessionConnectionWait = sessionConnectionWait;
    if (sessionConnectionWait) {
        [self performSelector:@selector(calcelSessionConnection)
                   withObject:nil
                   afterDelay:kApplilinkWebAPISessionConnectionWaitTimeout];
    }
}

+ (void)calcelSessionConnection {
    g_bApplilinkWebAPISessionConnectionWait = NO;
}

+ (void)setSessionStatus:(BOOL)sessionStatus {
    g_bApplilinkWebAPISessionStatus = sessionStatus;
}

@end
