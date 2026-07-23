//
//  RBViewController.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBViewController). This is the
//  AppDelegate root view controller: it hosts the neGLView game surface and the RBMenuView
//  music-select menu, runs the task/draw loop from a CADisplayLink, and owns the preview,
//  gameplay, playlist-popover, corporate-button, Twitter, and iTunes-store flows. It is
//  Objective-C++ because the loop, projection, and preview paths call directly into the C++ game
//  engine (GetGameSystem, GetGlRenderer, the projection-matrix helpers, and the media timers).
//
//  The heavy projection method (UpdateProjection) and the preview/gameplay setup follow the arm64
//  disassembly; the field writes go through the engine bridge's named GameSystem accessors rather
//  than raw 32-bit offsets.
//

#import "RBViewController.h"

#import <QuartzCore/QuartzCore.h>
#import <SafariServices/SafariServices.h>
#import <Social/Social.h>
#import <StoreKit/StoreKit.h>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "MusicData.h"
#import "NSFileManager+RB.h"
#import "RBCoreDataManager.h"
#import "RBExperienceData.h"
#import "RBMusicManager.h"
#import "RBNavigationController.h"
#import "RBUserSettingData.h"
#import "ScoreData.h"
#import "UIAlertView+RB.h"
#import "neEngineBridge.h"

// Speculative imports for collaborators that are not yet reconstructed. They are messaged through
// their recovered selectors below.
#import "RBBGMManager.h"
#import "RBCorporateViewController.h"
#import "RBErosionMarkUpdater.h"
#import "RBMenuView.h"
#import "RBPlaylistViewController.h"
#import "RBPopoverBackgroundView.h"
#import "RBTermAgreeView.h"
#import "StoreUtil.h"
#import "neGLView.h"

// The music id the bundle preview song is registered under.
constexpr int kPreviewMusicID = 999999999;

// The HTTP status code (404) that aborts the Twitter reachability probe.
constexpr NSInteger kHttpStatusNotFound = 404;

// The number of attempts made to start the menu background music.
constexpr int kMenuBgmPlayAttempts = 101;

// The maximum stored speed type that still maps to a shaped sheet layer.
constexpr int kMaxShapedSpeedType = 10;

// The play difficulties. The public HistoryDifficulty enum covers only Basic, Medium, and Hard;
// the fourth value is the special extend chart, which routes gameplay through the song's extend
// note data.
enum {
    kDifficultyBasic = 0,
    kDifficultyMedium = 1,
    kDifficultyHard = 2,
    kDifficultyExtend = 3,
};

// The themed sound-effect identifier played when the playlist button is pushed.
constexpr int kSoundEffectDecide = 1;

// The corporate-button web destination.
static NSString *const kCorporateURLString = @"https://www.konami.com/ja";

// The camera pitch reference height used for the standard (non-variant) font layout, in points.
constexpr float kStandardCameraPitchHeight = 25.0f;

// The camera target y offset used for the standard (non-variant) font layout, in points.
constexpr float kStandardCameraTargetY = 26.0f;

// The number of nanoseconds in one second (the preview dispatch delay).
constexpr int64_t kOneSecondInNanoseconds = 1000000000LL;

// The sheet height used while a preview/gameplay scene is on screen, in points.
constexpr float kPreviewSheetHeight = 25.0f;

// The GL clear masks (GL_COLOR_BUFFER_BIT and GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT).
constexpr unsigned int kClearColor = 0x4000;
constexpr unsigned int kClearColorAndDepth = 0x4100;

// The render-elapsed cap that gates a Draw pass; the stored threshold is effectively always
// satisfied.
// @ghidraAddress 0x2f8540
constexpr float kMaxRenderFrameElapsed = 1000.0f;

// The corporate-button fade duration, in seconds, shared with the audio resume fade.
// @ghidraAddress 0x2ec718 (g_dAudioManagerResumeFadeInTime)
constexpr double kCorporateFadeDuration = 0.3;

// The point height of the variant (wide-font) layout screen used to centre the preview camera.
// @ghidraAddress 0x3c8834 (g_nVariantScreenHeight)
constexpr int kVariantScreenHeightPoints = 1024;

// The playlist popover content size, in points.
constexpr CGFloat kPopoverContentWidth = 320.0;
constexpr CGFloat kPopoverContentHeight = 480.0;

// The corporate-button inset from the view's top-right corner, in points.
constexpr CGFloat kCorporateButtonMargin = 10.0;

// The game-start sound-effect identifier played when a song begins.
constexpr int kSoundEffectGameStart = 17;

// The Twitter reachability-probe request timeout, in seconds.
constexpr NSTimeInterval kTwitterProbeTimeout = 15.0;

// Projection constants used by -UpdateProjection.
// The sheet field-of-view is (sheetWidth / 180) * pi, converting the sheet's angular width in
// degrees to radians.
// @ghidraAddress 0x2fd024
constexpr float kSheetFovReferenceWidth = 180.0f;
// @ghidraAddress 0x2f85a0
constexpr double kSheetFovScale = 3.14159265358979323846;
// The near and far plane distances for the portrait perspective, as multiples of the camera
// distance.
// @ghidraAddress 0x2fede0
constexpr double kNearPlaneScale = 0.9;
// @ghidraAddress 0x2f8588
constexpr double kFarPlaneScale = 1.1;
// The near and far plane distances, in points, for the landscape tilt perspective.
// @ghidraAddress 0x2ec6b0
constexpr float kTiltNearPlane = 100.0f;
// @ghidraAddress 0x2fedf0
constexpr float kTiltFarPlane = 5000.0f;
// Half of pi, the level (untilted) reference pitch used by the tilt projection.
// @ghidraAddress 0x2fedd8
constexpr double kPiOverTwo = 1.5707963267948966;
// The sheet centre used as the flat-landscape camera focus, in points.
constexpr float kSheetCentreX = 384.0f;
constexpr float kSheetCentreY = 512.0f;

