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
 * @brief Returns the cached image-asset directory path (PrivateDocuments/Images/<deviceAssetTag>).
 * @ghidraAddress 0x1a1260
 */
NSString *GetImageAssetDirectoryPath(void);
/**
 * @brief Returns the cached download directory path (Caches/Download).
 * @ghidraAddress 0x1a126c
 */
NSString *GetDownloadDirectoryPath(void);
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
 * @brief Returns the cached "screen is Retina" flag (the main screen scale differs from 1.0).
 * @ghidraAddress 0x1a120c
 */
bool GetIsRetinaFlag(void);
/**
 * @brief Returns the cached "screen is tall" flag (the main screen is a 4-inch or larger display).
 * @ghidraAddress 0x1a1248
 */
bool GetIsTallScreenFlag(void);
/**
 * @brief Returns the cached preferred language code (for example @c "ja" or @c "en").
 * @ghidraAddress 0x1a1230
 */
NSString *GetPreferredLanguageCode(void);
/**
 * @brief Returns the cached primary localization folder name (for example @c "ja.lproj").
 * @ghidraAddress 0x1a1284
 */
NSString *GetPrimaryLprojName(void);
/**
 * @brief Returns the cached fallback localization folder name (the opposite of the primary lproj).
 * @ghidraAddress 0x1a1290
 */
NSString *GetFallbackLprojName(void);
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
 * @brief Rebuilds the cached device description string from the current server data and device
 *        info; a no-op until server data is available.
 * @ghidraAddress 0x1a12a8
 */
void RebuildDeviceDescriptionString(void);
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
 * @brief Computes the MD5 digest of a C string and returns it as a 32-character lowercase
 *        hexadecimal string.
 * @ghidraAddress 0x175c8
 */
NSString *Md5StringToHex(const char *pString);
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
 * @brief Reports whether the device uses the iPad interface idiom.
 *
 * Reads the cached idiom flag (@c UIDevice.userInterfaceIdiom @c == @c UIUserInterfaceIdiomPad) that
 * @c InitializeDeviceEnvironment sets once at startup. It selects the wide (pad) versus narrow
 * (phone) layout branch throughout the UI, and the score-digit glyph-spacing table.
 * @return @c true on an iPad-idiom device, @c false otherwise.
 * @ghidraAddress 0x1a1200
 */
bool IsPad(void);
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
 * @brief Builds the bundle image path for a customize asset of the given category and variant.
 *
 * Formats a name of the form @c "04_customize/cus_i<category>_<variant>" for the bgm (0), shot (1),
 * explosion (2), frame (3), background (4), object (5), and thema (10) categories, or the
 * variant-less @c "04_customize/cus_imusic" for a music item (7); returns @c nil for any other
 * category.
 * @param assetType The customize asset category.
 * @param variantIndex The index into the category's variant-name table.
 * @return An autoreleased path string, or @c nil for an unhandled category.
 * @ghidraAddress 0x54ee0
 */
NSString *_Nullable BuildCustomizeAssetPathString(int assetType, int variantIndex);
/**
 * @brief Builds the bundle image path for a customize music-item frame overlay.
 * @param kind The customize element id; only the music kind (7) yields a path.
 * @return An autoreleased path string, or @c nil for any other kind.
 * @ghidraAddress 0x550dc
 */
NSString *_Nullable GetCustomizeFrameImagePath(int kind);
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
namespace ne {
class C_TEXTURE;
} // namespace ne
/**
 * @brief Finds the cached texture for a key, loading it from its image asset on first request.
 * @param szKey The texture key, an image asset path such as @c "00_texture/gm_parts2".
 * @return The cached texture for @p szKey.
 * @ghidraAddress 0x33c78
 */
ne::C_TEXTURE *FindOrLoadCachedTexture(const char *szKey);
/**
 * @brief Releases every texture handle held in the global texture cache.
 * @ghidraAddress 0x33e1c
 */
void ReleaseAllCachedTextures(void);
/**
 * @brief Renders the whole global scene tree for the current frame.
 * @ghidraAddress 0x29d58
 */
void RenderGlobalSceneTree(void);
/**
 * @brief Dispatches the per-frame notification (an opaque frame-elapsed argument) to every live
 *        node in the engine listener list.
 * @ghidraAddress 0x36628
 */
void DispatchListenerList(void *pFrameArg);
/**
 * @brief Returns the elapsed time since the timer was last started, scaled to frames, as a float.
 * @ghidraAddress 0x3671c
 */
