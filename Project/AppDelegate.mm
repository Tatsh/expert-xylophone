//
//  AppDelegate.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class AppDelegate).
//

#import "AppDelegate.h"

#import <stdlib.h>

#import <AVFoundation/AVFoundation.h>

#import "ApplilinkNetwork.h"
#import "AudioManager.h"
#import "NSFileManager+RB.h"
#import "RBCampaignData.h"
#import "RBMusicManager.h"
#import "RBNavigationController.h"
#import "RBPurchaseManager.h"
#import "RBUrlSchemeManager.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "UIAlertView+RB.h"
#import "neEngineBridge.h" // GetGameSystem() + the ne:: engine/sheet-layer/texture-cache helpers.
#import "neWindow.h"

/// GameScene state-machine value referenced at launch. The state enum lives with the GameScene class
/// (neEngineBridge.h); only the value used here is named.
enum { kGameSceneStateMusicSelect = 1 };

// Note-sheet layout geometry, recovered from the launch decompile. Float DAT_ values were read from
// the binary (0x1002ef180 = 96.0, 0x1002ef184 = 64.0, 0x1003ce930 = 1024).
static const float kSheetWidth = 70.0f;
static const float kSheetHeight = 25.0f;
static const float kSheetMarginX = 24.0f;
static const float kSheetMarginY = 22.0f;
static const float kSheetLayerRadius = 96.0f;
static const float kSheetCameraTargetY = -26.0f;
static const float kSheetVariantWidth = 640.0f;
static const float kSheetVariantMargin = 64.0f;
static const int kVariantScreenHeightPoints = 1024;
static const int kSheetVariantHeightInset = 44;

/// The reference (4") screen envelope, in points, that the standard sheet layout is clamped to, and
/// the 2x-pixel insets applied to the fitted sheet size.
static const int kReferenceScreenWidthPoints = 320;
static const int kReferenceScreenHeightPoints = 568;
static const int kRetinaScale = 2;
static const int kSheetSizeInsetX = 48;
static const int kSheetSizeInsetY = 98;

/// Launch miscellany: the render-loop period, the clear-gauge listener priority, and the initial
/// capacity of the pending-push-notification list.
static const float kGameLoopTimeMs = 1.0f;
static const int kClearGaugeListenerPriority = 1;
static const NSUInteger kPushListInitialCapacity = 3;

@implementation AppDelegate

#pragma mark - Class helpers

+ (instancetype)appDelegate {
    return (AppDelegate *)UIApplication.sharedApplication.delegate;
}