// The component indices of a two-component screen-size vector.
enum {
    kVectorComponentX = 0,
    kVectorComponentY = 1,
};

// The playlist view controller modes. Type "create" opens the playlist create and browse screen
// from the playlist button; type "add to set" adds a music set to an existing playlist.
enum {
    kPlaylistTypeCreate = 0,
    kPlaylistTypeAddToSet = 1,
};

// The terms-agreement document type shown by -showTermsWithDelegate:.
constexpr int kTermTypeAgreement = 1;

// The default play colour that the preview restores before showing the bundled preview song.
constexpr int kDefaultPlayColor = 0;

@interface RBViewController () <NSURLConnectionDataDelegate, SKStoreProductViewControllerDelegate>

// The display-link callback that runs one task and draw pass.
- (void)mainLoop;

// The shared tail of -startPreview that copies the user settings into the game system.
- (void)applyPreviewSettingsToGameSystem:(GameSystem *)gameSystem music:(MusicData *)music;

@end

@implementation RBViewController {
    // The task and render media timers. Their bytes are read and written as a C_TIME through the
    // engine's media-timer helpers; each is stored inline in the instance, not as an object.
    float m_LoopTime;              // +0x08
    C_TIME m_TaskTime;             // +0x10
    C_TIME m_RenderTime;           // +0x18
    BOOL m_IsResume;               // +0x20
    BOOL m_IsLoop;                 // +0x21
    BOOL m_Tweeting;               // +0x22
    int m_PreviewGrageCache;       // +0x24
    int m_PreviewPlayerColorCache; // +0x28
}

#pragma mark - Class helpers

+ (BOOL)hasTwitterAPI {
    /** @ghidraAddress 0x8d540 */
    return NSClassFromString(@"TWTweetComposeViewController") != nil;
}

+ (BOOL)canTweet {
    /** @ghidraAddress 0x8d564 */
    if (![RBViewController hasTwitterAPI]) {
        return NO;
    }
    return [SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter];
}

#pragma mark - Lifecycle and view loop

- (instancetype)init {
    /** @ghidraAddress 0x88fc0 */
    self = [super init];
    if (self) {
        m_LoopTime = 1.0f;
        m_IsResume = YES;
        m_IsLoop = NO;
        m_Tweeting = NO;
        m_PreviewGrageCache = 5;
        m_PreviewPlayerColorCache = 3;
    }
    return self;
}

- (void)loadView {
    /** @ghidraAddress 0x89050 */
    [super loadView];
    self.view.frame = [UIScreen mainScreen].bounds;
    if (!self.glView) {
        neGLView *view = [[neGLView alloc] initWithFrame:self.view.bounds];
        self.glView = view;
        self.glView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    if ([self.glView respondsToSelector:@selector(setContentScaleFactor:)]) {
        self.glView.contentScaleFactor = [UIScreen mainScreen].scale;
    }
    self.glView.delegate = self;
    [self.view addSubview:self.glView];
    [self setupCorporateButton];
}

- (void)viewWillAppear:(BOOL)animated {
    /** @ghidraAddress 0x8a134 */
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
    [self.navigationController setToolbarHidden:YES];
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self performSelector:@selector(prefersStatusBarHidden)];
        [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:YES
                                                withAnimation:UIStatusBarAnimationFade];
    }
}

- (neGLView *)openGLView {
    /** @ghidraAddress 0x8af30 */
    return self.glView;
}

- (void)Task {
    /** @ghidraAddress 0x8af3c */
    float elapsed = GetElapsedMediaTime(reinterpret_cast<double *>(&m_TaskTime));
    StartMediaTimer(reinterpret_cast<double *>(&m_TaskTime));
    auto elapsedFrames = static_cast<uintptr_t>(static_cast<int>(elapsed));
    DispatchListenerList(reinterpret_cast<void *>(elapsedFrames));
    TouchManager::FetchSharedSingleton()->CompactTouchList();
}

- (void)Draw {
    /** @ghidraAddress 0x8af88 */
    neGLESRenderer *renderer = GetGlRenderer();
    float elapsed = GetElapsedMediaTime(reinterpret_cast<double *>(&m_RenderTime));
    if (elapsed < kMaxRenderFrameElapsed) {
        [self.glView BeginRender];
        ClearBuffers(renderer, kClearColor);
        RenderGlobalSceneTree();
        [self.glView Present];
    }
    StartMediaTimer(reinterpret_cast<double *>(&m_RenderTime));
}

- (void)LayoutedGLView:(neGLView *)glView {
    /** @ghidraAddress 0x8a7e4 */
    [self UpdateProjection];
}

