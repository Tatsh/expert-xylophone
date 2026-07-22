/** @file
 * The catalogue entry for a single tune. A @c MusicData instance carries the tune identifier, its
 * per-difficulty levels, its tempo bounds, the localised title and artist strings (with their
 * hiragana readings, romanisations, sort keys, and initials), and the packaged asset archive it
 * was loaded from. It decrypts and vends the audio, note-sheet, artwork, and pre-rendered
 * name-strip assets held in that archive on demand, caches the decoded artwork image, and provides
 * the comparators used to order a music list.
 *
 * The class is subclassed by @c MusicDataFromDoc, which overrides the metadata and asset accessors
 * to serve a user-supplied tune from the Documents directory instead of a packaged archive.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class MusicData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class UIColor;
@class UIImage;

/**
 * @brief A catalogue entry describing one tune and vending its packaged assets.
 */
@interface MusicData : NSObject

/**
 * @brief The tune identifier.
 * @ghidraAddress 0x66344 (getter)
 * @ghidraAddress 0x66354 (setter)
 */
@property(nonatomic, assign) int MusicID;
/**
 * @brief The basic-chart level.
 * @ghidraAddress 0x66364 (getter)
 * @ghidraAddress 0x66374 (setter)
 */
@property(nonatomic, assign) int difficultyBasic;
/**
 * @brief The medium-chart level.
 * @ghidraAddress 0x66384 (getter)
 * @ghidraAddress 0x66394 (setter)
 */
@property(nonatomic, assign) int difficultyMedium;
/**
 * @brief The hard-chart level.
 * @ghidraAddress 0x663a4 (getter)
 * @ghidraAddress 0x663b4 (setter)
 */
@property(nonatomic, assign) int difficultyHard;
/**
 * @brief The special-chart level.
 * @ghidraAddress 0x663c4 (getter)
 * @ghidraAddress 0x663d4 (setter)
 */
@property(nonatomic, assign) int difficultySpecial;
/**
 * @brief The minimum tempo in BPM.
 * @ghidraAddress 0x663e4 (getter)
 * @ghidraAddress 0x663f4 (setter)
 */
@property(nonatomic, assign) int bpm_MIN;
/**
 * @brief The maximum tempo in BPM.
 * @ghidraAddress 0x66404 (getter)
 * @ghidraAddress 0x66414 (setter)
 */
@property(nonatomic, assign) int bpm_MAX;

/**
 * @brief The display title.
 * @ghidraAddress 0x66424 (getter)
 * @ghidraAddress 0x66434 (setter)
 */
@property(nonatomic, strong) NSString *musicName;
/**
 * @brief The hiragana reading of the title.
 * @ghidraAddress 0x6646c (getter)
 * @ghidraAddress 0x6647c (setter)
 */
@property(nonatomic, strong) NSString *musicNameHira;
/**
 * @brief The romanised title.
 * @ghidraAddress 0x664b4 (getter)
 * @ghidraAddress 0x664c4 (setter)
 */
@property(nonatomic, strong) NSString *musicNameRoman;
/**
 * @brief The artist name.
 * @ghidraAddress 0x664fc (getter)
 * @ghidraAddress 0x6650c (setter)
 */
@property(nonatomic, strong) NSString *artistName;
/**
 * @brief The hiragana reading of the artist name.
 * @ghidraAddress 0x66544 (getter)
 * @ghidraAddress 0x66554 (setter)
 */
@property(nonatomic, strong) NSString *artistNameHira;
/**
 * @brief The romanised artist name.
 * @ghidraAddress 0x6658c (getter)
 * @ghidraAddress 0x6659c (setter)
 */
@property(nonatomic, strong) NSString *artistNameRoman;
/**
 * @brief The sort key derived from the title reading.
 * @ghidraAddress 0x665d4 (getter)
 * @ghidraAddress 0x665e4 (setter)
 */
