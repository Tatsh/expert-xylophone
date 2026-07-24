//
//  MusicData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class MusicData). Verified against the
//  arm64 disassembly: the decompiler drops the variadic message arguments, the screen-scale
//  comparisons flow through VFP registers it renders as extraout_d0, and the CFString asset-name
//  literals (whose method names invert the White/Black asset suffixes) were read straight from the
//  __cfstring references.
//

#import "MusicData.h"

#import <UIKit/UIKit.h>

// Collaborator classes reached from the asset and load helpers. Their headers are not yet
// reconstructed in this tree (the same speculative imports ScoreData.m and AppDelegate.mm already
// use); they resolve once those classes land.
#import "BFCodec.h"
#import "MusicDataExtend.h"
#import "RBExtendNoteManager.h"
#import "RBMusicManager.h"
#import "StringConvert.h"
#import "UnZipArchive.h"
#import "deviceenvironment.h"
#import "enginecrypto.h"
#import "engineglobals.h"

// Archive member names. The White image accessors read the @c _b (black-background) members and
// the Black image accessors read the @c _w (white-background) members; the binary names its
// accessors the opposite way round from its assets, and that inversion is preserved here.
static NSString *const kEntryMusic = @"bgm";
static NSString *const kEntryMusicBasic = @"bgm_b";
static NSString *const kEntryMusicMedium = @"bgm_m";
static NSString *const kEntryMusicHard = @"bgm_h";
static NSString *const kEntryMusicPre = @"pre";
static NSString *const kEntrySheetBasic = @"note_bas";
static NSString *const kEntrySheetBasicLight = @"note_bas2";
static NSString *const kEntrySheetMedium = @"note_med";
static NSString *const kEntrySheetMediumLight = @"note_med2";
static NSString *const kEntrySheetHard = @"note_har";
static NSString *const kEntrySheetHardLight = @"note_har2";
static NSString *const kEntryArtwork = @"artwork";
static NSString *const kEntryArtworkBasic = @"artwork_b";
static NSString *const kEntryArtworkMedium = @"artwork_m";
static NSString *const kEntryArtworkHard = @"artwork_h";
static NSString *const kEntryTitleBlack = @"title_b";
static NSString *const kEntryTitleBlackBasic = @"title_b_b";
static NSString *const kEntryTitleBlackMedium = @"title_b_m";
static NSString *const kEntryTitleBlackHard = @"title_b_h";
static NSString *const kEntryArtistBlack = @"artist_b";
static NSString *const kEntryArtistBlackBasic = @"artist_b_b";
static NSString *const kEntryArtistBlackMedium = @"artist_b_m";
static NSString *const kEntryArtistBlackHard = @"artist_b_h";
static NSString *const kEntryTitleWhite = @"title_w";
static NSString *const kEntryTitleWhiteBasic = @"title_w_b";
static NSString *const kEntryTitleWhiteMedium = @"title_w_m";
static NSString *const kEntryTitleWhiteHard = @"title_w_h";
static NSString *const kEntryArtistWhite = @"artist_w";
static NSString *const kEntryArtistWhiteBasic = @"artist_w_b";
static NSString *const kEntryArtistWhiteMedium = @"artist_w_m";
static NSString *const kEntryArtistWhiteHard = @"artist_w_h";
static NSString *const kEntryArtwork2x = @"artwork2x";
static NSString *const kEntryArtwork2xBasic = @"artwork2x_b";
static NSString *const kEntryArtwork2xMedium = @"artwork2x_m";
static NSString *const kEntryArtwork2xHard = @"artwork2x_h";
static NSString *const kEntryTitleBlack2x = @"title_b2x";
static NSString *const kEntryTitleBlack2xBasic = @"title_b2x_b";
static NSString *const kEntryTitleBlack2xMedium = @"title_b2x_m";
static NSString *const kEntryTitleBlack2xHard = @"title_b2x_h";
static NSString *const kEntryArtistBlack2x = @"artist_b2x";
static NSString *const kEntryArtistBlack2xBasic = @"artist_b2x_b";
static NSString *const kEntryArtistBlack2xMedium = @"artist_b2x_m";
static NSString *const kEntryArtistBlack2xHard = @"artist_b2x_h";
static NSString *const kEntryTitleWhite2x = @"title_w2x";
static NSString *const kEntryTitleWhite2xBasic = @"title_w2x_b";
static NSString *const kEntryTitleWhite2xMedium = @"title_w2x_m";
static NSString *const kEntryTitleWhite2xHard = @"title_w2x_h";
static NSString *const kEntryArtistWhite2x = @"artist_w2x";
static NSString *const kEntryArtistWhite2xBasic = @"artist_w2x_b";
static NSString *const kEntryArtistWhite2xMedium = @"artist_w2x_m";
static NSString *const kEntryArtistWhite2xHard = @"artist_w2x_h";

// Metadata keys read from the archive's info dictionary.
static NSString *const kInfoDictionaryEntry = @"info";
static NSString *const kInfoKeyID = @"ID";
static NSString *const kInfoKeyMusicName = @"MusicName";
static NSString *const kInfoKeyMusicNameHira = @"MusicNameHira";
static NSString *const kInfoKeyMusicNameRoman = @"MusicNameRoman";
static NSString *const kInfoKeyArtistName = @"ArtistName";
static NSString *const kInfoKeyArtistNameHira = @"ArtistNameHira";
static NSString *const kInfoKeyArtistNameRoman = @"ArtistNameRoman";
static NSString *const kInfoKeyBasic = @"Basic";
static NSString *const kInfoKeyMedium = @"Medium";
static NSString *const kInfoKeyHard = @"Hard";
static NSString *const kInfoKeyBpmMin = @"BpmMin";
static NSString *const kInfoKeyBpmMax = @"BpmMax";
static NSString *const kInfoKeyOptions = @"Options";

// The empty initial used when a tune has no sortable reading.
static NSString *const kEmptyInitial = @"";

// The number of decode types with a registered decryption key; a larger index selects no key.
static const int kDecodeTypeCount = 2;

// The inclusive one-based level range accepted from the archive metadata.
static const int kLevelMinimum = 1;
static const int kLevelMaximum = 15;