float GetElapsedMediaTime(double *pStartTime);
/**
 * @brief Records the current media time as a timer start value.
 * @ghidraAddress 0x366f8
 */
void StartMediaTimer(double *pStartTime);
/**
 * @brief Scales a two-component vector in place by the screen scale factor.
 * @ghidraAddress 0x20c08
 */
void ScaleVector2(float *pVec, float scale);
/**
 * @brief Builds a look-at view matrix from a target, an eye, and an up vector.
 * @ghidraAddress 0x19844
 */
void MakeLookAtMatrix(float *pOutMatrix, float *pTarget, float *pEye, float *pUp);
/**
 * @brief Builds an x-axis rotation matrix for the given angle, in radians.
 * @ghidraAddress 0x196b4
 */
void MakeRotationMatrixX(float angle, float *pOutMatrix);
/**
 * @brief Builds a translation matrix for the given offset.
 * @ghidraAddress 0x19624
 */
void MakeTranslationMatrix(float *pOutMatrix, float x, float y, float z);
/**
 * @brief Post-multiplies the accumulator matrix by the source matrix in place.
 * @ghidraAddress 0x18f10
 */
void ComposeMatrices(float *pAccumulator, float *pSource);

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
 * @brief The device screen height, in points, used to centre the variant (wide-font) layout.
 * @ghidraAddress 0x3c8834
 */
extern int g_nVariantScreenHeight;
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

/**
 * @brief A shared layout metric of 100 points used across the customize and store screens.
 * @ghidraAddress 0x2ec6f8
 */
extern const double g_dCustomizeLayoutMetric100;
/**
 * @brief The wide (pad) slider and section row height metric.
 * @ghidraAddress 0x2ee950
 */
extern const double g_dSliderRowHeightWide;
/**
 * @brief The shared translucent-panel background white value.
 * @ghidraAddress 0x2ec6a0
 */
extern const double g_dTranslucentAlpha;
/**
 * @brief The shared minimum flash opacity, reused as the store BGM push/pop fade duration.
 * @ghidraAddress 0x2ec6b4
 */
extern const float g_flFlashMinOpacity;
/**
 * @brief The audio-manager resume fade-in time, reused as the shared short UI fade duration.
 * @ghidraAddress 0x2ec718
 */
extern const double g_dAudioManagerResumeFadeInTime;
/**
 * @brief The localised "Delete" action-button title (pad layout).
 * @ghidraAddress 0x3cfbb0
 */
extern NSString *const g_pLocalizedDelete;
/**
 * @brief The localised "Download" action-button title (pad layout).
 * @ghidraAddress 0x3cfbc8
 */
extern NSString *const g_pLocalizedDownload;
/**
 * @brief The localised action-button title format for a purchasable store item (one @c %@ price,
 * localised from the @c "BUY (%@)" catalogue key).
 * @ghidraAddress 0x3cfb78
 */
extern NSString *const g_pLocalizedBuyFormat;
/**
 * @brief The localised "Error" alert title.
 * @ghidraAddress 0x3cfbc8
 */
extern NSString *const g_pLocalizedError;
/**
 * @brief The localised "INSTALL" action-button title shown for a purchased but not-yet-downloaded
 * store item.
 * @ghidraAddress 0x3cfc00
 */
extern NSString *const g_pLocalizedInstall;
/**
 * @brief The localised "INSTALLED" action-button title shown once a store item is fully downloaded.
 * @ghidraAddress 0x3cfc08
 */
extern NSString *const g_pLocalizedInstalled;
/**
 * @brief The localised "INSTALLING" action-button title shown while a store item downloads.
 * @ghidraAddress 0x3cfc10
 */
extern NSString *const g_pLocalizedInstalling;
/**
 * @brief The localised "Purchased" disabled-button title shown on the pack detail purchase button
 * once the pack has been bought.
 * @ghidraAddress 0x3cfd10
 */
extern NSString *const g_pLocalizedPurchased;
/**
 * @brief The download-progress modal-dialog message format string (one @c %@ tune name).
 * @ghidraAddress 0x3cfbd8
 */
extern NSString *const g_pDownloadingMessageFormat;
/**
 * @brief The delete-confirmation alert message format string (one @c %@ tune name).
 * @ghidraAddress 0x3cfcb8
 */