@property(nonatomic, strong) NSString *musicSortName;
/**
 * @brief The sort key derived from the artist reading.
 * @ghidraAddress 0x6661c (getter)
 * @ghidraAddress 0x6662c (setter)
 */
@property(nonatomic, strong) NSString *artistSortName;
/**
 * @brief The single-character index initial derived from the title sort key.
 * @ghidraAddress 0x66664 (getter)
 * @ghidraAddress 0x66674 (setter)
 */
@property(nonatomic, strong) NSString *musicNameInitial;
/**
 * @brief The single-character index initial derived from the artist sort key.
 * @ghidraAddress 0x666ac (getter)
 * @ghidraAddress 0x666bc (setter)
 */
@property(nonatomic, strong) NSString *artistNameInitial;
/**
 * @brief The optional per-tune settings read from the archive metadata's @c Options entry.
 * @ghidraAddress 0x666f4 (getter)
 * @ghidraAddress 0x66704 (setter)
 */
@property(nonatomic, strong) NSDictionary *optionalDataDict;
/**
 * @brief The extend (special) note data owner, held without ownership.
 * @ghidraAddress 0x6673c (getter)
 * @ghidraAddress 0x6674c (setter)
 */
@property(nonatomic, assign) MusicData *spData;
/**
 * @brief The extend audio archive entry loaded for the special chart.
 * @ghidraAddress 0x6675c (getter)
 * @ghidraAddress 0x6676c (setter)
 */
@property(nonatomic, strong) MusicData *ExtMusicData;
/**
 * @brief The cached decoded default artwork image.
 * @ghidraAddress 0x667a4 (getter)
 * @ghidraAddress 0x667b4 (setter)
 */
@property(strong) UIImage *artworkCache;
/**
 * @brief The cached decoded basic-chart artwork image.
 * @ghidraAddress 0x667c0 (getter)
 * @ghidraAddress 0x667d0 (setter)
 */
@property(strong) UIImage *artworkCacheBasic;
/**
 * @brief The cached decoded medium-chart artwork image.
 * @ghidraAddress 0x667dc (getter)
 * @ghidraAddress 0x667ec (setter)
 */
@property(strong) UIImage *artworkCacheMedium;
/**
 * @brief The cached decoded hard-chart artwork image.
 * @ghidraAddress 0x667f8 (getter)
 * @ghidraAddress 0x66808 (setter)
 */
@property(strong) UIImage *artworkCacheHard;
/**
 * @brief The path of the packaged archive backing this tune.
 * @ghidraAddress 0x66814 (getter)
 * @ghidraAddress 0x66824 (setter)
 */
@property(nonatomic, strong) NSString *filePath;
/**
 * @brief The decode-type index selecting the archive decryption key.
 * @ghidraAddress 0x6685c (getter)
 * @ghidraAddress 0x6686c (setter)
 */
@property(nonatomic, assign) int decodeType;

/**
 * @brief Load and assemble the catalogue entry for the tune archived at @p path.
 * @param path The packaged archive path.
 * @param musicID The expected tune identifier; the archive must declare the same value.
 * @return A fully populated instance, or @c nil if the archive is missing, undecryptable, or
 *         declares a mismatched identifier or an out-of-range level.
 * @ghidraAddress 0x5ee64
 */
+ (instancetype)dataWithPath:(NSString *)path ID:(int)musicID;

/**
 * @brief Decrypt @p data in place with a Blowfish key derived from @p key.
 * @param data The archive member to decrypt in place.
 * @param key The per-decode-type key bytes.
 * @param keyLength The number of key bytes.
 * @return @p data on success, or @c nil if deciphering fails.
 * @ghidraAddress 0x5eb78
 */
+ (NSMutableData *)decodeBF:(NSMutableData *)data Key:(const char *)key KeyLength:(int)keyLength;