// The blowfish key length used for the derived MD5 key.
static const int kBlowfishKeyLength = 16;

// The brown tint applied to the brown name-strip artwork.
// @ghidraAddress 0x2fcf38 (g_dBrownTintRed)
// @ghidraAddress 0x2fcf40 (g_dBrownTintGreen)
// @ghidraAddress 0x2fcf48 (g_dBrownTintBlue)
static const CGFloat kBrownTintRed = 78.0 / 255.0;
static const CGFloat kBrownTintGreen = 69.0 / 255.0;
static const CGFloat kBrownTintBlue = 58.0 / 255.0;

// The greyscale components of the black tint applied to the black name-strip artwork.
static const CGFloat kBlackTintComponent = 0.0;

// The opaque alpha component used for every tint colour.
static const CGFloat kTintAlpha = 1.0;

// The scale factor forced onto a double-resolution image.
static const CGFloat kDoubleScale = 2.0;

// The screen scale above which a double-resolution asset is preferred.
static const CGFloat kRetinaScaleThreshold = 1.0;

// Registry caches mapping a tune identifier to an overriding sort name.
// @ghidraAddress 0x3dc2d8 (g_pMusicSortNameOverrides)
// @ghidraAddress 0x3dc2e0 (g_pArtistSortNameOverrides)
static NSMutableDictionary *g_pMusicSortNameOverrides;
static NSMutableDictionary *g_pArtistSortNameOverrides;

// The katakana rows, in the reading order used to pick a title's index bucket.
static NSArray *g_yomiGroups;
// The hiragana initial labelling each katakana row.
static NSArray *g_yomiLabels;

// Decodes @p data into an image, preferring nil over an empty image.
static UIImage *ImageFromData(NSData *data) {
    if (data == nil) {
        return nil;
    }
    return [UIImage imageWithData:data];
}

// Decodes @p data and re-wraps it as a double-resolution image.
static UIImage *DoubleResolutionImageFromData(NSData *data) {
    UIImage *image = ImageFromData(data);
    if (image == nil) {
        return nil;
    }
    return [UIImage imageWithCGImage:image.CGImage
                               scale:kDoubleScale
                         orientation:UIImageOrientationUp];
}

// The black tint colour used by the black name-strip images.
static UIColor *BlackTintColor(void) {
    return [UIColor colorWithRed:kBlackTintComponent
                           green:kBlackTintComponent
                            blue:kBlackTintComponent
                           alpha:kTintAlpha];
}

// The brown tint colour used by the brown name-strip images.
static UIColor *BrownTintColor(void) {
    return [UIColor colorWithRed:kBrownTintRed
                           green:kBrownTintGreen
                            blue:kBrownTintBlue
                           alpha:kTintAlpha];
}

// Orders two integer keys, ranking the larger key later, matching the binary's -1/0/1 result.
static NSComparisonResult OrderByValue(int left, int right) {
    if (right > left) {
        return NSOrderedAscending;
    }
    return (right < left) ? NSOrderedDescending : NSOrderedSame;
}

// Orders two lengths, ranking the longer length later, matching the binary's -1/0/1 result.
static NSComparisonResult OrderByLength(NSUInteger left, NSUInteger right) {
    if (right > left) {
        return NSOrderedAscending;
    }
    return (right < left) ? NSOrderedDescending : NSOrderedSame;
}

@interface MusicData ()
// Returns the katakana-row bucket of @p text's first character, the last row when no row matches,
// or -1 when @p text is empty.
// @ghidraAddress 0x5ea48
+ (int)GetYomiIndex:(NSString *)text;
// Returns the hiragana initial for a katakana-row bucket, or the empty string when out of range.
// @ghidraAddress 0x5eb44
+ (NSString *)GetYomiString:(int)index;
@end

@implementation MusicData

+ (void)initialize {
    if (self != [MusicData class]) {
        return;
    }
    /** @ghidraAddress 0x66a2c (InitializeGlobalDictionaries) */
    g_pMusicSortNameOverrides = [[NSMutableDictionary alloc] init];
    g_pArtistSortNameOverrides = [[NSMutableDictionary alloc] init];
    g_yomiGroups = @[
        @"ァアィイゥウェエォオ",
        @"カガキギクグケゲコゴ",
        @"サザシジスズセゼソゾ",
        @"タダチヂッツヅテデトド",
        @"ナニヌネノ",
        @"ハバパヒビピフブプヘベペホボポ",
        @"マミムメモ",
        @"ャヤュユョヨ",
        @"ラリルレロ",
        @"ヮワヰヱヲンヴヵヶ"
    ];
    g_yomiLabels = @[ @"あ", @"か", @"さ", @"た", @"な", @"は", @"ま", @"や", @"ら", @"わ" ];
}

- (void)dealloc {
    /** @ghidraAddress 0x60044 */
    self.artworkCache = nil;
}

#pragma mark - Yomi index lookup

+ (int)GetYomiIndex:(NSString *)text {
    /** @ghidraAddress 0x5ea48 */
    if (text.length == 0) {
        return -1;
    }
    unichar first = [text characterAtIndex:0];
    NSUInteger groupCount = g_yomiGroups.count;
    for (NSUInteger group = 0; group < groupCount; ++group) {
        NSString *members = g_yomiGroups[group];
        NSUInteger memberCount = members.length;
        for (NSUInteger index = 0; index < memberCount; ++index) {
            if ([members characterAtIndex:index] == first) {
                return (int)group;
            }
        }
    }
    return (int)(groupCount - 1);
}

+ (NSString *)GetYomiString:(int)index {
    /** @ghidraAddress 0x5eb44 */
    if (index >= (int)g_yomiLabels.count) {
        return kEmptyInitial;
    }
    return g_yomiLabels[index];
}

#pragma mark - Loading

+ (NSMutableData *)decodeBF:(NSMutableData *)data Key:(const char *)key KeyLength:(int)keyLength {
    /** @ghidraAddress 0x5eb78 */
    unsigned char digest[kBlowfishKeyLength];
    char *derived = (char *)malloc((size_t)keyLength);
    for (int index = 0; index < keyLength; ++index) {
        derived[index] = (char)index + key[index];
    }
    ComputeMd5Digest(derived, (CC_LONG)keyLength, digest);
    free(derived);
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:digest keyLength:kBlowfishKeyLength];
    if (![codec decipher:data]) {
        return nil;
    }
    return data;
}

