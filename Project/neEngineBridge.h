/**
 * @file
 * Umbrella header for the C++ game-engine layer, reached from the Objective-C code.
 */

//
//  neEngineBridge.h
//  REFLEC BEAT plus
//
//  Transitional umbrella over the split engine headers. The declarations that once lived here have
//  moved to per-class and per-domain headers under GameSystem/src/; this header now only re-exports
//  them so the many existing consumers keep compiling while they are migrated to include the
//  specific headers they use. It will be removed once every consumer has been updated.
//
//  Reconstructed from Ghidra project rb458, program rb458. Addresses in @ghidraAddress tags are
//  relative to the program image base.
//

#pragma once

// The Objective-C / C free-function groups and shared globals: safe to include from pure
// Objective-C (.m) translation units.
#import "GameSystem/src/deviceenvironment.h"
#import "GameSystem/src/enginecrypto.h"
#import "GameSystem/src/engineglobals.h"
#import "GameSystem/src/engineruntime.h"

#ifdef __cplusplus
// The C++ engine classes and maths helpers: only visible to Objective-C++ / C++ translation units.
#import "GameSystem/src/Audio/audiosourceslot.h"
#import "GameSystem/src/Audio/caplayermgr.h"
#import "GameSystem/src/Audio/shotsoundmanager.h"
#import "GameSystem/src/Audio/soundeffectmanager.h"
#import "GameSystem/src/Render/curve.h"
#import "GameSystem/src/Render/matrixmath.h"
#import "GameSystem/src/Render/neRenderer.h"
#import "GameSystem/src/Render/s_vector2.h"
#import "GameSystem/src/Render/s_vector3.h"
#import "GameSystem/src/Render/vectormath.h"
#import "GameSystem/src/gamescene.h"
#import "GameSystem/src/gamesystem.h"
#import "GameSystem/src/leveltables.h"
#import "GameSystem/src/ne_c_time.h"
#import "GameSystem/src/playtimer.h"
#import "GameSystem/src/sheetlayer.h"
#import "GameSystem/src/touchmanager.h"
#import "OpenGL/Layer/Share/clear_gauge_layer.h"
#endif

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objc :
