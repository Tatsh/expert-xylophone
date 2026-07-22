//
//  RBCampaignData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBCampaignData). Verified against
//  the arm64 disassembly (the store colour components travel the soft-float path, so the
//  decompiler garbles the per-component divide-by-255, and the download completion handlers are
//  reconstructed from the captured block layout).
//

#import "RBCampaignData.h"

// Collaborator class reached from the store image download path. Its header is not yet
// reconstructed in this tree; the import resolves once that class lands, matching the
// speculative-import style already used by AppDelegate.mm and RBExperienceData.m.
#import "ImageDownloader.h"

/// Top-level campaign descriptor keys.
static NSString *const kCampaignNameKey = @"Name";
static NSString *const kCampaignOptionKey = @"Option";

/// The campaign name that marks the March 2017 "hinabita" collaboration, also seeded by
/// @c presetHinabitaMode.
static NSString *const kHinabita201703CampaignName = @"201703hnbt";

/// Campaign option keys. The "a01" entry carries the message list; the "cNN" entries carry the
/// store skin colours and images.
static NSString *const kCampaignMessageListKey = @"a01";
static NSString *const kStoreBaseColorKey = @"c01";
static NSString *const kStoreStrapImageKey = @"c02";
static NSString *const kStoreBaseImageKey = @"c03";
static NSString *const kStoreSampleColorKey = @"c11";
static NSString *const kStoreColorPackAKey = @"c21";
static NSString *const kStoreColorPackBKey = @"c22";

/// The colour component array index for each channel parsed by @c setColor:key:.
static const NSUInteger kColorComponentRed = 0;
static const NSUInteger kColorComponentGreen = 1;
static const NSUInteger kColorComponentBlue = 2;
static const NSUInteger kColorComponentAlpha = 3;

/// The divisor that maps a 0-255 colour component to the 0-1 range @c UIColor expects.
static const double kColorComponentScale = 255.0;

/// The initial capacity reserved for the keyed table of in-flight store image downloaders.
static const NSUInteger kImageDownloadersCapacity = 5;

/// Whether the store images downloaded here are fetched without a Retina (2x) variant.
static const BOOL kStoreImageUnUseRetina = NO;

/// The cached singleton returned by @c sharedInstance.
/// @ghidraAddress 0x3dc6c8 (g_pRBCampaignDataSharedInstance)
static RBCampaignData *sSharedInstance = nil;

@implementation RBCampaignData

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    /** @ghidraAddress 0x9c404 */
    if (sSharedInstance == nil) {
        sSharedInstance = [[RBCampaignData alloc] init];
    }
    return sSharedInstance;
}

#pragma mark - Descriptor parsing

- (void)parseDictionary:(NSDictionary *)parseDictionary {
    /** @ghidraAddress 0x9c45c */
    if (parseDictionary == nil) {
        return;
    }
    self.campaignName = parseDictionary[kCampaignNameKey];
    if (self.campaignName != nil) {
        self.isCampaignMode = YES;
        if ([self.campaignName isEqualToString:kHinabita201703CampaignName]) {
            self.isCampaignHinabita201703 = YES;
        }
    }
    NSDictionary *option = parseDictionary[kCampaignOptionKey];
    if (option == nil) {
        return;
    }
    if (option[kCampaignMessageListKey] != nil) {
        self.messageList = option[kCampaignMessageListKey];
    }
    if (option[kStoreBaseColorKey] != nil) {
        [self setColor:option[kStoreBaseColorKey] key:kStoreBaseColorKey];
    }
    if (option[kStoreStrapImageKey] != nil) {
        [self startDownloadWithPath:option[kStoreStrapImageKey] key:kStoreStrapImageKey];
    }
    if (option[kStoreBaseImageKey] != nil) {
        [self startDownloadWithPath:option[kStoreBaseImageKey] key:kStoreBaseImageKey];
    }
    if (option[kStoreSampleColorKey] != nil) {
        [self setColor:option[kStoreSampleColorKey] key:kStoreSampleColorKey];
    }
    if (option[kStoreColorPackAKey] != nil) {
        [self setColor:option[kStoreColorPackAKey] key:kStoreColorPackAKey];
    }
    if (option[kStoreColorPackBKey] != nil) {
        [self setColor:option[kStoreColorPackBKey] key:kStoreColorPackBKey];
    }
}

