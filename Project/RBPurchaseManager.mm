//
//  RBPurchaseManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBPurchaseManager). Verified
//  against the arm64 disassembly (the fast-enumeration loops, the variadic error-building message
//  sends, and the receipt-verification response parsing are partly obscured by the decompiler).
//

#import "RBPurchaseManager.h"

#import <CoreFoundation/CoreFoundation.h>

// Collaborator classes reached from these methods. Their headers are not all reconstructed in this
// tree yet (the same speculative-import style AppDelegate.mm and RBMusicManager.m already use); they
// resolve once those classes land. Downloader, StoreUtil, and BFCodec are committed;
// PurchaseTransactionCache is not.
#import "AppDelegate.h"
#import "BFCodec.h"
#import "NSData+RB.h"
#import "NSFileManager+RB.h"
#import "PurchaseTransactionCache.h"
#import "StoreUtil.h"
#import "deviceenvironment.h"
#import "enginecrypto.h"

// The filename the encrypted owned-product list is written to under Application Support.
// @ghidraAddress 0x337b84 (the filename literal)
static NSString *const kProductListFilename = @"prodlist";

// The random header the saved product list is prefixed with, and the offset that skips it on load.
constexpr NSUInteger kProductListSaltLength = 4;

// The initial capacities the mutable arrays are created with.
constexpr NSUInteger kSmallListCapacity = 0;
constexpr NSUInteger kProductListCapacity = 32;
constexpr NSUInteger kSavedListCapacity = 128;

// The length of the receipt-verification nonce, in characters.
constexpr NSUInteger kReceiptNonceLength = 32;

// The text encoding the verification response body and its JSON request are (de)serialised with.
constexpr NSStringEncoding kResponseEncoding = NSUTF8StringEncoding;

// Keys read from the verification response JSON, and the response signature header.
// @ghidraAddress 0x337b8d (@c "status"), 0x337b94 (@c "Products"), 0x337b9d (@c "error"),
// 0x337ba3 (@c "MsgDev"), 0x337baa (@c "RB-RES-SIG-V2")
static NSString *const kResponseStatusKey = @"status";
static NSString *const kResponseProductsKey = @"Products";
static NSString *const kResponseErrorKey = @"error";
static NSString *const kResponseMessageKey = @"MsgDev";
static NSString *const kResponseSignatureHeader = @"RB-RES-SIG-V2";

// The status value that marks a successful verification response.
constexpr int kResponseStatusOK = 0;

// The empty string the failure @c NSError is built from (an empty domain, description, and code).
// @ghidraAddress 0x32dca6 (the empty-string literal)
static NSString *const kEmptyErrorText = @"";
constexpr NSInteger kErrorCode = 0;

// The Base64 alphabet shared by the encoders and the decoder.
constexpr char kBase64Alphabet[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
constexpr char kBase64Pad = '=';

// The number of input bytes and output characters a Base64 group spans.
constexpr NSUInteger kBase64InputGroup = 3;
constexpr NSUInteger kBase64OutputGroup = 4;

@implementation RBPurchaseManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    // @ghidraAddress 0x3dc308 (g_pRBPurchaseManagerSharedManager)
    static RBPurchaseManager *sSharedManager = nil;
    if (!sSharedManager) {
        sSharedManager = [[RBPurchaseManager alloc] init];
    }
    return sSharedManager;
}

- (instancetype)init {
    if ((self = [super init])) {
        self.purchasedProducts = [[NSMutableArray alloc] initWithCapacity:kSmallListCapacity];
        self.purchaseCheckedProductsIn =
            [[NSMutableArray alloc] initWithCapacity:kSmallListCapacity];
        self.purchaseCheckTransactions =
            [[NSMutableArray alloc] initWithCapacity:kSmallListCapacity];
        self.productIds = [[NSMutableArray alloc] init];
        self.transactioing = NO;
        self.isRestored = NO;
        self.restoredTransactions = [[NSMutableArray alloc] initWithCapacity:kSmallListCapacity];
    }
    return self;
}

- (void)dealloc {
    self.delegate = nil;
    [self.downloader cancel];
}

#pragma mark - Availability

+ (BOOL)isPurchasable {
    return SKPaymentQueue.canMakePayments;
}

#pragma mark - Observing

