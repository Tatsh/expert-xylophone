/** @file
 * The catalogue entry for a purchased extend (special) note pack. A @c MusicDataExtend instance
 * pairs a base tune identifier with the extend audio archive it draws its special chart from: it
 * records the base @c MusicID, the extend archive's own @c ExtMusicID, the special-chart level, an
 * optional comment, and the packaged archive path. Its @c sheetSpecial and @c sheetSpecialLight
 * accessors open that extend archive as an ordinary @c MusicData and vend its basic and
 * basic-light note sheets, which the base @c MusicData exposes through its @c spData reference as
 * the special chart.
 *
 * Instances are produced by @c RBExtendNoteManager from the purchased-extend-note dictionaries and
 * held in that manager's extend-note data array; @c MusicData receives one as its @c spData when a
 * tune has a matching extend pack.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class MusicDataExtend, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A catalogue entry pairing a base tune with a purchased extend (special) note pack.
 */
@interface MusicDataExtend : NSObject

/**
 * @brief The extend archive's own tune identifier, used to load its note sheets.
 * @ghidraAddress 0x5a624 (getter)
 * @ghidraAddress 0x5a634 (setter)
 */
@property(nonatomic, assign) int ExtMusicID;
/**
 * @brief The base tune identifier this extend pack augments.
 * @ghidraAddress 0x5a644 (getter)
 * @ghidraAddress 0x5a654 (setter)
 */
@property(nonatomic, assign) int MusicID;
/**
 * @brief The special-chart level.
 * @ghidraAddress 0x5a664 (getter)
 * @ghidraAddress 0x5a674 (setter)
 */
@property(nonatomic, assign) int difficulty;
/**
 * @brief The pack comment.
 * @ghidraAddress 0x5a684 (getter)
 * @ghidraAddress 0x5a694 (setter)
 */
@property(nonatomic, strong) NSString *comment;
/**
 * @brief The path of the packaged extend archive backing the special chart.
 * @ghidraAddress 0x5a6cc (getter)
 * @ghidraAddress 0x5a6dc (setter)
 */
@property(nonatomic, strong) NSString *dataPath;

/**
 * @brief Build an extend-pack entry from @p path and a purchased-extend-note dictionary.
 * @param path The packaged extend archive path.
 * @param dictionary The purchased-extend-note dictionary, providing the @c ExtID, @c ID,
 *        @c ExtLevel, and @c Comment entries.
 * @return A populated instance.
 * @ghidraAddress 0x5a230
 */
+ (instancetype)dataWithPath:(NSString *)path dictionary:(NSDictionary *)dictionary;

/**
 * @brief The special note sheet, read as the extend archive's basic note sheet.
 * @return The decrypted note-sheet data, or @c nil if the extend archive is missing.
 * @ghidraAddress 0x5a428
 */
- (nullable NSMutableData *)sheetSpecial;
/**
 * @brief The special-light note sheet, read as the extend archive's basic-light note sheet.
 * @return The decrypted note-sheet data, or @c nil if the extend archive is missing.
 * @ghidraAddress 0x5a4fc
 */
- (nullable NSMutableData *)sheetSpecialLight;

/**
 * @brief An unused hook that would set the extend note sheet directly; the binary leaves it empty.
 * @param extendSheetWithPath The extend sheet path (ignored).
 * @param musicID The extend tune identifier (ignored).
 * @ghidraAddress 0x5a22c
 */
- (void)setExtendSheetWithPath:(NSString *)extendSheetWithPath ID:(int)musicID;
/**
 * @brief An unused hook that would read a member from the extend archive; the binary returns
 *        @c nil.
 * @param entryName The archive member name (ignored).
 * @param zipPath The archive path (ignored).
 * @param decodeType The decode-type index (ignored).
 * @return @c nil.
 * @ghidraAddress 0x5a5d0
 */
- (nullable NSMutableData *)getExtendZipData:(NSString *)entryName
                                        Path:(NSString *)zipPath
                                  DecodeType:(int)decodeType;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
