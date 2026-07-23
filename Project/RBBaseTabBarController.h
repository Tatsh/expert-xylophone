/** @file
 * The shared base tab bar controller for the store screens. It is a @c UITabBarController subclass
 * that supplies the store's status-bar and rotation policy; @c RBStoreTabController derives from
 * it. The class adds no ivars, properties, or protocols of its own: it only overrides the standard
 * @c UIViewController and @c UITabBarController status-bar, appearance, and rotation methods so
 * the store tabs adopt the region-dependent rotation lock and hidden status bar.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBBaseTabBarController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store screens' common tab bar controller base, supplying status-bar, appearance, and
 *        rotation policy.
 */
@interface RBBaseTabBarController : UITabBarController

/**
 * @brief Loads the view, then clears the tab bar's translucency on iOS 7 and later so the store
 *        tabs keep the opaque bar the pre-iOS-7 layout assumed.
 * @ghidraAddress 0x2029e4
 */
- (void)viewDidLoad;

/**
 * @brief Reports that the status bar is always hidden over the store screens.
 * @return Always @c YES.
 * @ghidraAddress 0x202af8
 */
- (BOOL)prefersStatusBarHidden;

/**
 * @brief Reports whether the store screens may autorotate. The default region always may; a font
 *        variant region may only while no background music is playing.
 * @return @c YES if rotation is permitted.
 * @ghidraAddress 0x202b00
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Reports the interface orientations the store screens support, gated on the region font
 *        variant, the background-music flag, and the current interface orientation.
 * @return The supported orientation mask.
 * @ghidraAddress 0x202b30
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Reports the preferred orientation used when the store screens are presented.
 * @return Always @c UIInterfaceOrientationPortrait.
 * @ghidraAddress 0x202b8c
 */
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation;

/**
 * @brief Reports whether the store screens may rotate to the given orientation. The default region
 *        always may; a iPad idiom region may rotate only to portrait orientations, and only
 *        while no background music is playing.
 * @param interfaceOrientation The orientation being queried.
 * @return @c YES if rotation to that orientation is permitted.
 * @ghidraAddress 0x202b94
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