/**
 * @brief Open the backing archive, read the named member, and decrypt it.
 * @param entryName The archive member name.
 * @param zipPath The archive path.
 * @param decodeType The decode-type index selecting the decryption key.
 * @return The decrypted member data, or @c nil.
 * @ghidraAddress 0x5ecd4
 */
+ (NSMutableData *)getZipData:(NSString *)entryName
                         Path:(NSString *)zipPath
                   DecodeType:(int)decodeType;

/**
 * @brief Read the named member from the backing archive using the instance's path and decode type.
 * @param entryName The archive member name.
 * @return The decrypted member data, or @c nil.
 * @ghidraAddress 0x600cc
 */
- (NSMutableData *)getZipData:(NSString *)entryName;

/**
 * @brief Read a member preferring the tune's @c Options override, falling back to the base member.
 * @param entryName The archive member name.
 * @return The decrypted member data, or @c nil.
 * @ghidraAddress 0x60190
 */
- (NSMutableData *)getOptionalZipData:(NSString *)entryName;

/**
 * @brief Read a member preferring the tune's @c Options override, then @p defaultName.
 * @param entryName The primary archive member name.
 * @param defaultName The fallback archive member name, or @c nil.
 * @return The decrypted member data, or @c nil.
 * @ghidraAddress 0x601b8
 */
- (NSMutableData *)getOptionalZipData:(NSString *)entryName withDefaultName:(NSString *)defaultName;

/**
 * @brief The main audio archive member (@c bgm).
 * @ghidraAddress 0x602d8
 */
- (NSMutableData *)music;
/**
 * @brief The basic-chart audio member (@c bgm_b, falling back to @c bgm).
 * @ghidraAddress 0x602ec
 */
- (NSMutableData *)musicBasic;
/**
 * @brief The medium-chart audio member (@c bgm_m, falling back to @c bgm).
 * @ghidraAddress 0x60308
 */
- (NSMutableData *)musicMedium;
/**
 * @brief The hard-chart audio member (@c bgm_h, falling back to @c bgm).
 * @ghidraAddress 0x60324
 */
- (NSMutableData *)musicHard;
/**
 * @brief The preview audio member (@c pre).
 * @ghidraAddress 0x60340
 */
- (NSMutableData *)musicPre;

/**
 * @brief The basic note sheet (@c note_bas).
 * @ghidraAddress 0x60354
 */
- (NSMutableData *)sheetBasic;
/**
 * @brief The basic-light note sheet (@c note_bas2, falling back to @c note_bas).
 * @ghidraAddress 0x60368
 */
- (NSMutableData *)sheetBasicLight;
/**
 * @brief The medium note sheet (@c note_med).
 * @ghidraAddress 0x60384
 */
- (NSMutableData *)sheetMedium;
/**
 * @brief The medium-light note sheet (@c note_med2, falling back to @c note_med).
 * @ghidraAddress 0x60398
 */
- (NSMutableData *)sheetMediumLight;
/**
 * @brief The hard note sheet (@c note_har).
 * @ghidraAddress 0x603b4
 */
- (NSMutableData *)sheetHard;
/**
 * @brief The hard-light note sheet (@c note_har2, falling back to @c note_har).
 * @ghidraAddress 0x603c8
 */
- (NSMutableData *)sheetHardLight;
/**
 * @brief The special note sheet, sourced from the extend note data owner.
 * @ghidraAddress 0x603e4
 */
- (NSMutableData *)sheetSpecial;
/**
 * @brief The special-light note sheet, sourced from the extend note data owner.
 * @ghidraAddress 0x60484
 */
- (NSMutableData *)sheetSpecialLight;

/**
 * @brief The default artwork member (@c artwork).
 * @ghidraAddress 0x60524
 */
- (NSMutableData *)artworkData;
/**
 * @brief The basic-chart artwork member (@c artwork_b).
 * @ghidraAddress 0x60538
 */
- (NSMutableData *)artworkDataBasic;
/**
 * @brief The medium-chart artwork member (@c artwork_m).
 * @ghidraAddress 0x6054c
 */
