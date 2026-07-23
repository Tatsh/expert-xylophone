//
//  UIImage+RB.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (category UIImage(RB)). Verified against
//  the arm64 disassembly: the CoreGraphics and CoreImage creators are variadic-shaped and their
//  scalar arguments arrive in VFP registers, so the decompiler drops several float parameters
//  (the crop scale, the reflection height, and the colour-matrix alpha) and lists the localised
//  loaders as taking no arguments; the true signatures were recovered from the register and stack
//  reads.
//

#import "UIImage+RB.h"

#import <CoreGraphics/CoreGraphics.h>
#import <CoreImage/CoreImage.h>

#import "RBUserSettingData.h"
#import "neEngineBridge.h"

// The shared image directory tried after the current theme directory.
static NSString *const kSharedImageDirectoryName = @"00_Share";

// The Retina asset-name suffix appended before the file extension.
static NSString *const kRetinaSuffixFormat = @"%@@2x";

// The format that joins an lproj folder to an asset name for the imageNamed: fallback.
static NSString *const kLprojPrefixedNameFormat = @"%@/%@";

// The PNG file extension used for on-disk image assets.
static NSString *const kImageFileExtension = @"png";

// The device-and-scale asset-name suffixes chosen for imageNamedWithoutCache:, selected by the
// font-variant (iPad) build flag and the Retina flag.
static NSString *const kRetinaPadDeviceTag = @"@2x~ipad";
static NSString *const kNonRetinaPadDeviceTag = @"~ipad";
static NSString *const kRetinaPhoneDeviceTag = @"@2x~iphone";

// The localised resource-name formats: name + device tag; name + language + device tag; and the
// region-specific Japanese and English forms.
static NSString *const kDeviceTaggedNameFormat = @"%@%@";
static NSString *const kLanguageTaggedNameFormat = @"%@_%@%@";
static NSString *const kJapaneseTaggedNameFormat = @"%@_ja%@";
static NSString *const kEnglishTaggedNameFormat = @"%@_en%@";

// The preferred-language and region codes recognised by the localised loader.
static NSString *const kLanguageCodeJapanese = @"ja";
static NSString *const kLanguageCodeEnglish = @"en";
static NSString *const kLanguagePrefixJapanese = @"ja-";
static NSString *const kLanguagePrefixEnglish = @"en-";
static NSString *const kRegionCodeJapan = @"JP";

// The Retina scale factors at which a crop rectangle is expressed in points rather than pixels.
static const CGFloat kRetinaScale2x = 2.0;
static const CGFloat kRetinaScale3x = 3.0;

// The bits per component of the colour and grey bitmap contexts.
static const size_t kBitsPerComponent = 8;

// The number of stops in the reflection alpha-gradient mask.
static const size_t kReflectionGradientStopCount = 2;

// The lazily created, owned themed-image cache keyed by asset name.
// @ghidraAddress 0x3df3d8 (g_pThemedImageCache)
static NSCache *g_pThemedImageCache = nil;

// Returns the shared themed-image cache, creating it on first use.
static NSCache *RBThemedImageCache(void) {
    if (g_pThemedImageCache == nil) {
        g_pThemedImageCache = [[NSCache alloc] init];
    }
    return g_pThemedImageCache;
}

// Loads a PNG resource of the given name from the main bundle.
static UIImage *RBBundleImage(NSString *resourceName) {
    NSString *path =
        [[NSBundle mainBundle] pathForResource:resourceName ofType:kImageFileExtension];
    return [UIImage imageWithContentsOfFile:path];
}

// Chooses the device-and-scale asset-name suffix for the running build: the iPad variant build
// uses "@2x~ipad" or "~ipad" by Retina, and the iPhone build uses "@2x~iphone".
static NSString *RBDeviceAssetTag(void) {
    if (GetFontVariantFlag() != kFontVariantDefault) {
        return GetIsRetinaFlag() ? kRetinaPadDeviceTag : kNonRetinaPadDeviceTag;
    }
    return kRetinaPhoneDeviceTag;
}

// Runs one localised bundle-image lookup pass for a base name and device tag: the plain
// device-tagged name, then a preferred-language variant, then the region-specific variant.
static UIImage *RBLocalizedBundleImage(NSString *name, NSString *deviceTag) {
    UIImage *image =
        RBBundleImage([NSString stringWithFormat:kDeviceTaggedNameFormat, name, deviceTag]);
    if (image != nil) {
        return image;
    }

    NSString *language = GetPreferredLanguageCode();
    if ([language isEqualToString:kLanguageCodeJapanese] ||
        [language isEqualToString:kLanguageCodeEnglish] ||
        [language rangeOfString:kLanguagePrefixJapanese].location != NSNotFound ||
        [language rangeOfString:kLanguagePrefixEnglish].location != NSNotFound) {
        NSString *languageName =
            [NSString stringWithFormat:kLanguageTaggedNameFormat, name, language, deviceTag];
        image = RBBundleImage(languageName);
        if (image != nil) {
            return image;
        }
    }

    NSString *regionFormat = [GetRegionCode() isEqualToString:kRegionCodeJapan]
                                 ? kJapaneseTaggedNameFormat
                                 : kEnglishTaggedNameFormat;
    return RBBundleImage([NSString stringWithFormat:regionFormat, name, deviceTag]);
}

