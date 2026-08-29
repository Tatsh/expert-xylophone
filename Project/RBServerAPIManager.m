#import "RBServerAPIManager.h"

#import "AppDelegate.h"
#import "Downloader.h"
#import "NetworkUtil.h"
#import "RBUserSettingData.h"
#import "deviceenvironment.h"

static const NSUInteger kHTTPArrayInitialCapacity = 5;

static const unsigned int kPlayedV2MinMusicID = 99999999;

static NSString *const kJSONContentType = @"application/json";

static const NSUInteger kServerDataUserIDIndex = 0;

static NSString *const kParamKeyTarget = @"target";
static NSString *const kParamKeyUUID = @"uuid";
static NSString *const kParamKeyUserID = @"user_id";
static NSString *const kParamKeyUser = @"user";
static NSString *const kParamKeyVersion = @"version";

static NSString *const kParamKeyMusic = @"music";
static NSString *const kParamKeyDif = @"dif";
static NSString *const kParamKeyMusicID = @"music_id";
static NSString *const kParamKeyDifficulty = @"difficulty";
static NSString *const kParamKeyNote = @"note";
static NSString *const kParamKeyJR = @"jr";
static NSString *const kParamKeyScore = @"score";
static NSString *const kParamKeyDevice = @"device";
static NSString *const kParamKeyOS = @"os";
static NSString *const kParamKeyLocale = @"locale";

static NSString *const kParamKeyType = @"type";
static NSString *const kParamKeyID = @"id";
static NSString *const kParamKeyTP = @"tp";

static NSString *const kParamKeyTypes = @"types";

@implementation RBServerAPIManager

#pragma mark - Singleton

+ (instancetype)getInstance {
    /** @ghidraAddress 0x17ca08 */
    static RBServerAPIManager *sharedInstance = nil;
    if (!sharedInstance) {
        sharedInstance = [[RBServerAPIManager alloc] init];
        sharedInstance.httpArray =
            [[NSMutableArray alloc] initWithCapacity:kHTTPArrayInitialCapacity];
    }
    return sharedInstance;
}

#pragma mark - API calls

+ (void)playedAPIWithMusicID:(unsigned int)musicID dif:(unsigned int)dif {
    /** @ghidraAddress 0x17cac4 */
    NSDictionary *params = @{
        kParamKeyTarget : GetRegionCode(),
        kParamKeyMusic : [NSNumber numberWithUnsignedInt:musicID],
        kParamKeyDif : [NSNumber numberWithUnsignedInt:dif],
        kParamKeyUUID : [AppDelegate musicListKey]
    };
    NSData *body = [Downloader dictionaryToJsonData:params];
    Downloader *downloader = [[Downloader alloc] initWithURL:[NetworkUtil playedURL]
                                                        post:body
                                                 contentType:kJSONContentType];
    [[RBServerAPIManager getInstance].httpArray addObject:downloader];
    [downloader startDownloadingWithDelegate:[RBServerAPIManager getInstance]];
}

+ (void)playedV2APIWithMusicID:(unsigned int)musicID
                           dif:(unsigned int)dif
                          note:(unsigned int)note
                            jr:(unsigned int)jr
                         score:(unsigned int)score {
    /** @ghidraAddress 0x17ce50 */
    if (musicID < kPlayedV2MinMusicID) {
        return;
    }
    NSDictionary *params = @{
        kParamKeyTarget : GetRegionCode(),
        kParamKeyUserID : [AppDelegate getServerData][kServerDataUserIDIndex],
        kParamKeyUUID : [NetworkUtil identifierParams],
        kParamKeyMusicID : [NSNumber numberWithUnsignedInt:musicID],
        kParamKeyDifficulty : [NSNumber numberWithUnsignedInt:dif],
        kParamKeyNote : [NSNumber numberWithUnsignedInt:note],
        kParamKeyJR : [NSNumber numberWithUnsignedInt:jr],
        kParamKeyScore : [NSNumber numberWithUnsignedInt:score],
        kParamKeyDevice : [NetworkUtil deviceName],
        kParamKeyOS : GetSystemVersionString(),
        kParamKeyLocale : GetFormattedVersionString(),
        kParamKeyVersion : GetBundleVersionString()
    };
    NSData *body = [Downloader dictionaryToJsonData:params];
    Downloader *downloader = [[Downloader alloc] initWithURL:[NetworkUtil playedV2URL]
                                                        post:body
                                                 contentType:kJSONContentType];
    [[RBServerAPIManager getInstance].httpArray addObject:downloader];
    [downloader startDownloadingWithDelegate:[RBServerAPIManager getInstance]];
}

+ (void)unlockedAPIWithType:(unsigned int)type identity:(unsigned int)identity point:(float)point {
    /** @ghidraAddress 0x17d484 */
    NSDictionary *params = @{
        kParamKeyTarget : GetRegionCode(),
        kParamKeyType : [NSNumber numberWithUnsignedInt:type],
        kParamKeyID : [NSNumber numberWithUnsignedInt:identity],
        kParamKeyTP : [NSNumber numberWithFloat:point],
        kParamKeyUUID : [AppDelegate musicListKey]
    };
    NSData *body = [Downloader dictionaryToQueryData:params];
    Downloader *downloader = [[Downloader alloc] initWithURL:[NetworkUtil unlockedURL]
                                                        post:body
                                                 contentType:nil];
    [[RBServerAPIManager getInstance].httpArray addObject:downloader];
    [downloader startDownloadingWithDelegate:[RBServerAPIManager getInstance]];
}

+ (void)tutorialAPI {
    /** @ghidraAddress 0x17d860 */
    NSDictionary *params = @{
        kParamKeyUser : [AppDelegate getServerData][kServerDataUserIDIndex],
        kParamKeyTypes : [[RBUserSettingData sharedInstance] getTutorialStatusList],
        kParamKeyUUID : [AppDelegate musicListKey]
    };
    NSData *body = [Downloader dictionaryToJsonData:params];
    Downloader *downloader = [[Downloader alloc] initWithURL:[NetworkUtil tutorialStatusURL]
                                                        post:body
                                                 contentType:kJSONContentType];
    [[RBServerAPIManager getInstance].httpArray addObject:downloader];
    [downloader startDownloadingWithDelegate:[RBServerAPIManager getInstance]];
}

#pragma mark - DownloaderDelegate

- (void)downloaderProceed:(Downloader *)downloader {
    /** @ghidraAddress 0x17dca0 */
}

- (void)downloaderFinished:(Downloader *)downloader {
    /** @ghidraAddress 0x17dc08 */
    [downloader cancel];
    [self.httpArray removeObject:downloader];
}

- (void)downloaderError:(Downloader *)downloader {
    /** @ghidraAddress 0x17dca4 */
    [downloader cancel];
    [self.httpArray removeObject:downloader];
}

@end
