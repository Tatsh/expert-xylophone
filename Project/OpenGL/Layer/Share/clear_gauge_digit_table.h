/**
 * @file
 * The clear-gauge percentage label and digit glyph descriptor tables.
 */

#pragma once

/**
 * @brief One clear-gauge label or digit quad descriptor.
 *
 * The digit paths take only the anchor Y, the size, and the atlas frame from this record and
 * override the anchor X with a per-position value; the label paths use every field.
 */
struct GaugeGlyphDesc {
    float flAnchorX = {}; /*!< The pivot X offset (used by the labels only). +0x00 */
    float flAnchorY = {}; /*!< The pivot Y offset. +0x04 */
    float flSizeX = {};   /*!< The quad width. +0x08 */
    float flSizeY = {};   /*!< The quad height. +0x0c */
    int nAtlasFrame = {}; /*!< The sprite atlas frame. +0x10 */
};

// The two fixed gauge labels (a separator drawn into batch five and the percent sign drawn
// into batch seven), each with a normal and a high-value (at or above 70%) variant.
// @ghidraAddress 0x30c294
constexpr GaugeGlyphDesc g_aGaugeLabelSeparatorPad[] = {{-6.0f, 2.0f, 2.0f, 10.0f, 197},
                                                        {-6.0f, 2.0f, 2.0f, 10.0f, 198}};
// @ghidraAddress 0x30c2bc
constexpr GaugeGlyphDesc g_aGaugeLabelSeparatorPhone[] = {{-6.0f, 9.0f, 2.0f, 10.0f, 326},
                                                          {-6.0f, 9.0f, 2.0f, 10.0f, 327}};
// @ghidraAddress 0x30c2e4
constexpr GaugeGlyphDesc g_aGaugeLabelPercentPad[] = {{-22.0f, 2.0f, 12.0f, 10.0f, 199},
                                                      {-22.0f, 2.0f, 12.0f, 10.0f, 200}};
// @ghidraAddress 0x30c30c
constexpr GaugeGlyphDesc g_aGaugeLabelPercentPhone[] = {{-22.0f, 9.0f, 12.0f, 10.0f, 328},
                                                        {-22.0f, 9.0f, 12.0f, 10.0f, 329}};