+ (NSMutableData *)getZipData:(NSString *)entryName
                         Path:(NSString *)zipPath
                   DecodeType:(int)decodeType {
    /** @ghidraAddress 0x5ecd4 */
    if (decodeType >= kDecodeTypeCount) {
        return nil;
    }
    UnZipArchive *archive = [[UnZipArchive alloc] init];
    if (![archive openFile:zipPath]) {
        return nil;
    }
    NSMutableData *data = [archive getData:entryName];
    if (data == nil) {
        [archive closeFile];
        return nil;
    }
    NSMutableData *decoded = [MusicData decodeBF:data
                                             Key:kChartDecodeKeys[decodeType]
                                       KeyLength:kChartDecodeKeyLengths[decodeType]];
    [archive closeFile];
    return decoded;
}

+ (instancetype)dataWithPath:(NSString *)path ID:(int)musicID {
    /** @ghidraAddress 0x5ee64 */
    NSDictionary *info = nil;
    int decodeType = 0;
    while (YES) {
        NSMutableData *archiveData = [MusicData getZipData:kInfoDictionaryEntry
                                                      Path:path
                                                DecodeType:decodeType];
        if (archiveData == nil) {
            return nil;
        }
        info = [archiveData dictionary];
        if (info != nil) {
            break;
        }
        ++decodeType;
        if (decodeType > kDecodeTypeCount - 1) {
            return nil;
        }
    }

    NSNumber *idNumber = info[kInfoKeyID];
    if (idNumber == nil || idNumber.intValue != musicID) {
        return nil;
    }
    NSString *musicName = info[kInfoKeyMusicName];
    NSString *musicNameHira = info[kInfoKeyMusicNameHira];
    NSString *musicNameRoman = info[kInfoKeyMusicNameRoman];
    NSString *artistName = info[kInfoKeyArtistName];
    NSString *artistNameHira = info[kInfoKeyArtistNameHira];
    NSString *artistNameRoman = info[kInfoKeyArtistNameRoman];
    NSNumber *basicNumber = info[kInfoKeyBasic];
    NSNumber *mediumNumber = info[kInfoKeyMedium];
    NSNumber *hardNumber = info[kInfoKeyHard];
    NSNumber *bpmMinNumber = info[kInfoKeyBpmMin];
    NSNumber *bpmMaxNumber = info[kInfoKeyBpmMax];

    int difficultyBasic = basicNumber.intValue - kLevelMinimum;
    if (basicNumber.intValue < kLevelMinimum || difficultyBasic > kLevelMaximum - kLevelMinimum) {
        return nil;
    }
    int difficultyMedium = mediumNumber.intValue - kLevelMinimum;
    if (mediumNumber.intValue < kLevelMinimum || difficultyMedium > kLevelMaximum - kLevelMinimum) {
        return nil;
    }
    int difficultyHard = hardNumber.intValue - kLevelMinimum;
    if (hardNumber.intValue < kLevelMinimum || difficultyHard > kLevelMaximum - kLevelMinimum) {
        return nil;
    }

    MusicData *data = [[MusicData alloc] init];
    data.MusicID = idNumber.intValue;
    data.musicName = [[NSString alloc] initWithString:musicName];
    data.musicNameHira = [[NSString alloc] initWithString:musicNameHira];
    data.musicNameRoman = [[NSString alloc] initWithString:musicNameRoman];
    data.artistName = [[NSString alloc] initWithString:artistName];
    data.artistNameHira = [[NSString alloc] initWithString:artistNameHira];
    data.artistNameRoman = [[NSString alloc] initWithString:artistNameRoman];
    data.difficultyBasic = difficultyBasic;
    data.difficultyMedium = difficultyMedium;
    data.difficultyHard = difficultyHard;
    data.bpm_MIN = bpmMinNumber.intValue;
    data.bpm_MAX = bpmMaxNumber.intValue;
    data.filePath = [[NSString alloc] initWithString:path];
    data.decodeType = decodeType;

    NSNumber *musicKey = [NSNumber numberWithInt:data.MusicID];
    NSString *musicOverride = g_pMusicSortNameOverrides[musicKey];
    if (musicOverride == nil) {
        data.musicSortName =
            [[NSString alloc] initWithString:[StringConvert convertYomigana:data.musicNameHira]];
        g_pMusicSortNameOverrides[[NSNumber numberWithInt:data.MusicID]] = data.musicSortName;
    } else {
        data.musicSortName = g_pMusicSortNameOverrides[[NSNumber numberWithInt:data.MusicID]];
    }
    NSString *artistOverride = g_pArtistSortNameOverrides[[NSNumber numberWithInt:data.MusicID]];
    if (artistOverride == nil) {
        data.artistSortName =
            [[NSString alloc] initWithString:[StringConvert convertYomigana:data.artistNameHira]];
        g_pArtistSortNameOverrides[[NSNumber numberWithInt:data.MusicID]] = data.artistSortName;
    } else {
        data.artistSortName = g_pArtistSortNameOverrides[[NSNumber numberWithInt:data.MusicID]];
    }
    // The binary compares the artist reading against its sort name here but discards the result.
    (void)[data.artistNameHira isEqualToString:data.artistSortName];

    if (data.musicSortName.length == 0) {
        data.musicNameInitial = [[NSString alloc] initWithString:kEmptyInitial];
    } else {
        int bucket = [MusicData GetYomiIndex:[data.musicSortName substringToIndex:1]];
        data.musicNameInitial = [[NSString alloc] initWithString:[MusicData GetYomiString:bucket]];
    }
    if (data.artistSortName.length == 0) {
        data.artistNameInitial = [[NSString alloc] initWithString:kEmptyInitial];
    } else {
        int bucket = [MusicData GetYomiIndex:[data.artistSortName substringToIndex:1]];
        data.artistNameInitial = [[NSString alloc] initWithString:[MusicData GetYomiString:bucket]];
    }

    NSArray<MusicDataExtend *> *extendData =
        [[RBExtendNoteManager getInstance] getExtendNoteDataWithMusicID:musicID];
    if (extendData != nil && extendData.count != 0) {
        MusicDataExtend *extend = extendData[0];
        data.spData = extend;
        data.difficultySpecial = extend.difficulty - kLevelMinimum;
        NSString *extendPath = [RBMusicManager getPathFromPurchesed:extend.ExtMusicID];
        data.ExtMusicData = [MusicData dataWithPath:extendPath ID:extend.ExtMusicID];
    }

    NSDictionary *options = info[kInfoKeyOptions];
    if (options != nil) {
        data.optionalDataDict = info[kInfoKeyOptions];
    }
    return data;
}

