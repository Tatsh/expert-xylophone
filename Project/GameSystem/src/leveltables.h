/**
 * @file
 * The level-threshold tables manager, @c LevelTables.
 */

#pragma once

/**
 * The level-threshold tables manager. Its instance is a lazily constructed singleton, and the
 * threshold check takes the manager as its first argument, so both are modelled as members here.
 * Its full field layout is not yet reconstructed.
 */
class LevelTables {
public:
    /**
     * @brief Returns the level-tables manager singleton, constructing it on first use.
     * @ghidraAddress 0x1cbec8
     */
    static LevelTables *GetInstance();
    /**
     * @brief Reports whether the current value has reached a level threshold in one of the tables.
     * @ghidraAddress 0x1cc460
     */
    bool CheckThresholdReached(int category, int itemID);
    /**
     * @brief Loads and validates the player's level and experience from the persisted plist into
     * this manager.
     * @ghidraAddress 0x1cbf18
     */
    bool LoadPlayerLevelData();
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
