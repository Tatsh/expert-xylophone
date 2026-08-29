/**
 * @file
 * The catalogue entry for a single tune.
 *
 * A @c MusicData instance carries the tune identifier, its
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
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class MusicDataExtend;
@class UIColor;
@class UIImage;

NS_ASSUME_NONNULL_BEGIN

/**
 * A catalogue entry describing one tune and vending its packaged assets.
 */
@interface MusicData : NSObject

/**
 * The tune identifier.
 * @ghidraAddress 0x66344 (getter)
 * @ghidraAddress 0x66354 (setter)
 */
@property(nonatomic, assign) int MusicID;
/**
 * The basic-chart level.
 * @ghidraAddress 0x66364 (getter)
 * @ghidraAddress 0x66374 (setter)
 */
@property(nonatomic, assign) int difficultyBasic;
/**
 * The medium-chart level.
 * @ghidraAddress 0x66384 (getter)
 * @ghidraAddress 0x66394 (setter)
 */
@property(nonatomic, assign) int difficultyMedium;
/**
 * The hard-chart level.
 * @ghidraAddress 0x663a4 (getter)
 * @ghidraAddress 0x663b4 (setter)
 */
@property(nonatomic, assign) int difficultyHard;
/**
 * The special-chart level.
 * @ghidraAddress 0x663c4 (getter)
 * @ghidraAddress 0x663d4 (setter)
 */
@property(nonatomic, assign) int difficultySpecial;
/**
 * The minimum tempo in BPM.
 * @ghidraAddress 0x663e4 (getter)
 * @ghidraAddress 0x663f4 (setter)
 */
@property(nonatomic, assign) int bpm_MIN;
/**
 * The maximum tempo in BPM.
 * @ghidraAddress 0x66404 (getter)
 * @ghidraAddress 0x66414 (setter)
 */
@property(nonatomic, assign) int bpm_MAX;

/**
 * The display title.
 * @ghidraAddress 0x66424 (getter)
 * @ghidraAddress 0x66434 (setter)
 */
@property(nonatomic, strong) NSString *musicName;
/**
 * The hiragana reading of the title.
 * @ghidraAddress 0x6646c (getter)
 * @ghidraAddress 0x6647c (setter)
 */
@property(nonatomic, strong, nullable) NSString *musicNameHira;
/**
 * The romanised title.
 * @ghidraAddress 0x664b4 (getter)
 * @ghidraAddress 0x664c4 (setter)
 */
@property(nonatomic, strong, nullable) NSString *musicNameRoman;
/**
 * The artist name.
 * @ghidraAddress 0x664fc (getter)
 * @ghidraAddress 0x6650c (setter)
 */
@property(nonatomic, strong, nullable) NSString *artistName;
/**
 * The hiragana reading of the artist name.
 * @ghidraAddress 0x66544 (getter)
 * @ghidraAddress 0x66554 (setter)
 */
@property(nonatomic, strong, nullable) NSString *artistNameHira;
/**
 * The romanised artist name.
 * @ghidraAddress 0x6658c (getter)
 * @ghidraAddress 0x6659c (setter)
 */
@property(nonatomic, strong, nullable) NSString *artistNameRoman;
/**
 * The sort key derived from the title reading.
 * @ghidraAddress 0x665d4 (getter)
 * @ghidraAddress 0x665e4 (setter)
 */
@property(nonatomic, strong) NSString *musicSortName;
/**
 * The sort key derived from the artist reading.
 * @ghidraAddress 0x6661c (getter)
 * @ghidraAddress 0x6662c (setter)
 */
@property(nonatomic, strong) NSString *artistSortName;
/**
 * The single-character index initial derived from the title sort key.
 * @ghidraAddress 0x66664 (getter)
 * @ghidraAddress 0x66674 (setter)
 */
@property(nonatomic, strong) NSString *musicNameInitial;
/**
 * The single-character index initial derived from the artist sort key.
 * @ghidraAddress 0x666ac (getter)
 * @ghidraAddress 0x666bc (setter)
 */
@property(nonatomic, strong) NSString *artistNameInitial;
/**
 * The optional per-tune settings read from the archive metadata's @c Options entry.
 * @ghidraAddress 0x666f4 (getter)
 * @ghidraAddress 0x66704 (setter)
 */