- (void)setColor:(NSArray *)color key:(NSString *)key {
    /** @ghidraAddress 0x9c8e4 */
    if (color == nil || key == nil) {
        return;
    }
    UIColor *parsed =
        [UIColor colorWithRed:[color[kColorComponentRed] doubleValue] / kColorComponentScale
                        green:[color[kColorComponentGreen] doubleValue] / kColorComponentScale
                         blue:[color[kColorComponentBlue] doubleValue] / kColorComponentScale
                        alpha:[color[kColorComponentAlpha] doubleValue] / kColorComponentScale];
    if (parsed == nil) {
        return;
    }
    if ([kStoreBaseColorKey isEqualToString:key]) {
        self.storeBaseColor = parsed;
    }
    if ([kStoreSampleColorKey isEqualToString:key]) {
        self.storeSampleColor = parsed;
    }
    if ([kStoreColorPackAKey isEqualToString:key]) {
        self.storeColorPackA = parsed;
    }
    if ([kStoreColorPackBKey isEqualToString:key]) {
        self.storeColorPackB = parsed;
    }
}

- (void)startDownloadWithPath:(NSString *)startDownloadWithPath key:(NSString *)key {
    /** @ghidraAddress 0x9cbc8 */
    if (key == nil) {
        return;
    }
    __weak RBCampaignData *weakSelf = self;
    if (self.imageDownloaders == nil) {
        self.imageDownloaders =
            [[NSMutableDictionary alloc] initWithCapacity:kImageDownloadersCapacity];
    }
    if ([self.imageDownloaders objectForKey:key] != nil) {
        // A download for this key is already in flight; if its image is ready, route it now.
        if ([key isEqualToString:kStoreBaseImageKey]) {
            self.storeBaseImage = [[self.imageDownloaders objectForKey:key] getImage];
        }
        if ([key isEqualToString:kStoreStrapImageKey]) {
            self.storeStrapImage = [[self.imageDownloaders objectForKey:key] getImage];
        }
        return;
    }
    ImageDownloader *downloader =
        [[ImageDownloader alloc] initWithGetURL:startDownloadWithPath
                                    unUseRetina:kStoreImageUnUseRetina];
    [self.imageDownloaders setObject:downloader forKey:key];
    [downloader
        startDownloadWithProceed:^(ImageDownloader *proceedDownloader) {
        }
        success:^(ImageDownloader *finishedDownloader) {
          /** @ghidraAddress 0x9d070 */
          // Route the finished image by its key, then cancel and drop the downloader.
          if ([key isEqualToString:kStoreBaseImageKey]) {
              weakSelf.storeBaseImage = [finishedDownloader getImage];
          }
          if ([key isEqualToString:kStoreStrapImageKey]) {
              weakSelf.storeStrapImage = [finishedDownloader getImage];
          }
          [finishedDownloader cancelDownload];
          [weakSelf.imageDownloaders removeObjectForKey:key];
        }
        failure:^(ImageDownloader *failedDownloader) {
          /** @ghidraAddress 0x9d284 */
          [failedDownloader cancelDownload];
          [weakSelf.imageDownloaders removeObjectForKey:key];
        }];
}

#pragma mark - Hinabita mode

- (void)presetHinabitaMode {
    /** @ghidraAddress 0x9d37c */
    self.campaignName = kHinabita201703CampaignName;
    self.isCampaignHinabita201703 = NO;
}

- (void)setHinabitaMode:(BOOL)hinabitaMode {
    /** @ghidraAddress 0x9d3bc */
    self.isCampaignHinabita201703 = hinabitaMode;
}

@end
