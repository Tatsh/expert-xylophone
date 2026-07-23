//
//  neEngineBridge.h
//  REFLEC BEAT plus
//
//  Shared declarations for the C++ game-engine layer (the "ne" runtime and its caplayer audio
//  bridge) reached from the Objective-C application code. Each engine helper is declared here
//  exactly once and imported where it is used, so no implementation file re-declares an engine
//  prototype locally.
//
//  Reconstructed from Ghidra project rb458, program rb458. Addresses in @ghidraAddress tags are
//  relative to the program image base.
//

#pragma once

#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>

// The genuine free engine functions (no object / this pointer) that pure Objective-C (.m) code
// calls. The binary exports them with C linkage (unmangled symbols), so they are wrapped in
// extern "C" and take only C-safe types.
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Returns the cached Application Support directory path.
 * @ghidraAddress 0x1a1624
 */
NSString *GetApplicationSupportPath(void);
/**
 * @brief Returns the cached PrivateDocuments directory path.
 * @ghidraAddress 0x1a1224
 */
NSString *GetPrivateDocumentsPath(void);
/**
 * @brief Returns the cached Caches directory path.
 * @ghidraAddress 0x1a1218
 */
NSString *GetCachesDirectoryPath(void);
/**
 * @brief Returns the API host name string.
 * @ghidraAddress 0x325e4
 */
NSString *GetApiHostString(void);
/**
 * @brief Returns the cached region code string (for example @c "JP").
 * @ghidraAddress 0x1a1278
 */
NSString *GetRegionCode(void);
/**
 * @brief Returns the cached CFBundleVersion string.
 * @ghidraAddress 0x1a160c
 */
NSString *GetBundleVersionString(void);
/**
 * @brief Returns the cached device description string (device, iOS, and build).
 * @ghidraAddress 0x1a129c
 */
NSString *GetDeviceDescriptionString(void);
/**
 * @brief Returns the cached iOS system version string.
 * @ghidraAddress 0x1a1600
 */
NSString *GetSystemVersionString(void);
/**
 * @brief Returns the cached formatted version string.
 * @ghidraAddress 0x1a1618
 */
NSString *GetFormattedVersionString(void);
/**
 * @brief Builds the MD5 digest of a C string and returns it as data.
 * @ghidraAddress 0x17534
 */
NSData *Md5StringToData(const char *pString);
/**
 * @brief Computes the MD5 digest of a buffer into a 16-byte output.
 * @ghidraAddress 0x174dc
 */
void ComputeMd5Digest(const void *pData, CC_LONG dwLength, unsigned char *pDigest);
/**
 * @brief Computes the SHA-256 of a C string and returns it as a lowercase hexadecimal string.
 * @ghidraAddress 0x17b0c
 */
NSString *ComputeSha256HexString(const char *cString);
/**
 * @brief Reports the font-variant selector flag, which chooses the region glyph-spacing table.
 * @ghidraAddress 0x1a1200
 */
unsigned int GetFontVariantFlag(void);
/**
 * @brief Constructs and initialises the AVFoundation sound-effect backend.
 * @ghidraAddress 0x4a5e8
 */
void InitializeSourceManager(void);
/**
 * @brief Returns the clear rank for the given achievement rate.
 * @ghidraAddress 0x14992c
 */
int GetClearRank(float achievementRate);
/**
 * @brief One-time initialiser for the global device, locale, and filesystem environment values.
 * @ghidraAddress 0x1a04c4
 */
void InitializeDeviceEnvironment(void);
/**
 * @brief Lazily constructs the global touch-manager singleton.
 * @ghidraAddress 0x17c44
 */
void EnsureTouchManagerSingleton(void);
/**
 * @brief Lazily creates the global texture-cache list.
 * @ghidraAddress 0x33bfc
 */
void EnsureTextureCacheList(void);
/**
 * @brief Lazily allocates the texture-cache control singleton.
 * @ghidraAddress 0x3198c
 */
void EnsureTextureCacheSingleton(unsigned char firstByte);
/**
 * @brief Reloads every cached texture from its stored image name after a context loss.
 * @ghidraAddress 0x33e5c
 */
