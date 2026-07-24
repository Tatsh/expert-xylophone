/**
 * @file
 * The global game-system singleton, @c GameSystem.
 */

#pragma once

#include "Render/s_vector2.h"
#include "gamescene.h"

/**
 * The global game-system singleton. Its setters are compiled inline in the binary as writes to the
 * named fields below; the 32-bit offset comments are documentation only.
 */
class GameSystem {
public:
    /** @brief Returns the screen origin x coordinate, in points. */
    double GetScreenX() const {
        return m_dScreenX;
    }
    /** @brief Stores the screen origin x coordinate, in points. */
    void SetScreenX(double value) {
        m_dScreenX = value;
    }
    /** @brief Returns the screen origin y coordinate, in points. */
    double GetScreenY() const {
        return m_dScreenY;
    }
    /** @brief Stores the screen origin y coordinate, in points. */
    void SetScreenY(double value) {
        m_dScreenY = value;
    }
    /** @brief Returns the screen width, in points. */
    double GetScreenWidth() const {
        return m_dScreenWidth;
    }
    /** @brief Stores the screen width, in points. */
    void SetScreenWidth(double value) {
        m_dScreenWidth = value;
    }
    /** @brief Returns the screen height, in points. */
    double GetScreenHeight() const {
        return m_dScreenHeight;
    }
    /** @brief Stores the screen height, in points. */
    void SetScreenHeight(double value) {
        m_dScreenHeight = value;
    }
    /** @brief Returns the screen scale factor. */
    float GetScreenScale() const {
        return m_flScreenScale;
    }
    /** @brief Stores the screen scale factor. */
    void SetScreenScale(float value) {
        m_flScreenScale = value;
    }
    /** @brief Returns the GL viewport width, in pixels. */
    float GetViewportWidth() const {
        return m_flViewportWidth;
    }
    /** @brief Stores the GL viewport width, in pixels. */
    void SetViewportWidth(float value) {
        m_flViewportWidth = value;
    }
    /** @brief Returns the GL viewport height, in pixels. */
    float GetViewportHeight() const {
        return m_flViewportHeight;
    }
    /** @brief Stores the GL viewport height, in pixels. */
    void SetViewportHeight(float value) {
        m_flViewportHeight = value;
    }
    /** @brief Returns the far-plane x extent of the note sheet. */
    float GetSheetFarX() const {
        return m_flSheetFarX;
    }
    /** @brief Returns the far-plane y extent of the note sheet. */
    float GetSheetFarY() const {
        return m_flSheetFarY;
    }
    /** @brief Returns the play-field scale. */
    float GetPlayfieldScale() const {
        return m_flPlayfieldScale;
    }
    /** @brief Returns the camera pitch reference height used by the tilt projection. */
    float GetCameraPitchHeight() const {
        return m_flCameraPitchHeight;
    }
    /** @brief Stores the camera pitch reference height used by the tilt projection. */
    void SetCameraPitchHeight(float value) {
        m_flCameraPitchHeight = value;
    }
    /** @brief Returns the cached target score used by the play screen. */
    int GetTargetScore() const {
        return m_nTargetScore;
    }
    /** @brief Stores the cached target score used by the play screen. */
    void SetTargetScore(int value) {
        m_nTargetScore = value;
    }
    /** @brief Returns the cached target achievement rate used by the play screen. */
    float GetTargetAR() const {
        return m_flTargetAR;
    }
    /** @brief Stores the cached target achievement rate used by the play screen. */
    void SetTargetAR(float value) {
        m_flTargetAR = value;
    }
    /**
     * @brief Reports whether the music-menu tutorial is suppressing the menu's gameplay input.
     *
     * The music-menu hub clears this at the start of its hide animation and sets it again while a
     * tutorial hide step is playing.
     */
    int GetMenuTutorialActive() const {
        return m_nMenuTutorialActive;
    }
    /** @brief Records whether the music-menu tutorial is suppressing the menu's gameplay input. */
    void SetMenuTutorialActive(int value) {
        m_nMenuTutorialActive = value;
    }
    /** @brief Reports whether this is the player's first play of the song. */
    bool GetIsFirstPlay() const {
        return m_fIsFirstPlay;
    }
    /** @brief Records whether this is the player's first play of the song. */
    void SetIsFirstPlay(bool value) {
        m_fIsFirstPlay = value;
    }
    /** @brief Returns the random seed used to drive gameplay. */
    unsigned int GetRandSeed() const {
        return m_dwRandSeed;
    }
    /** @brief Stores the random seed used to drive gameplay. */
    void SetRandSeed(unsigned int value) {
        m_dwRandSeed = value;
    }
    /** @brief Returns the note-sheet width. */
    float GetSheetWidth() const {
        return m_flSheetWidth;
    }
    /** @brief Stores the note-sheet width. */
    void SetSheetWidth(float value) {
        m_flSheetWidth = value;
    }
    /** @brief Returns the note-sheet height. */
    float GetSheetHeight() const {
        return m_flSheetHeight;
    }
    /** @brief Stores the note-sheet height. */
    void SetSheetHeight(float value) {
        m_flSheetHeight = value;
    }
    /** @brief Reports whether the 3D tilt sheet projection is enabled. */
    bool GetSheetLayerFlags() const {
        return m_fUse3dTiltProjection;
    }
    /** @brief Enables or disables the 3D tilt sheet projection from an integer flag. */
    void SetSheetLayerFlags(int value) {
        m_fUse3dTiltProjection = value != 0;
    }
    /** @brief Returns the camera target x coordinate. */
    float GetCameraTargetX() const {
        return m_flCameraTargetX;
    }
    /** @brief Stores the camera target x coordinate. */
    void SetCameraTargetX(float value) {
        m_flCameraTargetX = value;
    }
    /** @brief Returns the camera target y coordinate. */
    float GetCameraTargetY() const {
        return m_flCameraTargetY;
    }
    /** @brief Stores the camera target y coordinate. */
    void SetCameraTargetY(float value) {
        m_flCameraTargetY = value;
    }
    /** @brief Returns the selected game type. */
    int GetGameType() const {
        return m_nGameType;
    }
    /** @brief Stores the selected game type. */
    void SetGameType(int value) {
        m_nGameType = value;
    }
    /** @brief Returns the selected difficulty. */
    int GetDifficulty() const {
        return m_nDifficulty;
    }
    /** @brief Stores the selected difficulty. */
    void SetDifficulty(int value) {
        m_nDifficulty = value;
    }
    /** @brief Returns the selected difficulty level. */
    int GetDifficultyLevel() const {
        return m_nDifficultyLevel;
    }
    /** @brief Stores the selected difficulty level. */
    void SetDifficultyLevel(int value) {
        m_nDifficultyLevel = value;
    }
    /** @brief Returns the play colour. */
    int GetPlayColor() const {
        return m_nPlayColor;
    }
    /** @brief Stores the play colour. */
    void SetPlayColor(int value) {
        m_nPlayColor = value;
    }
    /** @brief Returns the player colour. */
    int GetPlayerColor() const {
        return m_nPlayerColor;
    }
    /** @brief Stores the player colour. */
    void SetPlayerColor(int value) {
        m_nPlayerColor = value;
    }
    /** @brief Returns the rival alpha. */
    float GetRivalAlpha() const {
        return m_flRivalAlpha;
    }
    /** @brief Stores the rival alpha. */
    void SetRivalAlpha(float value) {
        m_flRivalAlpha = value;
    }
    /** @brief Returns the shot volume. */
    float GetShotVolume() const {
        return m_flShotVolume;
    }
    /** @brief Stores the shot volume. */
    void SetShotVolume(float value) {
        m_flShotVolume = value;
    }
    /** @brief Returns the background brightness. */
    float GetBackgroundBrightness() const {
        return m_flBackgroundBrightness;
    }
    /** @brief Stores the background brightness. */
    void SetBackgroundBrightness(float value) {
        m_flBackgroundBrightness = value;
    }
    /** @brief Whether the play-field background fade-in has reached full opacity. */
    bool IsBackgroundFadeComplete() const {
        return m_fBackgroundFadeComplete;
    }
    /** @brief Records whether the play-field background fade-in has reached full opacity. */
    void SetBackgroundFadeComplete(bool bComplete) {
        m_fBackgroundFadeComplete = bComplete;
    }
    /** @brief Returns the shot cosmetic type. */
    int GetShotType() const {
        return m_nShotType;
    }
    /** @brief Stores the shot cosmetic type. */
    void SetShotType(int value) {
        m_nShotType = value;
    }
    /** @brief Returns the background-music cosmetic type. */
    int GetBgmType() const {
        return m_nBgmType;
    }
    /** @brief Stores the background-music cosmetic type. */
    void SetBgmType(int value) {
        m_nBgmType = value;
    }
    /** @brief Returns the frame cosmetic type. */
    int GetFrameType() const {
        return m_nFrameType;
    }
    /** @brief Stores the frame cosmetic type. */
    void SetFrameType(int value) {
        m_nFrameType = value;
    }
    /** @brief Returns the explosion cosmetic type. */
    int GetExplosionType() const {
        return m_nExplosionType;
    }
    /** @brief Stores the explosion cosmetic type. */
    void SetExplosionType(int value) {
        m_nExplosionType = value;
    }
    /** @brief Returns the background cosmetic type. */
    int GetBackgroundType() const {
        return m_nBackgroundType;
    }
    /** @brief Stores the background cosmetic type. */
    void SetBackgroundType(int value) {
        m_nBackgroundType = value;
    }
    /** @brief Returns the note cosmetic type. */
    int GetNoteType() const {
        return m_nNoteType;
    }
    /** @brief Stores the note cosmetic type. */
    void SetNoteType(int value) {
        m_nNoteType = value;
    }
    /** @brief Reports whether the CPU achieved a full combo. */
    bool GetCpuFullCombo() const {
        return m_fCpuFullCombo;
    }
    /** @brief Records whether the CPU achieved a full combo. */
    void SetCpuFullCombo(bool value) {
        m_fCpuFullCombo = value;
    }
    /** @brief Reports whether the user achieved a full combo. */
    bool GetUserFullCombo() const {
        return m_fUserFullCombo;
    }
    /** @brief Records whether the user achieved a full combo. */
    void SetUserFullCombo(bool value) {
        m_fUserFullCombo = value;
    }
    /** @brief Reports whether every reflec was a full-just. */
    bool GetFullJustReflec() const {
        return m_fFullJustReflec;
    }
    /** @brief Records whether every reflec was a full-just. */
    void SetFullJustReflec(bool value) {
        m_fFullJustReflec = value;
    }
    /** @brief Reports whether background music is currently playing. */
    bool GetBgmPlaying() const {
        return m_fBgmPlaying;
    }
    /**
     * @brief Stores the sheet-layer base position and recomputes its derived anchor points.
     * @ghidraAddress 0x12f33c
     */
    void SetSheetLayerPosition(S_VECTOR2 *pPosition);
    /**
     * @brief Recomputes the note-sheet layer position and margins for the current screen and the
     *        given speed type.
     * @ghidraAddress 0x8ef60
     */
    void ConfigureSheetLayerForScreen(int speedType);
    /** @brief Returns the active game scene, or @c nullptr when none is running. */
    GameScene *GetCurrentScene() const;
    /**
     * @brief Returns the global GameSystem singleton, constructing it on first use.
     * @ghidraAddress 0x12edb4
     */
    static GameSystem *GetGameSystem();

private:
    double m_dScreenX = {};              // +0x08
    double m_dScreenY = {};              // +0x10
    double m_dScreenWidth = {};          // +0x18
    double m_dScreenHeight = {};         // +0x20
    float m_flScreenScale = {};          // +0x28
    float m_flViewportWidth = {};        // +0x2c
    float m_flViewportHeight = {};       // +0x30
    bool m_fBackgroundFadeComplete = {}; // +0x34
    bool m_fUse3dTiltProjection = {};    // +0x35
    void *m_pMusicNameTexture = {};      // +0x48
    float m_flSheetPosX = {};            // +0x58
    float m_flSheetPosY = {};            // +0x5c
    float m_flSheetMarginLeft = {};      // +0x60
    float m_flSheetMarginTop = {};       // +0x64
    float m_flSheetMarginRight = {};     // +0x68
    float m_flSheetMarginBottom = {};    // +0x6c
    float m_flSheetRadius = {};          // +0x70
    float m_flCameraTargetX = {};        // +0x74
    float m_flCameraTargetY = {};        // +0x78
    float m_flSheetFarX = {};            // +0x7c
    float m_flSheetFarY = {};            // +0x80
    float m_flSheetInsetX = {};          // +0x84
    float m_flSheetInsetY = {};          // +0x88
    float m_flSheetInsetHalfX = {};      // +0x8c
    float m_flSheetInsetHalfY = {};      // +0x90
    float m_flSheetRadiusHalf = {};      // +0x94
    float m_flSheetDiameterSq = {};      // +0x98
    float m_flSheetRadiusScaled = {};    // +0x9c
    float m_flSheetWidth = {};           // +0xa0
    float m_flSheetHeight = {};          // +0xa4
    float m_flCameraPitchHeight = {};    // +0xa8
    bool m_fBgmPlaying = {};             // +0xac
    int m_nGameType = {};                // +0xb0
    int m_nPlayerColor = {};             // +0xb4
    int m_nPlayColor = {};               // +0xb8
    int m_nTargetScore = {};             // +0xc4
    float m_flTargetAR = {};             // +0xc8
    int m_nDifficulty = {};              // +0xcc
    int m_nDifficultyLevel = {};         // +0xd0
    unsigned int m_dwRandSeed = {};      // +0xd4
    int m_nShotType = {};                // +0xd8
    int m_nBgmType = {};                 // +0xdc
    int m_nFrameType = {};               // +0xe0
    int m_nExplosionType = {};           // +0xe4
    int m_nBackgroundType = {};          // +0xe8
    int m_nNoteType = {};                // +0xec
    float m_flShotVolume = {};           // +0xf0
    float m_flBackgroundBrightness = {}; // +0xf4
    float m_flRivalAlpha = {};           // +0xf8
    int m_nComboCount = {};              // +0xfc
    int m_nPastelBonusType = {};         // +0x100
    bool m_fIsFirstPlay = {};            // +0x104
    int m_nPlayerLevel = {};             // +0x108
    int m_nPlayerExp = {};               // +0x10c
    int m_nGainedExp = {};               // +0x110
    int m_nMenuTutorialActive = {};      // +0x12c
    float m_flPlayfieldScale = {};       // +0x134
    bool m_fCpuFullCombo = {};           // +0x138
    bool m_fUserFullCombo = {};          // +0x139
    bool m_fFullJustReflec = {};         // +0x13a
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