#pragma mark - Archive members

- (NSMutableData *)getZipData:(NSString *)entryName {
    /** @ghidraAddress 0x600cc */
    return [MusicData getZipData:entryName Path:self.filePath DecodeType:self.decodeType];
}

- (NSMutableData *)getOptionalZipData:(NSString *)entryName {
    /** @ghidraAddress 0x60190 */
    return [self getOptionalZipData:entryName withDefaultName:nil];
}

- (NSMutableData *)getOptionalZipData:(NSString *)entryName
                      withDefaultName:(NSString *)defaultName {
    /** @ghidraAddress 0x601b8 */
    if (self.optionalDataDict[entryName] != nil) {
        NSMutableData *data = [self getZipData:entryName];
        if (data != nil) {
            return data;
        }
    }
    if (defaultName != nil) {
        NSMutableData *data = [self getZipData:defaultName];
        if (data != nil) {
            return data;
        }
    }
    return nil;
}

#pragma mark - Audio

- (NSMutableData *)music {
    /** @ghidraAddress 0x602d8 */
    return [self getZipData:kEntryMusic];
}

- (NSMutableData *)musicBasic {
    /** @ghidraAddress 0x602ec */
    return [self getOptionalZipData:kEntryMusicBasic withDefaultName:kEntryMusic];
}

- (NSMutableData *)musicMedium {
    /** @ghidraAddress 0x60308 */
    return [self getOptionalZipData:kEntryMusicMedium withDefaultName:kEntryMusic];
}

- (NSMutableData *)musicHard {
    /** @ghidraAddress 0x60324 */
    return [self getOptionalZipData:kEntryMusicHard withDefaultName:kEntryMusic];
}

- (NSMutableData *)musicPre {
    /** @ghidraAddress 0x60340 */
    return [self getZipData:kEntryMusicPre];
}

#pragma mark - Note sheets

- (NSMutableData *)sheetBasic {
    /** @ghidraAddress 0x60354 */
    return [self getZipData:kEntrySheetBasic];
}

- (NSMutableData *)sheetBasicLight {
    /** @ghidraAddress 0x60368 */
    return [self getOptionalZipData:kEntrySheetBasicLight withDefaultName:kEntrySheetBasic];
}

- (NSMutableData *)sheetMedium {
    /** @ghidraAddress 0x60384 */
    return [self getZipData:kEntrySheetMedium];
}

- (NSMutableData *)sheetMediumLight {
    /** @ghidraAddress 0x60398 */
    return [self getOptionalZipData:kEntrySheetMediumLight withDefaultName:kEntrySheetMedium];
}

- (NSMutableData *)sheetHard {
    /** @ghidraAddress 0x603b4 */
    return [self getZipData:kEntrySheetHard];
}

- (NSMutableData *)sheetHardLight {
    /** @ghidraAddress 0x603c8 */
    return [self getOptionalZipData:kEntrySheetHardLight withDefaultName:kEntrySheetHard];
}

- (NSMutableData *)sheetSpecial {
    /** @ghidraAddress 0x603e4 */
    if (self.spData == nil) {
        return nil;
    }
    return [self.spData sheetSpecial];
}

- (NSMutableData *)sheetSpecialLight {
    /** @ghidraAddress 0x60484 */
    if (self.spData == nil) {
        return nil;
    }
    return [self.spData sheetSpecialLight];
}

#pragma mark - Artwork member data

- (NSMutableData *)artworkData {
    /** @ghidraAddress 0x60524 */
    return [self getZipData:kEntryArtwork];
}

- (NSMutableData *)artworkDataBasic {
    /** @ghidraAddress 0x60538 */
    return [self getOptionalZipData:kEntryArtworkBasic];
}

- (NSMutableData *)artworkDataMedium {
    /** @ghidraAddress 0x6054c */
    return [self getOptionalZipData:kEntryArtworkMedium];
}

- (NSMutableData *)artworkDataHard {
    /** @ghidraAddress 0x60560 */
    return [self getOptionalZipData:kEntryArtworkHard];
}

#pragma mark - White title-strip member data

- (NSMutableData *)musicNameImageWhiteData {
    /** @ghidraAddress 0x60574 */
    return [self getZipData:kEntryTitleBlack];
}

- (NSMutableData *)musicNameImageWhiteDataBasic {
    /** @ghidraAddress 0x60588 */
    return [self getOptionalZipData:kEntryTitleBlackBasic];
}

- (NSMutableData *)musicNameImageWhiteDataMedium {
    /** @ghidraAddress 0x6059c */
    return [self getOptionalZipData:kEntryTitleBlackMedium];
}

- (NSMutableData *)musicNameImageWhiteDataHard {
    /** @ghidraAddress 0x605b0 */
    return [self getOptionalZipData:kEntryTitleBlackHard];
}

- (NSMutableData *)artistNameImageWhiteData {
    /** @ghidraAddress 0x605c4 */
    return [self getZipData:kEntryArtistBlack];
}

- (NSMutableData *)artistNameImageWhiteDataBasic {
    /** @ghidraAddress 0x605d8 */
    return [self getOptionalZipData:kEntryArtistBlackBasic];
}

- (NSMutableData *)artistNameImageWhiteDataMedium {
    /** @ghidraAddress 0x605ec */
    return [self getOptionalZipData:kEntryArtistBlackMedium];
}

- (NSMutableData *)artistNameImageWhiteDataHard {
    /** @ghidraAddress 0x60600 */
    return [self getOptionalZipData:kEntryArtistBlackHard];
}

#pragma mark - Black title-strip member data

