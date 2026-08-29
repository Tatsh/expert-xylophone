/**
 * @file
 * A @c MusicData subclass that represents a single user-supplied tune loaded from the app's
 * Documents directory rather than from the shipped catalogue.
 *
 * The stored @c musicName (inherited
 * from @c MusicData) names the audio file and @c plyName names the companion note sheet; both are
 * resolved against the Documents directory on demand. Most catalogue metadata is fixed: the tune
 * identifier is 1, every difficulty is 0, and both tempo bounds are 100 BPM. The class also renders
 * the tune title and artist text into PNG image data on the fly.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class MusicDataFromDoc, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

// The superclass is not yet reconstructed in this tree; this speculative import resolves once the
// MusicData class lands (the same approach ScoreData.m and AppDelegate.mm already use).
#import "MusicData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A user-supplied tune backed by audio and note-sheet files in the Documents directory.
 */
@interface MusicDataFromDoc : MusicData

/**
 * The note-sheet file name, resolved against the Documents directory when the sheet loads.
 * @ghidraAddress 0x67e28 (getter)
 * @ghidraAddress 0x67e38 (setter)
 */
@property(nonatomic, strong) NSString *plyName;

/**
 * Build a Documents-directory path by appending @p document to the Documents directory.
 * @param document The file name to resolve against the Documents directory.
 * @return The absolute path @c \@"Documents/document".
 * @ghidraAddress 0x6726c
 */
+ (NSString *)getPathWithDocument:(NSString *)document;

/**
 * Create an instance whose audio file is @p path and whose note sheet is @p plyName.
 * @param path The audio file name stored as the inherited @c musicName.
 * @param plyName The note-sheet file name.
 * @return A newly initialised instance.
 * @ghidraAddress 0x6734c
 */
+ (instancetype)dataWithPath:(NSString *)path PlyName:(NSString *)plyName;

/**
 * The tune identifier, always 1 for a Documents-backed tune.
 * @return The tune identifier, always 1.
 * @ghidraAddress 0x674cc
 */
- (int)MusicID;
/**
 * The basic-chart difficulty, always 0.
 * @return The basic-chart difficulty, always 0.
 * @ghidraAddress 0x674d4
 */
- (int)difficultyBasic;
/**
 * The medium-chart difficulty, always 0.
 * @return The medium-chart difficulty, always 0.
 * @ghidraAddress 0x674dc
 */
- (int)difficultyMedium;
/**
 * The hard-chart difficulty, always 0.
 * @return The hard-chart difficulty, always 0.
 * @ghidraAddress 0x674e4
 */
- (int)difficultyHard;
/**
 * The special-chart difficulty, always 0.
 * @return The special-chart difficulty, always 0.
 * @ghidraAddress 0x674ec
 */
- (int)difficultySpecial;
/**
 * The minimum tempo in BPM, always 100.
 * @return The minimum tempo in BPM, always 100.
 * @ghidraAddress 0x674f4
 */
- (int)bpm_MIN;
/**
 * The maximum tempo in BPM, always 100.
 * @return The maximum tempo in BPM, always 100.
 * @ghidraAddress 0x674fc
 */
- (int)bpm_MAX;
/**
 * The hiragana title reading, always nil for a Documents-backed tune.
 * @return Always @c nil.
 * @ghidraAddress 0x67504
 */
- (nullable NSString *)musicNameHira;
/**
 * The romanised title, always nil for a Documents-backed tune.
 * @return Always @c nil.
 * @ghidraAddress 0x6750c
 */
- (nullable NSString *)musicNameRoman;
/**
 * The artist name, always nil for a Documents-backed tune.
 * @return Always @c nil.
 * @ghidraAddress 0x67514
 */
- (nullable NSString *)artistName;
/**
 * The hiragana artist reading, always nil for a Documents-backed tune.
 * @return Always @c nil.
 * @ghidraAddress 0x6751c
 */
- (nullable NSString *)artistNameHira;
/**
 * The romanised artist name, always nil for a Documents-backed tune.
 * @return Always @c nil.
 * @ghidraAddress 0x67524
 */
- (nullable NSString *)artistNameRoman;

/**
 * The audio file contents loaded from the Documents directory.
 * @return The audio file contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x6752c
 */
- (nullable NSData *)music;
/**
 * The preview audio, always nil for a Documents-backed tune.
 * @return Always @c nil.
 * @ghidraAddress 0x675e4
 */
- (nullable NSData *)musicPre;

/**
 * Load the note-sheet file contents from the Documents directory.
 * @return The note-sheet contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x675ec
 */
- (nullable NSData *)loadSheet;
/**
 * The basic note sheet (the single Documents note sheet).
 * @return The note-sheet contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x676a4
 */
