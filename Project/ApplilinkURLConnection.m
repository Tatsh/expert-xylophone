#import "ApplilinkURLConnection.h"

@implementation ApplilinkURLConnection

#pragma mark Request

- (void)loadRequestWithRequest:(NSURLRequest *)request
                      delegate:(id<ApplilinkURLConnectionDelegate>)delegate {
    self.connectionDelegate = delegate;
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (connection) {
        self.receivedData = [NSMutableData data];
    }
}

#pragma mark NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.responseData = response;
    [self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.receivedData = nil;
    id<ApplilinkURLConnectionDelegate> delegate = self.connectionDelegate;
    if (delegate && [delegate respondsToSelector:@selector(failLoadWithError:)]) {
        [delegate failLoadWithError:error];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *response = [[NSString alloc] initWithData:self.receivedData
                                               encoding:NSUTF8StringEncoding];
    self.receivedData = nil;
    self.responseData = nil;
    id<ApplilinkURLConnectionDelegate> delegate = self.connectionDelegate;
    if (delegate && [delegate respondsToSelector:@selector(finishLoadWithResponse:)]) {
        [delegate finishLoadWithResponse:response];
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)redirectResponse {
    id<ApplilinkURLConnectionDelegate> delegate = self.connectionDelegate;
    if (delegate && [delegate respondsToSelector:@selector(redirectStartLoad:)] &&
        [delegate redirectStartLoad:request]) {
        if ([delegate respondsToSelector:@selector(finishLoadWithResponse:)]) {
            [delegate finishLoadWithResponse:nil];
        }
        // Returning nil cancels the redirect so the intercepted load stops here.
        request = nil;
    }
    return request;
}

@end