- (NSMutableData *)artworkDataMedium;
/**
 * @brief The hard-chart artwork member (@c artwork_h).
 * @ghidraAddress 0x60560
 */
- (NSMutableData *)artworkDataHard;

/**
 * @brief The default white title-strip member.
 * @ghidraAddress 0x60574
 */
- (NSMutableData *)musicNameImageWhiteData;
/**
 * @brief The basic white title-strip member.
 * @ghidraAddress 0x60588
 */
- (NSMutableData *)musicNameImageWhiteDataBasic;
/**
 * @brief The medium white title-strip member.
 * @ghidraAddress 0x6059c
 */
- (NSMutableData *)musicNameImageWhiteDataMedium;
/**
 * @brief The hard white title-strip member.
 * @ghidraAddress 0x605b0
 */
- (NSMutableData *)musicNameImageWhiteDataHard;
/**
 * @brief The default white artist-strip member.
 * @ghidraAddress 0x605c4
 */
- (NSMutableData *)artistNameImageWhiteData;
/**
 * @brief The basic white artist-strip member.
 * @ghidraAddress 0x605d8
 */
- (NSMutableData *)artistNameImageWhiteDataBasic;
/**
 * @brief The medium white artist-strip member.
 * @ghidraAddress 0x605ec
 */
- (NSMutableData *)artistNameImageWhiteDataMedium;
/**
 * @brief The hard white artist-strip member.
 * @ghidraAddress 0x60600
 */
- (NSMutableData *)artistNameImageWhiteDataHard;
/**
 * @brief The default black title-strip member.
 * @ghidraAddress 0x60614
 */
- (NSMutableData *)musicNameImageBlackData;
/**
 * @brief The basic black title-strip member.
 * @ghidraAddress 0x60628
 */
- (NSMutableData *)musicNameImageBlackDataBasic;
/**
 * @brief The medium black title-strip member.
 * @ghidraAddress 0x6063c
 */
- (NSMutableData *)musicNameImageBlackDataMedium;
/**
 * @brief The hard black title-strip member.
 * @ghidraAddress 0x60650
 */
- (NSMutableData *)musicNameImageBlackDataHard;
/**
 * @brief The default black artist-strip member.
 * @ghidraAddress 0x60664
 */
- (NSMutableData *)artistNameImageBlackData;
/**
 * @brief The basic black artist-strip member.
 * @ghidraAddress 0x60678
 */
- (NSMutableData *)artistNameImageBlackDataBasic;
/**
 * @brief The medium black artist-strip member.
 * @ghidraAddress 0x6068c
 */
- (NSMutableData *)artistNameImageBlackDataMedium;
/**
 * @brief The hard black artist-strip member.
 * @ghidraAddress 0x606a0
 */
- (NSMutableData *)artistNameImageBlackDataHard;

/**
 * @brief The default artwork member at double resolution (@c artwork2x).
 * @ghidraAddress 0x606b4
 */
- (NSMutableData *)artwork2xData;
/**
 * @brief The basic double-resolution artwork member.
 * @ghidraAddress 0x606c8
 */
- (NSMutableData *)artwork2xDataBasic;
/**
 * @brief The medium double-resolution artwork member.
 * @ghidraAddress 0x606dc
 */
- (NSMutableData *)artwork2xDataMedium;
/**
 * @brief The hard double-resolution artwork member.
 * @ghidraAddress 0x606f0
 */
- (NSMutableData *)artwork2xDataHard;
/**
 * @brief The default double-resolution white title-strip member.
 * @ghidraAddress 0x60704
 */
- (NSMutableData *)musicNameImageWhite2xData;
/**
 * @brief The basic double-resolution white title-strip member.
 * @ghidraAddress 0x60718
 */
