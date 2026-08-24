# REFLEC BEAT plus — source reconstruction

<!-- WISWA-GENERATED-README:START -->

[![GitHub tag (with filter)](https://img.shields.io/github/v/tag/Tatsh/expert-xylophone)](https://github.com/Tatsh/expert-xylophone/tags)
[![License](https://img.shields.io/github/license/Tatsh/expert-xylophone)](https://github.com/Tatsh/expert-xylophone/blob/master/LICENSE.txt)
[![GitHub commits since latest release (by SemVer including pre-releases)](https://img.shields.io/github/commits-since/Tatsh/expert-xylophone/v4.5.8/master)](https://github.com/Tatsh/expert-xylophone/compare/v4.5.8...master)
[![Dependabot](https://img.shields.io/badge/Dependabot-enabled-blue?logo=dependabot)](https://github.com/dependabot)
[![Stargazers](https://img.shields.io/github/stars/Tatsh/expert-xylophone?logo=github&style=flat)](https://github.com/Tatsh/expert-xylophone/stargazers)
[![pre-commit.ci status](https://results.pre-commit.ci/badge/github/Tatsh/expert-xylophone/master.svg)](https://results.pre-commit.ci/latest/github/Tatsh/expert-xylophone/master)
[![Prettier](https://img.shields.io/badge/Prettier-black?logo=prettier)](https://prettier.io/)

[![@Tatsh](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fpublic.api.bsky.app%2Fxrpc%2Fapp.bsky.actor.getProfile%2F%3Factor=did%3Aplc%3Auq42idtvuccnmtl57nsucz72&query=%24.followersCount&label=Follow+%40Tatsh&logo=bluesky&style=social)](https://bsky.app/profile/Tatsh.bsky.social)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Tatsh-black?logo=buymeacoffee)](https://buymeacoffee.com/Tatsh)
[![Libera.Chat](https://img.shields.io/badge/Libera.Chat-Tatsh-black?logo=liberadotchat)](irc://irc.libera.chat/Tatsh)
[![Mastodon Follow](https://img.shields.io/mastodon/follow/109370961877277568?domain=hostux.social&style=social)](https://hostux.social/@Tatsh)
[![Patreon](https://img.shields.io/badge/Patreon-Tatsh2-F96854?logo=patreon)](https://www.patreon.com/Tatsh2)

<!-- WISWA-GENERATED-README:STOP -->

Reconstructed source of **REFLEC BEAT plus** 4.5.8 (`jp.konami.rbplus`).

No copyrighted material is in this repository. You must provide your own IPA with the game assets.
Building this source alone will not result in a playable game.

The reconstruction is complete in the sense that every routine the application defines has source
here. It stays faithful to the shipped binary by default; the deliberate deviations are gated
behind the `ENABLE_PATCHES` flag and documented in [PATCHES.md](PATCHES.md).

## Bundled third-party libraries

| Import as                         | Library                                     | How identified                                                               |
| --------------------------------- | ------------------------------------------- | ---------------------------------------------------------------------------- |
| `SSZipArchive.h`, `SSZipCommon.h` | **SSZipArchive** (minizip wrapper)          | `SSZipArchive` class name and its delegate protocol, plus `zlib` linkage.    |
| `UnZipArchive.h`                  | **ZipArchive** (the older minizip wrapper)  | `UnZipArchive` class name; kept alongside SSZipArchive, as the original did. |
| `DAProgressOverlayView.h`         | **DAProgressOverlayView** (Daria Kopaliani) | `DAProgressOverlayView` class name and its exact public property set.        |

## Layout

This tree mimics the original source layout recovered from the `__FILE__` paths embedded in the
binary's `assert` strings, with two elisions: the
`/Users/.../Program/Games/REFLECBEAT/` prefix is dropped, and so is the `Classess/` path segment (a
typo in the shipped tree). The original file names are kept verbatim.

```plain
Project/
  AppDelegate.{h,mm}                 confirmed original path
  main.m
  RB*.{h,m,mm}                       view, controller, and model classes (root of the tree)
  Applilink*, Recommend*, Reward*    Konami's shared SDK components
  Store*                             the in-app store
  GameSystem/src/
    OpenGL/     neGLES.cpp and the GL ES abstraction
    Render/     neSpriteInstancing.mm, neDrawPolygon2D/3D.mm, neTextTexture
    Sound/      the CoreAudio and OpenAL players
    Audio/      stream decoding
    *.mm        gamesystem, engineruntime, touchmanager, playtimer, sheetlayer, …
  OpenGL/
    Layer/      Classic/  Colette/  Limelight/  Share/   per-theme play-field layers
    Models/     3D models
    Scene/      the scene graph
  Views/
    Music/      RBMusicView and the song-select chrome
    Customize/  the customise screens
  Util/
```

Naming follows the original: engine and layer sources are `snake_case` with the lowercase `ne`
prefix on the System layer (`neGLES`, `neTextTexture`), while the view and UI classes keep their
`RB` CamelCase names. Identifiers come from the Objective-C runtime metadata, C++ RTTI, and
embedded `__func__` strings wherever possible.

## Building

Both build paths need **macOS with Xcode installed**, and an iOS toolchain installed within it (open
Xcode once so it finishes installing its components, and run `xcode-select --install`). Neither path
builds on Linux: the app links UIKit, OpenGL ES, CoreData, StoreKit, and the rest of the iOS
frameworks.

Neither path signs anything for you. The result is an unsigned `.app`; sign it ad hoc, then re-sign
the packaged `.ipa` with your own certificate before it will run on a device.

### CMake and Xcode

This path also needs **CMake 3.14 or newer** (`sudo port install cmake`, `brew install cmake`, or
the official installer — Xcode does not bring its own). It drives the Xcode generator, and needs the
[leetal/ios-cmake](https://github.com/leetal/ios-cmake) toolchain file:

```shell
git clone https://github.com/leetal/ios-cmake.git .ios-cmake
cmake -B build -G Xcode \
    -DCMAKE_TOOLCHAIN_FILE="$PWD/.ios-cmake/ios.toolchain.cmake" \
    -DPLATFORM=OS64 \
    -DDEPLOYMENT_TARGET=12.0 \
    -DENABLE_BITCODE=NO \
    -DENABLE_PATCHES=ON \
    -DRESOURCES_DIR=/path/to/extracted/Payload/REFLEC_BEAT_plus.app
cmake --build build --config Debug
```

Every knob is a cache entry, so all of them are overridable with `-D<name>=...`:

| Option                  | Default              | Effect                                                                                                                                                        |
| ----------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `API_HOST`              | `akx.s.konaminet.jp` | Hostname every secure API request is built against. Point it at a private or replacement server. Does not affect the in-app link allow-list in `RBWebView.m`. |
| `APP_BUNDLE_ID`         | `jp.konami.rbplus`   | `CFBundleIdentifier`.                                                                                                                                         |
| `BUILD_DOCS`            | `OFF`                | Build the Doxygen documentation alongside the app.                                                                                                            |
| `ENABLE_PATCHES`        | `OFF`                | Compile in the deviations described in [PATCHES.md](PATCHES.md).                                                                                              |
| `IOS_ARCHS`             | `arm64`              | Space-separated slices; add `arm64e` if your toolchain emits it.                                                                                              |
| `IOS_DEPLOYMENT_TARGET` | `12.0`               | Minimum iOS version.                                                                                                                                          |
| `RBPDBGINFO`            | `OFF`                | Emit DWARF without altering the optimisation level.                                                                                                           |
| `RBPDBG`                | `OFF`                | Compile in the `os_log` runtime diagnostics.                                                                                                                  |
| `RESOURCES_DIR`         | empty                | Directory of the original extracted `.app` whose assets to bundle. Without it the build links but has no artwork, audio, or charts.                           |

`RESOURCES_DIR` is the one that matters most: the repository contains no game assets, so a build
without it produces an app that launches into nothing.

### Theos

Theos is supported. See `theos/`. The `Makefile` builds arm64 and arm64e against
`iphone:clang:latest:12.0`. Set `$THEOS` to your Theos installation first;
on macOS it uses Xcode's SDK.

```shell
make -C theos ENABLE_PATCHES=1
make -C theos ENABLE_PATCHES=1 package
```

`ENABLE_PATCHES`, `RBPDBG`, and `RBPDBGINFO` mirror the CMake options of the same name and are all
off by default, and `API_HOST` mirrors the cache entry of the same name
(`make -C theos API_HOST=my.server.example`). Theos has no `RESOURCES_DIR` equivalent: copy the
original `.app`'s resources into
`theos/Resources/` yourself, or add them to the staged bundle after packaging.

## Status

Some of Konami's services are still up and some are gone, so online behaviour is mixed rather than
uniformly dead. The initial asset download works, and it is **required**: the game will not run
without it, so let it finish on first launch. The store is largely broken as a result of the parts
that are gone.

The Terms of Service screen is patched out, which is why a patched build never shows it. It is not
a launch-time screen: the title scene's touch handler checks for outstanding terms and pre-empts the
first tap with it. Acceptance is only recorded when the agree POST comes back OK, so with that
endpoint unavailable the screen cannot be cleared and the title screen cannot be passed.

The **Colette** theme is the one that is actively maintained and tested, on iPad.

### iPhone support

Not well-tested. The reconstruction targets the pad, and the phone paths — which the binary splits
on at nearly every layout site — have had far less time on real hardware. Expect layout problems
there, and note that some phone-only code paths (a third play-button image table, for one) were
left as the binary has them rather than guessed at.

### Classic and Limelight themes

**Please do not file bugs about the Classic or Limelight themes.** They work: both were audited
against the binary, their crashes are fixed, and they play. They will not be supported going
forward, so known cosmetic differences in those themes are being left as they are.
