/**
 * @file
 * Optional @c os_log runtime diagnostics, gated behind the @c RBPDBG build flag.
 *
 * None of this is part of the original binary: it is compiled in only when the build defines
 * @c RBPDBG (the CMake option of that name, which is enable-able in any build configuration and is
 * turned on in CI). With @c RBPDBG off every helper here collapses to a no-op, so a translation
 * unit that only logs matches the reconstructed original exactly without any preprocessor guard at
 * the call site. Lines are tagged @c RBPDBG so they can be captured on device with
 * @c idevicesyslog piped through @c grep.
 */

//
//  neDebugLog.h
//  REFLEC BEAT plus
//
//  Optional runtime diagnostics. Emits os_log lines tagged "RBPDBG" so they can be captured on
//  device with:  idevicesyslog | grep RBPDBG
//
//  This code is NOT part of the original binary. It is compiled in only when the build defines
//  RBPDBG (see the RBPDBG CMake option, which is enable-able in any build configuration and is
//  turned on in CI). With RBPDBG off the helpers below collapse to no-ops, so every translation
//  unit that only logs matches the reconstructed original exactly -- WITHOUT any `#if RBPDBG` at
//  the call site:
//
//    * neDebugLog(...) becomes an empty inline, so a bare log call vanishes.
//    * NE_DBG_FIRST(n) becomes `(0)`, so an `if (NE_DBG_FIRST(n)) { ... }` block turns into
//      `if (0) { ... }` and is dead-code-eliminated; debug-only locals declared inside the
//      block stay "used" within it, so -Werror stays quiet. Put all diagnostic work inside that
//      block.
//    * NE_DBG(...) wraps debug statements that have real side effects we must NOT run in the
//      faithful build (for example glGetError(), which clears GL error state). It expands to the
//      statements when RBPDBG is on and to nothing otherwise.
//

#pragma once

/**
 * @brief Whether the optional runtime diagnostics are compiled in.
 *
 * Defaults to zero when the build system does not define it, which selects the no-op helpers
 * below.
 */
#ifndef RBPDBG
#define RBPDBG 0
#endif

#if RBPDBG

// The C spellings, not <cstdarg>/<cstdio>: this header is included from pure Objective-C (.m)
// translation units, where the C++ headers do not exist.
#include <os/log.h>
#include <stdarg.h>
#include <stdio.h>

/**
 * @brief Emits one printf-style diagnostic line through @c os_log.
 *
 * Works in @c .c, @c .m, @c .cpp, and @c .mm translation units alike; @c os_log lines are what
 * @c idevicesyslog captures.
 * @param fmt The printf-style format string.
 * @param ... The format's arguments.
 */
static inline void neDebugLog(const char *fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    os_log(OS_LOG_DEFAULT, "RBPDBG %{public}s", buf);
}

/**
 * @brief A call counter helper: returns true for the first @p limit invocations at a given site.
 *
 * A per-frame draw call can therefore log a bounded burst instead of flooding the log at 60 fps.
 * This is a statement expression rather than a lambda so that it compiles in the project's pure
 * Objective-C (@c .m) translation units as well as the C++ ones.
 * @param limit The number of invocations at this site that evaluate to true.
 */
#define NE_DBG_FIRST(limit)                                                                        \
    __extension__({                                                                                \
        static int _c = 0;                                                                         \
        _c < (limit) ? (++_c, 1) : 0;                                                              \
    })

/**
 * @brief Wraps debug-only statements that have real side effects.
 *
 * Expands to the statements when @c RBPDBG is on and to nothing otherwise, so a call such as
 * @c glGetError(), which clears GL error state, never runs in the faithful build. An internal
 * semicolon separates multiple statements; the macro supplies the trailing one.
 * @param ... The statements to run only under @c RBPDBG.
 */
#define NE_DBG(...)                                                                                \
    do {                                                                                           \
        __VA_ARGS__;                                                                               \
    } while (0)

#else

/**
 * @brief The no-op fallback build of @c neDebugLog.
 *
 * A bare, unguarded log call still compiles away to nothing.
 * @param fmt Ignored in this build.
 * @param ... Ignored in this build.
 */
static inline void neDebugLog(const char *fmt, ...) {
    (void)fmt;
}

/**
 * @brief The no-op fallback build of @c NE_DBG_FIRST, which is always false.
 *
 * It collapses an `if (NE_DBG_FIRST(n)) { ... }` block to dead code that the optimiser drops.
 * The expansion is a plain @c 0 rather than @c false, which is a keyword only in C++ and would
 * need the @c stdbool.h header in the pure Objective-C translation units.
 * @param limit Ignored in this build.
 */
#define NE_DBG_FIRST(limit) (0)
/**
 * @brief The no-op fallback build of @c NE_DBG: the wrapped statements are not compiled in.
 * @param ... The debug-only statements, which do not run in this build.
 */
#define NE_DBG(...) ((void)0)

#endif

/**
 * @brief The build's git SHA, set by CMake at configure time.
 *
 * Logged once at startup under @c RBPDBG so a captured @c os_log identifies exactly which build
 * produced it. It falls back to @c "unknown" when the build system does not define it.
 */
#ifndef RBPDBG_BUILD_SHA
#define RBPDBG_BUILD_SHA "unknown"
#endif