- (void)UpdateProjection {
    /** @ghidraAddress 0x8a800 */
    // Rebuilds the viewport and camera for the current front-buffer size. First installs an
    // orthographic viewport sized to the drawable, then a perspective (or 3D-tilt) projection for
    // the note sheet, following the arm64 disassembly. The camera helpers take a viewport for the
    // active-camera slot and an ne_CameraNode for the model node.
    neGLESRenderer *renderer = GetGlRenderer();
    int viewW = [self.glView GetFrontBufferWidth];
    int viewH = [self.glView GetFrontBufferHeight];
    float scaleFactor = static_cast<float>(self.glView.contentScaleFactor);

    GameSystem *gameSystem = GameSystem::GetGameSystem();
    float scaledSize[] = {static_cast<float>(viewW), static_cast<float>(viewH)};
    float aspect = static_cast<float>(viewW) / static_cast<float>(viewH);
    ScaleVector2(scaledSize, 1.0f / scaleFactor);
    gameSystem->SetViewportWidth(scaledSize[kVectorComponentX]);
    gameSystem->SetViewportHeight(scaledSize[kVectorComponentY]);

    ne_Viewport *orthoViewport = CreateOrthoViewport(
        scaledSize[kVectorComponentX], scaledSize[kVectorComponentY], 0, 0, viewW, viewH);
    SetCurrentProjection(orthoViewport);
    ReleaseViewportCamera(orthoViewport);

    float fovY =
        static_cast<float>(gameSystem->GetSheetWidth() / kSheetFovReferenceWidth * kSheetFovScale);

    if (viewW < viewH) {
        // Portrait: a plain perspective looking straight down the note sheet.
        gameSystem->SetSheetLayerFlags(0);
        float sheetFarX = gameSystem->GetSheetFarX();
        float sheetFarY = gameSystem->GetSheetFarY() / gameSystem->GetPlayfieldScale();
        float halfCot = 0.5f * static_cast<float>(1.0 / tan(fovY * 0.5f));
        float distance = (sheetFarX / aspect) * halfCot;
        if (sheetFarX / sheetFarY < aspect) {
            distance = sheetFarY * halfCot;
        }
        if (IsPad()) {
            distance = (sheetFarX / aspect) * halfCot;
        }
        ne_Viewport *viewport =
            CreatePerspectiveViewport(fovY,
                                      aspect,
                                      static_cast<float>(distance * kNearPlaneScale),
                                      static_cast<float>(distance * kFarPlaneScale),
                                      0,
                                      0,
                                      viewW,
                                      viewH);
        float eye[] = {gameSystem->GetCameraTargetX(), gameSystem->GetCameraTargetY(), -distance};
        float target[] = {gameSystem->GetCameraTargetX(), gameSystem->GetCameraTargetY(), 0.0f};
        float up[] = {0.0f, -1.0f, 0.0f};
        ne_CameraNode *camera = CreateLookAtCamera(eye, target, up);
        SetActiveViewCamera(viewport);
        SetCurrentModelNode(camera);
        ReleaseViewportCamera(viewport);
    } else {
        // Landscape: either a flat perspective or a 3D-tilt projection depending on whether the
        // sheet still fits when tilted.
        float pitchRef = gameSystem->GetCameraPitchHeight();
        float halfViewH = scaledSize[kVectorComponentY] * 0.5f;
        float sheetRatio = gameSystem->GetSheetHeight() / halfViewH;
        float sheetFarX = gameSystem->GetSheetFarX();
        float sheetFarY = gameSystem->GetSheetFarY();
        double tanHalfFov = tan(fovY * 0.5f);
        float slope = (1.0f - sheetRatio) * static_cast<float>(tanHalfFov);
        float shift = ((2.0f - pitchRef / halfViewH) - sheetRatio) *
                      (sheetFarX / (aspect * (sheetFarY + sheetFarY)));
        float a = slope * slope + 1.0f;
        float b = shift * (slope + slope);
        float discriminant = sqrtf(b * b + (shift * shift - 1.0f) * a * -4.0f);
        float root1 = (discriminant - b) / (a + a);
        float root2 = (-b - discriminant) / (a + a);
        float root = (root1 <= root2) ? root2 : root1;

        BOOL tilted = root > 0.0f && !isnan(root) && root < 1.0f;
        if (tilted) {
            gameSystem->SetSheetLayerFlags(1);
            float pitch = acosf(root);
            // Build the tilted view matrix, following the arm64 SIMD sequence: look at the sheet
            // mid-plane, rotate by the pitch about x, offset the sheet in y, and push it back in z.
            // The four ComposeMatrices calls fold the look-at, y-offset, rotation, and z-offset
            // matrices into the accumulator in that order.
            float sheetMidY = sheetFarY * 0.5f;
            float lookAt[16] = {};
            float lookTarget[] = {0.0f, sheetMidY, 0.0f};
            float lookEye[] = {0.0f, sheetMidY, 1.0f};
            float lookUp[] = {0.0f, -1.0f, 0.0f};
            MakeLookAtMatrix(lookAt, lookTarget, lookEye, lookUp);
            float rotation[16] = {};
            MakeRotationMatrixX(-(static_cast<float>(kPiOverTwo) - pitch), rotation);
            float sheetHalfDepth = sheetFarX / (2.0f * aspect);
            float yOffset[16] = {};
            MakeTranslationMatrix(yOffset, 0.0f, -sheetHalfDepth * (1.0f - sheetRatio), 0.0f);
            float zOffset[16] = {};
            float pitchDepth = sheetHalfDepth / static_cast<float>(tanHalfFov);
            MakeTranslationMatrix(zOffset, 0.0f, 0.0f, -pitchDepth);
            // The accumulator is seeded with the identity matrix (loaded as four constant vectors
            // in the binary) before the composition chain.
            float viewMatrix[] = {1.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  1.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  1.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  1.0f};
            ComposeMatrices(viewMatrix, lookAt);
            ComposeMatrices(viewMatrix, yOffset);
            ComposeMatrices(viewMatrix, rotation);
            ComposeMatrices(viewMatrix, zOffset);
            ne_Viewport *viewport = CreatePerspectiveViewport(
                fovY, aspect, kTiltNearPlane, kTiltFarPlane, 0, 0, viewW, viewH);
            ne_CameraNode *camera = CreateCameraFromMatrix(viewMatrix);
            SetActiveViewCamera(viewport);
            SetCurrentModelNode(camera);
            ReleaseViewportCamera(viewport);
        } else {
            gameSystem->SetSheetLayerFlags(0);
            ne_Viewport *viewport = CreatePerspectiveViewport(
                fovY, aspect, kTiltNearPlane, kTiltFarPlane, 0, 0, viewW, viewH);
            float eye[] = {kSheetCentreX,
                           kSheetCentreY,
                           static_cast<float>(sheetFarY / (tanHalfFov + tanHalfFov))};
            float target[] = {kSheetCentreX, kSheetCentreY, 0.0f};
            float up[] = {0.0f, -1.0f, 0.0f};
            ne_CameraNode *camera = CreateLookAtCamera(eye, target, up);
            SetActiveViewCamera(viewport);
            SetCurrentModelNode(camera);
            ReleaseViewportCamera(viewport);
        }
    }

    [self.glView BeginRender];
    [self.glView SetDefaultFrameBuffer];
    ClearBuffers(renderer, kClearColorAndDepth);
    [self.glView SetDefaultColorBuffer];
    [self.glView Present];
}

