//
//  ImageDownloader.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ImageDownloader). Verified against
//  the arm64 disassembly: the completion handlers are reconstructed from the captured block layout
//  (each block calls the connection's -getData), and the screen-scale comparisons travel the
//  soft-float path that the decompiler renders through an extra register.
//

#import "ImageDownloader.h"

// The HTTP connection primitive this downloader drives. Its header is already reconstructed in this
// tree.
#import "RBHttpUtil.h"

// The HTTP method used for every image request.
static NSString *const kImageRequestHTTPMethod = @"GET";

// The format that inserts the "@2x" Retina marker between an image URL's base and its extension,
// producing "<base>@2x.<ext>".
static NSString *const kRetinaImageURLFormat = @"%@@2x.%@";

// The screen scale at or below which an image is treated as plain (non-Retina) resolution.
static const CGFloat kNonRetinaScreenScale = 1.0;

// The image orientation used when rebuilding a Retina image from its backing @c CGImage.
static const UIImageOrientation kRetinaImageOrientation = UIImageOrientationUp;

@interface ImageDownloader ()

- (void)startDownloadRetina;
- (void)startDownloadNonRetina;
- (void)setImage:(nullable NSData *)image;
- (void)proceed;
- (void)success;
- (void)failure;

@end

@implementation ImageDownloader

#pragma mark - Initialisation

- (instancetype)initWithGetURL:(NSString *)getURL unUseRetina:(BOOL)unUseRetina {
    /** @ghidraAddress 0x83d30 */
    self = [super init];
    if (self) {
        self.unUseRetina = unUseRetina;
        self.imageURL = getURL;
    }
    return self;
}

#pragma mark - Starting a download

- (void)startDownloadWithProceed:(ImageDownloaderBlock)proceed
                         success:(ImageDownloaderBlock)success
                         failure:(ImageDownloaderBlock)failure {
    /** @ghidraAddress 0x83eb0 */
    self.proceedBlock = proceed;
    self.successBlock = success;
    self.failureBlock = failure;
    [self startDownload];
}

- (void)startDownload {
    /** @ghidraAddress 0x83dc8 */
    UIScreen *mainScreen = [UIScreen mainScreen];
    if ([mainScreen respondsToSelector:@selector(scale)] &&
        mainScreen.scale != kNonRetinaScreenScale && !self.unUseRetina) {
        [self startDownloadRetina];
    } else {
        [self startDownloadNonRetina];
    }
}

- (void)startDownloadRetina {
    /** @ghidraAddress 0x83f6c */
    __weak ImageDownloader *weakSelf = self;
    if (self.conn) {
        [weakSelf.conn cancel];
        weakSelf.conn = nil;
    }
    weakSelf.conn = [[RBHttpUtil alloc] init];
    NSString *retinaURL = [NSString stringWithFormat:kRetinaImageURLFormat,
                                                     [self.imageURL stringByDeletingPathExtension],
                                                     [self.imageURL pathExtension]];
    [weakSelf.conn updateRequest:[NSURL URLWithString:retinaURL]
                      HTTPMethod:kImageRequestHTTPMethod
                     contentType:nil
                        sendData:nil
                        filePath:nil];
    [weakSelf.conn startDownloadingWithProceed:nil
        success:^(RBHttpUtil *connection) {
          /** @ghidraAddress 0x8431c */
          // On a decoded body, keep the image and report success; on an empty body, retry at 1x.
          if ([connection getData] == nil) {
              [weakSelf startDownloadNonRetina];
          } else {
              [weakSelf setImage:[connection getData]];
              if (weakSelf.downloadedImage != nil) {
                  [weakSelf success];
              }
          }
        }
        failure:^(RBHttpUtil *connection) {
          /** @ghidraAddress 0x84448 */
          [weakSelf startDownloadNonRetina];
        }];
}

