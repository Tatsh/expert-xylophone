/**
 * @file
 * The per-play score and judgement tracker, @c ScoreTracker.
 */

#pragma once

#include "playerfieldlayer.h"

/**
 * @brief One player side's play record: the per-grade judgement counters plus the derived rate,
 * rank, and a trailing field.
 *
 * The eleven 32-bit slots are addressed both by index (through @c ScoreTracker::GetPlayRecordCell)
 * and by name; slot 8 is reinterpreted as a float rate, slots 9 and 10 as integers. The trailing
 * @c // +0xNN comments document the original 32-bit member offsets for reference only.
 */
struct PlayRecord {
    int nCells[8] = {}; // +0x00: the per-grade judgement counters (cell indices 0 through 7).
    float flRate = {};  // +0x20: the clear rate (cell index 8, read as a float).
    int nRank = {};     // +0x24: the play rank (cell index 9).
    int nField10 = {};  // +0x28: the trailing field (cell index 10).
};

/**
 * @brief The process-wide per-play score and judgement tracker.
 *
 * Holds one @c PlayRecord for each of the two player sides, behind a leading state field. Created on
 * first use by @c GetScoreTracker. The trailing @c // +0xNN comments document the original 32-bit
 * member offsets for reference only.
 */
class ScoreTracker {
public:
    // The number of player sides tracked.
    static constexpr int kSideCount = 2;

    /**
     * @brief A judgement cell of a side's play record, indexed 0 through 10.
     *
     * Indices 0 through 7 are the per-grade counters; index 8 is the rate slot, 9 the rank, and 10
     * the trailing field. An index of 10 reads one slot past the named fields, which for a side
     * below the last reads into the following side's record — reproduced faithfully.
     * @param nSide The player side.
     * @param nCell The cell index.
     * @return The cell value.
     * @ghidraAddress 0x149824
     */
    int GetPlayRecordCell(unsigned int nSide, unsigned int nCell) const {
        return reinterpret_cast<const int *>(&m_aRecords[nSide].nCells[0])[nCell];
    }

    /**
     * @brief A side's clear rate.
     * @param nSide The player side.
     * @return The clear rate.
     * @ghidraAddress 0x1499c4
     */
    float GetPlayRecordRate(unsigned int nSide) const {
        return m_aRecords[nSide].flRate;
    }

    /**
     * @brief A side's play rank.
     * @param nSide The player side.
     * @return The rank.
     * @ghidraAddress 0x1499b0
     */
    int GetPlayRecordRank(unsigned int nSide) const {
        return m_aRecords[nSide].nRank;
    }

    /**
     * @brief A side's trailing play-record field (judgement cell index 10).
     * @param nSide The player side.
     * @return The field value.
     * @ghidraAddress 0x14999c
     */
    int GetPlayRecordField10(unsigned int nSide) const {
        return m_aRecords[nSide].nField10;
    }

    /**
     * @brief Recomputes each side's clear rate and grade tier from its judgement counts and records
     * which side leads.
     *
     * Compares the two sides' first counter to pick the leading side (0, 1, or 2 for a tie), storing
     * it in each record's trailing field. For each side the clear rate is
     * @c (cool*3 + great*2 + good) / (totalNotes*3), stored in the rate slot, and mapped to a grade
     * tier 0 through 5 by the same thresholds as @c GetClearRank, stored in the rank slot.
     * @ghidraAddress 0x14983c
     */
    void ComputeLaneClearRateAndGrade();

    /**
     * @brief Resets every side's play record and repaints the score fields and lane gauges.
     * @ghidraAddress 0x149268
     */
    void ResetLaneGaugeState();

    /**
     * @brief The per-frame gauge-state tick: does nothing.
     *
     * The per-frame render pass calls this on the shared tracker; the body is empty in the binary.
     * @ghidraAddress 0x149320
     */
    void TickGaugeState() {
    }

    /**
     * @brief Stores a side's lane gauge value and repaints its background band, arming the
     * low-gauge warning on the 2P side when the danger state changes.
     * @param flValue The gauge value.
     * @param uSide The player side.
     * @ghidraAddress 0x149324
     */
    void ApplyLaneGaugeValueAndBackground(float flValue, unsigned int uSide);

