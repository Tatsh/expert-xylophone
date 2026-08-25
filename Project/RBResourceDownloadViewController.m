//
//  RBResourceDownloadViewController.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBResourceDownloadViewController).
//  Verified against the arm64 disassembly: the server-response block bodies dispatch their UI work
//  through the block invoke pointer, and the download/unzip progress is reported through
//  performSelectorOnMainThread:.
//

#import "RBResourceDownloadViewController.h"

#import "AppDelegate.h"
#import "Downloader.h"
#import "NSFileManager+RB.h"
#import "NetworkUtil.h"
#import "RBBGMManager.h"
#import "RBCampaignData.h"
#import "RBResoureDownloadBGEffectView.h"
#import "RBUserSettingData.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"

// Server response keys.
static NSString *const kResponseKeyError = @"Error";
static NSString *const kResponseKeyVersion = @"Version";
static NSString *const kResponseKeyItemURL = @"ItemURL";
static NSString *const kResponseKeyTime = @"Time";
static NSString *const kResponseKeyApp = @"App";
static NSString *const kResponseKeyUserID = @"UserID";
static NSString *const kResponseKeyPasswd = @"Passwd";
static NSString *const kResponseKeyCol = @"Col";

// Request parameter keys.
static NSString *const kRequestKeyTarget = @"target";
static NSString *const kRequestKeyVersion = @"version";
static NSString *const kRequestKeyUserID = @"user_id";
static NSString *const kRequestKeyPasswd = @"passwd";
static NSString *const kRequestKeyUUID = @"uuid";

// Download-descriptor keys.
static NSString *const kFileInfoKeyDownloadPath = @"downloadPath";
static NSString *const kFileInfoKeyDocumentPath = @"documentPath";
static NSString *const kFileInfoKeyFileName = @"fileName";
static NSString *const kFileInfoKeyTargetPath = @"targetPath";
static NSString *const kFileInfoKeyPassword = @"password";

// The archive password shared by the asset archive and the manifest archive.
static NSString *const kArchivePassword = @"mt972";
// The empty-credential placeholder sent when no cached server identity exists.
static NSString *const kEmptyCredential = @"";

// Asset-manifest suffixes appended to the image-asset directory path.
static NSString *const kManifestArchiveSuffix = @"/list";
static NSString *const kManifestListSuffix = @"/lists";
static NSString *const kPathSeparator = @"/";
static NSString *const kManifestLineSeparator = @"\n";

// Help-carousel artwork names.
static NSString *const kBackgroundImageName = @"dl_bg";
static NSString *const kInfoImageName = @"dl_info";
static NSString *const kHelpBackgroundImageName = @"how_bg";
static NSString *const kGradientImageName = @"set_grad";
static NSString *const kHelpBarImageName = @"how_bar";
// The six help-page artwork names, indexed by page.
static NSString *const kHelpPageImageNames[] = {
    @"how_1", @"how_2", @"how_3", @"how_4", @"how_5", @"how_6"};

// The tag the update-required alert carries so its button handling can be told apart.
enum { kUpdateRequiredAlertTag = 3 };

// Which phase drives the progress fill.
enum {
    kProgressModeDownload = 0,
    kProgressModeUnzip = 1,
    kProgressModeVerify = 2,
};

// The number of help pages in the carousel.
enum { kHelpPageCount = 6 };

// The background-music type played for the resource-download flow.
enum { kResourceDownloadBgmType = 15 };

// The resource-download background-music start volume, and the fade timings. The volume is a
// 4-byte ldr s0, so it really is a float32; the duration is an fmov immediate and so has no pool
// address to cite.
static const float kResourceDownloadBgmVolume = 0.3f; // @ghidraAddress 0x2ee910
static const NSTimeInterval kFadeOutDuration = 1.0;

// The progress-fill scale factors for the download and unzip phases.
static const CGFloat kDownloadProgressScale = 0.5;
static const CGFloat kUnzipProgressScale = 0.5;

// The interface-orientation masks this flow permits, by device idiom. The iPad (wide) layout is
// locked to the two portrait orientations (mask value 6); every other device allows all four.
enum {
    kOrientationMaskWideVariant =
        UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown,
    kOrientationMaskDefault = UIInterfaceOrientationMaskAll,
};

// Help-carousel and pastel-container canvas sizes, by device idiom, and the inter-container gutter.
static const CGFloat kHelpCanvasSize = 320;
// The wide help canvas is taller than it is wide: the initWithFrame: at 0x1cdf4 is handed 544 as
// its width and 670 as its height.
static const CGFloat kWideHelpCanvasWidth = 544;
static const CGFloat kWideHelpCanvasHeight = 670;
// @ghidraAddress 0x2ee970
static const CGFloat kWidePastelCanvasHeight = 180;
// The standard variant's pastel container is a 90-point square, not a second 320 canvas: the
// initWithFrame: at 0x1cf1c takes 90 for both width and height. The meter subviews reach only
// 85 by 81.5 points, and because -updateLayout reads this size back, a 320 square pushed the help
// panel off the top of the screen. @ghidraAddress 0x2ee920
static const CGFloat kPastelCanvasSize = 90;
static const CGFloat kLayoutGap = 20;

