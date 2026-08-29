/**
 * @file
 * The global game-system singleton, @c GameSystem.
 */

#pragma once

#include "Render/s_vector2.h"

#ifdef __OBJC__
@class MusicData;
#else
/** The Objective-C tune catalogue entry, opaque to a pure C++ translation unit. */
typedef struct objc_object MusicData;
#endif

namespace ne {
class C_TEXTURE;
}

namespace rb {
class GameScene;
}

/**
 * The global game-system singleton.
 *
 * Its setters are compiled inline in the binary as writes to the named fields below; the 32-bit
 * offset comments are documentation only.
 */
class GameSystem {
public:
    /**
     * Returns the screen origin x coordinate, in points.
     * @return The screen origin x coordinate, in points.
     */
    double GetScreenX() const {
        return m_dScreenX;
    }
    /**
     * Stores the screen origin x coordinate, in points.
     * @param value The screen origin x coordinate, in points.
     */
    void SetScreenX(double value) {
        m_dScreenX = value;
    }
    /**
     * Returns the screen origin y coordinate, in points.
     * @return The screen origin y coordinate, in points.
     */
    double GetScreenY() const {
        return m_dScreenY;
    }
    /**
     * Stores the screen origin y coordinate, in points.
     * @param value The screen origin y coordinate, in points.
     */
    void SetScreenY(double value) {
        m_dScreenY = value;
    }
    /**
     * Returns the screen width, in points.
     * @return The screen width, in points.
     */
    double GetScreenWidth() const {
        return m_dScreenWidth;
    }
    /**
     * Stores the screen width, in points.
     * @param value The screen width, in points.
     */
    void SetScreenWidth(double value) {
        m_dScreenWidth = value;
    }
    /**
     * Returns the screen height, in points.
     * @return The screen height, in points.
     */
    double GetScreenHeight() const {
        return m_dScreenHeight;
    }
    /**
     * Stores the screen height, in points.
     * @param value The screen height, in points.
     */
    void SetScreenHeight(double value) {
        m_dScreenHeight = value;
    }
    /**
     * Returns the screen scale factor.
     * @return The screen scale factor.
     */
    float GetScreenScale() const {
        return m_flScreenScale;
    }
    /**
     * Stores the screen scale factor.
     * @param value The screen scale factor.
     */
    void SetScreenScale(float value) {
        m_flScreenScale = value;
    }
    /**
     * Returns the GL viewport width, in pixels.
     * @return The GL viewport width, in pixels.
     */
    float GetViewportWidth() const {
        return m_flViewportWidth;
    }
    /**
     * Stores the GL viewport width, in pixels.
     * @param value The GL viewport width, in pixels.
     */
    void SetViewportWidth(float value) {
        m_flViewportWidth = value;
    }
    /**
     * Returns the GL viewport height, in pixels.
     * @return The GL viewport height, in pixels.
     */
    float GetViewportHeight() const {
        return m_flViewportHeight;
    }
    /**
     * Stores the GL viewport height, in pixels.
     * @param value The GL viewport height, in pixels.
     */
    void SetViewportHeight(float value) {
        m_flViewportHeight = value;
    }
    /**
     * Returns the note sheet's near-plane x position (half-width reference).
     * @return The note sheet's near-plane x position.
     */
    float GetSheetPosX() const {
        return m_flSheetPosX;
    }
    /**
     * Returns the note sheet's near-plane y position (half-height reference).
     * @return The note sheet's near-plane y position.
     */
    float GetSheetPosY() const {
        return m_flSheetPosY;
    }
    /**
     * Returns the far-plane x extent of the note sheet.
     * @return The far-plane x extent of the note sheet.
     */
    float GetSheetFarX() const {
        return m_flSheetFarX;
    }
    /**
     * Returns the far-plane y extent of the note sheet.
     * @return The far-plane y extent of the note sheet.
     */
    float GetSheetFarY() const {
        return m_flSheetFarY;
    }
    /**
     * Returns the note sheet's half-width inset, the across-field position scale.
     * @return The note sheet's half-width inset.
     */
    float GetSheetInsetHalfX() const {
        return m_flSheetInsetHalfX;
    }
    /**
     * Returns the note sheet's half-height inset, the toward-edge position scale.
     * @return The note sheet's half-height inset.
     */
    float GetSheetInsetHalfY() const {
        return m_flSheetInsetHalfY;
    }
    /**
     * Returns the note sheet's radius.
     * @return The note sheet's radius.
     */
    float GetSheetRadius() const {
        return m_flSheetRadius;
    }
    /**
     * Stores the note sheet's corner radius and recomputes everything derived from it.
     * @param fRadius The corner radius.
     * @ghidraAddress 0x12f3c4
     */
    void SetSheetLayerRadius(float fRadius);
    /**
     * Stores the note sheet's margins and recomputes the far corner.
     * @param fLeft The left margin.
     * @param fTop The top margin.
     * @param fRight The right margin.
     * @param fBottom The bottom margin.
     * @ghidraAddress 0x12f394
     */
    void SetSheetLayerMargins(float fLeft, float fTop, float fRight, float fBottom);
    /**
     * Returns the note sheet's half radius, the off-screen cull margin below the field.
     * @return The note sheet's half radius.
     */
    float GetSheetRadiusHalf() const {
        return m_flSheetRadiusHalf;
    }
    /**
     * Returns the note sheet's scaled radius, used as the slide-result sprite scale.
     * @return The note sheet's scaled radius.
     */
    float GetSheetRadiusScaled() const {
        return m_flSheetRadiusScaled;
    }
    /**
     * Returns the squared note-sheet diameter, the note touch-hit radius test.
     * @return The squared note-sheet diameter.
     */
    float GetSheetDiameterSq() const {
        return m_flSheetDiameterSq;
    }
    /**
     * Returns the play-field scale.
     * @return The play-field scale.
     */
    float GetPlayfieldScale() const {
        return m_flPlayfieldScale;
    }
    /**
     * Returns the camera pitch reference height used by the tilt projection.
     * @return The camera pitch reference height.
     */
    float GetCameraPitchHeight() const {
        return m_flCameraPitchHeight;
    }
    /**
     * Stores the camera pitch reference height used by the tilt projection.
     * @param value The camera pitch reference height.
     */
    void SetCameraPitchHeight(float value) {
        m_flCameraPitchHeight = value;
    }
    /**
     * Returns the cached target score used by the play screen.
     * @return The cached target score.
     */
    int GetTargetScore() const {
        return m_nTargetScore;
    }
    /**
     * Stores the cached target score used by the play screen.
     * @param value The target score.
     */
    void SetTargetScore(int value) {
        m_nTargetScore = value;
    }
    /**
     * Returns the cached target achievement rate used by the play screen.
     * @return The cached target achievement rate.
     */
    float GetTargetAR() const {
        return m_flTargetAR;
    }
    /**
     * Stores the cached target achievement rate used by the play screen.
     * @param value The target achievement rate.
     */
    void SetTargetAR(float value) {
        m_flTargetAR = value;
    }
    /**
     * Reports whether the music-menu tutorial is suppressing the menu's gameplay input.
     *
     * The music-menu hub clears this at the start of its hide animation and sets it again while a
     * tutorial hide step is playing.
     *
     * @return @c true while the tutorial is suppressing the menu's gameplay input.
     */
    bool GetMenuTutorialActive() const {
        return m_fMenuTutorialActive;
    }
    /**
     * Records whether the music-menu tutorial is suppressing the menu's gameplay input.
     * @param value @c true while the tutorial is suppressing the menu's gameplay input.
     */
    void SetMenuTutorialActive(bool value) {
        m_fMenuTutorialActive = value;
    }
    /**
     * Returns the in-play tutorial-guide phase.
     * @return The in-play tutorial-guide phase.
     */
    int GetTutorialPhase() const {
        return m_nTutorialPhase;
    }
    /**
     * Sets the in-play tutorial-guide phase.
     * @param nPhase The in-play tutorial-guide phase.
     */
    void SetTutorialPhase(int nPhase) {
        m_nTutorialPhase = nPhase;
    }
    /**
     * Reports whether this is the player's first play of the song.
     * @return @c true when this is the player's first play of the song.
     */
    bool GetIsFirstPlay() const {
        return m_fIsFirstPlay;
    }
    /**
     * Records whether this is the player's first play of the song.
     * @param value @c true when this is the player's first play of the song.
     */
    void SetIsFirstPlay(bool value) {
        m_fIsFirstPlay = value;
    }
    /**
     * Returns the random seed used to drive gameplay.
     * @return The random seed used to drive gameplay.
     */
    unsigned int GetRandSeed() const {
        return m_dwRandSeed;
    }
    /**
     * Stores the random seed used to drive gameplay.
     * @param value The random seed used to drive gameplay.
     */
    void SetRandSeed(unsigned int value) {
        m_dwRandSeed = value;
    }
    /**
     * Returns the note-sheet width.
     * @return The note-sheet width.
     */
    float GetSheetWidth() const {
        return m_flSheetWidth;
    }
    /**
     * Stores the note-sheet width.
     * @param value The note-sheet width.
     */
    void SetSheetWidth(float value) {
        m_flSheetWidth = value;
    }
    /**
     * Returns the note-sheet height.
     * @return The note-sheet height.
     */
    float GetSheetHeight() const {
        return m_flSheetHeight;
    }
    /**
     * Stores the note-sheet height.
     * @param value The note-sheet height.
     */
    void SetSheetHeight(float value) {
        m_flSheetHeight = value;
    }
    /**
     * Reports whether the 3D tilt sheet projection is enabled.
     * @return @c true when the 3D tilt sheet projection is enabled.
     */
    bool GetSheetLayerFlags() const {
        return m_fUse3dTiltProjection;
    }
    /**
     * Enables or disables the 3D tilt sheet projection from an integer flag.
     * @param value Non-zero to enable the 3D tilt sheet projection.
     */
    void SetSheetLayerFlags(int value) {
        m_fUse3dTiltProjection = value != 0;
    }
    /**
     * Returns the camera target x coordinate.
     * @return The camera target x coordinate.
     */
    float GetCameraTargetX() const {
        return m_flCameraTargetX;
    }
    /**
     * Stores the camera target x coordinate.
     * @param value The camera target x coordinate.
     */
    void SetCameraTargetX(float value) {
        m_flCameraTargetX = value;
    }
    /**
     * Returns the camera target y coordinate.
     * @return The camera target y coordinate.
     */
    float GetCameraTargetY() const {
        return m_flCameraTargetY;
    }
    /**
     * Stores the camera target y coordinate.
     * @param value The camera target y coordinate.
     */
    void SetCameraTargetY(float value) {
        m_flCameraTargetY = value;
    }
    /**
     * Returns the selected game type.
     * @return The selected game type.
     */
    int GetGameType() const {
        return m_nGameType;
    }
    /**
     * Stores the selected game type.
     * @param value The selected game type.
     */
    void SetGameType(int value) {
        m_nGameType = value;
    }
    /**
     * Returns the selected difficulty.
     * @return The selected difficulty.
     */
    int GetDifficulty() const {
        return m_nDifficulty;
    }
    /**
     * Stores the selected difficulty.
     * @param value The selected difficulty.
     */
    void SetDifficulty(int value) {
        m_nDifficulty = value;
    }
    /**
     * Returns the selected difficulty level.
     * @return The selected difficulty level.
     */
    int GetDifficultyLevel() const {
        return m_nDifficultyLevel;
    }
    /**
     * Stores the selected difficulty level.
     * @param value The selected difficulty level.
     */
    void SetDifficultyLevel(int value) {
        m_nDifficultyLevel = value;
    }
    /**
     * Returns the play colour.
     * @return The play colour.
     */
    int GetPlayColor() const {
        return m_nPlayColor;
    }
    /**
     * Stores the play colour.
     * @param value The play colour.
     */
    void SetPlayColor(int value) {
        m_nPlayColor = value;
    }
    /**
     * Returns the player colour.
     * @return The player colour.
     */
    int GetPlayerColor() const {
        return m_nPlayerColor;
    }
    /**
     * Stores the player colour.
     * @param value The player colour.
     */
    void SetPlayerColor(int value) {
        m_nPlayerColor = value;
    }
    /**
     * Returns the rival alpha.
     * @return The rival alpha.
     */
    float GetRivalAlpha() const {
        return m_flRivalAlpha;
    }
    /**
     * Stores the rival alpha.
     * @param value The rival alpha.
     */
    void SetRivalAlpha(float value) {
        m_flRivalAlpha = value;
    }
    /**
     * Returns the shot volume.
     * @return The shot volume.
     */
    float GetShotVolume() const {
        return m_flShotVolume;
    }
    /**
     * Stores the shot volume.
     * @param value The shot volume.
     */
    void SetShotVolume(float value) {
        m_flShotVolume = value;
    }
    /**
     * Returns the background brightness.
     * @return The background brightness.
     */
    float GetBackgroundBrightness() const {
        return m_flBackgroundBrightness;
    }
    /**
     * Stores the background brightness.
     * @param value The background brightness.
     */
    void SetBackgroundBrightness(float value) {
        m_flBackgroundBrightness = value;
    }
    /**
     * Whether the play-field background fade-in has reached full opacity.
     * @return @c true once the background fade-in has reached full opacity.
     */
    bool IsBackgroundFadeComplete() const {
        return m_fBackgroundFadeComplete;
    }
    /**
     * Records whether the play-field background fade-in has reached full opacity.
     * @param bComplete @c true once the background fade-in has reached full opacity.
     */
    void SetBackgroundFadeComplete(bool bComplete) {
        m_fBackgroundFadeComplete = bComplete;
    }
    /**
     * Returns the shot cosmetic type.
     * @return The shot cosmetic type.
     */
    int GetShotType() const {
        return m_nShotType;
    }
    /**
     * Stores the shot cosmetic type.
     * @param value The shot cosmetic type.
     */
    void SetShotType(int value) {
        m_nShotType = value;
    }
    /**
     * Returns the background-music cosmetic type.
     * @return The background-music cosmetic type.
     */
    int GetBgmType() const {
        return m_nBgmType;
    }
    /**
     * Stores the background-music cosmetic type.
     * @param value The background-music cosmetic type.
     */
    void SetBgmType(int value) {
        m_nBgmType = value;
    }
    /**
     * Returns the frame cosmetic type.
     * @return The frame cosmetic type.
     */
    int GetFrameType() const {
        return m_nFrameType;
    }
    /**
     * Stores the frame cosmetic type.
     * @param value The frame cosmetic type.
     */
    void SetFrameType(int value) {
        m_nFrameType = value;
    }
    /**
     * Returns the explosion cosmetic type.
     * @return The explosion cosmetic type.
     */
    int GetExplosionType() const {
        return m_nExplosionType;
    }
    /**
     * Stores the explosion cosmetic type.
     * @param value The explosion cosmetic type.
     */
    void SetExplosionType(int value) {
        m_nExplosionType = value;
    }
    /**
     * Returns the background cosmetic type.
     * @return The background cosmetic type.
     */
    int GetBackgroundType() const {
        return m_nBackgroundType;
    }
    /**
     * Stores the background cosmetic type.
     * @param value The background cosmetic type.
     */
    void SetBackgroundType(int value) {
        m_nBackgroundType = value;
    }
    /**
     * Returns the note cosmetic type.
     * @return The note cosmetic type.
     */
    int GetNoteType() const {
        return m_nNoteType;
    }
    /**
     * Stores the note cosmetic type.
     * @param value The note cosmetic type.
     */
    void SetNoteType(int value) {
        m_nNoteType = value;
    }
    /**
     * Returns the current combo count.
     * @return The current combo count.
     */
    int GetComboCount() const {
        return m_nComboCount;
    }
    /**
     * Stores the current combo count.
     * @param value The current combo count.
     */
    void SetComboCount(int value) {
        m_nComboCount = value;
    }
    /**
     * Reports whether the CPU achieved a full combo.
     * @return @c true when the CPU achieved a full combo.
     */
    bool GetCpuFullCombo() const {
        return m_fCpuFullCombo;
    }
    /**
     * Records whether the CPU achieved a full combo.
     * @param value @c true when the CPU achieved a full combo.
     */
    void SetCpuFullCombo(bool value) {
        m_fCpuFullCombo = value;
    }
    /**
     * Reports whether the user achieved a full combo.
     * @return @c true when the user achieved a full combo.
     */
    bool GetUserFullCombo() const {
        return m_fUserFullCombo;
    }
    /**
     * Records whether the user achieved a full combo.
     * @param value @c true when the user achieved a full combo.
     */
    void SetUserFullCombo(bool value) {
        m_fUserFullCombo = value;
    }
    /**
     * Reports whether every reflec was a full-just.
     * @return @c true when every reflec was a full-just.
     */
    bool GetFullJustReflec() const {
        return m_fFullJustReflec;
    }
    /**
     * Records whether every reflec was a full-just.
     * @param value @c true when every reflec was a full-just.
     */
    void SetFullJustReflec(bool value) {
        m_fFullJustReflec = value;
    }
    /**
     * Reports whether background music is currently playing.
     * @return @c true while background music is playing.
     */
    bool GetBgmPlaying() const {
        return m_fBgmPlaying;
    }
    /**
     * Sets whether background music is currently playing.
     * @param value @c true while background music is playing.
     */
    void SetBgmPlaying(bool value) {
        m_fBgmPlaying = value;
    }
    /**
     * Reports whether the game is paused or interrupted.
     * @return @c true while the game is paused or interrupted.
     */
    bool GetPaused() const {
        return m_fPaused;
    }
    /**
     * Sets whether the game is paused or interrupted.
     * @param value @c true while the game is paused or interrupted.
     */
    void SetPaused(bool value) {
        m_fPaused = value;
    }
    /**
     * The pastel-bonus type for the current play (0 when no bonus is active).
     * @return The pastel-bonus type, or zero when no bonus is active.
     */
    int GetPastelBonusType() const {
        return m_nPastelBonusType;
    }
    /**
     * Stores the pastel-bonus type for the current play.
     * @param value The pastel-bonus type, or zero when no bonus is active.
     */
    void SetPastelBonusType(int value) {
        m_nPastelBonusType = value;
    }
    /**
     * Whether the finished play set a new record, which arms the result screen's celebration
     * cue.
     * @return @c true when the finished play set a new record.
     */
    bool IsNewRecord() const {
        return m_nNewRecordFlag != 0;
    }
    /**
     * Records whether the finished play set a new record.
     * @param value @c true when the finished play set a new record.
     */
    void SetNewRecord(bool value) {
        m_nNewRecordFlag = value ? 1 : 0;
    }
    /**
     * Stores the player's level, current experience, and experience gained this play.
     * @param nLevel The player's level.
     * @param nExp The player's current experience.
     * @param nGained The experience gained this play.
     */
    void SetResultLevelExp(int nLevel, int nExp, int nGained) {
        m_nPlayerLevel = nLevel;
        m_nPlayerExp = nExp;
        m_nGainedExp = nGained;
    }
    /**
     * The player's level, as stored for the result screen.
     * @return The player's level.
     */
    int GetPlayerLevel() const {
        return m_nPlayerLevel;
    }
    /**
     * The player's current experience, as stored for the result screen.
     * @return The player's current experience.
     */
    int GetPlayerExp() const {
        return m_nPlayerExp;
    }
    /**
     * The experience gained this play, as stored for the result screen.
     * @return The experience gained this play.
     */
    int GetGainedExp() const {
        return m_nGainedExp;
    }
    /**
     * Stores the sheet-layer base position and recomputes its derived anchor points.
     * @param pPosition The sheet-layer base position.
     * @ghidraAddress 0x12f33c
     */
    void SetSheetLayerPosition(S_VECTOR2 *pPosition);
    /**
     * Recomputes the note-sheet layer position and margins for the current screen and the
     *        given speed type.
     * @param nScaleStep The note-speed type the layout is computed for.
     * @ghidraAddress 0x8ef60
     */
    void ConfigureSheetLayerForScreen(int nScaleStep);
    /**
     * Sets the note-sheet corner radius and recomputes the derived inset, half, scaled, and
     *        squared-diameter fields.
     * @param flRadius The sheet corner radius.
     * @ghidraAddress 0x12f3c4
     */
    void SetSheetRadius(float flRadius);
    /**
     * Sets the note-sheet margins and recomputes the far-corner anchor.
     * @param flLeft The left margin.
     * @param flTop The top margin.
     * @param flRight The right margin.
     * @param flBottom The bottom margin.
     * @ghidraAddress 0x12f394
     */
    void SetSheetMargins(float flLeft, float flTop, float flRight, float flBottom);
    /**
     * Returns the active game scene, or @c nullptr when none is running.
     * @return The active game scene, or @c nullptr when none is running.
     */
    rb::GameScene *GetCurrentScene() const {
        return m_pCurrentScene;
    }
    /**
     * Returns the address of the leading scene slot, the play scene's singleton cache.
     *
     * @c rb::GameScene::GetInstance lazily constructs the play scene into this slot; it is the same
     * field as @c GetCurrentScene reads.
     *
     * @return The address of the leading scene slot.
     */
    rb::GameScene **GetCurrentSceneSlot() {
        return &m_pCurrentScene;
    }
    /**
     * Returns the global GameSystem singleton, constructing it on first use.
     * @return The global @c GameSystem singleton.
     * @ghidraAddress 0x12edb4
     */
    static GameSystem *GetGameSystem();