#pragma mark - Launch

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    InitializeDeviceEnvironment();

    // Grow the shared URL cache to disk-back it under Caches, keeping the memory cap at 0.
    NSURLCache *cache =
        [[NSURLCache alloc] initWithMemoryCapacity:0
                                      diskCapacity:NSURLCache.sharedURLCache.diskCapacity
                                          diskPath:GetCachesDirectoryPath()];
    [NSURLCache setSharedURLCache:cache];
    (void)NSURLCache.sharedURLCache;

    srand(arc4random());

    [AudioManager.sharedManager systemStart];

    GameSystem *gameSystem = GetGameSystem();

    CGRect screenBounds = UIScreen.mainScreen.bounds;
    gameSystem->SetScreenX(screenBounds.origin.x);
    gameSystem->SetScreenY(screenBounds.origin.y);
    gameSystem->SetScreenWidth(screenBounds.size.width);
    gameSystem->SetScreenHeight(screenBounds.size.height);
    if ([UIScreen.mainScreen respondsToSelector:@selector(scale)]) {
        gameSystem->SetScreenScale((float)UIScreen.mainScreen.scale);
    } else {
        gameSystem->SetScreenScale(1.0f);
    }

    // Ensure the private Documents directory exists and is excluded from backup.
    NSString *privateDocuments = GetPrivateDocumentsPath();
    if (![NSFileManager isDirectoryExist:privateDocuments] &&
        [NSFileManager createDirectory:privateDocuments]) {
        [AppDelegate setNoBackupAttribute:privateDocuments];
    }

    self.isSkipUpdate = NO;
    self.isUpdate = NO;

    LoadPlayerLevelData(GetLevelTablesInstance());

    // Seed the GameSystem from the persisted user settings.
    RBUserSettingData *settings = RBUserSettingData.sharedInstance;
    gameSystem->SetGameType(settings.gameType);
    gameSystem->SetDifficulty(settings.difficulty);
    gameSystem->SetDifficultyLevel(settings.difficultyLevel);
    gameSystem->SetPlayColor(settings.playColor);
    gameSystem->SetPlayerColor(settings.playerColor);
    gameSystem->SetRivalAlpha(settings.rivalAlpha);
    gameSystem->SetShotVolume(settings.shotVolume);
    gameSystem->SetBackgroundBrightness(settings.backgroundBrighness);
    gameSystem->SetShotType(settings.shotType);
    gameSystem->SetBgmType(settings.bgmType);
    gameSystem->SetFrameType(settings.frameType);
    gameSystem->SetExplosionType(settings.explosionType);
    gameSystem->SetBackgroundType(settings.backgroundType);
    gameSystem->SetNoteType(settings.noteType);
    gameSystem->SetCpuFullCombo(settings.cpuFullCombo);
    gameSystem->SetUserFullCombo(settings.userFullCombo);
    gameSystem->SetFullJustReflec(settings.fullJustReflec);

    [RBPurchaseManager.sharedManager start];
    [RBPurchaseManager.sharedManager loadProductList];
    [RBMusicManager.getInstance loadPurchasedMusics];
    [RBMusicManager.getInstance setMusicDataArrayDirty];

    // Lay out the note sheet against the screen. The font-variant (large-text) build uses a fixed
    // 640-wide sheet; the standard build fits the sheet to the screen, clamped to the 4" 640x1136
    // envelope (0x140 x 0x238 points).
    gameSystem->SetSheetWidth(kSheetWidth);
    gameSystem->SetSheetHeight(kSheetHeight);
    gameSystem->SetSheetLayerFlags(0);
    if (GetFontVariantFlag() == 0) {
        double shortEdge = MIN(screenBounds.size.width, screenBounds.size.height);
        double longEdge = MAX(screenBounds.size.width, screenBounds.size.height);
        int height =
            (int)longEdge <= kReferenceScreenHeightPoints ? (int)longEdge : kReferenceScreenHeightPoints;
        int width =
            (int)longEdge <= kReferenceScreenHeightPoints ? (int)shortEdge : kReferenceScreenWidthPoints;
        S_VECTOR2 sheetSize = {(float)(width * kRetinaScale - kSheetSizeInsetX),
                               (float)(height * kRetinaScale - kSheetSizeInsetY)};
        SetSheetLayerPosition(gameSystem, &sheetSize);
        SetSheetLayerMargins(kSheetMarginX, kSheetMarginY, kSheetMarginX, kSheetMarginY, gameSystem);
        SetSheetLayerRadius(kSheetLayerRadius, gameSystem);
        gameSystem->SetCameraTargetX(0.0f);
        gameSystem->SetCameraTargetY(kSheetCameraTargetY);
    } else {
        S_VECTOR2 sheetSize = {kSheetVariantWidth,
                               (float)(kVariantScreenHeightPoints - kSheetVariantHeightInset)};
        SetSheetLayerPosition(gameSystem, &sheetSize);
        SetSheetLayerMargins(kSheetVariantMargin, kSheetMarginY, kSheetVariantMargin, kSheetMarginY,
                             gameSystem);
        SetSheetLayerRadius(kSheetVariantMargin, gameSystem);
        gameSystem->SetCameraTargetX(0.0f);
        gameSystem->SetCameraTargetY(0.0f);
    }

    // Build the window, root view controller, and its (bar-hidden) navigation controller.
    self.window = [[neWindow alloc] initWithFrame:screenBounds];
    self.window.backgroundColor = UIColor.blackColor;
    self.viewController = [[RBViewController alloc] init];
    self.navigationController =
        [[RBNavigationController alloc] initWithRootViewController:self.viewController];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];

    // Bring up the touch manager, texture caches, and the persistent clear-gauge render layer, then
    // start the view controller's 60 fps game loop.
    EnsureTouchManagerSingleton();
    EnsureTextureCacheList();
    EnsureTextureCacheSingleton(0);
    ClearGaugeLayer *clearGauge = new ClearGaugeLayer();
    InsertSortedListenerNode(clearGauge, kClearGaugeListenerPriority);
    [self.viewController SetLoopTimeMilliSec:kGameLoopTimeMs];
    [self.viewController StartLoop];

    self.strageAlertView = [UIAlertView strageAlertView];
    self.packIDForOpenStore = nil;
    self.campaignIDForOpenStore = nil;
    self.extendNotePIDForOpenStore = nil;

    // News-info and terms endpoint URLs, built against the current API host.
    self.urlBaseWebInfo = [NSURL
        URLWithString:[NSString stringWithFormat:@"https://%@/akx/main/news/info.jsp?target=JP",
                                                 GetApiHostString()]];
    self.urlPreWebInfo = [NSURL
        URLWithString:[NSString
                          stringWithFormat:@"https://%@/akx/main/news/passed_info.jsp?target=JP",
                                           GetApiHostString()]];
    self.urlBaseTerm = [NSURL
        URLWithString:[NSString stringWithFormat:@"https://%@/akx/main/cgi/v3/terms/",
                                                 GetApiHostString()]];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(audioSessionInterrupted:)
                                               name:AVAudioSessionInterruptionNotification
                                             object:AVAudioSession.sharedInstance];

    [self startRegisterForRemoteNotification];

    // A remote notification that launched the app is handed straight to the URL-scheme router.
    NSDictionary *remote = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remote) {
        [RBUrlSchemeManager.sharedManager parseURL:remote[@"url"]];
    }

    self.pushList = [[NSMutableArray alloc] initWithCapacity:kPushListInitialCapacity];

    // A local notification that launched the app is cancelled and its body/sound/url captured.
    UILocalNotification *local = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];
    if (local) {
        [UIApplication.sharedApplication cancelLocalNotification:local];
        [self.pushList addObject:@{
            @"body" : local.alertBody,
            @"sound" : local.soundName,
            @"url" : local.userInfo[@"url"],
        }];
    }

    [RBCampaignData.sharedInstance presetHinabitaMode];
    return YES;
}