// Completion-animation constants.
static const CGFloat kPopFadeInAlpha = 0.0;
static const CGFloat kPopPopScale = 0.1;
static const CGFloat kPopTranslateXFactor = 0.125;
static const CGFloat kPopTranslateYDivisor = 3.0;
static const NSTimeInterval kPopAnimationDuration = 2.0;
// The delay before the pop animation retries, in nanoseconds (2 seconds).
static const int64_t kAnimationRetryDelayNanos = 2000000000;

@interface RBResourceDownloadViewController () {
    // Private ivars with no accessor: the pop-animation guard flag and the help-page count. Their
    // binary names are preserved.
    BOOL m_Animating; // +0x8
    int m_PageNum;    // +0xc
}
@end

@implementation RBResourceDownloadViewController

#pragma mark - Rotation

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return !IsPad() ? kOrientationMaskDefault : kOrientationMaskWideVariant;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return self.interfaceOrientation;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // All six flags: the binary sends setAutoresizingMask:0x3f, not the width-and-height pair.
    self.view.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self setupView];
    [[RBBGMManager getInstance] LoadMusicType:kResourceDownloadBgmType Loop:YES];
    [[RBBGMManager getInstance] PlayMusic:kResourceDownloadBgmVolume];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.nextAnimation = YES;

    __weak UIImageView *weakFadeImageView = self.fadeImageView;
    __weak RBResourceDownloadViewController *weakSelf = self;
    [UIView animateWithDuration:kFadeOutDuration
        animations:^{
          /** @ghidraAddress 0x1a478 */
          weakFadeImageView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1a4d8 */
          [weakSelf animation];
          [weakSelf download];
        }];
    [self.bgEffectView startAnimation];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.dataTask) {
        [self.dataTask cancel];
        self.dataTask = nil;
    }
    if (self.downloadTask) {
        [self.downloadTask cancel];
        self.downloadTask = nil;
    }
    self.scrollView.delegate = nil;
    for (UIImageView *subview in self.scrollView.subviews) {
        subview.image = nil;
    }
    [self.bgEffectView stopAnimation];
    self.popImageView.image = nil;
    self.pastelImageView.image = nil;
    self.trackImageView.image = nil;
    self.progressImageView.image = nil;
    self.scrollBGView.image = nil;
    self.gradView.image = nil;
    self.fadeImageView.image = nil;
    [[AppDelegate appDelegate] performSelectorOnMainThread:@selector(showTitle)
                                                withObject:nil
                                             waitUntilDone:NO];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self updateLayout];
}

- (void)dealloc {
    // The binary's -dealloc only chains to super, which ARC performs automatically.
}

#pragma mark - Version request

- (void)request {
    NSArray *serverData = [AppDelegate getServerData];
#ifdef ENABLE_PATCHES
    // The identity, not the list key. See RBDeviceIdentityUUID.
    NSString *deviceUUID = RBDeviceIdentityUUID();
#else
    NSString *deviceUUID = [AppDelegate musicListKey];
#endif
    NSDictionary *params;
    if (serverData == nil) {
        params = @{
            kRequestKeyTarget : GetRegionCode(),
            kRequestKeyVersion : GetBundleVersionString(),
            kRequestKeyUserID : kEmptyCredential,
            kRequestKeyPasswd : kEmptyCredential,
            kRequestKeyUUID : deviceUUID
        };
    } else {
        params = @{
            kRequestKeyTarget : GetRegionCode(),
            kRequestKeyVersion : GetBundleVersionString(),
            kRequestKeyUserID : serverData[0],
            kRequestKeyPasswd : serverData[1],
            kRequestKeyUUID : deviceUUID
        };
    }
    NSData *body = [Downloader dictionaryToJsonData:params];

    if (self.downloader) {
        [self.downloader cancel];
        self.downloader = nil;
    }
    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil resourceURL]
                                                 post:body
                                          contentType:nil];

    __weak RBResourceDownloadViewController *weakSelf = self;
    [self.downloader
        startDownloadingWithProceed:^(Downloader *downloader) {
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x1b0c8 */
          NSDictionary *json = [downloader getDataInJSON];
          if (json[kResponseKeyError]) {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x1b680 */
                [UIAlertView showNetworkErrorWithDelegate:weakSelf];
              });
              return;
          }
          weakSelf.version = json[kResponseKeyVersion];
          weakSelf.downloadPath = json[kResponseKeyItemURL];
          [AppDelegate appDelegate].serverTime = json[kResponseKeyTime];

          // "App" carries the minimum required application version; "UserID"/"Passwd" carry the
          // refreshed server credentials.
          NSString *requiredAppVersion = json[kResponseKeyApp];
          id userID = json[kResponseKeyUserID];
          id passwd = json[kResponseKeyPasswd];

          // Show the credential-error alert only when the returned identity is internally
          // inconsistent. The binary expresses this as a short-circuit followed by an obfuscated
          // boolean; it is reproduced here branch for branch.
          BOOL hasPasswd = passwd != nil;
          BOOL hasUserID = userID != nil;
          BOOL hasServerData = serverData != nil;
          BOOL credentialsAccepted = (!hasPasswd && !hasUserID && hasServerData);
          if (!credentialsAccepted) {
              BOOL missingServerData = !hasServerData;
              BOOL bothPresent = hasPasswd ? hasUserID : NO;
              if (!bothPresent) {
                  BOOL both = hasPasswd && (hasUserID && missingServerData);
                  if (missingServerData ^ both) {
                      dispatch_async(dispatch_get_main_queue(), ^{
                        /** @ghidraAddress 0x1b6f8 */
                        [UIAlertView showNetworkErrorWithDelegate:weakSelf];
                      });
                      return;
                  }
              }
          }
          [AppDelegate setServerData:userID andB:passwd];
          RebuildDeviceDescriptionString();

          id campaign = json[kResponseKeyCol];
          if (campaign) {
              [[RBCampaignData sharedInstance] parseDictionary:campaign];
          }

          if (![AppDelegate appDelegate].isSkipUpdate &&
              [GetBundleVersionString() compare:requiredAppVersion
                                        options:NSNumericSearch] == NSOrderedAscending) {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x1b770 */
                [UIAlertView showAlertLatestApplication:weakSelf];
              });
              return;
          }
          if (weakSelf.downloadPath) {
              [weakSelf download];
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x1b7b4 */
                [UIAlertView showNetworkErrorWithDelegate:weakSelf];
              });
          }
        }
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0x1b890 */
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x1b908 */
            [UIAlertView showNetworkErrorWithDelegate:weakSelf];
          });
        }];
}

