/**
 * @file
 * The binary-resident customize-asset variant-name tables, indexed by variant to build a customize
 * asset's on-disk path. Each is an array of @c NSString* variant tokens living in the binary's
 * read-only data; only the arrays are referenced, so they are declared @c extern here.
 */

#pragma once

#import <Foundation/Foundation.h>

/** @brief The BGM (category 0) variant-name table. @ghidraAddress 0x359c50 */
extern NSString *const g_aCustomizeBgmVariants[];
/** @brief The shot-sound (category 1) variant-name table. @ghidraAddress 0x359e90 */
extern NSString *const g_aCustomizeShotVariants[];
/** @brief The explosion (category 2) variant-name table. @ghidraAddress 0x35a0c0 */
extern NSString *const g_aCustomizeExplosionVariants[];
/** @brief The frame (category 3) variant-name table. @ghidraAddress 0x35a158 */
extern NSString *const g_aCustomizeFrameVariants[];
/** @brief The background (category 4) variant-name table. @ghidraAddress 0x35a250 */
extern NSString *const g_aCustomizeBackgroundVariants[];
/** @brief The object (category 5) variant-name table. @ghidraAddress 0x35a330 */
extern NSString *const g_aCustomizeObjectVariants[];
/** @brief The theme (category 10) variant-name table. @ghidraAddress 0x35a348 */
extern NSString *const g_aCustomizeThemaVariants[];

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
