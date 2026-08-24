//
//  AppDelegate.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class AppDelegate).
//

#import "AppDelegate.h"

#import <stdlib.h>
#import <sys/xattr.h>

#import <AVFoundation/AVFoundation.h>
#import <Security/Security.h>

#import "ApplilinkNetwork.h"
#import "AudioManager.h"
#import "DownloadResourceManager.h"
#import "Downloader.h"
#import "GameSystem/src/OpenGL/neTexture.h"
#import "MusicData.h"
#import "NSFileManager+RB.h"
#import "NetworkUtil.h"
#import "RBCampaignData.h"
#import "RBGameKitManager.h"
#import "RBMenuView.h"
#import "RBMusicManager.h"
#import "RBNavigationController.h"
#import "RBPurchaseManager.h"
#import "RBResourceDownloadViewController.h"
#import "RBUrlSchemeManager.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "RecommendNetwork.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "ctask.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "engineruntime.h"
#import "game_scene.h"
#import "gamesystem.h"
#import "leveltables.h"
#import "logo_scene.h"
#import "neDebugLog.h"
#import "neWindow.h"
#import "playtimer.h"
#import "s_vector2.h"
#import "sheetlayer.h"
#import "touchmanager.h"

// Messaged from the startup-request success block, which the binary emits inline there.
@interface AppDelegate ()
- (void)setPreWebInfoURL:(nullable NSString *)preWebInfoURL;
@end

// rb::GameScene state-machine value referenced at launch. The state enum lives with the
// rb::GameScene class; only the value used here is named.
enum { kGameSceneStateMusicSelect = 1 };

// Note-sheet layout geometry, recovered from the launch decompile. Float DAT_ values were read from
// the binary (0x1002ef180 = 96.0, 0x1002ef184 = 64.0, 0x1003ce930 = 1024).
static constexpr float kSheetWidth = 70.0f;
static constexpr float kSheetHeight = 25.0f;
static constexpr float kSheetMarginX = 24.0f;
static constexpr float kSheetMarginY = 22.0f;
static constexpr float kSheetLayerRadius = 96.0f;
static constexpr float kSheetCameraTargetY = -26.0f;
static constexpr float kSheetVariantWidth = 640.0f;
static constexpr float kSheetVariantMargin = 64.0f;
static constexpr int kVariantScreenHeightPoints = 1024;
static constexpr int kSheetVariantHeightInset = 44;

// The reference (4") screen envelope, in points, that the standard sheet layout is clamped to, and
// the 2x-pixel insets applied to the fitted sheet size.
static constexpr int kReferenceScreenWidthPoints = 320;
static constexpr int kReferenceScreenHeightPoints = 568;
static constexpr int kRetinaScale = 2;
static constexpr int kSheetSizeInsetX = 48;
static constexpr int kSheetSizeInsetY = 98;

// Launch miscellany: the render-loop period, the logo-scene listener priority, and the initial
// capacity of the pending-push-notification list.
static constexpr float kGameLoopTimeMs = 1.0f;
static constexpr int kLogoSceneListenerPriority = 1;
static constexpr NSUInteger kPushListInitialCapacity = 3;

// The App Store product page for REFLEC BEAT plus, opened by @c -launchAppStore.
static NSString *const kAppStoreURLString =
    @"https://itunes.apple.com/jp/app/reflec-beat-plus/id472140433?mt=8";

// Server-data placeholder strings rejected before remote-notification registration: a usable value
// must be neither nil nor either textual form of "null".
static NSString *const kNullPlaceholder = @"null";
static NSString *const kNullPlaceholderDescription = @"(null)";

// The Keychain generic-password account name and the field separator backing @c +getServerData.
static NSString *const kServerIdKeychainAccount = @"ReflecBeatPlusServerID";
static NSString *const kServerDataSeparator = @"@@@";

// The number of @c "@@@"-separated fields a valid server-data value holds: the user identifier and
// its paired token. Remote-notification registration is skipped unless both are present.
static constexpr NSUInteger kServerDataFieldCount = 2;

// Indices into the @c "@@@"-separated server-data pair returned by @c +getServerData.
enum { kServerDataUserIdIndex = 0, kServerDataTokenIndex = 1 };

// The minimum iOS version supporting the do-not-back-up extended attribute, and the attribute name
// itself, used by @c +setNoBackupAttribute:.
static NSString *const kMinSystemVersionForNoBackup = @"5.0.1";

// The minimum iOS version the keychain accessibility attribute is set on, used by
// @c +setServerData:andB:. It is a different version from the do-not-back-up one above.
static NSString *const kMinSystemVersionForKeychainAccessible = @"4.0";

// The keychain account name the music-list key is stored under, and the empty string the binary
// files as that item's label and description.
static NSString *const kApplicationUniqueIDAccount = @"ApplicationUniqueID";
static NSString *const kEmptyKeychainAttribute = @"";

#ifdef ENABLE_PATCHES
// Spelled the way CFUUIDCreateString spells one, so nothing downstream special-cases it.
static NSString *const kFixedMusicListKey = @"00000000-0000-0000-0000-000000000000";
#endif
static constexpr char kDoNotBackUpXattrName[] = "com.apple.MobileBackup";

// The value written into the do-not-back-up extended attribute to mark a file as excluded.
static constexpr uint8_t kDoNotBackUpXattrValue = 1;

// The Applilink application identifier and server environment ("0" is production) passed at init.
static NSString *const kApplilinkAppId = @"10";
static NSString *const kApplilinkEnv = @"0";

// The ad-location the recommend-unread-count fetch queries.
static NSString *const kRecommendUnreadAdLocation = @"ADL_MYPAGE";

// The total-score leaderboard category identifiers for the two device idioms.
static NSString *const kTotalScoreLeaderboardPad = @"rbplus.totalscore";
static NSString *const kTotalScoreLeaderboardPhone = @"rbplus.totalscorephone";

// The delay before the theme title layer is built, and the corporate-button target fade alpha.
static constexpr int64_t kTitleLayerBuildDelayNs = 100000000;
static constexpr float kCorporateButtonFadeAlpha = 1.0f;

// The terms-URL format (base, region, terms id), the bonus-list music-id key format, and the fixed
// save-data passphrase.
static NSString *const kTermURLFormat = @"%@/?target=%@&type=%@";
static NSString *const kBonusListKeyFormat = @"%d";
static NSString *const kSaveDataPassphrase = @"Copyright 2014 KDE.";

// The interruption-type key, spelled as a literal rather than referencing AVFoundation's
// AVAudioSessionInterruptionTypeKey symbol, which is what the binary does.
static NSString *const kAudioSessionInterruptionTypeKey = @"AVAudioSessionInterruptionTypeKey";

// The device OS versions whose timing behaviour differs, compared numerically at startup.
static NSString *const kOsVersion80 = @"8.0";
static NSString *const kOsVersion81 = @"8.1";