#pragma mark - Display-link loop control

- (void)StartLoop {
    /** @ghidraAddress 0x8b0a8 */
    m_IsLoop = YES;
    [self CreateTimer];
}

- (void)StopLoop {
    /** @ghidraAddress 0x8b0c4 */
    m_IsLoop = NO;
    [self RemoveTimer];
}

- (void)RestartLoop {
    /** @ghidraAddress 0x8b0f8 */
    m_IsResume = NO;
    [self CreateTimer];
}

- (void)CreateTimer {
    /** @ghidraAddress 0x8b2a0 */
    if (!m_IsResume && m_IsLoop) {
        StartMediaTimer(reinterpret_cast<double *>(&m_TaskTime));
        StartMediaTimer(reinterpret_cast<double *>(&m_RenderTime));
        [self CreateDisplayLinkTimer];
    }
}

- (void)RemoveTimer {
    /** @ghidraAddress 0x8b314 */
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (void)CreateDisplayLinkTimer {
    /** @ghidraAddress 0x8b110 */
    if (self.displayLink) {
        return;
    }
    Class displayLinkClass = NSClassFromString(@"CADisplayLink");
    self.displayLink = [displayLinkClass displayLinkWithTarget:self selector:@selector(mainLoop)];
    self.displayLink.frameInterval = static_cast<NSInteger>(m_LoopTime);
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)SetLoopTimeMilliSec:(float)milliSec {
    /** @ghidraAddress 0x8b288 */
    m_LoopTime = milliSec;
    [self CreateTimer];
}

// The display-link callback that drives one loop iteration. Named mainLoop in the binary; it runs
// the task and draw passes and is targeted by the CADisplayLink created above.
- (void)mainLoop {
    /** @ghidraAddress 0x8b3a8 */
    [self Task];
    [self Draw];
}

#pragma mark - Menu view management

- (void)createView {
    /** @ghidraAddress 0x89c90 */
    if (!self.musicMenuView) {
        RBMenuView *menu = [[RBMenuView alloc] initWithFrame:self.view.bounds viewController:self];
        self.musicMenuView = menu;
        self.musicMenuView.viewController = self;
        self.musicMenuView.hidden = YES;
        [self.view addSubview:self.musicMenuView];
        [self.musicMenuView.playListButton addTarget:self
                                              action:@selector(playListButtonPush:)
                                    forControlEvents:UIControlEventTouchUpInside];
    }
    if (!self.tweetCoverView) {
        UIView *cover = [[UIView alloc] initWithFrame:self.view.bounds];
        cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        cover.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        cover.hidden = YES;
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.autoresizingMask =
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        spinner.bounds = cover.bounds;
        spinner.center = cover.center;
        [spinner startAnimating];
        [cover addSubview:spinner];
        self.tweetCoverView = cover;
    }
    [self.view addSubview:self.tweetCoverView];
}

- (void)removeView {
    /** @ghidraAddress 0x89c24 */
    [self.musicMenuView removeFromSuperview];
    self.musicMenuView = nil;
}

- (void)showMusicListView {
    /** @ghidraAddress 0x8b3bc */
    [self createView];
    [self.musicMenuView showAnimation];
    EnsureTextureCacheList();
    ReleaseAllCachedTextures();
    [self StopLoop];
    [[RBExperienceData sharedInstance] takeover];
    if (![[RBUserSettingData sharedInstance] takeoverPoint]) {
        float takeoverPoint = [[RBExperienceData sharedInstance] takeoverPoint];
        [[RBUserSettingData sharedInstance] setTakeoverPoint:YES];
        [[RBUserSettingData sharedInstance] save];
        if (takeoverPoint != 0.0f) {
            [UIAlertView showTakeoverMessage];
        }
    }
    [self updateErosionMarkScore];
}

- (void)updateErosionMarkScore {
    /** @ghidraAddress 0x8e2d8 */
    [RBErosionMarkUpdater updateCheckStart:self];
}

#pragma mark - Preview and gameplay

- (void)startPreview {
    /** @ghidraAddress 0x8be40 */
    GameSystem *gameSystem = GameSystem::GetGameSystem();
    NSString *previewPath = [RBMusicManager getPathFromBundle:kPreviewMusicID];
    MusicData *previewMusic = nil;
    if ([NSFileManager isFileExist:previewPath]) {
        previewMusic = [MusicData dataWithPath:previewPath ID:kPreviewMusicID];
    }
    if (!IsPad()) {
        GameSystem::GetGameSystem()->ConfigureSheetLayerForScreen(0);
        gameSystem->SetSheetHeight(0.0f);
        gameSystem->SetCameraPitchHeight(kStandardCameraPitchHeight);
        gameSystem->SetCameraTargetX(0.0f);
        gameSystem->SetCameraTargetY(kStandardCameraTargetY);
    } else {
        int speedType = [[RBUserSettingData sharedInstance] speedType];
        if (speedType < 0 || speedType > kMaxShapedSpeedType) {
            GameSystem::GetGameSystem()->ConfigureSheetLayerForScreen(0);
        } else {
            GameSystem::GetGameSystem()->ConfigureSheetLayerForScreen(
                [[RBUserSettingData sharedInstance] speedType]);
        }
        gameSystem->SetSheetHeight(0.0f);
        gameSystem->SetCameraPitchHeight(0.0f);
        gameSystem->SetCameraTargetX(0.0f);
        gameSystem->SetCameraTargetY(0.0f);
    }
    [self UpdateProjection];
    [self applyPreviewSettingsToGameSystem:gameSystem music:previewMusic];
}

// Shared tail of -startPreview: caches the difficulty and play-colour, copies the user settings
// into the game system, reveals the loading cover, pauses the menu BGM, starts the loop, and
// schedules the deferred preview reveal.
- (void)applyPreviewSettingsToGameSystem:(GameSystem *)gameSystem music:(MusicData *)music {
    /** @ghidraAddress 0x8bf40 */
    if (music) {
        [AppDelegate.appDelegate setMusicData:music];
        if (!IsPad()) {
            gameSystem->SetSheetHeight(0.0f);
            gameSystem->SetCameraPitchHeight(kStandardCameraPitchHeight);
            gameSystem->SetCameraTargetX(0.0f);
            gameSystem->SetCameraTargetY(kStandardCameraTargetY);
        } else {
            gameSystem->SetSheetHeight(0.0f);
            gameSystem->SetCameraPitchHeight(0.0f);
            int delta = g_nVariantScreenHeight - kVariantScreenHeightPoints;
            gameSystem->SetCameraTargetX(0.0f);
            gameSystem->SetCameraTargetY(static_cast<float>(delta >> 1));
        }
        [self UpdateProjection];
        gameSystem->SetRandSeed(static_cast<unsigned int>(rand()));
    }
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    m_PreviewGrageCache = [settings difficulty];
    [settings setDifficulty:kDifficultyBasic];
    m_PreviewPlayerColorCache = [settings playColor];
    [settings setPlayColor:kDefaultPlayColor];
    gameSystem->SetGameType([settings gameType]);
    gameSystem->SetDifficulty([settings difficulty]);
    gameSystem->SetDifficultyLevel([settings difficultyLevel]);
    gameSystem->SetPlayColor([settings playColor]);
    gameSystem->SetPlayerColor([settings playerColor]);
    gameSystem->SetRivalAlpha([settings rivalAlpha]);
    gameSystem->SetShotVolume([settings shotVolume]);
    gameSystem->SetBackgroundBrightness([settings backgroundBrighness]);
    gameSystem->SetShotType([settings shotType]);
    gameSystem->SetBgmType([settings bgmType]);
    gameSystem->SetFrameType([settings frameType]);
    gameSystem->SetExplosionType([settings explosionType]);
    gameSystem->SetBackgroundType([settings backgroundType]);
    gameSystem->SetNoteType([settings noteType]);
    gameSystem->SetCpuFullCombo([settings cpuFullCombo]);
    gameSystem->SetUserFullCombo([settings userFullCombo]);
    gameSystem->SetFullJustReflec([settings fullJustReflec]);
    self.tweetCoverView.hidden = NO;
    [settings save];
    [[RBBGMManager getInstance] PauseMusic:YES];
    [self.musicMenuView stopBGEffect];
    [self StartLoop];
    dispatch_after(dispatch_time(0, kOneSecondInNanoseconds), dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x8bd60 */
      [self showPreview];
    });
}

