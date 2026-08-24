THEOS_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
PROJECT_ROOT       := $(patsubst %/,%,$(dir $(THEOS_MAKEFILE_DIR)))

# The CMake build names the app "REFLEC BEAT plus"; Theos variable prefixes cannot
# contain spaces, so this project is ReflecBeatPlus here (see Resources/Info.plist).
export ARCHS  = arm64 arm64e
export TARGET = iphone:clang:latest:12.0

# These mirror the CMake cache entries of the same names: the pieces of every secure API endpoint,
# and Konami's Applilink SDK identifiers and per-environment base URLs. Each defaults to what the
# shipped binary uses and reaches the sources as an RB_-prefixed macro (see Project/RBMacros.h), so
# an unconfigured build is unchanged. Override on the command line, for example
# `make -C theos API_HOST=my.server.example API_BASE_PATH=/cgi/`.
API_SCHEME    ?= https
API_HOST      ?= akx.s.konaminet.jp
API_BASE_PATH ?= /akx/main/cgi/

# The Applilink environment selector is "0" production, "1" staging, "2" and "3" sandbox, and
# "4" development; each selects one of the base URLs below.
APPLILINK_APP_ID          ?= 10
APPLILINK_ENV             ?= 0
APPLILINK_URL_PRODUCTION  ?= https://www.applilink.jp
APPLILINK_URL_STAGING     ?= https://st.es.i-revoinf.jp
APPLILINK_URL_DEVELOPMENT ?= https://dev.es.i-revoinf.jp
APPLILINK_URL_SANDBOX     ?= https://sandbox.applilink.jp

API_DEFINES := -DRB_API_SCHEME='"$(API_SCHEME)"' \
               -DRB_API_HOST='"$(API_HOST)"' \
               -DRB_API_BASE_PATH='"$(API_BASE_PATH)"' \
               -DRB_APPLILINK_APP_ID='"$(APPLILINK_APP_ID)"' \
               -DRB_APPLILINK_ENV='"$(APPLILINK_ENV)"' \
               -DRB_APPLILINK_URL_PRODUCTION='"$(APPLILINK_URL_PRODUCTION)"' \
               -DRB_APPLILINK_URL_STAGING='"$(APPLILINK_URL_STAGING)"' \
               -DRB_APPLILINK_URL_DEVELOPMENT='"$(APPLILINK_URL_DEVELOPMENT)"' \
               -DRB_APPLILINK_URL_SANDBOX='"$(APPLILINK_URL_SANDBOX)"'

# ENABLE_PATCHES mirrors the CMake option of the same name: it compiles in the preservation
# patches guarded by #ifdef ENABLE_PATCHES. Off by default so a plain build matches the binary;
# enable with `make -C theos ENABLE_PATCHES=1`.
ENABLE_PATCHES ?= 0
ifneq ($(ENABLE_PATCHES),0)
PATCH_DEFINES := -DENABLE_PATCHES=1
else
PATCH_DEFINES :=
endif

# SKIP_TUTORIAL mirrors the CMake option of the same name: it suppresses the first-run walkthroughs.
# It only takes effect alongside ENABLE_PATCHES, because the gates it removes are guarded by both;
# enable with `make -C theos ENABLE_PATCHES=1 SKIP_TUTORIAL=1`.
SKIP_TUTORIAL ?= 0
ifneq ($(ENABLE_PATCHES),0)
ifneq ($(SKIP_TUTORIAL),0)
PATCH_DEFINES += -DSKIP_TUTORIAL=1
endif
endif

# RBPDBG mirrors the CMake option of the same name: it compiles in the os_log diagnostics declared
# in Project/GameSystem/src/neDebugLog.h. Off by default so a plain build matches the binary; enable
# with `make -C theos RBPDBG=1`. The build SHA stamps the startup banner so a captured log
# identifies which build produced it.
RBPDBG ?= 0
ifneq ($(RBPDBG),0)
RBPDBG_BUILD_SHA := $(shell git -C $(PROJECT_ROOT) rev-parse --short=12 HEAD 2>/dev/null \
                            || echo unknown)
DEBUG_DEFINES := -DRBPDBG=1 -DRBPDBG_BUILD_SHA='"$(RBPDBG_BUILD_SHA)"'
else
DEBUG_DEFINES :=
endif