- (NSMutableData *)musicNameImageWhite2xDataBasic;
/**
 * @brief The medium double-resolution white title-strip member.
 * @ghidraAddress 0x6072c
 */
- (NSMutableData *)musicNameImageWhite2xDataMedium;
/**
 * @brief The hard double-resolution white title-strip member.
 * @ghidraAddress 0x60740
 */
- (NSMutableData *)musicNameImageWhite2xDataHard;
/**
 * @brief The default double-resolution white artist-strip member.
 * @ghidraAddress 0x60754
 */
- (NSMutableData *)artistNameImageWhite2xData;
/**
 * @brief The basic double-resolution white artist-strip member.
 * @ghidraAddress 0x60768
 */
- (NSMutableData *)artistNameImageWhite2xDataBasic;
/**
 * @brief The medium double-resolution white artist-strip member.
 * @ghidraAddress 0x6077c
 */
- (NSMutableData *)artistNameImageWhite2xDataMedium;
/**
 * @brief The hard double-resolution white artist-strip member.
 * @ghidraAddress 0x60790
 */
- (NSMutableData *)artistNameImageWhite2xDataHard;
/**
 * @brief The default double-resolution black title-strip member.
 * @ghidraAddress 0x607a4
 */
- (NSMutableData *)musicNameImageBlack2xData;
/**
 * @brief The basic double-resolution black title-strip member.
 * @ghidraAddress 0x607b8
 */
- (NSMutableData *)musicNameImageBlack2xDataBasic;
/**
 * @brief The medium double-resolution black title-strip member.
 * @ghidraAddress 0x607cc
 */
- (NSMutableData *)musicNameImageBlack2xDataMedium;
/**
 * @brief The hard double-resolution black title-strip member.
 * @ghidraAddress 0x607e0
 */
- (NSMutableData *)musicNameImageBlack2xDataHard;
/**
 * @brief The default double-resolution black artist-strip member.
 * @ghidraAddress 0x607f4
 */
- (NSMutableData *)artistNameImageBlack2xData;
/**
 * @brief The basic double-resolution black artist-strip member.
 * @ghidraAddress 0x60808
 */
- (NSMutableData *)artistNameImageBlack2xDataBasic;
/**
 * @brief The medium double-resolution black artist-strip member.
 * @ghidraAddress 0x6081c
 */
- (NSMutableData *)artistNameImageBlack2xDataMedium;
/**
 * @brief The hard double-resolution black artist-strip member.
 * @ghidraAddress 0x60830
 */
- (NSMutableData *)artistNameImageBlack2xDataHard;

/**
 * @brief The default double-resolution brown-tinted title strip, PNG encoded.
 * @ghidraAddress 0x60844
 */
- (NSData *)musicNameImageBrown2xData;
/**
 * @brief The basic double-resolution brown-tinted title strip, PNG encoded.
 * @ghidraAddress 0x60988
 */
- (NSData *)musicNameImageBrown2xDataBasic;
/**
 * @brief The medium double-resolution brown-tinted title strip, PNG encoded.
 * @ghidraAddress 0x60ad8
 */
- (NSData *)musicNameImageBrown2xDataMedium;
/**
 * @brief The hard double-resolution brown-tinted title strip, PNG encoded.
 * @ghidraAddress 0x60c28
 */
- (NSData *)musicNameImageBrown2xDataHard;
/**
 * @brief The default double-resolution brown-tinted artist strip, PNG encoded.
 * @ghidraAddress 0x60d78
 */
- (NSData *)artistNameImageBrown2xData;
/**
 * @brief The basic double-resolution brown-tinted artist strip, PNG encoded.
 * @ghidraAddress 0x60ebc
 */
- (NSData *)artistNameImageBrown2xDataBasic;
/**
 * @brief The medium double-resolution brown-tinted artist strip, PNG encoded.
 * @ghidraAddress 0x6100c
 */
- (NSData *)artistNameImageBrown2xDataMedium;
/**
 * @brief The hard double-resolution brown-tinted artist strip, PNG encoded.
 * @ghidraAddress 0x6115c
 */