void LoadAllCachedTextures(void);
/**
 * @brief Releases every texture handle held in the global texture cache.
 * @ghidraAddress 0x33e1c
 */
void ReleaseAllCachedTextures(void);

// Shared engine data tables, seeded at startup. They are defined once in the engine layer and read
// from the Objective-C code, so they are declared here rather than re-declared locally.

/**
 * @brief The macron-to-vowel katakana lookup table (89 entries).
 * @ghidraAddress 0x3dc258
 */
extern NSDictionary *const g_pMacronToVowelTable;
/**
 * @brief The small-kana-to-large-kana lookup table (11 entries).
 * @ghidraAddress 0x3dc260
 */
extern NSDictionary *const g_pLowerToUpperTable;
/**
 * @brief The voiced-kana-to-voiceless-kana lookup table (25 entries).
 * @ghidraAddress 0x3dc268
 */
extern NSDictionary *const g_pVoiceToVoicelessTable;
/**
 * @brief The per-decode-type Blowfish key table shared with the chart loader.
 * @ghidraAddress 0x35b7c8
 */
extern const char *const kChartDecodeKeys[];
/**
 * @brief The per-decode-type Blowfish key lengths that pair with @c kChartDecodeKeys.
 * @ghidraAddress 0x35b7d0
 */
extern const int kChartDecodeKeyLengths[];

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus

// The GetFontVariantFlag value that selects the default region glyph-spacing table; any other value
// selects a font variant.
constexpr unsigned int kFontVariantDefault = 0;

/**
 * A two-component float vector shared with the engine's sheet-layout helpers.
 * @ghidraAddress S_VECTOR2 (engine struct type)
 */
class S_VECTOR2 {
public:
    /** @brief Constructs a zero vector. */
    S_VECTOR2() = default;
    /** @brief Constructs a vector from its two components. */
    S_VECTOR2(float x, float y) : m_flX(x), m_flY(y) {
    }

    /** @brief Returns the x component. */
    float GetX() const {
        return m_flX;
    }
    /** @brief Returns the y component. */
    float GetY() const {
        return m_flY;
    }
    /** @brief Stores the x component. */
    void SetX(float value) {
        m_flX = value;
    }
    /** @brief Stores the y component. */
    void SetY(float value) {
        m_flY = value;
    }

private:
    float m_flX = {}; // +0x0
    float m_flY = {}; // +0x4
};

/**
 * The active game scene. The application queries and advances its state through the free scene
 * helpers below; only the state accessor it reads is modelled here.
 */
class GameScene {
public:
    /** @brief Returns the scene's current state. */
    int GetState() const {
        return m_nState;
    }
    /**
     * @brief Advances this scene from state 0x11 to 0x12.
     * @ghidraAddress 0x14aff8
     */
    void AdvanceGameSceneStateFrom11();
    /**
     * @brief Pauses the play timer and background music when this scene is interrupted.
     * @ghidraAddress 0x14b010
     */
    void PausePlayTimerAndBgm();

private:
    int m_nState = {}; // +0x4c
};

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
    float m_flPlayfieldScale = {};       // +0x134
    bool m_fCpuFullCombo = {};           // +0x138
    bool m_fUserFullCombo = {};          // +0x139
    bool m_fFullJustReflec = {};         // +0x13a
};

/**
 * The level-threshold tables manager. Its instance is a lazily constructed singleton, and the
 * threshold check takes the manager as its first argument, so both are modelled as members here.
 * Its full field layout is not yet reconstructed.
 */
class LevelTables {
public:
    /**
     * @brief Returns the level-tables manager singleton, constructing it on first use.
     * @ghidraAddress 0x1cbec8
     */
    static LevelTables *GetInstance();
    /**
     * @brief Reports whether the current value has reached a level threshold in one of the tables.
     * @ghidraAddress 0x1cc460
     */
    bool CheckThresholdReached(int category, int itemID);
    /**
     * @brief Loads and validates the player's level and experience from the persisted plist into
     * this manager.
     * @ghidraAddress 0x1cbf18
     */
    bool LoadPlayerLevelData();
};

