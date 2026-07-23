/** @file
 * A single campaign store item: one entry of the server campaign unlock list, describing an
 * unlockable tune or reward, the granted-experience payload, and the acquisition-button state its
 * cell should display. Instances are built from a server campaign-list dictionary and re-evaluated
 * with @c termCheck after each acquisition step.
 *
 * @c StoreCampaignItemInfo derives from @c StoreMusicInfo: when the campaign entry carries a
 * nested @c music dictionary the superclass is initialised from it, so a campaign item is also a
 * fully formed store tune.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreCampaignItemInfo, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

#import "StoreMusicInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One campaign unlock-list item and its acquisition-button state.
 */
@interface StoreCampaignItemInfo : StoreMusicInfo

/**
 * @brief The campaign identifier.
 * @ghidraAddress 0x109bb8 (getter)
 */
@property(nonatomic, assign, readonly) int campaignID;
/**
 * @brief The campaign display name.
 * @ghidraAddress 0x109bc8 (getter)
 */
@property(nonatomic, strong, readonly, nullable) NSString *campaignName;
/**
 * @brief The campaign description text.
 * @ghidraAddress 0x109bd8 (getter)
 */
@property(nonatomic, strong, readonly, nullable) NSString *campaignDescription;
/**
 * @brief The campaign unlock-terms description text.
 * @ghidraAddress 0x109be8 (getter)
 */
@property(nonatomic, strong, readonly, nullable) NSString *campaignTermsDescription;
/**
 * @brief The banner-artwork URL, if any.
 * @ghidraAddress 0x109bf8 (getter)
 */
@property(nonatomic, strong, readonly, nullable) NSString *campaignBannerURL;
/**
 * @brief Whether the server reports the item as already unlocked.
 * @ghidraAddress 0x109c08 (getter)
 */
@property(nonatomic, assign, readonly) BOOL bServerUnlock;
/**
 * @brief The item type; zero identifies a downloadable tune.
 * @ghidraAddress 0x109c18 (getter)
 */
@property(nonatomic, assign, readonly) int itemType;
/**
 * @brief The item identifier.
 * @ghidraAddress 0x109c28 (getter)
 */
@property(nonatomic, assign, readonly) int itemID;
/**
 * @brief The thumbnail-artwork URL, read only when the item is a downloadable tune.
 * @ghidraAddress 0x109c38 (getter)
 */
@property(nonatomic, strong, readonly, nullable) NSString *thumbnailURL;
/**
 * @brief Whether the item's archive is already present on disk.
 * @ghidraAddress 0x109c48 (getter)
 */
@property(nonatomic, assign, readonly) BOOL alreadyDownload;
/**
 * @brief Whether the item is unlocked and available to acquire.
 * @ghidraAddress 0x109c58 (getter)
 */
@property(nonatomic, assign, readonly) BOOL bUnlock;
/**
 * @brief The action-button kind the item's cell should display.
 * @ghidraAddress 0x109c68 (getter)
 */
@property(nonatomic, assign, readonly) int buttonType;
/**
 * @brief The item hide mode; a value of two hides the item from the row list.
 * @ghidraAddress 0x109c78 (getter)
 */
@property(nonatomic, assign, readonly) int hideType;
/**
 * @brief The external link URL attached to the item, if any.
 * @ghidraAddress 0x109c88 (getter)
 */
@property(nonatomic, strong, readonly, nullable) NSURL *linkURL;
/**
 * @brief The copyright text attached to the item, if any.
 * @ghidraAddress 0x109c98 (getter)
 */
@property(nonatomic, strong, readonly, nullable) NSString *copyright;
/**
 * @brief The raw unlock dictionary carrying the granted-experience type and identifier.
 * @ghidraAddress 0x109ca8 (getter)
 */
@property(nonatomic, strong, readonly, nullable) NSDictionary *unlockDict;

/**
 * @brief Initialises the item from a server campaign-list dictionary.
 *
 * When the entry carries a nested @c music dictionary the superclass is initialised from it,
 * otherwise the superclass is initialised bare. The campaign metadata, the granted-experience
 * @c option dictionary, the optional @c foreignUrl link, the server unlock flag, and the terms
 * table are then read, and @c termCheck is run to settle the acquisition-button state.
 * @param dictionary The campaign-item dictionary, or @c nil.
 * @return The initialised item.
 * @ghidraAddress 0x108b90
 */
- (nullable instancetype)initWithDictionary:(nullable NSDictionary *)dictionary;
/**
 * @brief Re-evaluates the item's unlock and button state after an acquisition step.
 *
 * Refreshes the already-downloaded flag, resolves the unlock terms (open-URL terms, purchased-pack
 * terms, or a server unlock flag), settles @c buttonType and @c hideType, and grants any pending
 * experience payload from @c unlockDict.
 * @return The resulting unlocked state.
 * @ghidraAddress 0x109088
 */
- (BOOL)termCheck;
/**
 * @brief Reports whether the given pack identifier appears in a checked-pack list.
 * @param checkExistPackList The list of pack-identifier entries to scan.
 * @param packID The pack identifier to find.
 * @return @c YES when the identifier is present.
 * @ghidraAddress 0x1096c4
 */
- (BOOL)checkExistPackList:(nullable NSArray *)checkExistPackList packID:(int)packID;
/**
 * @brief Reports whether the item is a new (not previously downloaded) unlock for the badge count.
 * @return @c YES when the item is unlocked but not yet downloaded.
 * @ghidraAddress 0x109850
 */
- (BOOL)checkNewUnlock;
/**
 * @brief Reports whether a tune item's archive is already present on disk.
 * @param hasItem Zero identifies a downloadable tune; any other value reports no.
 * @param itemID The tune identifier whose archive is checked.
 * @return @c YES when the archive exists on disk.
 * @ghidraAddress 0x109898
 */
- (BOOL)hasItem:(int)hasItem itemID:(int)itemID;
/**
 * @brief Marks the item as server-unlocked and unlocked.
 * @ghidraAddress 0x1099ac
 */
- (void)registSuccess;

/**
 * @brief The tint colour for a campaign cell's action button in the given button state.
 * @param buttonType The action-button kind (see the item's @c buttonType).
 * @return The fill colour for that button state.
 * @ghidraAddress 0x1099cc
 */
+ (nullable UIColor *)getButtonColor:(int)buttonType;
/**
 * @brief The title text for a campaign cell's action button in the given button state.
 * @param buttonType The action-button kind (see the item's @c buttonType).
 * @return The title for that button state.
 * @ghidraAddress 0x109b10
 */
+ (nullable NSString *)getButtonName:(int)buttonType;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
