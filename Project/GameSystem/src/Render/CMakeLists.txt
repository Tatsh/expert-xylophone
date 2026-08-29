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
