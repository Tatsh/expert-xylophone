# CMakeLists.txt — Project/GameSystem/src/OpenGL
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    neGLES.cpp
    neTexture.mm
    neTextureForiOS.mm
    neGLES.h
    neTexture.h
    neTextureForiOS.h
)

target_include_directories(rbplus PRIVATE .)
