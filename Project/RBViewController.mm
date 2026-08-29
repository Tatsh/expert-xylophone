#import "RBViewController.h"

#import <QuartzCore/QuartzCore.h>
#import <SafariServices/SafariServices.h>
#import <Social/Social.h>
#import <StoreKit/StoreKit.h>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "GameSystem/src/OpenGL/neGLES.h"
#import "GameSystem/src/OpenGL/neTexture.h"
#import "MusicData.h"
#import "NSFileManager+RB.h"
#import "RBBGMManager.h"
#import "RBCoreDataManager.h"
#import "RBCorporateViewController.h"
#import "RBErosionMarkUpdater.h"
#import "RBExperienceData.h"
#import "RBMenuButton.h"
#import "RBMenuView.h"
#import "RBMusicManager.h"
#import "RBNavigationController.h"
#import "RBPlaylistViewController.h"
#import "RBPopoverBackgroundView.h"
#import "RBTermAgreeView.h"
#import "RBUserSettingData.h"
#import "ScoreData.h"
#import "StoreUtil.h"
#import "TwitterImageCreater.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "engineruntime.h"
#import "game_scene.h"
#import "gamesystem.h"
#import "matrixmath.h"
#import "neGLView.h"
#import "neRenderer.h"
#import "ne_c_time.h"
#import "s_vector2.h"
#import "s_vector3.h"
#import "soundeffectmanager.h"
#import "touchmanager.h"
#import "vectormath.h"

constexpr int kPreviewMusicID = 999999999;

constexpr NSInteger kHttpStatusNotFound = 404;

constexpr int kMenuBgmPlayAttempts = 101;

constexpr int kMaxShapedSpeedType = 10;

// The fourth difficulty is the extend chart, which the public HistoryDifficulty enum omits.
enum {
    kDifficultyBasic = 0,
    kDifficultyMedium = 1,
    kDifficultyHard = 2,
    kDifficultyExtend = 3,
};

constexpr int kSoundEffectDecide = 1;

static NSString *const kCorporateURLString = @"https://www.konami.com/ja";

constexpr float kStandardCameraPitchHeight = 25.0f;

constexpr float kStandardCameraTargetY = 26.0f;

// A tenth of a second computed in single precision and truncated, as the binary builds it.
// @ghidraAddress 0x8c3f0
constexpr int64_t kPreviewSceneDelayNanoseconds = 100000001LL;

// @ghidraAddress 0x2ec6b4
constexpr float kPreviewBgmPauseTime = 0.2f;

constexpr float kPreviewSheetHeight = 25.0f;

constexpr unsigned int kClearColor = 0x4000;
constexpr unsigned int kClearColorAndDepth = 0x4100;

// The stored threshold is effectively always satisfied.
// @ghidraAddress 0x2f8540
constexpr float kMaxRenderFrameElapsed = 1000.0f;

// The pool holds a float widened to double, so the literal keeps its suffix.
// @ghidraAddress 0x2ec718 (g_dAudioManagerResumeFadeInTime)
constexpr double kCorporateFadeDuration = 0.3f;

// @ghidraAddress 0x8e630
constexpr double kCorporateFadeDelay = 0.5;

// The `sub w9,w8,#0x400` immediate at 0x8bdd0 and 0x8c07c, not a global.
constexpr int kReferencePlayfieldHeight = 1024;

// @ghidraAddress 0x2ee918
constexpr CGFloat kPopoverContentWidth = 320.0;
// @ghidraAddress 0x2fedd0
constexpr CGFloat kPopoverContentHeight = 480.0;

// @ghidraAddress 0x89f28
constexpr CGFloat kTweetCoverAlpha = 0.5;

// @ghidraAddress 0x89fb4
constexpr CGFloat kSpinnerSide = 20.0;

constexpr CGFloat kCorporateButtonMargin = 10.0;

// The call at 0x8bc08 is LoadAndSetThemedVoice (0x1ccc18), not the themed sound-effect player.
constexpr int kGameStartVoiceID = 17;

#ifdef ENABLE_PATCHES
// An empty arrow-direction set presents the pad popover centred and without a callout arrow.
constexpr UIPopoverArrowDirection kNoPopoverArrow = static_cast<UIPopoverArrowDirection>(0);
#else
// @ghidraAddress 0x8dd48
constexpr NSTimeInterval kTwitterProbeTimeout = 15.0;
#endif