- (void)startDownloadNonRetina {
    /** @ghidraAddress 0x84490 */
    __weak ImageDownloader *weakSelf = self;
    if (self.conn) {
        [weakSelf.conn cancel];
        weakSelf.conn = nil;
    }
    weakSelf.conn = [[RBHttpUtil alloc] init];
    [weakSelf.conn updateRequest:[NSURL URLWithString:self.imageURL]
                      HTTPMethod:kImageRequestHTTPMethod
                     contentType:nil
                        sendData:nil
                        filePath:nil];
    [weakSelf.conn startDownloadingWithProceed:nil
        success:^(RBHttpUtil *connection) {
          /** @ghidraAddress 0x8478c */
          // On a decoded body, keep the image and report success; on an empty body, report failure.
          if ([connection getData] == nil) {
              [weakSelf failure];
          } else {
              [weakSelf setImage:[connection getData]];
              if (weakSelf.downloadedImage != nil) {
                  [weakSelf success];
              }
          }
        }
        failure:^(RBHttpUtil *connection) {
          /** @ghidraAddress 0x848b8 */
          [weakSelf failure];
        }];
}

#pragma mark - Image decoding

- (void)setImage:(NSData *)image {
    /** @ghidraAddress 0x849cc */
    UIImage *decoded = [[UIImage alloc] initWithData:image];
    if (decoded == nil) {
        return;
    }
    if ([UIScreen mainScreen].scale <= kNonRetinaScreenScale) {
        self.downloadedImage = decoded;
    } else {
        self.downloadedImage = [UIImage imageWithCGImage:decoded.CGImage
                                                   scale:[UIScreen mainScreen].scale
                                             orientation:kRetinaImageOrientation];
    }
}

- (UIImage *)getImage {
    /** @ghidraAddress 0x84b3c */
    return self.downloadedImage;
}

#pragma mark - Cancellation

- (void)cancelDownload {
    /** @ghidraAddress 0x84900 */
    self.delegate = nil;
    self.downloadedImage = nil;
    [self.imageTask cancel];
    self.imageTask = nil;
    [self.imageTaskRetina cancel];
    self.imageTaskRetina = nil;
}

#pragma mark - Completion dispatch

- (void)proceed {
    /** @ghidraAddress 0x84b48 */
    __weak ImageDownloader *weakSelf = self;
    if (self.proceedBlock == nil) {
        if (weakSelf.delegate == nil) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x84d34 */
          // The binary dispatches the failure selector here; the quirk is preserved.
          [weakSelf.delegate performSelector:@selector(imageDownloaderDidFail:didLoad:)
                                  withObject:weakSelf
                                  withObject:weakSelf.indexPathInTableView];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x84ca8 */
          weakSelf.proceedBlock(weakSelf);
        });
    }
}

- (void)success {
    /** @ghidraAddress 0x84e0c */
    __weak ImageDownloader *weakSelf = self;
    if (self.successBlock == nil) {
        if (weakSelf.delegate == nil) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x84ff8 */
          [weakSelf.delegate performSelector:@selector(imageDownloader:didLoad:)
                                  withObject:weakSelf
                                  withObject:weakSelf.indexPathInTableView];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x84f6c */
          weakSelf.successBlock(weakSelf);
        });
    }
}

- (void)failure {
    /** @ghidraAddress 0x850d0 */
    __weak ImageDownloader *weakSelf = self;
    if (self.failureBlock == nil) {
        if (weakSelf.delegate == nil) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x852bc */
          [weakSelf.delegate performSelector:@selector(imageDownloaderDidFail:didLoad:)
                                  withObject:weakSelf
                                  withObject:weakSelf.indexPathInTableView];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x85230 */
          weakSelf.failureBlock(weakSelf);
        });
    }
}

#pragma mark - Deallocation

- (void)dealloc {
    /** @ghidraAddress 0x85394 */
    self.imageURL = nil;
    [self.imageTask cancel];
    self.imageTask = nil;
    [self.imageTaskRetina cancel];
    self.imageTaskRetina = nil;
    self.downloadedImage = nil;
    self.indexPathInTableView = nil;
    self.proceedBlock = nil;
    self.successBlock = nil;
    self.failureBlock = nil;
    self.delegate = nil;
}

@end
