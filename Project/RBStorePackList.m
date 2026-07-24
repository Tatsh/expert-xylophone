#import "RBStorePackList.h"

#import "AppDelegate.h"
#import "Downloader.h"
#import "RBUserSettingData.h"
#import "StorePackInfo.h"
#import "StorePackListGenre.h"
#import "StoreUtil.h"
#import "engineglobals.h"

// The default genre presented before any catalogue page has loaded, with identifier zero. Its name
// is a three-character CFString literal at 0x36eee0 whose data lives at 0x41c800; that __cstring
// region is not mapped in the Ghidra image, so the exact three characters could not be recovered.
// "ALL" is the length-matching best guess and is unverified at the byte level.
static NSString *const kStoreDefaultGenreName = @"ALL"; // @ghidraAddress 0x36eee0
enum { kStoreDefaultGenreID = 0 };

// The number of packs requested per catalogue page.
enum { kStorePackListPageSize = 10 };

// The purchase-limit type is reset to this "unset" tier, and the running purchase total is zeroed,
// when a newer purchase month is reported by the server.
enum { kPurchaseLimitTypeUnset = 0 };
enum { kPurchaseTotalReset = 0 };

// The purchase-limit type must be below this bound (the age-tier count) to be reset.
enum { kPurchaseLimitTypeCount = 3 };

// The queued deep-link ("open store") pack identifier is only valid when strictly positive.
enum { kInvalidPackID = 0 };

// The initial capacities used when building the model's mutable collections.
enum {
    kPackInfoInitialCapacity = 50,
    kGenreInitialCapacity = 8,
    kProductIDSetCapacity = 10,
};

// The result of -indexOfObjectIdenticalTo: when the object is absent.
static const NSUInteger kNotFoundIndex = NSNotFound;

// The catalogue JSON dictionary keys.
static NSString *const kStoreJSONKeyVersion = @"Version";
static NSString *const kStoreJSONKeyDate = @"Date";
static NSString *const kStoreJSONKeyPackList = @"PackList";
static NSString *const kStoreJSONKeyError = @"Error";
static NSString *const kStoreJSONKeyPromotion = @"Promotion";
static NSString *const kStoreJSONKeyGenre = @"Genre";
static NSString *const kStoreJSONKeyID = @"ID";
static NSString *const kStoreJSONKeyHasNext = @"HasNext";

// The genre payload is a two-element array: the identifiers first, then the parallel names.
enum {
    kGenrePayloadCount = 2,
    kGenrePayloadIndexIDs = 0,
    kGenrePayloadIndexNames = 1,
};

// The app version compares as equal or newer only when the shop-master version does not order after
// it. -compare:options: returns this when the info-dictionary version is older than the requirement.
static const NSComparisonResult kVersionRequirementUnmet = NSOrderedAscending;

// The country code most recently seen on a StoreKit product's price locale, retained across product
// requests so the store can detect a currency change.
static NSString *_lastProductCountryCode = nil;

@implementation RBStorePackList

#pragma mark - Store country

