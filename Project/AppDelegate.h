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

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The application delegate for REFLEC BEAT plus.
 */
@interface AppDelegate : UIResponder <UIApplicationDelegate, UIAlertViewDelegate>

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
@property(nonatomic, strong, nullable) id musicData;
/**
 * @brief The loaded replay/ghost data for the current play.
 * @ghidraAddress 0x547ec (getter)
 * @ghidraAddress 0x547fc (setter)
 */
@property(nonatomic, strong, nullable) id replayData;
/**
 * @brief The active music-list search string.
 * @ghidraAddress 0x54834 (getter)
 * @ghidraAddress 0x54844 (setter)
 */
@property(nonatomic, strong, nullable) NSString *searchString;
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
@property(nonatomic, strong, nullable) NSArray *earlyBonusList;
/**
 * @brief The hot bonus campaign list.
 * @ghidraAddress 0x54908 (getter)
 * @ghidraAddress 0x54918 (setter)
 */
@property(nonatomic, strong, nullable) NSArray *hotBonusList;
/**
 * @brief Whether the treasure map screen has already been shown this session.
 * @ghidraAddress 0x54950 (getter)
 * @ghidraAddress 0x54960 (setter)
 */
@property(nonatomic, assign) BOOL isShowedMap;
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
@property(nonatomic, strong, nullable)
    RBResourceDownloadViewController *resourceDownloadViewController;
/**
 * @brief A general-purpose URL string used by the update/web flows.
 * @ghidraAddress 0x549f8 (getter)
 * @ghidraAddress 0x54a08 (setter)
 */
@property(nonatomic, strong, nullable) NSString *urlString;
/**
 * @brief The server-reported latest app version string.
 * @ghidraAddress 0x54a14 (getter)
 * @ghidraAddress 0x54a24 (setter)
 */
@property(nonatomic, strong, nullable) NSString *version;
/**
 * @brief The server time string from the last info fetch.
 * @ghidraAddress 0x54a30 (getter)
 * @ghidraAddress 0x54a40 (setter)
 */
@property(nonatomic, strong, nullable) NSString *serverTime;
/**
 * @brief The server's mandatory-update flag string (@c "1" when a mandatory update is required,
 * otherwise @c "0"), taken verbatim from the startup response's @c "Type" field.
 * @ghidraAddress 0x54a5c (getter)
 * @ghidraAddress 0x54a6c (setter)
 */
@property(nonatomic, copy, nullable) NSString *mustUpdateFlag;
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
 * @ghidraAddress 0x4ef6c (setter)
 */
@property(nonatomic, strong, nullable) NSString *infoLastUpdateTimeString;
/**
 * @brief The pack identifier to open in the store on next launch.
 * @ghidraAddress 0x54afc (getter)
 */
@property(nonatomic, strong, nullable) NSString *packIDForOpenStore;
/**
 * @brief The campaign identifier to open in the store on next launch.
 * @ghidraAddress 0x54b0c (getter)
 */
@property(nonatomic, strong, nullable) NSString *campaignIDForOpenStore;
/**
 * @brief The extend-note product identifier to open in the store on next launch.
 * @ghidraAddress 0x54b1c (getter)
 */
@property(nonatomic, strong, nullable) NSString *extendNotePIDForOpenStore;
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
@property(nonatomic, strong, readonly, nullable) NSString *termLastUpdateTimeString;
/**
 * @brief Convenience accessor for the last-update time string of the terms document.
 * @return The last-update time string, or @c nil when none has been recorded.
 * @ghidraAddress 0x4ee40
 */
- (nullable NSString *)getTermLastUpdateTimeString;
/**
 * @brief The latest accepted terms version.
 * @ghidraAddress 0x54b84 (setter)
 */
@property(nonatomic, strong, nullable) NSString *latestTermVer;
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
@property(nonatomic, strong, nullable) NSURL *outerUrl;
/**
 * @brief The resource downloader driving update fetches.
 * @ghidraAddress 0x54bf4 (getter)
 * @ghidraAddress 0x54c04 (setter)
 */
