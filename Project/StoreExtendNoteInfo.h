/** @file
 * A parsed extend-note catalogue record, built from a downloaded extend-note info dictionary and
 * registered with @c RBExtendNoteManager once its files are downloaded.
 *
 * Minimal stub: only the surface @c RBStoreManageViewController and
 * @c RBStoreExtendPageViewController message is declared here; the full class is reconstructed
 * separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteInfo, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A parsed extend-note catalogue record.
 */
@interface StoreExtendNoteInfo : NSObject

/**
 * @brief The extend-note product identifier.
 */
@property(nonatomic, assign) int pid;
/**
 * @brief The owning pack identifier.
 */
@property(nonatomic, assign) int packID;
/**
 * @brief The music identifier of the associated tune.
 */
@property(nonatomic, assign) int musicID;
/**
 * @brief The extend-note music identifier.
 */
@property(nonatomic, assign) int extMusicID;
/**
 * @brief The display name of the extend note.
 */
@property(nonatomic, strong, nullable) NSString *name;
/**
 * @brief The owning pack's display name.
 */
@property(nonatomic, strong, nullable) NSString *packName;
/**
 * @brief The tune file download URL.
 */
@property(nonatomic, strong, nullable) NSString *itemURL;
/**
 * @brief The extend-note file download URL.
 */
@property(nonatomic, strong, nullable) NSString *extendURL;
/**
 * @brief The artwork image URL.
 */
@property(nonatomic, strong, nullable) NSString *artworkURL;
/**
 * @brief The StoreKit product backing this extend note.
 */
@property(nonatomic, strong, nullable) SKProduct *product;

/**
 * @brief Parses an extend-note record from its catalogue dictionary.
 * @param dictionary The extend-note info dictionary.
 * @return The initialised record, or @c nil when @p dictionary is unusable.
 */
- (nullable instancetype)initWithDictionary:(nullable NSDictionary *)dictionary;

/**
 * @brief The button state that drives the pack cell's action (select, purchase, or download).
 * @return The current button state.
 */
- (int)getButtonState;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