- (NSMutableData *)musicNameImageBlackData {
    /** @ghidraAddress 0x60614 */
    return [self getZipData:kEntryTitleWhite];
}

- (NSMutableData *)musicNameImageBlackDataBasic {
    /** @ghidraAddress 0x60628 */
    return [self getOptionalZipData:kEntryTitleWhiteBasic];
}

- (NSMutableData *)musicNameImageBlackDataMedium {
    /** @ghidraAddress 0x6063c */
    return [self getOptionalZipData:kEntryTitleWhiteMedium];
}

- (NSMutableData *)musicNameImageBlackDataHard {
    /** @ghidraAddress 0x60650 */
    return [self getOptionalZipData:kEntryTitleWhiteHard];
}

- (NSMutableData *)artistNameImageBlackData {
    /** @ghidraAddress 0x60664 */
    return [self getZipData:kEntryArtistWhite];
}

- (NSMutableData *)artistNameImageBlackDataBasic {
    /** @ghidraAddress 0x60678 */
    return [self getOptionalZipData:kEntryArtistWhiteBasic];
}

- (NSMutableData *)artistNameImageBlackDataMedium {
    /** @ghidraAddress 0x6068c */
    return [self getOptionalZipData:kEntryArtistWhiteMedium];
}

- (NSMutableData *)artistNameImageBlackDataHard {
    /** @ghidraAddress 0x606a0 */
    return [self getOptionalZipData:kEntryArtistWhiteHard];
}

#pragma mark - Double-resolution artwork member data

- (NSMutableData *)artwork2xData {
    /** @ghidraAddress 0x606b4 */
    return [self getZipData:kEntryArtwork2x];
}

- (NSMutableData *)artwork2xDataBasic {
    /** @ghidraAddress 0x606c8 */
    return [self getOptionalZipData:kEntryArtwork2xBasic];
}

- (NSMutableData *)artwork2xDataMedium {
    /** @ghidraAddress 0x606dc */
    return [self getOptionalZipData:kEntryArtwork2xMedium];
}

- (NSMutableData *)artwork2xDataHard {
    /** @ghidraAddress 0x606f0 */
    return [self getOptionalZipData:kEntryArtwork2xHard];
}

#pragma mark - Double-resolution white title-strip member data

- (NSMutableData *)musicNameImageWhite2xData {
    /** @ghidraAddress 0x60704 */
    return [self getZipData:kEntryTitleBlack2x];
}

- (NSMutableData *)musicNameImageWhite2xDataBasic {
    /** @ghidraAddress 0x60718 */
    return [self getOptionalZipData:kEntryTitleBlack2xBasic];
}

- (NSMutableData *)musicNameImageWhite2xDataMedium {
    /** @ghidraAddress 0x6072c */
    return [self getOptionalZipData:kEntryTitleBlack2xMedium];
}

- (NSMutableData *)musicNameImageWhite2xDataHard {
    /** @ghidraAddress 0x60740 */
    return [self getOptionalZipData:kEntryTitleBlack2xHard];
}

- (NSMutableData *)artistNameImageWhite2xData {
    /** @ghidraAddress 0x60754 */
    return [self getZipData:kEntryArtistBlack2x];
}

- (NSMutableData *)artistNameImageWhite2xDataBasic {
    /** @ghidraAddress 0x60768 */
    return [self getOptionalZipData:kEntryArtistBlack2xBasic];
}

- (NSMutableData *)artistNameImageWhite2xDataMedium {
    /** @ghidraAddress 0x6077c */
    return [self getOptionalZipData:kEntryArtistBlack2xMedium];
}

- (NSMutableData *)artistNameImageWhite2xDataHard {
    /** @ghidraAddress 0x60790 */
    return [self getOptionalZipData:kEntryArtistBlack2xHard];
}

#pragma mark - Double-resolution black title-strip member data

- (NSMutableData *)musicNameImageBlack2xData {
    /** @ghidraAddress 0x607a4 */
    return [self getZipData:kEntryTitleWhite2x];
}

- (NSMutableData *)musicNameImageBlack2xDataBasic {
    /** @ghidraAddress 0x607b8 */
    return [self getOptionalZipData:kEntryTitleWhite2xBasic];
}

- (NSMutableData *)musicNameImageBlack2xDataMedium {
    /** @ghidraAddress 0x607cc */
    return [self getOptionalZipData:kEntryTitleWhite2xMedium];
}

- (NSMutableData *)musicNameImageBlack2xDataHard {
    /** @ghidraAddress 0x607e0 */
    return [self getOptionalZipData:kEntryTitleWhite2xHard];
}

- (NSMutableData *)artistNameImageBlack2xData {
    /** @ghidraAddress 0x607f4 */
    return [self getZipData:kEntryArtistWhite2x];
}

- (NSMutableData *)artistNameImageBlack2xDataBasic {
    /** @ghidraAddress 0x60808 */
    return [self getOptionalZipData:kEntryArtistWhite2xBasic];
}

- (NSMutableData *)artistNameImageBlack2xDataMedium {
    /** @ghidraAddress 0x6081c */
    return [self getOptionalZipData:kEntryArtistWhite2xMedium];
}

- (NSMutableData *)artistNameImageBlack2xDataHard {
    /** @ghidraAddress 0x60830 */
    return [self getOptionalZipData:kEntryArtistWhite2xHard];
}

#pragma mark - Brown title-strip member data

// Tints @p imageData's decoded image brown and PNG-encodes it.
static NSData *BrownImageData(MusicData *self, NSData *imageData) {
    if (imageData == nil) {
        return nil;
    }
    UIImage *image = [UIImage imageWithData:imageData];
    return UIImagePNGRepresentation([self setColor:image withColor:BrownTintColor()]);
}

- (NSData *)musicNameImageBrown2xData {
    /** @ghidraAddress 0x60844 */
    return BrownImageData(self, [self getZipData:kEntryTitleWhite2x]);
}

- (NSData *)musicNameImageBrown2xDataBasic {
    /** @ghidraAddress 0x60988 */
    return BrownImageData(self, [self musicNameImageWhite2xDataBasic]);
}

- (NSData *)musicNameImageBrown2xDataMedium {
    /** @ghidraAddress 0x60ad8 */
    return BrownImageData(self, [self musicNameImageWhite2xDataMedium]);
}