@property(nonatomic, strong, nullable) id downloader;
/**
 * @brief The APNs device-token uploader.
 * @ghidraAddress 0x54c3c (getter)
 * @ghidraAddress 0x54c4c (setter)
 */
@property(nonatomic, strong, nullable) id apnsUploader;

/**
 * @brief The pack identifier a deep link ("open store") queued for the store to open, as a string.
 * @ghidraAddress 0x4efec (getter)
 * @ghidraAddress 0x4efb4 (setter)
 */
@property(nonatomic, copy, nullable, getter=getPackIDForOpenStore) NSString *packIDForOpenStore;

/**
 * @brief The shared app delegate: @c [[UIApplication sharedApplication] delegate].
 * @ghidraAddress 0x50af0
 */
+ (instancetype)appDelegate;

/**
 * @brief Remove and return the oldest pending push-notification payload from @c pushList.
 * @return The oldest queued notification dictionary, or @c nil when none is queued.
 * @ghidraAddress 0x4f0fc
 */
+ (nullable NSDictionary *)popPushNotificationData;

/**
 * @brief The external URL captured for the next launch-time open.
 * @ghidraAddress 0x4f3d4
 */
+ (nullable NSURL *)getOuterURL;

/**
 * @brief Store the external URL to open on the next launch.
 * @param url The external URL, or @c nil to clear it.
 * @ghidraAddress 0x4f444
 */
+ (void)setOuterURL:(nullable NSURL *)url;

/**
 * @brief The base news web-info URL.
 * @ghidraAddress 0x4eb78
 */
- (nullable NSURL *)getBaseWebInfoURL;

/**
 * @brief The resolved news web-info URL.
 * @ghidraAddress 0x4ec18
 */
- (nullable NSURL *)getWebInfoURL;

/**
 * @brief The pre-release news web-info URL.
 * @ghidraAddress 0x4eca4
 */
- (nullable NSURL *)getPreWebInfoURL;

/**
 * @brief Store the base terms URL.
 * @param baseTermURL The base terms URL.
 * @ghidraAddress 0x4ecb4
 */
- (void)setBaseTermURL:(nullable NSURL *)baseTermURL;

/**
 * @brief The base terms URL.
 * @ghidraAddress 0x4ecec
 */
- (nullable NSURL *)getBaseTermURL;

/**
 * @brief The terms URL for a given terms id, built from the base terms URL and the region code.
 *
 * A @c nil id resolves the terms URL to the base terms URL; otherwise the region and type are
 * appended.
 * @param termID The terms identifier, or @c nil for the base URL.
 * @return The resolved terms URL.
 * @ghidraAddress 0x4ecfc
 */
- (nullable NSURL *)getTermURLWithID:(nullable NSString *)termID;

/**
 * @brief The last-update time string for the news info feed.
 * @ghidraAddress 0x4efa4
 */
- (nullable NSString *)getInfoLastUpdateTimeString;

/**
 * @brief The extend-note product identifier queued for a launch-time store open.
 * @ghidraAddress 0x4f07c
 */
- (nullable NSString *)getExtendNotePIDForOpenStore;

/**
 * @brief The pending push-notification queue.
 * @ghidraAddress 0x4f08c
 */
+ (nullable NSMutableArray *)getPushNotificationData;

/**
 * @brief Append a payload to the pending push-notification queue.
 * @param data The notification payload to queue.
 * @ghidraAddress 0x4f314
 */
+ (void)addPushNotificationData:(nullable NSDictionary *)data;

/**
 * @brief Whether the accepted terms version is older than the latest available, requiring re-accept.
 * @ghidraAddress 0x4ee50
 */
- (BOOL)needUpdateTerms;

/**
 * @brief Whether the current music has an early-bonus entry.
 * @ghidraAddress 0x4f4d0
 */
- (BOOL)isEnableEarlyBonus;

/**
 * @brief Whether the current music has a hot-bonus entry.
 * @ghidraAddress 0x4f658
 */
- (BOOL)isEnableHotBonus;

/**
 * @brief The fixed passphrase used to encrypt persisted save data.
 * @ghidraAddress 0x517fc
 */
- (nullable NSString *)saveDataKey;