- (void)download {
    if (self.downloadPath) {
        [self downloadWithURLString:self.downloadPath];
    } else {
        [self request];
    }
}

#pragma mark - Archive download

- (void)downloadWithURLString:(NSString *)urlString {
    NSString *fileName = urlString.lastPathComponent;
    NSString *documentPath = GetDownloadDirectoryPath();
    NSString *targetPath = [GetImageAssetDirectoryPath() stringByDeletingLastPathComponent];
    NSString *downloadFilePath = [documentPath stringByAppendingPathComponent:fileName];

    self.fileInfoDic = @{
        kFileInfoKeyDownloadPath : self.downloadPath,
        kFileInfoKeyFileName : fileName,
        kFileInfoKeyDocumentPath : targetPath,
        kFileInfoKeyTargetPath : downloadFilePath,
        kFileInfoKeyPassword : kArchivePassword
    };

    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [NSFileManager createDirectorysAtPath:documentPath];
    [NSFileManager createDirectorysAtPath:targetPath];
    [[NSFileManager defaultManager] removeItemAtPath:downloadFilePath error:nil];

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    self.downloadTask = [session downloadTaskWithRequest:urlRequest];
    [self.downloadTask resume];
}

- (void)resume {
    [self.downloadTask resume];
    [RBUserSettingData sharedInstance].resourceDownloadPause = NO;
    [[RBUserSettingData sharedInstance] save];
}

- (void)pause {
    [self.downloadTask suspend];
    [RBUserSettingData sharedInstance].resourceDownloadPause = YES;
    [[RBUserSettingData sharedInstance] save];
}

#pragma mark - Archive extraction

- (void)unzip:(NSDictionary *)info {
    [[NSFileManager defaultManager] removeItemAtPath:GetImageAssetDirectoryPath() error:nil];
    BOOL unzipped = [SSZipArchive unzipFileAtPath:info[kFileInfoKeyTargetPath]
                                    toDestination:info[kFileInfoKeyDocumentPath]
                                        overwrite:YES
                                         password:info[kFileInfoKeyPassword]
                                            error:nil
                                         delegate:self];
    if (!unzipped) {
        // This runs on the detached unzip thread, so the view update joins the alert on the main
        // thread rather than being set here as the binary does.
        dispatch_async(dispatch_get_main_queue(), ^{
          self.popImageView.hidden = NO;
          /** @ghidraAddress 0x1c094 */
          [UIAlertView showDownloadErrorWithDelegate:self];
        });
        self.downloadPath = nil;
    }
}

