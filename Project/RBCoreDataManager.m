//
//  RBCoreDataManager.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBCoreDataManager). Verified
//  against the arm64 disassembly (the store-option dictionary and the variadic
//  addPersistentStoreWithType:configuration:URL:options:error: message are dropped or garbled by
//  the decompiler, and the RBCoreDataManager struct is mispacked in the project so several methods
//  fail to decompile and were read from the disassembly instead).
//

#import "RBCoreDataManager.h"

#import "neEngineBridge.h"

// The score store file name for the tablet and phone variants.
static NSString *const kScoreDataStoreFileName = @"ScoreData.sqlite";
static NSString *const kScoreDataPhoneStoreFileName = @"ScoreDataPhone.sqlite";

// The history store file name.
static NSString *const kHistoryStoreFileName = @"History.data";

// Bundled managed object model resource names and their type.
static NSString *const kScoreDataModelResource = @"ScoreData";
static NSString *const kHistoryModelResource = @"History";
static NSString *const kManagedObjectModelType = @"mom";

@implementation RBCoreDataManager

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize historyContext = _historyContext;
@synthesize historyModel = _historyModel;
@synthesize historyCoordinator = _historyCoordinator;

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    /** @ghidraAddress 0x1cb234 */
    static RBCoreDataManager *sSharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /** @ghidraAddress 0x1cb2a4 */
        sSharedInstance = [[self alloc] init];
    });
    return sSharedInstance;
}

#pragma mark - Store names

- (NSString *)scoreDataFileName {
    /** @ghidraAddress 0x1cb2e8 */
    return GetFontVariantFlag() != kFontVariantDefault ? kScoreDataStoreFileName : kScoreDataPhoneStoreFileName;
}

#pragma mark - Score stack

- (NSManagedObjectContext *)managedObjectContext {
    /** @ghidraAddress 0x1cb314 */
    if (_managedObjectContext == nil) {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil) {
            _managedObjectContext = [[NSManagedObjectContext alloc] init];
            _managedObjectContext.persistentStoreCoordinator = coordinator;
        }
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    /** @ghidraAddress 0x1cb3c8 */
    if (_managedObjectModel == nil) {
        NSString *path = [[NSBundle mainBundle] pathForResource:kScoreDataModelResource
                                                         ofType:kManagedObjectModelType];
        NSURL *url = [NSURL fileURLWithPath:path];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    }
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    /** @ghidraAddress 0x1cb4e8 */
    if (_persistentStoreCoordinator == nil) {
        NSString *directory = GetApplicationSupportPath();
        NSString *storePath = [directory stringByAppendingPathComponent:self.scoreDataFileName];
        NSURL *storeURL = [NSURL fileURLWithPath:storePath];
        NSDictionary *options = @{
            NSMigratePersistentStoresAutomaticallyOption: [NSNumber numberWithBool:YES],
            NSInferMappingModelAutomaticallyOption: [NSNumber numberWithBool:YES],
        };
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
            initWithManagedObjectModel:self.managedObjectModel];
        NSError *error = nil;
        [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                  configuration:nil
                                                            URL:storeURL
                                                        options:options
                                                          error:&error];
    }
    return _persistentStoreCoordinator;
}

#pragma mark - History stack

- (NSManagedObjectContext *)historyContext {
    /** @ghidraAddress 0x1cb7b8 */
    if (_historyContext == nil) {
        NSPersistentStoreCoordinator *coordinator = self.historyCoordinator;
        if (coordinator != nil) {
            _historyContext = [[NSManagedObjectContext alloc] init];
            _historyContext.persistentStoreCoordinator = coordinator;
        }
    }
    return _historyContext;
}

- (NSManagedObjectModel *)historyModel {
    /** @ghidraAddress 0x1cb86c */
    if (_historyModel == nil) {
        NSString *path = [[NSBundle mainBundle] pathForResource:kHistoryModelResource
                                                         ofType:kManagedObjectModelType];
        NSURL *url = [NSURL fileURLWithPath:path];
        _historyModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    }
    return _historyModel;
}

- (NSPersistentStoreCoordinator *)historyCoordinator {
    /** @ghidraAddress 0x1cb98c */
    if (_historyCoordinator == nil) {
        NSString *directory = GetApplicationSupportPath();
        NSString *storePath = [directory stringByAppendingPathComponent:kHistoryStoreFileName];
        NSURL *storeURL = [NSURL fileURLWithPath:storePath];
        NSDictionary *options = @{
            NSMigratePersistentStoresAutomaticallyOption: [NSNumber numberWithBool:YES],
            NSInferMappingModelAutomaticallyOption: [NSNumber numberWithBool:YES],
        };
        _historyCoordinator = [[NSPersistentStoreCoordinator alloc]
            initWithManagedObjectModel:self.historyModel];
        NSError *error = nil;
        [_historyCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                          configuration:nil
                                                    URL:storeURL
                                                options:options
                                                  error:&error];
    }
    return _historyCoordinator;
}

@end
