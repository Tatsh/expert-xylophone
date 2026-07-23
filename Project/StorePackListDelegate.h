/** @file
 * The delegate protocol adopted by the store page to receive pack-list load results from its
 * @c RBStorePackList model. This is a minimal stub declaring only the surface
 * @c RBStorePageViewController relies on; the full model class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (protocol @c StorePackListDelegate, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class RBStorePackList;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Pack-list load-result callbacks delivered to the store page.
 */
@protocol StorePackListDelegate <NSObject>

@required

/**
 * @brief Sent when a pack list finished loading successfully.
 * @param packList The pack list that finished loading.
 */
- (void)packListDownloadSuccess:(RBStorePackList *)packList;

/**
 * @brief Sent when a pack list failed to load.
 * @param packList The pack list that failed.
 * @param errorMessage The failure message, or @c nil for the default.
 */
- (void)packListDownloadError:(RBStorePackList *)packList
                 errorMessage:(nullable NSString *)errorMessage;

/**
 * @brief Sent when a pack list returned no packs.
 * @param packList The empty pack list.
 */
- (void)packListDownloadNothing:(RBStorePackList *)packList;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
