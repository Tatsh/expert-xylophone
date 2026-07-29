# CMakeLists.txt — Project/GameSystem/src/Audio
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    audiosourceslot.mm
    caplayermgr.mm
    shotsoundmanager.mm
    soundeffectmanager.mm
    audiosourceslot.h
    caplayermgr.h
    shotsoundmanager.h
    soundeffectmanager.h
)

target_include_directories(rbplus PRIVATE .)
