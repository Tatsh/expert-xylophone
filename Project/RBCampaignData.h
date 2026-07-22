/** @file
 * The campaign and bonus-event data singleton. It parses the campaign descriptor served with the
 * store payload, tracking the active campaign name, whether a campaign is currently running,
 * whether the running campaign is the March 2017 "hinabita" collaboration, the store skin colours
 * and images, and the campaign message list. Store banner and strap images are fetched
 * asynchronously through a keyed table of image downloaders.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBCampaignData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A singleton holding the current campaign descriptor, store skin, and campaign messages.
 */
@interface RBCampaignData : NSObject

/**
 * @brief Whether a campaign is currently active. Set once a campaign name is parsed.
 * @ghidraAddress 0x9d3c8 (getter)
 * @ghidraAddress 0x9d3dc (setter)
 */
@property(atomic, assign) BOOL isCampaignMode;
/**
 * @brief The active campaign's name, or @c nil when no campaign is running.
 * @ghidraAddress 0x9d3ec (getter)
 * @ghidraAddress 0x9d3fc (setter)
 */
@property(atomic, strong, nullable) NSString *campaignName;
/**
 * @brief The store base colour parsed from the campaign descriptor's "c01" entry.
 * @ghidraAddress 0x9d408 (getter)
 * @ghidraAddress 0x9d418 (setter)
 */
@property(atomic, strong, nullable) UIColor *storeBaseColor;
/**
 * @brief The store strap image fetched from the campaign descriptor's "c02" entry.
 * @ghidraAddress 0x9d424 (getter)
 * @ghidraAddress 0x9d434 (setter)
 */
@property(atomic, strong, nullable) UIImage *storeStrapImage;
/**
 * @brief The store base image fetched from the campaign descriptor's "c03" entry.
 * @ghidraAddress 0x9d440 (getter)
 * @ghidraAddress 0x9d450 (setter)
 */
@property(atomic, strong, nullable) UIImage *storeBaseImage;
/**
 * @brief The store sample colour parsed from the campaign descriptor's "c11" entry.
 * @ghidraAddress 0x9d45c (getter)
 * @ghidraAddress 0x9d46c (setter)
 */
@property(atomic, strong, nullable) UIColor *storeSampleColor;
/**
 * @brief The first store pack colour parsed from the campaign descriptor's "c21" entry.
 * @ghidraAddress 0x9d478 (getter)
 * @ghidraAddress 0x9d488 (setter)
 */
@property(atomic, strong, nullable) UIColor *storeColorPackA;
/**
 * @brief The second store pack colour parsed from the campaign descriptor's "c22" entry.
 * @ghidraAddress 0x9d494 (getter)
 * @ghidraAddress 0x9d4a4 (setter)
 */
@property(atomic, strong, nullable) UIColor *storeColorPackB;
/**
 * @brief The campaign message list parsed from the campaign descriptor's "a01" entry.
 * @ghidraAddress 0x9d4b0 (getter)
 * @ghidraAddress 0x9d4c0 (setter)
 */
@property(atomic, strong, nullable) NSArray *messageList;
/**
 * @brief Whether the active campaign is the March 2017 "hinabita" collaboration.
 * @ghidraAddress 0x9d4cc (getter)
 * @ghidraAddress 0x9d4e0 (setter)
 */
@property(atomic, assign) BOOL isCampaignHinabita201703;
/**
 * @brief The in-flight store image downloaders, keyed by their campaign descriptor key.
 * @ghidraAddress 0x9d4f0 (getter)
 * @ghidraAddress 0x9d500 (setter)
 */
@property(atomic, strong, nullable) NSMutableDictionary *imageDownloaders;

/**
 * @brief Returns the shared campaign-data singleton, allocating it on first use.
 * @return The shared @c RBCampaignData instance.
 * @ghidraAddress 0x9c404
 */
+ (instancetype)sharedInstance;

/**
 * @brief Parses a campaign descriptor dictionary, populating the campaign name, mode flags, store
 * skin colours and images, and message list.
 * @param parseDictionary The campaign descriptor dictionary, or @c nil to do nothing.
 * @ghidraAddress 0x9c45c
 */
- (void)parseDictionary:(nullable NSDictionary *)parseDictionary;

/**
 * @brief Parses a four-component colour array and stores it into the store skin colour matching the
 * given key.
 * @param color The colour as an array of four 0-255 component numbers (red, green, blue, and
 * alpha).
 * @param key The store colour key ("c01", "c11", "c21", or "c22").
 * @ghidraAddress 0x9c8e4
 */
- (void)setColor:(nullable NSArray *)color key:(nullable NSString *)key;

/**
 * @brief Starts, or reuses, an image download for a store image keyed by the given key.
 * @param startDownloadWithPath The image URL to download.
 * @param key The store image key ("c02" for the strap image or "c03" for the base image).
 * @ghidraAddress 0x9cbc8
 */
- (void)startDownloadWithPath:(NSString *)startDownloadWithPath key:(nullable NSString *)key;

/**
 * @brief Seeds the singleton into the fixed March 2017 "hinabita" campaign name with the campaign
 * flag cleared, used at launch.
 * @ghidraAddress 0x9d37c
 */
- (void)presetHinabitaMode;

/**
 * @brief Sets whether the active campaign is the March 2017 "hinabita" collaboration.
 * @param hinabitaMode Whether the hinabita campaign is active.
 * @ghidraAddress 0x9d3bc
 */
- (void)setHinabitaMode:(BOOL)hinabitaMode;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
