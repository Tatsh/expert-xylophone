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
//    * NE_DBG_FIRST(n) becomes `(false)`, so an `if (NE_DBG_FIRST(n)) { ... }` block turns into
//      `if (false) { ... }` and is dead-code-eliminated; debug-only locals declared inside the
//      block stay "used" within it, so -Werror stays quiet. Put all diagnostic work inside that
//      block.
//    * NE_DBG(...) wraps debug statements that have real side effects we must NOT run in the
//      faithful build (for example glGetError(), which clears GL error state). It expands to the
//      statements when RBPDBG is on and to nothing otherwise.
//

#pragma once

#ifndef RBPDBG
#define RBPDBG 0
#endif

#if RBPDBG

// The C spellings, not <cstdarg>/<cstdio>: this header is included from pure Objective-C (.m)
// translation units, where the C++ headers do not exist.
#include <dlfcn.h>
#include <execinfo.h>
#include <os/log.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

// printf-style wrapper over os_log (works in .c, .m, .cpp, and .mm translation units alike; os_log
// lines are what idevicesyslog captures).
static inline void neDebugLog(const char *fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    os_log(OS_LOG_DEFAULT, "RBPDBG %{public}s", buf);
}

// A call counter helper: returns true for the first @c limit invocations at a given site, so a
// per-frame draw call can log a bounded burst instead of flooding the log at 60 fps. This is a
// statement expression rather than a lambda so that it compiles in the project's pure Objective-C
// (.m) translation units as well as the C++ ones.
#define NE_DBG_FIRST(limit)                                                                        \
    __extension__({                                                                                \
        static int _c = 0;                                                                         \
        _c < (limit) ? (++_c, 1) : 0;                                                              \
    })

// Name the nearest frame above the engine, for a trace that must identify which layer drove it.
// A return address one frame up is not enough: an allocation lands in a base constructor called
// from a derived one, and a deletion lands in the deleting destructor, so the immediate caller is
// always another engine routine. Walk out until a frame is not one, and resolve it with dladdr,
// which reads the in-process symbol table and so needs no debugger and no entitlement.
static inline const char *neDebugOwnerName(void) {
    void *frames[8];
    const int count = backtrace(frames, 8);
    // Frame 0 is this helper; start above it.
    for (int at = 1; at < count; ++at) {
        Dl_info info;
        if (dladdr(frames[at], &info) == 0 || info.dli_sname == NULL) {
            continue;
        }
        // Itanium-mangled `ne::` members all begin _ZN2ne; anything else is a caller worth naming.
        if (strncmp(info.dli_sname, "_ZN2ne", 6) != 0) {
            return info.dli_sname;
        }
    }
    return "?";
}

// A return address as an offset within its own image. dladdr reports that image's base, so this
// needs no dyld slide and is directly comparable against the reconstruction's addresses.
static inline unsigned long neDebugCallerOffset(void *addr) {
    Dl_info info;
    if (dladdr(addr, &info) == 0) {
        return 0;
    }
    return (unsigned long)((const char *)addr - (const char *)info.dli_fbase);
}

// Name the function containing a return address.
static inline const char *neDebugCallerName(void *addr) {
    Dl_info info;
    if (dladdr(addr, &info) != 0 && info.dli_sname != NULL) {
        return info.dli_sname;
    }
    return "?";
}

// Wrap debug-only statements with real side effects. Internal `;` separates multiple statements;
// the macro supplies the trailing one.
#define NE_DBG(...)                                                                                \
    do {                                                                                           \
        __VA_ARGS__;                                                                               \
    } while (0)

#else

// No-op fallbacks: a bare, unguarded log call still compiles away to nothing, and
// NE_DBG_FIRST(n) collapses an `if (...) { ... }` diagnostic block to dead code that the optimiser
// drops.
static inline void neDebugLog(const char *fmt, ...) {
    (void)fmt;
}

// The arguments of a disabled neDebugLog call are still evaluated, so these must exist in the
// faithful build too.
static inline const char *neDebugCallerName(void *addr) {
    (void)addr;
    return "?";
}

static inline unsigned long neDebugCallerOffset(void *addr) {
    (void)addr;
    return 0;
}

static inline const char *neDebugOwnerName(void) {
    return "?";
}

// A plain 0 rather than `false`, which is a keyword only in C++ and would need <stdbool.h> in the
// pure Objective-C translation units.
#define NE_DBG_FIRST(limit) (0)
#define NE_DBG(...) ((void)0)

#endif

// The build's git SHA (set by CMake at configure time). Logged once at startup under RBPDBG so a
// captured os_log identifies exactly which build produced it.
#ifndef RBPDBG_BUILD_SHA
#define RBPDBG_BUILD_SHA "unknown"
#endif

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
