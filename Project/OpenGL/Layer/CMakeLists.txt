target_sources(rbplus PRIVATE
    background_sprite_manager.mm
    event_effect_layer.mm
    keyframe_step_table.mm
    playerfieldlayer.mm
    playfieldlayerbase.mm
    title_part_layout_data.mm
    titleclassicscene.mm
    titlecolettescene.mm
    titlecolettescene_data.mm
    titlelimelightscene.mm
    tutorial_guide_layer.mm
    background_sprite_manager.h
    campaign_portrait_table.h
    event_effect_layer.h
    keyframe_step_table.h
    playerfieldlayer.h
    playfieldlayerbase.h
    title_anim_table.h
    title_part_layout.h
    titleclassicscene.h
    titlecolettescene.h
    titlelimelightscene.h
    tutorial_guide_layer.h
)

target_include_directories(rbplus PRIVATE .)

add_subdirectory(Classic)
add_subdirectory(Colette)
add_subdirectory(Limelight)
add_subdirectory(Share)
