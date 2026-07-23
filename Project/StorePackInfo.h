/** @file
 * A store pack model describing one purchasable song pack: its identifier, its StoreKit product,
 * and the tunes it contains. This is a minimal stub declaring only the surface
 * @c RBStorePageViewController relies on; the full model class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackInfo, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class StoreMusicInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A store model for a single purchasable song pack.
 */
@interface StorePackInfo : NSObject

/**
 * @brief The pack identifier.
 */
@property(nonatomic, assign) int packID;

/**
 * @brief The StoreKit product backing the pack, once loaded.
 */
@property(nonatomic, strong, nullable) SKProduct *product;

/**
 * @brief The tunes contained in the pack, once its detail is loaded.
 */
@property(nonatomic, strong, nullable) NSArray<StoreMusicInfo *> *musicInfos;

/**
 * @brief The pack artwork URL string.
 */
@property(nonatomic, strong, nullable) NSString *artworkURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
