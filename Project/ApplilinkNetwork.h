/** @file
 * Reconstructed interface for the Applilink advert SDK's @c ApplilinkNetwork umbrella class.
 *
 * @c ApplilinkNetwork is the SDK's public entry-point facade: every one of its members is a class
 * method that forwards to the SDK's internal collaborators (@c ApplilinkConsts for the persisted
 * application, user, and version state, @c ApplilinkCore for the session, environment, and UDID
 * plumbing, and @c RewardCore and @c RecommendCore for advert-screen rotation). The class has no
 * instance state. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink SDK public facade.
 */
@interface ApplilinkNetwork : NSObject

/**
 * @brief Initialise the SDK for an application, selecting a server environment.
 *
 * Forwards to @c ApplilinkCore, requesting the non-resume initialisation path: the application and
 * environment are written to @c NSUserDefaults and an authentication session is regenerated. The
 * callback receives a localised error, or @c nil on success.
 * @param appliId The Applilink application identifier.
 * @param env The server environment name (@c "0" through @c "4"), or @c nil for production.
 * @param callback The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x248464
 */
+ (void)initializeWithAppliId:(nullable NSString *)appliId
                          env:(nullable NSString *)env
                     callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Resume the SDK after the application returns to the foreground.
 *
 * Forwards to @c ApplilinkCore, which closes any open store, then re-initialises with the persisted
 * application and environment on the resume path.
 * @ghidraAddress 0x2484d8
 */
+ (void)resume;

/**
 * @brief Set the Applilink user identifier.
 * @param userId The user identifier, or @c nil to clear it.
 * @ghidraAddress 0x2484f0
 */
+ (void)setUserId:(nullable NSString *)userId;

/**
 * @brief Set whether advert screens use the common navigation-bar appearance.
 * @param navigationBarCommonAppearance @c YES to use the common appearance.
 * @ghidraAddress 0x248508
 */
+ (void)setNavigationBarCommonAppearance:(BOOL)navigationBarCommonAppearance;

/**
 * @brief Set whether the SDK localises using the device's preferred languages.
 * @param priorityDeviceLanguages @c YES to prioritise the device languages.
 * @ghidraAddress 0x248520
 */
+ (void)setPriorityDeviceLanguages:(BOOL)priorityDeviceLanguages;

/**
 * @brief Set the tint colour of the SDK's loading indicator.
 * @param indicatorColor The indicator colour.
 * @ghidraAddress 0x248538
 */
+ (void)setIndicatorColor:(nullable UIColor *)indicatorColor;

/**
 * @brief Flag the SDK as not currently used inside the store.
 * @ghidraAddress 0x248550
 */
+ (void)unusedInStore;

/**
 * @brief Flag the SDK as built with the legacy pre-Xcode 6 toolchain.
 * @ghidraAddress 0x248568
 */
+ (void)buildUnderXcode6;

/**
 * @brief The Applilink application identifier.
 * @return The stored application identifier, or @c nil.
 * @ghidraAddress 0x248580
 */
+ (nullable NSString *)appliId;

/**
 * @brief The Applilink SDK version string.
 * @return The SDK version.
 * @ghidraAddress 0x248598
 */
+ (nullable NSString *)version;

/**
 * @brief The Applilink SDK development version string.
 * @return The SDK development version.
 * @ghidraAddress 0x2485b0
 */
+ (nullable NSString *)versionDev;

/**
 * @brief Whether the current operating-system version supports the SDK.
 * @return @c YES when the operating-system version is at least the minimum the SDK supports.
 * @ghidraAddress 0x2485c8
 */
+ (BOOL)isSupportediOSVersion;

/**
 * @brief The current device UDID cached by the SDK.
 * @return The current UDID, or @c nil.
 * @ghidraAddress 0x2485e0
 */
+ (nullable NSString *)currentUdid;

/**
 * @brief Rotate any open advert screens to a new interface orientation.
 *
 * Forwards to both @c RewardCore and @c RecommendCore when the operating-system version supports
 * the SDK.
 * @param interfaceOrientation The target @c UIInterfaceOrientation.
 * @param duration The animation duration.
 * @ghidraAddress 0x2485f8
 */
+ (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                              duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