extern NSString *const g_pDeleteConfirmFormat;
/**
 * @brief The localised "failed to connect to the server" message.
 * @ghidraAddress 0x3cfcc0
 */
extern NSString *const g_pLocalizedServerConnectFailed;
/**
 * @brief The localised message shown when the server returns no usable data.
 * @ghidraAddress 0x3cfd60
 */
extern NSString *const g_pLocalizedServerNoData;
/**
 * @brief The localised "update required" message format shown when the extend-note catalogue
 * demands a newer app version (positional @c %1$@ feature name and @c %2$@ minimum version).
 * @ghidraAddress 0x3cfd68
 */
extern NSString *const g_pLocalizedUpdateRequiredFormat;
/**
 * @brief The localised message shown when the shop-master version is older than the app.
 * @ghidraAddress 0x3cfdc8
 */
extern NSString *const g_pLocalizedSearchVersionMismatch;

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus

/**
 * A media-time stamp used by the engine timers. Its sole field is the media time in seconds; the
 * @c GetElapsedMediaTime and @c StartMediaTimer helpers read and write it through a @c double
 * pointer to its first field.
 * @ghidraAddress C_TIME (engine struct type)
 */
struct C_TIME {
    double m_flTime = {}; // +0x0
};

// The engine render, viewport, and camera object types. Their full field layouts are not yet
// reconstructed; they are modelled as opaque reference-counted engine classes so the render helpers
// can take and return real typed pointers rather than @c void *.
class neGLESRenderer;

/**
 * A reference-counted projection viewport (orthographic or perspective), 0x70 bytes in the binary.
 * Created by @c CreateOrthoViewport / @c CreatePerspectiveViewport and released through
 * @c ReleaseViewportCamera.
 * @ghidraAddress ne_Viewport (engine class, refcount at +0x0)
 */
class ne_Viewport;

/**
 * A reference-counted camera/model node, 0x90 bytes in the binary. Created by
 * @c CreateLookAtCamera / @c CreateCameraFromMatrix and installed through @c SetCurrentModelNode.
 * @ghidraAddress ne_CameraNode (engine class, refcount at +0x0)
 */
class ne_CameraNode;

/**
 * @brief Returns the global OpenGL ES renderer, or @c nullptr when it has not been created.
 * @ghidraAddress 0x20f50
 */
neGLESRenderer *GetGlRenderer();
/**
 * @brief Installs the given viewport as the current projection (retaining it and releasing the
 *        previous one).
 * @ghidraAddress 0x29f1c
 */
void SetCurrentProjection(ne_Viewport *pViewport);
/**
 * @brief Installs the given viewport as the active view camera (retaining it and releasing the
 *        previous one).
 * @ghidraAddress 0x29f64
 */
void SetActiveViewCamera(ne_Viewport *pViewport);
/**
 * @brief Installs the given camera node as the current model/world node (retaining it and releasing
 *        the previous one).
 * @ghidraAddress 0x29fac
 */
void SetCurrentModelNode(ne_CameraNode *pCamera);
/**
 * @brief Releases a viewport created by one of the viewport constructors (decrements its
 *        reference count and destroys it at zero).
 * @ghidraAddress 0x29900
 */
void ReleaseViewportCamera(ne_Viewport *pViewport);
/**
 * @brief Creates an orthographic viewport for the given view rectangle.
 * @ghidraAddress 0x2991c
 */
ne_Viewport *
CreateOrthoViewport(float width, float height, int x, int y, int viewportWidth, int viewportHeight);
/**
 * @brief Creates a perspective viewport for the given field of view and view rectangle.
 * @ghidraAddress 0x299c4
 */
ne_Viewport *CreatePerspectiveViewport(float fovY,
                                       float aspect,
                                       float nearZ,
                                       float farZ,
                                       int x,
                                       int y,
                                       int viewportWidth,
                                       int viewportHeight);
/**
 * @brief Creates a camera node from a 4x4 view matrix.
 * @ghidraAddress 0x21fe0
 */
ne_CameraNode *CreateCameraFromMatrix(float *pMatrix);
/**
 * @brief Creates a look-at camera node from an eye, a target, and an up vector.
 * @ghidraAddress 0x21f74
 */
ne_CameraNode *CreateLookAtCamera(float *pEye, float *pTarget, float *pUp);