# RBPDBGINFO emits DWARF and keeps the symbol table, so lldb can read locals and struct members on
# the device instead of being reduced to `memory read` at hand-computed offsets. It deliberately
# does not touch the optimisation level: changing that would change code generation, and a crash
# under investigation has to reproduce identically to the build that showed it. Enable with
# `make -C theos RBPDBGINFO=1`, usually alongside RBPDBG=1.
RBPDBGINFO ?= 0
ifneq ($(RBPDBGINFO),0)
# Do not add FINALPACKAGE=1 alongside this: that is what strips the result.
DEBUG_INFO_FLAGS := -g -fstandalone-debug -fno-omit-frame-pointer
else
DEBUG_INFO_FLAGS :=
endif

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = ReflecBeatPlus

ReflecBeatPlus_FILES = $(shell find $(PROJECT_ROOT)/Project \
                           \( -name '*.m' -o -name '*.mm' -o -name '*.c' -o -name '*.cpp' \)) \
                       $(PROJECT_ROOT)/3rdparty/DAProgressOverlayView/DAProgressOverlayView.m \
                       $(PROJECT_ROOT)/3rdparty/SSZipArchive/SSZipArchive.m \
                       $(PROJECT_ROOT)/3rdparty/ziparchive/UnZipArchive.mm \
                       $(wildcard $(PROJECT_ROOT)/3rdparty/SSZipArchive/minizip/*.c)

ReflecBeatPlus_WARNINGS = -Wall -Wextra -Wshadow -Wcomma -Wnewline-eof -Wpointer-arith \
                          -Wimplicit-fallthrough -Wunreachable-code -Wconditional-uninitialized \
                          -Winfinite-recursion \
                          -Wundeclared-selector -Wblock-capture-autoreleasing \
                          -Wobjc-literal-conversion -Wduplicate-method-match \
                          -Wimplicit-retain-self
ReflecBeatPlus_CFLAGS  = -std=gnu2x -ftrivial-auto-var-init=zero -fobjc-arc -fobjc-exceptions \
                         -DGLES_SILENCE_DEPRECATION \
                         $(API_DEFINES) $(PATCH_DEFINES) $(DEBUG_DEFINES) $(DEBUG_INFO_FLAGS) \
                         $(ReflecBeatPlus_WARNINGS) \
                         -I$(PROJECT_ROOT)/Project \
                         $(addprefix -I,$(shell find $(PROJECT_ROOT)/Project -type d)) \
                         -I$(PROJECT_ROOT)/3rdparty/DAProgressOverlayView \
                         -I$(PROJECT_ROOT)/3rdparty/SSZipArchive \
                         -I$(PROJECT_ROOT)/3rdparty/ziparchive
ReflecBeatPlus_CCFLAGS = -std=gnu++2b -stdlib=libc++ -fno-char8_t \
                         -D_LIBCPP_ENABLE_ASSERTIONS=1 \
                         -Woverloaded-virtual -Wnon-virtual-dtor \
                         -Wdelete-non-abstract-non-virtual-dtor -Wrange-loop-analysis -Wextra-semi

# SSZipArchive's own podspec define set, needed by its bundled minizip too.
MINIZIP_DEFINES := -DHAVE_INTTYPES_H -DHAVE_PKCRYPT -DHAVE_STDINT_H -DHAVE_WZAES -DHAVE_ZLIB
$(PROJECT_ROOT)/3rdparty/SSZipArchive/SSZipArchive.m_CFLAGS = $(MINIZIP_DEFINES) -w
$(foreach _mz,$(wildcard $(PROJECT_ROOT)/3rdparty/SSZipArchive/minizip/*.c),\
    $(eval $(_mz)_CFLAGS = -std=gnu17 $(MINIZIP_DEFINES) -w))
$(PROJECT_ROOT)/3rdparty/DAProgressOverlayView/DAProgressOverlayView.m_CFLAGS = -w
$(PROJECT_ROOT)/3rdparty/ziparchive/UnZipArchive.mm_CFLAGS = $(MINIZIP_DEFINES) -w

ReflecBeatPlus_FRAMEWORKS = UIKit Foundation CoreFoundation CoreGraphics CoreImage QuartzCore \
                            OpenGLES AudioToolbox AVFoundation OpenAL CoreData StoreKit Social \
                            SafariServices GameKit CoreLocation MapKit AdSupport
ReflecBeatPlus_LDFLAGS    = -framework Security -lz $(DEBUG_INFO_FLAGS)

include $(THEOS)/makefiles/application.mk

# kate: hl Makefile;