@property(nonatomic, strong, nullable) NSDictionary *optionalDataDict;
/**
 * The extend (special) note data owner, held without ownership.
 * @ghidraAddress 0x6673c (getter)
 * @ghidraAddress 0x6674c (setter)
 */
@property(nonatomic, assign, nullable) MusicDataExtend *spData;
/**
 * The extend audio archive entry loaded for the special chart.
 * @ghidraAddress 0x6675c (getter)
 * @ghidraAddress 0x6676c (setter)
 */
@property(nonatomic, strong, nullable) MusicData *ExtMusicData;
/**
 * The cached decoded default artwork image.
 * @ghidraAddress 0x667a4 (getter)
 * @ghidraAddress 0x667b4 (setter)
 */
@property(strong, nullable) UIImage *artworkCache;
/**
 * The cached decoded basic-chart artwork image.
 * @ghidraAddress 0x667c0 (getter)
 * @ghidraAddress 0x667d0 (setter)
 */
@property(strong, nullable) UIImage *artworkCacheBasic;
/**
 * The cached decoded medium-chart artwork image.
 * @ghidraAddress 0x667dc (getter)
 * @ghidraAddress 0x667ec (setter)
 */
@property(strong, nullable) UIImage *artworkCacheMedium;
/**
 * The cached decoded hard-chart artwork image.
 * @ghidraAddress 0x667f8 (getter)
 * @ghidraAddress 0x66808 (setter)
 */
@property(strong, nullable) UIImage *artworkCacheHard;
/**
 * The path of the packaged archive backing this tune.
 * @ghidraAddress 0x66814 (getter)
 * @ghidraAddress 0x66824 (setter)
 */
@property(nonatomic, strong) NSString *filePath;
/**
 * The decode-type index selecting the archive decryption key.
 * @ghidraAddress 0x6685c (getter)
 * @ghidraAddress 0x6686c (setter)
 */
@property(nonatomic, assign) int decodeType;

/**
 * Load and assemble the catalogue entry for the tune archived at @p path.
 * @param path The packaged archive path.
 * @param musicID The expected tune identifier; the archive must declare the same value.
 * @return A fully populated instance, or @c nil if the archive is missing, undecryptable, or
 *         declares a mismatched identifier or an out-of-range level.
 * @ghidraAddress 0x5ee64
 */
+ (nullable instancetype)dataWithPath:(NSString *)path ID:(int)musicID;

/**
 * Decrypt @p data in place with a Blowfish key derived from @p key.
 * @param data The archive member to decrypt in place.
 * @param key The per-decode-type key bytes.
 * @param keyLength The number of key bytes.
 * @return @p data on success, or @c nil if deciphering fails.
 * @ghidraAddress 0x5eb78
 */
+ (nullable NSMutableData *)decodeBF:(NSMutableData *)data
                                 Key:(const char *)key
                           KeyLength:(int)keyLength;

/**
 * Open the backing archive, read the named member, and decrypt it.
 * @param entryName The archive member name.
 * @param zipPath The archive path.
 * @param decodeType The decode-type index selecting the decryption key.
 * @return The decrypted member data, or @c nil.
 * @ghidraAddress 0x5ecd4
 */
+ (nullable NSMutableData *)getZipData:(NSString *)entryName
                                  Path:(NSString *)zipPath
                            DecodeType:(int)decodeType;

/**
 * Read the named member from the backing archive using the instance's path and decode type.
 * @param entryName The archive member name.
 * @return The decrypted member data, or @c nil.
 * @ghidraAddress 0x600cc
 */
- (nullable NSMutableData *)getZipData:(NSString *)entryName;

/**
 * Read a member preferring the tune's @c Options override, falling back to the base member.
 * @param entryName The archive member name.
 * @return The decrypted member data, or @c nil.
 * @ghidraAddress 0x60190
 */
- (nullable NSMutableData *)getOptionalZipData:(NSString *)entryName;

