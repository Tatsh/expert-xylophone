//
//  MusicDataFromDoc.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class MusicDataFromDoc). Verified
//  against the arm64 disassembly (the variadic stringWithFormat: path builder and the image
//  drawInRect:/graphics-context maths are dropped or garbled by the decompiler).
//

#import "MusicDataFromDoc.h"

#import <UIKit/UIKit.h>

// The Documents-directory path builder format: directory, a separator, then the file name.
static NSString *const kDocumentPathFormat = @"%@/%@";

// File-name suffixes stripped before a title or sheet name is rendered, and their common length.
static NSString *const kAudioFileSuffix = @".m4a";
static NSString *const kSheetFileSuffix = @".ply";
static const NSUInteger kFileSuffixLength = 4;

// The fixed catalogue metadata reported for a Documents-backed tune.
static const int kDocumentMusicID = 1;
static const int kDocumentDifficulty = 0;
static const int kDocumentBPM = 100;

// Image scale factors passed to the graphics context.
static const CGFloat kImageScaleSingle = 1.0f;
static const CGFloat kImageScaleDouble = 2.0f;

// Greyscale fill luminance values: white text and black text.
static const CGFloat kLuminanceWhite = 1.0f;
static const CGFloat kLuminanceBlack = 0.0f;

// The opaque alpha component used for every rendered fill.
static const CGFloat kFillAlpha = 1.0f;

// The point size of the font used to render the title into artwork.
static const CGFloat kArtworkFontSize = 20.0f;
// The edge length in points of the square artwork canvas.
// @ghidraAddress 0x2ee970 (g_dArtworkCanvasSize)
static const CGFloat kArtworkCanvasSize = 180.0f;

// The point size of the font used to render the title strip.
static const CGFloat kMusicNameFontSize = 18.0f;
// The height in points of the title strip canvas.
static const CGFloat kMusicNameImageHeight = 18.0f;

// The point size of the font used to render the artist strip.
static const CGFloat kArtistNameFontSize = 13.0f;
// The height in points of the artist strip canvas.
static const CGFloat kArtistNameImageHeight = 14.0f;

// The maximum width in points of a name-strip canvas.
// @ghidraAddress 0x2fcfd8 (g_dNameImageMaxWidth)
static const CGFloat kNameImageMaxWidth = 280.0f;

// The factor that centres drawn text within its canvas.
static const CGFloat kCentreFactor = 0.5f;

@implementation MusicDataFromDoc

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x67238 */
    return [super init];
}

// The binary's -dealloc (0x67498) only chains to [super dealloc]; under ARC that chaining is
// automatic, so no override is reconstructed. The strong plyName ivar is released by the
// compiler-generated .cxx_destruct (0x67e70).

#pragma mark - Path resolution

+ (NSString *)getPathWithDocument:(NSString *)document {
    /** @ghidraAddress 0x6726c */
    NSArray *paths =
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    return [NSString stringWithFormat:kDocumentPathFormat, documentsDirectory, document];
}

+ (instancetype)dataWithPath:(NSString *)path PlyName:(NSString *)plyName {
    /** @ghidraAddress 0x6734c */
    MusicDataFromDoc *data = [[MusicDataFromDoc alloc] init];
    data.musicName = [[NSString alloc] initWithString:path];
    data.plyName = [[NSString alloc] initWithString:plyName];
    return data;
}

#pragma mark - Fixed metadata

- (int)MusicID {
    /** @ghidraAddress 0x674cc */
    return kDocumentMusicID;
}

- (int)difficultyBasic {
    /** @ghidraAddress 0x674d4 */
    return kDocumentDifficulty;
}

- (int)difficultyMedium {
    /** @ghidraAddress 0x674dc */
    return kDocumentDifficulty;
}

- (int)difficultyHard {
    /** @ghidraAddress 0x674e4 */
    return kDocumentDifficulty;
}

- (int)difficultySpecial {
    /** @ghidraAddress 0x674ec */
    return kDocumentDifficulty;
}

