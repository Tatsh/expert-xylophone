//
//  NSStringURLEncoding.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class NSStringURLEncoding). Verified
//  against the arm64 disassembly. Both methods wrap the CoreFoundation percent-escape APIs and
//  transfer the +1 create result into ARC with CFBridgingRelease.
//

#import "NSStringURLEncoding.h"

// The reserved characters escaped by +URLEncodedString: (the RFC 3986 reserved set plus the percent
// sign and square brackets).
static NSString *const kURLEscapedCharacters = @"!*'();:@&=+$,/?%#[]";

@implementation NSStringURLEncoding

+ (NSString *)URLEncodedString:(NSString *)string {
    return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault, (__bridge CFStringRef)string, NULL,
        (__bridge CFStringRef)kURLEscapedCharacters, kCFStringEncodingUTF8));
}

+ (NSString *)URLDecodedString:(NSString *)string {
    return CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(
        kCFAllocatorDefault, (__bridge CFStringRef)string, CFSTR(""), kCFStringEncodingUTF8));
}

@end
