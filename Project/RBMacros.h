/** @file
 * The shared preprocessor helpers. These are conveniences for the reconstructed sources rather
 * than macros recovered from the binary: a compiled image retains no macro definitions, so they
 * correspond to no address in the shipped binary.
 */

#ifndef RBMACROS_H
#define RBMACROS_H

/**
 * @def ARRAY_SIZE
 * @brief The number of elements in a fixed-size C array.
 * @param array A fixed-size C array (not a decayed pointer).
 */
#define ARRAY_SIZE(array) (sizeof(array) / sizeof((array)[0]))

/**
 * @def RB_API_HOST
 * @brief The hostname every secure API request is built against.
 *
 * Defaults to the host the shipped binary uses. The build systems override it so a build can be
 * pointed at a private or replacement server without editing the sources: pass @c -DAPI_HOST=...
 * to CMake, or @c API_HOST=... to the Theos @c Makefile. It must expand to a bare string literal,
 * because the call sites spell it @c \@RB_API_HOST to form an @c NSString.
 *
 * This only redirects the API host. The in-app link allow-list in @c RBWebView.m is a separate
 * set of hostnames and is not affected.
 */
#ifndef RB_API_HOST
#define RB_API_HOST "akx.s.konaminet.jp"
#endif

#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