// The iPad digit glyphs: indices 0-9 and 10-19 are the large digits (normal and high-value),
// 20-29 and 30-39 the small fractional digits. @ghidraAddress 0x30c344
constexpr GaugeGlyphDesc g_aGaugeDigitGlyphPad[] = {
    {0.0f, 5.0f, 12.0f, 14.0f, 157}, {0.0f, 5.0f, 12.0f, 14.0f, 158},
    {0.0f, 5.0f, 12.0f, 14.0f, 159}, {0.0f, 5.0f, 12.0f, 14.0f, 160},
    {0.0f, 5.0f, 12.0f, 14.0f, 161}, {0.0f, 5.0f, 12.0f, 14.0f, 162},
    {0.0f, 5.0f, 12.0f, 14.0f, 163}, {0.0f, 5.0f, 12.0f, 14.0f, 164},
    {0.0f, 5.0f, 12.0f, 14.0f, 165}, {0.0f, 5.0f, 12.0f, 14.0f, 166},
    {0.0f, 5.0f, 12.0f, 14.0f, 167}, {0.0f, 5.0f, 12.0f, 14.0f, 168},
    {0.0f, 5.0f, 12.0f, 14.0f, 169}, {0.0f, 5.0f, 12.0f, 14.0f, 170},
    {0.0f, 5.0f, 12.0f, 14.0f, 171}, {0.0f, 5.0f, 12.0f, 14.0f, 172},
    {0.0f, 5.0f, 12.0f, 14.0f, 173}, {0.0f, 5.0f, 12.0f, 14.0f, 174},
    {0.0f, 5.0f, 12.0f, 14.0f, 175}, {0.0f, 5.0f, 12.0f, 14.0f, 176},
    {0.0f, 2.0f, 10.0f, 10.0f, 177}, {0.0f, 2.0f, 10.0f, 10.0f, 178},
    {0.0f, 2.0f, 10.0f, 10.0f, 179}, {0.0f, 2.0f, 10.0f, 10.0f, 180},
    {0.0f, 2.0f, 10.0f, 10.0f, 181}, {0.0f, 2.0f, 10.0f, 10.0f, 182},
    {0.0f, 2.0f, 10.0f, 10.0f, 183}, {0.0f, 2.0f, 10.0f, 10.0f, 184},
    {0.0f, 2.0f, 10.0f, 10.0f, 185}, {0.0f, 2.0f, 10.0f, 10.0f, 186},
    {0.0f, 2.0f, 10.0f, 10.0f, 187}, {0.0f, 2.0f, 10.0f, 10.0f, 188},
    {0.0f, 2.0f, 10.0f, 10.0f, 189}, {0.0f, 2.0f, 10.0f, 10.0f, 190},
    {0.0f, 2.0f, 10.0f, 10.0f, 191}, {0.0f, 2.0f, 10.0f, 10.0f, 192},
    {0.0f, 2.0f, 10.0f, 10.0f, 193}, {0.0f, 2.0f, 10.0f, 10.0f, 194},
    {0.0f, 2.0f, 10.0f, 10.0f, 195}, {0.0f, 2.0f, 10.0f, 10.0f, 196},
};
// The phone digit glyphs, laid out like the iPad set. @ghidraAddress 0x30c664
constexpr GaugeGlyphDesc g_aGaugeDigitGlyphPhone[] = {
    {0.0f, 12.0f, 12.0f, 12.0f, 286}, {0.0f, 12.0f, 12.0f, 12.0f, 287},
    {0.0f, 12.0f, 12.0f, 12.0f, 288}, {0.0f, 12.0f, 12.0f, 12.0f, 289},
    {0.0f, 12.0f, 12.0f, 12.0f, 290}, {0.0f, 12.0f, 12.0f, 12.0f, 291},
    {0.0f, 12.0f, 12.0f, 12.0f, 292}, {0.0f, 12.0f, 12.0f, 12.0f, 293},
    {0.0f, 12.0f, 12.0f, 12.0f, 294}, {0.0f, 12.0f, 12.0f, 12.0f, 295},
    {0.0f, 12.0f, 12.0f, 12.0f, 296}, {0.0f, 12.0f, 12.0f, 12.0f, 297},
    {0.0f, 12.0f, 12.0f, 12.0f, 298}, {0.0f, 12.0f, 12.0f, 12.0f, 299},
    {0.0f, 12.0f, 12.0f, 12.0f, 300}, {0.0f, 12.0f, 12.0f, 12.0f, 301},
    {0.0f, 12.0f, 12.0f, 12.0f, 302}, {0.0f, 12.0f, 12.0f, 12.0f, 303},
    {0.0f, 12.0f, 12.0f, 12.0f, 304}, {0.0f, 12.0f, 12.0f, 12.0f, 305},
    {0.0f, 9.0f, 10.0f, 10.0f, 306},  {0.0f, 9.0f, 10.0f, 10.0f, 307},
    {0.0f, 9.0f, 10.0f, 10.0f, 308},  {0.0f, 9.0f, 10.0f, 10.0f, 309},
    {0.0f, 9.0f, 10.0f, 10.0f, 310},  {0.0f, 9.0f, 10.0f, 10.0f, 311},
    {0.0f, 9.0f, 10.0f, 10.0f, 312},  {0.0f, 9.0f, 10.0f, 10.0f, 313},
    {0.0f, 9.0f, 10.0f, 10.0f, 314},  {0.0f, 9.0f, 10.0f, 10.0f, 315},
    {0.0f, 9.0f, 10.0f, 10.0f, 316},  {0.0f, 9.0f, 10.0f, 10.0f, 317},
    {0.0f, 9.0f, 10.0f, 10.0f, 318},  {0.0f, 9.0f, 10.0f, 10.0f, 319},
    {0.0f, 9.0f, 10.0f, 10.0f, 320},  {0.0f, 9.0f, 10.0f, 10.0f, 321},
    {0.0f, 9.0f, 10.0f, 10.0f, 322},  {0.0f, 9.0f, 10.0f, 10.0f, 323},
    {0.0f, 9.0f, 10.0f, 10.0f, 324},  {0.0f, 9.0f, 10.0f, 10.0f, 325},
};

// The sprite batch each digit position draws into. @ghidraAddress 0x30c334
constexpr int g_aGaugeDigitBatch[] = {2, 3, 4, 6};
// Each digit position's anchor X offset. @ghidraAddress 0x30c984
constexpr float g_aGaugeDigitAnchorX[] = {31.0f, 19.0f, 7.0f, -9.0f};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