/** @ghidraAddress 0x1f05fc */
+ (NSString *)storeCountry {
    if (_lastProductCountryCode != nil) {
        return [NSString stringWithString:_lastProductCountryCode];
    }
    return nil;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1f063c */
- (instancetype)init {
    self = [super init];
    if (self) {
        self->_packlistContinued = YES;
        self.arrayPackInfo = [[NSMutableArray alloc] initWithCapacity:kPackInfoInitialCapacity];
        self.arrayGenre = [[NSMutableArray alloc] initWithCapacity:kGenreInitialCapacity];
        [self.arrayGenre addObject:[[StorePackListGenre alloc] initWithName:kStoreDefaultGenreName
                                                                    genreID:kStoreDefaultGenreID]];
    }
    return self;
}

#pragma mark - Fetch control

/** @ghidraAddress 0x1f094c */
- (BOOL)isFetching {
    if (self.packlistDownloader != nil) {
        return YES;
    }
    return self.productsRequest != nil;
}

/** @ghidraAddress 0x1f07fc */
- (void)cancelFetching {
    if (self.packlistDownloader != nil) {
        [self.packlistDownloader cancel];
        self.packlistDownloader = nil;
    }
    if (self.productsRequest != nil) {
        [self.productsRequest cancel];
        self.productsRequest.delegate = nil;
        self.productsRequest = nil;
    }
}

#pragma mark - Genre access

/** @ghidraAddress 0x1f09d0 */
- (NSMutableArray<StorePackInfo *> *)packInfos {
    return self.arrayPackInfo;
}

/** @ghidraAddress 0x1f09dc */
- (NSUInteger)numGenres {
    return self.arrayGenre.count;
}

/** @ghidraAddress 0x1f0a3c */
- (NSArray<NSString *> *)genreNames {
    NSMutableArray<NSString *> *names =
        [[NSMutableArray alloc] initWithCapacity:self.arrayGenre.count];
    [self.arrayGenre
        enumerateObjectsUsingBlock:^(StorePackListGenre *genre, NSUInteger idx, BOOL *stop) {
          /** @ghidraAddress 0x1f0b84 */
          [names addObject:genre.genreName];
        }];
    return names;
}

/** @ghidraAddress 0x1f0c04 */
- (void)addGenres:(NSArray *)genres {
    if (genres.count != kGenrePayloadCount) {
        return;
    }
    NSArray *genreIDs = genres[kGenrePayloadIndexIDs];
    NSArray *genreNames = genres[kGenrePayloadIndexNames];
    if (![genreIDs isKindOfClass:[NSArray class]] || ![genreNames isKindOfClass:[NSArray class]]) {
        return;
    }
    [genreIDs enumerateObjectsUsingBlock:^(id genreID, NSUInteger idx, BOOL *stop) {
      /** @ghidraAddress 0x1f0dd8 */
      if (idx >= genreNames.count) {
          *stop = YES;
          return;
      }
      id name = genreNames[idx];
      if ([genreID isKindOfClass:[NSNumber class]] && [name isKindOfClass:[NSString class]]) {
          StorePackListGenre *genre =
              [[StorePackListGenre alloc] initWithName:name genreID:[genreID unsignedIntegerValue]];
          [self.arrayGenre addObject:genre];
      }
    }];
}

/** @ghidraAddress 0x1f0fe8 */
- (StorePackListGenre *)packListForGenreIndex:(NSUInteger)index {
    if (index < self.arrayGenre.count) {
        return self.arrayGenre[index];
    }
    return nil;
}

#pragma mark - Fetch

/** @ghidraAddress 0x1f10bc */
- (void)startFetchForGenreIndex:(NSUInteger)index {
    if (index >= self.arrayGenre.count) {
        return;
    }
    self.genreFetching = self.arrayGenre[index];
    NSURL *url = [StoreUtil packListURL:self.genreFetching.numFetchedPack + 1
                                  limit:kStorePackListPageSize
                                  genre:self.genreFetching.genreID];
    self.packlistDownloader = [[Downloader alloc] initWithURL:url save:nil];
    [self.packlistDownloader startDownloadingWithDelegate:self];
}

/** @ghidraAddress 0x1f1304 */
- (void)startFetchGenre:(StorePackListGenre *)genre {
    NSUInteger index = [self.arrayGenre indexOfObjectIdenticalTo:genre];
    if (index != kNotFoundIndex) {
        [self startFetchForGenreIndex:index];
    }
}

#pragma mark - Pack cache

/** @ghidraAddress 0x1f13b4 */
- (StorePackInfo *)getPackInfo:(int)packID {
    for (StorePackInfo *packInfo in self.arrayPackInfo) {
        if (packInfo.packID == packID) {
            return packInfo;
        }
    }
    return nil;
}

/** @ghidraAddress 0x1f1514 */
- (StorePackInfo *)addPackInfoFromID:(int)packID {
    StorePackInfo *packInfo = [self getPackInfo:packID];
    if (packInfo == nil) {
        packInfo = [[StorePackInfo alloc] initWithPackID:packID];
        [self.arrayPackInfo addObject:packInfo];
    }
    return packInfo;
}

#pragma mark - Downloader delegate

/** @ghidraAddress 0x1f2a84 */
- (void)downloaderProceed:(Downloader *)downloader {
}

/** @ghidraAddress 0x1f1ca0 */
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    NSString *requiredVersion = json[kStoreJSONKeyVersion];
    NSString *appVersion = [[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleVersion"];

    int lastPurchaseMonth = [RBUserSettingData sharedInstance].lastPurchaseMonth;
    NSNumber *date = json[kStoreJSONKeyDate];
    if (date != nil) {
        int month = json[kStoreJSONKeyDate].intValue;
        if (lastPurchaseMonth < month) {
            if ([RBUserSettingData sharedInstance].purchaseLimitType < kPurchaseLimitTypeCount) {
                [RBUserSettingData sharedInstance].purchaseLimitType = kPurchaseLimitTypeUnset;
            }
            [RBUserSettingData sharedInstance].totalPurchase = kPurchaseTotalReset;
        }
        [RBUserSettingData sharedInstance].lastPurchaseMonth = month;
    }
    [[RBUserSettingData sharedInstance] save];

    if (appVersion == nil || (requiredVersion != nil &&
                              [appVersion compare:requiredVersion
                                          options:NSNumericSearch] == kVersionRequirementUnmet)) {
        // The binary formats the version-mismatch message without substituting its positional
        // arguments.
        NSString *message = [NSString stringWithFormat:g_pLocalizedUpdateRequiredFormat];
        [self.delegate packListDownloadError:self errorMessage:message];
    } else {
        NSArray *packList = json[kStoreJSONKeyPackList];
        if (packList.count == 0) {
            NSString *error = json[kStoreJSONKeyError];
            if (error == nil) {
                error = g_pLocalizedServerNoData;
            }
            [self.delegate packListDownloadError:self errorMessage:error];
        } else {
            NSMutableSet<NSString *> *productIDs =
                [NSMutableSet setWithCapacity:kStorePackListPageSize];
            BOOL sawPack = NO;
            for (NSDictionary *entry in packList) {
                NSNumber *packID = entry[kStoreJSONKeyID];
                if (packID != nil) {
                    int pid = packID.intValue;
                    if ([self getPackInfo:pid] == nil) {
                        [productIDs addObject:[StoreUtil productIDForPackID:pid]];
                    }
                    sawPack = YES;
                }
            }

            if (self.promotionList == nil) {
                NSArray *promotion = json[kStoreJSONKeyPromotion];
                if (promotion != nil) {
                    self.promotionList = [[NSArray alloc] initWithArray:promotion];
                    for (NSDictionary *entry in promotion) {
                        NSNumber *packID = entry[kStoreJSONKeyID];
                        if (packID != nil) {
                            int pid = packID.intValue;
                            if ([self getPackInfo:pid] == nil) {
                                [productIDs addObject:[StoreUtil productIDForPackID:pid]];
                            }
                        }
                    }
                }

                if ([AppDelegate appDelegate].getPackIDForOpenStore != nil) {
                    int pid = [AppDelegate appDelegate].getPackIDForOpenStore.intValue;
                    if ([self getPackInfo:pid] == nil) {
                        [productIDs addObject:[StoreUtil productIDForPackID:pid]];
                    }
                }

                if (json[kStoreJSONKeyGenre] != nil) {
                    [self addGenres:json[kStoreJSONKeyGenre]];
                }
            }

            if (productIDs.count == 0) {
                if (sawPack) {
                    [self updatePackInfo:json SKProductsResponse:nil];
                } else {
                    [self.delegate packListDownloadError:self
                                            errorMessage:g_pLocalizedServerNoData];
                }
            } else {
                self.tempPackList = [[NSDictionary alloc] initWithDictionary:json];
                if (self.productsRequest != nil) {
                    [self.productsRequest cancel];
                    self.productsRequest.delegate = nil;
                    self.productsRequest = nil;
                }
                self.productsRequest =
                    [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
                self.productsRequest.delegate = self;
                [self.productsRequest start];
            }
        }
    }
    self.packlistDownloader = nil;
}

/** @ghidraAddress 0x1f29fc */
- (void)downloaderError:(Downloader *)downloader {
    [self.delegate packListDownloadError:self errorMessage:g_pLocalizedServerConnectFailed];
    self.packlistDownloader = nil;
}

#pragma mark - StoreKit product request

/** @ghidraAddress 0x1f2a88 */
- (void)optionalProductsRequest {
    if ([AppDelegate appDelegate].getPackIDForOpenStore == nil) {
        return;
    }
    int packID = [AppDelegate appDelegate].getPackIDForOpenStore.intValue;
    if (packID <= kInvalidPackID || [self getPackInfo:packID] != nil) {
        return;
    }
    NSMutableSet<NSString *> *productIDs = [NSMutableSet setWithCapacity:kProductIDSetCapacity];
    [productIDs addObject:[StoreUtil productIDForPackID:packID]];
    if (productIDs.count == 0) {
        return;
    }
    if (self.productsRequest != nil) {
        [self.productsRequest cancel];
        self.productsRequest.delegate = nil;
        self.productsRequest = nil;
    }
    self.isOptionalProductRequest = YES;
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
}

/** @ghidraAddress 0x1f2db4 */
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    if (response.products.count != 0) {
        NSString *countryCode =
            [response.products.lastObject.priceLocale objectForKey:NSLocaleCountryCode];
        if (_lastProductCountryCode == nil ||
            ![_lastProductCountryCode isEqualToString:countryCode]) {
            _lastProductCountryCode = [[NSString alloc] initWithString:countryCode];
        }
    }

    [self updatePackInfo:self.tempPackList SKProductsResponse:response];
    self.productsRequest = nil;
    self.tempPackList = nil;

    if (self.isOptionalProductRequest) {
        self.isOptionalProductRequest = NO;
        if (response.invalidProductIdentifiers != nil) {
            int packID = [AppDelegate appDelegate].getPackIDForOpenStore.intValue;
            NSString *productID = [StoreUtil productIDForPackID:packID];
            if ([response.invalidProductIdentifiers containsObject:productID]) {
                [AppDelegate appDelegate].packIDForOpenStore = nil;
                return;
            }
        }
        if ([self.delegate respondsToSelector:@selector(forceOpenPackDetailView)]) {
            [self.delegate performSelector:@selector(forceOpenPackDetailView)];
        }
    }
}

/** @ghidraAddress 0x1f31f8 */
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    self.productsRequest = nil;
    self.tempPackList = nil;
    [self.delegate packListDownloadError:self errorMessage:g_pLocalizedServerConnectFailed];
    self.isOptionalProductRequest = NO;
}

#pragma mark - Catalogue merge

/** @ghidraAddress 0x1f15f8 */
- (void)updatePackInfo:(NSDictionary *)packList SKProductsResponse:(SKProductsResponse *)response {
    if (response != nil) {
        for (SKProduct *product in response.products) {
            int packID = [StoreUtil packIDForProductID:product.productIdentifier];
            if ([self getPackInfo:packID] == nil) {
                [self.arrayPackInfo addObject:[[StorePackInfo alloc] initWithProduct:product]];
            }
        }
    }

    NSMutableArray<NSNumber *> *loadedPackIDs =
        [[NSMutableArray alloc] initWithCapacity:kStorePackListPageSize];
    for (NSDictionary *entry in packList[kStoreJSONKeyPackList]) {
        int packID = [entry[kStoreJSONKeyID] intValue];
        StorePackInfo *packInfo = [self getPackInfo:packID];
        if (packInfo != nil) {
            [packInfo setDictionary:entry];
            [loadedPackIDs addObject:@(packID)];
        }
    }

    if (!self.isOptionalProductRequest) {
        self->_packlistContinued = [packList[kStoreJSONKeyHasNext] boolValue];
    }

    if (loadedPackIDs.count == 0) {
        if (self.delegate != nil) {
            [self.delegate packListDownloadNothing:self];
        }
    } else {
        [self.genreFetching updateList:loadedPackIDs
                                  step:kStorePackListPageSize
                               hasNext:self->_packlistContinued];
        if (self.delegate != nil) {
            [self.delegate packListDownloadSuccess:self];
        }
    }
}

@end
