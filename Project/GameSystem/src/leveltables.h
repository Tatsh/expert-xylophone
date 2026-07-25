/**
 * @file
 * The level-threshold tables manager, @c LevelTables, and the player-level table helpers.
 */

#pragma once

#ifdef __OBJC__
@class NSData;
#else
typedef struct objc_object NSData;
#endif

/**
 * @brief One packed {category, item} unlock entry: the category and item whose unlock level is its
 * position (plus one) in the table.
 */
struct LevelUnlockEntry {
    int nCategory = {}; // +0x00: the unlock category (0 through 4).
    int nItem = {};     // +0x04: the item index within the category.
};

/**
 * @brief The level-threshold tables manager.
 *
 * A lazily constructed singleton. It owns one unlock-level array per category (sized by a per-
 * category count table) built from the packed unlock table, and holds the player's current level as
 * its first field so a threshold check can compare against it. The trailing @c // +0xNN comments
 * document the original 32-bit offsets for reference only.
 */
class LevelTables {
public:
    /**
     * @brief Returns the level-tables manager singleton, constructing it on first use.
     * @ghidraAddress 0x1cbec8
     */
    static LevelTables *GetInstance();

    /**
     * @brief Constructs the manager: allocates one unlock-level array per category and seeds each
     * item's unlock level from the packed unlock table.
     * @ghidraAddress 0x1cbe04
     */
    LevelTables();

    /**
     * @brief Reports whether the player's current level has reached an item's unlock level.
     *
     * Clamps @p itemID to the category's array bounds and compares the stored current level against
     * the item's unlock level.
     * @param category The unlock category (0 through 4).
     * @param itemID The item index within the category.
     * @return @c true when the current level is at or above the item's unlock level.
     * @ghidraAddress 0x1cc460
     */
    bool CheckThresholdReached(int category, int itemID);

    /** @brief The number of unlock categories. */
    static constexpr int kCategoryCount = 5;

private:
    int m_nCurrentLevel = {};                   // +0x00: the player's current level.
    int *m_apUnlockLevels[kCategoryCount] = {}; // +0x08: per-category item unlock-level arrays.
};

/**
 * @brief Returns the cumulative experience required to reach a level.
 *
 * Clamps @p nLevel to the experience table's bounds.
 * @param nLevel The level (0 through 30).
 * @return The cumulative experience threshold for the level.
 * @ghidraAddress 0x1cc410
 */
unsigned int GetLevelExpThreshold(int nLevel);

/**
 * @brief Returns the packed unlock entry for a level.
 *
 * Clamps @p nLevel to the unlock table's bounds. The entry's {category, item} names what unlocks at
 * that level.
 * @param nLevel The level (0 through 30).
 * @return A pointer to the level's unlock entry.
 * @ghidraAddress 0x1cc438
 */
const struct LevelUnlockEntry *GetLevelUnlockEntry(int nLevel);

/**
 * @brief Computes the level and experience gain step scaled by a per-level factor.
 *
 * Clamps @p nLevel to the step table's bounds, then returns
 * @c (flBase + (bAddHalf ? 0.5 : 0)) * stepTable[nLevel], plus a fixed base offset when @p bAddOffset
 * is set, truncated to an integer.
 * @param nLevel The level (0 through 9).
 * @param bAddHalf Non-zero to bias the base by half a step.
 * @param flBase The base multiplier.
 * @param bAddOffset Non-zero to add the fixed pixel base offset.
 * @return The scaled step value.
 * @ghidraAddress 0x1cc3b4
 */
int ComputeLevelExpStep(int nLevel, int bAddHalf, float flBase, int bAddOffset);

/**
 * @brief Builds the validation hash of a saved level record from its level and experience.
 * @param nLevel The player level.
 * @param nExp The player experience.
 * @return The MD5 hash data of the formatted record string.
 * @ghidraAddress 0x1cc138
 */
NSData *MakeLevelCustomizeHash(int nLevel, int nExp);

/**
 * @brief Loads and validates the player's level and experience from the persisted plist.
 *
 * Reads the @c lelist plist from the application-support directory, re-hashes its level and
 * experience, and accepts them into @p pOutLevelExp only when the stored hash matches; otherwise the
 * output level is cleared.
 * @param pOutLevelExp Receives the {level, experience} pair.
 * @return Always @c true.
 * @ghidraAddress 0x1cbf18
 */
bool LoadPlayerLevelData(int *pOutLevelExp);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
