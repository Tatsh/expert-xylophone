/** @file
 * Katakana normalisation helpers used to build a searchable reading (yomigana) key from a song's
 * katakana title. The transforms fold full-width and half-width forms together, expand the
 * @c ヴ (vu) digraphs, spell out a couple of loanword readings, collapse the prolonged-sound mark,
 * and map small kana and voiced kana onto their large and voiceless base forms so that titles with
 * cosmetic kana variations sort and match consistently.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class StringConvert, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief Katakana reading normalisation helpers.
 */
@interface StringConvert : NSObject

/**
 * @brief Build a normalised katakana reading key from an arbitrary katakana string.
 *
 * Folds full-width and half-width forms together, applies the @c ヴ, DJ, and Korsk spelling
 * rewrites, then walks the string character by character: prolonged-sound marks are resolved
 * against the preceding character via @c convertFromMacronToVowel:, and every character in the
 * @c [ァ-ン] katakana range is mapped to its large voiceless base form before being appended to
 * the result.
 * @param string The katakana string to normalise.
 * @return The normalised reading key, or an empty string when nothing normalisable remained;
 * returns @p string unchanged when it is @c nil or empty.
 * @ghidraAddress 0x2a190
 */
+ (NSString *)convertYomigana:(NSString *)string;

/**
 * @brief Expand the @c ヴ (vu) katakana digraphs into their @c バ-row equivalents.
 * @param string The katakana string to rewrite.
 * @return @p string with @c ヴァ→バ, @c ヴィ→ビ, @c ヴ→ブ, @c ヴェ→ベ, and @c ヴォ→ボ applied;
 * returns @p string unchanged when it is @c nil or empty.
 * @ghidraAddress 0x2a640
 */
+ (NSString *)convertFromVToB:(NSString *)string;

/**
 * @brief Spell out the "DJ" loanword reading in katakana.
 * @param string The katakana string to rewrite.
 * @return @p string with @c ディージェー and @c ディージェイ rewritten to @c ディイジエイ; returns
 * @p string unchanged when it is @c nil or empty.
 * @ghidraAddress 0x2a7b4
 */
+ (NSString *)convertDJ:(NSString *)string;

/**
 * @brief Spell out the "Korsk" loanword reading in katakana.
 * @param string The katakana string to rewrite.
 * @return @p string with @c コースケ rewritten to @c コウスケ; returns @p string unchanged when it
 * is @c nil or empty.
 * @ghidraAddress 0x2a88c
 */
+ (NSString *)convertKorsk:(NSString *)string;

/**
 * @brief Resolve a prolonged-sound mark to the vowel of its preceding character.
 * @param string A single-character string looked up in the macron-to-vowel table.
 * @return The mapped vowel character, or @p string unchanged when it is @c nil, empty, or has no
 * table entry.
 * @ghidraAddress 0x2a92c
 */
+ (NSString *)convertFromMacronToVowel:(NSString *)string;

/**
 * @brief Map a small katakana character onto its large base form.
 * @param string A single-character string looked up in the small-to-large kana table.
 * @return The mapped large character, or @p string unchanged when it is @c nil, empty, or has no
 * table entry.
 * @ghidraAddress 0x2a9e8
 */
+ (NSString *)convertFromLowerToUpper:(NSString *)string;

/**
 * @brief Map a voiced katakana character onto its voiceless base form.
 * @param string A single-character string looked up in the voiced-to-voiceless kana table.
 * @return The mapped voiceless character, or @p string unchanged when it is @c nil, empty, or has
 * no table entry.
 * @ghidraAddress 0x2aaa4
 */
+ (NSString *)convertFromVoiceToVoiceless:(NSString *)string;

/**
 * @brief Apply a Core Foundation string transform to a mutable copy of a string.
 * @param string The source string; a mutable copy is transformed in place.
 * @param transform A @c CFStringTransform identifier (for example
 * @c kCFStringTransformFullwidthHalfwidth).
 * @param reverse Whether to apply the transform in reverse.
 * @return A new string holding the transformed copy.
 * @ghidraAddress 0x2ab60
 */
+ (NSString *)stringTransform:(NSString *)string
                withTransform:(NSString *)transform
                      reverse:(BOOL)reverse;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
