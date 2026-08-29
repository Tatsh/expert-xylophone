target_sources(rbplus PRIVATE
    ctask.mm
    customize_variant_tables.mm
    deviceenvironment.mm
    enginecrypto.mm
    engineglobals.mm
    engineruntime.mm
    gamesystem.mm
    leveltables.mm
    linear_tween.cpp
    note_path_point_array.cpp
    note_replay.mm
    number_effect_layer.mm
    pause_gauge_layer.mm
    playtimer.mm
    sheetlayer.cpp
    sprite_uv_table.cpp
    touchmanager.cpp
    ctask.h
    customize_variant_tables.h
    deviceenvironment.h
    deviceenvironment_globals.h
    enginecrypto.h
    engineglobals.h
    engineruntime.h
    gamesystem.h
    leveltables.h
    linear_tween.h
    ne_c_time.h
    neDebugLog.h
    note_path_point_array.h
    note_replay.h
    number_effect_layer.h
    pause_gauge_layer.h
    playtimer.h
    sheetlayer.h
    sprite_uv_table.h
    texture_cache_control.h
    touch_point.h
    touchmanager.h
)

target_include_directories(rbplus PRIVATE .)

add_subdirectory(Audio)
add_subdirectory(OpenGL)
add_subdirectory(Render)
add_subdirectory(Sound)