/**
 * Read a member preferring the tune's @c Options override, then @p defaultName.
 * @param entryName The primary archive member name.
 * @param defaultName The fallback archive member name, or @c nil.
 * @return The decrypted member data, or @c nil.
 * @ghidraAddress 0x601b8
 */
- (nullable NSMutableData *)getOptionalZipData:(NSString *)entryName
                               withDefaultName:(nullable NSString *)defaultName;

/**
 * The main audio archive member (@c bgm).
 * @return The decrypted audio data, or @c nil when the member is absent.
 * @ghidraAddress 0x602d8
 */
- (nullable NSMutableData *)music;
/**
 * The basic-chart audio member (@c bgm_b, falling back to @c bgm).
 * @return The decrypted audio data, or @c nil when the member is absent.
 * @ghidraAddress 0x602ec
 */
- (nullable NSMutableData *)musicBasic;
/**
 * The medium-chart audio member (@c bgm_m, falling back to @c bgm).
 * @return The decrypted audio data, or @c nil when the member is absent.
 * @ghidraAddress 0x60308
 */
- (nullable NSMutableData *)musicMedium;
/**
 * The hard-chart audio member (@c bgm_h, falling back to @c bgm).
 * @return The decrypted audio data, or @c nil when the member is absent.
 * @ghidraAddress 0x60324
 */
- (nullable NSMutableData *)musicHard;
/**
 * The preview audio member (@c pre).
 * @return The decrypted audio data, or @c nil when the member is absent.
 * @ghidraAddress 0x60340
 */
- (nullable NSMutableData *)musicPre;

/**
 * The basic note sheet (@c note_bas).
 * @return The decrypted note-sheet data, or @c nil when the member is absent.
 * @ghidraAddress 0x60354
 */
- (nullable NSMutableData *)sheetBasic;
/**
 * The basic-light note sheet (@c note_bas2, falling back to @c note_bas).
 * @return The decrypted note-sheet data, or @c nil when the member is absent.
 * @ghidraAddress 0x60368
 */
- (nullable NSMutableData *)sheetBasicLight;
/**
 * The medium note sheet (@c note_med).
 * @return The decrypted note-sheet data, or @c nil when the member is absent.
 * @ghidraAddress 0x60384
 */
- (nullable NSMutableData *)sheetMedium;
/**
 * The medium-light note sheet (@c note_med2, falling back to @c note_med).
 * @return The decrypted note-sheet data, or @c nil when the member is absent.
 * @ghidraAddress 0x60398
 */
- (nullable NSMutableData *)sheetMediumLight;
/**
 * The hard note sheet (@c note_har).
 * @return The decrypted note-sheet data, or @c nil when the member is absent.
 * @ghidraAddress 0x603b4
 */
- (nullable NSMutableData *)sheetHard;
/**
 * The hard-light note sheet (@c note_har2, falling back to @c note_har).
 * @return The decrypted note-sheet data, or @c nil when the member is absent.
 * @ghidraAddress 0x603c8
 */
- (nullable NSMutableData *)sheetHardLight;
/**
 * The special note sheet, sourced from the extend note data owner.
 * @return The decrypted note-sheet data, or @c nil when no extend note data is present.
 * @ghidraAddress 0x603e4
 */
- (nullable NSMutableData *)sheetSpecial;
/**
 * The special-light note sheet, sourced from the extend note data owner.
 * @return The decrypted note-sheet data, or @c nil when no extend note data is present.
 * @ghidraAddress 0x60484
 */
- (nullable NSMutableData *)sheetSpecialLight;

/**
 * The default artwork member (@c artwork).
 * @return The decrypted artwork data, or @c nil when the member is absent.
 * @ghidraAddress 0x60524
 */
- (nullable NSMutableData *)artworkData;
/**
 * The basic-chart artwork member (@c artwork_b).
 * @return The decrypted artwork data, or @c nil when the member is absent.
 * @ghidraAddress 0x60538
 */
- (nullable NSMutableData *)artworkDataBasic;
/**
 * The medium-chart artwork member (@c artwork_m).
 * @return The decrypted artwork data, or @c nil when the member is absent.
 * @ghidraAddress 0x6054c
 */
