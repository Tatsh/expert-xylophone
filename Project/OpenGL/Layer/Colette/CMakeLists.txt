# CMakeLists.txt — Project/OpenGL/Layer/Colette
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    colette_theme_layer.mm
    full_combo_colette_layer.mm
    number_layer.mm
    result_bonus_color_table.mm
    result_window_colette_layer.mm
    anchor_box_table.h
    colette_theme_layer.h
    full_combo_colette_layer.h
    full_combo_colette_sprite_table.h
    number_layer.h
    parts_data_table.h
    phone_anchor_table.h
    result_bonus_color_table.h
    result_layout_position_table.h
    result_window_colette_layer.h
)

target_include_directories(rbplus PRIVATE .)
