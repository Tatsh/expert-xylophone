/** @file
 * The extend-note catalogue list model. It fetches the extend-note catalogue from the server in
 * pages, resolves each entry against StoreKit, caches the parsed @c StoreExtendNoteInfo records,
 * and reports load progress to its delegate. It also drives the optional-products request used to
 * open a single extend-note pack from an external launch.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreExtendNoteList, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import "Downloader.h"

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
 * @param list The reporting list model.
 */
- (void)extendNoteListDownloadSuccess:(nullable RBStoreExtendNoteList *)list;
/**
 * @brief A catalogue page failed to load.
 * @param list The reporting list model.
 * @param errorMessage The failure message, or @c nil for the default message.
 */
- (void)extendNoteListDownloadError:(nullable RBStoreExtendNoteList *)list
                       errorMessage:(nullable NSString *)errorMessage;
/**
 * @brief The catalogue loaded but contained no extend notes.
 * @param list The reporting list model.
 */
- (void)extendNoteListDownloadNothing:(nullable RBStoreExtendNoteList *)list;
/**
 * @brief The optional-products request resolved the pack queued for an external launch.
 */
- (void)forceOpenExtendNoteView;

@end

/**
 * @brief The extend-note catalogue list model.
 */
@interface RBStoreExtendNoteList : NSObject <DownloaderDelegate, SKProductsRequestDelegate>

/**
 * @brief The delegate notified as the catalogue loads.
 * @ghidraAddress 0xc11c4 (getter)
 * @ghidraAddress 0xc11a4 (setter)
 */
@property(nonatomic, weak, nullable) id<StoreExtendNoteListDelegate> delegate;
/**
 * @brief The parsed extend-note records loaded so far.
 * @ghidraAddress 0xc11f8 (getter)
 * @ghidraAddress 0xc1208 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<StoreExtendNoteInfo *> *arrayExtendNoteInfo;
/**
 * @brief The ordered product identifiers currently loaded, as boxed integers.
 * @ghidraAddress 0xc1240 (getter)
 * @ghidraAddress 0xc1250 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<NSNumber *> *listProductID;
/**
 * @brief The in-flight catalogue-page downloader, when a page fetch is active.
 * @ghidraAddress 0xc1288 (getter)
 * @ghidraAddress 0xc1298 (setter)
 */
@property(nonatomic, strong, nullable) Downloader *extendNotelistDownloader;
/**
 * @brief The server catalogue dictionary held while its StoreKit products are being resolved.
 * @ghidraAddress 0xc12d0 (getter)
 * @ghidraAddress 0xc12e0 (setter)
 */
@property(nonatomic, strong, nullable) NSDictionary *tempExtendNoteList;
/**
 * @brief The in-flight StoreKit products request, when one is active.
 * @ghidraAddress 0xc1318 (getter)
 * @ghidraAddress 0xc1328 (setter)
 */
@property(nonatomic, strong, nullable) SKProductsRequest *productsRequest;
/**
 * @brief The number of catalogue items already fetched (the paging cursor).
 * @ghidraAddress 0xc1360 (getter)
 * @ghidraAddress 0xc1370 (setter)
 */
@property(nonatomic, assign) unsigned int fetchedExtendNoteNum;
/**
 * @brief Whether the current products request is the single-pack optional-products request.
 * @ghidraAddress 0xc1380 (getter)
 * @ghidraAddress 0xc1390 (setter)
 */
@property(nonatomic, assign) BOOL isOptionalProductRequest;
/**
 * @brief Whether the catalogue has further pages to load.
 * @ghidraAddress 0xc11d8 (getter)
 * @ghidraAddress 0xc11e8 (setter)
 */
@property(nonatomic, assign) BOOL extendNoteListContinued;

/**
 * @brief Whether a catalogue fetch (page download or products request) is currently in flight.
 * @return @c YES while a page downloader or a StoreKit products request is active.
 * @ghidraAddress 0xbf488
 */
@property(nonatomic, readonly) BOOL isFetching;

/**
 * @brief The parsed extend-note records loaded so far.
 * @return The @c arrayExtendNoteInfo backing store.
 * @ghidraAddress 0xbf50c
 */
- (nullable NSMutableArray<StoreExtendNoteInfo *> *)extendMusicInfos;
/**
 * @brief The ordered product identifiers currently loaded, as boxed integers.
 * @return The @c listProductID backing store.
 * @ghidraAddress 0xbf518
 */
- (nullable NSMutableArray<NSNumber *> *)extendNoteProductIDList;

/**
 * @brief Returns the cached extend-note record for the given product identifier.
 * @param productID The extend-note product identifier.
 * @return The cached record, or @c nil when it is not loaded.
 * @ghidraAddress 0xbf524
 */
- (nullable StoreExtendNoteInfo *)getExtendNoteInfoWithProductID:(int)productID;
/**
 * @brief Returns the cached extend-note record for the given product identifier, creating and
 * caching a placeholder record from the identifier when none exists.
 * @param productID The extend-note product identifier.
 * @return The resolved record.
 * @ghidraAddress 0xbf684
 */
- (nullable StoreExtendNoteInfo *)addExtendNoteInfoFromProductID:(int)productID;

/**
 * @brief Begins fetching the next catalogue page.
 * @return @c YES when a fetch was started, @c NO when one was already in flight.
 * @ghidraAddress 0xbf1a0
 */
- (BOOL)startFetching;
/**
 * @brief Cancels any in-flight catalogue-page download or StoreKit products request.
 * @ghidraAddress 0xbf338
 */
- (void)cancelFetching;
/**
 * @brief Requests the single-pack optional-products catalogue queued for an external launch.
 * @ghidraAddress 0xc07f4
 */
- (void)optionalProductsRequest;

/**
 * @brief Merges a resolved StoreKit products response with the server catalogue dictionary,
 * updating and caching the extend-note records, then notifies the delegate.
 * @param dictionary The server catalogue dictionary.
 * @param response The resolved StoreKit products response, or @c nil.
 * @ghidraAddress 0xbf768
 */
- (void)updateExtendNoteInfo:(nullable NSDictionary *)dictionary
          SKProductsResponse:(nullable SKProductsResponse *)response;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
