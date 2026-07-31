# CMakeLists.txt — Project/GameSystem/src/Render
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(rbplus PRIVATE
    curve.cpp
    neDrawPolygon2D.mm
    neDrawPolygon3D.mm
    neMatrix.mm
    neRender.mm
    neRenderer.mm
    neSpriteInstancing.mm
    neSpriteInstancing3D.mm
    polygon2d_trail.mm
    curve.h
    matrixmath.h
    neDrawPolygon2D.h
    neDrawPolygon3D.h
    neRender.h
    neRenderer.h
    neSpriteInstancing.h
    neSpriteInstancing3D.h
    polygon2d_trail.h
    s_vector2.h
    s_vector3.h
    vectormath.h
)

target_include_directories(rbplus PRIVATE .)