    /**
     * @brief Applies one note's judgement to a player's record and fires the score effects.
     *
     * The binary qualifies this @c ScoreManager::AddScore (in @c score_manager.mm), but it takes the
     * tracker as its object, so it is modelled as a tracker method. It adds the per-grade delta to
     * the side's running score (clamped at zero), bumps the matching judgement counter, advances the
     * combo and maximum combo (resetting the combo on a miss), recomputes the clear rate, and fires
     * the lane-gauge, note-result, and score-digit effects. The result quad's position band is
     * chosen from the hit's screen x against the note sheet's quarter-width, the play mode, and
     * whether the note's player matches the current play side.
     * @param nPlayer The scoring note's player index.
     * @param nPosX The hit's screen x, selecting the result-quad band.
     * @param nPosY The hit's screen y (unused by the score path).
     * @param nJudge The judgement type (0 = just, 1 = great, 2 = good, 3 = miss).
     * @param nBonusFlag The bonus modifier (deepens the miss penalty when set).
     * @param nMode The play mode (non-zero shifts the result-quad band).
     * @ghidraAddress 0x1493b0
     */
    void AddScore(int nPlayer, int nPosX, int nPosY, int nJudge, int nBonusFlag, int nMode);

    /**
     * @brief Adjusts a player's running score by a signed delta and refreshes its field display.
     *
     * The delta is added to the side's score cell, clamped at zero; the player-field score digits
     * are then retargeted to the new value with no animation. The hit-position arguments mirror
     * @c AddScore's signature but are unused by this path.
     * @param nPlayer The scoring note's player index.
     * @param nPosX The hit's screen x (unused by this path).
     * @param nPosY The hit's screen y (unused by this path).
     * @param nDelta The signed score delta.
     * @ghidraAddress 0x149610
     */
    void AddScoreDelta(int nPlayer, int nPosX, int nPosY, int nDelta);

    /**
     * @brief Applies a shot-note judgement to a player's lane and fires its score/judge effects.
     *
     * Maps the player side to a lane slot, then: on the no-score path (judge flag bit 0) only bumps
     * the lane's hit counter; otherwise adds ten to the lane's score, bumps the hit counter, retargets
     * the player-field score digits, and fires a judge effect.
     * @param nPlayerSide The player side selector.
     * @param nJudgeFlags The judgement flags (bit 0 marks the no-score path).
     * @ghidraAddress 0x149678
     */
    void AddLaneJudgeResult(int nPlayerSide, unsigned int nJudgeFlags);

    /**
     * @brief Adds the full-combo bonus to a side's score and fires its judge popup (grade 0).
     * @param nSide The player side.
     * @ghidraAddress 0x149710
     */
    void SetJudgeScore0(unsigned int nSide);
    /**
     * @brief Adds the grade-2 bonus to a side's score and fires its judge popup.
     * @param nSide The player side.
     * @ghidraAddress 0x14976c
     */
    void SetJudgeScore2(unsigned int nSide);
    /**
     * @brief Adds the grade-3 bonus to a side's score and fires its judge popup.
     * @param nSide The player side.
     * @ghidraAddress 0x1497c8
     */
    void SetJudgeScore3(unsigned int nSide);

    /**
     * @brief Whether every note on a side has been judged.
     *
     * Sums the side's three main judgement counters (cells 4, 5, and 6) and compares the total
     * against the chart's note count.
     * @param nSide The player side.
     * @return @c true when the side's judged-note count equals the total note count.
     * @ghidraAddress 0x1499d8
     */
    bool IsSideAllNotesJudged(unsigned int nSide) const;

    /**
     * @brief Sets the chart's total note count (the clear-rate denominator).
     * @param nTotalNotes The total note count.
     */
    void SetTotalNotes(int nTotalNotes) {
        m_nTotalNotes = nTotalNotes;
    }

    /**
     * @brief The chart's total note count (the clear-rate denominator).
     * @return The total note count.
     */
    int GetTotalNotes() const {
        return m_nTotalNotes;
    }

    /**
     * @brief The process-wide score tracker, created on first use.
     * @return The shared score tracker.
     * @ghidraAddress 0x1492cc
     */
    static ScoreTracker *shared();

private:
    int m_nTotalNotes = {}; // +0x00: the chart's total note count (rate denominator).
    PlayRecord m_aRecords[kSideCount] = {}; // +0x04: one play record per player side.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
