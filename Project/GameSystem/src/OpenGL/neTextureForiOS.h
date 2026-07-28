/**
 * @file
 * The iOS texture-loading helper class, @c neTextureForiOS.
 */

#pragma once

#import <Foundation/Foundation.h>

namespace ne {
class C_TEXTURE;
} // namespace ne

/**
 * @brief The iOS texture-loading helper.
 *
 * Vends engine textures decoded from image data. Only the class method used by the game system's
 * artwork/name texture loaders is modelled so far.
 */
@interface neTextureForiOS : NSObject

/**
 * @brief Decodes @p pData into a reference-counted engine texture at the given screen scale.
 * @param pData The encoded image data.
 * @param flScale The screen scale (1 or 2) the texture is decoded for.
 * @return The loaded texture, or @c nullptr when the data could not be decoded.
 */
+ (nullable ne::C_TEXTURE *)LoadTexture:(nullable NSData *)pData Scale:(double)flScale;

@end

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