@implementation UIImage (RB)

#pragma mark - Named-asset loading

+ (UIImage *)imageWithName:(NSString *)name {
    /** @ghidraAddress 0x1a2830 */
    return [self imageWithName:name useCache:YES];
}

+ (UIImage *)imageWithName:(NSString *)name useCache:(BOOL)useCache {
    /** @ghidraAddress 0x1a2858 */
    NSCache *cache = RBThemedImageCache();
    UIImage *cached = [cache objectForKey:name];
    if (cached != nil) {
        return cached;
    }

    NSString *themaName = [[RBUserSettingData sharedInstance] themaName];
    UIImage *image = [self imageWithName:name
                          imageDirectory:GetImageAssetDirectoryPath()
                          themaDirectory:themaName];
    if (image == nil) {
        image = [self imageWithName:name
                     imageDirectory:GetImageAssetDirectoryPath()
                     themaDirectory:kSharedImageDirectoryName];
    }
    if (image == nil) {
        NSString *primaryName =
            [NSString stringWithFormat:kLprojPrefixedNameFormat, GetPrimaryLprojName(), name];
        image = [UIImage imageNamed:primaryName];
        if (image == nil) {
            NSString *fallbackName =
                [NSString stringWithFormat:kLprojPrefixedNameFormat, GetFallbackLprojName(), name];
            image = [UIImage imageNamed:fallbackName];
            if (image == nil) {
                image = [self imageNamedWithoutCache:name];
            }
        }
    }

    if (image != nil && useCache) {
        [cache setObject:image forKey:name];
    }
    return image;
}

+ (UIImage *)imageWithName:(NSString *)name
            imageDirectory:(NSString *)imageDirectory
            themaDirectory:(NSString *)themaDirectory {
    /** @ghidraAddress 0x1a1a0c */
    if (GetIsRetinaFlag()) {
        UIImage *image = [self imageWithName:name
                              imageDirectory:imageDirectory
                              themaDirectory:themaDirectory
                                      retina:YES];
        if (image != nil) {
            return image;
        }
    }
    return [self imageWithName:name
               imageDirectory:imageDirectory
               themaDirectory:themaDirectory
                       retina:NO];
}

+ (UIImage *)imageWithName:(NSString *)name
            imageDirectory:(NSString *)imageDirectory
            themaDirectory:(NSString *)themaDirectory
                    retina:(BOOL)retina {
    /** @ghidraAddress 0x1a1644 */
    NSString *assetName = name;
    if (retina) {
        assetName = [NSString stringWithFormat:kRetinaSuffixFormat, name];
    }

    NSString *path = [[[imageDirectory stringByAppendingPathComponent:themaDirectory]
        stringByAppendingPathComponent:assetName]
        stringByAppendingPathExtension:kImageFileExtension];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (image != nil) {
        return image;
    }

    NSMutableArray *components = [NSMutableArray arrayWithArray:path.pathComponents];
    if (components.count >= 2) {
        [components insertObject:GetPrimaryLprojName() atIndex:components.count - 1];
        image = [UIImage imageWithContentsOfFile:[NSString pathWithComponents:components]];
        if (image != nil) {
            return image;
        }
    }
    if (components.count < 2) {
        return nil;
    }
    [components replaceObjectAtIndex:components.count - 1 withObject:GetFallbackLprojName()];
    return [UIImage imageWithContentsOfFile:[NSString pathWithComponents:components]];
}

+ (UIImage *)imageNamedWithoutCache:(NSString *)name {
    /** @ghidraAddress 0x1a1b08 */
    // The binary runs the localised lookup twice against the device-and-scale tag, then falls back
    // to the untagged resource name.
    UIImage *image = RBLocalizedBundleImage(name, RBDeviceAssetTag());
    if (image != nil) {
        return image;
    }
    image = RBLocalizedBundleImage(name, RBDeviceAssetTag());
    if (image != nil) {
        return image;
    }
    return RBBundleImage(name);
}

+ (void)clearImageCache {
    /** @ghidraAddress 0x1a1630 */
    [g_pThemedImageCache removeAllObjects];
}

#pragma mark - Cropping

- (UIImage *)clipImageWithRect:(CGRect)rect {
    /** @ghidraAddress 0x1a2fa4 */
    @autoreleasepool {
        // The binary keeps a weak reference to the receiver across the crop; it is never read, so
        // the crop reads the receiver directly.
        __weak UIImage *weakSelf = self;
        (void)weakSelf;
        CGImageRef sourceImage = self.CGImage;
        CGFloat scale = self.scale;
        if (scale == kRetinaScale2x || scale == kRetinaScale3x) {
            rect = CGRectMake(rect.origin.x * scale,
                              rect.origin.y * scale,
                              rect.size.width * scale,
                              rect.size.height * scale);
        }
        CGImageRef cropped = CGImageCreateWithImageInRect(sourceImage, rect);
        UIImage *result = [UIImage imageWithCGImage:cropped
                                              scale:self.scale
                                        orientation:self.imageOrientation];
        CGImageRelease(cropped);
        return result;
    }
}