// @ghidraAddress 0x2fd024
constexpr float kSheetFovReferenceWidth = 180.0f;
// @ghidraAddress 0x2f85a0
constexpr double kSheetFovScale = 3.14159265358979323846;
// @ghidraAddress 0x2fede0
constexpr double kNearPlaneScale = 0.9;
// @ghidraAddress 0x2f8588
constexpr double kFarPlaneScale = 1.1;
// @ghidraAddress 0x2ec6b0
constexpr float kTiltNearPlane = 100.0f;
// @ghidraAddress 0x2fedf0
constexpr float kTiltFarPlane = 5000.0f;
// @ghidraAddress 0x2fedd8
constexpr double kPiOverTwo = 1.5707963267948966;
constexpr float kSheetCenterX = 384.0f;
constexpr float kSheetCenterY = 512.0f;

enum {
    kPlaylistTypeCreate = 0,
    kPlaylistTypeAddToSet = 1,
};

constexpr int kTermTypeAgreement = 1;

constexpr int kDefaultPlayColor = 0;

// The binary inlines this at the end of the reachability probe, which a patched build skips.
static void EnqueueImageCreaterOperation(RBViewController *controller) {
    if (!controller.twitterImageCreaterQueue) {
        controller.twitterImageCreaterQueue = [[NSOperationQueue alloc] init];
    }
    NSInvocationOperation *operation =
        [[NSInvocationOperation alloc] initWithTarget:controller
                                             selector:@selector(PostImageCreater)
                                               object:nil];
    [controller.twitterImageCreaterQueue addOperation:operation];
}

@interface RBViewController () <NSURLConnectionDataDelegate,
                                SKStoreProductViewControllerDelegate,
                                RBPlaylistViewControllerDelegate,
                                UIPopoverControllerDelegate>

- (void)applyPreviewSettingsToGameSystem:(GameSystem *)gameSystem music:(MusicData *)music;

@end

@implementation RBViewController {
    float m_LoopTime;
    C_TIME m_TaskTime;
    C_TIME m_RenderTime;
    BOOL m_IsResume;
    BOOL m_IsLoop;
    BOOL m_Tweeting;
    int m_PreviewGrageCache;
    int m_PreviewPlayerColorCache;
}

#pragma mark - Class helpers

+ (BOOL)hasTwitterAPI {
    /** @ghidraAddress 0x8d540 */
#ifdef ENABLE_PATCHES
    // Twitter.framework is not linked, so the original probe can never resolve the class.
    return YES;
#else
    return NSClassFromString(@"TWTweetComposeViewController") != nil;
#endif
}

+ (BOOL)canTweet {
    /** @ghidraAddress 0x8d564 */
#ifdef ENABLE_PATCHES
    return YES;
#else
    if (![RBViewController hasTwitterAPI]) {
        return NO;
    }
    return [SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter];
#endif
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
        // w3 is 2 at 0x8a24c, which is Slide rather than Fade.
        [[UIApplication sharedApplication] setStatusBarHidden:YES
                                                withAnimation:UIStatusBarAnimationSlide];
    }
}

- (neGLView *)openGLView {
    /** @ghidraAddress 0x8af30 */
    return self.glView;
}

- (void)Task {
    /** @ghidraAddress 0x8af3c */
    float elapsed = m_TaskTime.GetElapsedMilliseconds();
    m_TaskTime.Start();
    DispatchListenerList(static_cast<int>(elapsed));
    TouchManager::FetchSharedSingleton()->CompactTouchList();
}

- (void)Draw {
    /** @ghidraAddress 0x8af88 */
    neGLESRenderer *renderer = neGLESRenderer::GetShared();
    float elapsed = m_RenderTime.GetElapsedMilliseconds();
    if (elapsed < kMaxRenderFrameElapsed) {
        [self.glView BeginRender];
        renderer->ClearBuffers(kClearColor);
        RenderGlobalSceneTree();
        [self.glView Present];
    }
    m_RenderTime.Start();
}

- (void)LayoutedGLView:(neGLView *)glView {
    /** @ghidraAddress 0x8a7e4 */
    [self UpdateProjection];
}