// The resource-info request payload keys.
static NSString *const kResourceInfoKeyTarget = @"target";
static NSString *const kResourceInfoKeyVersion = @"version";
static NSString *const kResourceInfoKeyUserID = @"user_id";
static NSString *const kResourceInfoKeyPasswd = @"passwd";
static NSString *const kResourceInfoKeyUUID = @"uuid";

// The startup response JSON keys and the mandatory-update-off flag value.
static NSString *const kStartupKeyVersion = @"Version";
static NSString *const kStartupKeyItemURL = @"ItemURL";
static NSString *const kStartupKeyType = @"Type";
static NSString *const kStartupKeyApp = @"App";
static NSString *const kStartupKeyUserID = @"UserID";
static NSString *const kStartupKeyPasswd = @"Passwd";
static NSString *const kStartupKeyCol = @"Col";
static NSString *const kStartupKeyTermsVersion = @"terms_version";
static NSString *const kMustUpdateFlagOff = @"0";

// The alert-view tags that route the delegate callback.
static const NSInteger kResourceUpdateAlertTag = 2;
static const NSInteger kNewVersionAlertTag = 3;
static const NSInteger kStartupNetworkErrorTag = 10;

// The web-info response JSON keys, its timestamp format, and the epoch fallback used when the
// stored timestamp cannot be parsed.
static NSString *const kWebInfoKeyURL = @"URL";
static NSString *const kWebInfoKeyUpdateTime = @"UpdateTime";
static NSString *const kWebInfoKeyAnotherURL = @"AnotherURL";
static NSString *const kWebInfoDateFormat = @"YYYYMMddHHmm";
static NSString *const kWebInfoEpochFallback = @"200001010000";

@implementation AppDelegate

#pragma mark - Class helpers

+ (void)initialize {
    /** @ghidraAddress 0x4d778 */
    // The binary's body is empty; it establishes no one-time state.
}

+ (instancetype)appDelegate {
    return static_cast<AppDelegate *>(UIApplication.sharedApplication.delegate);
}

+ (NSArray *)getServerData {
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;

    // First pass: fetch the generic-password item's attributes for this app's server-ID account.
    // Built with the nil-terminated variadic constructor, not a dictionary literal, which would
    // send +dictionaryWithObjects:forKeys:count: instead.
    NSDictionary *attributeQuery =
        [NSDictionary dictionaryWithObjectsAndKeys:(__bridge id)kSecClassGenericPassword,
                                                   (__bridge id)kSecClass,
                                                   kServerIdKeychainAccount,
                                                   (__bridge id)kSecAttrAccount,
                                                   bundleIdentifier,
                                                   (__bridge id)kSecAttrService,
                                                   (__bridge id)kSecMatchLimitOne,
                                                   (__bridge id)kSecMatchLimit,
                                                   (__bridge id)kCFBooleanTrue,
                                                   (__bridge id)kSecReturnAttributes,
                                                   nil];
    CFTypeRef attributesResult = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)attributeQuery, &attributesResult) !=
        errSecSuccess) {
        return nil;
    }
    NSDictionary *attributes = (__bridge_transfer NSDictionary *)attributesResult;

    // Second pass: re-query with those attributes to retrieve the stored password bytes.
    NSMutableDictionary *dataQuery = [NSMutableDictionary dictionaryWithDictionary:attributes];
    // -setObject:forKey:, not the subscript form, which would send -setObject:forKeyedSubscript:.
    [dataQuery setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [dataQuery setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    CFTypeRef dataResult = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)dataQuery, &dataResult) != errSecSuccess) {
        return nil;
    }
    NSData *storedData = (__bridge_transfer NSData *)dataResult;

    NSString *joined = [[NSString alloc] initWithBytes:storedData.bytes
                                                length:storedData.length
                                              encoding:NSUTF8StringEncoding];
    if (!joined) {
        return nil;
    }
    return [joined componentsSeparatedByString:kServerDataSeparator];
}

+ (BOOL)setNoBackupAttribute:(NSString *)path {
    // The com.apple.MobileBackup exclude-from-backup attribute only exists on iOS 5.0.1 and later.
    if ([UIDevice.currentDevice.systemVersion compare:kMinSystemVersionForNoBackup
                                              options:NSNumericSearch] == NSOrderedAscending) {
        return NO;
    }
    uint8_t excludeValue = kDoNotBackUpXattrValue;
    return setxattr(
               path.UTF8String, kDoNotBackUpXattrName, &excludeValue, sizeof(excludeValue), 0, 0) ==
           0;
}

