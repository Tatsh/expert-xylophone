/** @file
 * A lightweight two-dimensional kinematic model for an animated menu character. It carries a
 * position, a per-frame velocity, and an acceleration, plus an optional axis-aligned boundary box
 * and the flags that decide how the boundary is enforced. Each @c update step advances the
 * position by the velocity and then, when limiting is enabled, clamps the position back inside the
 * box and optionally reflects the velocity and acceleration so that the character bounces off the
 * edge. It is a plain model object with no drawing of its own; a view layer reads its @c posX and
 * @c posY to place the character on screen.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBCharacterBase, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

/**
 * @brief The boundary-enforcement flags stored in @c useLimit.
 *
 * @c update tests these bits with @c checkLimitType: to decide whether to clamp the position to
 * the boundary box and whether to reflect the velocity and acceleration at the edge. A value of
 * zero disables all boundary handling.
 */
typedef NS_OPTIONS(NSUInteger, RBCharacterLimitType) {
    RBCharacterLimitTypeNone = 0,      /*!< No boundary handling. */
    RBCharacterLimitTypeClamp = 0x1,   /*!< Clamp the position to the boundary box. */
    RBCharacterLimitTypeBounce = 0x10, /*!< Reflect the velocity and acceleration at the edge. */
};

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A two-dimensional kinematic model with an optional bounded, bouncing playfield.
 */
@interface RBCharacterBase : NSObject

/**
 * @brief The current horizontal position.
 * @ghidraAddress 0x19ea1c (getter)
 * @ghidraAddress 0x19ea2c (setter)
 */
@property(nonatomic, assign) float posX;
/**
 * @brief The current vertical position.
 * @ghidraAddress 0x19ea3c (getter)
 * @ghidraAddress 0x19ea4c (setter)
 */
@property(nonatomic, assign) float posY;
/**
 * @brief The per-frame horizontal velocity added to @c posX by @c update.
 * @ghidraAddress 0x19ea5c (getter)
 * @ghidraAddress 0x19ea6c (setter)
 */
@property(nonatomic, assign) float moveX;
/**
 * @brief The per-frame vertical velocity added to @c posY by @c update.
 * @ghidraAddress 0x19ea7c (getter)
 * @ghidraAddress 0x19ea8c (setter)
 */
@property(nonatomic, assign) float moveY;
/**
 * @brief The horizontal acceleration. It is reflected alongside @c moveX when the character
 * bounces off a horizontal edge.
 * @ghidraAddress 0x19ea9c (getter)
 * @ghidraAddress 0x19eaac (setter)
 */
@property(nonatomic, assign) float accX;
/**
 * @brief The vertical acceleration. It is reflected alongside @c moveY when the character bounces
 * off a vertical edge.
 * @ghidraAddress 0x19eabc (getter)
 * @ghidraAddress 0x19eacc (setter)
 */
@property(nonatomic, assign) float accY;
/**
 * @brief The boundary-enforcement flag mask, an @c RBCharacterLimitType bit set.
 * @ghidraAddress 0x19eadc (getter)
 * @ghidraAddress 0x19eaec (setter)
 */
@property(nonatomic, assign) int useLimit;
/**
 * @brief The top edge of the boundary box (the minimum @c posY).
 * @ghidraAddress 0x19eafc (getter)
 * @ghidraAddress 0x19eb0c (setter)
 */
@property(nonatomic, assign) float limitPosUp;
/**
 * @brief The right edge of the boundary box (the maximum @c posX).
 * @ghidraAddress 0x19eb1c (getter)
 * @ghidraAddress 0x19eb2c (setter)
 */
@property(nonatomic, assign) float limitPosRight;
/**
 * @brief The bottom edge of the boundary box (the maximum @c posY).
 * @ghidraAddress 0x19eb3c (getter)
 * @ghidraAddress 0x19eb4c (setter)
 */
@property(nonatomic, assign) float limitPosDown;
/**
 * @brief The left edge of the boundary box (the minimum @c posX).
 * @ghidraAddress 0x19eb5c (getter)
 * @ghidraAddress 0x19eb6c (setter)
 */
@property(nonatomic, assign) float limitPosLeft;
/**
 * @brief A spare horizontal-velocity limit, reset by @c setDefault but not used by @c update.
 * @ghidraAddress 0x19eb7c (getter)
 * @ghidraAddress 0x19eb8c (setter)
 */
@property(nonatomic, assign) float limitMoveX;
/**
 * @brief A spare vertical-velocity limit, reset by @c setDefault but not used by @c update.
 * @ghidraAddress 0x19eb9c (getter)
 * @ghidraAddress 0x19ebac (setter)
 */
@property(nonatomic, assign) float limitMoveY;
/**
 * @brief A spare horizontal-acceleration limit, reset by @c setDefault but not used by @c update.
 * @ghidraAddress 0x19ebbc (getter)
 * @ghidraAddress 0x19ebcc (setter)
 */
@property(nonatomic, assign) float limitAccX;
/**
 * @brief A spare vertical-acceleration limit, reset by @c setDefault but not used by @c update.
 * @ghidraAddress 0x19ebdc (getter)
 * @ghidraAddress 0x19ebec (setter)
 */
@property(nonatomic, assign) float limitAccY;

/**
 * @brief Initialises the receiver and zeroes every field through @c setDefault.
 * @return The initialised instance.
 * @ghidraAddress 0x19e5b0
 */
- (instancetype)init;

/**
 * @brief Resets the position, velocity, acceleration, boundary box, and flags to zero.
 * @ghidraAddress 0x19e608
 */
- (void)setDefault;

/**
 * @brief Advances the position by the velocity and, when limiting is enabled, clamps the position
 * to the boundary box and optionally reflects the velocity and acceleration at the edge.
 * @ghidraAddress 0x19e748
 */
- (void)update;

/**
 * @brief Reports whether all of the given boundary-enforcement bits are set in @c useLimit.
 * @param checkLimitType The @c RBCharacterLimitType bits to test.
 * @return @c YES when every bit in @p checkLimitType is set in @c useLimit.
 * @ghidraAddress 0x19e9e8
 */
- (BOOL)checkLimitType:(int)checkLimitType;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