- (void)success {
    [RBUserSettingData sharedInstance].resourceDownloadVersion = self.version;
    [RBUserSettingData sharedInstance].resourceDownloadPause = NO;
    [[RBUserSettingData sharedInstance] save];

    BOOL verified = [RBResourceDownloadViewController checkFile];
    if (verified) {
        self.nextAnimation = NO;
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    self.popImageView.hidden = NO;
    [UIAlertView showDownloadErrorWithDelegate:self];
    self.downloadPath = nil;
}

+ (BOOL)checkFile {
    NSString *imageAssetPath = GetImageAssetDirectoryPath();
    NSString *manifestArchivePath = [imageAssetPath stringByAppendingString:kManifestArchiveSuffix];
    BOOL unzipped = [SSZipArchive unzipFileAtPath:manifestArchivePath
                                    toDestination:GetImageAssetDirectoryPath()
                                        overwrite:YES
                                         password:kArchivePassword
                                            error:nil
                                         delegate:nil];
    if (!unzipped) {
        return NO;
    }

    NSString *manifestListPath =
        [GetImageAssetDirectoryPath() stringByAppendingString:kManifestListSuffix];
    NSString *manifest = [NSString stringWithContentsOfFile:manifestListPath
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    if (manifest == nil) {
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager
        removeItemAtPath:[GetImageAssetDirectoryPath() stringByAppendingString:kManifestListSuffix]
                   error:nil];
    NSArray *entries = [manifest componentsSeparatedByString:kManifestLineSeparator];
    if (entries == nil) {
        return NO;
    }

    BOOL allPresent = YES;
    for (NSUInteger i = 0; i < entries.count; ++i) {
        NSString *filePath = [[[GetImageAssetDirectoryPath() stringByAppendingString:kPathSeparator]
            stringByAppendingString:entries[i]] copy];
        allPresent = allPresent && [fileManager fileExistsAtPath:filePath];
        if (!allPresent) {
            break;
        }
    }
    return allPresent;
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    if (progress < 1.0f) {
        [self performSelectorOnMainThread:@selector(updateProgress:)
                               withObject:@(progress)
                            waitUntilDone:NO];
    }
}

- (void)URLSession:(NSURLSession *)session
          downloadTask:(NSURLSessionDownloadTask *)downloadTask
     didResumeAtOffset:(int64_t)fileOffset
    expectedTotalBytes:(int64_t)expectedTotalBytes {
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:@(0.0f)
                        waitUntilDone:NO];
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
    NSError *error = nil;
    NSURL *targetURL = [NSURL fileURLWithPath:self.fileInfoDic[kFileInfoKeyTargetPath]];
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:targetURL error:&error];
    if (error == nil) {
        self.progressMode = kProgressModeUnzip;
        [NSThread detachNewThreadSelector:@selector(unzip:)
                                 toTarget:self
                               withObject:self.fileInfoDic];
    } else {
        [UIAlertView showDownloadErrorWithDelegate:self];
        self.downloadPath = nil;
        [RBUserSettingData sharedInstance].resourceDownloadPause = YES;
    }
}

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    if (error) {
        [UIAlertView showDownloadErrorWithDelegate:self];
        self.downloadPath = nil;
        [RBUserSettingData sharedInstance].resourceDownloadPause = YES;
    }
}

#pragma mark - SSZipArchiveDelegate

- (void)zipArchiveWillUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo {
}

- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path
                                zipInfo:(unz_global_info)zipInfo
                           unzippedPath:(NSString *)unzippedPath {
    /** @ghidraAddress 0x1ca44 */
    // SSZipArchive calls this back on the detached thread that runs -unzip:, and -success dismisses
    // this controller. The binary is seven instructions that tail-call -success at 0x1ca54, from
    // that thread.
#ifdef ENABLE_PATCHES
    // Current iOS traps the direct call with an EXC_BREAKPOINT out of FBSMainRunLoopSerialQueue,
    // so the call is marshalled to the main thread. See PATCHES.md.
    dispatch_async(dispatch_get_main_queue(), ^{
      [self success];
    });
#else
    [self success];
#endif
}

- (void)zipArchiveWillUnzipFileAtIndex:(NSInteger)fileIndex
                            totalFiles:(NSInteger)totalFiles
                           archivePath:(NSString *)archivePath
                              fileInfo:(unz_file_info)fileInfo {
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:@((float)fileIndex / (float)totalFiles)
                        waitUntilDone:NO];
}

- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex
                           totalFiles:(NSInteger)totalFiles
                          archivePath:(NSString *)archivePath
                             fileInfo:(unz_file_info)fileInfo {
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == kUpdateRequiredAlertTag) {
        if (alertView.cancelButtonIndex == buttonIndex) {
            [AppDelegate appDelegate].isSkipUpdate = YES;
            [self download];
        } else {
            [AppDelegate launchAppStore];
        }
    } else {
        [self download];
    }
}

#pragma mark - Completion animation