#pragma mark - Launch

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // RBPDBG: stamp the build's git SHA at startup so any captured log identifies exactly which
    // build produced it. idevicesyslog | grep RBPDBG.
    neDebugLog("build sha=%s", RBPDBG_BUILD_SHA);

    InitializeDeviceEnvironment();

    // RBPDBG: the keychain key whose MD5 is the BFCodec key for the purchased-content lists
    // (mulist, prodlist, nolist), so those blobs can be decrypted offline, plus the resolved
    // filesystem paths and the free-space reading. The keychain query and the volume stat are real
    // side effects, so they stay inside the block that compiles away entirely.
    if (NE_DBG_FIRST(1)) {
        NSString *listKey = [AppDelegate musicListKey];
        neDebugLog("mulist/prodlist key uuid=%s", listKey.length ? listKey.UTF8String : "(nil)");
        neDebugLog("documents=%s", GetDocumentsDirectoryPath().UTF8String);
        neDebugLog("privateDocuments=%s", GetPrivateDocumentsPath().UTF8String);
        neDebugLog("imageAssets=%s", GetImageAssetDirectoryPath().UTF8String);
        neDebugLog("download=%s", GetDownloadDirectoryPath().UTF8String);
        neDebugLog("caches=%s", GetCachesDirectoryPath().UTF8String);
        neDebugLog("freeBytes=%llu overThreshold=%d",
                   [NSFileManager freeFileSystemSize],
                   [NSFileManager isFreeSystemSize] ? 1 : 0);
        neDebugLog("isPad=%d screen=%.0fx%.0f scale=%.1f",
                   IsPad() ? 1 : 0,
                   UIScreen.mainScreen.bounds.size.width,
                   UIScreen.mainScreen.bounds.size.height,
                   UIScreen.mainScreen.scale);
        // The theme selects which of the three title scenes runs.
        neDebugLog("thema=%d", static_cast<int>(RBUserSettingData.sharedInstance.thema));
    }

    // Grow the shared URL cache to disk-back it under Caches, keeping the memory cap at 0.
    NSURLCache *cache =
        [[NSURLCache alloc] initWithMemoryCapacity:0
                                      diskCapacity:NSURLCache.sharedURLCache.diskCapacity
                                          diskPath:GetCachesDirectoryPath()];
    [NSURLCache setSharedURLCache:cache];
    (void)NSURLCache.sharedURLCache;

    srand(arc4random());

    [AudioManager.sharedManager systemStart];

    GameSystem *gameSystem = GameSystem::GetGameSystem();

    CGRect screenBounds = UIScreen.mainScreen.bounds;
    gameSystem->SetScreenX(screenBounds.origin.x);
    gameSystem->SetScreenY(screenBounds.origin.y);
    gameSystem->SetScreenWidth(screenBounds.size.width);
    gameSystem->SetScreenHeight(screenBounds.size.height);
    if ([UIScreen.mainScreen respondsToSelector:@selector(scale)]) {
        gameSystem->SetScreenScale(static_cast<float>(UIScreen.mainScreen.scale));
    } else {
        gameSystem->SetScreenScale(1.0f);
    }

    // The GL layers, including the title screen's parts, position themselves from these values
    // rather than from any UIKit view's bounds.
    neDebugLog("gameSystemScreen=(%.0f,%.0f %.0fx%.0f) scale=%.2f",
               gameSystem->GetScreenX(),
               gameSystem->GetScreenY(),
               gameSystem->GetScreenWidth(),
               gameSystem->GetScreenHeight(),
               gameSystem->GetScreenScale());

    // Ensure the private Documents directory exists and is excluded from backup.
    NSString *privateDocuments = GetPrivateDocumentsPath();
    if (![NSFileManager isDirectoryExist:privateDocuments] &&
        [NSFileManager createDirectory:privateDocuments]) {
        [AppDelegate setNoBackupAttribute:privateDocuments];
    }

    self.isSkipUpdate = NO;
    self.isUpdate = NO;

    LevelTables::LoadPlayerLevelData(LevelTables::GetInstance()->GetLevelExpRecord());

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

    // Lay out the note sheet against the screen. The iPad idiom (large-text) build uses a fixed
    // 640-wide sheet; the standard build fits the sheet to the screen, clamped to the 4" 640x1136
    // envelope (0x140 x 0x238 points).
    gameSystem->SetSheetWidth(kSheetWidth);
    gameSystem->SetSheetHeight(kSheetHeight);
    gameSystem->SetSheetLayerFlags(0);
    if (!IsPad()) {
        double shortEdge = MIN(screenBounds.size.width, screenBounds.size.height);
        double longEdge = MAX(screenBounds.size.width, screenBounds.size.height);
        int height = static_cast<int>(longEdge) <= kReferenceScreenHeightPoints ?
                         static_cast<int>(longEdge) :
                         kReferenceScreenHeightPoints;
        int width = static_cast<int>(longEdge) <= kReferenceScreenHeightPoints ?
                        static_cast<int>(shortEdge) :
                        kReferenceScreenWidthPoints;
        S_VECTOR2 sheetSize{static_cast<float>(width * kRetinaScale - kSheetSizeInsetX),
                            static_cast<float>(height * kRetinaScale - kSheetSizeInsetY)};
        gameSystem->SetSheetLayerPosition(&sheetSize);
        gameSystem->SetSheetMargins(kSheetMarginX, kSheetMarginY, kSheetMarginX, kSheetMarginY);
        gameSystem->SetSheetRadius(kSheetLayerRadius);
        gameSystem->SetCameraTargetX(0.0f);
        gameSystem->SetCameraTargetY(kSheetCameraTargetY);
    } else {
        S_VECTOR2 sheetSize{
            kSheetVariantWidth,
            static_cast<float>(kVariantScreenHeightPoints - kSheetVariantHeightInset)};
        gameSystem->SetSheetLayerPosition(&sheetSize);
        gameSystem->SetSheetMargins(
            kSheetVariantMargin, kSheetMarginY, kSheetVariantMargin, kSheetMarginY);
        gameSystem->SetSheetRadius(kSheetVariantMargin);
        gameSystem->SetCameraTargetX(0.0f);
        gameSystem->SetCameraTargetY(0.0f);
    }

    // Build the window, root view controller, and its (bar-hidden) navigation controller.
    self.window = [[neWindow alloc] initWithFrame:screenBounds];
    self.window.backgroundColor = UIColor.blackColor;
#ifdef ENABLE_PATCHES
    // The app predates dark mode by years and has no dark assets, and iOS 15 additionally makes an
    // unconfigured bar transparent at its scroll edge, which shows this black window straight
    // through the store's navigation and tab bars — the bars then appear to flip between black and
    // light as the content behind them scrolls. Pin the window light and give both bar kinds an
    // opaque background so they stay light whatever is under them. The Info.plist's
    // UIUserInterfaceStyle covers the first half of this; the appearance proxies are what stop the
    // bars going transparent, and they must be set before any store view controller is built.
    if (@available(iOS 13.0, *)) {
        self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;

        UINavigationBarAppearance *navigationAppearance = [[UINavigationBarAppearance alloc] init];
        [navigationAppearance configureWithOpaqueBackground];
        UINavigationBar.appearance.standardAppearance = navigationAppearance;
        UINavigationBar.appearance.scrollEdgeAppearance = navigationAppearance;

        UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
        [tabAppearance configureWithOpaqueBackground];
        UITabBar.appearance.standardAppearance = tabAppearance;
        if (@available(iOS 15.0, *)) {
            UITabBar.appearance.scrollEdgeAppearance = tabAppearance;
        }

        // The playlist popover's sort row sits in a toolbar, which keeps the modern transparent
        // scroll-edge appearance and so loses the separating shadow line the original draws.
        UIToolbarAppearance *toolbarAppearance = [[UIToolbarAppearance alloc] init];
        [toolbarAppearance configureWithOpaqueBackground];
        UIToolbar.appearance.standardAppearance = toolbarAppearance;
        if (@available(iOS 15.0, *)) {
            UIToolbar.appearance.scrollEdgeAppearance = toolbarAppearance;
        }
    }
