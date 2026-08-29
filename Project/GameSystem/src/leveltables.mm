#include "leveltables.h"

#include <climits>
#include <cstring>

#import <Foundation/Foundation.h>

#import "NSFileManager+RB.h"
#include "deviceenvironment.h"
#include "enginecrypto.h"

static LevelTables *g_pLevelTables = nullptr; // @ghidraAddress 0x3df548

// @ghidraAddress 0x31066c
constexpr int kUnlockCtorCount = 30;
constexpr int kUnlockMaxIndex = 30;
const LevelUnlockEntry g_aLevelUnlockTable[kUnlockMaxIndex + 1] = {
    {3, 1},  {1, 6}, {2, 2},  {0, 2}, {1, 11}, {4, 1}, {2, 9},  {3, 2},  {1, 17}, {2, 3}, {0, 3},
    {1, 21}, {4, 2}, {0, 6},  {3, 3}, {1, 7},  {2, 4}, {0, 4},  {1, 12}, {4, 3},  {3, 4}, {1, 18},
    {2, 5},  {0, 5}, {1, 22}, {4, 4}, {3, 5},  {4, 5}, {2, 10}, {3, 6},  {3, -1},
};

// @ghidraAddress 0x3cf7e8
constexpr int kExpTableMaxLevel = 30;
const unsigned int g_aLevelExpThreshold[kExpTableMaxLevel + 1] = {
    10u,    990u,   1100u,  1200u,  1300u,  1400u,  1500u,  2500u,  2700u,    2900u, 3100u,
    3300u,  3500u,  3700u,  5200u,  5600u,  6000u,  6400u,  6800u,  7200u,    9200u, 9800u,
    10400u, 11000u, 11600u, 12200u, 15200u, 18200u, 25500u, 35500u, UINT_MAX,
};

// @ghidraAddress 0x310764
constexpr int kStepTableMaxLevel = 9;
const int g_aLevelExpStep[kStepTableMaxLevel + 1] = {
    400,
    420,
    440,
    465,
    495,
    530,
    570,
    610,
    655,
    700,
};

namespace {

// @ghidraAddress 0x310658
constexpr int kCategoryItemCounts[LevelTables::kCategoryCount] = {36, 33, 19, 31, 28};

constexpr float kHalfStep = 0.5f;
constexpr float kBaseOffset = 250.0f; // @ghidraAddress 0x301f88

// The two salt blobs (@ghidraAddress 0x3415c7 and 0x3415da).
constexpr unsigned short kHashTag = 0xab81;
constexpr unsigned char kHashSaltHead[] = {
    0xe6, 0x83, 0x85, 0xe5, 0xa0, 0xb1, 0xe3, 0x81, 0xae, 0xe5, 0x8f, 0x96, 0xe5, 0xbe, 0x97, 0xe3};
constexpr unsigned char kHashSaltTail[] = {0xe5, 0xa4, 0xb1, 0xe6, 0x95, 0x97, 0xe3,
                                           0x81, 0x97, 0xe3, 0x81, 0xbe, 0xe3, 0x81,
                                           0x97, 0xe3, 0x81, 0x9f, 0xe3, 0x80, 0x82};

static NSString *const kLevelKey = @"level";
static NSString *const kExpKey = @"exp";
static NSString *const kCustomizeKey = @"customize";
static NSString *const kLevelListFileName = @"lelist";

} // namespace

/** @ghidraAddress 0x1cbe04 */
LevelTables::LevelTables() {
    m_nCurrentLevel = 0;

    for (int nCategory = 0; nCategory < kCategoryCount; ++nCategory) {
        m_apUnlockLevels[nCategory] = new int[kCategoryItemCounts[nCategory]]();
    }

    // An entry's one-based position in the table is the level at which its item unlocks.
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
    const int nItemCount = kCategoryItemCounts[category];
    int nIndex = itemID < nItemCount ? itemID : nItemCount;
    if (nIndex < 0) {
        nIndex = 0;
    }
    return m_nCurrentLevel >= m_apUnlockLevels[category][nIndex];
}

/** @ghidraAddress 0x1cc410 */
unsigned int LevelTables::GetLevelExpThreshold(int nLevel) {
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
const LevelUnlockEntry *LevelTables::GetLevelUnlockEntry(int nLevel) {
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
int LevelTables::ComputeLevelExpStep(float flBase, int nStep, int bAddHalf, int bAddOffset) {
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
NSData *LevelTables::MakeLevelCustomizeHash(int nLevel, int nExp) {
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
    // Hash the assembled byte record as a C string (the MD5 helper takes const char *).
    return Md5StringToData(reinterpret_cast<const char *>(aRecord));
}

/** @ghidraAddress 0x1cbf18 */
bool LevelTables::LoadPlayerLevelData(int *pOutLevelExp) {
    NSString *directory = GetDocumentsDirectoryPath();
    NSString *path = [directory stringByAppendingPathComponent:kLevelListFileName];

    if ([NSFileManager isFileExist:path]) {
        NSDictionary *record = [NSDictionary dictionaryWithContentsOfFile:path];
        const int nLevel = [[record objectForKey:kLevelKey] intValue];
        const int nExp = [[record objectForKey:kExpKey] intValue];
        NSData *storedHash = [record objectForKey:kCustomizeKey];

        if ([storedHash isEqualToData:MakeLevelCustomizeHash(nLevel, nExp)]) {
            pOutLevelExp[0] = nLevel;
            pOutLevelExp[1] = nExp;
            return true;
        }
    }

    pOutLevelExp[0] = 0;
    return true;
}

/** @ghidraAddress 0x1cc1dc */
bool LevelTables::SavePlayerLevelData(const int *pLevelExp) {
    NSString *directory = GetDocumentsDirectoryPath();
    NSString *path = [directory stringByAppendingPathComponent:kLevelListFileName];

    const int nLevel = pLevelExp[0];
    const int nExp = pLevelExp[1];

    // The stored hash lets a later load reject a tampered file.
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:3];
    record[kLevelKey] = @(nLevel);
    record[kExpKey] = @(nExp);
    record[kCustomizeKey] = MakeLevelCustomizeHash(nLevel, nExp);

    return [record writeToFile:path atomically:YES];
}
