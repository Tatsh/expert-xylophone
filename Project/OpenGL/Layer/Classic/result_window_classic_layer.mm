#include "result_window_classic_layer.h"

#include <cassert>

#include "classic_parts_data_table.h"
#import "neEngineBridge.h"

// The process-wide Classic result-window layer, created lazily by shared().
static ResultWindowClassicLayer *g_pClassicResultLayer = nullptr; // @ghidraAddress 0x3dd2f8

// The Classic pad parts table (declared in classic_parts_data_table.h): zero-initialised here to
// match the binary's __common segment, filled at runtime.
PartsDataRecord g_aClassicPartsPad[kClassicPartsRecordBound] = {}; // @ghidraAddress 0x3d6650

// The Classic phone parts table (@ghidraAddress 0x303580): static read-only sprite descriptors, one
// per result-window part, giving each part's placement offset, size, and UV-palette index.
const PartsDataRecord g_aClassicPartsPhone[kClassicPhonePartsRecordCount] = {
    {1, 0.0f, 0.0f, 1024.0f, 1024.0f, 0}, {1, 0.0f, 0.0f, 57.0f, 20.0f, 1},
    {1, 0.0f, 0.0f, 9.0f, 9.0f, 2},       {1, 0.0f, 0.0f, 1.0f, 9.0f, 3},
    {1, 0.0f, 0.0f, 9.0f, 1.0f, 4},       {1, 0.0f, 0.0f, 1.0f, 1.0f, 5},
    {1, 0.0f, 0.0f, 9.0f, 9.0f, 6},       {1, 0.0f, 0.0f, 1.0f, 9.0f, 7},
    {1, 0.0f, 0.0f, 9.0f, 1.0f, 8},       {1, 0.0f, 0.0f, 1.0f, 1.0f, 9},
    {1, 0.0f, 0.0f, 15.0f, 17.0f, 10},    {1, 0.0f, 0.0f, 1.0f, 17.0f, 11},
    {1, 0.0f, 0.0f, 1.0f, 1.0f, 12},      {1, 0.0f, 0.0f, 1.0f, 1.0f, 13},
    {1, 0.0f, 0.0f, 48.0f, 8.0f, 14},     {1, 0.0f, 0.0f, 30.0f, 8.0f, 15},
    {1, 0.0f, 0.0f, 26.0f, 8.0f, 16},     {1, 0.0f, 0.0f, 164.0f, 8.0f, 17},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 18},      {1, 0.0f, 0.0f, 38.0f, 8.0f, 19},
    {1, 0.0f, 0.0f, 38.0f, 8.0f, 20},     {1, 0.0f, 0.0f, 38.0f, 8.0f, 21},
    {1, 0.0f, 0.0f, 38.0f, 8.0f, 22},     {1, 0.0f, 0.0f, 4.0f, 6.0f, 23},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 24},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 25},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 26},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 27},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 28},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 29},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 30},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 31},
    {1, 0.0f, 0.0f, 4.0f, 6.0f, 32},      {1, 0.0f, 0.0f, 4.0f, 6.0f, 33},
    {1, 0.0f, 0.0f, 6.0f, 6.0f, 34},      {1, 0.0f, 0.0f, 6.0f, 6.0f, 35},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 36},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 37},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 38},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 39},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 40},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 41},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 42},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 43},
    {1, 0.0f, 0.0f, 20.0f, 24.0f, 44},    {1, 0.0f, 0.0f, 20.0f, 24.0f, 45},
    {1, 13.0f, 12.0f, 26.0f, 24.0f, 46},  {1, 10.0f, 12.0f, 20.0f, 24.0f, 47},
    {1, 13.0f, 12.0f, 26.0f, 24.0f, 48},  {1, 20.0f, 12.0f, 40.0f, 24.0f, 49},
    {1, 20.0f, 12.0f, 40.0f, 24.0f, 50},  {1, 20.0f, 12.0f, 40.0f, 24.0f, 51},
    {1, 0.0f, 0.0f, 50.0f, 6.0f, 52},     {1, 0.0f, 0.0f, 26.0f, 10.0f, 53},
    {1, 0.0f, 0.0f, 26.0f, 10.0f, 54},    {1, 0.0f, 0.0f, 33.0f, 10.0f, 55},
    {1, 0.0f, 0.0f, 33.0f, 10.0f, 56},    {1, 0.0f, 0.0f, 6.0f, 8.0f, 57},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 58},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 59},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 60},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 61},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 62},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 63},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 64},      {1, 0.0f, 0.0f, 6.0f, 8.0f, 65},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 66},      {1, 0.0f, 0.0f, 2.0f, 8.0f, 67},
    {1, 0.0f, 0.0f, 4.0f, 8.0f, 68},      {1, 0.0f, 0.0f, 8.0f, 8.0f, 69},
    {1, 0.0f, 0.0f, 6.0f, 8.0f, 70},      {1, 13.0f, 4.0f, 26.0f, 8.0f, 71},
    {1, 13.0f, 4.0f, 26.0f, 8.0f, 72},    {1, 13.0f, 4.0f, 26.0f, 8.0f, 73},
    {1, 13.0f, 4.0f, 26.0f, 8.0f, 74},    {1, 18.0f, 4.0f, 36.0f, 8.0f, 75},
    {1, 18.0f, 4.0f, 36.0f, 8.0f, 76},    {1, 13.0f, 4.0f, 26.0f, 8.0f, 77},
    {1, 30.0f, 4.0f, 60.0f, 8.0f, 78},    {1, 30.0f, 4.0f, 60.0f, 8.0f, 79},
    {1, 30.0f, 4.0f, 60.0f, 8.0f, 80},    {1, 30.0f, 4.0f, 60.0f, 8.0f, 81},
    {1, 33.0f, 4.0f, 66.0f, 8.0f, 82},    {1, 18.0f, 4.0f, 36.0f, 8.0f, 83},
    {1, 46.0f, 4.0f, 92.0f, 8.0f, 84},    {1, 0.0f, 0.0f, 8.0f, 10.0f, 85},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 86},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 87},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 88},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 89},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 90},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 91},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 92},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 93},
    {1, 0.0f, 0.0f, 8.0f, 10.0f, 94},     {1, 0.0f, 0.0f, 8.0f, 10.0f, 95},
    {1, 0.0f, 0.0f, 5.0f, 10.0f, 96},     {1, 0.0f, 0.0f, 114.0f, 10.0f, 97},
    {1, 0.0f, 0.0f, 1.0f, 8.0f, 98},      {1, 0.0f, 0.0f, 8.0f, 11.0f, 99},
    {1, 0.0f, 0.0f, 62.0f, 62.0f, 100},   {1, 3.0f, 3.0f, 6.0f, 6.0f, 101},
    {1, 0.0f, 0.0f, 66.0f, 8.0f, 102},    {1, 0.0f, 0.0f, 76.0f, 8.0f, 103},
    {1, 0.0f, 0.0f, 32.0f, 7.0f, 104},    {1, 0.0f, 0.0f, 86.0f, 12.0f, 105},
    {1, 0.0f, 0.0f, 170.0f, 20.0f, 106},  {1, 0.0f, 0.0f, 150.0f, 26.0f, 107},
    {1, 0.0f, 0.0f, 123.0f, 26.0f, 108},  {1, 0.0f, 0.0f, 150.0f, 26.0f, 109},
    {1, 0.0f, 0.0f, 1.0f, 28.0f, 110},    {1, 0.0f, 0.0f, 22.0f, 28.0f, 111},
    {1, 0.0f, 0.0f, 1.0f, 28.0f, 112},    {1, 0.0f, 0.0f, 24.0f, 50.0f, 113},
    {1, 0.0f, 0.0f, 1.0f, 50.0f, 114},    {1, 58.0f, 9.0f, 116.0f, 18.0f, 115},
    {1, 0.0f, 0.0f, 72.0f, 24.0f, 116},   {1, 0.0f, 0.0f, 70.0f, 24.0f, 117},
    {1, 0.0f, 0.0f, 94.0f, 24.0f, 118},   {1, 51.0f, 6.0f, 102.0f, 12.0f, 119},
    {1, 56.0f, 6.0f, 112.0f, 12.0f, 120}, {1, 22.0f, 5.0f, 44.0f, 10.0f, 121},
    {1, 51.0f, 5.0f, 102.0f, 10.0f, 122}, {1, 51.0f, 5.0f, 102.0f, 10.0f, 123},
    {1, 22.0f, 5.0f, 44.0f, 10.0f, 124},  {1, 51.0f, 5.0f, 102.0f, 10.0f, 125},
};

/** @ghidraAddress 0x1151fc */
ResultWindowClassicLayer *ResultWindowClassicLayer::shared() {
    if (g_pClassicResultLayer == nullptr) {
        // The binary allocates the raw 0x1c0-byte object and runs the colour-marker constructor
        // (0x115094), which seeds the transform vectors and four colour sub-objects; that
        // constructor's field initialisation is not yet reconstructed, so only the base is set up
        // here.
        g_pClassicResultLayer = new ResultWindowClassicLayer();
    }
    return g_pClassicResultLayer;
}

/** @ghidraAddress 0x114b78 */
const PartsDataRecord *ResultWindowClassicLayer::getPartsData(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kClassicPartsRecordBound);

    // The pad build reads the runtime-filled pad table; the phone build reads the static table.
    return IsPad() ? &g_aClassicPartsPad[nIndex] : &g_aClassicPartsPhone[nIndex];
}

/** @ghidraAddress 0x114c10 */
const PartsDataRecord *ResultWindowClassicLayer::getPartsData_Phone(int nIndex) const {
    assert(nIndex >= 0 && nIndex < kClassicPhonePartsRecordCount);

    // This accessor always reads the static phone parts table.
    return &g_aClassicPartsPhone[nIndex];
}
