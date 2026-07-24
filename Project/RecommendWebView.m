#import "RecommendWebView.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "RecommendAdAreaView.h"
#import "RecommendAdCache.h"
#import "RecommendAdData.h"
#import "RecommendAdWebView.h"
#import "RecommendCore.h"

// The activity indicator is a square of this side, and is auto-hidden after this many seconds. The
// container only shows the indicator when both frame dimensions are at least this large.
static const CGFloat kRecommendIndicatorSize = 60.0;

// Advert-model identifiers whose content is served from a locally cached HTML file rather than a
// live web request.
enum {
    kRecommendCachedAdModelFive = 5,
    kRecommendCachedAdModelLower = 100,
    kRecommendCachedAdModelUpper = 101,
};

// Applilink error codes reported through the delegate when the advert cannot be loaded.
enum {
    kApplilinkErrorNotInitialised = 0x3f2,
    kApplilinkErrorCachedFileMissing = 0x40b,
};

@implementation RecommendWebView

/** @ghidraAddress 0x2453c8 */
- (instancetype)init {
    self = [super init];
    if (self) {
        [self setInitParam];
    }
    return self;
}

/** @ghidraAddress 0x24542c */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setInitParam];
    }
    return self;
}

/** @ghidraAddress 0x245490 */
- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setInitParam];
    }
    return self;
}

- (void)setInitParam {
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                            UIViewAutoresizingFlexibleRightMargin |
                            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight |
                            UIViewAutoresizingFlexibleBottomMargin;
    self.contentMode = UIViewContentModeScaleToFill;
}

#pragma mark - Loading

- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(id)requestCode
                      delegate:(id<ApplilinkViewDelegate>)delegate {
    self.applilinkParams = [[ApplilinkParameters alloc] init];
    [self.applilinkParams setRequestWithAdModel:adModel
                                     adLocation:adLocation
                                    requestCode:requestCode];
    [self loadRequestWithAdModel:adModel
                      adLocation:adLocation
                   verticalAlign:verticalAlign
                        delegate:delegate];
}

- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                      delegate:(id<ApplilinkViewDelegate>)delegate {
    if (!self.applilinkParams) {
        self.applilinkParams = [[ApplilinkParameters alloc] init];
        [self.applilinkParams setRequestWithAdModel:adModel adLocation:adLocation requestCode:nil];
    }
    if (![ApplilinkConsts checkUseSDKWithAdModel:adModel
                                      adLocation:adLocation
                                   verticalAlign:verticalAlign
                                     requestCode:self.applilinkParams.requestCode
                                        delegate:delegate]) {
        return;
    }
    if ([RecommendCore sharedInstance].initializeFlg == 0 &&
        ![ApplilinkCore isInitializeStatusFlg]) {
        NSError *error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorNotInitialised];
        [ApplilinkCore toDelegateFailLoadWithError:error
                                          appParam:self.applilinkParams
                                          delegate:delegate];
        return;
    }
    // Advert models 5 and 100..101 are served from a locally cached HTML file; every other model is
    // loaded live on the main queue.
    if ((adModel != kRecommendCachedAdModelFive) &&
        (adModel < kRecommendCachedAdModelLower || adModel > kRecommendCachedAdModelUpper)) {
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x245c84 */
          if (!self.webView) {
              CGRect webFrame = self.frame;
              self.webView = [[RecommendAdWebView alloc]
                  initWithFrame:CGRectMake(0, 0, webFrame.size.width, webFrame.size.height)];
              [self addSubview:self.webView];
          }
          CGRect frame = self.frame;
          if (!self.indicator && frame.size.width >= kRecommendIndicatorSize &&
              frame.size.height >= kRecommendIndicatorSize) {
              self.indicator = [[UIActivityIndicatorView alloc]
                  initWithFrame:CGRectMake((frame.size.width - kRecommendIndicatorSize) * 0.5,
                                           (frame.size.height - kRecommendIndicatorSize) * 0.5,
                                           kRecommendIndicatorSize,
                                           kRecommendIndicatorSize)];
              self.indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
              self.indicator.autoresizingMask =
                  UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                  UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                  UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
              if ([self.indicator respondsToSelector:@selector(setColor:)]) {
                  self.indicator.color = [ApplilinkCore getIndicatorColor];
              }
              [self addSubview:self.indicator];
              [self.indicator startAnimating];
              [self performSelector:@selector(hiddenIndicator)
                         withObject:nil
                         afterDelay:kRecommendIndicatorSize];
          }
          [self.webView setScrollEnabled:self.webViewBounces];
          self.applilinkDelegate = delegate;
          [self.webView loadRequestWithAdModel:adModel
                                    adLocation:adLocation
                                 verticalAlign:verticalAlign
                                   requestCode:self.applilinkParams.requestCode
                                      delegate:self];
        });
        return;
    }
    NSError *createError = [RecommendAdCache createHtmlWithAdModel:adModel
                                                        adLocation:adLocation
                                                     verticalAlign:verticalAlign];
    if (createError) {
        [ApplilinkCore toDelegateFailLoadWithError:createError
                                          appParam:self.applilinkParams
                                          delegate:delegate];
        return;
    }
    NSString *fileName = [NSString stringWithFormat:@"%d_%@.html", adModel, adLocation];
    NSString *path = [[RecommendAdCache getContentsPath] stringByAppendingPathComponent:fileName];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        NSError *missingError = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorCachedFileMissing];
        [ApplilinkCore toDelegateFailLoadWithError:missingError
                                          appParam:self.applilinkParams
                                          delegate:delegate];
        return;
    }
    self.applilinkDelegate = delegate;
    CGRect frame = self.frame;
    int adType = [RecommendAdData getAdTypeWithAdModel:adModel adLocation:adLocation];
    if (!self.adAreaWebView) {
        self.adAreaWebView = [[RecommendAdAreaView alloc] init];
    }
    self.adAreaWebView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    [self.adAreaWebView setAdModel:adModel
                        adLocation:adLocation
                            adType:adType
                       requestCode:self.applilinkParams.requestCode
                          delegate:delegate];
    [self.adAreaWebView startPath:path];
    [self addSubview:self.adAreaWebView];
    [self appListDidStart];
}

