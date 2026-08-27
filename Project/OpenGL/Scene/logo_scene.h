/**
 * @file
 * The boot logo scene, @c rb::LogoScene (RTTI @c N2rb9LogoSceneE).
 */

#pragma once

#include "basescene.h"
#include "linear_tween.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

namespace rb {

/**
 * @brief The boot logo scene: the opening screen that shows the corporate and rating logos and
 * waits for a touch to start the application.
 *
 * The first scene registered after launch. It loads the konami, bemani, and rating (nonage) logo
 * textures, sweeps them on with a set of animation curves, and, once the caution notice has been
 * acknowledged and enough time has passed, starts the application on the first touch (or after a
 * timeout). It derives from @c rb::BaseScene (and thus the @c ne::C_TASK per-frame node) and drives
 * its own three-state machine through the per-frame dispatch. The trailing @c // +0xNN comments
 * document the original member offsets for reference only.
 */
class LogoScene : public BaseScene {
public:
    /**
     * @brief The number of logo sprite layers the scene sweeps on (konami, bemani, rating, and two
     * more).
     */
    static constexpr int kLayerCount = 5;
    /** @brief The number of ref-counted logo textures the scene owns (konami, bemani, and rating).
     */
    static constexpr int kTextureCount = 3;

    /**
     * @brief Constructs the logo scene: chains the scene-base constructor, installs the logo
     * dispatch table, and zero-clears its animation, fade, and sprite state (seeding the fade
     * progress to one).
     * @ghidraAddress 0x149a04
     */
    LogoScene();

    /**
     * @brief Destroys the logo scene: releases the three logo textures, flags the five logo sprite
     * instancers for deferred deletion, and chains the base destructor.
     *
     * The compiler emits the deleting-destructor variant at @c 0x149b08 (which runs this body then
     * frees the object); it folds into this one destructor.
     * @ghidraAddress 0x149a6c
     * @ghidraAddress 0x149b08
     */
    ~LogoScene() override;

    /**
     * @brief The per-frame dispatch (vtable slot 0): runs the handler for the current state (0
     * initialise, 1 present, 2 start), and does nothing for any other state.
     * @param nElapsedMs The frame delta, in milliseconds.
     * @ghidraAddress 0x149b40
     */
    void OnFrame(int nElapsedMs) override;

private:
    /**
     * @brief State 0: loads the three logo textures, builds the five logo sprite instancers and
     * binds their sources, loads the sound effects, seeds the fade tween, and advances to the
     * present state.
     * @ghidraAddress 0x149b68
     */
    void Initialise();

    /**
     * @brief State 1: advances the present animation by the frame delta, latches the start once the
     * caution notice is acknowledged and a touch arrives (or a timeout elapses), computes the fade,
     * and positions the logo sprites along their animation curves.
     * @param nDeltaMs The frame delta, in milliseconds.
     * @ghidraAddress 0x149c5c
     */
    void Present(int nDeltaMs);

    /**
     * @brief State 2: once the audio system is ready, starts the application, persists the
     * caution-notice acknowledgement, and flags the scene dead so the dispatcher destroys it.
     * @ghidraAddress 0x149ec8
     */
    void Start();

    /**
     * @brief Advances the fade channel by @p nDeltaMs.
     * @ghidraAddress 0x149ff4
     */
    void CalculateFade(int nDeltaMs);

    /**
     * @brief Positions and fills one logo sprite layer's instancer slot, if it has a free slot.
     *
     * A no-op for an out-of-range kind or a full instancer. The three textured kinds (1..3) bind
     * their instancer's texture and derive the anchor, size, and UV span from its pixel size,
     * allocated size, and retina scale. The two backdrop kinds (0 and 4) draw a full-viewport quad
     * sized from the game system, white for kind 0 and black for kind 4.
     * @param nKind The sprite kind, also the layer index (0..4).
     * @param pPosition The sprite's screen position.
     * @param flScale The sprite's uniform scale.
     * @param nAlpha The sprite's alpha.
     * @ghidraAddress 0x14a040
     */
    void SetTitleSprite(unsigned int nKind, const S_VECTOR2 *pPosition, float flScale, int nAlpha);

    int m_nState = {};     // +0x4c: the scene state (0, 1, or 2).
    int m_nElapsedMs = {}; // +0x50: the present animation clock, in ms.
    // unsigned char m_aReserved54[4] = {};  // +0x54
    ne::C_TEXTURE *m_pKonamiTexture = {}; // +0x58: the konami logo texture.
    ne::C_TEXTURE *m_pBemaniTexture = {}; // +0x60: the bemani logo texture.
    ne::C_TEXTURE *m_pRatingTexture = {}; // +0x68: the rating (nonage) logo texture.
    ne::C_SPRITE_INSTANCING_2D *m_apLayers[kLayerCount] = {}; // +0x70: the five logo sprite layers.
    int m_aLayerState98[kLayerCount] = {}; // +0x98: per-layer state (cleared at construction).
    int m_aLayerStateAc[kLayerCount] = {}; // +0xac: per-layer state (cleared at construction).
    bool m_bStarted = {};                  // +0xc0: latched once the start has been triggered.
    // unsigned char m_aReservedC1[3] = {};   // +0xc1
    LinearTween m_fade; // +0xc4: the logo fade tween (seeded current to one).
};

} // namespace rb

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