#endif
    self.viewController = [[RBViewController alloc] init];
    self.navigationController =
        [[RBNavigationController alloc] initWithRootViewController:self.viewController];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];

    // Bring up the touch manager and texture caches, register the startup listener, then start the
    // view controller's 60 fps game loop.
    TouchManager::EnsureSingleton();
    ne::C_TEXTURE::EnsureCacheList();
    ne::C_TEXTURE::EnsureCacheControl(0);
    // The launch handler builds the logo scene and registers it in the sorted listener list; it is
    // a BaseScene, so the listener node is a real base and InsertSorted is inherited.
    (new rb::LogoScene())->InsertSorted(kLogoSceneListenerPriority);
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
    // The terms endpoint is stored as a string, not wrapped in an NSURL like the two above.
    self.urlBaseTerm =
        [NSString stringWithFormat:@"https://%@/akx/main/cgi/v3/terms/", GetApiHostString()];

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
    GameSystem *gameSystem = GameSystem::GetGameSystem();
    rb::GameScene *scene = gameSystem->GetCurrentScene();
    if (scene) {
        scene->AdvanceGameSceneStateFrom11();
    }
    [AudioManager.sharedManager systemResume];
    [self.viewController RestartLoop];

    // Warn once about low free space, unless the alert is already visible.
    if (![NSFileManager isFreeSystemSize] && !self.strageAlertView.isVisible) {
        [self.strageAlertView show];
    }

    // If a store deep-link was queued and the music-select menu is active, jump to the store
    // button.
    if (scene && scene->GetState() == kGameSceneStateMusicSelect &&
        (self.packIDForOpenStore || self.campaignIDForOpenStore ||
         self.extendNotePIDForOpenStore)) {
        [self.viewController.musicMenuView SelectStoreButton];
    }

    // A pending mandatory update prompts the "please update" alert on foreground.
    if (self.isUpdate && !self.isSkipUpdate) {
        [UIAlertView showAlertLatestApplication:self];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    GameSystem *gameSystem = GameSystem::GetGameSystem();
    rb::GameScene *scene = gameSystem->GetCurrentScene();
    if (scene) {
        scene->PausePlayTimerAndBgm();
    }
    [AudioManager.sharedManager systemSuspend];
    [self.viewController ResumeLoop];
    [self.viewController mainLoop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if (!self.isShowedMap) {
        ne::C_TEXTURE::ReloadAll();
    }
    [ApplilinkNetwork resume];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [RBUserSettingData.sharedInstance save];
    if (!self.isShowedMap) {
        ne::C_TEXTURE::ReleaseAllHandles();
    }
    if (self.viewController) {
        [self.viewController closeItunesWithURL];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    if (self.resourceDownloadViewController) {
        [self.resourceDownloadViewController pause];
    }
    [RBUserSettingData.sharedInstance save];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [RBMusicManager.getInstance releaseChacheMusicData];
}

- (void)applicationSignificantTimeChange:(UIApplication *)application {
}

- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application {
}

- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application {
}

#pragma mark - Audio session

- (void)audioSessionInterrupted:(NSNotification *)notification {
    // The boxed value is unwrapped once per comparison, not held in a local.
    NSNumber *type = [notification.userInfo objectForKey:kAudioSessionInterruptionTypeKey];
    if (type.unsignedIntegerValue == AVAudioSessionInterruptionTypeBegan) {
        [AudioManager.sharedManager systemSuspend];
    } else if (type.unsignedIntegerValue == AVAudioSessionInterruptionTypeEnded) {
        [AudioManager.sharedManager systemResume];
    }
}

#pragma mark - URL handling

- (BOOL)application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation {
    // A hostless URL is accepted but not routed: there is nothing for the scheme manager to parse.
    if (url.host == nil) {
        return YES;
    }
    return [RBUrlSchemeManager.sharedManager parseURL:url];
}

#pragma mark - Remote and local notifications

- (void)startRegisterForRemoteNotification {
    // Registration is gated on a valid server-data pair; a missing or "null" placeholder aborts it.
    NSArray *serverData = [AppDelegate getServerData];
    // The nil test is its own branch, so -count is never sent to nil.
    if (serverData == nil || serverData.count != kServerDataFieldCount) {
        return;
    }
    NSString *first = serverData[kServerDataUserIdIndex];
    NSString *second = serverData[kServerDataTokenIndex];
    if (!first || [first isEqualToString:kNullPlaceholderDescription] ||
        [first isEqualToString:kNullPlaceholder] || !second ||
        [second isEqualToString:kNullPlaceholderDescription] ||
        [second isEqualToString:kNullPlaceholder]) {
        return;
    }

    // Each arm fetches the shared application itself; in the newer arm that happens after the
    // settings object is built, not before the branch.
    if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_1) {
        [UIApplication.sharedApplication
            registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge |
                                               UIRemoteNotificationTypeSound |
                                               UIRemoteNotificationTypeAlert];
    } else {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings
            settingsForTypes:UIUserNotificationTypeBadge | UIUserNotificationTypeSound |
                             UIUserNotificationTypeAlert
                  categories:nil];
        [UIApplication.sharedApplication registerUserNotificationSettings:settings];
    }
}

- (void)application:(UIApplication *)application
    didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    [application registerForRemoteNotifications];
}

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // Hexadecimal token string: strip the "<", ">", and spaces from -[NSData description].
    NSString *token = [[[deviceToken.description stringByReplacingOccurrencesOfString:@"<"
                                                                           withString:@""]
        stringByReplacingOccurrencesOfString:@">"
                                  withString:@""] stringByReplacingOccurrencesOfString:@" "
                                                                            withString:@""];

    // Upload the token with the region, bundle version, and the two server-data values as a JSON
    // POST.
    NSArray *serverData = [AppDelegate getServerData];
    NSDictionary *payload = @{
        @"target" : GetRegionCode(),
        @"version" : GetBundleVersionString(),
        @"p1" : serverData[kServerDataUserIdIndex],
        @"p2" : serverData[kServerDataTokenIndex],
        @"p3" : token,
    };
    NSData *json = [Downloader dictionaryToJsonData:payload];

    __weak AppDelegate *weakSelf = self;
    if (self.apnsUploader) {
        weakSelf.apnsUploader = nil;
    }
    weakSelf.apnsUploader = [[Downloader alloc] initWithURL:[NetworkUtil tokenSetURL]
                                                       post:json
                                                contentType:@"application/json"];
    // The uploader is released once the request settles (success or failure); progress is ignored.
    [weakSelf.apnsUploader
        startDownloadingWithProceed:^(Downloader *downloader) {
        }
        success:^(Downloader *downloader) {
          weakSelf.apnsUploader = nil;
        }
        failure:^(Downloader *downloader) {
          weakSelf.apnsUploader = nil;
        }];
}

- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
}

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSDictionary *aps = userInfo[@"aps"];
    [self.pushList addObject:@{
        @"body" : aps[@"alert"],
        @"sound" : aps[@"sound"],
        @"url" : userInfo[@"url"],
    }];

    // While the app is active on the music-select (or earlier) screen, surface the queued push
    // view.
    GameSystem *gameSystem = GameSystem::GetGameSystem();
    rb::GameScene *scene = gameSystem->GetCurrentScene();
    if (scene && application.applicationState == UIApplicationStateActive &&
        scene->GetState() <= kGameSceneStateMusicSelect && self.pushList.count > 0 &&
        self.viewController && self.viewController.musicMenuView) {
        [self.viewController.musicMenuView showPushNotificationView];
    }

    // Route the payload URL only while foreground (active or inactive), never when backgrounded.
    if (userInfo && application.applicationState <= UIApplicationStateInactive) {
        id urlString = userInfo[@"url"];
        if (urlString) {
            [RBUrlSchemeManager.sharedManager parseURL:[NSURL URLWithString:urlString]];
        }
    }
}

- (void)application:(UIApplication *)application
    didReceiveLocalNotification:(UILocalNotification *)notification {
    // The outer dictionary really is a literal here, but the userInfo lookup sends -objectForKey:.
    [self.pushList addObject:@{
        @"body" : notification.alertBody,
        @"sound" : notification.soundName,
        @"url" : [notification.userInfo objectForKey:@"url"],
    }];

    if (application.applicationState == UIApplicationStateActive && self.viewController &&
        self.viewController.musicMenuView) {
        [self.viewController.musicMenuView showPushNotificationView];
    }
}