    /**
     * Loads the given song's jacket/artwork image into @c m_pArtworkTexture, at 2x on a
     * retina screen (falling back to 1x). Releases any previously loaded artwork first.
     * @param pMusicData The current song's music-data object.
     * @ghidraAddress 0x12eee0
     */
    void LoadArtworkTexture(MusicData *pMusicData);

    /**
     * Loads the given song's music-name (white) image into @c m_pMusicNameTexture, at 2x on
     * a retina screen (falling back to 1x). Releases any previously loaded texture first.
     * @param pMusicData The current song's music-data object.
     * @ghidraAddress 0x12f054
     */
    void LoadMusicNameTexture(MusicData *pMusicData);

    /**
     * Loads the given song's artist-name (white) image into @c m_pArtistNameTexture, at 2x
     * on a retina screen (falling back to 1x). Releases any previously loaded texture first.
     * @param pMusicData The current song's music-data object.
     * @ghidraAddress 0x12f1c8
     */
    void LoadArtistNameTexture(MusicData *pMusicData);

    /**
     * The rendered music-name text texture, loaded by @c LoadMusicNameTexture.
     * @return The rendered music-name text texture, or @c nullptr when none is loaded.
     */
    ne::C_TEXTURE *GetMusicNameTexture() const {
        return m_pMusicNameTexture;
    }

