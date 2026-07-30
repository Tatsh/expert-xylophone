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

Which shape a loop has is decided by whether the pre-header branches _over_ the increment, and by
whether the back edge targets the increment block or the body. Six loops use a negative counter and
exactly one is increment-at-bottom. The other seven use a zero-based counter with a `cmp`, so the
question does not arise; all seven are twelve iterations and all seven are correct as written.

| Loop      | Counter | `add`   | Increment             | True ids           | Verdict          |
| --------- | ------: | ------- | --------------------- | ------------------ | ---------------- |
| `0x5878c` |      −2 | `#0x3`  | bottom, before test   | `0x1`–`0x2` (2)    | already correct  |
| `0x58b88` |      −9 | `#0x4a` | top, skipped on entry | `0x41`–`0x4a` (10) | id base fixed    |
| `0x58c50` |      −5 | `#0x55` | top, skipped on entry | `0x50`–`0x55` (6)  | fixed            |
| `0x58d04` |      −5 | `#0x5c` | top, skipped on entry | `0x57`–`0x5c` (6)  | id base fixed    |
| `0x58e08` |      −3 | `#0x4e` | top, skipped on entry | `0x4b`–`0x4e` (4)  | **not modelled** |
| `0x5934c` |      −1 | —       | top, skipped on entry | `0x3f`–`0x40` (2)  | fixed            |

Every trip count is confirmed a second time without reference to the counter at all, by dividing the
loop's `memcpy` size by its per-iteration stride: 2 for `0x5878c`, 10 for `0x58b88`, 7 rows read 6
times for `0x58c50` and `0x58d04`, 4 for `0x58e08`, and one row read twice for `0x5934c`.

**Windows 6 and 7 read rows one through six.** Both hold seven rows and each pre-header advances one
row before the loop starts, at `0x58c40` and at `0x58cf0`/`0x58cf4`, so row zero of each is dead
data. Window 6's _position_ table already carried that offset — which is why its apparent
off-by-one was correct all along — while its curve and both of window 7's tables did not.

**Window 13 read out of bounds.** Its `memcpy` at `0x5932c` copies `0x50` bytes, one ten-knot curve,
and `0x59378` recomputes the pointer inside the body every iteration with no stride, so both sprites
share row zero. Indexing by the sprite read twenty floats past the end of a twenty-float array.

The ten from `0x58b88` are the logo's letters. The run from `0x58d04` explains the white box beside
the logo: emitting `0x5c` upwards reached `0x61`, a full-screen quad over a single solid texel that
the binary never emits here. Window 6's true base `0x50` matches the start prompt's observed kind.

## Verified correct — do not re-audit

Recording these so a later pass does not spend the effort again.

- `titlecolettescene.mm` placement mapping, jump table, all eight hit-box slots, and the `IsPad`
  asymmetry via `ldrb w8,[x22,#0x49]`.
- **All 26 arrays in `title_anim_table.h`**, checked float-for-float against the bytes at their
  annotated addresses, with every row count equal to its loop's `memcpy` size over its stride. No
  table needs re-extracting or extending, so loop bounds can be corrected on their own. The
  attract-intro pair is settled twice over: `g_aTitleAnim01Alpha` at `0x2f9958` plus `0x60` lands
  exactly on `g_aTitleAnim01Scale` at `0x2f99b8`, which plus `0x60` lands exactly on
  `g_aTitleAnim02Alpha` at `0x2f9a18` — three tables packed with no gap, so a third row of either
  would _be_ the next table.
- The complete loop inventory for `RenderSprites`, thirteen loops plus two single emits covering
  `0x5872c`–`0x59473`, with nothing unexamined. Windows 2, 3, 4, 9, 10, 11 and 12 are correct as
  written (twelve parts each: ids `0x3`–`0xe`, `0xf`–`0x1a`, `0x1b`–`0x26`, `0x33`–`0x3e` twice,
  and `0x27`–`0x32` twice).
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

## The annotation audit

`tools/audit_ghidra_addresses.py` now reports **no method mismatches** (from 42) and **one**
constant (from 16). Getting there took three fixes to the tool as well as to the annotations.

- It probed four lines past a method's opening brace for a tag without noticing a block literal
  opening in between, so it read a block's address as the enclosing method's. Five findings were
  that; it now stops at the block literal.
- It walked only `__objc_classlist`, so every category method was invisible — 86 of the 107 "absent"
  selectors. It now walks `__objc_catlist` too. A category cannot be attributed to its class from
  the file, since the class is reached through a load-time bind and the category's own name is the
  category's, so category methods match on the selector alone and a selector defined by two
  categories is reported unverifiable rather than checked against whichever came first.
