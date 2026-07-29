# CMakeLists.txt — Project/OpenGL/Layer/Classic
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    classicthemelayer.mm
    full_combo_classic_layer.mm
    result_window_classic_layer.mm
    classic_parts_data_table.h
    classicthemelayer.h
    full_combo_classic_layer.h
    full_combo_classic_sprite_table.h
    result_window_classic_layer.h
)

target_include_directories(rbplus PRIVATE .)
