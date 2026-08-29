cmake_minimum_required(VERSION 3.14)

# Declared before project() so a docs-only configure declares no languages: the GitHub Pages runner
# is Linux and has no Objective-C compiler to probe for.
option(BUILD_DOCS "Build documentation." OFF)
option(BUILD_DOCS_ONLY "Build documentation only." OFF)

if(BUILD_DOCS_ONLY)
    project(ReflecBeatPlus VERSION 4.5.8 LANGUAGES NONE)
else()
    project(ReflecBeatPlus
            VERSION 4.5.8
            LANGUAGES C CXX OBJC OBJCXX)
endif()

if(BUILD_DOCS OR BUILD_DOCS_ONLY)
    set(DOXYGEN_USE_MDFILE_AS_MAINPAGE "${CMAKE_SOURCE_DIR}/README.md")
    set(DOXYGEN_GENERATE_HTML YES)
    set(DOXYGEN_JAVADOC_AUTOBRIEF YES)
    set(DOXYGEN_QT_AUTOBRIEF YES)
    # Without VERBATIM_VARS, CMake re-quotes the alias and the Doxygen-side quoting is lost.
    set(DOXYGEN_VERBATIM_VARS DOXYGEN_ALIASES)
    set(DOXYGEN_ALIASES [[ghidraAddress="\par Ghidra address:^^"]])
    set(DOXYGEN_ENABLE_PREPROCESSING YES)
    set(DOXYGEN_MACRO_EXPANSION YES)
    set(DOXYGEN_EXPAND_ONLY_PREDEF YES)
    set(DOXYGEN_PREDEFINED
        "NS_ENUM(type,name)=enum name : type"
        "NS_OPTIONS(type,name)=enum name : type"
        "NS_CLOSED_ENUM(type,name)=enum name : type")
    set(DOXYGEN_EXTRACT_LOCAL_CLASSES NO)
    set(DOXYGEN_EXCLUDE "${CMAKE_SOURCE_DIR}/Project/bf_init_bytes.inc")
    find_package(Doxygen REQUIRED)
    doxygen_add_docs(docs README.md Project ALL)
endif()
if(BUILD_DOCS_ONLY)
    return()
endif()

