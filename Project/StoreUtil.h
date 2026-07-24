/** @file
 * In-app-purchase receipt signing helpers. Computes salted SHA-256 hex digests over the
 * receipt-check JSON payload so the server can authenticate the client's verification request.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class StoreUtil, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class SKProduct;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Digest builders that sign the IAP receipt-verification request sent to the game server.
 */
@interface StoreUtil : NSObject

/**
 * @brief Compute the salted SHA-256 check digest for a receipt-verification payload.
 * @param jsonString The receipt-check JSON payload to sign.
 * @return A 64-character lowercase SHA-256 hex digest of the salt concatenated with @p jsonString.
 * @ghidraAddress 0x86484
 */
+ (NSString *)createReceiptCheckDigest:(NSString *)jsonString;

/**
 * @brief Compute the nonce-salted SHA-256 check digest for a receipt-verification payload.
 * @param jsonString The receipt-check JSON payload to sign.
 * @param nonce A caller-supplied nonce that provides replay protection.
 * @return A 64-character lowercase SHA-256 hex digest of the shared secret, @p nonce, and
 * @p jsonString concatenated in that order.
 * @ghidraAddress 0x8657c
 */
+ (NSString *)createReceiptCheckDigestV2:(NSString *)jsonString withNonce:(NSString *)nonce;

/**
 * @brief Whether a string is a usable @c http or @c https URL.
 *
 * Rejects a @c nil string and an @c NSNull placeholder, then requires that it parse into an
 * @c NSURL whose scheme is @c http or @c https.
 * @param urlString The candidate URL string.
 * @return @c YES when @p urlString is a valid @c http or @c https URL.
 * @ghidraAddress 0x85cc0
 */
+ (BOOL)isValidURL:(nullable NSString *)urlString;

/**
 * @brief Build a random nonce string of the given length.
 * @param length The number of random characters to generate.
 * @return A newly generated nonce, or an empty string when @p length is zero.
 * @ghidraAddress 0x8665c
 */
+ (NSString *)createNonce:(unsigned long long)length;

/**
 * @brief Build the receipt-verification JSON payload for the V2 protocol.
 * @param receipt The Base64-encoded App Store receipt.
 * @param productIds The product identifiers being verified.
 * @param nonce The nonce carried through the request for replay protection.
 * @return The JSON payload string.
 * @ghidraAddress 0x85fd4
 */
+ (NSString *)createReceiptCheckJSONForV2:(NSString *)receipt
                               productIds:(NSArray *)productIds
                                    nonce:(NSString *)nonce;

/**
 * @brief The V3 receipt-verification endpoint URL.
 * @return The endpoint URL.
 * @ghidraAddress 0x85980
 */
+ (NSURL *)receiptV3URL;

/**
 * @brief Map a numeric pack identifier to its App Store product identifier.
 * @param pid The numeric pack identifier.
 * @return The product identifier string.
 * @ghidraAddress 0x874a0
 */
+ (nullable NSString *)pidToProductID:(int)pid;

/**
 * @brief Build the tune-info download URL for a purchased tune.
 * @param musicId The tune identifier.
 * @return The tune-info endpoint URL.
 * @ghidraAddress 0x8596c
 */
+ (nullable NSURL *)musicInfoURL:(int)musicId;

/**
 * @brief Build the paged pack-list catalogue download URL for a genre.
 * @param offset The one-based start offset of the page to fetch.
 * @param limit The maximum number of packs to request.
 * @param genre The genre identifier to fetch.
 * @return The pack-list catalogue endpoint URL.
 * @ghidraAddress 0x85944
 */
+ (nullable NSURL *)packListURL:(int)offset limit:(int)limit genre:(unsigned int)genre;

/**
 * @brief Build the pack-detail info download URL for a pack.
 *
 * Forwards to @c NetworkUtil to compose the @c v3/packinfo/ endpoint URL for the pack.
 * @param packID The pack identifier.
 * @param userOpen Whether the request is on behalf of a user-initiated open.
 * @return The pack-detail info endpoint URL.
 * @ghidraAddress 0x85964
 */
+ (nullable NSURL *)packInfoURL:(int)packID UserOpen:(BOOL)userOpen;

/**
 * @brief Build the extend-note-detail info download URL for an extend note.
 *
 * Forwards to @c NetworkUtil to compose the extend-note-info endpoint URL for the item.
 * @param extendNoteID The extend-note identifier.
 * @param userOpen Whether the request is on behalf of a user-initiated open.
 * @return The extend-note-detail info endpoint URL.
 * @ghidraAddress 0x8748c
 */
