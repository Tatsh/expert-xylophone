<!-- markdownlint-configure-file {"MD024": { "siblings_only": true } } -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.1/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]

### Security

- Fixed PBKDF2 counter overflow and rejected invalid lengths and iteration counts in patched builds.

### Changed

- The result screen's share button now opens the iOS share sheet, carrying the rendered score card
  and the play text, so a result can be sent to any installed app. The button was previously never
  drawn, because its availability check looked for a Twitter framework the app does not link, and
  the flow behind it went through the Twitter integration iOS 11 removed. The App Store link was
  dropped from the shared text. Patched builds only.

### Fixed

- In patched builds, cancelling an image download now stops its active network request.
- Corrected the tutorial message panel's position above highlighted controls on iPhone.
- Restored theme-specific text colours for rank, name, and score in ranking rows.
- Restored the music menu page slider label with up to three reading characters or `#` when empty.
- Restored left and right end caps on the iPad terms agreement progress bar.
- In patched builds, push-token upload skips missing account or device-token data.
- In patched builds, reward setup uses a default environment and removes invalid stored IDs.
- Reward ID storage errors no longer crash the app when callers omit the optional error output.
- Failed texture loads no longer leak memory when a missing image is requested again. Patched
  builds only.
- Restored note colours for special chart lanes whose selectors precede the normal lookup range.
- Corrected the iPhone music detail Decide button artwork and placement used by the tutorial.
- The share image draws its MAX COMBO value again. `-[TwitterImageCreater drawScore:Pos:Dot:]` was
  missing the last of the binary's eight `drawNumber` calls, so the row's label and dotted leader
  came from the background artwork with no number over them.
- Corrected the localised UI string keys cached by `CacheLocalizedUIStrings` so that they match the
  shipped binary. A key that misses the lookup is drawn on screen verbatim, so every mismatch was
  visible in the game.
  - Alerts whose text embeds a line break render across the intended lines again instead of
    running on as one: the server error, connection failure, download failure, new version,
    update data, latest game data, version requirement, free space, and location service messages.
  - The download, delete confirmation, added item, Lime Point, cancelled purchase, and sequence
    requirement messages regained their quoting and punctuation.
  - Labels regained their missing spaces and correct punctuation: `Level 1` through `Level 15`,
    `Playlist Name`, `Unlock Requirement`, `App Installed Reward`, `Game Center`, `Sort:`,
    `▼ SHOW MORE ▼`, and the two restore-pack prompts.
- The playlist and sort popup draws its rows with `UITableViewCellStyleValue1`, so each level's
  song count sits at the right of the row instead of being stacked beneath the title.

## [0.0.1] - 2026-00-00

First version.

[unreleased]: https://github.com/Tatsh/expert-xylophone/compare/v4.5.8...HEAD
[0.0.1]: https://github.com/Tatsh/expert-xylophone/releases/tag/v4.5.8
