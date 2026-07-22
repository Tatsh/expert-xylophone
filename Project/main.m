//
//  main.m
//  REFLEC BEAT plus
//
//  Application entry point. Reconstructed from Ghidra project rb458, program rb458
//  (entry @ 0x10038, relative to the image base 0x100000000). The binary's entry
//  does exactly what a standard iOS main() emits: push an autorelease pool, then
//  call UIApplicationMain with a nil principal class name and the delegate class
//  name "AppDelegate", popping the pool on return. The
//  objc_autoreleasePoolPush/Pop pair Ghidra shows is the @autoreleasepool
//  lowering; the third argument (principalClassName) is nil (0) in the binary, and
//  the fourth is an embedded CFString literal "AppDelegate" (equivalent to
//  NSStringFromClass([AppDelegate class])).
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
