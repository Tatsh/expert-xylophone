/** @file
 * The application delegate: owns the main window, root view controller, and navigation controller,
 * brings up the audio and game engine at launch, seeds the GameSystem from the persisted user
 * settings, drives the app lifecycle (resign/foreground/background/terminate), registers for remote
 * and local notifications, bridges StoreKit purchases via RBPurchaseManager, and holds the news /
 * terms web-info endpoint URLs plus the pending push-notification list.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class AppDelegate, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class neWindow, RBViewController, RBNavigationController, RBResourceDownloadViewController;

/**
 * @brief The application delegate for REFLEC BEAT plus.
 */
@interface AppDelegate : UIResponder <UIApplicationDelegate>

/**
 * @brief The main window that hosts the game engine's render surface.
 * @ghidraAddress 0x54684 (getter)
 * @ghidraAddress 0x54694 (setter)
 */
@property(nonatomic, strong) neWindow *window;
/**
 * @brief The root view controller driving the game's screens.
 * @ghidraAddress 0x546cc (getter)
 * @ghidraAddress 0x546dc (setter)
 */
@property(nonatomic, strong) RBViewController *viewController;
/**
 * @brief The navigation controller wrapping the root view controller (its bar kept hidden).
 * @ghidraAddress 0x54714 (getter)
 * @ghidraAddress 0x54724 (setter)
 */
@property(nonatomic, strong) RBNavigationController *navigationController;
/**
 * @brief The alert shown when the device is low on storage. The name retains the binary's
 * misspelling of "storage" as "strage".
 * @ghidraAddress 0x5475c (getter)
 * @ghidraAddress 0x5476c (setter)
 */
@property(nonatomic, strong) UIAlertView *strageAlertView;
/**
 * @brief The currently-selected music data object.
 * @ghidraAddress 0x547a4 (getter)
 * @ghidraAddress 0x547b4 (setter)
 */
@property(nonatomic, strong) id musicData;
/**
 * @brief The loaded replay/ghost data for the current play.
 * @ghidraAddress 0x547ec (getter)
 * @ghidraAddress 0x547fc (setter)
 */
@property(nonatomic, strong) id replayData;
/**
 * @brief The active music-list search string.
 * @ghidraAddress 0x54834 (getter)
 * @ghidraAddress 0x54844 (setter)
 */
@property(nonatomic, strong) NSString *searchString;
/**
 * @brief The unread cross-promotion (Applilink) recommendation count shown on the badge.
 * @ghidraAddress 0x5487c (getter)
 * @ghidraAddress 0x5488c (setter)
 */
@property(nonatomic, assign) NSInteger unreadRecommendCount;
/**
 * @brief Whether the Applilink (KONAMI ID) network layer has finished initialising.
 * @ghidraAddress 0x5489c (getter)
 * @ghidraAddress 0x548b0 (setter)
 */
@property(nonatomic, assign) BOOL applilinkInitialized;
/**
 * @brief The early-bird bonus campaign list.
 * @ghidraAddress 0x548c0 (getter)
 * @ghidraAddress 0x548d0 (setter)
 */
@property(nonatomic, strong) NSArray *earlyBonusList;
/**
 * @brief The hot bonus campaign list.
 * @ghidraAddress 0x54908 (getter)
 * @ghidraAddress 0x54918 (setter)
 */
@property(nonatomic, strong) NSArray *hotBonusList;
/**
 * @brief Whether the treasure map screen has already been shown this session.
 * @ghidraAddress 0x54950 (getter)
 */
@property(nonatomic, assign, readonly) BOOL isShowedMap;
/**
 * @brief Whether the first-run resource update is being skipped.
 * @ghidraAddress 0x54970 (getter)
 * @ghidraAddress 0x54980 (setter)
 */
@property(nonatomic, assign) BOOL isSkipUpdate;
/**
 * @brief Whether a resource update is currently in progress.
 * @ghidraAddress 0x54990 (getter)
 * @ghidraAddress 0x549a0 (setter)
 */
@property(nonatomic, assign) BOOL isUpdate;
/**
 * @brief The resource-download progress view controller shown during updates.
 * @ghidraAddress 0x549b0 (getter)
 * @ghidraAddress 0x549c0 (setter)
 */
@property(nonatomic, strong) RBResourceDownloadViewController *resourceDownloadViewController;
/**
 * @brief A general-purpose URL string used by the update/web flows.
 * @ghidraAddress 0x549f8 (getter)
 * @ghidraAddress 0x54a08 (setter)
 */
@property(nonatomic, strong) NSString *urlString;
/**
 * @brief The server-reported latest app version string.
 * @ghidraAddress 0x54a14 (getter)
 * @ghidraAddress 0x54a24 (setter)
 */
@property(nonatomic, strong) NSString *version;
/**
 * @brief The server time string from the last info fetch.
 * @ghidraAddress 0x54a30 (getter)
 * @ghidraAddress 0x54a40 (setter)
 */
@property(nonatomic, strong) NSString *serverTime;
/**
 * @brief Whether the server flagged a mandatory app update.
 * @ghidraAddress 0x54a5c (getter)
 * @ghidraAddress 0x54a6c (setter)
 */