/**
 * @brief The engine render-kind that selects a GL framebuffer attachment point.
 *
 * Passed to @c AttachRenderbufferToFramebuffer; @c neGLES::RenderKindToGLRenderKind maps the kind
 * to its GL attachment enum (colour, depth, or stencil).
 * @ghidraAddress neGLES::RenderKind (engine enumeration)
 */
enum RenderKind {
    RENDER_KIND_COLOR = 0,   /*!< The colour attachment (@c GL_COLOR_ATTACHMENT0_OES). */
    RENDER_KIND_DEPTH = 1,   /*!< The depth attachment (@c GL_DEPTH_ATTACHMENT_OES). */
    RENDER_KIND_STENCIL = 2, /*!< The stencil attachment (@c GL_STENCIL_ATTACHMENT_OES). */
};

// The shared ne::neGLES_11 GL ES 1.1 render-state backend. Its buffer and framebuffer-object entry
// points are C++ instance methods (each is an out-of-line trampoline over a GL / @c
// GL_OES_framebuffer_object call). Bridge-facing declaration: only the members the application layer
// calls are declared here — the full class layout is reconstructed in the C++ engine phase. GL
// object names are @c GLuint and the size-out arguments are @c GLint, spelled as their C-safe
// equivalents so this header need not import the OpenGL ES headers. The application layer only ever
// holds a @c neGLESRenderer* obtained from @c GetGlRenderer() / @c EnsureGLRenderStateSingleton().
class neGLESRenderer {
public:
    /**
     * @brief Clears the current GL buffers selected by the GL clear mask.
     * @ghidraAddress 0x21400
     */
    void ClearBuffers(unsigned int dwMask);
    /**
     * @brief Generates one GL framebuffer object name into @p pOutFramebuffer.
     * @ghidraAddress 0x212ac
     */
    void GenFramebuffer(unsigned int *pOutFramebuffer);
    /**
     * @brief Deletes the GL framebuffer object @p dwFramebuffer.
     * @ghidraAddress 0x212b4
     */
    void DeleteFramebuffer(unsigned int dwFramebuffer);
    /**
     * @brief Binds @p dwFramebuffer as the current @c GL_FRAMEBUFFER_OES draw target.
     * @ghidraAddress 0x212dc
     */
    void BindFramebuffer(unsigned int dwFramebuffer);
    /**
     * @brief Generates one GL renderbuffer object name into @p pOutRenderbuffer.
     * @ghidraAddress 0x212e4
     */
    void GenRenderbuffer(unsigned int *pOutRenderbuffer);
    /**
     * @brief Deletes the GL renderbuffer object @p dwRenderbuffer.
     * @ghidraAddress 0x212ec
     */
    void DeleteRenderbuffer(unsigned int dwRenderbuffer);
    /**
     * @brief Binds @p dwRenderbuffer as the current @c GL_RENDERBUFFER_OES.
     * @ghidraAddress 0x21314
     */
    void BindRenderbuffer(unsigned int dwRenderbuffer);
    /**
     * @brief Attaches @p dwRenderbuffer to the bound framebuffer at the @p nRenderKind attachment.
     * @ghidraAddress 0x21380
     */
    void AttachRenderbufferToFramebuffer(RenderKind nRenderKind, unsigned int dwRenderbuffer);
    /**
     * @brief Reads the bound renderbuffer's width into @p pOutWidth.
     * @ghidraAddress 0x213d8
     */
    void GetRenderbufferWidth(int *pOutWidth);
    /**
     * @brief Reads the bound renderbuffer's height into @p pOutHeight.
     * @ghidraAddress 0x213ec
     */
    void GetRenderbufferHeight(int *pOutHeight);
};

/**
 * @brief Lazily constructs the global GL render-state singleton and probes GL capabilities.
 * @ghidraAddress 0x20f5c
 */
neGLESRenderer *EnsureGLRenderStateSingleton();
/**
 * @brief Returns the @c GL_RENDERBUFFER_OES bind target constant (0x8d41).
 * @ghidraAddress 0x212a4
 */
unsigned int GetGLRenderbufferTarget();
/**
 * @brief Returns @c true when the bound framebuffer is complete.
 * @ghidraAddress 0x213b4
 */
bool CheckFramebufferComplete();

/**
 * The global touch manager. The application obtains it through @c FetchSharedSingleton and commits
 * each frame through @c CompactTouchList; only the operations the Objective-C layer calls are
 * modelled here.
 * @ghidraAddress TouchManager (engine class, slot array at +0x0, count at +0x100)
 */