- (void)animation {
    if (!self.nextAnimation) {
        return;
    }
    self.popImageView.alpha = kPopFadeInAlpha;
    CGAffineTransform scale = CGAffineTransformMakeScale(kPopPopScale, kPopPopScale);
    CGAffineTransform base =
        self.popImageView ? self.popImageView.transform : CGAffineTransformIdentity;
    CGRect popFrame = self.popImageView.frame;
    CGAffineTransform translate =
        CGAffineTransformTranslate(base,
                                   popFrame.size.width * kPopTranslateXFactor,
                                   popFrame.size.height / kPopTranslateYDivisor);
    self.popImageView.transform = CGAffineTransformConcat(scale, translate);

    __weak RBResourceDownloadViewController *weakSelf = self;
    [UIView animateWithDuration:kPopAnimationDuration
        animations:^{
          /** @ghidraAddress 0x1a8b4 */
          weakSelf.popImageView.alpha = 1.0;
          weakSelf.popImageView.transform = CGAffineTransformIdentity;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1a9cc */
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kAnimationRetryDelayNanos),
                         dispatch_get_main_queue(),
                         ^{
                           /** @ghidraAddress 0x1aa68 */
                           [weakSelf animation];
                         });
        }];
}

#pragma mark - View construction

// The layout constants below are the sprite-atlas crop rectangles and container sizes baked into
// the binary as double-precision literals, kept per device idiom. Every frame in this block has
// since been recovered exactly from the d0-d3 arguments of its setFrame: or clipImageWithRect:
// call, so none of them is centred or inferred; each is an absolute pool constant.

// dl_info atlas crop rectangles (phone (standard) layout).
// The pastel meter's crop from the dl_info atlas, per idiom. The wide rect is the doubled one, from
// the clipImageWithRect: at 0x1d130; the narrow one is half its size, matching kMeterSpriteScale.
static const CGRect kPastelClipRectNarrow = {{0, 0}, {86, 91}};
static const CGRect kPastelClipRectWide = {{0, 0}, {173, 182}};
// The remaining crops from the dl_info atlas, per idiom. The narrow set is what this file already
// had; the wide set comes from the pad arm of the branch at 0x1d10c, whose clip calls sit at
// 0x1d274, 0x1d398 and 0x1d3c4.
static const CGRect kPopClipRectNarrow = {{87, 0}, {128, 84}};
static const CGRect kPopClipRectWide = {{175, 0}, {256, 169}};
static const CGRect kTrackClipRectNarrow = {{0, 92}, {155, 7}};
static const CGRect kTrackClipRectWide = {{0, 184}, {310, 14}};
static const CGRect kFillClipRectNarrow = {{0, 100}, {155, 7}};
static const CGRect kFillClipRectWide = {{0, 200}, {310, 14}};
// Progress-meter placement within the pastel container, per idiom. Only the narrow set was here, so
// on a pad the whole meter was laid out for a phone. The wide origins are the 132 and 68 at
// 0x2ee9f8, the 62 at 0x2eea20, and the 160 at 0x2eea38; the pop sprite takes y zero in both.
static const CGFloat kPastelImageOriginXNarrow = 42;
static const CGFloat kPastelImageOriginYNarrow = 32;
static const CGFloat kPastelImageOriginXWide = 132;
static const CGFloat kPastelImageOriginYWide = 68;
static const CGFloat kPopImageOriginXNarrow = 0;
static const CGFloat kPopImageOriginXWide = 62;
static const CGFloat kTrackImageOriginXNarrow = 5;
static const CGFloat kTrackImageOriginYNarrow = 78;
static const CGFloat kTrackImageOriginXWide = 0;
static const CGFloat kTrackImageOriginYWide = 160;
// The half-scale applied to each cropped meter sprite so it renders at point resolution. The pad
// draws its track and fill at the crop's own size instead: the pad arm moves the size straight into
// the frame at 0x1d49c where the phone arm multiplies it, and an unscaled 310 is what spans the
// 320-wide container.
static const CGFloat kMeterSpriteScale = 0.5;
static const CGFloat kTrackSpriteScaleNarrow = 0.5;
static const CGFloat kTrackSpriteScaleWide = 1.0;
// The resizable cap inset used for the help background (and the wide-variant progress fill).
static const CGFloat kHelpBackgroundCapInset = 10;
// The wide progress fill stretches horizontally only: the resizableImageWithCapInsets: at 0x1d3f0
// takes zero top and bottom and 7 either side, which are the fill's rounded caps. The help
// background's own call at 0x1dba0 really does take 10 on all four.
static const CGFloat kProgressFillCapInsetHorizontal = 7;
static const CGFloat kProgressFillCapInsetVertical = 0;
// The help-carousel container geometry (phone (standard) layout).
static const CGFloat kHelpScrollBackgroundOriginX = 2;
static const CGFloat kHelpScrollBackgroundWidth = 316;
static const CGFloat kHelpScrollBackgroundHeight = 320;
// The help carousel's scroll view, per idiom. The wide values come from the branch at 0x1ce64 and
// the narrow ones from 0x1cf40; each inset fits its canvas exactly.
static const CGRect kHelpScrollViewFrameNarrow = {{10, 10}, {300, 300}};
static const CGRect kHelpScrollViewFrameWide = {{8, 20}, {528, 630}};
// The gradient bar across the top of the help panel, per idiom. The wide values come from the same
// branch as the scroll view: x and y from d12 and sp+0x50, the width from the 540 at 0x2ee990, and
// the height from the 80 at 0x2ec6c8.
static const CGRect kHelpGradientFrameNarrow = {{3, 2}, {314, 40}};
static const CGRect kHelpGradientFrameWide = {{2, 0}, {540, 80}};
static const CGFloat kHelpBarTop = 5;
// The page control, from the ldp d0,d2,[sp,#0x20] at 0x1e044: x comes from sp+0x20 and the width
// from sp+0x28, which the narrow branch fills with 60 and 200. The wide branch pairs d12 with the
// 540 at 0x2ee990 and takes its y from the 642 at 0x2ee988.
static const CGRect kHelpPageControlFrameNarrow = {{60, 298}, {200, 24}};
static const CGRect kHelpPageControlFrameWide = {{2, 642}, {540, 24}};
// Page-control cosmetics.
static const CGFloat kPageControlScale = 0.8;
static const CGFloat kPageIndicatorTintWhite = 0.667;
static const CGFloat kCurrentPageIndicatorTintWhite = 0.5;

