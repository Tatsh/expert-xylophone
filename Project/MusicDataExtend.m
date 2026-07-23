//
//  MusicDataExtend.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class MusicDataExtend). Verified against
//  the arm64 disassembly: the object setters call the runtime's storeStrong helper (a retaining
//  store), and the extend dictionary keys were read straight from the __cfstring references.
//

#import "MusicDataExtend.h"

#import "MusicData.h"

// Purchased-extend-note dictionary keys read by the factory.
static NSString *const kExtendKeyExtMusicID = @"ExtID";
static NSString *const kExtendKeyMusicID = @"ID";
static NSString *const kExtendKeyDifficulty = @"ExtLevel";
static NSString *const kExtendKeyComment = @"Comment";

@implementation MusicDataExtend

#pragma mark - Loading

+ (instancetype)dataWithPath:(NSString *)path dictionary:(NSDictionary *)dictionary {
    /** @ghidraAddress 0x5a230 */
    MusicDataExtend *data = [[MusicDataExtend alloc] init];
    data.ExtMusicID = [dictionary[kExtendKeyExtMusicID] intValue];
    data.MusicID = [dictionary[kExtendKeyMusicID] intValue];
    data.difficulty = [dictionary[kExtendKeyDifficulty] intValue];
    data.comment = dictionary[kExtendKeyComment];
    data.dataPath = path;
    return data;
}

#pragma mark - Special note sheets

- (NSMutableData *)sheetSpecial {
    /** @ghidraAddress 0x5a428 */
    MusicData *extend = [MusicData dataWithPath:self.dataPath ID:self.ExtMusicID];
    if (extend == nil) {
        return nil;
    }
    return [extend sheetBasic];
}

- (NSMutableData *)sheetSpecialLight {
    /** @ghidraAddress 0x5a4fc */
    MusicData *extend = [MusicData dataWithPath:self.dataPath ID:self.ExtMusicID];
    if (extend == nil) {
        return nil;
    }
    return [extend sheetBasicLight];
}

#pragma mark - Unused archive hooks

- (void)setExtendSheetWithPath:(NSString *)extendSheetWithPath ID:(int)musicID {
    /** @ghidraAddress 0x5a22c */
}

- (NSMutableData *)getExtendZipData:(NSString *)entryName
                               Path:(NSString *)zipPath
                         DecodeType:(int)decodeType {
    /** @ghidraAddress 0x5a5d0 */
    return nil;
}

@end