- (NSData *)musicNameImageBrown2xDataHard {
    /** @ghidraAddress 0x60c28 */
    return BrownImageData(self, [self musicNameImageWhite2xDataHard]);
}

- (NSData *)artistNameImageBrown2xData {
    /** @ghidraAddress 0x60d78 */
    return BrownImageData(self, [self getZipData:kEntryArtistWhite2x]);
}

- (NSData *)artistNameImageBrown2xDataBasic {
    /** @ghidraAddress 0x60ebc */
    return BrownImageData(self, [self artistNameImageWhite2xDataBasic]);
}

- (NSData *)artistNameImageBrown2xDataMedium {
    /** @ghidraAddress 0x6100c */
    return BrownImageData(self, [self artistNameImageWhite2xDataMedium]);
}

- (NSData *)artistNameImageBrown2xDataHard {
    /** @ghidraAddress 0x6115c */
    return BrownImageData(self, [self artistNameImageWhite2xDataHard]);
}

#pragma mark - Tinting

- (UIImage *)setColor:(UIImage *)image withColor:(UIColor *)color {
    /** @ghidraAddress 0x657e4 */
    CGSize size = image.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = CGRectMake(0, 0, size.width, size.height);
    [image drawInRect:bounds];
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    CGContextFillRect(context, bounds);
    UIImage *tinted = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return tinted;
}

#pragma mark - Artwork images (cached)

- (UIImage *)artwork {
    /** @ghidraAddress 0x612ac */
    if (self.artworkCache != nil) {
        return self.artworkCache;
    }
    UIImage *image = nil;
    if (!IsPad()) {
        image = ImageFromData([self artworkData]);
    } else {
        if ([UIScreen mainScreen].scale > kRetinaScaleThreshold) {
            image = [self artwork2x];
        }
        if (image == nil) {
            image = ImageFromData([self artworkData]);
        }
    }
    if (image == nil) {
        return nil;
    }
    self.artworkCache = image;
    return image;
}

- (UIImage *)artworkBasic {
    /** @ghidraAddress 0x61498 */
    if (self.artworkCacheBasic != nil) {
        return self.artworkCacheBasic;
    }
    UIImage *image = nil;
    if (!IsPad()) {
        image = ImageFromData([self artworkDataBasic]);
    } else {
        if ([UIScreen mainScreen].scale > kRetinaScaleThreshold) {
            image = [self artwork2xBasic];
        }
        if (image == nil) {
            image = ImageFromData([self artworkDataBasic]);
        }
    }
    if (image == nil) {
        return nil;
    }
    self.artworkCacheBasic = image;
    return image;
}

- (UIImage *)artworkMedium {
    /** @ghidraAddress 0x61684 */
    if (self.artworkCacheMedium != nil) {
        return self.artworkCacheMedium;
    }
    UIImage *image = nil;
    if (!IsPad()) {
        image = ImageFromData([self artworkDataMedium]);
    } else {
        if ([UIScreen mainScreen].scale > kRetinaScaleThreshold) {
            image = [self artwork2xMedium];
        }
        if (image == nil) {
            image = ImageFromData([self artworkDataMedium]);
        }
    }
    if (image == nil) {
        return nil;
    }
    self.artworkCacheMedium = image;
    return image;
}

- (UIImage *)artworkHard {
    /** @ghidraAddress 0x6188c */
    if (self.artworkCacheHard != nil) {
        return self.artworkCacheHard;
    }
    UIImage *image = nil;
    if (!IsPad()) {
        image = ImageFromData([self artworkDataHard]);
    } else {
        if ([UIScreen mainScreen].scale > kRetinaScaleThreshold) {
            image = [self artwork2xHard];
        }
        if (image == nil) {
            image = ImageFromData([self artworkDataHard]);
        }
    }
    if (image == nil) {
        return nil;
    }
    self.artworkCacheHard = image;
    return image;
}

#pragma mark - Name-strip images

// Fetches a white name-strip image, preferring the double-resolution variant on a retina screen.
static UIImage *WhitePreferringRetina2x(UIImage *retina2x, NSData *singleData) {
    if ([UIScreen mainScreen].scale > kRetinaScaleThreshold && retina2x != nil) {
        return retina2x;
    }
    return ImageFromData(singleData);
}

- (UIImage *)musicNameImageWhite {
    /** @ghidraAddress 0x61a94 */
    return WhitePreferringRetina2x([self musicNameImageWhite2x], [self musicNameImageWhiteData]);
}

- (UIImage *)musicNameImageWhiteBasic {
    /** @ghidraAddress 0x61ba4 */
    return WhitePreferringRetina2x([self musicNameImageWhite2xBasic],
                                   [self musicNameImageWhiteDataBasic]);
}

- (UIImage *)musicNameImageWhiteMedium {
    /** @ghidraAddress 0x61cb4 */
    return WhitePreferringRetina2x([self musicNameImageWhite2xMedium],
                                   [self musicNameImageWhiteDataMedium]);
}

- (UIImage *)musicNameImageWhiteHard {
    /** @ghidraAddress 0x61dc4 */
    return WhitePreferringRetina2x([self musicNameImageWhite2xHard],
                                   [self musicNameImageWhiteDataHard]);
}

- (UIImage *)artistNameImageWhite {
    /** @ghidraAddress 0x61ed4 */
    return WhitePreferringRetina2x([self artistNameImageWhite2x], [self artistNameImageWhiteData]);
}

- (UIImage *)artistNameImageWhiteBasic {
    /** @ghidraAddress 0x61fe4 */
    return WhitePreferringRetina2x([self artistNameImageWhite2xBasic],
                                   [self artistNameImageWhiteDataBasic]);
}

- (UIImage *)artistNameImageWhiteMedium {
    /** @ghidraAddress 0x620f4 */
    return WhitePreferringRetina2x([self artistNameImageWhite2xMedium],
                                   [self artistNameImageWhiteDataMedium]);
}

- (UIImage *)artistNameImageWhiteHard {
    /** @ghidraAddress 0x62204 */
    return WhitePreferringRetina2x([self artistNameImageWhite2xHard],
                                   [self artistNameImageWhiteDataHard]);
}

