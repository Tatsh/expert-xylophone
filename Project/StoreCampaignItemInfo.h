/** @file
 * A single campaign store item: one entry of the server unlock list, describing an unlockable tune
 * or reward and its acquisition button state.
 *
 * Minimal stub for the surface @c RBCampaignViewController messages; the full class is
 * reconstructed separately. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c StoreCampaignItemInfo, image base 0x100000000).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One campaign unlock-list item.
 */
@interface StoreCampaignItemInfo : NSObject

/**
 * @brief The campaign identifier.
 */
@property(nonatomic, assign) int campaignID;
/**
 * @brief The banner-artwork URL, if any.
 */
@property(nonatomic, strong, nullable) NSString *campaignBannerURL;
/**
 * @brief The external link URL attached to the item, if any.
 */
@property(nonatomic, strong, nullable) NSString *linkURL;
/**
 * @brief The action-button kind (0 info download, 2 terms, 3 update, 4 serial code).
 */
@property(nonatomic, assign) int buttonType;
/**
 * @brief The item hide mode (2 hides the item from the row list).
 */
@property(nonatomic, assign) int hideType;
/**
 * @brief The item type (0 for a downloadable tune).
 */
@property(nonatomic, assign) int itemType;
/**
 * @brief The item identifier.
 */
@property(nonatomic, assign) int itemID;
/**
 * @brief The raw unlock dictionary carrying the granted-experience type and identifier.
 */
@property(nonatomic, strong, nullable) NSDictionary *unlockDict;

/**
 * @brief Initialises the item from a server unlock-list dictionary.
 * @param dictionary The item dictionary.
 * @return The initialised item.
 */
- (nullable instancetype)initWithDictionary:(nullable NSDictionary *)dictionary;
/**
 * @brief Reports whether the item is a new (not previously seen) unlock for the badge count.
 * @return Non-zero when the item is a new unlock.
 */
- (int)checkNewUnlock;
/**
 * @brief Re-evaluates the item's terms/button state after an acquisition step.
 */
- (void)termCheck;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