- (nullable NSMutableData *)artworkDataMedium;
/**
 * The hard-chart artwork member (@c artwork_h).
 * @return The decrypted artwork data, or @c nil when the member is absent.
 * @ghidraAddress 0x60560
 */
- (nullable NSMutableData *)artworkDataHard;

/**
 * The default white title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60574
 */
- (nullable NSMutableData *)musicNameImageWhiteData;
/**
 * The basic white title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60588
 */
- (nullable NSMutableData *)musicNameImageWhiteDataBasic;
/**
 * The medium white title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x6059c
 */
- (nullable NSMutableData *)musicNameImageWhiteDataMedium;
/**
 * The hard white title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x605b0
 */
- (nullable NSMutableData *)musicNameImageWhiteDataHard;
/**
 * The default white artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x605c4
 */
- (nullable NSMutableData *)artistNameImageWhiteData;
/**
 * The basic white artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x605d8
 */
- (nullable NSMutableData *)artistNameImageWhiteDataBasic;
/**
 * The medium white artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x605ec
 */
- (nullable NSMutableData *)artistNameImageWhiteDataMedium;
/**
 * The hard white artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60600
 */
- (nullable NSMutableData *)artistNameImageWhiteDataHard;
/**
 * The default black title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60614
 */
- (nullable NSMutableData *)musicNameImageBlackData;
/**
 * The basic black title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60628
 */
- (nullable NSMutableData *)musicNameImageBlackDataBasic;
/**
 * The medium black title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x6063c
 */
- (nullable NSMutableData *)musicNameImageBlackDataMedium;
/**
 * The hard black title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60650
 */
- (nullable NSMutableData *)musicNameImageBlackDataHard;
/**
 * The default black artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60664
 */
- (nullable NSMutableData *)artistNameImageBlackData;
/**
 * The basic black artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60678
 */
- (nullable NSMutableData *)artistNameImageBlackDataBasic;
/**
 * The medium black artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x6068c
 */
- (nullable NSMutableData *)artistNameImageBlackDataMedium;
/**
 * The hard black artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x606a0
 */
- (nullable NSMutableData *)artistNameImageBlackDataHard;

/**
 * The default artwork member at double resolution (@c artwork2x).
 * @return The decrypted artwork data, or @c nil when the member is absent.
 * @ghidraAddress 0x606b4
 */
- (nullable NSMutableData *)artwork2xData;
/**
 * The basic double-resolution artwork member.
 * @return The decrypted artwork data, or @c nil when the member is absent.
 * @ghidraAddress 0x606c8
 */
- (nullable NSMutableData *)artwork2xDataBasic;
/**
 * The medium double-resolution artwork member.
 * @return The decrypted artwork data, or @c nil when the member is absent.
 * @ghidraAddress 0x606dc
 */
- (nullable NSMutableData *)artwork2xDataMedium;
/**
 * The hard double-resolution artwork member.
 * @return The decrypted artwork data, or @c nil when the member is absent.
 * @ghidraAddress 0x606f0
 */
- (nullable NSMutableData *)artwork2xDataHard;
/**
 * The default double-resolution white title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60704
 */
- (nullable NSMutableData *)musicNameImageWhite2xData;
/**
 * The basic double-resolution white title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60718
 */
- (nullable NSMutableData *)musicNameImageWhite2xDataBasic;
/**
 * The medium double-resolution white title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x6072c
 */
- (nullable NSMutableData *)musicNameImageWhite2xDataMedium;
/**
 * The hard double-resolution white title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60740
 */
- (nullable NSMutableData *)musicNameImageWhite2xDataHard;
/**
 * The default double-resolution white artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60754
 */
- (nullable NSMutableData *)artistNameImageWhite2xData;
/**
 * The basic double-resolution white artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60768
 */
- (nullable NSMutableData *)artistNameImageWhite2xDataBasic;
/**
 * The medium double-resolution white artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x6077c
 */
- (nullable NSMutableData *)artistNameImageWhite2xDataMedium;
/**
 * The hard double-resolution white artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60790
 */
- (nullable NSMutableData *)artistNameImageWhite2xDataHard;
/**
 * The default double-resolution black title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x607a4
 */
- (nullable NSMutableData *)musicNameImageBlack2xData;
/**
 * The basic double-resolution black title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x607b8
 */
