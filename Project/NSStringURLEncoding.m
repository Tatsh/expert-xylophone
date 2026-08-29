#import "NSStringURLEncoding.h"

static NSString *const kURLEscapedCharacters = @"!*'();:@&=+$,/?%#[]";

@implementation NSStringURLEncoding

+ (NSString *)URLEncodedString:(NSString *)string {
    return CFBridgingRelease(
        CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                (__bridge CFStringRef)string,
                                                NULL,
                                                (__bridge CFStringRef)kURLEscapedCharacters,
                                                kCFStringEncodingUTF8));
}

+ (NSString *)URLDecodedString:(NSString *)string {
    return CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(
        kCFAllocatorDefault, (__bridge CFStringRef)string, CFSTR(""), kCFStringEncodingUTF8));
}

@end