- (void)UpdateProjection {
    /** @ghidraAddress 0x8a800 */
    neGLESRenderer *renderer = neGLESRenderer::GetShared();
    int viewW = [self.glView GetFrontBufferWidth];
    int viewH = [self.glView GetFrontBufferHeight];
    float scaleFactor = static_cast<float>(self.glView.contentScaleFactor);

    GameSystem *gameSystem = GameSystem::GetGameSystem();
    S_VECTOR2 scaledSize{static_cast<float>(viewW), static_cast<float>(viewH)};
    float aspect = static_cast<float>(viewW) / static_cast<float>(viewH);
    ScaleVector2(&scaledSize, 1.0f / scaleFactor);
    gameSystem->SetViewportWidth(scaledSize.x);
    gameSystem->SetViewportHeight(scaledSize.y);

    ne::Viewport *orthoViewport =
        CreateOrthoViewport(scaledSize.x, scaledSize.y, 0, 0, viewW, viewH);
    const float *pOrtho = orthoViewport->GetProjectionMatrix();
    SetCurrentProjection(orthoViewport);
    orthoViewport->Release();

    float fovY =
        static_cast<float>(gameSystem->GetSheetWidth() / kSheetFovReferenceWidth * kSheetFovScale);

    if (viewW < viewH) {
        gameSystem->SetSheetLayerFlags(0);
        float sheetFarX = gameSystem->GetSheetFarX();
        float sheetFarY = gameSystem->GetSheetFarY() / gameSystem->GetPlayfieldScale();
        float halfCot = 0.5f * static_cast<float>(1.0 / tan(fovY * 0.5f));
        float distance = (sheetFarX / aspect) * halfCot;
        if (sheetFarX / sheetFarY < aspect) {
            distance = sheetFarY * halfCot;
        }
        // The fcsel at 0x8a9c0 forces the width-fitted distance on the phone; on a pad the ratio
        // test above stands.
        if (!IsPad()) {
            distance = (sheetFarX / aspect) * halfCot;
        }
        ne::Viewport *viewport =
            CreatePerspectiveViewport(fovY,
                                      aspect,
                                      static_cast<float>(distance * kNearPlaneScale),
                                      static_cast<float>(distance * kFarPlaneScale),
                                      0,
                                      0,
                                      viewW,
                                      viewH);
        S_VECTOR3 eye{gameSystem->GetCameraTargetX(), gameSystem->GetCameraTargetY(), -distance};
        S_VECTOR3 target{gameSystem->GetCameraTargetX(), gameSystem->GetCameraTargetY(), 0.0f};
        S_VECTOR3 up{0.0f, -1.0f, 0.0f};
        ne::CameraNode *camera = CreateLookAtCamera(&eye, &target, &up);
        const float *pProj = viewport->GetProjectionMatrix();
        const float *pView = camera->GetViewMatrix();
        SetActiveViewCamera(viewport);
        SetCurrentModelNode(camera);
        viewport->Release();
    } else {
        float halfViewH = scaledSize.y * 0.5f;
        float sheetRatio = gameSystem->GetSheetHeight() / halfViewH;
        float pitchRatio = gameSystem->GetCameraPitchHeight() / halfViewH;
        float sheetFarX = gameSystem->GetSheetFarX();
        float sheetFarY = gameSystem->GetSheetFarY();
        double tanHalfFov = tan(fovY * 0.5f);
        float slope = (1.0f - sheetRatio) * static_cast<float>(tanHalfFov);
        float shift =
            ((2.0f - pitchRatio) - sheetRatio) * (sheetFarX / (aspect * (sheetFarY + sheetFarY)));
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
            // Composition does not commute, so the order at 0x8ac80-0x8aca4 is load-bearing.
            float sheetMidY = sheetFarY * 0.5f;
            float lookAt[16] = {};
            S_VECTOR3 lookEye{0.0f, sheetMidY, 0.0f};
            S_VECTOR3 lookTarget{0.0f, sheetMidY, 1.0f};
            S_VECTOR3 lookUp{0.0f, -1.0f, 0.0f};
            MakeLookAtMatrix(lookAt, &lookEye, &lookTarget, &lookUp);
            float rotation[16] = {};
            MakeRotationMatrixX(-(static_cast<float>(kPiOverTwo) - pitch), rotation);
            float sheetHalfDepth = sheetFarX / (2.0f * aspect);
            float yOffset[16] = {};
            // 0x8ac20 reads the pitch ratio, not the sheet ratio, whose register 0x8ab64 reused.
            MakeTranslationMatrix(yOffset, 0.0f, -sheetHalfDepth * (1.0f - pitchRatio), 0.0f);
            float zOffset[16] = {};
            float pitchDepth = sheetHalfDepth / static_cast<float>(tanHalfFov);
            MakeTranslationMatrix(zOffset, 0.0f, 0.0f, -pitchDepth);
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
            ComposeMatrices(viewMatrix, rotation);
            ComposeMatrices(viewMatrix, yOffset);
            ComposeMatrices(viewMatrix, zOffset);
            ne::Viewport *viewport = CreatePerspectiveViewport(
                fovY, aspect, kTiltNearPlane, kTiltFarPlane, 0, 0, viewW, viewH);
            ne::CameraNode *camera = CreateCameraFromMatrix(viewMatrix);
            SetActiveViewCamera(viewport);
            SetCurrentModelNode(camera);
            viewport->Release();
        } else {
            gameSystem->SetSheetLayerFlags(0);
            ne::Viewport *viewport = CreatePerspectiveViewport(
                fovY, aspect, kTiltNearPlane, kTiltFarPlane, 0, 0, viewW, viewH);
            S_VECTOR3 eye{kSheetCenterX,
                          kSheetCenterY,
                          static_cast<float>(sheetFarY / (tanHalfFov + tanHalfFov))};
            S_VECTOR3 target{kSheetCenterX, kSheetCenterY, 0.0f};
            S_VECTOR3 up{0.0f, -1.0f, 0.0f};
            ne::CameraNode *camera = CreateLookAtCamera(&eye, &target, &up);
            SetActiveViewCamera(viewport);
            SetCurrentModelNode(camera);
            viewport->Release();
        }
    }

    [self.glView BeginRender];
    [self.glView SetDefaultFrameBuffer];
    renderer->ClearBuffers(kClearColorAndDepth);
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

