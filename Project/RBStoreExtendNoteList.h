/** @file
 * The extend-note catalogue list controller. It fetches the extend-note catalogue in pages, caches
 * the parsed records keyed by product identifier, and reports load progress to its delegate.
 *
 * Minimal interface; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreExtendNoteList, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class RBStoreExtendNoteList;
@class StoreExtendNoteInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Delegate notified as the extend-note catalogue loads.
 */
@protocol StoreExtendNoteListDelegate <NSObject>

@optional
/**
 * @brief A catalogue page loaded successfully.
 * @param downloader The reporting list controller.
 */
- (void)extendNoteListDownloadSuccess:(nullable id)downloader;
/**
 * @brief A catalogue page failed to load.
 * @param downloader The reporting list controller.
 * @param errorMessage The failure message, or @c nil for the default message.
 */
- (void)extendNoteListDownloadError:(nullable id)downloader
                       errorMessage:(nullable NSString *)errorMessage;
/**
 * @brief The catalogue loaded but contained no extend notes.
 * @param downloader The reporting list controller.
 */
- (void)extendNoteListDownloadNothing:(nullable id)downloader;

@end

/**
 * @brief The extend-note catalogue list controller.
 */
@interface RBStoreExtendNoteList : NSObject

/**
 * @brief The delegate notified as the catalogue loads.
 */
@property(nonatomic, weak, nullable) id<StoreExtendNoteListDelegate> delegate;
/**
 * @brief The ordered product identifiers currently loaded.
 */
@property(nonatomic, strong, nullable) NSArray *extendNoteProductIDList;
/**
 * @brief Whether the catalogue has further pages to load.
 */
@property(nonatomic, assign, readonly) BOOL extendNoteListContinued;
/**
 * @brief Whether a catalogue fetch is currently in flight.
 */
@property(nonatomic, assign, readonly) BOOL isFetching;

/**
 * @brief Returns the cached extend-note record for the given product identifier.
 * @param productID The extend-note product identifier.
 * @return The cached record, or @c nil when it is not loaded.
 */
- (nullable StoreExtendNoteInfo *)getExtendNoteInfoWithProductID:(int)productID;
/**
 * @brief Resolves and caches an extend-note record from its product identifier.
 * @param productID The extend-note product identifier.
 * @return The resolved record.
 */
- (nullable StoreExtendNoteInfo *)addExtendNoteInfoFromProductID:(int)productID;
/**
 * @brief Requests the optional-products catalogue.
 */
- (void)optionalProductsRequest;
/**
 * @brief Begins fetching the next catalogue page.
 */
- (void)startFetching;
/**
 * @brief Cancels any in-flight catalogue fetch.
 */
- (void)cancelFetching;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