#pragma mark - Status bar (no-op delegate overrides)

- (void)application:(UIApplication *)application
    willChangeStatusBarOrientation:(UIInterfaceOrientation)newStatusBarOrientation
                          duration:(NSTimeInterval)duration {
}

- (void)application:(UIApplication *)application
    didChangeStatusBarOrientation:(UIInterfaceOrientation)oldStatusBarOrientation {
}

- (void)application:(UIApplication *)application
    willChangeStatusBarFrame:(CGRect)newStatusBarFrame {
}

- (void)application:(UIApplication *)application didChangeStatusBarFrame:(CGRect)oldStatusBarFrame {
}

#pragma mark - Store

/** @ghidraAddress 0x53268 */
+ (void)launchAppStore {
    // Mark an update as in progress on the shared delegate, then open the store product page.
    AppDelegate.appDelegate.isUpdate = YES;
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:kAppStoreURLString]];
}

#pragma mark - Server data

/** @ghidraAddress 0x514c8 */
+ (BOOL)setServerData:(NSString *)p1 andB:(NSString *)p2 {
    // Only persist the pair on first run, when no server-data item exists yet.
    if ([AppDelegate getServerData] != nil) {
        return NO;
    }
    NSMutableDictionary *item =
        [NSMutableDictionary dictionaryWithObjectsAndKeys:(__bridge id)kSecClassGenericPassword,
                                                          (__bridge id)kSecClass,
                                                          kServerIdKeychainAccount,
                                                          (__bridge id)kSecAttrAccount,
                                                          NSBundle.mainBundle.bundleIdentifier,
                                                          (__bridge id)kSecAttrService,
                                                          kEmptyKeychainAttribute,
                                                          (__bridge id)kSecAttrLabel,
                                                          kEmptyKeychainAttribute,
                                                          (__bridge id)kSecAttrDescription,
                                                          nil];
    if ([UIDevice.currentDevice.systemVersion compare:kMinSystemVersionForKeychainAccessible
                                              options:NSNumericSearch] != NSOrderedAscending) {
        // -setObject:forKey:, not the subscript form, which sends -setObject:forKeyedSubscript:.
        [item setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock
                 forKey:(__bridge id)kSecAttrAccessible];
    }
    // The "@@@" separator is embedded in the format string, so only the two values are passed.
    NSString *joined = [NSString stringWithFormat:@"%@@@@%@", p1, p2];
    [item setObject:[joined dataUsingEncoding:NSUTF8StringEncoding]
             forKey:(__bridge id)kSecValueData];
    SecItemAdd((__bridge CFDictionaryRef)item, nullptr);
    return YES;
}

/** @ghidraAddress 0x50cb8 */
+ (NSString *)musicListKey {
#ifdef ENABLE_PATCHES
    // A fixed key, so the purchased-content lists are portable rather than tied to one install's
    // keychain. See PATCHES.md.
    return kFixedMusicListKey;
#else
    // Try to read the stored generic-password key for this app. The five pairs were read from the
    // stack setup at 0x50d90-0x50da8, not from a decompile, which shows only the first of them.
    // The bundle identifier is fetched again for the second dictionary further down, as here.
    NSDictionary *attributeQuery =
        [NSDictionary dictionaryWithObjectsAndKeys:(__bridge id)kSecClassGenericPassword,
                                                   (__bridge id)kSecClass,
                                                   kApplicationUniqueIDAccount,
                                                   (__bridge id)kSecAttrAccount,
                                                   NSBundle.mainBundle.bundleIdentifier,
                                                   (__bridge id)kSecAttrService,
                                                   (__bridge id)kSecMatchLimitOne,
                                                   (__bridge id)kSecMatchLimit,
                                                   (__bridge id)kCFBooleanTrue,
                                                   (__bridge id)kSecReturnAttributes,
                                                   nil];
    CFTypeRef attributesResult = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)attributeQuery, &attributesResult) ==
        errSecSuccess) {
        NSMutableDictionary *dataQuery = [NSMutableDictionary
            dictionaryWithDictionary:(__bridge NSDictionary *)attributesResult];
        // -setObject:forKey:, not the subscript form.
        [dataQuery setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
        [dataQuery setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
        CFTypeRef dataResult = nullptr;
        NSString *stored = nil;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)dataQuery, &dataResult) ==
            errSecSuccess) {
            NSData *data = (__bridge_transfer NSData *)dataResult;
            stored = [[NSString alloc] initWithBytes:data.bytes
                                              length:data.length
                                            encoding:NSUTF8StringEncoding];
        }
        if (stored) {
            return stored;
        }
    }

    // No key stored yet: generate a fresh UUID string and persist it as the generic password.
    CFUUIDRef uuid = CFUUIDCreate(nullptr);
    CFStringRef uuidString = CFUUIDCreateString(nullptr, uuid);
    NSString *key = [NSString stringWithString:(__bridge NSString *)uuidString];
    CFRelease(uuidString);
    CFRelease(uuid);

    // The five pairs here were likewise read from the stack setup at 0x50f9c-0x50fc4.
    NSMutableDictionary *item =
        [NSMutableDictionary dictionaryWithObjectsAndKeys:(__bridge id)kSecClassGenericPassword,
                                                          (__bridge id)kSecClass,
                                                          kApplicationUniqueIDAccount,
                                                          (__bridge id)kSecAttrAccount,
                                                          NSBundle.mainBundle.bundleIdentifier,
                                                          (__bridge id)kSecAttrService,
                                                          kEmptyKeychainAttribute,
                                                          (__bridge id)kSecAttrLabel,
                                                          kEmptyKeychainAttribute,
                                                          (__bridge id)kSecAttrDescription,
                                                          nil];
    if ([UIDevice.currentDevice.systemVersion compare:kMinSystemVersionForKeychainAccessible
                                              options:NSNumericSearch] != NSOrderedAscending) {
        [item setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock
                 forKey:(__bridge id)kSecAttrAccessible];
    }
    [item setObject:[key dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id)kSecValueData];
    SecItemAdd((__bridge CFDictionaryRef)item, nullptr);
    return key;
#endif
}

#pragma mark - Applilink

/** @ghidraAddress 0x50698 */
+ (void)ApplilinkInitialize {
    // Only initialise when server data (a KONAMI ID login) is present; otherwise mark
    // uninitialised. The binary re-sends +getServerData for the element read rather than holding
    // the array in a local.
    if ([AppDelegate getServerData] != nil &&
        [AppDelegate getServerData][kServerDataUserIdIndex] != nil) {
        [ApplilinkNetwork
            initializeWithAppliId:kApplilinkAppId
                              env:kApplilinkEnv
                         callback:^(NSError *error) {
                           /** @ghidraAddress 0x507c8 */
                           if (error == nil) {
                               [ApplilinkNetwork
                                   setUserId:[AppDelegate getServerData][kServerDataUserIdIndex]];
                               [AppDelegate setRecommendUnreadCount];
                               AppDelegate.appDelegate.applilinkInitialized = YES;
                           } else {
                               AppDelegate.appDelegate.applilinkInitialized = NO;
                           }
                         }];
        return;
    }
    AppDelegate.appDelegate.applilinkInitialized = NO;
}