- (nullable NSMutableData *)musicNameImageBlack2xDataBasic;
/**
 * The medium double-resolution black title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x607cc
 */
- (nullable NSMutableData *)musicNameImageBlack2xDataMedium;
/**
 * The hard double-resolution black title-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x607e0
 */
- (nullable NSMutableData *)musicNameImageBlack2xDataHard;
/**
 * The default double-resolution black artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x607f4
 */
- (nullable NSMutableData *)artistNameImageBlack2xData;
/**
 * The basic double-resolution black artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60808
 */
- (nullable NSMutableData *)artistNameImageBlack2xDataBasic;
/**
 * The medium double-resolution black artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x6081c
 */
- (nullable NSMutableData *)artistNameImageBlack2xDataMedium;
/**
 * The hard double-resolution black artist-strip member.
 * @return The decrypted strip data, or @c nil when the member is absent.
 * @ghidraAddress 0x60830
 */
- (nullable NSMutableData *)artistNameImageBlack2xDataHard;

/**
 * The default double-resolution brown-tinted title strip, PNG encoded.
 * @return The PNG-encoded strip data, or @c nil when the source strip is absent.
 * @ghidraAddress 0x60844
 */
- (nullable NSData *)musicNameImageBrown2xData;
/**
 * The basic double-resolution brown-tinted title strip, PNG encoded.
 * @return The PNG-encoded strip data, or @c nil when the source strip is absent.
 * @ghidraAddress 0x60988
 */
- (nullable NSData *)musicNameImageBrown2xDataBasic;
/**
 * The medium double-resolution brown-tinted title strip, PNG encoded.
 * @return The PNG-encoded strip data, or @c nil when the source strip is absent.
 * @ghidraAddress 0x60ad8
 */
- (nullable NSData *)musicNameImageBrown2xDataMedium;
/**
 * The hard double-resolution brown-tinted title strip, PNG encoded.
 * @return The PNG-encoded strip data, or @c nil when the source strip is absent.
 * @ghidraAddress 0x60c28
 */
- (nullable NSData *)musicNameImageBrown2xDataHard;
/**
 * The default double-resolution brown-tinted artist strip, PNG encoded.
 * @return The PNG-encoded strip data, or @c nil when the source strip is absent.
 * @ghidraAddress 0x60d78
 */
- (nullable NSData *)artistNameImageBrown2xData;
/**
 * The basic double-resolution brown-tinted artist strip, PNG encoded.
 * @return The PNG-encoded strip data, or @c nil when the source strip is absent.
 * @ghidraAddress 0x60ebc
 */
- (nullable NSData *)artistNameImageBrown2xDataBasic;
/**
 * The medium double-resolution brown-tinted artist strip, PNG encoded.
 * @return The PNG-encoded strip data, or @c nil when the source strip is absent.
 * @ghidraAddress 0x6100c
 */
- (nullable NSData *)artistNameImageBrown2xDataMedium;
/**
 * The hard double-resolution brown-tinted artist strip, PNG encoded.
 * @return The PNG-encoded strip data, or @c nil when the source strip is absent.
 * @ghidraAddress 0x6115c
 */
- (nullable NSData *)artistNameImageBrown2xDataHard;

/**
 * The default artwork image, decoded and cached.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x612ac
 */
- (nullable UIImage *)artwork;
/**
 * The basic artwork image, decoded and cached.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x61498
 */
- (nullable UIImage *)artworkBasic;
/**
 * The medium artwork image, decoded and cached.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x61684
 */
- (nullable UIImage *)artworkMedium;
/**
 * The hard artwork image, decoded and cached.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6188c
 */
- (nullable UIImage *)artworkHard;
/**
 * The default white title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x61a94
 */
- (nullable UIImage *)musicNameImageWhite;
/**
 * The basic white title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x61ba4
 */
- (nullable UIImage *)musicNameImageWhiteBasic;
/**
 * The medium white title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x61cb4
 */
- (nullable UIImage *)musicNameImageWhiteMedium;
/**
 * The hard white title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x61dc4
 */
- (nullable UIImage *)musicNameImageWhiteHard;
/**
 * The default white artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x61ed4
 */