@property(nonatomic, assign) BOOL mustUpdateFlag;
/**
 * @brief Whether the app is still in its startup sequence.
 * @ghidraAddress 0x54a78 (getter)
 * @ghidraAddress 0x54a88 (setter)
 */
@property(nonatomic, assign) BOOL isStarting;
/**
 * @brief The base news web-info endpoint URL.
 * @ghidraAddress 0x54a98 (getter)
 * @ghidraAddress 0x54aa8 (setter)
 */
@property(nonatomic, strong) NSURL *urlBaseWebInfo;
/**
 * @brief The resolved news web-info URL.
 * @ghidraAddress 0x54ab4 (getter)
 * @ghidraAddress 0x54ac4 (setter)
 */
@property(nonatomic, strong) NSURL *urlWebInfo;
/**
 * @brief The pre-release news web-info endpoint URL.
 * @ghidraAddress 0x54ad0 (getter)
 * @ghidraAddress 0x54ae0 (setter)
 */
@property(nonatomic, strong) NSURL *urlPreWebInfo;
/**
 * @brief The last-update time string for the news info feed.
 * @ghidraAddress 0x54aec (getter)
 */
@property(nonatomic, strong, readonly) NSString *infoLastUpdateTimeString;
/**
 * @brief The pack identifier to open in the store on next launch.
 * @ghidraAddress 0x54afc (getter)
 */
@property(nonatomic, strong) NSString *packIDForOpenStore;
/**
 * @brief The campaign identifier to open in the store on next launch.
 * @ghidraAddress 0x54b0c (getter)
 */
@property(nonatomic, strong) NSString *campaignIDForOpenStore;
/**
 * @brief The extend-note product identifier to open in the store on next launch.
 * @ghidraAddress 0x54b1c (getter)
 */
@property(nonatomic, strong) NSString *extendNotePIDForOpenStore;
/**
 * @brief The base terms-of-service endpoint URL.
 * @ghidraAddress 0x54b2c (getter)
 * @ghidraAddress 0x54b3c (setter)
 */
@property(nonatomic, strong) NSURL *urlBaseTerm;
/**
 * @brief The resolved terms-of-service URL.
 * @ghidraAddress 0x54b58 (setter)
 */
@property(nonatomic, strong) NSURL *urlTerm;
/**
 * @brief The last-update time string for the terms document.
 * @ghidraAddress 0x54b64 (getter)
 */
@property(nonatomic, strong, readonly) NSString *termLastUpdateTimeString;
/**
 * @brief The latest accepted terms version.
 * @ghidraAddress 0x54b84 (setter)
 */
@property(nonatomic, strong) NSString *latestTermVer;
/**
 * @brief The pending push-notification payloads captured at launch.
 * @ghidraAddress 0x54b90 (getter)
 * @ghidraAddress 0x54ba0 (setter)
 */
@property(nonatomic, strong) NSMutableArray *pushList;
/**
 * @brief An external URL to open (deep link / promotion).
 * @ghidraAddress 0x54bd8 (getter)
 * @ghidraAddress 0x54be8 (setter)
 */
@property(nonatomic, strong) NSURL *outerUrl;
/**
 * @brief The resource downloader driving update fetches.
 * @ghidraAddress 0x54bf4 (getter)
 * @ghidraAddress 0x54c04 (setter)
 */
@property(nonatomic, strong) id downloader;
/**
 * @brief The APNs device-token uploader.
 * @ghidraAddress 0x54c3c (getter)
 * @ghidraAddress 0x54c4c (setter)
 */
@property(nonatomic, strong) id apnsUploader;

/**
 * @brief The shared app delegate: @c [[UIApplication sharedApplication] delegate].
 * @ghidraAddress 0x50af0
 */
+ (instancetype)appDelegate;

/**
 * @brief The two-element server-data pair (@c \@[p1, p2]) used to gate remote-notification
 * registration and to build the APNs token-upload payload.
 * @ghidraAddress 0x511cc
 */
+ (NSArray *)getServerData;

/**
 * @brief Exclude a file or directory from iCloud/iTunes backup via the legacy
 * @c com.apple.MobileBackup extended attribute.
 * @param path The filesystem path to mark.
 * @return @c YES if the attribute was set; @c NO on pre-5.0.1 systems or on @c setxattr failure.
 * @ghidraAddress 0x50b60
 */
+ (BOOL)setNoBackupAttribute:(NSString *)path;

/**
 * @brief Audio-session interruption handler: suspends the audio engine when an interruption begins
 * and resumes it when one ends.
 * @param notification The @c AVAudioSessionInterruptionNotification.
 * @ghidraAddress 0x54550
 */
- (void)audioSessionInterrupted:(NSNotification *)notification;

/**
 * @brief Open the App Store page for the game.
 * @ghidraAddress 0x53268
 */
- (void)launchAppStore;

/**
 * @brief Begin registering for remote (push) notifications, requesting the alert/badge/sound
 * authorisation and calling @c -registerForRemoteNotifications.
 * @ghidraAddress 0x533c8
 */
- (void)startRegisterForRemoteNotification;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
