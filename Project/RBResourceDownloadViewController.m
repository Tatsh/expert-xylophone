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

static NSString *const kResponseKeyError = @"Error";
static NSString *const kResponseKeyVersion = @"Version";
static NSString *const kResponseKeyItemURL = @"ItemURL";
static NSString *const kResponseKeyTime = @"Time";
static NSString *const kResponseKeyApp = @"App";
static NSString *const kResponseKeyUserID = @"UserID";
static NSString *const kResponseKeyPasswd = @"Passwd";
static NSString *const kResponseKeyCol = @"Col";

static NSString *const kRequestKeyTarget = @"target";
static NSString *const kRequestKeyVersion = @"version";
static NSString *const kRequestKeyUserID = @"user_id";
static NSString *const kRequestKeyPasswd = @"passwd";
static NSString *const kRequestKeyUUID = @"uuid";

static NSString *const kFileInfoKeyDownloadPath = @"downloadPath";
static NSString *const kFileInfoKeyDocumentPath = @"documentPath";
static NSString *const kFileInfoKeyFileName = @"fileName";
static NSString *const kFileInfoKeyTargetPath = @"targetPath";
static NSString *const kFileInfoKeyPassword = @"password";

static NSString *const kArchivePassword = @"mt972";
static NSString *const kEmptyCredential = @"";

static NSString *const kManifestArchiveSuffix = @"/list";
static NSString *const kManifestListSuffix = @"/lists";
static NSString *const kPathSeparator = @"/";
static NSString *const kManifestLineSeparator = @"\n";

static NSString *const kBackgroundImageName = @"dl_bg";
static NSString *const kInfoImageName = @"dl_info";
static NSString *const kHelpBackgroundImageName = @"how_bg";
static NSString *const kGradientImageName = @"set_grad";
static NSString *const kHelpBarImageName = @"how_bar";
static NSString *const kHelpPageImageNames[] = {
    @"how_1", @"how_2", @"how_3", @"how_4", @"how_5", @"how_6"};

static const int kUpdateRequiredAlertTag = 3;

enum {
    kProgressModeDownload = 0,
    kProgressModeUnzip = 1,
    kProgressModeVerify = 2,
};

static const int kHelpPageCount = 6;

static const int kResourceDownloadBgmType = 15;

static const float kResourceDownloadBgmVolume = 0.3f; // @ghidraAddress 0x2ee910
static const NSTimeInterval kFadeOutDuration = 1.0;

static const CGFloat kDownloadProgressScale = 0.5;
static const CGFloat kUnzipProgressScale = 0.5;

enum {
    kOrientationMaskWideVariant =
        UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown,
    kOrientationMaskDefault = UIInterfaceOrientationMaskAll,
};

static const CGFloat kHelpCanvasSize = 320;
static const CGFloat kWideHelpCanvasWidth = 544;
static const CGFloat kWideHelpCanvasHeight = 670;
// @ghidraAddress 0x2ee970
static const CGFloat kWidePastelCanvasHeight = 180;
// @ghidraAddress 0x2ee920
static const CGFloat kPastelCanvasSize = 90;
static const CGFloat kLayoutGap = 20;

static const CGFloat kPopFadeInAlpha = 0.0;
static const CGFloat kPopPopScale = 0.1;
static const CGFloat kPopTranslateXFactor = 0.125;
static const CGFloat kPopTranslateYDivisor = 3.0;
static const NSTimeInterval kPopAnimationDuration = 2.0;
static const int64_t kAnimationRetryDelayNanos = 2000000000;

@interface RBResourceDownloadViewController () {
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

          NSString *requiredAppVersion = json[kResponseKeyApp];
          id userID = json[kResponseKeyUserID];
          id passwd = json[kResponseKeyPasswd];

          // The binary expresses this as an obfuscated boolean; it is reproduced branch for branch.
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

static const CGRect kPastelClipRectNarrow = {{0, 0}, {86, 91}};
static const CGRect kPastelClipRectWide = {{0, 0}, {173, 182}};
static const CGRect kPopClipRectNarrow = {{87, 0}, {128, 84}};
static const CGRect kPopClipRectWide = {{175, 0}, {256, 169}};
static const CGRect kTrackClipRectNarrow = {{0, 92}, {155, 7}};
static const CGRect kTrackClipRectWide = {{0, 184}, {310, 14}};
static const CGRect kFillClipRectNarrow = {{0, 100}, {155, 7}};
static const CGRect kFillClipRectWide = {{0, 200}, {310, 14}};
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
static const CGFloat kMeterSpriteScale = 0.5;
static const CGFloat kTrackSpriteScaleNarrow = 0.5;
static const CGFloat kTrackSpriteScaleWide = 1.0;
static const CGFloat kHelpBackgroundCapInset = 10;
static const CGFloat kProgressFillCapInsetHorizontal = 7;
static const CGFloat kProgressFillCapInsetVertical = 0;
static const CGFloat kHelpScrollBackgroundOriginX = 2;
static const CGFloat kHelpScrollBackgroundWidth = 316;
static const CGFloat kHelpScrollBackgroundHeight = 320;
static const CGRect kHelpScrollViewFrameNarrow = {{10, 10}, {300, 300}};
static const CGRect kHelpScrollViewFrameWide = {{8, 20}, {528, 630}};
static const CGRect kHelpGradientFrameNarrow = {{3, 2}, {314, 40}};
static const CGRect kHelpGradientFrameWide = {{2, 0}, {540, 80}};
static const CGFloat kHelpBarTop = 5;
static const CGRect kHelpPageControlFrameNarrow = {{60, 298}, {200, 24}};
static const CGRect kHelpPageControlFrameWide = {{2, 642}, {540, 24}};
static const CGFloat kPageControlScale = 0.8;
static const CGFloat kPageIndicatorTintWhite = 0.667;
static const CGFloat kCurrentPageIndicatorTintWhite = 0.5;

- (void)setupView {
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
    self.progressImageView.frame = CGRectMake(0, 0, 0, fill.size.height * trackScale);
    self.progressImageView.clipsToBounds = YES;
    [self.trackImageView addSubview:self.progressImageView];
    if (narrow) {
        [self.view addSubview:self.pastelView];
    }

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
    // 0x1e41c sends the same 0x3f, not the width-and-height pair.
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
    // 0x1e984 sends the same 0x3f, not the width-and-height pair.
    pageView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.scrollView addSubview:pageView];
}

- (void)updateLayout {
    // Three arms, not two: the idiom split, then an aspect split that puts every other device side
    // by side in landscape. Each computed origin round-trips through fcvt, so single precision.
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
    // The binary's second -frame send is not redundant: no arm writes d3, so it is what carries the
    // track's height into the fill's frame.
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