- (nullable UIImage *)artistNameImageWhite;
/**
 * The basic white artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x61fe4
 */
- (nullable UIImage *)artistNameImageWhiteBasic;
/**
 * The medium white artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x620f4
 */
- (nullable UIImage *)artistNameImageWhiteMedium;
/**
 * The hard white artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x62204
 */
- (nullable UIImage *)artistNameImageWhiteHard;
/**
 * The default black title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x62314
 */
- (nullable UIImage *)musicNameImageBlack;
/**
 * The basic black title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x624a0
 */
- (nullable UIImage *)musicNameImageBlackBasic;
/**
 * The medium black title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x62638
 */
- (nullable UIImage *)musicNameImageBlackMedium;
/**
 * The hard black title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x627d0
 */
- (nullable UIImage *)musicNameImageBlackHard;
/**
 * The default black artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x62968
 */
- (nullable UIImage *)artistNameImageBlack;
/**
 * The basic black artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x62af4
 */
- (nullable UIImage *)artistNameImageBlackBasic;
/**
 * The medium black artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x62c8c
 */
- (nullable UIImage *)artistNameImageBlackMedium;
/**
 * The hard black artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x62e24
 */
- (nullable UIImage *)artistNameImageBlackHard;
/**
 * The default brown-tinted title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x62fbc
 */
- (nullable UIImage *)musicNameImageBrown;
/**
 * The basic brown-tinted title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x63154
 */
- (nullable UIImage *)musicNameImageBrownBasic;
/**
 * The medium brown-tinted title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x632f8
 */
- (nullable UIImage *)musicNameImageBrownMedium;
/**
 * The hard brown-tinted title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6349c
 */
- (nullable UIImage *)musicNameImageBrownHard;
/**
 * The default brown-tinted artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x63640
 */
- (nullable UIImage *)artistNameImageBrown;
/**
 * The basic brown-tinted artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x637d8
 */
- (nullable UIImage *)artistNameImageBrownBasic;
/**
 * The medium brown-tinted artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6397c
 */
- (nullable UIImage *)artistNameImageBrownMedium;
/**
 * The hard brown-tinted artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x63b20
 */
- (nullable UIImage *)artistNameImageBrownHard;

/**
 * The default double-resolution artwork image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x63cc4
 */
- (nullable UIImage *)artwork2x;
/**
 * The basic double-resolution artwork image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x63dbc
 */
- (nullable UIImage *)artwork2xBasic;
/**
 * The medium double-resolution artwork image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x63eb4
 */
- (nullable UIImage *)artwork2xMedium;
/**
 * The hard double-resolution artwork image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x63fac
 */
- (nullable UIImage *)artwork2xHard;
/**
 * The default double-resolution white title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x640a4
 */
- (nullable UIImage *)musicNameImageWhite2x;
/**
 * The basic double-resolution white title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6419c
 */
- (nullable UIImage *)musicNameImageWhite2xBasic;
/**
 * The medium double-resolution white title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64294
 */
- (nullable UIImage *)musicNameImageWhite2xMedium;
/**
 * The hard double-resolution white title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6438c
 */
- (nullable UIImage *)musicNameImageWhite2xHard;
/**
 * The default double-resolution white artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64484
 */
- (nullable UIImage *)artistNameImageWhite2x;
/**
 * The basic double-resolution white artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6457c
 */
- (nullable UIImage *)artistNameImageWhite2xBasic;
/**
 * The medium double-resolution white artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64674
 */
- (nullable UIImage *)artistNameImageWhite2xMedium;
/**
 * The hard double-resolution white artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6476c
 */
- (nullable UIImage *)artistNameImageWhite2xHard;
/**
 * The default double-resolution black title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64864
 */
- (nullable UIImage *)musicNameImageBlack2x;
/**
 * The basic double-resolution black title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6495c
 */
- (nullable UIImage *)musicNameImageBlack2xBasic;
/**
 * The medium double-resolution black title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64a54
 */
- (nullable UIImage *)musicNameImageBlack2xMedium;
/**
 * The hard double-resolution black title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64b4c
 */