- (void)ResumeLoop {
    /** @ghidraAddress 0x8b0dc */
    m_IsResume = YES;
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
        m_TaskTime.Start();
        m_RenderTime.Start();
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

- (void)mainLoop {
    /** @ghidraAddress 0x8b074 */
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
        // The mask constant at 0x310450 is 0x3f, every margin and both dimensions.
        cover.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
        cover.backgroundColor = [UIColor colorWithWhite:0 alpha:kTweetCoverAlpha];
        cover.hidden = YES;
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        spinner.autoresizingMask =
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        spinner.bounds = CGRectMake(0, 0, kSpinnerSide, kSpinnerSide);
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
    ne::C_TEXTURE::EnsureCacheList();
    ne::C_TEXTURE::ReleaseAllHandles();
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

// Shared tail of -startPreview, beginning at the cbz on the music at 0x8c01c.
- (void)applyPreviewSettingsToGameSystem:(GameSystem *)gameSystem music:(MusicData *)music {
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
            // The csel at 0x8c088 is the divide-by-two correction, so this rounds toward zero
            // rather than toward minus infinity.
            int delta = g_nPlayfieldFieldHeight - kReferencePlayfieldHeight;
            gameSystem->SetCameraTargetX(0.0f);
            gameSystem->SetCameraTargetY(static_cast<float>(delta / 2));
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
    [[RBBGMManager getInstance] PauseMusic:kPreviewBgmPauseTime];
    [self.musicMenuView stopBGEffect];
    [self StartLoop];
    dispatch_after(dispatch_time(0, kPreviewSceneDelayNanoseconds), dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x8c884 */
      rb::GameScene *scene = GameSystem::GetGameSystem()->GetCurrentScene();
      if (scene) {
          scene->EnterModeAlt();
      }
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

- (void)playGameWithMusicData:(MusicData *)musicData RandSeed:(unsigned int)randSeed {
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
      GameSystem *blockGameSystem = GameSystem::GetGameSystem();
      BOOL isPad = IsPad();
      // One 8-byte store at 0x8bdbc writes the pair, so the pitch height is cleared in both arms.
      blockGameSystem->SetSheetHeight(kPreviewSheetHeight);
      blockGameSystem->SetCameraPitchHeight(0.0f);
      blockGameSystem->SetCameraTargetX(0.0f);
      if (isPad) {
          int delta = g_nPlayfieldFieldHeight - kReferencePlayfieldHeight;
          blockGameSystem->SetCameraTargetY(static_cast<float>(delta / 2));
      } else {
          blockGameSystem->SetCameraTargetY(-kStandardCameraTargetY);
      }
      [self UpdateProjection];
      [self StartLoop];
      GameSystem::GetGameSystem()->GetCurrentScene()->EnterModeNormal();
    }];
    [[RBUserSettingData sharedInstance] save];
    SoundEffectManager::GetInstance()->PlayGameStateSoundEffect();
    [[AudioManager sharedManager] releaseVoice];
    SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kGameStartVoiceID);
    [[RBBGMManager getInstance] StopMusic:0.0f];
    // Yes, the loop is started here as well as inside the hide-animation block above.
    [self StartLoop];
}

- (void)clientIsGameEnd {
    /** @ghidraAddress 0x8b5b4 */
}

#pragma mark - Playlist popover

- (void)playListAddMusicSet:(id)musicSet {
    /** @ghidraAddress 0x89798 */
    self.playlistViewController = [[RBPlaylistViewController alloc] init];
    [self.playlistViewController setPlaylistType:kPlaylistTypeAddToSet];
    [self.playlistViewController setPlaylistNode:0];
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
    [self.playlistViewController setPlaylistNode:0];
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
                                      permittedArrowDirections:UIPopoverArrowDirectionDown
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
    UIImage *logo = [UIImage imageWithName:@"00_texture/co_info"];
    if (!logo) {
        return;
    }
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:logo forState:UIControlStateNormal];
    // The width comes from the UIView(RB) -width category (the selector at 0x3bf998), not from the
    // view's bounds.
    button.frame = CGRectMake(self.view.width - logo.size.width - kCorporateButtonMargin,
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
    // w2 is 3 at 0x8e634, which is LayoutSubviews together with AllowUserInteraction, with no ease
    // curve requested.
    [UIView animateWithDuration:kCorporateFadeDuration
        delay:kCorporateFadeDelay
        options:UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionAllowUserInteraction
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

- (void)closeItunesWithURL {
    /** @ghidraAddress 0x8d204 */
    [self productViewControllerDidFinish:self.itunesViewCtrl];
}

#pragma mark - Twitter

- (void)PostTwitter:(NSString *)text Images:(NSArray *)images URLs:(NSArray *)urls {
    /** @ghidraAddress 0x8d5b4 */
    if (![RBViewController hasTwitterAPI]) {
        return;
    }
    m_Tweeting = YES;
#ifdef ENABLE_PATCHES
    // iOS 11 removed the system Twitter account, so SLComposeViewController can no longer post.
    NSMutableArray *items = [NSMutableArray array];
    if (text) {
        [items addObject:text];
    }
    if (images) {
        [items addObjectsFromArray:images];
    }
    if (urls) {
        [items addObjectsFromArray:urls];
    }
    if (items.count == 0) {
        // UIActivityViewController raises on an empty item list.
        m_Tweeting = NO;
        self.tweetCoverView.hidden = YES;
        return;
    }
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:items
                                                                        applicationActivities:nil];
    // The share button is drawn by the GL scene, so the centre of the game view is the anchor.
    UIPopoverPresentationController *popover = share.popoverPresentationController;
    popover.sourceView = self.view;
    popover.sourceRect =
        CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0.0, 0.0);
    popover.permittedArrowDirections = kNoPopoverArrow;
    __weak RBViewController *weakSelf = self;
    share.completionWithItemsHandler =
        ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *error) {
          RBViewController *strongSelf = weakSelf;
          if (!strongSelf) {
              return;
          }
          strongSelf->m_Tweeting = NO;
          // The binary leaves the cover up until the next preview transition, stranding it over a
          // sheet dismissed in place.
          strongSelf.tweetCoverView.hidden = YES;
        };
    [self presentViewController:share animated:YES completion:nil];
#else
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
      // Like the binary, no nil check before the ivar store (a nil weakSelf would crash there too).
      RBViewController *strongSelf = weakSelf;
      strongSelf->m_Tweeting = NO;
    };
    [self presentViewController:compose animated:YES completion:nil];
#endif
}

- (void)PostTweet {
    /** @ghidraAddress 0x8d9c0 */
#ifdef ENABLE_PATCHES
    // -createImage is nullable and the binary's literal array would throw on a nil element.
    NSArray *images = self.tweetImage ? @[ self.tweetImage ] : @[];
    [self PostTwitter:self.tweetText Images:images URLs:nil];
#else
    [self PostTwitter:self.tweetText Images:@[ self.tweetImage ] URLs:nil];
#endif
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
#ifdef ENABLE_PATCHES
    // The probe requests http://twitter.com in the clear, which App Transport Security refuses.
    EnqueueImageCreaterOperation(self);
#else
    NSURL *url = [NSURL URLWithString:@"http://twitter.com"];
    // w3 is 4 at 0x8dd4c, which is ReloadIgnoringLocalAndRemoteCacheData, not the protocol default.
    self.twitterRequestTest =
        [[NSURLRequest alloc] initWithURL:url
                              cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                          timeoutInterval:kTwitterProbeTimeout];
    self.twitterConnectionTest = [[NSURLConnection alloc] initWithRequest:self.twitterRequestTest
                                                                 delegate:self];
#endif
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
    EnqueueImageCreaterOperation(self);
}

@end