- (UIImage *)musicNameImageBlack {
    /** @ghidraAddress 0x62314 */
    return [self setColor:[self musicNameImageWhite] withColor:BlackTintColor()];
}

- (UIImage *)musicNameImageBlackBasic {
    /** @ghidraAddress 0x624a0 */
    return [self setColor:[self musicNameImageWhiteBasic] withColor:BlackTintColor()];
}

- (UIImage *)musicNameImageBlackMedium {
    /** @ghidraAddress 0x62638 */
    return [self setColor:[self musicNameImageWhiteMedium] withColor:BlackTintColor()];
}

- (UIImage *)musicNameImageBlackHard {
    /** @ghidraAddress 0x627d0 */
    return [self setColor:[self musicNameImageWhiteHard] withColor:BlackTintColor()];
}

- (UIImage *)artistNameImageBlack {
    /** @ghidraAddress 0x62968 */
    return [self setColor:[self artistNameImageWhite] withColor:BlackTintColor()];
}

- (UIImage *)artistNameImageBlackBasic {
    /** @ghidraAddress 0x62af4 */
    return [self setColor:[self artistNameImageWhiteBasic] withColor:BlackTintColor()];
}

- (UIImage *)artistNameImageBlackMedium {
    /** @ghidraAddress 0x62c8c */
    return [self setColor:[self artistNameImageWhiteMedium] withColor:BlackTintColor()];
}

- (UIImage *)artistNameImageBlackHard {
    /** @ghidraAddress 0x62e24 */
    return [self setColor:[self artistNameImageWhiteHard] withColor:BlackTintColor()];
}

- (UIImage *)musicNameImageBrown {
    /** @ghidraAddress 0x62fbc */
    return [self setColor:[self musicNameImageWhite] withColor:BrownTintColor()];
}

- (UIImage *)musicNameImageBrownBasic {
    /** @ghidraAddress 0x63154 */
    return [self setColor:[self musicNameImageWhiteBasic] withColor:BrownTintColor()];
}

- (UIImage *)musicNameImageBrownMedium {
    /** @ghidraAddress 0x632f8 */
    return [self setColor:[self musicNameImageWhiteMedium] withColor:BrownTintColor()];
}

- (UIImage *)musicNameImageBrownHard {
    /** @ghidraAddress 0x6349c */
    return [self setColor:[self musicNameImageWhiteHard] withColor:BrownTintColor()];
}

- (UIImage *)artistNameImageBrown {
    /** @ghidraAddress 0x63640 */
    return [self setColor:[self artistNameImageWhite] withColor:BrownTintColor()];
}

- (UIImage *)artistNameImageBrownBasic {
    /** @ghidraAddress 0x637d8 */
    return [self setColor:[self artistNameImageWhiteBasic] withColor:BrownTintColor()];
}

- (UIImage *)artistNameImageBrownMedium {
    /** @ghidraAddress 0x6397c */
    return [self setColor:[self artistNameImageWhiteMedium] withColor:BrownTintColor()];
}

- (UIImage *)artistNameImageBrownHard {
    /** @ghidraAddress 0x63b20 */
    return [self setColor:[self artistNameImageWhiteHard] withColor:BrownTintColor()];
}

#pragma mark - Double-resolution images

- (UIImage *)artwork2x {
    /** @ghidraAddress 0x63cc4 */
    return DoubleResolutionImageFromData([self artwork2xData]);
}

- (UIImage *)artwork2xBasic {
    /** @ghidraAddress 0x63dbc */
    return DoubleResolutionImageFromData([self artwork2xDataBasic]);
}

- (UIImage *)artwork2xMedium {
    /** @ghidraAddress 0x63eb4 */
    return DoubleResolutionImageFromData([self artwork2xDataMedium]);
}

- (UIImage *)artwork2xHard {
    /** @ghidraAddress 0x63fac */
    return DoubleResolutionImageFromData([self artwork2xDataHard]);
}

- (UIImage *)musicNameImageWhite2x {
    /** @ghidraAddress 0x640a4 */
    return DoubleResolutionImageFromData([self musicNameImageWhite2xData]);
}

- (UIImage *)musicNameImageWhite2xBasic {
    /** @ghidraAddress 0x6419c */
    return DoubleResolutionImageFromData([self musicNameImageWhite2xDataBasic]);
}

- (UIImage *)musicNameImageWhite2xMedium {
    /** @ghidraAddress 0x64294 */
    return DoubleResolutionImageFromData([self musicNameImageWhite2xDataMedium]);
}

- (UIImage *)musicNameImageWhite2xHard {
    /** @ghidraAddress 0x6438c */
    return DoubleResolutionImageFromData([self musicNameImageWhite2xDataHard]);
}

- (UIImage *)artistNameImageWhite2x {
    /** @ghidraAddress 0x64484 */
    return DoubleResolutionImageFromData([self artistNameImageWhite2xData]);
}

- (UIImage *)artistNameImageWhite2xBasic {
    /** @ghidraAddress 0x6457c */
    return DoubleResolutionImageFromData([self artistNameImageWhite2xDataBasic]);
}

- (UIImage *)artistNameImageWhite2xMedium {
    /** @ghidraAddress 0x64674 */
    return DoubleResolutionImageFromData([self artistNameImageWhite2xDataMedium]);
}

- (UIImage *)artistNameImageWhite2xHard {
    /** @ghidraAddress 0x6476c */
    return DoubleResolutionImageFromData([self artistNameImageWhite2xDataHard]);
}

- (UIImage *)musicNameImageBlack2x {
    /** @ghidraAddress 0x64864 */
    return DoubleResolutionImageFromData([self musicNameImageBlack2xData]);
}

- (UIImage *)musicNameImageBlack2xBasic {
    /** @ghidraAddress 0x6495c */
    return DoubleResolutionImageFromData([self musicNameImageBlack2xDataBasic]);
}

- (UIImage *)musicNameImageBlack2xMedium {
    /** @ghidraAddress 0x64a54 */
    return DoubleResolutionImageFromData([self musicNameImageBlack2xDataMedium]);
}

