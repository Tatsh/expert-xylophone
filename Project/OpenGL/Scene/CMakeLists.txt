# CMakeLists.txt — Project/OpenGL/Scene
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    basescene.mm
    game_scene.mm
    logo_scene.mm
    basescene.h
    game_scene.h
    logo_scene.h
)

target_include_directories(rbplus PRIVATE .)