- (void)start {
    [SKPaymentQueue.defaultQueue addTransactionObserver:self];
}

- (void)end {
    [SKPaymentQueue.defaultQueue removeTransactionObserver:self];
}

#pragma mark - Owned-product persistence

- (void)saveProductList {
    if (self.purchasedProducts.count == 0) {
        return;
    }

    NSString *path =
        [GetApplicationSupportPath() stringByAppendingPathComponent:kProductListFilename];
    NSString *key = [AppDelegate musicListKey];

    CFDataRef plist = CFPropertyListCreateXMLData(
        kCFAllocatorDefault, (__bridge CFPropertyListRef)self.purchasedProducts);

    // Prefix the property list with a random salt so two saves of the same set differ on disk.
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:kSavedListCapacity];
    u_int32_t salt = arc4random();
    [data appendBytes:&salt length:kProductListSaltLength];
    [data appendData:(__bridge NSData *)plist];
    CFRelease(plist);

    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:Md5StringToData(key.UTF8String)];
    [codec encipher:data];
    [data writeToFile:path atomically:YES];
}

- (void)loadProductList {
    NSString *path =
        [GetApplicationSupportPath() stringByAppendingPathComponent:kProductListFilename];
    if ([NSFileManager isFileExist:path]) {
        NSString *key = [AppDelegate musicListKey];
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
        if (data) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:Md5StringToData(key.UTF8String)];
            [codec decipher:data];
            NSData *payload =
                [data subdataWithRange:NSMakeRange(kProductListSaltLength,
                                                   data.length - kProductListSaltLength)];
            self.purchasedProducts = payload.mutableArray;
        }
    }
    if (!self.purchasedProducts) {
        self.purchasedProducts = [[NSMutableArray alloc] initWithCapacity:kProductListCapacity];
    }
}

#pragma mark - Purchasing

- (BOOL)isPurchased:(NSString *)productID {
    return [self.purchasedProducts containsObject:productID];
}

- (BOOL)beginPurchase:(SKProduct *)product {
    if (product && !self.transactioing && SKPaymentQueue.canMakePayments &&
        ![self isPurchased:product.productIdentifier]) {
        [self.productIds removeAllObjects];
        self.transactioing = YES;
        self.isRestored = NO;
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.quantity = 1;
        [SKPaymentQueue.defaultQueue addPayment:payment];
        return YES;
    }
    return NO;
}

- (BOOL)beginRestore {
    if (!self.transactioing && SKPaymentQueue.canMakePayments) {
        self.productIds = [[NSMutableArray alloc] init];
        [self.purchaseCheckedProductsIn removeAllObjects];
        [self.restoredTransactions removeAllObjects];
        [self.productIds removeAllObjects];
        self.transactioing = YES;
        self.isRestored = YES;
        [SKPaymentQueue.defaultQueue restoreCompletedTransactions];
        return YES;
    }
    return NO;
}

#pragma mark - Purchase-checked products

- (NSMutableArray *)purchaseCheckedProducts {
    return self.purchaseCheckedProductsIn;
}

- (void)removePurchaseCheckedProduct:(NSString *)productID {
    [self.purchaseCheckedProductsIn removeObject:productID];
}

- (void)clearPurchaseCheckedProducts {
    [self.purchaseCheckedProductsIn removeAllObjects];
}

- (BOOL)addProductID:(NSString *)productID Save:(BOOL)save {
    if ([self.purchasedProducts containsObject:productID]) {
        return NO;
    }
    [self.purchasedProducts addObject:productID];
    if (save) {
        [self saveProductList];
    }
    return YES;
}

- (void)addProductFromPurchaseCheckedProducts {
    for (NSString *productID in self.purchaseCheckedProductsIn) {
        [self addProductID:productID Save:NO];
    }
    [self saveProductList];
}

#pragma mark - Receipt verification

- (BOOL)addPurchaseCheckTransaction:(id)transaction {
    PurchaseTransactionCache *cache = static_cast<PurchaseTransactionCache *>(transaction);
    if (transaction && ![self isPurchased:[cache productID]]) {
        [self.purchaseCheckTransactions addObject:transaction];
        [self checkNextReceipt];
        return YES;
    }
    return NO;
}

