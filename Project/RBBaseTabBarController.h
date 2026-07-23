/** @file
 * The shared base tab bar controller for the store screens. It is a @c UITabBarController subclass
 * that supplies the store's status-bar and rotation policy; @c RBStoreTabController derives from
 * it. This header declares only the surface that @c RBStoreTabController depends on (its
 * superclass identity); the base class adds no ivars and only overrides standard
 * @c UIViewController status-bar and rotation methods, so the full class is not reconstructed
 * here.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBBaseTabBarController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store screens' common tab bar controller base, supplying status-bar and rotation
 *        policy.
 */
@interface RBBaseTabBarController : UITabBarController

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
