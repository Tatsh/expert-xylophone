/** @file
 * Reconstructed interface for the Applilink advert SDK's @c ApplilinkUtilities helper.
 *
 * @c ApplilinkUtilities is the SDK's stateless utilities class: it builds the user-agent parameter
 * dictionary, resolves the device model name, locale, and country code, serialises parameter
 * dictionaries into a URL query string, generates a random impression identifier, filters lists
 * with a predicate, and provides small string and view-hierarchy helpers. The class has no instance
 * state; every member is a class method. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Applilink SDK string, device, and request-parameter utilities.
 */
@interface ApplilinkUtilities : NSObject

/**
 * @brief Merge two dictionaries into a new mutable dictionary.
 *
 * Entries from @p joinDictionary are added first, then entries from @p withDictionary, so the
 * latter wins on any duplicate key.
 * @param joinDictionary The first dictionary to merge.
 * @param withDictionary The second dictionary to merge, overriding duplicate keys.
 * @return A new dictionary containing the union of both.
 * @ghidraAddress 0x20c2a8
 */
+ (nullable NSDictionary *)joinDictionary:(nullable NSDictionary *)joinDictionary
                           withDictionary:(nullable NSDictionary *)withDictionary;

/**
 * @brief Merge the given dictionary with the standard user-agent parameters.
 * @param userAgentParametersJoinDictionary The caller's parameters to merge in.
 * @return A new dictionary combining @p userAgentParametersJoinDictionary and the user-agent
 * parameters, with the caller's entries taking precedence.
 * @ghidraAddress 0x20c37c
 */
+ (nullable NSDictionary *)userAgentParametersJoinDictionary:
    (nullable NSDictionary *)userAgentParametersJoinDictionary;

/**
 * @brief Build the standard Applilink user-agent parameter dictionary.
 *
 * The dictionary carries the application identifier, the URL-encoded device name, operating-system
 * name and version, SDK identifier, application version, preferred language, and country code. Each
 * entry is omitted when its value is @c nil.
 * @return The user-agent parameter dictionary.
 * @ghidraAddress 0x20c410
 */
+ (nullable NSDictionary *)userAgentParameters;

/**
 * @brief The hardware model name of the current device.
 *
 * The name is read once from the @c hw.machine sysctl and cached for the lifetime of the process.
 * @return The device model name, for example @c "iPhone9,1".
 * @ghidraAddress 0x20c86c
 */
+ (nullable NSString *)deviceName;

/**
 * @brief Append a parameter dictionary to a URL as a query string.
 *
 * Each value is percent-joined into a @c key=value pair; an array value expands into repeated
 * @c key[]=value pairs. The pairs are joined with @c & and appended after a @c ? or @c &, depending
 * on whether the URL already contains a query.
 * @param appendParametersToURL The base URL string.
 * @param parameters The parameters to append.
 * @return The URL string with the query appended.
 * @ghidraAddress 0x20ca98
 */
+ (nullable NSString *)appendParametersToURL:(nullable NSString *)appendParametersToURL
                                  parameters:(nullable NSDictionary *)parameters;

/**
 * @brief The user's preferred language code.
 * @return The first preferred language, or @c "ja" when none is available.
 * @ghidraAddress 0x20cefc
 */
+ (nullable NSString *)localeString;

/**
 * @brief The device's country code.
 * @return The current locale's country code, or @c "JP" when it is unavailable.
 * @ghidraAddress 0x20cf90
 */
+ (nullable NSString *)countryCodeString;

/**
 * @brief Whether a responder is attached to a presentable view hierarchy.
 *
 * A window, application, or view controller is treated as attached directly; a view is attached
 * when it can reach one of those through its responder chain.
 * @param hasParentViewController The responder to test.
 * @return @c YES when the responder resolves to a window, application, or view controller.
 * @ghidraAddress 0x20d02c
 */
+ (BOOL)hasParentViewController:(nullable UIResponder *)hasParentViewController;

/**
 * @brief Generate a random 64-character impression identifier.
 * @return A 64-character string of random alphanumeric characters.
 * @ghidraAddress 0x20d160
 */
+ (nullable NSString *)getImpressionId;

/**
 * @brief Filter a list to the objects whose key matches a value.
 *
 * The list is filtered with a @c "%K MATCHES %@" predicate, treating @p forKey as the key path and
 * @p object as the pattern.
 * @param narrowedListWithList The list to filter.
 * @param object The value the key must match.
 * @param forKey The key path to test on each element.
 * @return The subset of @p narrowedListWithList whose @p forKey matches @p object.
 * @ghidraAddress 0x20d240
 */
+ (nullable NSArray *)narrowedListWithList:(nullable NSArray *)narrowedListWithList
                                    object:(nullable NSString *)object
                                    forKey:(nullable NSString *)forKey;

/**
 * @brief The file-name portion of a path.
 *
 * The path is scanned backwards for the last @c "/" separator; the substring from that separator is
 * returned, or the whole path when there is no separator.
 * @param geFileNameFromPath The path to trim. The binary spells this selector @c geFileNameFromPath
 * without the @c t.
 * @return The trailing file-name component of @p geFileNameFromPath.
 * @ghidraAddress 0x20d38c
 */
+ (nullable NSString *)geFileNameFromPath:(nullable NSString *)geFileNameFromPath;

/**
 * @brief Emit a debug log message.
 *
 * This is an empty stub in the shipped build; the message is discarded.
 * @param text The message that would be logged.
 * @ghidraAddress 0x20d418
 */
+ (void)debugLog:(nullable id)text;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
