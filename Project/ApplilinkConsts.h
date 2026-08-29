/**
 * @file
 * Reconstructed interface for the Applilink advert SDK's @c ApplilinkConsts helper.
 *
 * @c ApplilinkConsts is the SDK's constants and capability class: it exposes the SDK version, the
 * per-environment base URL, and the advert identifiers, and it gates every advert request behind an
 * operating-system-version check and the advertising-tracking permission. It stores its persistent
 * state (advertising identifier, application-install list, and template list) in
 * @c NSUserDefaults, encrypting the payloads with @c Crypto. The class has no instance state; every
 * member is a class method. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Applilink SDK constants, capability checks, and advert-identifier storage.
 */
@interface ApplilinkConsts : NSObject

/**
 * The Applilink server environment name held in @c NSUserDefaults.
 * @return The value stored under the @c ApplilinkNetwork.env default, or @c nil when unset.
 * @ghidraAddress 0x2053e8
 */
+ (nullable NSString *)envServer;

/**
 * The HTTPS base URL of the Applilink server selected by the current environment.
 * @return The production URL by default, or a staging, sandbox, or development URL when the
 * @c ApplilinkNetwork.env default selects one.
 * @ghidraAddress 0x205454
 */
+ (nullable NSString *)baseUrlSsl;

/**
 * The Applilink application identifier held in @c NSUserDefaults.
 * @return The value stored under the @c ApplilinkNetwork.appliId default, or @c nil when unset.
 * @ghidraAddress 0x205580
 */
+ (nullable NSString *)appliId;

/**
 * Whether the Applilink SDK may be used at all on this device.
 * @return @c YES when the operating-system version is at least the minimum the SDK supports.
 * @ghidraAddress 0x2055ec
 */
+ (BOOL)canUseApplilinkSdk;

/**
 * The Applilink SDK version string.
 * @return The SDK version.
 * @ghidraAddress 0x205680
 */
+ (nullable NSString *)version;

/**
 * Store the Applilink user identifier, encrypted, in @c NSUserDefaults.
 *
 * Passing @c nil clears the identifier and flags the recommend network for re-login. A new,
 * changed identifier is encrypted and stored, both networks are flagged for re-login, and a
 * recommend session is started.
 * @param userId The user identifier, or @c nil to clear it.
 * @ghidraAddress 0x2056ac
 */
+ (void)setUserId:(nullable NSString *)userId;

/**
 * The decrypted Applilink user identifier.
 * @return The cached identifier, loading and decrypting it from @c NSUserDefaults on first access.
 * @ghidraAddress 0x205a18
 */
+ (nullable NSString *)userId;

/**
 * Whether the reward network still needs the user to log in.
 * @return @c YES when the @c ApplilinkReward.reLoginFlg default is set.
 * @ghidraAddress 0x205b7c
 */
+ (BOOL)isNeedRewardLogin;

/**
 * Whether the recommend network still needs the user to log in.
 * @return @c YES when the @c ApplilinkRecommend.reLoginFlg default is set.
 * @ghidraAddress 0x205bf0
 */
+ (BOOL)isNeedRecommendLogin;

/**
 * Clear the reward network's re-login flag after a successful login.
 * @return An unused Boolean; the implementation only clears the flag.
 * @ghidraAddress 0x205c64
 */
+ (BOOL)loggedInReward;

/**
 * Clear the recommend network's re-login flag after a successful login.
 * @return An unused Boolean; the implementation only clears the flag.
 * @ghidraAddress 0x205cf8
 */
+ (BOOL)loggedInRecommend;

/**
 * Set the country code from the Applilink SDK and lock out later overrides.
 * @param appliCountryCode The country code supplied by the SDK.
 * @ghidraAddress 0x205d8c
 */
+ (void)setAppliCountryCode:(nullable NSString *)appliCountryCode;

/**
 * Set the country code, unless the SDK already supplied one.
 * @param countryCode The country code.
 * @ghidraAddress 0x205de4
 */
+ (void)setCountryCode:(nullable NSString *)countryCode;

/**
 * The country code.
 * @return The current country code.
 * @ghidraAddress 0x205e44
 */
+ (nullable NSString *)countryCode;

/**
 * Set the advert category identifier.
 * @param categoryId The category identifier.
 * @ghidraAddress 0x205e54
 */
+ (void)setCategoryId:(nullable NSString *)categoryId;

/**
 * The advert category identifier.
 * @return The current category identifier.
 * @ghidraAddress 0x205e80
 */
+ (nullable NSString *)categoryId;

/**
 * Set the advertising identifier.
 * @param adId The advertising identifier.
 * @ghidraAddress 0x205e90
 */
+ (void)setAdId:(nullable NSString *)adId;

/**
 * The advertising identifier.
 * @return The current advertising identifier.
 * @ghidraAddress 0x205ed4
 */
+ (nullable NSString *)adId;

/**
 * Store the encrypted application-install list and refresh the advertising identifier.
 *
 * Passing @c nil clears the stored list. Otherwise the matching advertising identifier is adopted
 * from the list, the list is encrypted to a temporary file, and its expiry is recorded in
 * @c NSUserDefaults.
 * @param appInstallList The application-install list, or @c nil to clear it.
 * @ghidraAddress 0x205ee4
 */
+ (void)setAppInstallList:(nullable NSArray *)appInstallList;

/**
 * The application-install list, decrypted from its temporary file.
 * @return The stored list, or @c nil when it is absent or has expired.
 * @ghidraAddress 0x20649c
 */
+ (nullable id)appInstallList;

/**
 * Store the encrypted advert template list in @c NSUserDefaults.
 * @param templateList The template list, or @c nil to clear it.
 * @ghidraAddress 0x206b08
 */
+ (void)setTemplateList:(nullable NSDictionary *)templateList;

/**
 * The advert template list, decrypted from @c NSUserDefaults.
 * @return The stored template list, or @c nil when it is absent.
 * @ghidraAddress 0x206d14
 */
+ (nullable id)templateList;

/**
 * Remove every Applilink default from the application's persistent domain.
 * @return An unused Boolean; the implementation only clears the defaults.
 * @ghidraAddress 0x206e9c
 */
+ (BOOL)clearData;

/**
 * Whether a specific advert request may proceed, reporting a failure to the delegate when it
 * may not.
 *
 * The request is allowed only when the SDK is usable and advertising tracking is enabled. On either
 * failure the caller's parameters are packaged and a localised error is delivered to the delegate
 * through @c ApplilinkCore.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @return @c YES when the request may proceed.
 * @ghidraAddress 0x206f7c
 */
+ (BOOL)checkUseSDKWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(nullable id)requestCode
                      delegate:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
