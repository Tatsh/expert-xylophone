# Objective-C audit

The Objective-C reconstruction is being re-checked routine by routine against the disassembly, the
same way the engine was. [CXX_FUNCTIONS.md](CXX_FUNCTIONS.md) tracks the C and C++ side; this file
tracks what the Objective-C audit has established, so that a negative result is recorded once rather
than re-derived, and a claim is never acted on before it is verified.

Addresses are relative to the image base (`0x100000000`). The reference binary is the one **inside
`REFLEC BEAT plus 4.5.8.ipa`**; the unpacked copy under `rb458orig` is a different build and matches
nothing.

The method is the five-step process in
[.claude/rules/reconstruction.md](.claude/rules/reconstruction.md): read the decompile, type it in
Ghidra, work the disassembly for anything the decompiler garbles, write the reconstruction, then
verify it against the disassembly. Constants come from the pool at the address they load from,
frames are checked for fit inside their container, and every idiom or theme branch has its arms
counted.

## Fixed

| Routine                                                    | Address    | Defect                                                                                                                       |
| ---------------------------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `-[ApplilinkStore init]`                                   | `0x2202ec` | Synced onto the main queue, deadlocking on first use from it; the queue is a private serial one created in `+allocWithZone:` |
| `-[RBMenuView createMusicList]`                            | `0xa9108`  | Passed `sortUsingSelector:` a selector nothing implements; **both** ternary arms were wrong                                  |
| `+[UIImage imageNamedWithoutCache:]`                       | `0x1a1b08` | Both lookup passes used one tag, so `~ipad` was never tried and `dl_info` never loaded                                       |
| `-[RBResourceDownloadViewController updateLayout]`         | `0x1ea20`  | Two arms and a guessed predicate where the binary has three, and aligns rather than centres                                  |
| `TitleColetteScene::RenderSprites`                         | `0x5872c`  | Three part-id runs emitted from the literal upwards, where the literal is the run's last id                                  |
| `-[RBMusicGridLayout layoutAttributesForItemAtIndexPath:]` | `0x16de84` | Deliberate deviation was ungated; now behind `ENABLE_PATCHES` and in [PATCHES.md](PATCHES.md)                                |
| `-[RBMusicManager createPreInMusics]`                      | —          | The three preinstalled song ids were each 512 low                                                                            |
| `deviceenvironment.mm` globals                             | `0x1a05f8` | The documents and application-support paths were swapped                                                                     |

### Part-id runs in `RenderSprites`

The trip count depends on where the increment sits relative to the test, and it is **not the same in
every loop**. Reading the counter's initial value and the `add` literal alone gives the right answer
four times in five, which is exactly the sort of near-miss that produces a confident wrong fix.

| Loop      | Counter | `add`   | Increment             | True ids           | Verdict          |
| --------- | ------: | ------- | --------------------- | ------------------ | ---------------- |
| `0x5878c` |      −2 | `#0x3`  | bottom, before test   | `0x1`–`0x2` (2)    | already correct  |
| `0x58b88` |      −9 | `#0x4a` | top, skipped on entry | `0x41`–`0x4a` (10) | fixed            |
| `0x58c50` |      −5 | `#0x55` | top, skipped on entry | `0x50`–`0x55` (6)  | fixed            |
| `0x58d04` |      −5 | `#0x5c` | top, skipped on entry | `0x57`–`0x5c` (6)  | fixed            |
| `0x58e08` |      −3 | `#0x4e` | top, skipped on entry | `0x4b`–`0x4e` (4)  | **not modelled** |

The ten from `0x58b88` are the logo's letters. The run from `0x58d04` explains the white box beside
the logo: emitting `0x5c` upwards reached `0x61`, a full-screen quad over a single solid texel that
the binary never emits here. Window 6's true base `0x50` matches the start prompt's observed kind.

## Verified correct — do not re-audit

Recording these so a later pass does not spend the effort again.

- `titlecolettescene.mm` placement mapping, jump table, all eight hit-box slots, and the `IsPad`
  asymmetry via `ldrb w8,[x22,#0x49]`.
- The attract-intro loop's tables: its two in-loop `memcpy`s copy `0x60` = 96 bytes = 24 floats,
  exactly what `g_aTitleAnim01Scale`/`Alpha` hold, with a `0x30` = 48-byte stride per iteration for
  one 6-knot curve. Nothing needed re-extracting.