/**
 * The one-shot voice-player subsystem, reached through @c AudioManager's @c sePlayer ivar. The
 * former free engine functions that took the @c caPlayerMgr as their first argument are its
 * instance methods.
 */
class caPlayerMgr {
public:
    /**
     * @brief Constructs the audio context: the graph, the name-to-id dictionary, and the buffer
     * array.
     * @ghidraAddress 0x4b580
     */
    void InitializeAudioContext(int channelCount);
    /**
     * @brief Tears down the audio context.
     * @ghidraAddress 0x4b4a8
     */
    void DestroyAudioContext();
    /**
     * @brief Tears down the audio context (wrapper entry point).
     * @ghidraAddress 0x4b57c
     */
    void DestroyAudioContextWrapper();
    /**
     * @brief Starts the audio graph.
     * @ghidraAddress 0x4b61c
     */
    void StartAudioGraph();
    /**
     * @brief Stops the audio graph.
     * @ghidraAddress 0x4b60c
     */
    void StopAudioGraph();
    /**
     * @brief Creates a sound buffer, loads PCM from a path, and registers it, returning its id.
     * @ghidraAddress 0x4b62c
     */
    int CreateAndLoadSound(const char *szPath, bool bLoop);
    /**
     * @brief Loads a sound and caches its id keyed by a call name, returning whether it was loaded.
     * @ghidraAddress 0x4b718
     */
    int LoadAndCacheSoundForKey(const char *szPath, NSString *callName, bool bLoop);
    /**
     * @brief Frees the sound buffer at the given index.
     * @ghidraAddress 0x4b870
     */
    void FreeSoundDataByIndex(unsigned int index);
    /**
     * @brief Frees the sound buffer registered under a call name.
     * @ghidraAddress 0x4b8cc
     */
    void FreeSoundForKey(NSString *callName);
    /**
     * @brief Plays the sound at the given index on the first free voice, returning its handle.
     * @ghidraAddress 0x4b998
     */
    unsigned int PlaySoundByIndex(unsigned int index);
    /**
     * @brief Plays the sound registered under a call name, returning its handle.
     * @ghidraAddress 0x4ba1c
     */
    unsigned int PlaySoundForKey(NSString *callName);
    /**
     * @brief Plays the sound at the given index on a specific voice, returning its handle.
     * @ghidraAddress 0x4b9d4
     */
    unsigned int PlaySoundOnVoice(int resourceId, int busId, int volume);
    /**
     * @brief Plays the sound under a call name on a specific voice, returning its handle.
     * @ghidraAddress 0x4bac0
     */
    unsigned int PlaySoundForKeyOnBus(NSString *callName, int busId, int volume);
    /**
     * @brief Resumes or starts the voice identified by a handle.
     * @ghidraAddress 0x4bb6c
     */
    void ResumeVoiceByHandle(unsigned int handle);
    /**
     * @brief Pauses the voice identified by a handle.
     * @ghidraAddress 0x4bb9c
     */
    void PauseVoiceByHandle(unsigned int handle);
    /**
     * @brief Stops the voice identified by a handle.
     * @ghidraAddress 0x4bb84
     */
    void StopVoiceByHandle(unsigned int handle);
    /**
     * @brief Releases the voice identified by a handle.
     * @ghidraAddress 0x4bcac
     */
    void ReleaseVoiceByHandle(unsigned int handle);
    /**
     * @brief Returns the playback state of the voice identified by a handle.
     * @ghidraAddress 0x4bbb4
     */
    int GetVoiceStateByHandle(unsigned int handle);
    /**
     * @brief Sets the mixer's master voice gain.
     * @ghidraAddress 0x4bbcc
     */
    void SetMasterVoiceParameter();
};

/**
 * The grouped mixer-bus source subsystem, reached through @c AudioManager's @c seAVPlayer ivar.
 * The former free engine functions that took the @c AudioSourceSlot as their first argument are
 * its instance methods.
 */
