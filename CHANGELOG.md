<!-- markdownlint-configure-file {"MD024": { "siblings_only": true } } -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.1/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]

### Fixed

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
