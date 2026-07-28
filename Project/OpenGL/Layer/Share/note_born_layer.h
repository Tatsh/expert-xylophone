/**
 * @file
 * The note-spawn ("born") effect layer, @c NoteBornLayer.
 */

#pragma once

/**
 * @brief One pooled note-spawn effect: a burst emitted at a note's spawn position, tinted by the
 * note's player colour.
 */
struct NoteBornEffect {
    bool bActive = {};  // +0x00: whether this pool slot holds a live effect.
    int nColorOne = {}; // +0x04: non-zero when the note's colour is the second player colour (1).
    float flX = {};     // +0x08: the effect's X position.
    float flY = {};     // +0x0c: the effect's Y position.
    float flTimer = {}; // +0x10: the effect's animation timer, reset to zero on spawn.
};

/**
 * @brief The note-spawn ("born") effect layer.
 *
 * Holds a fixed pool of note-spawn burst effects, each created at a note's spawn position by
 * @c Create. The name is inferred from the class's embedded @c __FILE__ path
 * (@c OpenGL/Layer/Share/note_born_layer.mm) rather than confirmed from runtime metadata. The
 * trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class NoteBornLayer {
public:
    // The number of player colours a note-spawn effect may take (the valid colour range is
    // @c [0, kPlayerColorMax)).
    static constexpr int kPlayerColorMax = 2;
    // The number of pooled note-spawn effects.
    static constexpr int kEffectPoolSize = 128;

    /**
     * @brief Spawns a note-spawn burst effect at @p flX, @p flY for a note of the given colour.
     *
     * Claims the first inactive pool slot and seeds it: marks it active, records whether the colour
     * is the second player colour, stores the position, and resets the animation timer. A full pool
     * drops the effect. Asserts the colour is in @c [0, kPlayerColorMax).
     * @param nColor The note's player colour (0 or 1).
     * @param flX The effect's X position.
     * @param flY The effect's Y position.
     * @ghidraAddress 0x185564
     */
    void Create(int nColor, float flX, float flY);

private:
    // +0x00..+0x23: the layer header preceding the effect pool, still being worked out; kept as a
    // reserved span so the pool lands at its original offset.
    unsigned char m_aReserved00[0x24] = {};          // +0x00
    NoteBornEffect m_aEffects[kEffectPoolSize] = {}; // +0x24: the pooled note-spawn effects.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
