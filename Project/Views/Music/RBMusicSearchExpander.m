#import "RBMusicSearchExpander.h"

#import "deviceenvironment.h"

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
        [GetDocumentsDirectoryPath() stringByAppendingPathComponent:kSearchExpandDictFileName];
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
    // The encoding says NSDictionary, yet the binary feeds it straight to arrayWithArray:.
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
        [GetDocumentsDirectoryPath() stringByAppendingPathComponent:kSearchExpandDictFileName];
    if ([fileManager fileExistsAtPath:path]) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSDictionary *decoded =
            [NSJSONSerialization JSONObjectWithData:data
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
        [GetDocumentsDirectoryPath() stringByAppendingPathComponent:kSearchExpandDictFileName];
    [json writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

@end
