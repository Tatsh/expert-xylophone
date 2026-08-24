/** @file
 * The shared preprocessor helper @c ARRAY_SIZE. It is a convenience for the reconstructed sources
 * rather than a macro recovered from the binary: a compiled image retains no macro definitions, so
 * it corresponds to no address in the shipped binary.
 */

#ifndef RBMACROS_H
#define RBMACROS_H

/**
 * @def ARRAY_SIZE
 * @brief The number of elements in a fixed-size C array.
 * @param array A fixed-size C array (not a decayed pointer).
 */
#define ARRAY_SIZE(array) (sizeof(array) / sizeof((array)[0]))

#endif