#pragma mark - Reflection

- (UIImage *)reflectedImageWithHeight:(CGFloat)height {
    /** @ghidraAddress 0x1a2c0c */
    if (self == nil || height == 0.0) {
        return nil;
    }

    CGFloat width = self.size.width;
    CGFloat drawHeight = self.size.height;
    CGFloat reflectionHeight = height;
    if ([self respondsToSelector:@selector(scale)] && self.scale != 1.0) {
        CGFloat scale = self.scale;
        width = self.size.width * scale;
        drawHeight = self.size.height * scale;
        reflectionHeight = (CGFloat)(unsigned long)(scale * height);
    }

    CGColorSpaceRef rgbSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef imageContext = CGBitmapContextCreate(
        NULL, (size_t)width, (size_t)reflectionHeight, kBitsPerComponent, 0, rgbSpace,
        kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(rgbSpace);
    if (imageContext == NULL) {
        return nil;
    }

    CGContextTranslateCTM(imageContext, 0, reflectionHeight);
    CGContextScaleCTM(imageContext, 1.0, -1.0);
    CGContextDrawImage(imageContext, CGRectMake(0, 0, width, drawHeight), self.CGImage);
    CGImageRef drawnImage = CGBitmapContextCreateImage(imageContext);
    CGContextRelease(imageContext);

    CGImageRef gradientMask = NULL;
    CGColorSpaceRef graySpace = CGColorSpaceCreateDeviceGray();
    CGContextRef gradientContext = CGBitmapContextCreate(
        NULL, 1, (size_t)reflectionHeight, kBitsPerComponent, 0, graySpace, kCGImageAlphaNone);
    if (gradientContext != NULL) {
        CGFloat components[] = {0.0, 0.0, 1.0, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(
            graySpace, components, NULL, kReflectionGradientStopCount);
        CGContextDrawLinearGradient(gradientContext, gradient, CGPointZero,
                                    CGPointMake(0, reflectionHeight),
                                    (kCGGradientDrawsBeforeStartLocation |
                                     kCGGradientDrawsAfterEndLocation));
        CGGradientRelease(gradient);
        gradientMask = CGBitmapContextCreateImage(gradientContext);
        CGContextRelease(gradientContext);
    }
    CGColorSpaceRelease(graySpace);

    CGImageRef maskedImage = CGImageCreateWithMask(drawnImage, gradientMask);
    CGImageRelease(drawnImage);
    CGImageRelease(gradientMask);

    UIImage *result;
    if (![self respondsToSelector:@selector(scale)] || self.scale == 1.0) {
        result = [UIImage imageWithCGImage:maskedImage];
    } else {
        result = [UIImage imageWithCGImage:maskedImage
                                    scale:self.scale
                              orientation:UIImageOrientationUp];
    }
    CGImageRelease(maskedImage);
    return result;
}

#pragma mark - Colour-matrix tint

- (UIImage *)colorMatrixFilterWithColor:(UIColor *)color {
    /** @ghidraAddress 0x1a31a0 */
    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    CGFloat alpha = 0.0;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        [color getWhite:&red alpha:&alpha];
        blue = red;
        green = red;
    }
    return [self colorMatrixFilterWithRed:red green:green blue:blue alpha:alpha];
}

- (UIImage *)colorMatrixFilterWithRed:(CGFloat)red
                                green:(CGFloat)green
                                 blue:(CGFloat)blue
                                alpha:(CGFloat)alpha {
    /** @ghidraAddress 0x1a3268 */
    CIImage *sourceImage = [[CIImage alloc] initWithImage:self];
    CIFilter *filter = [CIFilter filterWithName:@"CIColorMatrix"
                                  keysAndValues:kCIInputImageKey, sourceImage, nil];
    [filter setValue:[CIVector vectorWithX:red Y:0 Z:0 W:0] forKey:@"inputRVector"];
    [filter setValue:[CIVector vectorWithX:0 Y:green Z:0 W:0] forKey:@"inputGVector"];
    [filter setValue:[CIVector vectorWithX:0 Y:0 Z:blue W:0] forKey:@"inputBVector"];
    [filter setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:alpha] forKey:@"inputAVector"];

    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *outputImage = filter.outputImage;
    CGImageRef renderedImage =
        [context createCGImage:outputImage fromRect:filter.outputImage.extent];
    UIImage *result = [UIImage imageWithCGImage:renderedImage
                                          scale:self.scale
                                    orientation:UIImageOrientationUp];
    CGImageRelease(renderedImage);
    return result;
}

@end