- (UIImage *)musicNameImageBlack2xHard {
    /** @ghidraAddress 0x64b4c */
    return DoubleResolutionImageFromData([self musicNameImageBlack2xDataHard]);
}

- (UIImage *)artistNameImageBlack2x {
    /** @ghidraAddress 0x64c44 */
    return DoubleResolutionImageFromData([self artistNameImageBlack2xData]);
}

- (UIImage *)artistNameImageBlack2xBasic {
    /** @ghidraAddress 0x64d3c */
    return DoubleResolutionImageFromData([self artistNameImageBlack2xDataBasic]);
}

- (UIImage *)artistNameImageBlack2xMedium {
    /** @ghidraAddress 0x64e34 */
    return DoubleResolutionImageFromData([self artistNameImageBlack2xDataMedium]);
}

- (UIImage *)artistNameImageBlack2xHard {
    /** @ghidraAddress 0x64f2c */
    return DoubleResolutionImageFromData([self artistNameImageBlack2xDataHard]);
}

- (UIImage *)musicNameImageBrown2x {
    /** @ghidraAddress 0x65024 */
    return DoubleResolutionImageFromData([self musicNameImageBrown2xData]);
}

- (UIImage *)musicNameImageBrown2xBasic {
    /** @ghidraAddress 0x6511c */
    return DoubleResolutionImageFromData([self musicNameImageBrown2xDataBasic]);
}

- (UIImage *)musicNameImageBrown2xMedium {
    /** @ghidraAddress 0x65214 */
    return DoubleResolutionImageFromData([self musicNameImageBrown2xDataMedium]);
}

- (UIImage *)musicNameImageBrown2xHard {
    /** @ghidraAddress 0x6530c */
    return DoubleResolutionImageFromData([self musicNameImageBrown2xDataHard]);
}

- (UIImage *)artistNameImageBrown2x {
    /** @ghidraAddress 0x65404 */
    return DoubleResolutionImageFromData([self artistNameImageBrown2xData]);
}

- (UIImage *)artistNameImageBrown2xBasic {
    /** @ghidraAddress 0x654fc */
    return DoubleResolutionImageFromData([self artistNameImageBrown2xDataBasic]);
}

- (UIImage *)artistNameImageBrown2xMedium {
    /** @ghidraAddress 0x655f4 */
    return DoubleResolutionImageFromData([self artistNameImageBrown2xDataMedium]);
}

- (UIImage *)artistNameImageBrown2xHard {
    /** @ghidraAddress 0x656ec */
    return DoubleResolutionImageFromData([self artistNameImageBrown2xDataHard]);
}

#pragma mark - Artwork cache

- (void)createCache {
    /** @ghidraAddress 0x65964 */
    if (self.artworkCache != nil) {
        return;
    }
    UIImage *image = nil;
    if (!IsPad()) {
        image = ImageFromData([self artworkData]);
    } else {
        if ([UIScreen mainScreen].scale > kRetinaScaleThreshold) {
            image = [self artwork2x];
        }
        if (image == nil) {
            image = ImageFromData([self artworkData]);
        }
    }
    if (image == nil) {
        return;
    }
    self.artworkCache = image;
}

- (void)releaseChache {
    /** @ghidraAddress 0x65b3c */
    self.artworkCache = nil;
}

- (BOOL)isArtworkCache {
    /** @ghidraAddress 0x66308 */
    return self.artworkCache != nil;
}

#pragma mark - Comparators

- (NSComparisonResult)compare:(MusicData *)other {
    /** @ghidraAddress 0x65b4c */
    NSString *left = self.musicNameHira;
    NSString *right = other.musicNameHira;
    NSComparisonResult result = [left compare:right];
    if (result == NSOrderedSame) {
        return OrderByLength(left.length, right.length);
    }
    return result;
}

- (NSComparisonResult)compareMusicID:(MusicData *)other {
    /** @ghidraAddress 0x65c5c */
    return OrderByValue(self.MusicID, other.MusicID);
}

- (NSComparisonResult)compareMusicNameCustom:(MusicData *)other {
    /** @ghidraAddress 0x65ce0 */
    NSString *left = self.musicSortName;
    NSString *right = other.musicSortName;
    NSComparisonResult result = [left compare:right options:NSLiteralSearch];
    if (result == NSOrderedSame) {
        return OrderByLength(left.length, right.length);
    }
    return result;
}

- (NSComparisonResult)compareArtistNameCustom:(MusicData *)other {
    /** @ghidraAddress 0x65df4 */
    NSComparisonResult result = [self.artistSortName compare:other.artistSortName
                                                     options:NSLiteralSearch];
    if (result == NSOrderedSame) {
        return [self compareMusicNameCustom:other];
    }
    return result;
}

- (NSComparisonResult)compareMusicNameHira:(MusicData *)other {
    /** @ghidraAddress 0x65eec */
    NSString *left = self.musicNameHira;
    NSString *right = other.musicNameHira;
    NSComparisonResult result = [left compare:right options:NSLiteralSearch];
    if (result == NSOrderedSame) {
        return OrderByLength(left.length, right.length);
    }
    return result;
}

- (NSComparisonResult)compareArtistNameHira:(MusicData *)other {
    /** @ghidraAddress 0x66000 */
    NSComparisonResult result = [self.artistNameHira compare:other.artistNameHira
                                                     options:NSLiteralSearch];
    if (result == NSOrderedSame) {
        return [self compareMusicNameHira:other];
    }
    return result;
}

- (NSComparisonResult)compareDifficultyBasic:(MusicData *)other {
    /** @ghidraAddress 0x660f8 */
    return OrderByValue(self.difficultyBasic, other.difficultyBasic);
}

- (NSComparisonResult)compareDifficultyMedium:(MusicData *)other {
    /** @ghidraAddress 0x6617c */
    return OrderByValue(self.difficultyMedium, other.difficultyMedium);
}

- (NSComparisonResult)compareDifficultyHard:(MusicData *)other {
    /** @ghidraAddress 0x66200 */
    return OrderByValue(self.difficultyHard, other.difficultyHard);
}

- (NSComparisonResult)compareDifficultySpecial:(MusicData *)other {
    /** @ghidraAddress 0x66284 */
    return OrderByValue(self.difficultySpecial, other.difficultySpecial);
}

@end
