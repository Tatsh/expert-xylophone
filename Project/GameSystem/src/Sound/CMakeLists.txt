# CMakeLists.txt — Project/GameSystem/src/Sound
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    audioformat.c
    avsemixer.mm
    cacamixer.mm
    casource.mm
    cavoice.mm
    AVBus.h
    audioformat.h
    avsemixer.h
    cacamixer.h
    casource.h
    cavoice.h
)

target_include_directories(rbplus PRIVATE .)
