/**
 * @file
 * The Classic-theme result-window layer, @c ResultWindowClassicLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct PartsDataRecord;

/**
 * @brief The Classic-theme result-window layer.
 *
 * Draws the Classic result panel; a process-wide singleton built on first access, deriving from
 * @c PlayFieldLayerBase. Only the parts-data accessors and the singleton getter are reconstructed so
 * far; the object's own fields (a @c 0x1c0-byte layout seeded by the constructor) are still being
 * worked out and kept as a reserved span to preserve the binary's allocation size.
 */
class ResultWindowClassicLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Classic result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1151fc
     */
    static ResultWindowClassicLayer *shared();

    /**
     * @brief Returns a result-window parts descriptor by index for the current device.
     *
     * Selects the pad or phone parts table by the device kind and returns the record at @p nIndex.
     * @param nIndex The parts-record index (0 through 239).
     * @return The parts descriptor.
     * @ghidraAddress 0x114b78
     */
    const PartsDataRecord *getPartsData(int nIndex) const;

    /**
     * @brief Returns a phone-layout parts descriptor by index.
     *
     * Always reads the static phone parts table.
     * @param nIndex The parts-record index (0 through 125).
     * @return The parts descriptor.
     * @ghidraAddress 0x114c10
     */
    const PartsDataRecord *getPartsData_Phone(int nIndex) const;

private:
    // +0x08..+0x1bf: the layer's own state (the colour-marker sub-objects, transform vectors, and
    // per-cell fields the constructor seeds), whose individual fields are still being worked out.
    unsigned char m_aReserved08[0x1b8] = {}; // +0x08
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