class TouchManager {
public:
    /**
     * @brief Returns the global touch-manager singleton, or @c nullptr when not yet created.
     * @ghidraAddress 0x17c38
     */
    static TouchManager *FetchSharedSingleton();
    /**
     * @brief Commits the current touch frame and swap-removes the touches that have ended.
     * @ghidraAddress 0x17f50
     */
    void CompactTouchList();
};

/**
 * The themed sound-effect manager. It holds three theme banks of twenty slots plus thirty-six
 * shared slots, keyed by the current theme; the application plays a slot through
 * @c PlayThemedSoundEffect.
 * @ghidraAddress SoundEffectManager (engine class, 0x1e8 bytes)
 */
class SoundEffectManager {
public:
    /**
     * @brief Returns the shared themed sound-effect manager, constructing it on first use.
     * @ghidraAddress 0x1cc514
     */
    static SoundEffectManager *GetInstance();
    /**
     * @brief Plays the sound effect in the given slot for the current theme, returning its play
     *        handle, or @c 0xffffffff when the slot is not loaded.
     * @ghidraAddress 0x1cc934
     */
    unsigned int PlayThemedSoundEffect(int slotID);
    /**
     * @brief Loads the themed voice for the given identifier and immediately plays it.
     *
     * A thin wrapper that loads the voice data through @c LoadThemedVoiceData and then plays it
     * through @c PlayThemedVoice.
     * @param voiceID The themed voice identifier.
     * @ghidraAddress 0x1ccc18
     */
    void LoadAndSetThemedVoice(int voiceID);
    /**
     * @brief Reports whether the sound effect with the given play handle is still playing.
     *
     * The manager receiver is unused; the query is forwarded to
     * @c -[AudioManager isPlayingSe:]. It is modelled as a member because the binary passes the
     * manager pointer as the first argument.
     * @param playHandle The play handle returned by @c PlayThemedSoundEffect.
     * @return @c true while the effect is still playing.
     * @ghidraAddress 0x1ccba8
     */
    bool IsPlaying(unsigned int playHandle);
};

/**
 * The shot (tap) sound sub-manager. It holds thirty-three shot slots keyed by resource id and a
 * shared loaded flag; the application preloads the whole bank through @c LoadAll before a picker is
 * shown.
 * @ghidraAddress ShotSoundManager (engine class, 0x24c bytes)
 */
class ShotSoundManager {
public:
    /**
     * @brief Returns the shared shot-sound manager, constructing and clearing its slots on first
     *        use.
     * @ghidraAddress 0x1ccf30
     */
    static ShotSoundManager *GetInstance();
    /**
     * @brief Loads every shot sound slot from the bundle, no-op once the shared loaded flag is set.
     * @ghidraAddress 0x1cd190
     */
    void LoadAll();
    /**
     * @brief Stores the shot sound group volume (clamped to the unit interval) and applies it to the
     *        audio manager's shot bus.
     * @param flVolume The requested volume, clamped to the range zero to one.
     * @ghidraAddress 0x1cd4a4
     */
    void SetVolume(float flVolume);
    /**
     * @brief Auditions a shot sound slot, returning its play handle.
     * @param uChannel The mixer channel to play on.
     * @param iSlot The shot resource id to play.
     * @param iVariant The slot variant.
     * @ghidraAddress 0x1cd364
     */
    unsigned int PlaySlot(unsigned long uChannel, int iSlot, int iVariant);
};

/**
 * The engine play-timing singleton. It is created lazily by @c EnsurePlayTimer and read directly
 * through the @c g_pPlayTimer global; only the delay-frame offset the customize picker writes is
 * modelled here.
 * @ghidraAddress g_pPlayTimer (engine singleton, 0x40 bytes)
 */
class PlayTimer {
public:
    /**
     * @brief Stores the delay-frame-derived timing offset applied to note judging.
     * @param value The offset in seconds.
     */
    void SetDelayFrameOffset(float value) {
        m_flDelayFrameOffset = value;
    }

private:
    char m_reserved[0x20] = {};      // +0x00
    float m_flDelayFrameOffset = {}; // +0x20
};

/**
 * @brief Constructs the engine play-timing singleton (@c g_pPlayTimer) on first use.
 * @ghidraAddress 0x131868
 */
void EnsurePlayTimer(void);

/** @brief The engine play-timing singleton, constructed by @c EnsurePlayTimer. */
extern PlayTimer *g_pPlayTimer;

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