- (void)showPreview {
    /** @ghidraAddress 0x8c8cc */
    self.musicMenuView.hidden = YES;
    self.tweetCoverView.hidden = YES;
}

- (void)hidePreview {
    /** @ghidraAddress 0x8c970 */
    self.musicMenuView.hidden = NO;
    if ([[AppDelegate.appDelegate musicData] MusicID] == kPreviewMusicID) {
        [[RBBGMManager getInstance] StopMusic:0.0f];
        [[RBBGMManager getInstance] RelaseMusic];
    }
    [[RBBGMManager getInstance] LoadMusicSelect];
    for (int attempt = kMenuBgmPlayAttempts; attempt > 0; --attempt) {
        if ([[RBBGMManager getInstance] PlayMusic:1.5f]) {
            break;
        }
    }
    [self StopLoop];
    GameSystem *gameSystem = GameSystem::GetGameSystem();
    gameSystem->SetSheetHeight(kPreviewSheetHeight);
    gameSystem->SetCameraPitchHeight(0.0f);
    gameSystem->SetCameraTargetX(0.0f);
    gameSystem->SetCameraTargetY(-kStandardCameraTargetY);
    [self UpdateProjection];
    [[RBUserSettingData sharedInstance] setDifficulty:m_PreviewGrageCache];
    [[RBUserSettingData sharedInstance] setPlayColor:m_PreviewPlayerColorCache];
    [self.musicMenuView startBGEffect];
    [AppDelegate.appDelegate setMusicData:nil];
    if ([AppDelegate.appDelegate getPackIDForOpenStore] ||
        [AppDelegate.appDelegate getCampaignIDForOpenStore] ||
        [AppDelegate.appDelegate getExtendNotePIDForOpenStore]) {
        [self.musicMenuView SelectStoreButton];
    }
}