/** @ghidraAddress 0x50920 */
+ (void)setRecommendUnreadCount {
    // The binary re-sends +getServerData for the element read rather than holding it in a local.
    if ([AppDelegate getServerData] == nil ||
        [AppDelegate getServerData][kServerDataUserIdIndex] == nil) {
        return;
    }
    [RecommendNetwork getUnreadCountWithAdModel:RecommendAdModelAppList
                                     adLocation:kRecommendUnreadAdLocation
                                       callback:^(NSInteger status, NSError *error) {
                                         /** @ghidraAddress 0x50a20 */
                                         // The count field is four bytes in the binary, so the
                                         // callback's wider status narrows on the way in.
                                         AppDelegate.appDelegate.unreadRecommendCount =
                                             static_cast<int>(error == nil ? status : 0);
                                       }];
}

#pragma mark - Leaderboard

/** @ghidraAddress 0x50c8c */
+ (NSString *)totalScoreLeaderboardCategory {
    return IsPad() ? kTotalScoreLeaderboardPad : kTotalScoreLeaderboardPhone;
}

#pragma mark - Title

/** @ghidraAddress 0x51828 */
- (void)resetGame {
    __weak AppDelegate *weakSelf = self;
    [self.viewController.musicMenuView hideAnimation:^{
      /** @ghidraAddress 0x51978 */
      // Cycle the whole texture cache to reclaim GPU memory, then rebuild the title. Each use of
      // weakSelf reloads the weak reference; the binary holds no strong local across the body.
      [UIImage clearImageCache];
      ne::C_TEXTURE::GetCacheList();
      ne::C_TEXTURE::ReleaseAllHandles();
      ne::C_TEXTURE::GetCacheList();
      ne::C_TEXTURE::ReloadAll();
      [weakSelf.viewController removeView];
      RBCampaignData.sharedInstance.hinabitaMode = 0;
      [weakSelf showTitle];
      [weakSelf.viewController SetLoopTimeMilliSec:kGameLoopTimeMs];
      [weakSelf.viewController StartLoop];
      rb::GameScene *scene = GameSystem::GetGameSystem()->GetCurrentScene();
      if (scene) {
          scene->ClearLayerStateField();
          scene->AdvanceGameSceneStateFrom11();
      }
      [AudioManager.sharedManager systemResume];
      [weakSelf.viewController RestartLoop];
    }];
}

/** @ghidraAddress 0x4f7e0 */
- (void)showTitle {
    [RBGameKitManager.sharedInstance loginGameCenter];
    [AppDelegate ApplilinkInitialize];
    if (self.resourceDownloadViewController) {
        self.resourceDownloadViewController = nil;
    }
    [self.viewController UpdateProjection];

    // Reset the play-field effect sizes to their defaults and persist.
    RBUserSettingData.sharedInstance.explosionEffectSize = g_flDefaultExplosionEffectSize;
    RBUserSettingData.sharedInstance.boundsEffectSize = 1.0f;
    RBUserSettingData.sharedInstance.damageEffectSize = 1.0f;
    [RBUserSettingData.sharedInstance save];

    // Build the theme title layer shortly after, then request the startup / web-info data.
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, kTitleLayerBuildDelayNs), dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x4fa24 */
          CreateTitleLayerForTheme();
        });
    [self startupRequest];
    [self.viewController fadeCorporateButton:kCorporateButtonFadeAlpha];
}

/** @ghidraAddress 0x4fb4c */
- (void)startupRequest {
    // The receiver comes from +appDelegate and is held weakly; the binary never touches self here.
    __weak AppDelegate *weakSelf = AppDelegate.appDelegate;
    // Cancel any in-flight startup download before issuing a fresh one.
    if (weakSelf.downloader) {
        [weakSelf.downloader cancel];
        weakSelf.downloader = nil;
    }
    weakSelf.downloader = [[Downloader alloc] initWithURL:[NetworkUtil startupURL] save:nil];
    [weakSelf.downloader
        startDownloadingWithProceed:^(Downloader *downloader) {
          /** @ghidraAddress 0x4fde8 */
          // The proceed handler is empty.
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x4fdec */
          NSDictionary *json = [downloader getDataInJSON];
          NSString *url = json[kWebInfoKeyURL];
          NSString *updateTime = json[kWebInfoKeyUpdateTime];
          NSString *lastRead = RBUserSettingData.sharedInstance.infoLastReadTimeString;
          [weakSelf setPreWebInfoURL:json[kWebInfoKeyAnotherURL]];

          NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
          formatter.dateFormat = kWebInfoDateFormat;
          if (lastRead == nil) {
              // No prior read: adopt the served info unconditionally.
              [weakSelf setWebInfoURL:url];
              weakSelf.infoLastUpdateTimeString = updateTime;
          } else {
              NSDate *last = [formatter dateFromString:lastRead];
              if (last == nil) {
                  last = [formatter dateFromString:kWebInfoEpochFallback];
              }
              NSDate *served = [formatter dateFromString:updateTime];
              // Adopt the served info only when it is newer than what was last read.
              if ([last compare:served] == NSOrderedAscending) {
                  [weakSelf setWebInfoURL:url];
                  weakSelf.infoLastUpdateTimeString = updateTime;
              }
          }

          // Rebuild the base web-info URL from the served URL's scheme, host, and path.
          NSURL *served = [NSURL URLWithString:url];
          NSString *base =
              [NSString stringWithFormat:@"%@://%@%@", served.scheme, served.host, served.path];
          weakSelf.urlBaseWebInfo = [NSURL URLWithString:base];
        }
        failure:^(Downloader *downloader){
            /** @ghidraAddress 0x50394 */
            // The failure handler is empty.
        }];
}

/** @ghidraAddress 0x4eb88 */
- (void)setWebInfoURL:(NSString *)webInfoURL {
    self->_urlWebInfo = webInfoURL ? [NSURL URLWithString:webInfoURL] : nil;
}

/** @ghidraAddress 0x4ec28 */
- (void)setPreWebInfoURL:(NSString *)preWebInfoURL {
    if (preWebInfoURL) {
        self->_urlPreWebInfo = [NSURL URLWithString:preWebInfoURL];
    }
}

#pragma mark - Web-info and terms URLs

/** @ghidraAddress 0x4eb78 */
- (NSURL *)getBaseWebInfoURL {
    return self->_urlBaseWebInfo;
}

/** @ghidraAddress 0x4ec18 */
- (NSURL *)getWebInfoURL {
    return self->_urlWebInfo;
}

/** @ghidraAddress 0x4eca4 */
- (NSURL *)getPreWebInfoURL {
    return self->_urlPreWebInfo;
}

