# CMakeLists.txt — Project/Views/Music
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    RBMusicARView.m
    RBMusicCPUView.mm
    RBMusicColorBar.m
    RBMusicColorView.mm
    RBMusicDifficultyView.mm
    RBMusicExtendNoteView.m
    RBMusicFirstInfoView.m
    RBMusicHistoryView.m
    RBMusicOtherView.mm
    RBMusicScoreView.m
    RBMusicSearchExpander.m
    RBMusicSpeedView.mm
    RBMusicView.mm
    RBMusicARView.h
    RBMusicCPUView.h
    RBMusicColorBar.h
    RBMusicColorView.h
    RBMusicDifficultyView.h
    RBMusicExtendNoteView.h
    RBMusicFirstInfoView.h
    RBMusicHistoryView.h
    RBMusicOtherView.h
    RBMusicScoreView.h
    RBMusicSearchExpander.h
    RBMusicSpeedView.h
    RBMusicView.h
)

target_include_directories(rbplus PRIVATE .)
