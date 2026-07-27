//
//  leveltables.mm
//  REFLEC BEAT plus
//
//  The level-threshold tables manager (LevelTables) and the player-level table helpers.
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to the
//  program image base.
//

#include "leveltables.h"

#include <cstring>

#import <Foundation/Foundation.h>

#import "NSFileManager+RB.h"
#include "deviceenvironment.h"
#include "enginecrypto.h"

// The level-tables manager singleton.
static LevelTables *g_pLevelTables = nullptr; // @ghidraAddress 0x3df548

// The packed {category, item} unlock table: the unlock level of each entry is its one-based position
// in the table. Read-only ROM data in the binary.
constexpr int kUnlockCtorCount = 30;
constexpr int kUnlockMaxIndex = 30;
extern const LevelUnlockEntry g_aLevelUnlockTable[kUnlockMaxIndex + 1]; // @ghidraAddress 0x31066c

// The cumulative experience threshold for each level. Read-only ROM data in the binary.
constexpr int kExpTableMaxLevel = 30;
extern const unsigned int g_aLevelExpThreshold[kExpTableMaxLevel + 1]; // @ghidraAddress 0x3cf7e8

// The per-level experience-gain step table. Read-only ROM data in the binary.
constexpr int kStepTableMaxLevel = 9;
extern const int g_aLevelExpStep[kStepTableMaxLevel + 1]; // @ghidraAddress 0x310764

namespace {

// The number of items in each unlock category (@ghidraAddress 0x310658).
constexpr int kCategoryItemCounts[LevelTables::kCategoryCount] = {36, 33, 19, 31, 28};

// The half-step bias and the fixed base offset ComputeLevelExpStep applies.
constexpr float kHalfStep = 0.5f;
constexpr float kBaseOffset = 250.0f; // @ghidraAddress 0x301f88

// The hash record's fixed fields: a two-byte tag and the two salt blobs the record interleaves with
// the level and experience values (@ghidraAddress 0x3415c7 and 0x3415da).
constexpr unsigned short kHashTag = 0xab81;
constexpr unsigned char kHashSaltHead[] = {
    0xe6, 0x83, 0x85, 0xe5, 0xa0, 0xb1, 0xe3, 0x81, 0xae, 0xe5, 0x8f, 0x96, 0xe5, 0xbe, 0x97, 0xe3};
constexpr unsigned char kHashSaltTail[] = {0xe5, 0xa4, 0xb1, 0xe6, 0x95, 0x97, 0xe3,
                                           0x81, 0x97, 0xe3, 0x81, 0xbe, 0xe3, 0x81,
                                           0x97, 0xe3, 0x81, 0x9f, 0xe3, 0x80, 0x82};

// The persisted level record's plist keys and file name.
static NSString *const kLevelKey = @"level";
static NSString *const kExpKey = @"exp";
static NSString *const kCustomizeKey = @"customize";
static NSString *const kLevelListFileName = @"lelist";

} // namespace

/** @ghidraAddress 0x1cbe04 */
LevelTables::LevelTables() {
    m_nCurrentLevel = 0;

    // Allocate one unlock-level array per category, sized by the category's item count.
    for (int nCategory = 0; nCategory < kCategoryCount; ++nCategory) {
        m_apUnlockLevels[nCategory] = new int[kCategoryItemCounts[nCategory]]();
    }

    // Seed each listed item's unlock level from the packed unlock table: the entry's one-based
    // position is the level at which its {category, item} unlocks.
    for (int nEntry = 0; nEntry < kUnlockCtorCount; ++nEntry) {
        const LevelUnlockEntry &entry = g_aLevelUnlockTable[nEntry];
        m_apUnlockLevels[entry.nCategory][entry.nItem] = nEntry + 1;
    }
}

/** @ghidraAddress 0x1cbec8 */
LevelTables *LevelTables::GetInstance() {
    if (g_pLevelTables == nullptr) {
        g_pLevelTables = new LevelTables();
    }
    return g_pLevelTables;
}

