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
 * The iOS texture-loading helper.
 *
 * Vends engine textures decoded from image data. Only the class method used by the game system's
 * artwork/name texture loaders is modelled so far.
 */
@interface neTextureForiOS : NSObject

/**
 * Decodes @p pData into a reference-counted engine texture at the given screen scale.
 * The returned texture carries one reference, which the caller owns and drops through
 * @c ne::C_TEXTURE::Release.
 * @param pData The encoded image data.
 * @param flScale The screen scale (1 or 2) the texture is decoded for. The method's type encoding
 *        ends @c f24, and @c C_TEXTURE::SetDataAndUpload stores the forwarded register with
 *        @c str @c s0, so this is a single-precision float rather than a double.
 * @return The loaded texture, or @c nullptr when the data could not be decoded.
 * @ghidraAddress 0x32320
 */
+ (nullable ne::C_TEXTURE *)LoadTexture:(nullable NSData *)pData Scale:(float)flScale;

@end

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