- (NSData *)artistNameImageBrown2xDataHard;

/**
 * @brief The default artwork image, decoded and cached.
 * @ghidraAddress 0x612ac
 */
- (UIImage *)artwork;
/**
 * @brief The basic artwork image, decoded and cached.
 * @ghidraAddress 0x61498
 */
- (UIImage *)artworkBasic;
/**
 * @brief The medium artwork image, decoded and cached.
 * @ghidraAddress 0x61684
 */
- (UIImage *)artworkMedium;
/**
 * @brief The hard artwork image, decoded and cached.
 * @ghidraAddress 0x6188c
 */
- (UIImage *)artworkHard;
/**
 * @brief The default white title-strip image.
 * @ghidraAddress 0x61a94
 */
- (UIImage *)musicNameImageWhite;
/**
 * @brief The basic white title-strip image.
 * @ghidraAddress 0x61ba4
 */
- (UIImage *)musicNameImageWhiteBasic;
/**
 * @brief The medium white title-strip image.
 * @ghidraAddress 0x61cb4
 */
- (UIImage *)musicNameImageWhiteMedium;
/**
 * @brief The hard white title-strip image.
 * @ghidraAddress 0x61dc4
 */
- (UIImage *)musicNameImageWhiteHard;
/**
 * @brief The default white artist-strip image.
 * @ghidraAddress 0x61ed4
 */
- (UIImage *)artistNameImageWhite;
/**
 * @brief The basic white artist-strip image.
 * @ghidraAddress 0x61fe4
 */
- (UIImage *)artistNameImageWhiteBasic;
/**
 * @brief The medium white artist-strip image.
 * @ghidraAddress 0x620f4
 */
- (UIImage *)artistNameImageWhiteMedium;
/**
 * @brief The hard white artist-strip image.
 * @ghidraAddress 0x62204
 */
- (UIImage *)artistNameImageWhiteHard;
/**
 * @brief The default black title-strip image.
 * @ghidraAddress 0x62314
 */
- (UIImage *)musicNameImageBlack;
/**
 * @brief The basic black title-strip image.
 * @ghidraAddress 0x624a0
 */
- (UIImage *)musicNameImageBlackBasic;
/**
 * @brief The medium black title-strip image.
 * @ghidraAddress 0x62638
 */
- (UIImage *)musicNameImageBlackMedium;
/**
 * @brief The hard black title-strip image.
 * @ghidraAddress 0x627d0
 */
- (UIImage *)musicNameImageBlackHard;
/**
 * @brief The default black artist-strip image.
 * @ghidraAddress 0x62968
 */
- (UIImage *)artistNameImageBlack;
/**
 * @brief The basic black artist-strip image.
 * @ghidraAddress 0x62af4
 */
- (UIImage *)artistNameImageBlackBasic;
/**
 * @brief The medium black artist-strip image.
 * @ghidraAddress 0x62c8c
 */
- (UIImage *)artistNameImageBlackMedium;
/**
 * @brief The hard black artist-strip image.
 * @ghidraAddress 0x62e24
 */
- (UIImage *)artistNameImageBlackHard;
/**
 * @brief The default brown-tinted title-strip image.
 * @ghidraAddress 0x62fbc
 */
- (UIImage *)musicNameImageBrown;
/**
 * @brief The basic brown-tinted title-strip image.
 * @ghidraAddress 0x63154
 */
- (UIImage *)musicNameImageBrownBasic;
/**
 * @brief The medium brown-tinted title-strip image.
 * @ghidraAddress 0x632f8
 */
- (UIImage *)musicNameImageBrownMedium;
/**
 * @brief The hard brown-tinted title-strip image.
 * @ghidraAddress 0x6349c
 */
- (UIImage *)musicNameImageBrownHard;
/**
 * @brief The default brown-tinted artist-strip image.
 * @ghidraAddress 0x63640
 */