    /**
     * The song jacket/artwork texture, loaded by @c LoadArtworkTexture.
     * @return The song jacket/artwork texture, or @c nullptr when none is loaded.
     */
    ne::C_TEXTURE *GetArtworkTexture() const {
        return m_pArtworkTexture;
    }

    /**
     * The rendered artist-name text texture, loaded by @c LoadArtistNameTexture.
     * @return The rendered artist-name text texture, or @c nullptr when none is loaded.
     */
    ne::C_TEXTURE *GetArtistNameTexture() const {
        return m_pArtistNameTexture;
    }

private:
    /**
     * Constructs the singleton, seeding the non-default (non-zero) fields; every other field
     * is zero-initialised. Inlined into @c GetGameSystem in the binary.
     */
    GameSystem();

    rb::GameScene *m_pCurrentScene = {}; // +0x00: the active game scene, or null when none runs.
    double m_dScreenX = {};              // +0x08
    double m_dScreenY = {};              // +0x10
    double m_dScreenWidth = {};          // +0x18
    double m_dScreenHeight = {};         // +0x20
    float m_flScreenScale = {};          // +0x28
    float m_flViewportWidth = {};        // +0x2c
    float m_flViewportHeight = {};       // +0x30
    bool m_fBackgroundFadeComplete = {}; // +0x34
    bool m_fUse3dTiltProjection = {};    // +0x35

public:
    // The three cached song textures are torn down (released and nulled) directly by the game
    // scene, matching the binary's cross-class field access, so they are public.