set(IOS_ARCHS "arm64" CACHE STRING "Space-separated architecture slices")
set(IOS_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum iOS version")
if(DEFINED DEPLOYMENT_TARGET)                 # leetal/ios-cmake spelling
    set(IOS_DEPLOYMENT_TARGET "${DEPLOYMENT_TARGET}")
endif()

set(XCODE_PATH ""            CACHE PATH "Path to Xcode developer dir (blank = xcode-select)")

set(APP_BUNDLE_ID    "jp.konami.rbplus"  CACHE STRING "CFBundleIdentifier")
set(APP_DISPLAY_NAME "Rb plus"           CACHE STRING "CFBundleDisplayName")
set(APP_VERSION      "4.5.8"             CACHE STRING "CFBundleShortVersionString")
set(APP_BUILD        "4.5.8"             CACHE STRING "CFBundleVersion")
set(RESOURCES_DIR    "" CACHE PATH "Directory of the ORIGINAL extracted .app whose resources "
                                   "(images, sounds, data files, fonts, ...) are copied "
                                   "verbatim into the built bundle. Leave empty to build code only.")

set(API_SCHEME    "https"              CACHE STRING "URL scheme of the game's secure API")
set(API_HOST      "akx.s.konaminet.jp" CACHE STRING "Hostname of the game's secure API")
set(API_BASE_PATH "/akx/main/cgi/"     CACHE STRING "CGI base path every endpoint is built under")

set(APPLILINK_APP_ID "10" CACHE STRING "Applilink application identifier")
set(APPLILINK_ENV    "0"  CACHE STRING
    "Applilink environment: 0 production, 1 staging, 2 and 3 sandbox, 4 development")
set(APPLILINK_URL_PRODUCTION  "https://www.applilink.jp"     CACHE STRING "Applilink production URL")
set(APPLILINK_URL_STAGING     "https://st.es.i-revoinf.jp"   CACHE STRING "Applilink staging URL")
set(APPLILINK_URL_DEVELOPMENT "https://dev.es.i-revoinf.jp"  CACHE STRING "Applilink development URL")
set(APPLILINK_URL_SANDBOX     "https://sandbox.applilink.jp" CACHE STRING "Applilink sandbox URL")

# Defaults OFF so an unconfigured build matches the shipped binary.
option(ENABLE_PATCHES "Compile in preservation patches (skip dead service flows)" OFF)
option(SKIP_TUTORIAL "Never start the first-run tutorials (requires ENABLE_PATCHES)" OFF)
option(RBPDBG "Compile in the RBPDBG runtime diagnostics (os_log)" OFF)

# The optimisation level is deliberately left alone: changing it changes code generation, and a
# crash under investigation has to reproduce identically to the build that showed it.
option(RBPDBGINFO "Emit debug info (DWARF) without altering optimisation" OFF)

if(NOT XCODE_PATH)
    find_program(XCODE_SELECT xcode-select)
    if(XCODE_SELECT)
        execute_process(COMMAND ${XCODE_SELECT} -p
                        OUTPUT_VARIABLE _xcp OUTPUT_STRIP_TRAILING_WHITESPACE
                        ERROR_QUIET RESULT_VARIABLE _xcr)
        if(_xcr EQUAL 0 AND _xcp)
            set(XCODE_PATH "${_xcp}")
        endif()
    endif()
endif()
if(XCODE_PATH AND EXISTS "${XCODE_PATH}")
    message(STATUS "ReflecBeatPlus: found Xcode/developer dir at ${XCODE_PATH}")
endif()
message(STATUS "ReflecBeatPlus: archs='${IOS_ARCHS}' iOS>=${IOS_DEPLOYMENT_TARGET}")

set(SYS_FRAMEWORKS
    UIKit Foundation CoreFoundation CoreGraphics CoreImage QuartzCore
    OpenGLES AudioToolbox AVFoundation OpenAL
    CoreData StoreKit Social
    Security SafariServices
    AdSupport
    GameKit CoreLocation MapKit)

set(INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist")
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in" "${INFO_PLIST}" @ONLY)

# Per-directory static libraries are deliberately not used: an Objective-C class referenced only by
# name or selector carries no link-time reference, so the linker strips it out of a static archive.
add_executable(rbplus MACOSX_BUNDLE)
target_include_directories(rbplus PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/Project")

add_subdirectory(Project)

set(_zip "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/SSZipArchive")
set(_dap "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/DAProgressOverlayView")
# The chart loader messages UnZipArchive by name; it builds against SSZipArchive's bundled minizip,
# which still provides the legacy unz/zip API.
set(_uza "${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/ziparchive")
set(_minizip_sources
    "${_zip}/minizip/mz_compat.c"
    "${_zip}/minizip/mz_crypt.c"
    "${_zip}/minizip/mz_crypt_apple.c"
    "${_zip}/minizip/mz_os.c"
    "${_zip}/minizip/mz_os_posix.c"
    "${_zip}/minizip/mz_strm.c"
    "${_zip}/minizip/mz_strm_buf.c"
    "${_zip}/minizip/mz_strm_mem.c"
    "${_zip}/minizip/mz_strm_os_posix.c"
    "${_zip}/minizip/mz_strm_pkcrypt.c"
    "${_zip}/minizip/mz_strm_split.c"
    "${_zip}/minizip/mz_strm_wzaes.c"
    "${_zip}/minizip/mz_strm_zlib.c"
    "${_zip}/minizip/mz_zip.c"
    "${_zip}/minizip/mz_zip_rw.c")
target_sources(rbplus PRIVATE
    "${_dap}/DAProgressOverlayView.m"
    "${_uza}/UnZipArchive.mm"
    "${_zip}/SSZipArchive.m"
    ${_minizip_sources})
target_include_directories(rbplus PRIVATE "${_zip}" "${_dap}" "${_uza}")
# C23 rejects some of vendored minizip's constructs, and this per-source -std lands after the
# target-wide one, so it wins. The defines are SSZipArchive's own podspec set.
set(_minizip_defines "HAVE_INTTYPES_H;HAVE_PKCRYPT;HAVE_STDINT_H;HAVE_WZAES;HAVE_ZLIB")
set_source_files_properties(${_minizip_sources}
    PROPERTIES COMPILE_OPTIONS "-std=gnu17;-w" COMPILE_DEFINITIONS "${_minizip_defines}")
set_source_files_properties("${_zip}/SSZipArchive.m" "${_dap}/DAProgressOverlayView.m"
    "${_uza}/UnZipArchive.mm"
    PROPERTIES COMPILE_OPTIONS "-w" COMPILE_DEFINITIONS "${_minizip_defines}")

# Real -flags rather than XCODE_ATTRIBUTE build settings, so they apply under every generator and
# can be overridden per source file.
target_compile_options(rbplus PRIVATE
    $<$<COMPILE_LANGUAGE:C,OBJC>:-std=gnu2x>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-std=gnu++2b>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-stdlib=libc++>
    # Keeps u8"" literals as char[]; C++20 otherwise makes them char8_t[].
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-fno-char8_t>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-fobjc-arc>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-fobjc-arc-exceptions>
    # The CI toolchain's libc++ predates _LIBCPP_HARDENING_MODE, so assertions are the effective
    # knob; newer libc++ still honours it.
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-D_LIBCPP_ENABLE_ASSERTIONS=1>
    -ftrivial-auto-var-init=zero)

# Warnings only -- there is no -Werror, so the build stays green. The conversion, cast, and pedantic
# families are left off: this reconstruction narrows and reinterpret-casts on purpose.
target_compile_options(rbplus PRIVATE
    -Wall
    -Wextra
    -Wshadow
    -Wcomma
    -Wnewline-eof
    -Wpointer-arith
    -Wimplicit-fallthrough
    -Wunreachable-code
    -Wconditional-uninitialized
    -Winfinite-recursion
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Woverloaded-virtual>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Wnon-virtual-dtor>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Wdelete-non-abstract-non-virtual-dtor>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Wrange-loop-analysis>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Wextra-semi>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wundeclared-selector>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wblock-capture-autoreleasing>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wobjc-literal-conversion>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wduplicate-method-match>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wimplicit-retain-self>)

# The reconstruction faithfully uses OpenGL ES 1.1, which iOS 12 deprecated wholesale with no
# in-place replacement.
target_compile_definitions(rbplus PRIVATE GLES_SILENCE_DEPRECATION)

# Each is consumed as a bare string literal by the matching RB_ macro in Project/RBMacros.h.
target_compile_definitions(rbplus PRIVATE
    RB_API_SCHEME="${API_SCHEME}"
    RB_API_HOST="${API_HOST}"
    RB_API_BASE_PATH="${API_BASE_PATH}"
    RB_APPLILINK_APP_ID="${APPLILINK_APP_ID}"
    RB_APPLILINK_ENV="${APPLILINK_ENV}"
    RB_APPLILINK_URL_PRODUCTION="${APPLILINK_URL_PRODUCTION}"
    RB_APPLILINK_URL_STAGING="${APPLILINK_URL_STAGING}"
    RB_APPLILINK_URL_DEVELOPMENT="${APPLILINK_URL_DEVELOPMENT}"
    RB_APPLILINK_URL_SANDBOX="${APPLILINK_URL_SANDBOX}")

target_compile_definitions(rbplus PRIVATE $<$<BOOL:${ENABLE_PATCHES}>:ENABLE_PATCHES=1>)

target_compile_definitions(rbplus PRIVATE
    $<$<AND:$<BOOL:${ENABLE_PATCHES}>,$<BOOL:${SKIP_TUTORIAL}>>:SKIP_TUTORIAL=1>)

target_compile_definitions(rbplus PRIVATE $<$<BOOL:${RBPDBG}>:RBPDBG=1>)

# Mirrors the debug-info flags theos/Makefile applies under RBPDBGINFO.
if(RBPDBGINFO)
  target_compile_options(rbplus PRIVATE -g -fstandalone-debug -fno-omit-frame-pointer)
  target_link_options(rbplus PRIVATE -g)
endif()

# Identifies which build produced a captured RBPDBG log.
execute_process(COMMAND git -C ${CMAKE_SOURCE_DIR} rev-parse --short=12 HEAD
                OUTPUT_VARIABLE RBPDBG_BUILD_SHA
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET)
if(NOT RBPDBG_BUILD_SHA)
    set(RBPDBG_BUILD_SHA "unknown")
endif()
target_compile_definitions(rbplus PRIVATE RBPDBG_BUILD_SHA="${RBPDBG_BUILD_SHA}")

set_target_properties(rbplus PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${INFO_PLIST}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${APP_BUNDLE_ID}"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${IOS_DEPLOYMENT_TARGET}"
    XCODE_ATTRIBUTE_ARCHS "${IOS_ARCHS}"
    XCODE_ATTRIBUTE_VALID_ARCHS "${IOS_ARCHS}"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "NO"
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    # This build is never submitted to the App Store.
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_SKIP_APP_STORE_DEPLOYMENT "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_LOCALIZABILITY_EMPTY_CONTEXT "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_DIVIDE_BY_ZERO "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_DEADCODE_DEADSTORES "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_NONNULL "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_NULL_DEREFERENCE "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_ATSYNC "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_COLLECTIONS "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_GENERICS "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_INCOMP_METHOD_TYPES "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_NSCFERROR "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_SELF_INIT "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_UNUSED_IVARS "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_SECURITY_BUFFER_OVERFLOW_EXPERIMENTAL "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_SECURITY_FLOATLOOPCOUNTER "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_USE_AFTER_MOVE "YES"
    XCODE_ATTRIBUTE_CLANG_STATIC_ANALYZER_MODE "Deep"
    XCODE_ATTRIBUTE_CLANG_STATIC_ANALYZER_MODE_ON_ANALYZE_ACTION "Deep"
    XCODE_ATTRIBUTE_CLANG_TIDY_BUGPRONE_ASSERT_SIDE_EFFECT "YES"
    XCODE_ATTRIBUTE_CLANG_TIDY_BUGPRONE_INFINITE_LOOP "YES"
    XCODE_ATTRIBUTE_CLANG_TIDY_BUGPRONE_MOVE_FORWARDING_REFERENCE "YES"
    OUTPUT_NAME "REFLEC BEAT plus")

foreach(_fw ${SYS_FRAMEWORKS})
    find_library(FW_${_fw} ${_fw})
    if(FW_${_fw})
        target_link_libraries(rbplus PRIVATE ${FW_${_fw}})
    else()
        target_link_libraries(rbplus PRIVATE "-framework ${_fw}")
    endif()
endforeach()
target_link_libraries(rbplus PRIVATE z)   # CommonCrypto is in libSystem; zlib for minizip

if(RESOURCES_DIR AND EXISTS "${RESOURCES_DIR}")
    file(GLOB RES_ENTRIES "${RESOURCES_DIR}/*")
    foreach(_res ${RES_ENTRIES})
        get_filename_component(_name "${_res}" NAME)
        if(NOT _name MATCHES "^(REFLEC BEAT plus|_CodeSignature|CodeResources|embedded\\.mobileprovision|Info\\.plist)$")
            target_sources(rbplus PRIVATE "${_res}")
            set_source_files_properties("${_res}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
        endif()
    endforeach()
    message(STATUS "ReflecBeatPlus: bundling resources from ${RESOURCES_DIR}")
else()
    message(WARNING "ReflecBeatPlus: RESOURCES_DIR not set — building CODE ONLY (links, but no assets).")
endif()

# kate: hl CMake; replace-tabs on; indent-width 4; tab-width 4;