- (void)setupView {
    // iPad devices show an animated particle background; every other device shows the
    // static "dl_bg" artwork stretched to the view bounds.
    if (!IsPad()) {
        UIImageView *background = [[UIImageView alloc]
            initWithImage:[UIImage imageWithName:kBackgroundImageName useCache:NO]];
        background.frame = self.view.bounds;
        background.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        background.contentMode = UIViewContentModeScaleAspectFill;
        [self.view addSubview:background];
    } else {
        self.bgEffectView = [[RBResoureDownloadBGEffectView alloc] initWithFrame:self.view.bounds];
        [self.bgEffectView setupView];
        [self.view addSubview:self.bgEffectView];
    }
    self.view.backgroundColor = UIColor.whiteColor;

    // The wide variant lays the help carousel out over a 544x670 canvas; the standard variant uses
    // a square 320x320 help canvas and a 90-point square pastel container.
    self->m_PageNum = kHelpPageCount;
    if (!IsPad()) {
        self.helpView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, kHelpCanvasSize, kHelpCanvasSize)];
        self.pastelView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPastelCanvasSize, kPastelCanvasSize)];
    } else {
        self.helpView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, kWideHelpCanvasWidth, kWideHelpCanvasHeight)];
        self.pastelView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, kHelpCanvasSize, kWidePastelCanvasHeight)];
    }
    self.helpView.autoresizingMask = UIViewAutoresizingNone;
    self.pastelView.autoresizingMask = UIViewAutoresizingNone;
    [self.view addSubview:self.helpView];
    [self.view addSubview:self.pastelView];

    // The progress meter is assembled from crops of the single "dl_info" atlas: the pastel base,
    // the pop artwork, the track, and the clipped fill. Each cropped sprite is drawn at half size.
    UIImage *info = [UIImage imageWithName:kInfoImageName useCache:NO];

    const BOOL narrow = !IsPad();

    UIImage *pastel = [info clipImageWithRect:narrow ? kPastelClipRectNarrow : kPastelClipRectWide];
    self.pastelImageView = [[UIImageView alloc] initWithImage:pastel];
    self.pastelImageView.frame =
        CGRectMake(narrow ? kPastelImageOriginXNarrow : kPastelImageOriginXWide,
                   narrow ? kPastelImageOriginYNarrow : kPastelImageOriginYWide,
                   pastel.size.width * kMeterSpriteScale,
                   pastel.size.height * kMeterSpriteScale);
    [self.pastelView addSubview:self.pastelImageView];

    UIImage *pop = [info clipImageWithRect:narrow ? kPopClipRectNarrow : kPopClipRectWide];
    self.popImageView = [[UIImageView alloc] initWithImage:pop];
    self.popImageView.frame = CGRectMake(narrow ? kPopImageOriginXNarrow : kPopImageOriginXWide,
                                         0,
                                         pop.size.width * kMeterSpriteScale,
                                         pop.size.height * kMeterSpriteScale);
    [self.pastelView addSubview:self.popImageView];

    UIImage *track = [info clipImageWithRect:narrow ? kTrackClipRectNarrow : kTrackClipRectWide];
    UIImage *fill = [info clipImageWithRect:narrow ? kFillClipRectNarrow : kFillClipRectWide];
    const CGFloat trackScale = narrow ? kTrackSpriteScaleNarrow : kTrackSpriteScaleWide;
    if (!narrow) {
        fill = [fill resizableImageWithCapInsets:UIEdgeInsetsMake(kProgressFillCapInsetVertical,
                                                                  kProgressFillCapInsetHorizontal,
                                                                  kProgressFillCapInsetVertical,
                                                                  kProgressFillCapInsetHorizontal)];
    }
    self.trackImageView = [[UIImageView alloc] initWithImage:track];
    self.trackImageView.frame =
        CGRectMake(narrow ? kTrackImageOriginXNarrow : kTrackImageOriginXWide,
                   narrow ? kTrackImageOriginYNarrow : kTrackImageOriginYWide,
                   track.size.width * trackScale,
                   track.size.height * trackScale);
    [self.pastelView addSubview:self.trackImageView];

    self.progressImageView = [[UIImageView alloc] initWithImage:fill];
    // The fill starts with no width at all, in both arms, and -updateProgress: grows it. Giving it
    // the crop's width showed a full progress bar before anything had downloaded.
    self.progressImageView.frame = CGRectMake(0, 0, 0, fill.size.height * trackScale);
    self.progressImageView.clipsToBounds = YES;
    [self.trackImageView addSubview:self.progressImageView];
    if (narrow) {
        [self.view addSubview:self.pastelView];
    }

    // The help carousel: a resizable background, a paged scroll view, a gradient header carrying
    // the "how_bar" caption, a page control, and one "how_N" page per help page.
    UIImage *helpBackground = [[UIImage imageWithName:kHelpBackgroundImageName useCache:NO]
        resizableImageWithCapInsets:UIEdgeInsetsMake(kHelpBackgroundCapInset,
                                                     kHelpBackgroundCapInset,
                                                     kHelpBackgroundCapInset,
                                                     kHelpBackgroundCapInset)];
    self.scrollBGView = [[UIImageView alloc] initWithImage:helpBackground];
    self.scrollBGView.frame = CGRectMake(
        kHelpScrollBackgroundOriginX, 0, kHelpScrollBackgroundWidth, kHelpScrollBackgroundHeight);
    [self.helpView addSubview:self.scrollBGView];

    self.scrollView = [[UIScrollView alloc]
        initWithFrame:!IsPad() ? kHelpScrollViewFrameNarrow : kHelpScrollViewFrameWide];
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width * self->m_PageNum,
                                             self.scrollView.bounds.size.height);
    self.scrollView.delegate = self;
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    // 0x1de78 sends the 0x3f loaded at 0x1de6c, all six flags, not the width-and-height pair.
    self.scrollView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.helpView addSubview:self.scrollView];

    UIImageView *gradient =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kGradientImageName useCache:NO]];
    const CGRect gradientFrame = !IsPad() ? kHelpGradientFrameNarrow : kHelpGradientFrameWide;
    gradient.frame = gradientFrame;
    UIImage *helpBarImage = [UIImage imageWithName:kHelpBarImageName useCache:NO];
    UIImageView *helpBar = [[UIImageView alloc] initWithImage:helpBarImage];
    // Centred across the gradient, so a gradient narrower than the bar drove this negative and put
    // the bar off the panel's left edge entirely.
    helpBar.frame = CGRectMake((gradientFrame.size.width - helpBarImage.size.width) * 0.5,
                               kHelpBarTop,
                               helpBarImage.size.width,
                               helpBarImage.size.height);
    [gradient addSubview:helpBar];
    [self.helpView addSubview:gradient];

    self.pageControl = [[UIPageControl alloc]
        initWithFrame:!IsPad() ? kHelpPageControlFrameNarrow : kHelpPageControlFrameWide];
    self.pageControl.numberOfPages = self->m_PageNum;
    self.pageControl.currentPage = 0;
    self.pageControl.transform = CGAffineTransformMakeScale(kPageControlScale, kPageControlScale);
    [self.pageControl addTarget:self
                         action:@selector(pageDidChangeValue:)
               forControlEvents:UIControlEventValueChanged];
    // 0x1e194 sends the same 0x3f, not None; only the help and pastel containers get None.
    self.pageControl.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    self.pageControl.pageIndicatorTintColor = [UIColor colorWithWhite:kPageIndicatorTintWhite
                                                                alpha:1.0];
    self.pageControl.currentPageIndicatorTintColor =
        [UIColor colorWithWhite:kCurrentPageIndicatorTintWhite alpha:1.0];
    [self.helpView addSubview:self.pageControl];

    for (int i = 0; i < self->m_PageNum; ++i) {
        [self createViewSame:i];
    }
    [self layoutScrollView];

    self.fadeImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.fadeImageView.backgroundColor = UIColor.blackColor;
    self.fadeImageView.alpha = 1.0;
    // 0x1e41c sends the same 0x3f. Of the six masks this routine sets, only the background at
    // 0x1cce8 is the 0x12 width-and-height pair.
    self.fadeImageView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.fadeImageView];
}