- (UIImage *)artistNameImageBrown;
/**
 * @brief The basic brown-tinted artist-strip image.
 * @ghidraAddress 0x637d8
 */
- (UIImage *)artistNameImageBrownBasic;
/**
 * @brief The medium brown-tinted artist-strip image.
 * @ghidraAddress 0x6397c
 */
- (UIImage *)artistNameImageBrownMedium;
/**
 * @brief The hard brown-tinted artist-strip image.
 * @ghidraAddress 0x63b20
 */
- (UIImage *)artistNameImageBrownHard;

/**
 * @brief The default double-resolution artwork image.
 * @ghidraAddress 0x63cc4
 */
- (UIImage *)artwork2x;
/**
 * @brief The basic double-resolution artwork image.
 * @ghidraAddress 0x63dbc
 */
- (UIImage *)artwork2xBasic;
/**
 * @brief The medium double-resolution artwork image.
 * @ghidraAddress 0x63eb4
 */
- (UIImage *)artwork2xMedium;
/**
 * @brief The hard double-resolution artwork image.
 * @ghidraAddress 0x63fac
 */
- (UIImage *)artwork2xHard;
/**
 * @brief The default double-resolution white title-strip image.
 * @ghidraAddress 0x640a4
 */
- (UIImage *)musicNameImageWhite2x;
/**
 * @brief The basic double-resolution white title-strip image.
 * @ghidraAddress 0x6419c
 */
- (UIImage *)musicNameImageWhite2xBasic;
/**
 * @brief The medium double-resolution white title-strip image.
 * @ghidraAddress 0x64294
 */
- (UIImage *)musicNameImageWhite2xMedium;
/**
 * @brief The hard double-resolution white title-strip image.
 * @ghidraAddress 0x6438c
 */
- (UIImage *)musicNameImageWhite2xHard;
/**
 * @brief The default double-resolution white artist-strip image.
 * @ghidraAddress 0x64484
 */
- (UIImage *)artistNameImageWhite2x;
/**
 * @brief The basic double-resolution white artist-strip image.
 * @ghidraAddress 0x6457c
 */
- (UIImage *)artistNameImageWhite2xBasic;
/**
 * @brief The medium double-resolution white artist-strip image.
 * @ghidraAddress 0x64674
 */
- (UIImage *)artistNameImageWhite2xMedium;
/**
 * @brief The hard double-resolution white artist-strip image.
 * @ghidraAddress 0x6476c
 */
- (UIImage *)artistNameImageWhite2xHard;
/**
 * @brief The default double-resolution black title-strip image.
 * @ghidraAddress 0x64864
 */
- (UIImage *)musicNameImageBlack2x;
/**
 * @brief The basic double-resolution black title-strip image.
 * @ghidraAddress 0x6495c
 */
- (UIImage *)musicNameImageBlack2xBasic;
/**
 * @brief The medium double-resolution black title-strip image.
 * @ghidraAddress 0x64a54
 */
- (UIImage *)musicNameImageBlack2xMedium;
/**
 * @brief The hard double-resolution black title-strip image.
 * @ghidraAddress 0x64b4c
 */
- (UIImage *)musicNameImageBlack2xHard;
/**
 * @brief The default double-resolution black artist-strip image.
 * @ghidraAddress 0x64c44
 */
- (UIImage *)artistNameImageBlack2x;
/**
 * @brief The basic double-resolution black artist-strip image.
 * @ghidraAddress 0x64d3c
 */
- (UIImage *)artistNameImageBlack2xBasic;
/**
 * @brief The medium double-resolution black artist-strip image.
 * @ghidraAddress 0x64e34
 */
- (UIImage *)artistNameImageBlack2xMedium;
/**
 * @brief The hard double-resolution black artist-strip image.
 * @ghidraAddress 0x64f2c
 */
