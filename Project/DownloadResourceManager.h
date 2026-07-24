/** @file
 * The downloadable-resource state helper. It is a stateless @c NSObject utility whose class methods
 * answer whether the installed downloadable game-asset bundle needs refreshing: it verifies the
 * extracted asset file list, decides whether an offline launch may proceed, and, given a server
 * response, decides how an online launch must proceed.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c DownloadResourceManager, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The action an availability check reports the launch flow must take.
 */
typedef NS_ENUM(NSInteger, DownloadResourceManagerResult) {
    DownloadResourceManagerResultMissing = 0,  /*!< No usable resource bundle is installed. */
    DownloadResourceManagerResultOutdated = 1, /*!< A bundle is installed but unusable as-is. */
    DownloadResourceManagerResultUpdate = 2,   /*!< The installed bundle is older than required. */
    DownloadResourceManagerResultCurrent = 3,  /*!< The installed bundle is current. */
};

/**
 * @brief Stateless queries over the downloadable game-asset bundle's installed state.
 */
@interface DownloadResourceManager : NSObject

/**
 * @brief Verify the extracted asset list: unzip the manifest, then confirm every listed file exists
 * in the image-asset directory.
 * @return @c YES when the manifest and every file it lists are present; otherwise @c NO.
 * @ghidraAddress 0xdd2dc
 */
+ (BOOL)fileListCheck;

/**
 * @brief Decide how an offline launch must treat the installed resource bundle.
 * @return @c DownloadResourceManagerResultMissing when no bundle directory exists,
 * @c DownloadResourceManagerResultOutdated when no version is recorded,
 * @c DownloadResourceManagerResultUpdate when the recorded version is older than the built-in
 * version, and @c DownloadResourceManagerResultCurrent otherwise.
 * @ghidraAddress 0xdd74c
 */
+ (DownloadResourceManagerResult)offlineCheck;

/**
 * @brief Decide how an online launch must proceed, given the server's resource-version response.
 * @param response The server response dictionary, carrying the current @c "Version" and an optional
 * @c "Type" flag.
 * @return When the installed bundle is at least as new as the server version,
 * @c DownloadResourceManagerResultCurrent or @c DownloadResourceManagerResultUpdate depending on
 * whether the installed file list verifies; when the installed bundle is older,
 * @c DownloadResourceManagerResultMissing when the response's @c "Type" flag equals @c "1", or
 * @c DownloadResourceManagerResultOutdated otherwise.
 * @ghidraAddress 0xdd850
 */
+ (DownloadResourceManagerResult)onlineChek:(NSDictionary *)response;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