- (void)createViewSame:(int)index {
    if (index > kHelpPageCount - 1) {
        return;
    }
    UIImage *pageImage = [UIImage imageWithName:kHelpPageImageNames[index] useCache:NO];
    UIImageView *pageView = [[UIImageView alloc] initWithImage:pageImage];
    CGRect scrollFrame = self.scrollView.frame;
    pageView.frame = CGRectMake(
        (CGFloat)index * scrollFrame.size.width, 0, pageImage.size.width, pageImage.size.height);
    // All six flags again: 0x1e984 loads the same 0x3f slot at 0x310450 that -viewDidLoad uses,
    // not the width-and-height pair.
    pageView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.scrollView addSubview:pageView];
}

- (void)updateLayout {
    // Three arms, not two. The cbz at 0x1ea84 splits on the idiom, and the fcmp d8,d9 with b.le at
    // 0x1edac splits every other device on the bounds' aspect, taking side by side when the height
    // is the lesser. A pad stacks the help panel above the pastel container and centres both
    // horizontally. Any other device stacks them the same way in portrait but aligns the pastel
    // container's right edge with the help panel's, and in landscape sets them side by side with
    // the pastel container's bottom edge on the help panel's. Each computed origin round-trips
    // through fcvt in the binary, so the originals were single precision.
    CGRect bounds = self.view.bounds;
    CGSize helpSize = self.helpView.frame.size;
    CGSize pastelSize = self.pastelView.frame.size;
    BOOL isPad = IsPad();
    BOOL sideBySide = !isPad && (bounds.size.height <= bounds.size.width);
    if (isPad) {
        float helpY =
            (float)((bounds.size.height - helpSize.height - pastelSize.height - kLayoutGap) * 0.5);
        self.helpView.frame = CGRectMake((bounds.size.width * 0.5) - (helpSize.width * 0.5),
                                         helpY,
                                         helpSize.width,
                                         helpSize.height);
        self.pastelView.frame = CGRectMake((bounds.size.width * 0.5) - (pastelSize.width * 0.5),
                                           helpY + helpSize.height + kLayoutGap,
                                           pastelSize.width,
                                           pastelSize.height);
    } else if (!sideBySide) {
        CGFloat helpX = (bounds.size.width * 0.5) - (helpSize.width * 0.5);
        float helpY =
            (float)((bounds.size.height - helpSize.height - pastelSize.height - kLayoutGap) * 0.5);
        self.helpView.frame = CGRectMake(helpX, helpY, helpSize.width, helpSize.height);
        // The binary re-reads the help frame it has just set, which yields these same values.
        self.pastelView.frame = CGRectMake((float)((helpX + helpSize.width) - pastelSize.width),
                                           helpY + helpSize.height + kLayoutGap,
                                           pastelSize.width,
                                           pastelSize.height);
    } else {
        float helpX =
            (float)((bounds.size.width - helpSize.width - pastelSize.width - kLayoutGap) * 0.5);
        float helpY = (float)((bounds.size.height - helpSize.height) * 0.5);
        self.helpView.frame = CGRectMake(helpX, helpY, helpSize.width, helpSize.height);
        self.pastelView.frame = CGRectMake(helpX + helpSize.width + kLayoutGap,
                                           (float)((helpY + helpSize.height) - pastelSize.height),
                                           pastelSize.width,
                                           pastelSize.height);
    }
}