/** @ghidraAddress 0x4ecb4 */
- (void)setBaseTermURL:(NSString *)baseTermURL {
    self->_urlBaseTerm = baseTermURL;
}

/** @ghidraAddress 0x4ecec */
- (NSString *)getBaseTermURL {
    return self->_urlBaseTerm;
}

/** @ghidraAddress 0x4ecfc */
- (NSString *)getTermURLWithID:(NSString *)termID {
    if (termID == nil) {
        // No id: the resolved terms URL is just the base terms URL.
        self->_urlTerm = self->_urlBaseTerm;
    } else {
        self->_urlTerm =
            [NSString stringWithFormat:kTermURLFormat, self->_urlBaseTerm, GetRegionCode(), termID];
    }
    return self->_urlTerm;
}

/** @ghidraAddress 0x4efa4 */
- (NSString *)getInfoLastUpdateTimeString {
    return self->_infoLastUpdateTimeString;
}

/** @ghidraAddress 0x4f044 */
- (void)setExtendNotePIDForOpenStore:(NSString *)extendNotePIDForOpenStore {
    // Written out rather than synthesised, and it retains rather than copying, so the declared
    // copy attribute does not apply here.
    self->_extendNotePIDForOpenStore = extendNotePIDForOpenStore;
}

/** @ghidraAddress 0x4f07c */
- (NSString *)getExtendNotePIDForOpenStore {
    return self->_extendNotePIDForOpenStore;
}

/** @ghidraAddress 0x4ee50 */
- (BOOL)needUpdateTerms {
#ifdef ENABLE_PATCHES
    // Accepting the terms POSTs to a Konami endpoint that no longer answers, so the acceptance can
    // never be recorded and the screen returns on every launch. All three title scenes gate on this
    // one answer, so reporting no outstanding terms skips it everywhere, first install included.
    return NO;
#else
    NSString *accepted = RBUserSettingData.sharedInstance.termVersion;
    NSString *latest = self.latestTermVer;
    if (accepted == nil) {
        // No version accepted yet: an update is required.
        return YES;
    }
    if (latest == nil) {
        return NO;
    }
    // The accepted version being older than the latest means a re-accept is needed.
    return [accepted compare:latest options:NSNumericSearch] == NSOrderedAscending;
#endif
}

/** @ghidraAddress 0x4f4d0 */
- (BOOL)isEnableEarlyBonus {
    if (self.earlyBonusList == nil || self.earlyBonusList.count == 0) {
        return NO;
    }
    MusicData *music = self.musicData;
    NSString *key = [NSString stringWithFormat:kBonusListKeyFormat, music.MusicID];
    // The binary sends -objectForKey:, not the subscript form.
    return [self.earlyBonusList objectForKey:key] != nil;
}

/** @ghidraAddress 0x4f658 */
- (BOOL)isEnableHotBonus {
    if (self.hotBonusList == nil || self.hotBonusList.count == 0) {
        return NO;
    }
    MusicData *music = self.musicData;
    NSString *key = [NSString stringWithFormat:kBonusListKeyFormat, music.MusicID];
    // The binary sends -objectForKey:, not the subscript form.
    return [self.hotBonusList objectForKey:key] != nil;
}

/** @ghidraAddress 0x517fc */
+ (NSString *)saveDataKey {
    return kSaveDataPassphrase;
}

#pragma mark - Push notifications

/** @ghidraAddress 0x4f08c */
+ (NSMutableArray *)getPushNotificationData {
    return AppDelegate.appDelegate.pushList;
}

/** @ghidraAddress 0x4f314 */
+ (void)addPushNotificationData:(NSDictionary *)data {
    [AppDelegate.appDelegate.pushList addObject:data];
}

/** @ghidraAddress 0x4f0fc */
+ (NSDictionary *)popPushNotificationData {
    // The binary re-sends appDelegate and pushList for each step rather than holding the list in
    // a local, and it sends -objectAtIndex:, not the subscript form.
    if (AppDelegate.appDelegate.pushList != nil && AppDelegate.appDelegate.pushList.count != 0) {
        NSDictionary *data = [AppDelegate.appDelegate.pushList objectAtIndex:0];
        [AppDelegate.appDelegate.pushList removeObjectAtIndex:0];
        return data;
    }
    return nil;
}

#pragma mark - Outer URL

/** @ghidraAddress 0x4f3d4 */
+ (NSURL *)getOuterURL {
    return AppDelegate.appDelegate.outerUrl;
}

/** @ghidraAddress 0x4f444 */
+ (void)setOuterURL:(NSURL *)url {
    AppDelegate.appDelegate.outerUrl = url;
}

#pragma mark - Open-store campaign

/** @ghidraAddress 0x4efec */
- (NSString *)getPackIDForOpenStore {
    return self->_packIDForOpenStore;
}

/** @ghidraAddress 0x4efb4 */
- (void)setPackIDForOpenStore:(NSString *)packIDForOpenStore {
    self->_packIDForOpenStore = packIDForOpenStore;
}

/** @ghidraAddress 0x4f034 */
- (NSString *)getCampaignIDForOpenStore {
    return self->_campaignIDForOpenStore;
}

/** @ghidraAddress 0x4effc */
- (void)setCampaignIDForOpenStore:(NSString *)campaignID {
    self->_campaignIDForOpenStore = campaignID;
}

#pragma mark - Terms

/** @ghidraAddress 0x4ee08 */
- (void)setTermLastUpdateTimeString:(NSString *)termLastUpdateTimeString {
    // Written out rather than synthesised, and it retains rather than copying, so the declared
    // copy attribute does not apply here.
    self->_termLastUpdateTimeString = termLastUpdateTimeString;
}

/** @ghidraAddress 0x4ee40 */
- (NSString *)getTermLastUpdateTimeString {
    return self->_termLastUpdateTimeString;
}

/** @ghidraAddress 0x4ef50 */
- (void)setLatestTermsVersion:(NSString *)latestTermsVersion {
    self.latestTermVer = latestTermsVersion;
}

#pragma mark - Startup and resource update

/** @ghidraAddress 0x4d77c */
- (void)startApplication {
    // Classify the device OS version so play timing can compensate for the iOS 8.0/8.1 changes.
    if ([UIDevice.currentDevice.systemVersion compare:kOsVersion81
                                              options:NSNumericSearch] == NSOrderedAscending) {
        if ([UIDevice.currentDevice.systemVersion compare:kOsVersion80
                                                  options:NSNumericSearch] == NSOrderedAscending) {
            PlayTimer::shared();
            g_pPlayTimer->SetOsVersionTier(PlayTimer::kOsVersionTierPre80);
        } else {
            PlayTimer::shared();
            g_pPlayTimer->SetOsVersionTier(PlayTimer::kOsVersionTier80To81);
        }
    } else {
        PlayTimer::shared();
        g_pPlayTimer->SetOsVersionTier(PlayTimer::kOsVersionTier81OrLater);
    }

    // Seed the delay-frame timing offset from the persisted user setting.
    PlayTimer::shared();
    g_pPlayTimer->SetDelayFrameOffset(RBUserSettingData.sharedInstance.delayFrame *
                                      g_flDelayFrameToSeconds);

    __weak AppDelegate *weakSelf = self;
    switch ([DownloadResourceManager offlineCheck]) {
    case DownloadResourceManagerResultMissing:
    case DownloadResourceManagerResultOutdated:
        // No usable bundle: the user must download the resources before playing.
        [UIAlertView showAlertNeedResourceUpdate:weakSelf];
        break;
    case DownloadResourceManagerResultUpdate:
        [UIAlertView showAlertNeedResourceUpdate:weakSelf];
        break;
    case DownloadResourceManagerResultCurrent:
        [self requestResourceInfo];
        break;
    }
}

