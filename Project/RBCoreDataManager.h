/** @file
 * The Core Data stack singleton for the app. It owns two independent stacks: the score stack that
 * backs the @c ScoreData records and the history stack that backs the @c History records. Each
 * stack lazily builds its managed object context, managed object model, and persistent store
 * coordinator on first access and caches them.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBCoreDataManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 * @brief The shared owner of the app's Core Data stacks.
 *
 * Callers reach the score stack through @c managedObjectContext and the history stack through
 * @c historyContext; each getter lazily builds and caches its coordinator, model, and context.
 */
@interface RBCoreDataManager : NSObject

/**
 * @brief The managed object context for the score stack, built lazily on first access.
 */
@property(nonatomic, strong) NSManagedObjectContext *managedObjectContext;

/**
 * @brief The managed object model for the score stack, loaded lazily from the bundled model on
 * first access.
 */
@property(nonatomic, strong) NSManagedObjectModel *managedObjectModel;

/**
 * @brief The persistent store coordinator for the score stack, built lazily on first access.
 */
@property(nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

/**
 * @brief The managed object context for the history stack, built lazily on first access.
 */
@property(nonatomic, strong) NSManagedObjectContext *historyContext;

/**
 * @brief The managed object model for the history stack, loaded lazily from the bundled model on
 * first access.
 */
@property(nonatomic, strong) NSManagedObjectModel *historyModel;

/**
 * @brief The persistent store coordinator for the history stack, built lazily on first access.
 */
@property(nonatomic, strong) NSPersistentStoreCoordinator *historyCoordinator;

/**
 * @brief The shared manager, created once through @c dispatch_once.
 * @return The singleton instance.
 * @ghidraAddress 0x1cb234
 */
+ (instancetype)sharedInstance;

/**
 * @brief The file name of the score store, chosen by device variant.
 * @return @c ScoreData.sqlite on the tablet variant, otherwise @c ScoreDataPhone.sqlite.
 * @ghidraAddress 0x1cb2e8
 */
- (NSString *)scoreDataFileName;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