- The remaining 37 method findings were genuine, and are corrected to the metadata's addresses after
  spot-checking those against Ghidra. Most were four bytes high, which in a run of four-byte stub
  methods means the tag named the next stub.

For constants the decisive test is whether the declared value sits in a **neighbouring pool slot**:
if it does the address is wrong, if it does not the value is. Eleven were value errors, including
four colour components transcribed at single precision. Two were address errors:
`kPastelViewHeightWide`'s 96 lives at `0x2ec6d8`, three slots below the annotated `0x2ec6f0` which
holds 70; and `kEffectDelayA`'s 150 is a float at `0x2eedc8` where the tag said `0x2eedcc` and so
read the neighbouring 300. Two tags were removed rather than corrected: `kTermBarWhite` and
`kLoadingTextWhite` are single-precision and exist as no double anywhere in `__const`, so their tags
named other constants' doubles, and pointing at an unverified address is worse than carrying none.

The one remaining constant report is **not a defect**: the binary holds −60 where
`kProgressWidthInset` declares 60 and the use site subtracts it. The checker is left strict rather
than taught to accept a negated match, since that would also pass a real sign error.

## Open

| Item                           | State                                                                                                                                                                                                   |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-[RBMenuView layoutSubviews]` | `0xa22ec`–`0xa467b`, still unaudited as a body. Its width arithmetic and constants are verified (below) but it owns the three visible buttons' frames, so only a device log settles the size complaint. |
| Category annotations           | 45 annotated selectors cannot be attributed, because a category on a framework class does not name that class in the binary. A known limitation, not a defect.                                          |
| Unannotated constants          | 143 of 6140 constants carry a same-line address. The other 98% are unreachable by the annotation audit and need the disassembly-driven pass.                                                            |

### The side-menu buttons

Reported too small, surrounded by grey, and unresponsive. Both routines that could place them are
faithful (above), and the earlier diagnostic that appeared to show a negative origin was taken in
`-[RBMenuButton setupView:]`, which runs during construction, **before**
`-[RBMenuView layoutSubviews]` places anything — so it said nothing about the final frames, and
the hit-testing theory drawn from it was unfounded. Real placement is in `layoutSubviews`, where the
width is `bounds.width / 3` in every branch and all three themes are covered.

That diagnostic is worse than mistimed: its numbers are not self-consistent. It printed a size
of 92×72, the pad values, with a y of −21, which is −(42/2) from the _narrow_ height the pad arm
never touches — the `fcsel` at `0x9db10` selects 72 when `IsPad` is set. One `self.frame` read
cannot mix the two. The creation-time value on a pad is `(-46, -36, 92, 72)`. Either the
transcription slipped or the call is scrambling its arguments, which is plausible: it passes nine
variadic arguments, eight of them doubles. Do not build anything on the −21.

Two causes are now identified for the appearance, neither in the placement.

The first is a real defect and is fixed: both `resizableImageWithCapInsets:` calls in
`-[RBMenuButton setupView:]` took their **right** cap from the image's height. The binary sends
`-size` twice and takes `d0`, the width, from each — at `0x9dc94`/`0x9dca4` feeding `0x9dcb4` and
`0x9dcbc`, and again at `0x9de70`/`0x9de7c` — so both horizontal caps are the same width-derived
expression. A right cap taken from the height makes the two caps exceed the image whenever it is
taller than it is wide, which leaves an invalid resizable image that draws as a flat block rather
than a stretched button face. (The `-1.0` margin decodes from an `fmov` whose immediate Ghidra
prints as `-0x4010000000000000`; the real bit pattern is `0xBFF0000000000000`.)

The second is that the artwork may not be present at all. Every name in `kMenuButtonImageNames`
is an asset-pack path (`01_music_select/sel_b_set_1` and siblings), the bundle's `assets/` is
empty, and no `sel_b_set*` file ships anywhere in it. With no background image a button draws as a
bare control with only its icon, which also reads as grey and undersized — and that would be
downstream of the resource download, and so of the loader defect above.

`217a09d7` logs the branch metrics and the final frames, which will separate a placement fault from
either of these.

## Scale

Only **143 of 6140** constants carry a same-line `@ghidraAddress` — about 2%. The annotation audit
therefore cannot reach the class of defect that breaks a screen, and a clean run of
`tools/audit_ghidra_addresses.py` is necessary but nowhere near sufficient. Every screen-level
defect found so far came from reading a specific routine's disassembly.