- (void)layoutScrollView {
    CGRect bounds = self.scrollView.bounds;
    self.scrollView.contentSize =
        CGSizeMake(bounds.size.width * self->m_PageNum, bounds.size.height);
}

#pragma mark - Progress

- (void)updateProgress:(NSNumber *)progress {
    CGRect trackFrame = self.trackImageView.frame;
    float fraction = progress.floatValue;
    CGFloat trackWidth = trackFrame.size.width;
    // The height is the track's own. Each arm zeroes only d0 and d1, the origin, and computes d2,
    // the width; d3 is never written, so it still holds the height left there by the second
    // -[trackImageView frame] send. That second send looks redundant and is not: it is what
    // reloads the height. A zero there leaves the fill with no height and nothing is drawn.
    CGFloat trackHeight = trackFrame.size.height;
    switch (self.progressMode) {
    case kProgressModeDownload:
        self.progressImageView.frame =
            CGRectMake(0, 0, trackWidth * fraction * kDownloadProgressScale, trackHeight);
        break;
    case kProgressModeUnzip:
        self.progressImageView.frame =
            CGRectMake(0, 0, trackWidth * (fraction + 1.0f) * kUnzipProgressScale, trackHeight);
        break;
    case kProgressModeVerify:
        self.progressImageView.frame = CGRectMake(0, 0, trackWidth * fraction, trackHeight);
        break;
    default:
        break;
    }
}

- (void)pageDidChangeValue:(UIPageControl *)sender {
    NSInteger page = self.pageControl.currentPage;
    CGRect frame = self.scrollView.frame;
    if (self.scrollView && !self.scrollView.isTracking && !self.scrollView.isDragging &&
        !self.scrollView.isDecelerating) {
        [self.scrollView
            scrollRectToVisible:CGRectMake(
                                    page * frame.size.width, 0, frame.size.width, frame.size.height)
                       animated:YES];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offsetX = scrollView.contentOffset.x;
    CGFloat pageWidth = scrollView.bounds.size.width;
    CGFloat fractionalPage = offsetX / pageWidth;
    int page = (int)fractionalPage;
    float roundedPage =
        ((float)fractionalPage - (float)page > 0.5f) ? (float)(page + 1) : (float)page;
    if ((float)self.pageControl.currentPage != roundedPage) {
        self.pageControl.currentPage = (NSInteger)roundedPage;
    }
}

@end
