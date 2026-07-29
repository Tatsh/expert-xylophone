THEOS_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
PROJECT_ROOT       := $(patsubst %/,%,$(dir $(THEOS_MAKEFILE_DIR)))

# The CMake build names the app "REFLEC BEAT plus"; Theos variable prefixes cannot
# contain spaces, so this project is ReflecBeatPlus here (see Resources/Info.plist).
export ARCHS  = arm64 arm64e
export TARGET = iphone:clang:latest:12.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = ReflecBeatPlus

ReflecBeatPlus_FILES = $(shell find $(PROJECT_ROOT)/Project \
                           \( -name '*.m' -o -name '*.mm' -o -name '*.c' -o -name '*.cpp' \)) \
                       $(PROJECT_ROOT)/3rdparty/DAProgressOverlayView/DAProgressOverlayView.m \
                       $(PROJECT_ROOT)/3rdparty/SSZipArchive/SSZipArchive.m \
                       $(wildcard $(PROJECT_ROOT)/3rdparty/SSZipArchive/minizip/*.c)

ReflecBeatPlus_WARNINGS = -Wall -Wextra -Wshadow -Wcomma -Wnewline-eof -Wpointer-arith \
                          -Wimplicit-fallthrough -Wunreachable-code -Wconditional-uninitialized \
                          -Winfinite-recursion \
                          -Wundeclared-selector -Wblock-capture-autoreleasing \
                          -Wobjc-literal-conversion -Wduplicate-method-match \
                          -Wimplicit-retain-self
ReflecBeatPlus_CFLAGS  = -std=gnu2x -ftrivial-auto-var-init=zero -fobjc-arc -fobjc-exceptions \
                         -DGLES_SILENCE_DEPRECATION \
                         $(ReflecBeatPlus_WARNINGS) \
                         -I$(PROJECT_ROOT)/Project \
                         $(addprefix -I,$(shell find $(PROJECT_ROOT)/Project -type d)) \
                         -I$(PROJECT_ROOT)/3rdparty/DAProgressOverlayView \
                         -I$(PROJECT_ROOT)/3rdparty/SSZipArchive
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

ReflecBeatPlus_FRAMEWORKS = UIKit Foundation CoreFoundation CoreGraphics CoreImage QuartzCore \
                            OpenGLES AudioToolbox AVFoundation OpenAL CoreData StoreKit Social \
                            SafariServices GameKit CoreLocation MapKit
ReflecBeatPlus_LDFLAGS    = -framework Security -lz

include $(THEOS)/makefiles/application.mk

# kate: hl Makefile;