/**
 * @brief The campaign identifier queued for a launch-time open of the campaign store tab.
 * @return The queued campaign identifier, or @c nil when none is queued.
 */
- (nullable NSString *)getCampaignIDForOpenStore;

/**
 * @brief Store the campaign identifier to open on the next store-tab presentation.
 * @param campaignID The campaign identifier, or @c nil to clear it.
 */
- (void)setCampaignIDForOpenStore:(nullable NSString *)campaignID;

/**
 * @brief Initialise the Applilink companion-application SDK.
 * @ghidraAddress 0x50698
 */
+ (void)ApplilinkInitialize;

/**
 * @brief The two-element server-data pair (@c \@[p1, p2]) used to gate remote-notification
 * registration and to build the APNs token-upload payload.
 * @ghidraAddress 0x511cc
 */
+ (nullable NSArray *)getServerData;

/**
 * @brief Persist the two-element server-data pair (user identity and password) to the Keychain.
 * @param p1 The server-issued user identity.
 * @param p2 The server-issued password.
 * @ghidraAddress 0x514c8
 */
+ (void)setServerData:(nullable NSString *)p1 andB:(nullable NSString *)p2;

/**
 * @brief The device-unique key string used to encrypt the purchased-music list: a Keychain
 * generic-password value, generated as a fresh @c CFUUID on first run and persisted back.
 * @ghidraAddress 0x50cb8
 */
+ (nullable NSString *)musicListKey;

/**
 * @brief Exclude a file or directory from iCloud/iTunes backup via the legacy
 * @c com.apple.MobileBackup extended attribute.
 * @param path The filesystem path to mark.
 * @return @c YES if the attribute was set; @c NO on pre-5.0.1 systems or on @c setxattr failure.
 * @ghidraAddress 0x50b60
 */
+ (BOOL)setNoBackupAttribute:(NSString *)path;

/**
 * @brief The total-score Game Center leaderboard category identifier, selected by the iPad idiom
 * flag (the phone-specific identifier on a phone, otherwise the shared iPad identifier).
 * @return The leaderboard category identifier string.
 * @ghidraAddress 0x50c8c
 */
+ (NSString *)totalScoreLeaderboardCategory;

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

/**
 * @brief Reset the game to the music menu, fading the current music menu out.
 * @ghidraAddress 0x51828
 */
- (void)resetGame;

/**
 * @brief Return to the title screen: log in to Game Center, initialise Applilink, reset the
 * effect-size settings, schedule the title-layer build, and kick off the startup request.
 * @ghidraAddress 0x4f7e0
 */
- (void)showTitle;

/**
 * @brief Issue the startup / web-info request, cancelling any in-flight download first.
 * @ghidraAddress 0x4fb4c
 */
- (void)startupRequest;

/**
 * @brief Kick off the recommend-advert unread-count fetch, updating @c unreadRecommendCount when it
 * completes.
 * @ghidraAddress 0x50920
 */
+ (void)setRecommendUnreadCount;

/**
 * @brief Store the latest accepted terms version.
 *
 * A thin wrapper that forwards to the @c latestTermVer setter.
 * @param latestTermsVersion The accepted terms version string.
 * @ghidraAddress 0x4ef50
 */
- (void)setLatestTermsVersion:(nullable NSString *)latestTermsVersion;

/**
 * @brief Begin the application: record the device OS-version timing tier and the delay-frame
 * timing offset, then branch on the offline resource check to either prompt for a resource update
 * or issue the resource-info request.
 * @ghidraAddress 0x4d77c
 */
- (void)startApplication;

/**
 * @brief Post the resource-info request: build the identity payload (region, version, credentials,
 * and music-list key), replace any in-flight downloader, and start the request whose success routes
 * the startup response and whose failure falls back to the file-list check.
 * @ghidraAddress 0x4da2c
 */
- (void)requestResourceInfo;

/**
 * @brief Present the terms-of-service screen through the root view controller.
 * @ghidraAddress 0x4faf4
 */
- (void)showTerms;

/**
 * @brief Present the resource-download screen, seeded with the pending download URL and version.
 * @ghidraAddress 0x50398
 */
- (void)showDownload;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