- (nullable NSData *)sheetBasic;
/**
 * The basic-light note sheet (the single Documents note sheet).
 * @return The note-sheet contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x676b0
 */
- (nullable NSData *)sheetBasicLight;
/**
 * The medium note sheet (the single Documents note sheet).
 * @return The note-sheet contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x676bc
 */
- (nullable NSData *)sheetMedium;
/**
 * The medium-light note sheet (the single Documents note sheet).
 * @return The note-sheet contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x676c8
 */
- (nullable NSData *)sheetMediumLight;
/**
 * The hard note sheet (the single Documents note sheet).
 * @return The note-sheet contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x676d4
 */
- (nullable NSData *)sheetHard;
/**
 * The hard-light note sheet (the single Documents note sheet).
 * @return The note-sheet contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x676e0
 */
- (nullable NSData *)sheetHardLight;
/**
 * The special note sheet (the single Documents note sheet).
 * @return The note-sheet contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x676ec
 */
- (nullable NSData *)sheetSpecial;
/**
 * The special-light note sheet (the single Documents note sheet).
 * @return The note-sheet contents, or @c nil when the file could not be read.
 * @ghidraAddress 0x676f8
 */
- (nullable NSData *)sheetSpecialLight;

/**
 * The artwork PNG rendered at double scale.
 * @return The PNG-encoded artwork, or @c nil when rendering failed.
 * @ghidraAddress 0x67704
 */
- (nullable NSData *)artwork2xData;
/**
 * The artwork PNG rendered at single scale.
 * @return The PNG-encoded artwork, or @c nil when rendering failed.
 * @ghidraAddress 0x67718
 */
- (nullable NSData *)artworkData;
/**
 * Render the title into a square artwork PNG.
 * @param scale The image scale factor passed to the graphics context.
 * @param luminance The greyscale fill luminance in the range 0..1.
 * @return The PNG-encoded artwork.
 * @ghidraAddress 0x6772c
 */
- (nullable NSData *)artworkDataWithScale:(float)scale Luminance:(float)luminance;

/**
 * The white title-name image PNG rendered at double scale.
 * @return The PNG-encoded title image, or @c nil when rendering failed.
 * @ghidraAddress 0x67944
 */
- (nullable NSData *)musicNameImageWhite2xData;
/**
 * The white title-name image PNG rendered at single scale.
 * @return The PNG-encoded title image, or @c nil when rendering failed.
 * @ghidraAddress 0x67958
 */
- (nullable NSData *)musicNameImageWhiteData;
/**
 * The black title-name image PNG rendered at double scale.
 * @return The PNG-encoded title image, or @c nil when rendering failed.
 * @ghidraAddress 0x6796c
 */
- (nullable NSData *)musicNameImageBlack2xData;
/**
 * The black title-name image PNG rendered at single scale.
 * @return The PNG-encoded title image, or @c nil when rendering failed.
 * @ghidraAddress 0x67980
 */
- (nullable NSData *)musicNameImageBlackData;
/**
 * Render the title text into a name-strip PNG.
 * @param scale The image scale factor passed to the graphics context.
 * @param luminance The greyscale fill luminance in the range 0..1.
 * @return The PNG-encoded title image.
 * @ghidraAddress 0x67994
 */
- (nullable NSData *)musicNameImageDataWithScale:(float)scale Luminance:(float)luminance;

/**
 * The white artist-name image PNG rendered at double scale.
 * @return The PNG-encoded artist image, or @c nil when rendering failed.
 * @ghidraAddress 0x67c0c
 */
- (nullable NSData *)artistNameImageWhite2xData;
/**
 * The white artist-name image PNG rendered at single scale.
 * @return The PNG-encoded artist image, or @c nil when rendering failed.
 * @ghidraAddress 0x67c20
 */
- (nullable NSData *)artistNameImageWhiteData;
/**
 * The black artist-name image PNG rendered at double scale.
 * @return The PNG-encoded artist image, or @c nil when rendering failed.
 * @ghidraAddress 0x67c34
 */
- (nullable NSData *)artistNameImageBlack2xData;
/**
 * The black artist-name image PNG rendered at single scale.
 * @return The PNG-encoded artist image, or @c nil when rendering failed.
 * @ghidraAddress 0x67c48
 */
- (nullable NSData *)artistNameImageBlackData;
/**
 * Render the artist text into a name-strip PNG.
 * @param scale The image scale factor passed to the graphics context.
 * @param luminance The greyscale fill luminance in the range 0..1.
 * @return The PNG-encoded artist image.
 * @ghidraAddress 0x67c5c
 */
- (nullable NSData *)artistNameImageDataWithScale:(float)scale Luminance:(float)luminance;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
