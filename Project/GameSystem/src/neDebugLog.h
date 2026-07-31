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
#include <mach-o/dyld.h>
#include <os/log.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>

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

// Name the function containing a return address, for a trace that must identify its own caller.
// dladdr resolves in-process from the symbol table, so it needs no debugger and no entitlement.
static inline const char *neDebugCallerName(void *addr) {
    Dl_info info;
    if (dladdr(addr, &info) != 0 && info.dli_sname != NULL) {
        return info.dli_sname;
    }
    return "?";
}

// The same address as a static offset. The main executable's ASLR slide is subtracted, so the
// result is directly comparable against the reconstruction's own addresses.
static inline unsigned long neDebugCallerOffset(void *addr) {
    return (unsigned long)((intptr_t)addr - _dyld_get_image_vmaddr_slide(0));
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
