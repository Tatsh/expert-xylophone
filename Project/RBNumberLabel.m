//
//  RBNumberLabel.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBNumberLabel). Verified against the
//  arm64 disassembly: the glyph tables and their asset names, the number-by-ten scaling for the
//  decimal style, the ten-digit split, the two-pass layout that measures the run before centring the
//  lime style, the bottom-aligned right-to-left glyph placement, and the small decimal-point marker
//  drawn after the fractional digit.
//

#import "RBNumberLabel.h"

#import "UIImage+RB.h"

// The number of decimal digits the split buffer holds.
static const NSInteger kMaxDigits = 10;

// The radix the number is split into digits with.
static const int kDecimalRadix = 10;

// The number of decimal places the decimal style shows; the number is scaled by ten so the single
// fractional digit falls into the least-significant slot.
static const float kDecimalScale = 10.0f;

// The decimal style always shows at least an integer digit and one fractional digit.
static const NSInteger kDecimalMinDigits = 2;

// The fraction of the measured run width the lime style shifts left by to centre it.
static const CGFloat kCentreFactor = 0.5;

// The whole-number digit glyphs (cus_unlock_nm_0 … cus_unlock_nm_9).
static NSString *const kNormalDigitNames[] = {
    @"04_customize/cus_unlock_nm_0",
    @"04_customize/cus_unlock_nm_1",
    @"04_customize/cus_unlock_nm_2",
    @"04_customize/cus_unlock_nm_3",
    @"04_customize/cus_unlock_nm_4",
    @"04_customize/cus_unlock_nm_5",
    @"04_customize/cus_unlock_nm_6",
    @"04_customize/cus_unlock_nm_7",
    @"04_customize/cus_unlock_nm_8",
    @"04_customize/cus_unlock_nm_9",
};

// The big integer-part digit glyphs of the decimal style (cus_unlock_nmb_0 … cus_unlock_nmb_9).
static NSString *const kBigDigitNames[] = {
    @"04_customize/cus_unlock_nmb_0",
    @"04_customize/cus_unlock_nmb_1",
    @"04_customize/cus_unlock_nmb_2",
    @"04_customize/cus_unlock_nmb_3",
    @"04_customize/cus_unlock_nmb_4",
    @"04_customize/cus_unlock_nmb_5",
    @"04_customize/cus_unlock_nmb_6",
    @"04_customize/cus_unlock_nmb_7",
    @"04_customize/cus_unlock_nmb_8",
    @"04_customize/cus_unlock_nmb_9",
};

// The small fractional-digit glyphs of the decimal style (cus_unlock_nms_0 … cus_unlock_nms_9).
static NSString *const kSmallDigitNames[] = {
    @"04_customize/cus_unlock_nms_0",
    @"04_customize/cus_unlock_nms_1",
    @"04_customize/cus_unlock_nms_2",
    @"04_customize/cus_unlock_nms_3",
    @"04_customize/cus_unlock_nms_4",
    @"04_customize/cus_unlock_nms_5",
    @"04_customize/cus_unlock_nms_6",
    @"04_customize/cus_unlock_nms_7",
    @"04_customize/cus_unlock_nms_8",
    @"04_customize/cus_unlock_nms_9",
};

// The lime-badged digit glyphs (cus_unlock_0 … cus_unlock_9).
static NSString *const kLimeDigitNames[] = {
    @"04_customize/cus_unlock_0",
    @"04_customize/cus_unlock_1",
    @"04_customize/cus_unlock_2",
    @"04_customize/cus_unlock_3",
    @"04_customize/cus_unlock_4",
    @"04_customize/cus_unlock_5",
    @"04_customize/cus_unlock_6",
    @"04_customize/cus_unlock_7",
    @"04_customize/cus_unlock_8",
    @"04_customize/cus_unlock_9",
};

// The small decimal-point glyph drawn after the fractional digit of the decimal style.
static NSString *const kSmallDecimalPointName = @"04_customize/cus_unlock_nms_dp";

// The prefix badge drawn with the lime style.
static NSString *const kLimePrefixName = @"04_customize/cus_unlock_lime";

@implementation RBNumberLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.number = 0.0f;
    }
    return self;
}

// Look up the glyph image for a digit under a style, honouring the small/big split of the decimal
// style's fractional slot.
static UIImage *
RBNumberLabelGlyphImage(RBNumberLabelImageType imageType, int digit, NSInteger slot) {
    switch (imageType) {
    case RBNumberLabelImageTypeNormal:
        return [UIImage imageWithName:kNormalDigitNames[digit]];
    case RBNumberLabelImageTypeDecimal:
        if (slot < 1) {
            return [UIImage imageWithName:kSmallDigitNames[digit]];
        }
        return [UIImage imageWithName:kBigDigitNames[digit]];
    case RBNumberLabelImageTypeLime:
        return [UIImage imageWithName:kLimeDigitNames[digit]];
    }
    return nil;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    float value = self.number;
    if (self.imageType == RBNumberLabelImageTypeDecimal) {
        value *= kDecimalScale;
    }

    int digits[kMaxDigits];
    NSInteger significant = 0;
    int remainder = (int)value;
    for (NSInteger i = 0; i < kMaxDigits; ++i) {
        digits[i] = remainder % kDecimalRadix;
        if (digits[i] != 0) {
            significant = i + 1;
        }
        remainder /= kDecimalRadix;
    }

    NSInteger count = significant;
    if (count < 1) {
        count = 1;
    }
    if (self.imageType == RBNumberLabelImageTypeDecimal && count < kDecimalMinDigits) {
        count = kDecimalMinDigits;
    }

    CGFloat pen = CGRectGetWidth(rect);

    // First pass: for the lime style, measure the run width so it can be centred horizontally.
    if (self.imageType == RBNumberLabelImageTypeLime) {
        for (NSInteger slot = 0; slot < count; ++slot) {
            if (slot == 0) {
                UIImage *prefix = [UIImage imageWithName:kLimePrefixName];
                pen -= prefix.size.width;
            }
            UIImage *glyph = RBNumberLabelGlyphImage(self.imageType, digits[slot], slot);
            pen -= glyph.size.width;
        }
        pen = CGRectGetMinX(rect) + pen * -kCentreFactor;
    }

    // Second pass: draw each glyph bottom-aligned, laid out right to left from the pen position.
    CGFloat bottom = CGRectGetHeight(rect);
    for (NSInteger slot = 0; slot < count; ++slot) {
        if (slot == 0 && self.imageType == RBNumberLabelImageTypeLime) {
            UIImage *prefix = [UIImage imageWithName:kLimePrefixName];
            CGSize prefixSize = prefix.size;
            pen -= prefixSize.width;
            [prefix drawInRect:CGRectMake(pen,
                                          bottom - prefixSize.height,
                                          prefixSize.width,
                                          prefixSize.height)];
        }

        UIImage *glyph = RBNumberLabelGlyphImage(self.imageType, digits[slot], slot);
        CGSize glyphSize = glyph.size;
        pen -= glyphSize.width;
        [glyph drawInRect:CGRectMake(
                              pen, bottom - glyphSize.height, glyphSize.width, glyphSize.height)];

        if (slot == 0 && self.imageType == RBNumberLabelImageTypeDecimal) {
            UIImage *point = [UIImage imageWithName:kSmallDecimalPointName];
            CGSize pointSize = point.size;
            pen -= pointSize.width;
            [point
                drawInRect:CGRectMake(
                               pen, bottom - pointSize.height, pointSize.width, pointSize.height)];
        }
    }
}

@end