- (void)playGameWithMusicData:(MusicData *)musicData RandSeed:(int)randSeed {
    /** @ghidraAddress 0x8b5b8 */
    GameSystem *gameSystem = GameSystem::GetGameSystem();
    RBUserSettingData *settings = [RBUserSettingData sharedInstance];
    MusicData *music = musicData;
    if ([settings difficulty] == kDifficultyExtend) {
        music = [musicData ExtMusicData];
    }
    [AppDelegate.appDelegate setMusicData:music];
    NSManagedObjectContext *context = [[RBCoreDataManager sharedInstance] managedObjectContext];
    ScoreData *scoreData = [ScoreData getScoreData:[music MusicID] inManagedObjectContext:context];
    switch ([settings difficulty]) {
    case kDifficultyMedium:
        [settings setDifficultyLevel:[music difficultyMedium]];
        gameSystem->SetTargetScore([[scoreData scoMed] intValue]);
        gameSystem->SetTargetAR([[scoreData arMed] floatValue]);
        gameSystem->SetIsFirstPlay([[scoreData pcMed] intValue] == 0);
        break;
    case kDifficultyHard:
        [settings setDifficultyLevel:[music difficultyHard]];
        gameSystem->SetTargetScore([[scoreData scoHar] intValue]);
        gameSystem->SetTargetAR([[scoreData arHar] floatValue]);
        gameSystem->SetIsFirstPlay([[scoreData pcHar] intValue] == 0);
        break;
    default:
        [settings setDifficultyLevel:[music difficultyBasic]];
        gameSystem->SetTargetScore([[scoreData scoBas] intValue]);
        gameSystem->SetTargetAR([[scoreData arBas] floatValue]);
        gameSystem->SetIsFirstPlay([[scoreData pcBas] intValue] == 0);
        break;
    }
    gameSystem->SetGameType([settings gameType]);
    gameSystem->SetDifficulty([settings difficulty]);
    gameSystem->SetDifficultyLevel([settings difficultyLevel]);
    gameSystem->SetPlayColor([settings playColor]);
    gameSystem->SetPlayerColor([settings playerColor]);
    gameSystem->SetRivalAlpha([settings rivalAlpha]);
    gameSystem->SetShotVolume([settings shotVolume]);
    gameSystem->SetBackgroundBrightness([settings backgroundBrighness]);
    gameSystem->SetShotType([settings shotType]);
    gameSystem->SetBgmType([settings bgmType]);
    gameSystem->SetFrameType([settings frameType]);
    gameSystem->SetExplosionType([settings explosionType]);
    gameSystem->SetBackgroundType([settings backgroundType]);
    gameSystem->SetNoteType([settings noteType]);
    gameSystem->SetCpuFullCombo([settings cpuFullCombo]);
    gameSystem->SetUserFullCombo([settings userFullCombo]);
    gameSystem->SetFullJustReflec([settings fullJustReflec]);
    gameSystem->SetRandSeed(static_cast<unsigned int>(randSeed));
    [self.musicMenuView hideAnimation:^{
      /** @ghidraAddress 0x8bd9c */
      [self StartLoop];
    }];
    [[RBUserSettingData sharedInstance] save];
    SoundEffectManager *soundManager = SoundEffectManager::GetInstance();
    [[AudioManager sharedManager] releaseVoice];
    soundManager->PlayThemedSoundEffect(kSoundEffectGameStart);
    [[RBBGMManager getInstance] StopMusic:0.0f];
}

- (void)clientIsGameEnd {
    /** @ghidraAddress 0x8b5b4 */
}

#pragma mark - Playlist popover

- (void)playListAddMusicSet:(id)musicSet {
    /** @ghidraAddress 0x89798 */
    self.playlistViewController = [[RBPlaylistViewController alloc] init];
    [self.playlistViewController setPlaylistType:kPlaylistTypeAddToSet];
    [self.playlistViewController setPlaylistNode:nil];
    self.playlistViewController.delegate = self;
    [self.playlistViewController setMusicSet:musicSet];
    [self showPresentViewController:[self.musicMenuView playlistAddButton]];
}

