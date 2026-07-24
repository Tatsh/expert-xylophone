#import "RBMusicSearchExpander.h"

#import "neEngineBridge.h"

// The synonym dictionary is persisted as JSON under this name in the application-support directory,
// seeded on first run from the identically named bundled resource.
static NSString *const kSearchExpandDictResource = @"SearchExpandDict";
static NSString *const kSearchExpandDictType = @"txt";
static NSString *const kSearchExpandDictFileName = @"SearchExpandDict.txt";

@implementation RBMusicSearchExpander

+ (void)copyDictionary {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:kSearchExpandDictResource
                                                           ofType:kSearchExpandDictType];
    if (bundlePath == nil) {
        return;
    }
    NSString *destination =
        [GetApplicationSupportPath() stringByAppendingPathComponent:kSearchExpandDictFileName];
    NSError *error = nil;
    if ([fileManager fileExistsAtPath:destination]) {
        [fileManager removeItemAtPath:destination error:&error];
    }
    [fileManager copyItemAtPath:bundlePath toPath:destination error:&error];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadDictionary];
    }
    return self;
}

- (NSDictionary *)getDictionary {
    return [NSDictionary dictionaryWithDictionary:self.expandDict];
}

- (BOOL)addSearchInfo:(NSString *)addSearchInfo addWords:(NSDictionary *)addWords {
    // The parameter's method-type encoding is @"NSDictionary", yet the binary feeds it straight to
    // arrayWithArray:, so it is used as a word array here.
    NSMutableArray *words = [NSMutableArray arrayWithArray:(NSArray *)addWords];
    id existing = self.expandDict[addSearchInfo];
    if (existing != nil) {
        [words addObjectsFromArray:self.expandDict[addSearchInfo]];
        [self.expandDict removeObjectForKey:addSearchInfo];
    }
    NSArray *merged = [[NSSet setWithArray:words] allObjects];
    self.expandDict[addSearchInfo] = merged;
    return NO;
}

- (BOOL)addDictionary:(NSDictionary *)addDictionary {
    for (id key in [addDictionary allKeys]) {
        [self addSearchInfo:key addWords:addDictionary[key]];
    }
    return NO;
}

- (void)loadDictionary {
    self.expandDict = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path =
        [GetApplicationSupportPath() stringByAppendingPathComponent:kSearchExpandDictFileName];
    if ([fileManager fileExistsAtPath:path]) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSDictionary *decoded = [NSJSONSerialization JSONObjectWithData:data
                                                               options:NSJSONReadingMutableContainers
                                                                 error:nil];
        self.expandDict = [NSMutableDictionary dictionaryWithDictionary:decoded];
    } else {
        self.expandDict = [[NSMutableDictionary alloc] init];
    }
}

- (void)saveDictionary {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.expandDict
                                                  options:NSJSONWritingPrettyPrinted
                                                    error:&error];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *path =
        [GetApplicationSupportPath() stringByAppendingPathComponent:kSearchExpandDictFileName];
    [json writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

@end