- (int)bpm_MIN {
    /** @ghidraAddress 0x674f4 */
    return kDocumentBPM;
}

- (int)bpm_MAX {
    /** @ghidraAddress 0x674fc */
    return kDocumentBPM;
}

- (NSString *)musicNameHira {
    /** @ghidraAddress 0x67504 */
    return nil;
}

- (NSString *)musicNameRoman {
    /** @ghidraAddress 0x6750c */
    return nil;
}

- (NSString *)artistName {
    /** @ghidraAddress 0x67514 */
    return nil;
}

- (NSString *)artistNameHira {
    /** @ghidraAddress 0x6751c */
    return nil;
}

- (NSString *)artistNameRoman {
    /** @ghidraAddress 0x67524 */
    return nil;
}

#pragma mark - Audio

- (NSData *)music {
    /** @ghidraAddress 0x6752c */
    NSString *path = [MusicDataFromDoc getPathWithDocument:self.musicName];
    return [NSData dataWithContentsOfFile:path];
}

- (NSData *)musicPre {
    /** @ghidraAddress 0x675e4 */
    return nil;
}

#pragma mark - Note sheets

- (NSData *)loadSheet {
    /** @ghidraAddress 0x675ec */
    NSString *path = [MusicDataFromDoc getPathWithDocument:self.plyName];
    return [NSData dataWithContentsOfFile:path];
}

- (NSData *)sheetBasic {
    /** @ghidraAddress 0x676a4 */
    return [self loadSheet];
}

- (NSData *)sheetBasicLight {
    /** @ghidraAddress 0x676b0 */
    return [self loadSheet];
}

- (NSData *)sheetMedium {
    /** @ghidraAddress 0x676bc */
    return [self loadSheet];
}

- (NSData *)sheetMediumLight {
    /** @ghidraAddress 0x676c8 */
    return [self loadSheet];
}

- (NSData *)sheetHard {
    /** @ghidraAddress 0x676d4 */
    return [self loadSheet];
}

- (NSData *)sheetHardLight {
    /** @ghidraAddress 0x676e0 */
    return [self loadSheet];
}

- (NSData *)sheetSpecial {
    /** @ghidraAddress 0x676ec */
    return [self loadSheet];
}

- (NSData *)sheetSpecialLight {
    /** @ghidraAddress 0x676f8 */
    return [self loadSheet];
}

#pragma mark - Artwork rendering

- (NSData *)artwork2xData {
    /** @ghidraAddress 0x67704 */
    return [self artworkDataWithScale:kImageScaleDouble Luminance:kLuminanceWhite];
}

- (NSData *)artworkData {
    /** @ghidraAddress 0x67718 */
    return [self artworkDataWithScale:kImageScaleSingle Luminance:kLuminanceWhite];
}

- (NSData *)artworkDataWithScale:(float)scale Luminance:(float)luminance {
    /** @ghidraAddress 0x6772c */
    NSString *title = self.musicName;
    if ([title hasSuffix:kAudioFileSuffix]) {
        title = [title substringToIndex:title.length - kFileSuffixLength];
    }
    UIFont *font = [UIFont systemFontOfSize:kArtworkFontSize];
    CGSize textSize = [title sizeWithFont:font];
    CGSize canvasSize = CGSizeMake(kArtworkCanvasSize, kArtworkCanvasSize);
    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(context, luminance, luminance, luminance, kFillAlpha);
    CGRect textRect = CGRectMake((kArtworkCanvasSize - textSize.width) * kCentreFactor,
                                 (kArtworkCanvasSize - textSize.height) * kCentreFactor,
                                 textSize.width,
                                 textSize.height);
    [title drawInRect:textRect
             withFont:font
        lineBreakMode:NSLineBreakByWordWrapping
            alignment:NSTextAlignmentCenter];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [[NSData alloc] initWithData:UIImagePNGRepresentation(image)];
}

#pragma mark - Title-name image rendering