- (void)playListButtonPush:(id)sender {
    /** @ghidraAddress 0x8997c */
    if ([self.musicMenuView selectedView]) {
        return;
    }
    [self.musicMenuView setSearchBarNonActive];
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    self.playlistViewController = [[RBPlaylistViewController alloc] init];
    [self.playlistViewController setPlaylistType:kPlaylistTypeCreate];
    [self.playlistViewController setPlaylistNode:nil];
    self.playlistViewController.delegate = self;
    [self showPresentViewController];
    [self.musicMenuView playlistInfoView].hidden = YES;
    [[RBUserSettingData sharedInstance] setInfoPlaylist:YES];
    [[RBUserSettingData sharedInstance] save];
}

- (void)showPresentViewController {
    /** @ghidraAddress 0x893c4 */
    [self showPresentViewController:[self.musicMenuView playListButton]];
}

- (void)showPresentViewController:(UIView *)anchorView {
    /** @ghidraAddress 0x8945c */
    RBNavigationController *navController =
        [[RBNavigationController alloc] initWithRootViewController:self.playlistViewController];
    if (!IsPad()) {
        [self presentViewController:navController
                           animated:YES
                         completion:^{
                             /** @ghidraAddress 0x8ba50 */
                         }];
    } else {
        navController.delegate = self;
        self.playlistViewController.view.frame =
            CGRectMake(0, 0, kPopoverContentWidth, kPopoverContentHeight);
        self.playlistViewController.preferredContentSize =
            CGSizeMake(kPopoverContentWidth, kPopoverContentHeight);
        self.playlistPopoverController =
            [[UIPopoverController alloc] initWithContentViewController:navController];
        [self.playlistPopoverController
            setPopoverBackgroundViewClass:[RBPopoverBackgroundView class]];
        self.playlistPopoverController.delegate = self;
        CGRect anchor = [anchorView convertRect:anchorView.bounds toView:self.view];
        [self.playlistPopoverController presentPopoverFromRect:anchor
                                                        inView:self.view
                                      permittedArrowDirections:UIPopoverArrowDirectionUp
                                                      animated:NO];
    }
}

- (void)didSelectPlaylistViewController:(id)viewController {
    /** @ghidraAddress 0x8a294 */
    [self.musicMenuView playlistAddDelButtonUpdate];
    if (!IsPad()) {
        [self.playlistViewController.navigationController dismissViewControllerAnimated:YES
                                                                             completion:^{
                                                                                 /** @ghidraAddress
                                                                                    0x8ba90 */
                                                                             }];
    } else {
        [self.playlistPopoverController dismissPopoverAnimated:YES];
    }
    [self.musicMenuView reloadMusicData];
}

- (void)didSelectMenuSortViewController:(id)viewController {
    /** @ghidraAddress 0x8a3e8 */
    [self.musicMenuView reloadMusicData];
}

#pragma mark - Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
    /** @ghidraAddress 0x8a530 */
    [self.musicMenuView willRotate];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    /** @ghidraAddress 0x8a584 */
    [self.musicMenuView didRotate];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    /** @ghidraAddress 0x8a5d8 */
    [coordinator
        animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
          /** @ghidraAddress 0x8a704 */
          [self.musicMenuView willRotate];
        }
        completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
          /** @ghidraAddress 0x8a774 */
          [self.musicMenuView didRotate];
        }];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    /** @ghidraAddress 0x8a444 */
    viewController.preferredContentSize = navigationController.topViewController.view.frame.size;
}

#pragma mark - Corporate button and terms

- (void)setupCorporateButton {
    /** @ghidraAddress 0x8e2f4 */
    if (self.corporateButton) {
        return;
    }
    UIImage *logo = [UIImage imageWithName:@"00_texture/co/info"];
    if (!logo) {
        return;
    }
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:logo forState:UIControlStateNormal];
    button.frame =
        CGRectMake(CGRectGetWidth(self.view.bounds) - logo.size.width - kCorporateButtonMargin,
                   kCorporateButtonMargin,
                   logo.size.width,
                   logo.size.height);
    button.exclusiveTouch = YES;
    button.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [button addTarget:self
                  action:@selector(tapCorporateButton:)
        forControlEvents:UIControlEventTouchUpInside];
    button.alpha = 0.0f;
    [self.view addSubview:button];
    self.corporateButton = button;
}

- (void)fadeCorporateButton:(float)alpha {
    /** @ghidraAddress 0x8e550 */
    __weak RBViewController *weakSelf = self;
    [self setupCorporateButton];
    [UIView animateWithDuration:kCorporateFadeDuration
        delay:0.5
        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x8e6b0 */
          weakSelf.corporateButton.alpha = alpha;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x8e750 */
          if (weakSelf.corporateButton.alpha == 0.0f) {
              [weakSelf.corporateButton removeFromSuperview];
              weakSelf.corporateButton = nil;
          }
        }];
}

- (void)tapCorporateButton:(id)sender {
    /** @ghidraAddress 0x8e898 */
    if (NSClassFromString(@"SFSafariViewController")) {
        SFSafariViewController *safari =
            [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:kCorporateURLString]];
        safari.modalPresentationCapturesStatusBarAppearance = YES;
        [self presentViewController:safari
                           animated:YES
                         completion:^{
                             /** @ghidraAddress 0x8ecd0 */
                         }];
    } else {
        if ([[UIApplication sharedApplication]
                canOpenURL:[NSURL URLWithString:kCorporateURLString]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kCorporateURLString]];
        }
    }
}