/** @ghidraAddress 0x1cc460 */
bool LevelTables::CheckThresholdReached(int category, int itemID) {
    // Clamp the item index into the category array's bounds.
    const int nItemCount = kCategoryItemCounts[category];
    int nIndex = itemID < nItemCount ? itemID : nItemCount;
    if (nIndex < 0) {
        nIndex = 0;
    }
    return m_nCurrentLevel >= m_apUnlockLevels[category][nIndex];
}

/** @ghidraAddress 0x1cc410 */
unsigned int GetLevelExpThreshold(void *pUnused, int nLevel) {
    (void)pUnused; // The binary passes a level-tables pointer here but never reads it.
    int nIndex = nLevel;
    if (nIndex > kExpTableMaxLevel) {
        nIndex = kExpTableMaxLevel;
    }
    if (nIndex < 0) {
        nIndex = 0;
    }
    return g_aLevelExpThreshold[nIndex];
}

/** @ghidraAddress 0x1cc438 */
const LevelUnlockEntry *GetLevelUnlockEntry(int nLevel) {
    int nIndex = nLevel;
    if (nIndex > kUnlockMaxIndex) {
        nIndex = kUnlockMaxIndex;
    }
    if (nIndex < 0) {
        nIndex = 0;
    }
    return &g_aLevelUnlockTable[nIndex];
}

/** @ghidraAddress 0x1cc3b4 */
int ComputeLevelExpStep(float flBase, void *pUnused, int nStep, int bAddHalf, int bAddOffset) {
    (void)pUnused; // The binary passes a level-tables pointer here but never reads it.
    int nIndex = nStep;
    if (nIndex > kStepTableMaxLevel) {
        nIndex = kStepTableMaxLevel;
    }
    if (nIndex < 0) {
        nIndex = 0;
    }
    const float flStep = static_cast<float>(g_aLevelExpStep[nIndex]);
    float flValue = (flBase + (bAddHalf != 0 ? kHalfStep : 0.0f)) * flStep;
    if (bAddOffset != 0) {
        flValue += kBaseOffset;
    }
    return static_cast<int>(flValue);
}

/** @ghidraAddress 0x1cc138 */
NSData *MakeLevelCustomizeHash(int nLevel, int nExp) {
    // Build the fifty-six-byte record the hash covers: the head salt, a tag, the combined and
    // product values, the level and experience, and the tail salt, terminated by a null byte.
    unsigned char aRecord[0x38] = {};
    std::memcpy(&aRecord[0x00], kHashSaltHead, sizeof(kHashSaltHead));
    const unsigned short nTag = kHashTag;
    std::memcpy(&aRecord[0x10], &nTag, sizeof(nTag));
    const int nSum = nLevel + nExp;
    const int nProduct = nLevel * nExp;
    std::memcpy(&aRecord[0x12], &nSum, sizeof(nSum));
    std::memcpy(&aRecord[0x16], &nProduct, sizeof(nProduct));
    std::memcpy(&aRecord[0x1a], &nLevel, sizeof(nLevel));
    std::memcpy(&aRecord[0x1e], &nExp, sizeof(nExp));
    std::memcpy(&aRecord[0x22], kHashSaltTail, sizeof(kHashSaltTail));
    aRecord[0x37] = 0;
    return Md5StringToData(reinterpret_cast<const char *>(aRecord));
}

/** @ghidraAddress 0x1cbf18 */
bool LoadPlayerLevelData(int *pOutLevelExp) {
    NSString *directory = GetApplicationSupportPath();
    NSString *path = [directory stringByAppendingPathComponent:kLevelListFileName];

    if ([NSFileManager isFileExist:path]) {
        NSDictionary *record = [NSDictionary dictionaryWithContentsOfFile:path];
        const int nLevel = [[record objectForKey:kLevelKey] intValue];
        const int nExp = [[record objectForKey:kExpKey] intValue];
        NSData *storedHash = [record objectForKey:kCustomizeKey];

        // Accept the stored values only when their re-computed hash matches the stored one.
        if ([storedHash isEqualToData:MakeLevelCustomizeHash(nLevel, nExp)]) {
            pOutLevelExp[0] = nLevel;
            pOutLevelExp[1] = nExp;
            return true;
        }
    }

    pOutLevelExp[0] = 0;
    return true;
}