- (NSData *)musicNameImageWhite2xData {
    /** @ghidraAddress 0x67944 */
    return [self musicNameImageDataWithScale:kImageScaleDouble Luminance:kLuminanceWhite];
}

- (NSData *)musicNameImageWhiteData {
    /** @ghidraAddress 0x67958 */
    return [self musicNameImageDataWithScale:kImageScaleSingle Luminance:kLuminanceWhite];
}

- (NSData *)musicNameImageBlack2xData {
    /** @ghidraAddress 0x6796c */
    return [self musicNameImageDataWithScale:kImageScaleDouble Luminance:kLuminanceBlack];
}

- (NSData *)musicNameImageBlackData {
    /** @ghidraAddress 0x67980 */
    return [self musicNameImageDataWithScale:kImageScaleSingle Luminance:kLuminanceBlack];
}

- (NSData *)musicNameImageDataWithScale:(float)scale Luminance:(float)luminance {
    /** @ghidraAddress 0x67994 */
    NSString *title = self.plyName;
    if ([title hasSuffix:kAudioFileSuffix]) {
        title = [title substringToIndex:title.length - kFileSuffixLength];
    }
    if ([title hasSuffix:kSheetFileSuffix]) {
        title = [title substringToIndex:title.length - kFileSuffixLength];
    }
    UIFont *font = [UIFont systemFontOfSize:kMusicNameFontSize];
    CGSize textSize = [title sizeWithFont:font];
    CGFloat canvasWidth = MIN(textSize.width, kNameImageMaxWidth);
    UIGraphicsBeginImageContextWithOptions(
        CGSizeMake(canvasWidth, kMusicNameImageHeight), NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(context, luminance, luminance, luminance, kFillAlpha);
    CGRect textRect = CGRectMake((canvasWidth - textSize.width) * kCentreFactor,
                                 (kMusicNameImageHeight - textSize.height) * kCentreFactor,
                                 textSize.width,
                                 textSize.height);
    [title drawInRect:textRect withFont:font];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [[NSData alloc] initWithData:UIImagePNGRepresentation(image)];
}

#pragma mark - Artist-name image rendering

- (NSData *)artistNameImageWhite2xData {
    /** @ghidraAddress 0x67c0c */
    return [self artistNameImageDataWithScale:kImageScaleDouble Luminance:kLuminanceWhite];
}

- (NSData *)artistNameImageWhiteData {
    /** @ghidraAddress 0x67c20 */
    return [self artistNameImageDataWithScale:kImageScaleSingle Luminance:kLuminanceWhite];
}

- (NSData *)artistNameImageBlack2xData {
    /** @ghidraAddress 0x67c34 */
    return [self artistNameImageDataWithScale:kImageScaleDouble Luminance:kLuminanceBlack];
}

- (NSData *)artistNameImageBlackData {
    /** @ghidraAddress 0x67c48 */
    return [self artistNameImageDataWithScale:kImageScaleSingle Luminance:kLuminanceBlack];
}

- (NSData *)artistNameImageDataWithScale:(float)scale Luminance:(float)luminance {
    /** @ghidraAddress 0x67c5c */
    NSString *artist = self.plyName;
    UIFont *font = [UIFont systemFontOfSize:kArtistNameFontSize];
    CGSize textSize = [artist sizeWithFont:font];
    CGFloat canvasWidth = MIN(textSize.width, kNameImageMaxWidth);
    UIGraphicsBeginImageContextWithOptions(
        CGSizeMake(canvasWidth, kArtistNameImageHeight), NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(context, luminance, luminance, luminance, kFillAlpha);
    CGRect textRect = CGRectMake((canvasWidth - textSize.width) * kCentreFactor,
                                 (kArtistNameImageHeight - textSize.height) * kCentreFactor,
                                 textSize.width,
                                 textSize.height);
    [artist drawInRect:textRect withFont:font];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [[NSData alloc] initWithData:UIImagePNGRepresentation(image)];
}

@end
