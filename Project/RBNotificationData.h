/** @file
 * A small @c NSCoding-conforming data model wrapping a single push-notification payload
 * dictionary. Instances are archived and unarchived under the coder key @c notificationList and
 * are queued in the app delegate's pending push list.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBNotificationData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An archivable wrapper around a single push-notification payload dictionary.
 */
@interface RBNotificationData : NSObject <NSCoding>

/**
 * @brief The wrapped push-notification payload dictionary.
 * @ghidraAddress 0x39db4 (getter)
 * @ghidraAddress 0x39dc4 (setter)
 */
@property(nonatomic, strong, nullable) NSDictionary *notificationDict;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
