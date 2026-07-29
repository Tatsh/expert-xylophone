# CMakeLists.txt — Project/OpenGL/Layer/Limelight
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    full_combo_limelight_layer.mm
    limelight_effect_layer.mm
    limelight_result_layer.mm
    limelight_theme_layer.mm
    full_combo_limelight_layer.h
    limelight_effect_layer.h
    limelight_parts_data_table.h
    limelight_result_layer.h
    limelight_theme_layer.h
)

target_include_directories(rbplus PRIVATE .)
