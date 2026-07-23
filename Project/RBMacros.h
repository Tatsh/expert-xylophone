#ifndef RBMACROS_H
#define RBMACROS_H

/**
 * @brief The number of elements in a fixed-size C array.
 * @param array A fixed-size C array (not a decayed pointer).
 */
#define ARRAY_SIZE(array) (sizeof(array) / sizeof((array)[0]))

#endif