/** @ghidraAddress 0x4da2c */
- (void)requestResourceInfo {
    // Build the identity payload. When server data is present its credentials are used; otherwise
    // empty credentials are sent.
    NSArray *serverData = [AppDelegate getServerData];
    NSDictionary *payload;
    if (serverData) {
        payload = @{
            kResourceInfoKeyTarget : GetRegionCode(),
            kResourceInfoKeyVersion : GetBundleVersionString(),
            kResourceInfoKeyUserID : [serverData objectAtIndex:kServerDataUserIdIndex],
            kResourceInfoKeyPasswd : [serverData objectAtIndex:kServerDataTokenIndex],
            kResourceInfoKeyUUID : [AppDelegate musicListKey],
        };
    } else {
        payload = @{
            kResourceInfoKeyTarget : GetRegionCode(),
            kResourceInfoKeyVersion : GetBundleVersionString(),
            kResourceInfoKeyUserID : @"",
            kResourceInfoKeyPasswd : @"",
            kResourceInfoKeyUUID : [AppDelegate musicListKey],
        };
    }
    NSData *json = [Downloader dictionaryToJsonData:payload];

    // Replace any in-flight downloader with a fresh resource-info request.
    if (self.downloader) {
        [self.downloader cancel];
        self.downloader = nil;
    }
    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil resourceURL]
                                                 post:json
                                          contentType:nil];

    __weak AppDelegate *weakSelf = self;
    [self.downloader startDownloadingWithProceed:nil
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x4e01c */
          // Apply the served configuration to the app-info fields, then route the startup flow.
          NSDictionary *response = [downloader getDataInJSON];
          weakSelf.version = response[kStartupKeyVersion];
          weakSelf.urlString = response[kStartupKeyItemURL];
          weakSelf.mustUpdateFlag = response[kStartupKeyType];
          if (weakSelf.mustUpdateFlag == nil) {
              weakSelf.mustUpdateFlag = kMustUpdateFlagOff;
          }

          NSString *requiredAppVersion = response[kStartupKeyApp];
          NSString *userID = response[kStartupKeyUserID];
          NSString *passwd = response[kStartupKeyPasswd];

          // Proceed when server data already exists, or when both credentials were returned.
          BOOL haveCredentials = (userID != nil && passwd != nil);
          if (serverData != nil || haveCredentials) {
              [AppDelegate setServerData:userID andB:passwd];
              RebuildDeviceDescriptionString();

              NSDictionary *campaign = response[kStartupKeyCol];
              if (campaign) {
                  [[RBCampaignData sharedInstance] parseDictionary:campaign];
              }
              weakSelf.latestTermVer = response[kStartupKeyTermsVersion];

              if (!weakSelf.isSkipUpdate &&
                  [GetBundleVersionString() compare:requiredAppVersion
                                            options:NSNumericSearch] == NSOrderedAscending) {
                  // The installed app is older than the required version: prompt to update.
                  dispatch_async(dispatch_get_main_queue(), ^{
                    /** @ghidraAddress 0x4e774 */
                    [UIAlertView showAlertLatestApplication:weakSelf];
                  });
                  return;
              }

              switch ([DownloadResourceManager onlineChek:response]) {
              case DownloadResourceManagerResultMissing: {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    /** @ghidraAddress 0x4e7b8 */
                    [UIAlertView showAlertNeedResourceUpdate:weakSelf];
                  });
                  break;
              }
              case DownloadResourceManagerResultOutdated: {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    /** @ghidraAddress 0x4e830 */
                    [UIAlertView showDownloadWithDelegate:weakSelf];
                  });
                  break;
              }
              case DownloadResourceManagerResultUpdate: {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    /** @ghidraAddress 0x4e8a8 */
                    [weakSelf showDownload];
                  });
                  break;
              }
              case DownloadResourceManagerResultCurrent: {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    /** @ghidraAddress 0x4e904 */
                    [weakSelf showTitle];
                  });
                  break;
              }
              }
          } else {
              // Missing credentials: show the startup network-error alert (tag 10).
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x4e6cc */
                UIAlertView *alert = [UIAlertView showNetworkErrorWithDelegate:weakSelf];
                alert.tag = kStartupNetworkErrorTag;
              });
          }
        }
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0x4e9c4 */
          // Offline fallback: dispatch to the title screen when the file list is intact, otherwise
          // to the download screen.
          if ([DownloadResourceManager fileListCheck]) {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x4eaac */
                [weakSelf showTitle];
              });
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x4eb08 */
                [weakSelf showDownload];
              });
          }
        }];
}

/** @ghidraAddress 0x4faf4 */
- (void)showTerms {
    [self.viewController showTermsWithDelegate:nil];
}

/** @ghidraAddress 0x50398 */
- (void)showDownload {
    RBResourceDownloadViewController *downloadViewController =
        [[RBResourceDownloadViewController alloc] init];
    self.resourceDownloadViewController = downloadViewController;
    downloadViewController.downloadPath = self.urlString;
    downloadViewController.version = self.version;
    // Not in the binary, and not a deviation from it either: presenting a controller gave a
    // full-screen canvas on the iOS this was built for, and since iOS 13 the default is an inset
    // sheet instead. Without this the download screen lays out inside 704x944 of a 768x1024 screen.
    // Stating the original's style restores the original's behaviour, so it is not gated.
    downloadViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.viewController presentViewController:downloadViewController animated:NO completion:nil];
}

#pragma mark - Alert view delegate

/** @ghidraAddress 0x504dc */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    alertView.delegate = nil;
    if (alertView.tag == kResourceUpdateAlertTag) {
        [self showDownload];
    } else if (alertView.tag == kStartupNetworkErrorTag) {
        [self requestResourceInfo];
    } else if (alertView.tag == kNewVersionAlertTag) {
        if (alertView.cancelButtonIndex == buttonIndex) {
            self.isSkipUpdate = YES;
            if (self.resourceDownloadViewController == nil) {
                [self requestResourceInfo];
            } else {
                [self.resourceDownloadViewController download];
            }
        } else {
            [AppDelegate launchAppStore];
        }
    } else {
        if (alertView.cancelButtonIndex == buttonIndex) {
            [self showTitle];
        } else {
            [self showDownload];
        }
    }
}

@end
