#import "RBNumberLabel.h"

#import "UIImage+RB.h"

static const NSInteger kMaxDigits = 10;
static const int kDecimalRadix = 10;
static const float kDecimalScale = 10.0f;
static const NSInteger kDecimalMinDigits = 2;
static const CGFloat kCenterFactor = 0.5;

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

static NSString *const kSmallDecimalPointName = @"04_customize/cus_unlock_nms_dp";
static NSString *const kLimePrefixName = @"04_customize/cus_unlock_lime";

@implementation RBNumberLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.number = 0.0f;
    }
    return self;
}

#pragma mark - Properties

- (void)setNumber:(float)number {
    if (_number == number) {
        return;
    }
    _number = number;
    [self setNeedsDisplay];
}

- (void)setImageType:(RBNumberLabelImageType)imageType {
    if (_imageType == imageType) {
        return;
    }
    _imageType = imageType;
    [self setNeedsDisplay];
}

#pragma mark - Drawing

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

    if (self.imageType == RBNumberLabelImageTypeLime) {
        for (NSInteger slot = 0; slot < count; ++slot) {
            if (slot == 0) {
                UIImage *prefix = [UIImage imageWithName:kLimePrefixName];
                pen -= prefix.size.width;
            }
            UIImage *glyph = RBNumberLabelGlyphImage(self.imageType, digits[slot], slot);
            pen -= glyph.size.width;
        }
        pen = CGRectGetMinX(rect) + pen * -kCenterFactor;
    }

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
