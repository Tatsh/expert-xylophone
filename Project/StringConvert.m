//
//  StringConvert.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class StringConvert). Verified against
//  the arm64 disassembly (the katakana literals are CFString constants that the decompiler renders
//  as unprintable placeholders, so their code points were read from the binary).
//

#import "StringConvert.h"

/// Prolonged-sound mark (U+30FC, @c ー): when it follows a character it is replaced by that
/// character's vowel rather than kept verbatim.
static NSString *const kProlongedSoundMark = @"ー";

/// Regular-expression pattern that matches a single character in the full katakana range
/// @c [ァ-ン]; only matching characters are folded and appended to the reading key.
static NSString *const kKatakanaRangePattern = @"[ァ-ン]";

/// Format used to materialise a plain copy of the accumulator on the empty-result path.
static NSString *const kIdentityFormat = @"%@";

/// Number of table lookups to skip at the start of the walk: the first character has no predecessor,
/// so the prolonged-sound-mark resolution only applies from the second character onward.
static const NSInteger kNoPreviousIndex = -1;

/// The macron-to-vowel katakana lookup table (89 entries), seeded at startup.
/// Ghidra: g_pMacronToVowelTable @ 0x3dc258.
extern NSDictionary *const g_pMacronToVowelTable;

/// The small-kana-to-large-kana lookup table (11 entries), seeded at startup.
/// Ghidra: g_pLowerToUpperTable @ 0x3dc260.
extern NSDictionary *const g_pLowerToUpperTable;

/// The voiced-kana-to-voiceless-kana lookup table (25 entries), seeded at startup.
/// Ghidra: g_pVoiceToVoicelessTable @ 0x3dc268.
extern NSDictionary *const g_pVoiceToVoicelessTable;

@implementation StringConvert

+ (NSString *)convertYomigana:(NSString *)string {
    if (!string || string.length == 0) {
        return string;
    }
    NSString *folded = [StringConvert stringTransform:string
                                        withTransform:(__bridge NSString *)
                                                          kCFStringTransformFullwidthHalfwidth
                                              reverse:YES];
    folded = [StringConvert convertFromVToB:[folded copy]];
    folded = [StringConvert convertDJ:folded];
    folded = [StringConvert convertKorsk:folded];
    NSMutableString *result = [[NSMutableString alloc] init];
    NSRegularExpression *katakana =
        [NSRegularExpression regularExpressionWithPattern:kKatakanaRangePattern options:0 error:nil];
    NSInteger index = kNoPreviousIndex;
    while (index + 1 < (NSInteger)folded.length) {
        NSString *character = [folded substringWithRange:NSMakeRange(index + 1, 1)];
        if (!character) {
            break;
        }
        BOOL isProlongedSoundMark = [character isEqualToString:kProlongedSoundMark];
        if (index != kNoPreviousIndex && isProlongedSoundMark) {
            NSString *previous = [folded substringWithRange:NSMakeRange(index, 1)];
            character = [StringConvert convertFromMacronToVowel:previous];
        }
        if ([katakana numberOfMatchesInString:character
                                      options:0
                                        range:NSMakeRange(0, character.length)] != 0) {
            character = [StringConvert convertFromLowerToUpper:character];
            character = [StringConvert convertFromVoiceToVoiceless:character];
            [result appendString:character];
        }
        ++index;
    }
    if (result.length == 0) {
        return [NSString stringWithFormat:kIdentityFormat, result];
    }
    return result;
}

+ (NSString *)convertFromVToB:(NSString *)string {
    if (!string || string.length == 0) {
        return string;
    }
    string = [string stringByReplacingOccurrencesOfString:@"ヴァ" withString:@"バ"];
    string = [string stringByReplacingOccurrencesOfString:@"ヴィ" withString:@"ビ"];
    string = [string stringByReplacingOccurrencesOfString:@"ヴ" withString:@"ブ"];
    string = [string stringByReplacingOccurrencesOfString:@"ヴェ" withString:@"ベ"];
    string = [string stringByReplacingOccurrencesOfString:@"ヴォ" withString:@"ボ"];
    return string;
}

+ (NSString *)convertDJ:(NSString *)string {
    if (!string || string.length == 0) {
        return string;
    }
    string = [string stringByReplacingOccurrencesOfString:@"ディージェー" withString:@"ディイジエイ"];
    string = [string stringByReplacingOccurrencesOfString:@"ディージェイ" withString:@"ディイジエイ"];
    return string;
}

+ (NSString *)convertKorsk:(NSString *)string {
    if (!string || string.length == 0) {
        return string;
    }
    return [string stringByReplacingOccurrencesOfString:@"コースケ" withString:@"コウスケ"];
}

+ (NSString *)convertFromMacronToVowel:(NSString *)string {
    if (!string || string.length == 0 || ![g_pMacronToVowelTable objectForKey:string]) {
        return string;
    }
    return [g_pMacronToVowelTable objectForKey:string];
}

+ (NSString *)convertFromLowerToUpper:(NSString *)string {
    if (!string || string.length == 0 || ![g_pLowerToUpperTable objectForKey:string]) {
        return string;
    }
    return [g_pLowerToUpperTable objectForKey:string];
}

+ (NSString *)convertFromVoiceToVoiceless:(NSString *)string {
    if (!string || string.length == 0 || ![g_pVoiceToVoicelessTable objectForKey:string]) {
        return string;
    }
    return [g_pVoiceToVoicelessTable objectForKey:string];
}

+ (NSString *)stringTransform:(NSString *)string
                withTransform:(NSString *)transform
                      reverse:(BOOL)reverse {
    NSMutableString *copy = [[NSMutableString alloc] initWithString:string];
    CFStringTransform((__bridge CFMutableStringRef)copy, NULL, (__bridge CFStringRef)transform,
                      reverse);
    return copy;
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
