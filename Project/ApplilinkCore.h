/** @file
 * Reconstructed interface for the Applilink SDK's @c ApplilinkCore.
 *
 * @c ApplilinkCore is the Applilink advert SDK's central controller: a stateless facade whose whole
 * surface is class (@c +) methods backed by file-scope statics (the class has no instance ivars).
 * It owns SDK initialisation and foreground resume, the advert-screen appearance configuration
 * (navigation-bar common appearance, device-language priority, and loading-indicator tint), the
 * cached UDID accessors and their keychain/pasteboard maintenance, the fail-open advert delegate
 * fan-out, and the authentication-session regeneration. It coordinates the @c RewardCore and
 * @c RecommendCore singletons, @c ApplilinkWebAPI, @c ApplilinkUdid, @c ApplilinkStore, and
 * @c AnalysisNetworkCore. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink SDK's core entry point.
 */
@interface ApplilinkCore : NSObject

#pragma mark - Initialisation

/**
 * @brief Initialise the SDK core for an application and server environment.
 *
 * On the non-resume path the application and environment are persisted to @c NSUserDefaults and the
 * initialisation-status flag is set; either path regenerates an authentication session and then
 * starts the reward and recommend cores. The callback receives a localised error, or @c nil on
 * success.
 * @param appliId The Applilink application identifier.
 * @param env The server environment name, or @c nil for production.
 * @param resume @c YES when re-initialising after a foreground resume.
 * @param callback The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x214494
 */
+ (void)initializeWithAppliId:(nullable NSString *)appliId
                          env:(nullable NSString *)env
                       resume:(BOOL)resume
                     callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Resume the SDK core, closing any open store and re-initialising from persisted state.
 * @ghidraAddress 0x214b00
 */
+ (void)resume;

/**
 * @brief Regenerate the authentication session, invoking the block once the session is valid.
 * @param block The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x215d7c
 */
+ (void)appAuthSessionRegenerateWithBlock:(nullable void (^)(NSError *_Nullable error))block;

/**
 * @brief Reset the SDK core's cached initialisation state.
 * @ghidraAddress 0x215a90
 */
+ (void)clearInitialize;

#pragma mark - Appearance configuration

/**
 * @brief Set whether advert screens use the common navigation-bar appearance.
 * @param navigationBarCommonAppearance @c YES to use the common appearance.
 * @ghidraAddress 0x214c00
 */
+ (void)setNavigationBarCommonAppearance:(BOOL)navigationBarCommonAppearance;

/**
 * @brief Whether advert screens use the common navigation-bar appearance.
 * @return @c YES when the common appearance is used.
 * @ghidraAddress 0x214c10
 */
+ (BOOL)isNavigationBarCommonAppearance;

/**
 * @brief Set whether the SDK localises using the device's preferred languages.
 * @param priorityDeviceLanguages @c YES to prioritise the device languages.
 * @ghidraAddress 0x214c20
 */
+ (void)setPriorityDeviceLanguages:(BOOL)priorityDeviceLanguages;

/**
 * @brief Whether the SDK localises using the device's preferred languages.
 * @return @c YES when the device languages are prioritised.
 * @ghidraAddress 0x214c30
 */
+ (BOOL)isPriorityDeviceLanguages;

/**
 * @brief Set the tint colour of the SDK's loading indicator.
 * @param indicatorColor The indicator colour.
 * @ghidraAddress 0x214c40
 */
+ (void)setIndicatorColor:(nullable UIColor *)indicatorColor;

/**
 * @brief The tint colour of the SDK's loading indicator.
 * @return The configured indicator colour, or the white colour when unset.
 * @ghidraAddress 0x214c6c
 */
+ (nullable UIColor *)getIndicatorColor;

#pragma mark - Build and store flags

/**
 * @brief Flag the SDK as not currently used inside the store.
 * @ghidraAddress 0x214cb4
 */
+ (void)unusedInStore;

/**
 * @brief Whether the SDK is currently used inside the store.
 * @return @c YES when the SDK is used inside the store.
 * @ghidraAddress 0x214cc8
 */
+ (BOOL)isUsedInStore;

/**
 * @brief Flag the SDK as built with the legacy pre-Xcode 6 toolchain.
 * @ghidraAddress 0x214cd8
 */
+ (void)buildUnderXcode6;

/**
 * @brief Whether the SDK was built with the Xcode 6 (or later) toolchain.
 * @return @c YES when not built under the legacy pre-Xcode 6 toolchain.
 * @ghidraAddress 0x214cec
 */
+ (BOOL)isBuildXcode6;

#pragma mark - Windows and status

/**
 * @brief The SDK's main window, used as a fallback advert host.
 * @return The SDK main window.
 * @ghidraAddress 0x214d04
 */
+ (nullable UIWindow *)mainWindow;

/**
 * @brief Whether the SDK's initialisation is currently in progress.
 * @return @c YES while an initialisation is running.
 * @ghidraAddress 0x214fb4
 */
+ (BOOL)isInitializingFlg;

/**
 * @brief Whether the SDK's initialisation-status flag is set.
 * @return @c YES when the SDK has finished initialising.
 * @ghidraAddress 0x214fc4
 */
+ (BOOL)isInitializeStatusFlg;

/**
 * @brief The Applilink application identifier stored in @c NSUserDefaults.
 * @return The stored application identifier, or @c nil.
 * @ghidraAddress 0x214fd4
 */
+ (nullable NSString *)appliId;

#pragma mark - UDID accessors

/**
 * @brief The current UDID, preferring the advertising UDID when tracking is unavailable.
 * @return The current UDID, or @c nil.
 * @ghidraAddress 0x215040
 */
