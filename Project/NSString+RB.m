#import "NSString+RB.h"

// The RFC 3986 reserved set plus the percent sign and square brackets, as JavaScript escapes.
static NSString *const kURIComponentEscapedCharacters = @"!*'();:@&=+$,/?%#[]";

@implementation NSString (RB)

#pragma mark - URL encoding

- (NSString *)encodeURIComponent {
    /** @ghidraAddress 0x1b82a4 */
    return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault,
        (__bridge CFStringRef)self,
        NULL,
        (__bridge CFStringRef)kURIComponentEscapedCharacters,
        kCFStringEncodingUTF8));
}

#pragma mark - Font-based sizing

- (CGSize)sizeWithFont:(UIFont *)font {
    /** @ghidraAddress 0x1b82d0 */
    return [self sizeWithAttributes:@{NSFontAttributeName : font}];
}

- (CGSize)sizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size {
    /** @ghidraAddress 0x1b83c4 */
    return [self sizeWithFont:font constrainedToSize:size lineBreakMode:NSLineBreakByWordWrapping];
}

- (CGSize)sizeWithFont:(UIFont *)font
     constrainedToSize:(CGSize)size
         lineBreakMode:(NSLineBreakMode)lineBreakMode {
    /** @ghidraAddress 0x1b83e4 */
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = lineBreakMode;
    style.alignment = NSTextAlignmentLeft;
    NSDictionary *attributes = @{NSFontAttributeName : font, NSParagraphStyleAttributeName : style};
    return [self boundingRectWithSize:size
                              options:NSStringDrawingUsesLineFragmentOrigin
                           attributes:attributes
                              context:nil]
        .size;
}

#pragma mark - Font-based drawing

- (void)drawInRect:(CGRect)rect withFont:(UIFont *)font {
    /** @ghidraAddress 0x1b8578 */
    [self drawInRect:rect withAttributes:@{NSFontAttributeName : font}];
}

- (void)drawInRect:(CGRect)rect
          withFont:(UIFont *)font
     lineBreakMode:(NSLineBreakMode)lineBreakMode
         alignment:(NSTextAlignment)alignment {
    /** @ghidraAddress 0x1b8684 */
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = lineBreakMode;
    style.alignment = alignment;
    NSDictionary *attributes = @{NSFontAttributeName : font, NSParagraphStyleAttributeName : style};
    [self drawInRect:rect withAttributes:attributes];
}

- (void)drawAtPoint:(CGPoint)point withFont:(UIFont *)font {
    /** @ghidraAddress 0x1b881c */
    [self drawAtPoint:point withAttributes:@{NSFontAttributeName : font}];
}

@end
