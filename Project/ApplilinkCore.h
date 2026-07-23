/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c ApplilinkCore.
 *
 * The Applilink SDK ships as a closed third-party library, so only the class methods that
 * @c RecommendNetwork messages are declared here. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink SDK's core entry point.
 */
@interface ApplilinkCore : NSObject

/**
 * @brief The SDK's main window, used as a fallback advert host.
 * @return The SDK main window.
 */
+ (nullable UIWindow *)mainWindow;

/**
 * @brief Whether the SDK's initialisation-status flag is set.
 * @return @c YES when the SDK has finished initialising.
 */
+ (BOOL)isInitializeStatusFlg;

/**
 * @brief Report an open failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the open was attempted with.
 * @param delegate The advert delegate to notify.
 */
+ (void)toDelegateFailOpenWithError:(nullable NSError *)error
                           appParam:(nullable ApplilinkParameters *)appParam
                           delegate:(nullable id)delegate;

/**
 * @brief The device advertising UDID cached in the SDK core.
 * @return The advertising UDID, or @c nil.
 * @ghidraAddress 0x2153a0
 */
+ (nullable NSString *)ad_udid;

/**
 * @brief The current UDID cached in the SDK core.
 * @return The current UDID, or @c nil.
 * @ghidraAddress 0x2150ec
 */
+ (nullable NSString *)udid;

/**
 * @brief The old UDID cached in the SDK core.
 * @return The old UDID, or @c nil.
 * @ghidraAddress 0x21558c
 */
+ (nullable NSString *)old_udid;

/**
 * @brief The pasteboard UDID cached in the SDK core.
 * @return The pasteboard UDID, or @c nil.
 * @ghidraAddress 0x215260
 */
+ (nullable NSString *)pasteBoard_udid;

/**
 * @brief Store the advertising UDID in the SDK core.
 * @param adUdid The advertising UDID to store.
 * @ghidraAddress 0x2157f8
 */
+ (void)setAdUdid:(nullable NSString *)adUdid;

/**
 * @brief Reset the SDK core's cached initialisation state.
 * @ghidraAddress 0x215a90
 */
+ (void)clearInitialize;

/**
 * @brief Initialise the SDK core for an application and server environment.
 *
 * On the non-resume path the application and environment are persisted to @c NSUserDefaults; either
 * path regenerates an authentication session. The callback receives a localised error, or @c nil on
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
 * @brief Set whether advert screens use the common navigation-bar appearance.
 * @param navigationBarCommonAppearance @c YES to use the common appearance.
 * @ghidraAddress 0x214c00
 */
+ (void)setNavigationBarCommonAppearance:(BOOL)navigationBarCommonAppearance;

/**
 * @brief Set whether the SDK localises using the device's preferred languages.
 * @param priorityDeviceLanguages @c YES to prioritise the device languages.
 * @ghidraAddress 0x214c20
 */
+ (void)setPriorityDeviceLanguages:(BOOL)priorityDeviceLanguages;

/**
 * @brief Set the tint colour of the SDK's loading indicator.
 * @param indicatorColor The indicator colour.
 * @ghidraAddress 0x214c40
 */
+ (void)setIndicatorColor:(nullable UIColor *)indicatorColor;

/**
 * @brief Flag the SDK as not currently used inside the store.
 * @ghidraAddress 0x214cb4
 */
+ (void)unusedInStore;

/**
 * @brief Flag the SDK as built with the legacy pre-Xcode 6 toolchain.
 * @ghidraAddress 0x214cd8
 */
+ (void)buildUnderXcode6;

/**
 * @brief The Applilink SDK development version string.
 * @return The SDK development version.
 * @ghidraAddress 0x215b58
 */
+ (nullable NSString *)versionDev;

/**
 * @brief The current device UDID cached by the SDK core.
 * @return The current UDID, or @c nil.
 * @ghidraAddress 0x215040
 */
+ (nullable NSString *)currentUdid;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
