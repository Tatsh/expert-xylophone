# CMakeLists.txt — Project/Util
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    Random.cpp
    Random.h
)

target_include_directories(rbplus PRIVATE .)
