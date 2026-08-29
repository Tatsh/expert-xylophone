/**
 * @file
 * The shared preprocessor helpers, and the build-configurable endpoint defaults.
 *
 * The @c ARRAY_SIZE helper is a convenience for the reconstructed sources rather than a macro
 * recovered from the binary: a compiled image retains no macro definitions, so it corresponds to no
 * address in the shipped binary.
 *
 * The @c RB_ macros below each default to the value the shipped binary uses, so an unconfigured
 * build is unchanged. The build systems override them so a build can be pointed at private or
 * replacement servers without editing the sources: pass @c -D<NAME>=... to CMake or @c NAME=... to
 * the Theos @c Makefile, dropping the @c RB_ prefix (for example @c API_HOST for @c RB_API_HOST).
 * Each must expand to a bare string literal, because the call sites spell them @c \@RB_NAME to form
 * an @c NSString.
 */

#ifndef RBMACROS_H
#define RBMACROS_H

/**
 * @def ARRAY_SIZE
 * The number of elements in a fixed-size C array.
 * @param array A fixed-size C array (not a decayed pointer).
 */
#define ARRAY_SIZE(array) (sizeof(array) / sizeof((array)[0]))

/**
 * @def RB_API_SCHEME
 * The URL scheme every secure API request is built with.
 *
 * Only worth changing for a plaintext test server.
 */
#ifndef RB_API_SCHEME
#define RB_API_SCHEME "https"
#endif

/**
 * @def RB_API_HOST
 * The hostname every secure API request is built against.
 *
 * This host is also added to the in-app link allow-list in @c RBWebView.m, so links to a configured
 * server load inside the web view rather than being handed to Safari.
 */
#ifndef RB_API_HOST
#define RB_API_HOST "akx.s.konaminet.jp"
#endif

/**
 * @def RB_API_BASE_PATH
 * The common CGI base path every endpoint is built under.
 *
 * The companion to @c RB_API_HOST: an endpoint is the scheme, host, this path, and the per-endpoint
 * leaf, so a replacement server has to serve this prefix unless it is overridden too. Keep the
 * leading and trailing slashes.
 */
#ifndef RB_API_BASE_PATH
#define RB_API_BASE_PATH "/akx/main/cgi/"
#endif

/**
 * @def RB_APPLILINK_APP_ID
 * The application identifier passed to Konami's Applilink SDK.
 */
#ifndef RB_APPLILINK_APP_ID
#define RB_APPLILINK_APP_ID "10"
#endif

/**
 * @def RB_APPLILINK_ENV
 * The Applilink server environment selector.
 *
 * The SDK compares this against its own environment keys to pick a base URL: @c "0" is production,
 * @c "1" staging, @c "2" and @c "3" sandbox, and @c "4" development.
 */
#ifndef RB_APPLILINK_ENV
#define RB_APPLILINK_ENV "0"
#endif

/**
 * @def RB_APPLILINK_URL_PRODUCTION
 * The Applilink base URL selected when @c RB_APPLILINK_ENV is @c "0".
 */
#ifndef RB_APPLILINK_URL_PRODUCTION
#define RB_APPLILINK_URL_PRODUCTION "https://www.applilink.jp"
#endif

/**
 * @def RB_APPLILINK_URL_STAGING
 * The Applilink base URL selected when @c RB_APPLILINK_ENV is @c "1".
 */
#ifndef RB_APPLILINK_URL_STAGING
#define RB_APPLILINK_URL_STAGING "https://st.es.i-revoinf.jp"
#endif

/**
 * @def RB_APPLILINK_URL_DEVELOPMENT
 * The Applilink base URL selected when @c RB_APPLILINK_ENV is @c "4".
 */
#ifndef RB_APPLILINK_URL_DEVELOPMENT
#define RB_APPLILINK_URL_DEVELOPMENT "https://dev.es.i-revoinf.jp"
#endif

/**
 * @def RB_APPLILINK_URL_SANDBOX
 * The Applilink base URL selected when @c RB_APPLILINK_ENV is @c "2" or @c "3".
 */
#ifndef RB_APPLILINK_URL_SANDBOX
#define RB_APPLILINK_URL_SANDBOX "https://sandbox.applilink.jp"
#endif

#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
