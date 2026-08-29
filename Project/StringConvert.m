#import "StringConvert.h"

#import "engineglobals.h"

// Prolonged-sound mark, U+30FC.
static NSString *const kProlongedSoundMark = @"ー";

static NSString *const kKatakanaRangePattern = @"[ァ-ン]";

static NSString *const kIdentityFormat = @"%@";

static const NSInteger kNoPreviousIndex = -1;

@implementation StringConvert

+ (NSString *)convertYomigana:(NSString *)string {
    if (!string || string.length == 0) {
        return string;
    }
    NSString *folded =
        [StringConvert stringTransform:string
                         withTransform:(__bridge NSString *)kCFStringTransformFullwidthHalfwidth
                               reverse:YES];
    folded = [StringConvert convertFromVToB:[folded copy]];
    folded = [StringConvert convertDJ:folded];
    folded = [StringConvert convertKorsk:folded];
    NSMutableString *result = [[NSMutableString alloc] init];
    NSRegularExpression *katakana =
        [NSRegularExpression regularExpressionWithPattern:kKatakanaRangePattern
                                                  options:0
                                                    error:nil];
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
    // The binary formats its retained argument here, not the accumulator it failed to fill.
    if (result.length == 0) {
        return [NSString stringWithFormat:kIdentityFormat, string];
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
    string = [string stringByReplacingOccurrencesOfString:@"ディージェー"
                                               withString:@"デイイジエイ"];
    string = [string stringByReplacingOccurrencesOfString:@"ディージェイ"
                                               withString:@"デイイジエイ"];
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
                      reverse:(Boolean)reverse {
    NSMutableString *copy = [[NSMutableString alloc] initWithString:string];
    CFStringTransform(
        (__bridge CFMutableStringRef)copy, NULL, (__bridge CFStringRef)transform, reverse);
    return copy;
}

@end