+ (nullable NSString *)currentUdid;

/**
 * @brief The cached UDID without recomputation.
 * @return The cached UDID, or @c nil.
 * @ghidraAddress 0x2150bc
 */
+ (nullable NSString *)udid_cache;

/**
 * @brief The cached advertising UDID without recomputation.
 * @return The cached advertising UDID, or @c nil.
 * @ghidraAddress 0x2150cc
 */
+ (nullable NSString *)ad_udid_cache;

/**
 * @brief The cached old UDID without recomputation.
 * @return The cached old UDID, or @c nil.
 * @ghidraAddress 0x2150dc
 */
+ (nullable NSString *)old_udid_cache;

/**
 * @brief The UDID, computing and caching it from the keychain on first access.
 * @return The UDID, or @c nil.
 * @ghidraAddress 0x2150ec
 */
+ (nullable NSString *)udid;

/**
 * @brief The pasteboard UDID, computing and caching it from the keychain on first access.
 * @return The pasteboard UDID, or @c nil.
 * @ghidraAddress 0x215260
 */
+ (nullable NSString *)pasteBoard_udid;

/**
 * @brief The advertising UDID, computing and caching it on first access.
 * @return The advertising UDID, or @c nil.
 * @ghidraAddress 0x2153a0
 */
+ (nullable NSString *)ad_udid;

/**
 * @brief The old UDID, computing and caching it from the keychain on first access.
 * @return The old UDID, or @c nil.
 * @ghidraAddress 0x21558c
 */
+ (nullable NSString *)old_udid;

/**
 * @brief Whether either the UDID or the advertising UDID is available.
 * @return @c YES when a UDID is available.
 * @ghidraAddress 0x215654
 */
+ (BOOL)checkUdid;

#pragma mark - UDID maintenance

/**
 * @brief Clear the stored UDID and, outside the local environment, its keychain records.
 * @ghidraAddress 0x2156c4
 */
+ (void)clearUDID;

/**
 * @brief Store the advertising UDID in the SDK core.
 * @param adUdid The advertising UDID to store.
 * @ghidraAddress 0x2157f8
 */
+ (void)setAdUdid:(nullable NSString *)adUdid;

/**
 * @brief Clear the old-UDID keychain record and, when no UDID remains, the initialisation state.
 * @ghidraAddress 0x215864
 */
+ (void)clearKeyChainOldUDID;

/**
 * @brief Clear the advertising-UDID keychain records outside the local environment.
 * @ghidraAddress 0x2159bc
 */
+ (void)clearAdUDID;

/**
 * @brief Persist the cached advertising UDID to the pasteboard when a re-login is pending.
 * @ghidraAddress 0x215cec
 */
+ (void)updatePasteBoard;

#pragma mark - Store

/**
 * @brief Present the App Store product page for an application, unless already used in the store.
 * @param appStoreId The App Store application identifier.
 * @param appParam The request parameters.
 * @param delegate The advert delegate to notify.
 * @return @c YES when the App Store page was presented.
 * @ghidraAddress 0x215ba4
 */
+ (BOOL)showAppStoreId:(nullable NSString *)appStoreId
              appParam:(nullable ApplilinkParameters *)appParam
              delegate:(nullable id)delegate;

/**
 * @brief Close any open App Store product page.
 * @ghidraAddress 0x215c9c
 */
+ (void)closeAppStore;

#pragma mark - Metadata

/**
 * @brief The Applilink SDK signature key.
 * @return The signature key.
 * @ghidraAddress 0x215b2c
 */
+ (nullable NSString *)signatureKey;

/**
 * @brief The Applilink SDK development version string.
 * @return The SDK development version.
 * @ghidraAddress 0x215b58
 */
+ (nullable NSString *)versionDev;

#pragma mark - Delegate fan-out

/**
 * @brief Report that the advert did start back to a delegate.
 * @param appParam The request parameters.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2161ec
 */
+ (void)toDelegateDidStart:(nullable ApplilinkParameters *)appParam delegate:(nullable id)delegate;

/**
 * @brief Report that the advert did appear back to a delegate.
 * @param appParam The request parameters.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2162d4
 */
+ (void)toDelegateDidAppear:(nullable ApplilinkParameters *)appParam delegate:(nullable id)delegate;

/**
 * @brief Report that the advert did disappear back to a delegate.
 * @param appParam The request parameters.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2163bc
 */
+ (void)toDelegateDidDisappear:(nullable ApplilinkParameters *)appParam
                      delegate:(nullable id)delegate;

/**
 * @brief Report an open failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the open was attempted with.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2164a4
 */
+ (void)toDelegateFailOpenWithError:(nullable NSError *)error
                           appParam:(nullable ApplilinkParameters *)appParam
                           delegate:(nullable id)delegate;

/**
 * @brief Report a load failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the load was attempted with.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2165d8
 */
+ (void)toDelegateFailLoadWithError:(nullable NSError *)error
                           appParam:(nullable ApplilinkParameters *)appParam
                           delegate:(nullable id)delegate;

/**
 * @brief Report a generic failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the operation was attempted with.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x21670c
 */
+ (void)toDelegateFailWithError:(nullable NSError *)error
                       appParam:(nullable ApplilinkParameters *)appParam
                       delegate:(nullable id)delegate;

/**
 * @brief Report a link failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the link was attempted with.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x216814
 */
+ (void)toDelegateFailLinkWithError:(nullable NSError *)error
                           appParam:(nullable ApplilinkParameters *)appParam
                           delegate:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