- (void)setScrollEnabled:(BOOL)scrollEnabled {
    self.webViewBounces = scrollEnabled;
    if (self.webView) {
        [self.webView setScrollEnabled:self.webViewBounces];
    }
}

#pragma mark - Teardown

/** @ghidraAddress 0x245598 */
- (void)removeFromSuperview {
    [self closeAdArea];
    [super removeFromSuperview];
}

- (void)hiddenIndicator {
    if (self.indicator) {
        [self.indicator stopAnimating];
    }
    [RecommendWebView cancelPreviousPerformRequestsWithTarget:self];
}

- (void)closeAdArea {
    if (self.webView) {
        [self.webView closeAdArea];
        [self.webView removeFromSuperview];
        self.webView = nil;
    }
    if (self.adAreaWebView) {
        [self.adAreaWebView closeAdArea];
        [self.adAreaWebView removeFromSuperview];
        self.adAreaWebView = nil;
    }
}

/** @ghidraAddress 0x246500 */
- (void)dealloc {
    self.applilinkDelegate = nil;
    self.applilinkParams = nil;
    if (self.indicator) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    self.indicator = nil;
    if (self.webView) {
        [self.webView removeFromSuperview];
    }
    self.webView = nil;
    if (self.adAreaWebView) {
        [self.adAreaWebView removeFromSuperview];
    }
    self.adAreaWebView = nil;
}

#pragma mark - ApplilinkViewDelegate

- (void)appListDidStart {
    [ApplilinkCore toDelegateDidStart:self.applilinkParams delegate:self.applilinkDelegate];
}

- (void)appListDidAppear {
    if (self.indicator) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    self.indicator = nil;
    [RecommendWebView cancelPreviousPerformRequestsWithTarget:self];
    [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:self.applilinkDelegate];
}

- (void)appListDidDisappear {
    if (self.indicator) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    self.indicator = nil;
    [self.webView removeFromSuperview];
    self.webView = nil;
    [ApplilinkCore toDelegateDidDisappear:self.applilinkParams delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
}

- (void)appListFailLoadWithError:(NSError *)error {
    if (self.indicator) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    self.indicator = nil;
    [self.webView removeFromSuperview];
    self.webView = nil;
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
}

- (void)appListFailLinkWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
}

@end