- (BOOL)checkNextReceipt {
    if (self.purchaseCheckTransactions.count == 0 || self.downloader) {
        return NO;
    }

    NSData *receiptData = [NSData dataWithContentsOfURL:NSBundle.mainBundle.appStoreReceiptURL];
    self.nonce = [StoreUtil createNonce:kReceiptNonceLength];
    NSString *receipt = [RBPurchaseManager encodedStringWithBase64V2:receiptData];
    NSString *json = [StoreUtil createReceiptCheckJSONForV2:receipt
                                                 productIds:self.productIds
                                                      nonce:self.nonce];
    NSData *post = [json dataUsingEncoding:kResponseEncoding];
    Downloader *downloader = [[Downloader alloc] initWithURL:StoreUtil.receiptV3URL
                                                        post:post
                                                 contentType:@"application/json"];
    id transaction = self.purchaseCheckTransactions.lastObject;
    self.downloader = downloader;
    downloader.addData = transaction;
    [downloader startDownloadingWithDelegate:self];
    return YES;
}

#pragma mark - SKRequestDelegate

- (void)requestDidFinish:(SKRequest *)request {
    if (request) {
        [self checkNextReceipt];
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue
    updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        NSString *productID = transaction.payment.productIdentifier;
        SKPaymentTransactionState state = transaction.transactionState;
        if (state == SKPaymentTransactionStatePurchased) {
            if (self.transactioing) {
                [self.productIds addObject:productID];
                PurchaseTransactionCache *cache =
                    [[PurchaseTransactionCache alloc] initWithTransaction:transaction];
                if (![self addPurchaseCheckTransaction:cache]) {
                    if ([self.delegate respondsToSelector:@selector(purchaseFailed:error:)]) {
                        [self.delegate purchaseFailed:cache.productID error:nil];
                    }
                }
            }
            [SKPaymentQueue.defaultQueue finishTransaction:transaction];
            self.transactioing = NO;
        } else if (state == SKPaymentTransactionStateFailed) {
            if ([self.delegate respondsToSelector:@selector(purchaseFailed:error:)]) {
                [self.delegate purchaseFailed:productID error:transaction.error];
            }
            [SKPaymentQueue.defaultQueue finishTransaction:transaction];
            self.transactioing = NO;
        } else if (state == SKPaymentTransactionStateRestored) {
            if (self.transactioing && self.isRestored &&
                ![self isPurchased:transaction.payment.productIdentifier]) {
                PurchaseTransactionCache *cache =
                    [[PurchaseTransactionCache alloc] initWithTransaction:transaction];
                [self.restoredTransactions addObject:cache];
                [self.productIds addObject:cache.productID];
            }
            [SKPaymentQueue.defaultQueue finishTransaction:transaction];
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue
    removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        (void)transaction;
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    for (id transaction in self.restoredTransactions) {
        (void)transaction;
    }
    while (YES) {
        if (self.restoredTransactions.count == 0) {
            if ([self.delegate respondsToSelector:@selector(restoreNothing)]) {
                [self.delegate restoreNothing];
            }
            self.isRestored = NO;
            self.transactioing = NO;
            break;
        }
        id transaction = self.restoredTransactions.lastObject;
        [self.restoredTransactions removeLastObject];
        if ([self addPurchaseCheckTransaction:transaction]) {
            break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue
    restoreCompletedTransactionsFailedWithError:(NSError *)error {
    [self.restoredTransactions removeAllObjects];
    if ([self.delegate respondsToSelector:@selector(restoreFailed:)]) {
        [self.delegate restoreFailed:error];
    }
    self.isRestored = NO;
    self.transactioing = NO;
}

#pragma mark - DownloaderDelegate

- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *header = downloader.getHeader;
    NSString *body = [[NSString alloc] initWithData:downloader.getData encoding:kResponseEncoding];
    NSString *productID = [static_cast<PurchaseTransactionCache *>(downloader.addData) productID];

    BOOL verified = NO;
    NSDictionary *json = downloader.getDataInJSON;
    if (json) {
        if ([json[kResponseStatusKey] intValue] == kResponseStatusOK) {
            NSArray *products = json[kResponseProductsKey];
            (void)json[kResponseErrorKey];
            (void)json[kResponseMessageKey];
            NSString *signature = header[kResponseSignatureHeader];
            NSString *digest = [StoreUtil createReceiptCheckDigestV2:body withNonce:self.nonce];
            verified = products && [signature isEqualToString:digest] && products.count != 0;
        }
    }

    if (!self.isRestored) {
        if (verified) {
            if ([self.delegate respondsToSelector:@selector(purchaseSucceeded:)]) {
                [self.delegate purchaseSucceeded:productID];
            }
        } else {
            NSError *error = [self errorWithEmptyDescription];
            if ([self.delegate respondsToSelector:@selector(purchaseFailed:error:)]) {
                [self.delegate purchaseFailed:productID error:error];
            }
        }
        self.transactioing = NO;
    } else if (verified) {
        for (NSString *checkedID in self.productIds) {
            [self.purchaseCheckedProductsIn addObject:checkedID];
        }
        [self.restoredTransactions removeAllObjects];
    } else {
        [self.purchaseCheckedProductsIn removeAllObjects];
        [self.restoredTransactions removeAllObjects];
        if ([self.delegate respondsToSelector:@selector(restoreFailed:)]) {
            [self.delegate restoreFailed:[self errorWithEmptyDescription]];
        }
        self.transactioing = NO;
        self.isRestored = NO;
    }

    self.downloader = nil;

    if (self.isRestored) {
        while (YES) {
            if (self.restoredTransactions.count == 0) {
                if ([self.delegate respondsToSelector:@selector(restoreSucceeded)]) {
                    [self.delegate restoreSucceeded];
                }
                self.transactioing = NO;
                self.isRestored = NO;
                break;
            }
            id transaction = self.restoredTransactions.lastObject;
            [self.restoredTransactions removeLastObject];
            if ([self addPurchaseCheckTransaction:transaction]) {
                break;
            }
        }
    }
}

- (void)downloaderProceed:(Downloader *)downloader {
}

- (void)downloaderError:(Downloader *)downloader {
    NSString *productID = [static_cast<PurchaseTransactionCache *>(downloader.addData) productID];
    if (!self.isRestored) {
        NSError *error = [self errorWithEmptyDescription];
        if ([self.delegate respondsToSelector:@selector(purchaseFailed:error:)]) {
            [self.delegate purchaseFailed:productID error:error];
        }
    } else {
        [self.purchaseCheckedProductsIn removeAllObjects];
        [self.restoredTransactions removeAllObjects];
        if ([self.delegate respondsToSelector:@selector(restoreFailed:)]) {
            [self.delegate restoreFailed:[self errorWithEmptyDescription]];
        }
    }
    self.downloader = nil;
    self.transactioing = NO;
    self.isRestored = NO;
}

#pragma mark - Helpers

// Build the empty-domain, empty-description failure error the verification callbacks report.
- (NSError *)errorWithEmptyDescription {
    NSString *description =
        [NSString stringWithString:[NSString stringWithFormat:@"%@", kEmptyErrorText]];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:description
                                                         forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:kEmptyErrorText code:kErrorCode userInfo:userInfo];
}

#pragma mark - Base64

+ (NSString *)encodedStringWithBase64:(NSData *)data {
    const char *bytes = data.bytes;
    NSUInteger length = data.length;
    NSUInteger capacity = ((length * 8 + 23) / 6 & ~3UL) + kBase64OutputGroup;
    char *out = new char[capacity];
    NSUInteger written = 0;

    if (length != 0) {
        const char *end = bytes + length;
        char *cursor = out;
        do {
            // The final partial group is signalled by a NUL byte in the second or third slot; the
            // pad count then decides how many trailing '=' characters replace the encoded chars.
            char b1 = bytes[0];
            char b2 = bytes[1];
            BOOL secondIsNul = b2 == 0;
            const char *nextAfterSecond = secondIsNul ? bytes + 1 : bytes + 2;
            unsigned char padCount = secondIsNul ? 2 : 1;
            char b3 = *nextAfterSecond;
            const char *next = nextAfterSecond;
            if (b3 != 0) {
                next = nextAfterSecond + 1;
                padCount = secondIsNul ? 1 : 0;
            }
            cursor[0] = kBase64Alphabet[b1 >> 2];
            cursor[1] = kBase64Alphabet[(b1 << 4 | static_cast<unsigned char>(b2) >> 4) & 0x3f];
            cursor[2] = kBase64Alphabet[(b2 << 2 | static_cast<unsigned char>(b3) >> 6) & 0x3f];
            cursor[3] = padCount == 0 ? kBase64Alphabet[b3 & 0x3f] : kBase64Pad;
            if (padCount > 1) {
                cursor[2] = kBase64Pad;
            }
            cursor += kBase64OutputGroup;
            written += kBase64OutputGroup;
            bytes = next;
        } while (bytes != end);
    }
    out[written] = 0;

    NSString *result = [NSString stringWithCString:out encoding:NSASCIIStringEncoding];
    delete[] out;
    return result;
}

+ (NSString *)encodedStringWithBase64V2:(NSData *)data {
    const unsigned char *bytes = data.bytes;
    NSUInteger length = data.length;
    NSUInteger groups = length / kBase64InputGroup;
    if (length != groups * 2 + length / kBase64InputGroup) {
        ++groups;
    }
    char *out = static_cast<char *>(malloc((groups << 2) | 1));
    if (!out) {
        return nil;
    }

    NSUInteger inIndex = 0;
    NSUInteger outIndex = 0;
    if (length >= kBase64InputGroup) {
        do {
            const unsigned char *group = bytes + inIndex;
            out[outIndex] = kBase64Alphabet[group[0] >> 2];
            out[outIndex + 1] = kBase64Alphabet[group[1] >> 4 | (group[0] & 3) << 4];
            out[outIndex + 2] = kBase64Alphabet[group[2] >> 6 | (group[1] & 0xf) << 2];
            out[outIndex + 3] = kBase64Alphabet[group[2] & 0x3f];
            inIndex += kBase64InputGroup;
            outIndex += kBase64OutputGroup;
        } while (inIndex + 2 < length);
    }

    if (inIndex + 1 < length) {
        out[outIndex] = kBase64Alphabet[bytes[inIndex] >> 2];
        out[outIndex + 1] = kBase64Alphabet[bytes[inIndex + 1] >> 4 | (bytes[inIndex] & 3) << 4];
        out[outIndex + 2] = kBase64Alphabet[(bytes[inIndex + 1] & 0xf) << 2];
        out[outIndex + 3] = kBase64Pad;
        outIndex += kBase64OutputGroup;
    } else if (inIndex < length) {
        out[outIndex] = kBase64Alphabet[bytes[inIndex] >> 2];
        out[outIndex + 1] = kBase64Alphabet[(bytes[inIndex] & 3) << 4];
        out[outIndex + 2] = kBase64Pad;
        out[outIndex + 3] = kBase64Pad;
        outIndex += kBase64OutputGroup;
    }
    out[outIndex] = 0;

    NSString *result = [[NSString alloc] initWithBytes:out
                                                length:outIndex
                                              encoding:NSASCIIStringEncoding];
    free(out);
    return result;
}

+ (NSData *)decodedStringWithBase64:(NSString *)string {
    NSUInteger length = [string lengthOfBytesUsingEncoding:kResponseEncoding];
    const char *chars = string.UTF8String;
    unsigned char *out = new unsigned char[length * kBase64InputGroup >> 2];
    int written = 0;

    if (length != 0) {
        const char *end = chars + length;
        do {
            unsigned char values[kBase64OutputGroup];
            for (int slot = 0; slot < static_cast<int>(kBase64OutputGroup); ++slot) {
                unsigned char value = 0xff;
                for (int index = 0; index < static_cast<int>(sizeof(kBase64Alphabet)); ++index) {
                    if (kBase64Alphabet[index] == chars[slot]) {
                        value = static_cast<unsigned char>(index);
                        break;
                    }
                }
                values[slot] = value;
            }
            out[written] = values[0] << 2 | (values[1] >> 4 & 3);
            out[written + 1] = values[1] << 4 | (values[2] >> 2 & 0xf);
            out[written + 2] = (values[3] & 0x3f) | values[2] << 6;
            int advanced = values[3] != 0xff ? written + 3 : written + 2;
            written = values[2] != 0xff ? advanced : written + 1;
            chars += kBase64OutputGroup;
        } while (chars != end);
    }

    NSData *result = [NSData dataWithBytes:out length:written];
    delete[] out;
    return result;
}

@end