- (UIImage *)artistNameImageBlack2xHard;
/**
 * @brief The default double-resolution brown-tinted title-strip image.
 * @ghidraAddress 0x65024
 */
- (UIImage *)musicNameImageBrown2x;
/**
 * @brief The basic double-resolution brown-tinted title-strip image.
 * @ghidraAddress 0x6511c
 */
- (UIImage *)musicNameImageBrown2xBasic;
/**
 * @brief The medium double-resolution brown-tinted title-strip image.
 * @ghidraAddress 0x65214
 */
- (UIImage *)musicNameImageBrown2xMedium;
/**
 * @brief The hard double-resolution brown-tinted title-strip image.
 * @ghidraAddress 0x6530c
 */
- (UIImage *)musicNameImageBrown2xHard;
/**
 * @brief The default double-resolution brown-tinted artist-strip image.
 * @ghidraAddress 0x65404
 */
- (UIImage *)artistNameImageBrown2x;
/**
 * @brief The basic double-resolution brown-tinted artist-strip image.
 * @ghidraAddress 0x654fc
 */
- (UIImage *)artistNameImageBrown2xBasic;
/**
 * @brief The medium double-resolution brown-tinted artist-strip image.
 * @ghidraAddress 0x655f4
 */
- (UIImage *)artistNameImageBrown2xMedium;
/**
 * @brief The hard double-resolution brown-tinted artist-strip image.
 * @ghidraAddress 0x656ec
 */
- (UIImage *)artistNameImageBrown2xHard;

/**
 * @brief Tint @p image with @p color, preserving its alpha.
 * @param image The source image to tint.
 * @param color The tint colour.
 * @return The tinted image.
 * @ghidraAddress 0x657e4
 */
- (UIImage *)setColor:(UIImage *)image withColor:(UIColor *)color;

/**
 * @brief Decode and cache the default artwork image if it is not cached already.
 * @ghidraAddress 0x65964
 */
- (void)createCache;
/**
 * @brief Release the cached default artwork image. (The binary spells this @c releaseChache.)
 * @ghidraAddress 0x65b3c
 */
- (void)releaseChache;
/**
 * @brief Whether the default artwork image is currently cached.
 * @ghidraAddress 0x66308
 */
- (BOOL)isArtworkCache;

/**
 * @brief Order this tune against @p other by title reading, then by reading length.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65b4c
 */
- (NSComparisonResult)compare:(MusicData *)other;
/**
 * @brief Order this tune against @p other by tune identifier.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65c5c
 */
- (NSComparisonResult)compareMusicID:(MusicData *)other;
/**
 * @brief Order this tune against @p other by title sort key, then by sort-key length.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65ce0
 */
- (NSComparisonResult)compareMusicNameCustom:(MusicData *)other;
/**
 * @brief Order this tune against @p other by artist sort key, then by the title sort key.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65df4
 */
- (NSComparisonResult)compareArtistNameCustom:(MusicData *)other;
/**
 * @brief Order this tune against @p other by title reading, then by reading length.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65eec
 */
- (NSComparisonResult)compareMusicNameHira:(MusicData *)other;
/**
 * @brief Order this tune against @p other by artist reading, then by the title reading.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x66000
 */
- (NSComparisonResult)compareArtistNameHira:(MusicData *)other;
/**
 * @brief Order this tune against @p other by basic level.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x660f8
 */
- (NSComparisonResult)compareDifficultyBasic:(MusicData *)other;
/**
 * @brief Order this tune against @p other by medium level.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x6617c
 */
- (NSComparisonResult)compareDifficultyMedium:(MusicData *)other;
/**
 * @brief Order this tune against @p other by hard level.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x66200
 */
- (NSComparisonResult)compareDifficultyHard:(MusicData *)other;
/**
 * @brief Order this tune against @p other by special level.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x66284
 */
- (NSComparisonResult)compareDifficultySpecial:(MusicData *)other;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