- (void)showTermsWithDelegate:(id)delegate {
    /** @ghidraAddress 0x8e118 */
    if (self.termAgreeView) {
        return;
    }
    RBTermAgreeView *terms = [[RBTermAgreeView alloc] initWithFrame:self.view.bounds
                                                           termType:kTermTypeAgreement];
    terms.parentViewController = self;
    terms.delegate = delegate;
    self.termAgreeView = terms;
    [self.view addSubview:self.termAgreeView];
    [terms showAnimation];
}

#pragma mark - iTunes store

- (void)openItunesWithURL:(NSURL *)url {
    /** @ghidraAddress 0x8ce28 */
    if (!url) {
        return;
    }
    NSDictionary *affiliateParameters = [StoreUtil affiliateParametersFromURL:url];
    if (!affiliateParameters) {
        [[UIApplication sharedApplication] openURL:url];
        return;
    }
    self.itunesViewCtrl = [[SKStoreProductViewController alloc] init];
    self.itunesViewCtrl.delegate = self;
    [[AudioManager sharedManager] systemSuspend];
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *top = [self getTopViewController:root];
    [top presentViewController:self.itunesViewCtrl
                      animated:YES
                    completion:^{
                      /** @ghidraAddress 0x8d150 */
                      [self.itunesViewCtrl loadProductWithParameters:affiliateParameters
                                                     completionBlock:nil];
                    }];
}

- (UIViewController *)getTopViewController:(UIViewController *)rootViewController {
    /** @ghidraAddress 0x8d264 */
    if (!rootViewController.presentedViewController) {
        return rootViewController;
    }
    if ([rootViewController.presentedViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav =
            static_cast<UINavigationController *>(rootViewController.presentedViewController);
        return nav.viewControllers.lastObject;
    }
    return [self getTopViewController:rootViewController.presentedViewController];
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    /** @ghidraAddress 0x8d40c */
    if (self.itunesViewCtrl) {
        [self dismissViewControllerAnimated:YES
                                 completion:^{
                                   /** @ghidraAddress 0x8d4c0 */
                                   [[AudioManager sharedManager] systemResume];
                                   self.itunesViewCtrl = nil;
                                 }];
    }
}

#pragma mark - Twitter

- (void)PostTwitter:(NSString *)text Images:(NSArray *)images URLs:(NSArray *)urls {
    /** @ghidraAddress 0x8d5b4 */
    if (![RBViewController hasTwitterAPI]) {
        return;
    }
    m_Tweeting = YES;
    SLComposeViewController *compose =
        [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    [compose setInitialText:text];
    for (UIImage *image in images) {
        [compose addImage:image];
    }
    for (NSURL *url in urls) {
        [compose addURL:url];
    }
    __weak RBViewController *weakSelf = self;
    compose.completionHandler = ^(SLComposeViewControllerResult result) {
      /** @ghidraAddress 0x8d928 */
      weakSelf->m_Tweeting = NO;
    };
    [self presentViewController:compose animated:YES completion:nil];
}

- (void)PostTweet {
    /** @ghidraAddress 0x8d9c0 */
    [self PostTwitter:self.tweetText Images:@[ self.tweetImage ] URLs:nil];
    self.tweetText = nil;
    self.tweetImage = nil;
}

- (BOOL)PostTwitter:(TwitterImageCreater *)imageCreater Text:(NSString *)text {
    /** @ghidraAddress 0x8dbbc */
    if (![RBViewController hasTwitterAPI] || self.twitterImageCreater || self.tweetText ||
        m_Tweeting) {
        return NO;
    }
    self.tweetCoverView.hidden = NO;
    m_Tweeting = YES;
    self.twitterImageCreater = imageCreater;
    self.tweetText = text;
    NSURL *url = [NSURL URLWithString:@"http://twitter.com"];
    self.twitterRequestTest = [[NSURLRequest alloc] initWithURL:url
                                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                timeoutInterval:kTwitterProbeTimeout];
    self.twitterConnectionTest = [[NSURLConnection alloc] initWithRequest:self.twitterRequestTest
                                                                 delegate:self];
    return YES;
}

- (void)PostImageCreater {
    /** @ghidraAddress 0x8dacc */
    if (self.twitterImageCreater) {
        self.tweetImage = [self.twitterImageCreater createImage];
        self.twitterImageCreater = nil;
    }
    [self performSelectorOnMainThread:@selector(PostTweet) withObject:nil waitUntilDone:NO];
}

- (void)cancelTwitterConnection {
    /** @ghidraAddress 0x8de58 */
    [UIAlertView showNetworkErrorWithDelegate:nil];
    self.twitterImageCreater = nil;
    self.tweetText = nil;
    m_Tweeting = NO;
    self.tweetCoverView.hidden = YES;
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    /** @ghidraAddress 0x8df10 */
    if ([response respondsToSelector:@selector(statusCode)] &&
        [(NSHTTPURLResponse *)response statusCode] == kHttpStatusNotFound) {
        [connection cancel];
        [self cancelTwitterConnection];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    /** @ghidraAddress 0x8dfc8 */
    [self cancelTwitterConnection];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    /** @ghidraAddress 0x8dfe4 */
    if (!self.twitterImageCreaterQueue) {
        self.twitterImageCreaterQueue = [[NSOperationQueue alloc] init];
    }
    NSInvocationOperation *operation =
        [[NSInvocationOperation alloc] initWithTarget:self
                                             selector:@selector(PostImageCreater)
                                               object:nil];
    [self.twitterImageCreaterQueue addOperation:operation];
}

@end