+ (nullable NSURL *)extendNoteInfoURL:(unsigned int)extendNoteID UserOpen:(BOOL)userOpen;

/**
 * @brief Build the manage-screen sort-metadata list download URL.
 * @return The sort-metadata list endpoint URL.
 * @ghidraAddress 0x859d0
 */
+ (nullable NSURL *)manageSortListURL;

/**
 * @brief Map an App Store product identifier to its numeric extend-note identifier.
 * @param productID The product identifier string.
 * @return The numeric extend-note identifier.
 */
+ (int)productIDToPid:(nullable NSString *)productID;

/**
 * @brief Build the paged extend-note catalogue list download URL.
 * @param offset The one-based catalogue offset of the first item to fetch.
 * @param limit The maximum number of items to fetch.
 * @return The extend-note list endpoint URL.
 * @ghidraAddress 0x87484
 */
+ (nullable NSURL *)extendNoteListURL:(unsigned int)offset limit:(unsigned int)limit;

/**
 * @brief Build the user-age and purchase-limit-type check URL.
 * @return The user-age check endpoint URL.
 */
+ (nullable NSURL *)userAgeURL;

/**
 * @brief Extract the affiliate product parameters carried by an iTunes URL.
 * @param url The iTunes URL to parse.
 * @return The affiliate parameters, or @c nil when the URL carries none.
 */
+ (nullable NSDictionary *)affiliateParametersFromURL:(nullable NSString *)url;

/**
 * @brief Map an App Store product identifier to its numeric pack identifier.
 * @param productID The product identifier string.
 * @return The numeric pack identifier, or @c -1 when it is not a pack product.
 * @ghidraAddress 0x1e66f8 (caller reference)
 */
+ (int)packIDForProductID:(nullable NSString *)productID;

/**
 * @brief Map a numeric pack identifier to its App Store product identifier.
 * @param packID The numeric pack identifier.
 * @return The product identifier string.
 */
+ (nullable NSString *)productIDForPackID:(int)packID;

/**
 * @brief Format a StoreKit product's localised price string.
 *
 * Delegates to @c priceString:useCatalogPrice: with the catalogue-price flag cleared.
 * @param product The StoreKit product whose price to format.
 * @return The localised price string.
 * @ghidraAddress 0x85b4c
 */
+ (nullable NSString *)priceString:(nullable SKProduct *)product;

/**
 * @brief Format a StoreKit product's localised price string.
 *
 * The @p useCatalogPrice flag is accepted for call-site compatibility but does not affect the
 * result: the localised price always comes from the StoreKit product itself.
 * @param product The StoreKit product whose price to format.
 * @param useCatalogPrice Ignored.
 * @return The localised price string.
 * @ghidraAddress 0x85b7c
 */
+ (nullable NSString *)priceString:(nullable SKProduct *)product
                   useCatalogPrice:(BOOL)useCatalogPrice;

/**
 * @brief The campaign unlock-list endpoint URL.
 * @return The campaign list endpoint URL.
 */
+ (nullable NSURL *)campaignListURL;

/**
 * @brief The campaign serial-code verification endpoint URL.
 * @return The campaign serial-check endpoint URL.
 */
+ (nullable NSURL *)campaignSerialCheckURL;

/**
 * @brief The campaign item-info endpoint URL.
 * @return The campaign item-info endpoint URL.
 */
+ (nullable NSURL *)campaignItemInfoURL;

/**
 * @brief Build the campaign unlock-list request JSON payload.
 * @param offset The list start offset.
 * @param limit The maximum number of items to request.
 * @return The JSON payload string.
 */
+ (nullable NSString *)createCampaignListJSON:(int)offset limit:(int)limit;

/**
 * @brief Build the campaign serial-code verification request JSON payload.
 * @param campaignID The campaign identifier.
 * @param code The entered serial code.
 * @return The JSON payload string.
 */
+ (nullable NSString *)createCampaignSerialCheckJSON:(int)campaignID code:(nullable NSString *)code;

/**
 * @brief Build the campaign item-info request JSON payload.
 * @param campaignID The campaign identifier.
 * @return The JSON payload string.
 */
+ (nullable NSString *)createCampaignItemInfoJSON:(int)campaignID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