    /** The song jacket/artwork texture, loaded by @c LoadArtworkTexture. */
    ne::C_TEXTURE *m_pArtworkTexture = {}; // +0x40: released at teardown by the game scene.
    /** The rendered music-name text texture, loaded by @c LoadMusicNameTexture. */
    ne::C_TEXTURE *m_pMusicNameTexture = {}; // +0x48
    /** The rendered artist-name text texture, loaded by @c LoadArtistNameTexture. */
    ne::C_TEXTURE *m_pArtistNameTexture = {}; // +0x50

private:
    float m_flSheetPosX = {};         // +0x58
    float m_flSheetPosY = {};         // +0x5c
    float m_flSheetMarginLeft = {};   // +0x60
    float m_flSheetMarginTop = {};    // +0x64
    float m_flSheetMarginRight = {};  // +0x68
    float m_flSheetMarginBottom = {}; // +0x6c
    float m_flSheetRadius = {};       // +0x70
    float m_flCameraTargetX = {};     // +0x74
    float m_flCameraTargetY = {};     // +0x78
    float m_flSheetFarX = {};         // +0x7c
    float m_flSheetFarY = {};         // +0x80
    float m_flSheetInsetX = {};       // +0x84
    float m_flSheetInsetY = {};       // +0x88
    float m_flSheetInsetHalfX = {};   // +0x8c
    float m_flSheetInsetHalfY = {};   // +0x90
    float m_flSheetRadiusHalf = {};   // +0x94
    float m_flSheetDiameterSq = {};   // +0x98
    float m_flSheetRadiusScaled = {}; // +0x9c
    float m_flSheetWidth = {};        // +0xa0
    float m_flSheetHeight = {};       // +0xa4
    float m_flCameraPitchHeight = {}; // +0xa8
    bool m_fBgmPlaying = {};          // +0xac
    bool m_fPaused = {};              // +0xad: set while the game is paused or interrupted.
    // +0xae..+0xaf is alignment padding before the game type.
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
    int m_nNewRecordFlag = {};           // +0x114: set when the finished play beat the stored best
                                         //         score or rate (read at result-screen init to arm
                                         //         the celebration cue).
    bool m_fMenuTutorialActive = {};     // +0x12c: a byte; the binary loads and stores it with
                                         //         ldrb/strb.
    int m_nTutorialPhase = {};           // +0x130: the in-play tutorial-guide phase.
    float m_flPlayfieldScale = {};       // +0x134
    bool m_fCpuFullCombo = {};           // +0x138
    bool m_fUserFullCombo = {};          // +0x139
    bool m_fFullJustReflec = {};         // +0x13a
};