class AudioSourceSlot {
public:
    /**
     * @brief Constructs and initialises the mixer, name map, and source table.
     * @ghidraAddress 0x4a5d4
     */
    void InitAudioSourceSlot();
    /**
     * @brief Adds a source from a URL, returning its index.
     * @ghidraAddress 0x4a690
     */
    unsigned int AddSourceToManager(NSURL *url, bool bLoop);
    /**
     * @brief Registers a source from a URL under a call name, returning whether it was added.
     * @ghidraAddress 0x4a728
     */
    int RegisterSourceForKey(NSURL *url, NSString *callName, bool bLoop);
    /**
     * @brief Removes the source at the given index.
     * @ghidraAddress 0x4a870
     */
    void RemoveAudioSourceByIndex(unsigned int index);
    /**
     * @brief Removes the source registered under a call name.
     * @ghidraAddress 0x4a8c0
     */
    void RemoveAudioSourceByKey(NSString *callName);
    /**
     * @brief Acquires a playback bus for the source at the given index, returning its handle.
     * @ghidraAddress 0x4a954
     */
    unsigned int AcquireAudioBusForSourceIndex(unsigned int index);
    /**
     * @brief Acquires a playback bus for the source under a call name, returning its handle.
     * @ghidraAddress 0x4a990
     */
    unsigned int AcquireAudioBusForSourceKey(NSString *callName, int volume);
    /**
     * @brief Starts playback of the bus identified by a handle.
     * @ghidraAddress 0x4aa34
     */
    void PlaySourceByHandle(unsigned int handle);
    /**
     * @brief Pauses the bus identified by a play handle.
     * @ghidraAddress 0x4aa64
     */
    void PauseAudioBusByPlayHandle(unsigned int handle);
    /**
     * @brief Stops the bus identified by a play handle.
     * @ghidraAddress 0x4ab74
     */
    void StopAudioBusByPlayHandle(unsigned int handle);
    /**
     * @brief Stops the bus identified by a handle, returning whether it was playing.
     * @ghidraAddress 0x4aa4c
     */
    bool StopAudioBusByHandleWrapper(unsigned int handle);
    /**
     * @brief Returns the playback status of the bus identified by a handle.
     * @ghidraAddress 0x4aa7c
     */
    int QueryAudioBusPlaybackStatus(unsigned int handle);
    /**
     * @brief Pauses every audio bus.
     * @ghidraAddress 0x4a670
     */
    void PauseAllAudioBuses();
    /**
     * @brief Resumes every audio bus.
     * @ghidraAddress 0x4a680
     */
    void ResumeAllAudioBuses();
    /**
     * @brief Sets the volume of every audio bus.
     * @ghidraAddress 0x4aa94
     */
    void SetAllAudioBusVolumeWrapper(int volume);
};

/**
 * The persistent clear-gauge render layer inserted into the engine's listener list at launch. It
 * is an intrusive listener node, so its list insertion is one of its own methods.
 * @ghidraAddress ClearGaugeLayer (engine render class)
 */
class ClearGaugeLayer {
public:
    /** @brief Constructs the clear-gauge render layer. */
    ClearGaugeLayer();
    /**
     * @brief Inserts this node into the priority-sorted engine listener list.
     * @ghidraAddress 0x365e4
     */
    void InsertSortedListenerNode(int priority);
};

/**
 * The sheet-layer geometry helpers. Each takes the target GameSystem, so they are modelled as
 * static members of the sheet-layer helper class (its full type is not yet reconstructed).
 */
class SheetLayer {
public:
    /**
     * @brief Stores the sheet-layer margins on @p pGameSystem and recomputes the far corner.
     * @ghidraAddress 0x12f394
     */
    static void SetSheetLayerMargins(
        float fLeft, float fTop, float fRight, float fBottom, GameSystem *pGameSystem);
    /**
     * @brief Stores the sheet-layer corner radius on @p pGameSystem and recomputes the insets.
     * @ghidraAddress 0x12f3c4
     */
    static void SetSheetLayerRadius(float fRadius, GameSystem *pGameSystem);
};

#endif // __cplusplus

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