- Position indexing in both loop shapes: the letters' pointer starts at table+4 and is read four
  back (index _i_); window 6 starts at table+12 and is read eight back (index _i_+1), so its
  apparent off-by-one is real.
- `-[RBMenuView buildMenuBarWithThema:isPad:backgroundUsesEffectView:]` (`0xa5380`): reads the
  button's frame into `v8`–`v11` at `0xa54b8`, dispatches on the type through the jump table at
  `0xa54e0`, and writes the same registers back via `setFrame:` at `0xa5768` with no arm touching
  them. The read-then-write-back round-trip is a genuine no-op in the binary too, and the loop runs
  six times (`cmp x25,#6` at `0xa5788`).
- `-[RBMenuButton setupView:]`'s `setCenter:` at `0x9e0c8` is
  `effectTextImageView.center = effectImageView.center` (`x21` is `effectImageView`, `x24` is
  `effectTextImageView`), not the container's centre. The container's centre is never set.
- `RBMenuButton`'s `92`/`30`/`72`/`42` metrics and its `setBounds:`. Its `enabled` is write-only in
  the binary as well, so it cannot be read back.
- `-[RBMusicGridLayout prepareLayout]`'s page count is a ceiling division: `sdiv` at `0x16da74`, the
  remainder via `sdiv`/`msub` at `0x16da94`/`0x16da98`, then `cmp` against zero and `cinc` at
  `0x16daa0`. There is no zero guard on `pageItemCount` and none is needed, since `colCount` and
  `rowCount` are clamped to at least one.
- `-[UIImage clipImageWithRect:]` (`0x1a2fa4`): all of it, including the `d0`–`d3` mapping, both
  scale constants, the four `fmul`s and the release ordering. Its crop rects never exceed the atlas.
- Container sizes, positions and parenting in the download view; `kLayoutGap = 20`; the pad
  `544x670` and `320x180` canvases; the phone `90x90` pastel container.
- `-[RBMenuView updateLayout]` on iPad reproduces the binary exactly: 112, 77 and 224, 767.
- `RBCollectionView initWithFrame:self.bounds` — faithful (`bl [RBMenuView bounds]` at `0xa601c`).
- `appliURL` being nil is the original's behaviour. Only two references to its defaults key exist,
  one removing it and one reading it, so nothing writes it and the comparison always fails.

## Open

| Item                         | State                                                                                                                        |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| The `0x58e08` window         | Four parts `0x4b`–`0x4e`, not modelled at all. Needs its position and curve tables.                                          |
| Side-menu button appearance  | Cause identified as missing downloaded artwork, not layout — see below. Needs a device run.                                  |
| Five unimplemented selectors | Unguarded uses of selectors nothing implements; two fire without any interaction.                                            |
| Annotation backlog           | 42 method addresses and 16 constants disagree with the correct binary; 107 annotated selectors are absent from the metadata. |

### The side-menu buttons

Reported too small, surrounded by grey, and unresponsive. Both routines that could place them are
faithful (above), and the earlier diagnostic that appeared to show a negative origin was taken in
`-[RBMenuButton setupView:]`, which runs during construction, **before**
`-[RBMenuView layoutSubviews]` places anything — so it said nothing about the final frames, and
the hit-testing theory drawn from it was unfounded. Real placement is in `layoutSubviews`, where the
width is `bounds.width / 3` in every branch and all three themes are covered.

The appearance is explained instead by the artwork being absent. Every name in
`kMenuButtonImageNames` is an asset-pack path (`01_music_select/sel_b_set_1` and siblings), the
bundle's `assets/` directory is empty, and no `sel_b_set*` file ships anywhere in it. With no
background image a button draws as a bare control with only its icon, which reads as both grey and
undersized. That makes it downstream of the resource download, and so of the loader defect above,
rather than a layout fault. `217a09d7` logs the branch metrics and the final frames to confirm.

## Scale

Only **143 of 6140** constants carry a same-line `@ghidraAddress` — about 2%. The annotation audit
therefore cannot reach the class of defect that breaks a screen, and a clean run of
`tools/audit_ghidra_addresses.py` is necessary but nowhere near sufficient. Every screen-level
defect found so far came from reading a specific routine's disassembly.