#pragma mark - Lifecycle

- (void)applicationDidBecomeActive:(UIApplication *)application {
    GameSystem *gameSystem = GetGameSystem();
    GameScene *scene = gameSystem->GetCurrentScene();
    if (scene) {
        AdvanceGameSceneStateFrom11(scene);
    }
    [AudioManager.sharedManager systemResume];
    [self.viewController RestartLoop];

    // Warn once about low free space, unless the alert is already visible.
    if (![NSFileManager isFreeSystemSize] && !self.strageAlertView.isVisible) {
        [self.strageAlertView show];
    }

    // If a store deep-link was queued and the music-select menu is active, jump to the store button.
    if (scene && scene->GetState() == kGameSceneStateMusicSelect &&
        (self.packIDForOpenStore || self.campaignIDForOpenStore || self.extendNotePIDForOpenStore)) {
        [self.viewController.musicMenuView SelectStoreButton];
    }

    // A pending mandatory update prompts the "please update" alert on foreground.
    if (self.isUpdate && !self.isSkipUpdate) {
        [UIAlertView showAlertLatestApplication:self];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    GameSystem *gameSystem = GetGameSystem();
    GameScene *scene = gameSystem->GetCurrentScene();
    if (scene) {
        PausePlayTimerAndBgm(scene);
    }
    [AudioManager.sharedManager systemSuspend];
    [self.viewController ResumeLoop];
    [self.viewController mainLoop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if (!self.isShowedMap) {
        LoadAllCachedTextures();
    }
    [ApplilinkNetwork resume];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [RBUserSettingData.sharedInstance save];
    if (!self.isShowedMap) {
        ReleaseAllCachedTextures();
    }
    if (self.viewController) {
        [self.viewController closeItunes];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    if (self.resourceDownloadViewController) {
        [self.resourceDownloadViewController pause];
    }
    [RBUserSettingData.sharedInstance save];
}

@end

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
