target_sources(rbplus PRIVATE
    music_sheet.mm
    note_chain_link.mm
    note_effect_mgr.mm
    note_lane_slot.mm
    note_lane_tracker.mm
    note_model.mm
    rbff_stream.mm
    rbffnoterecord.mm
    music_sheet.h
    note_chain_link.h
    note_effect_mgr.h
    note_lane_slot.h
    note_lane_tracker.h
    note_model.h
    rbff_chart_note.h
    rbff_stream.h
    rbffnoterecord.h
)

target_include_directories(rbplus PRIVATE .)