- (nullable UIImage *)musicNameImageBlack2xHard;
/**
 * The default double-resolution black artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64c44
 */
- (nullable UIImage *)artistNameImageBlack2x;
/**
 * The basic double-resolution black artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64d3c
 */
- (nullable UIImage *)artistNameImageBlack2xBasic;
/**
 * The medium double-resolution black artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64e34
 */
- (nullable UIImage *)artistNameImageBlack2xMedium;
/**
 * The hard double-resolution black artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x64f2c
 */
- (nullable UIImage *)artistNameImageBlack2xHard;
/**
 * The default double-resolution brown-tinted title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x65024
 */
- (nullable UIImage *)musicNameImageBrown2x;
/**
 * The basic double-resolution brown-tinted title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6511c
 */
- (nullable UIImage *)musicNameImageBrown2xBasic;
/**
 * The medium double-resolution brown-tinted title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x65214
 */
- (nullable UIImage *)musicNameImageBrown2xMedium;
/**
 * The hard double-resolution brown-tinted title-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x6530c
 */
- (nullable UIImage *)musicNameImageBrown2xHard;
/**
 * The default double-resolution brown-tinted artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x65404
 */
- (nullable UIImage *)artistNameImageBrown2x;
/**
 * The basic double-resolution brown-tinted artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x654fc
 */
- (nullable UIImage *)artistNameImageBrown2xBasic;
/**
 * The medium double-resolution brown-tinted artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x655f4
 */
- (nullable UIImage *)artistNameImageBrown2xMedium;
/**
 * The hard double-resolution brown-tinted artist-strip image.
 * @return The decoded image, or @c nil when the source data is absent.
 * @ghidraAddress 0x656ec
 */
- (nullable UIImage *)artistNameImageBrown2xHard;

/**
 * Tint @p image with @p color, preserving its alpha.
 * @param image The source image to tint.
 * @param color The tint colour.
 * @return The tinted image.
 * @ghidraAddress 0x657e4
 */
- (nullable UIImage *)setColor:(UIImage *)image withColor:(UIColor *)color;

/**
 * Decode and cache the default artwork image if it is not cached already.
 * @ghidraAddress 0x65964
 */
- (void)createCache;
/**
 * Release the cached default artwork image. (The binary spells this @c releaseChache.)
 * @ghidraAddress 0x65b3c
 */
- (void)releaseChache;
/**
 * Whether the default artwork image is currently cached.
 * @return @c YES when a decoded artwork image is held, @c NO otherwise.
 * @ghidraAddress 0x66308
 */
- (BOOL)isArtworkCache;

/**
 * Order this tune against @p other by title reading, then by reading length.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65b4c
 */
- (NSComparisonResult)compare:(MusicData *)other;
/**
 * Order this tune against @p other by tune identifier.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65c5c
 */
- (NSComparisonResult)compareMusicID:(MusicData *)other;
/**
 * Order this tune against @p other by title sort key, then by sort-key length.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65ce0
 */
- (NSComparisonResult)compareMusicNameCustom:(MusicData *)other;
/**
 * Order this tune against @p other by artist sort key, then by the title sort key.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65df4
 */
- (NSComparisonResult)compareArtistNameCustom:(MusicData *)other;
/**
 * Order this tune against @p other by title reading, then by reading length.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x65eec
 */
- (NSComparisonResult)compareMusicNameHira:(MusicData *)other;
/**
 * Order this tune against @p other by artist reading, then by the title reading.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x66000
 */
- (NSComparisonResult)compareArtistNameHira:(MusicData *)other;
/**
 * Order this tune against @p other by basic level.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x660f8
 */
- (NSComparisonResult)compareDifficultyBasic:(MusicData *)other;
/**
 * Order this tune against @p other by medium level.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x6617c
 */
- (NSComparisonResult)compareDifficultyMedium:(MusicData *)other;
/**
 * Order this tune against @p other by hard level.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x66200
 */
- (NSComparisonResult)compareDifficultyHard:(MusicData *)other;
/**
 * Order this tune against @p other by special level.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult ordering the two tunes.
 * @ghidraAddress 0x66284
 */
- (NSComparisonResult)compareDifficultySpecial:(MusicData *)other;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
