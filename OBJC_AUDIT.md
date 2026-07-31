# Objective-C audit

The Objective-C reconstruction is being re-checked routine by routine against the disassembly, the
same way the engine was.

**Coverage lives in [OBJC_METHODS.md](OBJC_METHODS.md)**, the per-method checklist generated
from the binary's runtime metadata — every method, whether it is reconstructed, and whether
it is verified. That file is the counterpart to [CXX_FUNCTIONS.md](CXX_FUNCTIONS.md) and is
where to look for what remains. As of the last regeneration it stands at 6343 methods, 6306
reconstructed and **4785 verified**. The 1558 that remain are non-accessor bodies that have to be
read one at a time, and they are large: only 69 are under 128 bytes, while 601 exceed 512.

This file is the findings record behind those verifications: what each routine turned out to be, so
that a negative result is recorded once rather than re-derived, and a claim is never acted on before
it is checked.

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

| Routine                                                      | Address    | Defect                                                                                                                       |
| ------------------------------------------------------------ | ---------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `-[ApplilinkStore init]`                                     | `0x2202ec` | Synced onto the main queue, deadlocking on first use from it; the queue is a private serial one created in `+allocWithZone:` |
| `-[RBMenuView createMusicList]`                              | `0xa9108`  | Passed `sortUsingSelector:` a selector nothing implements; **both** ternary arms were wrong                                  |
| `+[UIImage imageNamedWithoutCache:]`                         | `0x1a1b08` | Both lookup passes used one tag, so `~ipad` was never tried and `dl_info` never loaded                                       |
| `-[RBResourceDownloadViewController updateLayout]`           | `0x1ea20`  | Two arms and a guessed predicate where the binary has three, and aligns rather than centres                                  |
| `TitleColetteScene::RenderSprites`                           | `0x5872c`  | Three part-id runs emitted from the literal upwards, where the literal is the run's last id                                  |
| `-[RBMusicGridLayout layoutAttributesForItemAtIndexPath:]`   | `0x16de84` | Deliberate deviation was ungated; now behind `ENABLE_PATCHES` and in [PATCHES.md](PATCHES.md)                                |
| `-[RBMusicManager createPreInMusics]`                        | —          | The three preinstalled song ids were each 512 low                                                                            |
| `deviceenvironment.mm` globals                               | `0x1a05f8` | The documents and application-support paths were swapped                                                                     |
| `-[RBCampaignDetailViewController viewWillAppear:]`          | `0x7f4c`   | Almost every frame in the page was misread; see below                                                                        |
| `-[RBCampaignDetailViewController setInfo:]`                 | `0x5b34`   | Three of the four string literals were invented rather than decoded                                                          |
| `-[RBMenuView showCustomizeView]`                            | `0xac0bc`  | Launched tutorial type `0` instead of `0x1d`, stranding the spotlight on the previous step                                   |
| `-[RBMenuView startTutorial]`                                | `0xb5678`  | The music-select (`0`) and customize (`0x18`) tutorial types were swapped                                                    |
| `-[RBMenuView selectMusic:animated:]`                        | `0xaaff0`  | Launched tutorial type `0x18` where the binary passes `0x4`                                                                  |
| `-[RBMenuView toggleSettingView]`                            | `0xaba74`  | Marked tutorial-status key `0x22` seen; the binary checks `0x22` but marks `0x18`                                            |
| `-[RBMenuView show*View]` (nine popups)                      | `0xabf94`… | Every popup got mask `0x12`; the binary sets `0x3f` on all of them                                                           |
| `-[RBMenuTutorialView startAnimation:]` / `-resetAnimation:` | `0x13de2c` | Message-layer Y anchored to an invented constant `20`, not the window layer's own origin Y                                   |
| `SetupDialogLayoutCoordTable`                                | `0x1414e0` | Row 15's origin X is written as `2.0` by the seeder; it had been left at `0`                                                 |
| `-[RBMusicMenuPopupView setupView]`                          | `0x19ec8c` | Wide base width is `544` (pool `0x2ee960`), not `552`; both Classic arms use corner radius `5`, not `10`                     |
| `-[RBCustomSelectCollectionView setupView]`                  | `0x155670` | Note/gauge button geometry, collection frame, cap insets, page control, slider events; see below                             |
| `rb::GameScene::OnFrame`                                     | `0x14b3e8` | Reconstructed as an uncalled plain method (`RunPlayStateMachineDispatch`); it is the `C_TASK` `OnFrame` vtable override      |

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

## Verifying every method

[OBJC_METHODS.md](OBJC_METHODS.md) tracks all 6343 methods, and the count verified against the
disassembly now stands at **4677**, up from 15. Two mechanical passes account for 3082 of those, and
both record per-address evidence so their reasoning can be audited rather than taken on trust:

- `tools/objc_verify_accessors.py` shows a property accessor moves exactly the ivar its property
  declares. That is a comparison of two independent statements of the same fact, because a synthesised
  accessor reaches its ivar through the `_OBJC_IVAR_$_` offset variable rather than an immediate: the
  ivar the instructions reach is resolved through that variable into the class's ivar list, and
  compared with the backing ivar the property list names. The body must also call nothing but the ARC
  and property runtime helpers, so a hand-written method that merely opens with an ivar load is not
  mistaken for a synthesised one. 2890 of 3260 pass; the 370 that do not are genuinely custom.
- `tools/objc_verify_trivial.py` shows an empty body, a constant return, or a `dealloc` that only
  calls the superclass agrees with its reconstruction. 192 pass. Resolving named constants was
  necessary, since the rules require a name rather than a bare number. The 47 super-only `dealloc`
  bodies also correct how part of the checklist reads: ARC writes that method and forbids writing it
  by hand, so its absence from the tree is right rather than a gap.

The remaining ~3000 are non-accessor bodies that need reading one at a time, which is the slow part
and is where the per-routine findings below come from.

One tool was written and deliberately not shipped. It compared the ordered selectors a method sends
against the sends in its reconstruction — the shape every screen defect so far has had — and it works,
but its source-side reading cannot handle a nested send, because matching brackets by regular
expression takes the innermost pair. A defect finder that cries wolf costs more attention than it
saves.

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

**`-[RBMusicView SetupView]` tail** (`0xcf1a0`–`0xd0110`): the decide/pastel/double/random/history
construction is three whole theme paths (thema 0 → `0xcf7dc`, 1 → inline at `0xcf1c0`, 2 →
`0xcf848`), which the reconstruction flattens into one sequence. Confirmed so far: the decide
button is sized by `setBounds:` to its image and centred at `{160, thema==2 ? 297 : 287}`
(`0xcf3c4`), where the reconstruction gives it a `{44, 546}` frame and hands `297`/`287` to the
pastel buttons. The tail needs re-deriving path by path.

| Item                           | State                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-[RBMenuView layoutSubviews]` | `0xa22ec`–`0xa467b`, still unaudited as a body. Its width arithmetic and constants are verified (below) but it owns the three visible buttons' frames, so only a device log settles the size complaint.                                                                                                                                                           |
| Category annotations           | 45 annotated selectors cannot be attributed, because a category on a framework class does not name that class in the binary. A known limitation, not a defect.                                                                                                                                                                                                    |
| Unannotated constants          | 143 of 6140 constants carry a same-line address. The other 98% are unreachable by the annotation audit and need the disassembly-driven pass.                                                                                                                                                                                                                      |
| Declared superclasses          | Five headers still disagree with the resolved superclass slot: `RBSettingMenuButton` and `StoreDetailHeaderView` and `StoreImageView` say `UIControl`/`UIImageView`/`UIImageView` where the binary says `UIView`, and `RBTimingSlider` and `RBVolumeSlider` say `UISlider` where the binary groups them with `RBPopupView` and `RBNumberLabel` under `UIControl`. |

### The side-menu buttons

Reported too small, surrounded by grey, and unresponsive. The grey is settled and fixed; the size
and the responsiveness are still open. Both routines that could place them are
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

Three causes were proposed for the appearance, none of them in the placement. The grey is the third
of them, and neither of the first two accounts for it.

**The grey rectangle behind each pill was the reconstruction's superclass, and is fixed.**
`RBMenuButton` was declared a subclass of `RBMenuNewsTickerView`, so the `[super init]` at `0x9da30`
in `-initWithType:` ran `-[RBMenuNewsTickerView initWithFrame:]` and through it `-SetUpView`, which
paints the receiver `218/255` grey under themes 1 and 2 and black under theme 0.
`-[RBMenuButton setupView:]` sets no background colour anywhere in `0x9dab4`–`0x9e1af`, so every
opaque rectangle came from that inherited call. The binary's own metadata says the superclass is
`UIView`, on two independent witnesses: the `class_ro_t` at `0x38b1f8` records `instanceStart` 8,
which is the compile-time size of a superclass declaring no ivars, and a subclass of
`RBMenuNewsTickerView` (`instanceSize` 104) would have recorded 104; and the superclass slot at
`0x3cb158`, which reads 0 in the file because it is an external bind, resolves under Ghidra's
relocations to the same address as `RBMenuView`'s, `RBMusicView`'s, and 37 other plain views'.
Grouping all 225 classes by that resolved slot names each framework superclass by consensus, and
it flags five further mismatches in the tree, recorded in the table above.

The second is a real defect and was fixed earlier: both `resizableImageWithCapInsets:` calls in
`-[RBMenuButton setupView:]` took their **right** cap from the image's height. The binary sends
`-size` twice and takes `d0`, the width, from each — at `0x9dc94`/`0x9dca4` feeding `0x9dcb4` and
`0x9dcbc`, and again at `0x9de70`/`0x9de7c` — so both horizontal caps are the same width-derived
expression. A right cap taken from the height makes the two caps exceed the image whenever it is
taller than it is wide, which leaves an invalid resizable image that draws as a flat block rather
than a stretched button face. (The `-1.0` margin decodes from an `fmov` whose immediate Ghidra
prints as `-0x4010000000000000`; the real bit pattern is `0xBFF0000000000000`.)

The first was that the artwork may not be present at all: every name in `kMenuButtonImageNames` is
an asset-pack path (`01_music_select/sel_b_set_1` and siblings) and the bundle's `assets/` ships no
`sel_b_set*` file, so a nil background would leave a bare control carrying only its icon. A device
screenshot after the resource download settles it — each pill draws its own stretched artwork,
correctly capped — so the names do resolve at run time and the theory is closed for these
buttons. It says nothing about the music-name artwork, which is a separate question.

`217a09d7` logs the branch metrics and the final frames, which will separate a placement fault from
the remaining size complaint.

## The campaign detail page

`-[RBCampaignDetailViewController viewWillAppear:]` at `0x7f4c` builds the whole page, and the
reconstruction had the right calls in the right order with the wrong numbers in almost all of them.
Nothing in it was visible by reading the source, and the class had already passed the annotation
audit.

The header panel is 140 tall (`0x2ec6c0`), not the 200 that the doubled button width produced, so
the detail block below it started 60 points too low. The three label rows are inset
from the view width — 104 (`0x2ec6d0`) for the name and artist rows, 230 (`0x2ec6e8`) for the levels
row — where the reconstruction gave each of them the full width; the artist row sits at y 50 and the
levels row at y 70 (`0x2ec6f0`), not 80 and 100. Both action buttons are 104 wide (`0x2ec700`), not
100, and both are right-aligned by two additions rather than one: the download button at
`width - 8 - 104` and the link button at `width - 16 - 208` (`0x2ec710`). Those two frames are what
makes the layout checkable — they leave an 8-point right margin and an 8-point gap between the
buttons, and the previous link-button x, `width - (-208)`, put it off-screen entirely.

Three whole properties were the wrong ones. The link button takes `-setButtonColor:`, not
`backgroundColor`, and its green is 0.3 (`0x2ec718`) against the shared 0.8 on red and blue. The
detail panel is **filled** with that same shared 0.8 (`0x2ec6a0`) and only **bordered** with 143/255
(`0x2ec730`); the reconstruction used the border colour for both. The sample indicator's style is 0,
`WhiteLarge`, not `White`.

The sample overlay is sized from the artwork's frame **at the origin**, not from the artwork frame
itself, and its indicator is half that size, halved once in single precision — the `fcvt s`/`fcvt d`
round trip at `0x95e8` is a `float` local, and the same pair of values is reused for both subviews'
centres. The divider is one point tall, not the whole view's bounds. The copyright block is 50 tall
and sits at the description's height, so description and copyright together fill the detail panel
exactly; the previous `CGRectGetMaxY` chain and 20-point height did not.

Six autoresizing masks were wrong in the same way: the binary's `0x22` is
`FlexibleWidth | FlexibleBottomMargin`, and each had been read as
`FlexibleWidth | FlexibleRightMargin` (`0x06`).

`-[RBCampaignDetailViewController setInfo:]` at `0x5b34` had three invented string literals. The
levels format at `0x3619a0` is `LEVEL:  %d / %d / %d` — colon, two spaces, slashes — not
`LEVEL %d %d %d`; the locked-item placeholder at `0x3619e0` is **six** full-width question marks,
not three (UTF-16, length 6 in the CFString record); and the placeholder jacket is
`09_store/store_jacket_80`, with a slash, as two already-verified sibling files spell it. The
identifier format `%d` at `0x3619c0` was right. `-initWithItemInfo:` at `0x58fc` was missing a whole
statement: it sets the navigation title to the inline literal `Gift` at `0x361980` before binding
the item, and only then overwrites it with `campaignName`.

Three ivars were reached through their accessors where the binary reaches them directly:
`_campaignID` in `-setInfo:`, and `_closingFlag` and `_packinfoDownloadAlertView` in the two
appearance callbacks.
The sibling `RBStoreExtendNoteDetailViewController` already spells those two directly.

One finding is outside this class and is left open: `kArtworkShadowOpacity` in
`Project/RBStoreExtendNoteDetailViewController.m` is annotated `0x2ec6b8` and declared `0.15`, but
that slot holds the float32 `0.6`. It is one of the four constants the annotation audit already
reports as mismatched.

## The customize walkthrough and the CUSTOMIZE window

The walkthrough is a chain of hand-off calls across five classes, each call site hard-coding the
next
step number. The interior links were right (`RBSettingView` `0x1b`, `RBCustomView` `0x1e`/`0x21`,
`RBUnlockView` `0x20`, `-hideAnimation:` `0xa`); the two entry points in `RBMenuView` were wrong.
`-startTutorial` had the music-select and customize types swapped, and `-showCustomizeView`
launched type `0` instead of `0x1d` — so opening the CUSTOMIZE window replayed the music-select
intro over a stale spotlight target instead of spotlighting the UNLOCK toggle. The status keys are
two, not one: `0x22` is the customize-done flag that gets checked, `0x18` is the entry step that
gets marked seen (`-toggleSettingView` at `0xabe98`, `-showCustomizeView` at `0xac1fc`).

The tutorial balloon text sat outside its window because both `-startAnimation:` and
`-resetAnimation:` compute the message layer's Y from the window layer's own `frame.origin.y`
(`d15` at `0x13e308`, `d8` at `0x13fc34`) — the reconstruction had an invented flat `20.0` there.
On the wide idiom the window's Y is `cvh*0.25+3 = 78`, so the text drew 58 points high.

In `-[RBCustomSelectCollectionView setupView]` (`0x155670`) the misreads were structural:

- The framed background's cap insets are `(capInset, 0, imageHeight - capInset, 0)` — the bottom
  inset had been modelled as `25 - capInset`, negative on the wide layout.
- The note-size buttons centre on and take the size of the `cus_sel_2` overlay artwork; they had
  been centred against the ~500-point frame image and sized to the item image.
- The gauge buttons take the `cus_gs_bt_eff` overlay's size, and are inset `66` (wide, `0x30be60`)
  or `33` (narrow, `0x2eeeb8`) from the ends of a button area `frameImage.width - 2` wide; the
  narrow inset had been read as `3`, and the second button's X had collapsed to the area centre.
  The wide Y pair `{45, 59}` is a theme-indexed table at `0x30be80`.
- The paged collection is `frameImage.width - 2` wide, centred, with a per-category height table
  (built on the stack at `0x1558c8`): default `80/72`, shot `150/200`, note `90/72`, gauge and
  timing `51`. It had been full-width at a single height.
- The page control is `{0, collectionView.bottom, selfWidth, 20}`, not zero-sized; on Classic the
  binary never writes the dot-tint register, so the dots keep the `0.5` left over from the frame
  maths.
- All three sliders register `sliderChanged:` for `TouchUpInside|TouchUpOutside` (`0x40`/`0x80`),
  not `ValueChanged`.

## The song-start crash

Starting a song crashed at `SetRefCountedMember` on a null sprite (`this + 0x138`,
`m_pTexture`'s offset) from `GameScene::Init`. The binary has **no null guard there either**
(`BoundsEffectLayer::SetStyle` at `0x1753e4` and `DamageEffectLayer::SetBoundsDamageStyle` at
`0x1740cc` both tail-call `SetRefCountedMember` on `this+0x10` unconditionally;
`NoteGlowLayer::SetTexture` at `0x176a84` does guard). The original survives because the sprites
are always built before the first play: `GameScene`'s vtable at `0x35da40` (RTTI
`N2rb9GameSceneE`) holds `0x14b3e8` in the `ne::C_TASK` `OnFrame` slot, the scene is constructed
and task-registered at title-screen exit (`GetInstance` xrefs), and the state machine's initial
state runs `InitializePlayFieldLayersForTheme` on the first task tick — during the menu, long
before a song starts. The reconstruction had `0x14b3e8` as a plain, never-called method named
`RunPlayStateMachineDispatch`, so the layers were never built and the first `Init` dereferenced
null. Fixed by making it the `OnFrame(int) override`, matching every other scene.

## Verified correct in the same pass — do not re-audit

- `SetupDialogLayoutCoordTable` (`0x1414e0`): all 34 rows decoded from the immediates; only row
  15's X was wrong. The balloon artwork rects (rows 28/29) are `{361,412,398,134}` and
  `{361,548,430,124}` as written.
- `-[RBMenuTutorialView setupView]` (`0x137bfc`): window/pastel/message geometry, including the
  `-0.85` pool load at `0x308cb8`, the `0.8` at `0x2eea40`, insets 20/26/16/8, and clip rows 9/10.
- `-[RBMenuTutorialView startTutorialWithType:withAnimation:]` (`0x13ab34`): the full jump table at
  `0x13b870` matches case-for-case, including `0x1c`/`0x1f` having no layout arm.
- `-[RBMenuTutorialView getTextureType]` (`0x14040c`): jump table at `0x1404b8` matches, including
  `pad?9:10` for the decide step and default `0x22`.
- `-[RBMenuTutorialView initWithFrame:]`: content view 640x300 wide, 300x100 narrow.
- `-[RBCustomView setupView]` (`0x96724`): the `0.21875` set-button shave is a real `fmov`
  immediate (7/32); the `20.0` unlock inset, `0.5` hairlines, `0.625/1.5/2.0` wide and `1.0/4.0`
  narrow effect nudges all match. `-showAnimation` (`0x987b0`) launches no tutorial step.
- `-[RBUnlockView setupView]`/`-reloadData`: every constant matches (34/70, 112/44/114/20,
  169/93/240/36, 169/90/240/40, margins 10/4, rows 144/124, pads 70/45, banner factor 0.8).
- `-[RBCustomSelectView setupView]` and its two metric helpers: start Y `{70, 40}` wide (table at
  `0x30bf00`) and `34/21` narrow, margins `20/12`, and all per-category stack heights.
- `-[RBCustomSelectCollectionCell layoutSubviews]` (`0x16e810`): the `(int)` truncation of the
  centred X and the `selectedImageView.center = backgroundView.center` assignment.
- `-[RBMusicView SetupView]` geometry tables: every sampled pool value in the four legs matches
  (`53/56/180`, `266/40/84`, `268/170/220/33`, `430/188`, `412/169`, `388/108`, `31/488/322/183`,
  `152/470/240`), and the leg dispatch is `_thema` (ivar-offset global `0x3c8b7c`; the ivar list at
  `0x100391348` names it) with the Brown theme (2) taking its own leg — not the game type. The
  name-artwork switch at `0xccf48` is also `_thema` (0 white, 1 black, 2 brown), the 0.7 name dim
  applies to `_thema == 1` only (`0xcd368`), the CPU/other setting pages split by `IsPad`
  (`0xceaa8`: pad pages 3/4, narrow pages 2/3 — the narrow CPU view shares the speed view's page),
  and `setBpmOrigin:` is passed `143.0` (`0x4061e00000000000`), not `142.0`.
- `-[RBMusicView ShowSelectDifficulty]` (`0xd2fd8`) branches on `m_GameType` (slot `0x3c8b80`):
  0 shows the score readout, 1 hides it — as reconstructed.

## Coverage: every method is now reconstructed

`OBJC_METHODS.md` reports **6306 of 6343** methods reconstructed. The 37 that remain are all
`-dealloc`, and their omission is deliberate and verified: each was disassembled and checked for
any call other than `[super dealloc]`, which ARC emits itself.

This paragraph previously claimed that **exactly one** `-dealloc` in the binary does more than
chain. That is wrong by a wide margin. Disassembling all 88 `-dealloc` entries and counting
`objc_msgSend` calls beyond the `objc_msgSendSuper2` chain gives **39** that do real work, from
`-[AVBus dealloc]`'s single send up to `-[RBSearchMapView dealloc]`'s twenty-three. The claim was
found while verifying `-[RBPushNotificationView initWithFrame:]` and noticing its neighbouring
`dealloc` at `0x18f74c` sends `setDelegate:nil` and `stopTimer` before chaining.

The conclusion the wrong number was supporting still holds, and it was re-checked rather than
assumed: cross-referencing those 39 against the reconstruction column, **all 39 are reconstructed**
and none is among the 37 omitted. So the omitted set really is pure super chains and the
reconstruction total is sound. The error was in the description, not in the coverage — but a stated
count that is off by a factor of thirty-nine is worth correcting, because the next reader would
reasonably use it to decide that `-dealloc` is a class not worth examining.

Treat 39 as a floor rather than the exact figure. The count matches `objc_msgSend` calls, so a
`-dealloc` whose only extra work is a **direct ivar write** does not appear in it.
`-[RewardWebViewController dealloc]` is both: it sends `clearDelegate` and also clears
`_viewCloseFlg` with a `strb wzr` at `0x21f224`, which the reconstruction has and the counter did
not see.

Getting there was mostly **not** writing new bodies. The checklist had reported 137 missing, and
they broke down as:

- **51 vendored** (`DAProgressOverlayView`, `SSZipArchive`, `UnZipArchive`): `objc_update` only
  scanned `Project/`, so `3rdparty/` never counted.
- **22 renamed**: `StoreExtendNoteView` had been reconstructed as `StoreExtendNoteCellView` to
  avoid a collision with `StoreExtendNoteCellPhone` that does not exist — that phone layout is its
  own class in the metadata. The checklist matches on the class name, so every method looked
  missing.
- **11 formatting artefacts**: clang-format wraps a long `@property` onto a second line, starts a
  selector on the line after its return type, and splits a twelve-keyword selector across a dozen
  lines; the parser handled none of those, and it also could not spell a selector with an unnamed
  part (`createContext::`).
- **9 method-kind inversions**: a `+` reconstruction never matches a `-` row, because the runtime
  keeps two separate method lists. Two of these had already been papered over at the call site with
  an `(id)` cast to silence the warning the wrong kind produced, which is the tell to look for.
- **~40 ARC deallocs** as above, plus a handful of genuinely missing bodies.

So the headline number was dominated by tooling and naming, and the audit's real value was
separating those from the four real gaps. The scanner is now fixed for each shape it missed; a
future run reporting a missing method is more likely to mean one.

## Scale

Only **143 of 6140** constants carry a same-line `@ghidraAddress` — about 2%. The annotation audit
therefore cannot reach the class of defect that breaks a screen, and a clean run of
`tools/audit_ghidra_addresses.py` is necessary but nowhere near sufficient. Every screen-level
defect found so far came from reading a specific routine's disassembly.

## A truncated variadic in the store product-id mapping

`+[StoreUtil productIDForPackID:]` (`0x859f8`) and `+[StoreUtil pidToProductID:]` (`0x874a0`) both
built their result from a bare `@"%05d"`, so a pack id of 12 became `"00012"` rather than
`"rbplus.pack00012"`. Ten call sites feed those strings straight into StoreKit product lookups and
`-[RBPurchaseManager isPurchased:]`, so every pack and extend-note purchase check was querying an
identifier no product has.

The binary's format is `@"%@%05d"`, with the prefix passed as the first variadic argument. That
argument lives in the `stp x8,x2,[sp, #-0x10]!` immediately before the `bl`, which is precisely
what a decompile of a variadic `objc_msgSend` does not show: Ghidra renders only the fixed
arguments, so the reconstruction was written against a silently truncated call and still compiled.

The tell was visible without the disassembly. `kPackProductIDPrefix` and `kNoteProductIDPrefix`
were both defined and neither was ever referenced. A dead string constant sitting next to a format
call is a dropped variadic argument until proven otherwise, and it is worth grepping for that shape
directly rather than waiting to reach these routines in address order.

Also worth recording because the names actively mislead: `pidToProductID:` vends _extend-note_
identifiers (`rbplus.note`), not the pack ones its generic name suggests.

## The same file's affiliate parser, found by the same tell

Chasing the one remaining unreferenced string constant in the tree, `kITunesHost`, led straight to
`+[StoreUtil affiliateParametersFromURL:]` (`0x86b9c`) and two more defects.

The parameter is an `NSURL *`. The routine sends it `-host` and `-query` directly and contains no
`URLWithString:` call at all, yet the reconstruction typed the parameter `NSString *` and opened
with a parse step the binary never performs. Worse, the mismatch had already been _noticed_: two
call sites passed `url.absoluteString` under a comment explaining that the header types the
parameter as a string, and a third passed the `NSURL` through a `static_cast<id>`. That third one
reached `+[NSURL URLWithString:]` with an `NSURL` argument.

The dead constant marked the second defect. `-host` is compared against `itunes.apple.com`, and a
mismatch branches to the epilogue with the result register zeroed, so a non-iTunes link returns nil
instead of having its query scraped for affiliate parameters. The reconstruction had no host test.

Two lessons generalise past this file. A comment at a call site explaining why an argument is
being converted is evidence that the callee's signature is wrong, not a note worth keeping — the
same shape as the `(id)`-cast method-kind inversions recorded above. And a `cbz` on a `__DATA` slot
immediately before it is read, as guards all three `SKStoreProductParameter*` loads here, is a
weak-imported framework symbol rather than application logic; it should not be reconstructed as a
branch.

## Sweeping the class instead of the instances

Both StoreUtil defects share a root cause that no amount of reading reconstructed source will
reliably surface: a variadic `objc_msgSend` decompiles with its stack-passed arguments missing, so
the reconstruction loses an argument and still compiles. `tools/scan_format_calls.py` now checks
the whole tree for the shapes that leave a trace in the source.

Two of its checks gate the exit code, and both are clean: no format call disagrees with its
argument count, and no file-local string constant is defined without being referenced. That is a
real result for the 6343-method surface rather than for one routine, and the arity check passing
also independently confirms the `"%@%05d"` correction.

The third check is advisory and worth explaining, because its precision is poor by design. It
looks for a prefix constant this tree strips but never emits, which is the only shape that exposes
the product-id defect: `"%05d"` is internally consistent, and the prefixes were referenced — by
the inverse mappings, which stripped a prefix the forward mappings never added. Run against the
tree as it stood before the fix it names both. Run against the tree today it names twelve
`applilink://` scheme and query-key constants that are all correct, because the remote ad and
reward pages build those URLs and the app only parses them. Two true positives against twelve
false ones makes it a lead worth following, not a gate.

Both scans were regression-tested against the pre-fix commit rather than assumed to work; a
checker that has only ever reported success has not been shown to check anything.

## The idiom-branch class, swept

The layout defects fixed earlier all had the same shape: the binary branches on `IsPad()` and the
reconstruction keeps one arm, so a constant that is right for the phone is applied to the pad too.
That class is enumerable rather than discoverable one routine at a time, because every call site of
`IsPad()` at `0x1a1200` is an xref.

**This section first reported 99 call sites in 61 methods and called the sweep complete. That was
wrong.** The Ghidra bridge's `get_xrefs_to` caps its result set at 100 rows unless `limit` is
passed, and both the count and the completeness claim were taken from the truncated response. The
true figure is **311 call sites in 172 methods**, so the first pass covered under a third of them.
Any xref query against this bridge needs an explicit `limit`, and a result of exactly 99 or 100
rows should be read as a truncation until proven otherwise.

Re-run over all 311, four methods call `IsPad()` with no idiom branch in the owning method's body.
None is a defect, and the three distinct reasons are each worth knowing, because each is a way this
sweep reports a false positive:

- **Identical arms.** `-[RBTermView showTermView:]`,
  `-[RBStoreManageSortViewController tableView:didSelectRowAtIndexPath:]`, and
  `-[RBStoreGenreViewController tableView:didSelectRowAtIndexPath:]` branch on the result and then
  run instruction-identical arms — the same `sharedInstance`/`thema` pair, the same
  `hideSortSelect:0`, the same `hideGenreSelect:0`. The idiom has no behavioural effect, so having
  no branch is correct rather than collapsed.
- **The branch lives in a de-inlined helper.** `-[RBCustomView toUnlock:]` and `-toCustomize:` hold
  the idiom test in `-placeEffectOverlayOverButton:`, which the binary inlines into both. Since the
  reconstruction rules ask for repeated blocks to be extracted, this is the expected shape rather
  than an exception, and a body-scoped scan cannot see it.
- **A selector-prefix collision in the scanner.** `-[RBMenuView collectionView:cellForItemAtIndexPath:]`
  has a real pad-only arm setting `cell.artistLabel.text` from `cell.musicData.artistName`, and the
  reconstruction has it. The first pass matched `-collectionView:numberOfItemsInSection:` instead;
  the extractor now parses the full selector from the signature.

Twelve further methods could not have their bodies located. All twelve are synthesised property
accessors (`-setFailureBlock:`, `-setLineSize:`, and similar) which have no body in the tree by
design, so those call sites belong to whatever the linker placed after them — attribution noise,
not coverage gaps.

### `-[RBMusicOtherView SetupView]`, checked in full

The one hit that looked substantial was this one, at `0x1a4a38`: eight `IsPad()` calls, and a
reconstruction whose visible branch is on `thema` rather than the idiom. It is correct, and
recording why saves the next pass from re-deriving it.

The top-level split really is the theme — `w19` holds `thema` and `cbz w19,0x1a56b4` at `0x1a4c10`
selects the column count — so `kToggleColumnCountWide`/`Narrow` being chosen by theme matches the
binary despite names that read as pad/phone. The idiom dimension is all inside
`-buildToggleColumnAtIndex:…`, which the binary inlines per column, and which does carry it.

The reconstruction also carries a comment claiming the binary's second `thema` read branches three
ways but that every arm routes on the idiom alone. That claim is now checked and true: at
`0x1a5254` the switch is genuinely three-way (`cbz w27` then `cmp #1`/`b.ne`), each arm tests
`IsPad()`, and all three pad arms converge at `0x1a52f0` while all three non-pad arms converge at
`0x1a5368`. The theme has no effect on the result.

Its constants match: bar rest left `11.0` on the phone (`fmov` at `0x1a5370`) and `18.0` on the pad
(`0x1a52f8`), against `kBarRestLeftDefault`/`Variant`; width adjust `-22.0` on the phone
(`0x1a5368`) against `kBarWidthAdjustDefault`. The pad's adjust arrives from the stack slot
`[sp, #0x98]` rather than an immediate and is **not** verified here, so `kBarWidthAdjustVariant`
(`-36.0`) remains open.

One methodological trap is worth recording, because it nearly produced a fabricated defect in the
other direction. Ghidra prints an `fmov` immediate as a signed hexadecimal that looks like an IEEE
bit pattern, and decoding `-0x3fca000000000000` that way gives `-0.203125`, which would have made
the correct `-22.0` look wrong. The immediate is an 8-bit arm64 VFP field, not a bit pattern: decode
it from the instruction word (`0x1e76d000` → `imm8 = 0xb6` → `-22.0`). The same trap is already
recorded above for `-1.0` in `-[RBMenuButton setupView:]`. Decode the word, never the printed form.

Two limits, so this is not read as more than it is. The sweep proves each method that consults the
idiom either has the branch or provably does not need it; it says nothing about whether the
constants inside each arm are right, which still needs the frame-fit check. And it covers `IsPad()`
only — the `[RBUserSettingData thema]` split has 117 read sites and has not been swept.

## The theme-branch class, swept

The companion enumeration to the idiom sweep above, and run the same way: every read of the `thema`
selector reference at `0x3bfa48` is an xref, **118 of them across 103 methods** (with `limit` passed
— see the truncation warning above).

Eleven methods read the theme with no theme reference in the owning body, and all eleven are false
positives of the modes already catalogued:

- **Nine** are the `-[RBUserSettingData reset*:]` family — `resetBgmType:`, `resetShotType:`,
  `resetExplosionType:`, `resetFrameType:`, `resetBackgroundType:`, `resetNoteType:`,
  `resetGaugeStyle:`, `resetShotVolume:`, `resetBackgroundBrightness:`. Each mirrors its option into
  `customizeItems[thema]`, and the reconstruction does exactly that through the file-static helper
  `RBWriteCustomizeValue`, which the binary inlines into all nine. Checked against `0x1f6ba0`:
  `setBgmType:`, then `customizeItems`, then `thema`, then `objectAtIndex:`, then
  `setValue:forKey:kBGMTypeKey`.
- `-[RBTermAgreeView showTermView]` (`0x1c6c50`) branches at `0x1c6cac` into two arms that both send
  `thema` and nothing else — identical arms, so no branch is owed.
- `-[RBCustomSelectCollectionView setupView]` (`0x155670`) reads the theme twice and handles both:
  `thema == 2` via `cset` at `0x155a38` for the gauge Y pair, and a three-way switch at `0x156394`
  for the page-indicator tints, whose theme-1 arm loads the `0.5` and `0.667` the file already
  declares. This was an extraction artefact on my side, not a gap.

Both sweeps are therefore clean, and together they cover the two discriminators behind every
layout defect fixed in this tree so far. What neither can show is whether the constants _inside_ a
correctly-branched arm are right; that is the frame-fit check, and it is still the open one.

## The frame-fit class, in the part that can be automated

The third sweep. Most of the frame-fit rule needs a runtime parent size and cannot be automated,
but one part can: where every argument folds to a number, some results are wrong whatever the
parent turns out to be. `tools/scan_frame_arithmetic.py` reports a negative width or height and a
negative cap inset, the two shapes that have already occurred here.

The first version of it was worthless and the regression test is what showed that. It folded only
named constants, so run against the commit before the cap-inset fix it reported nothing — because
the defect went through `capInset = wideFont ? kBackgroundCapInsetWide : kBackgroundCapInsetNarrow`,
a ternary-assigned local. That is this codebase's dominant layout idiom, and a defect usually lives
in **one arm only**, so folding a single arm cannot find it. Folding both arms and reporting any
reachable negative catches it: `kBackgroundCapInsetTotal` (25) minus the wide inset (36) is −11, the
recorded defect, and the narrow arm is fine at 0. The tree today is clean.

Coverage is the number to keep in view, because a clean run means little without it. Only **139 of
686** `CGRectMake` calls fold completely (20%), against **18 of 31** `UIEdgeInsetsMake` (58%). The
other 80% of frames are built from a runtime `bounds` or an image size and are invisible to any
source-level check; they need the disassembly read that the per-method audit is for. So this is a
floor under the class, not the class swept.

That makes three sweeps run and clean — idiom, theme, and the constant-folded part of frame fit —
and it is worth being plain that all three together cannot substitute for reading the remaining
1666 bodies. Each sweep rules out one shape of defect across the whole surface. None of them can
tell whether a frame recovered from the pool holds the right numbers, which is what the two
`StoreUtil` defects and every layout defect in the table above turned out to be.

## Vendored SSZipArchive diverges from the shipped build

Two `SSZipArchive` methods do not match the binary, and both differences run the same way: the
vendored source in this tree is a _newer, better_ upstream than the one the app shipped with.

`-open` (`0x1c35b8`) sends `-UTF8String` to `_path` and passes the result to `zipOpen` with a mode
of 0. The tree calls `-fileSystemRepresentation`, which is the correct API for a path and is what
later upstream releases use. Different selector, same intent.

`-close` (`0x1c3b58`) is the larger gap. The binary calls `zipClose(_zip, NULL)` and then executes
`mov w0,#0x1`, overwriting the return value, so it reports success unconditionally. It also never
writes `_zip` back. The tree captures `zipClose`'s result, returns `error == ZIP_OK`, and nils
`_zip`. So the shipped app cannot detect a failed close and leaves a dangling handle, and this tree
fixes both.

Neither is marked verified, because verified means read and matching. The `NSAssert` in each is not
part of the difference: assertions compile out of a release build, so their absence from the binary
is expected.

Two more instances turned up later, both milder than the first pair and both the same shape. The
binary's `+unzipFileAtPath:toDestination:delegate:` (`0x1c23c0`) and
`+unzipFileAtPath:toDestination:overwrite:password:error:` (`0x1c232c`) each forward to the
six-argument `+unzipFileAtPath:toDestination:overwrite:password:error:delegate:`, supplying nil for
whichever arguments they do not take. The tree's versions skip that hop and call the nine-argument
form directly, with the same values plus `preserveAttributes:YES` and nil handlers — which is what
the six-argument form supplies anyway. The net behaviour is identical and only the call chain
differs, so both are recorded here rather than touched.

The one convenience form that matches the binary exactly is `+unzipFileAtPath:toDestination:`,
which forwards to the delegate variant with a nil delegate; it is verified.

This needs a decision rather than a fix. Everywhere else the rule is to match the shipped binary and
gate deliberate deviations behind `ENABLE_PATCHES` with an entry in [PATCHES.md](PATCHES.md), but
these live in vendored third-party code where carrying a maintained upstream is the ordinary
practice. Reverting them would restore a real bug (an unreported close failure) for fidelity's sake.
Recorded here so the choice is made deliberately instead of by whoever next reads the file.

## A signed bounds check where the binary tests unsigned

`TwitterImageCreater`'s nine `…Side:` setters each guard their write with a bounds test on the
column index. The reconstruction wrote `if (side < kScoreColumnCount)` with `side` declared `int`,
which is a **signed** comparison. The binary's is `cmp w3,#0x1` followed by `b.ls` (or `b.hi` to
skip, at `0x87a70`), and both are **unsigned**.

The difference only shows on a negative index, which is exactly why it survived review: for every
sensible input the two agree. On `side = -1` the reconstruction passes the test and evaluates
`m_Score[-1]`, reading an object pointer from before the array, while the binary rejects it because
`(unsigned)-1` is far above 1. All nine now cast to `unsigned int`, matching the single unsigned
compare the binary performs.

Each of the nine was checked individually at `0x87930`, `0x87958`, `0x87980`, `0x879a8`, `0x879d0`,
`0x879f8`, `0x87a20`, `0x87a48`, and `0x87a70` rather than the family inferred from one, because a
single member using a signed compare would have made a blanket change wrong.

The tell generalises: an array index guarded only from above is worth re-reading, and the condition
codes say which comparison the binary meant. `b.lt`/`b.ge` are signed, `b.ls`/`b.hi` are not, and
the decompiler renders both as `<`.

Swept the rest of the tree for the same shape — a signed parameter guarded only from above and then
used as a subscript — and the class is otherwise clean. The two other sites it surfaces,
`-[AudioManager suspendPlayer:]` and `+[MusicData GetYomiString:]`, both already reject a negative
index explicitly and both already carry a comment saying the binary's check is unsigned. So this
was a known class with one family missed rather than an unrecognised one, which is the more
reassuring of the two possibilities.

## A return-width sweep that produced 197 confident wrong answers

Having found that `-[AVBus setSource:]` and `-currentID` return `S` rather than the `unsigned int`
they were declared with, the obvious next step is to check every method the same way: the runtime
records each one's exact type encoding, so the correct integer width is data rather than judgement.

The sweep was written, run, and **discarded**. It reported 197 mismatches and every one is false.

It found `method_t` triples by scanning the whole image for any 8-byte-aligned pointer to a
printable string, then reading the next two words as `types` and `imp`. That matches real method
lists and also matches any coincidental run of bytes that happens to look like one, which in a
2.5 MB image is a great many. Two checks kill it outright. `-[neGLView BeginRender]` is at `0x3a468`
in the runtime metadata and the scan claimed `0x315568`; and four of the reported `imp` values —
`0x314ab7`, `0x310ee3`, `0x329bde`, `0x31105a` — are not 4-byte aligned, so they cannot be arm64
code at all.

Acting on it would have retyped roughly two hundred correct return types from garbage. The output
was uniform, plausible, and sorted by file, which is exactly what a broken scan looks like when its
failure mode is systematic rather than random.

The `AVBus` change stands, and the difference is instructive. That one searched for a single
selector, produced a **coherent** encoding — `S24@0:8^{AVSource=@@B}16` parses as return `S`, self
at 0, selector at 8, struct pointer at 16, total 24 — and its `imp` matched the checklist's address
for the method. The bulk scan verified neither coherence nor address.

Doing this properly means walking `__objc_classlist` to each `class_ro_t` and reading its
`baseMethods` list, which is what `tools/objc_update.py` already does to build the checklist.

**Redone on that footing, and the class is clean.** `tools/scan_return_widths.py` reuses that
parsing, so every `method_t` comes from a real method list. It reads 3962 selectors with a types
string and reports **no** mismatch anywhere in the tree. Run against the commit before the `AVBus`
fix it names `-setSource:` and `-currentID` as `unsigned int` against an `S` encoding, so the zero
is a measured result rather than an untested checker reporting success.

The contrast between the two runs is the whole lesson: same question, same binary, same afternoon,
197 confident wrong answers from a plausible shortcut and 0 correct ones from the real walk.

## The return-width sweep does not cover parameters

`+[RBHttpUtil initWithPostURL:post:contentType:]` forwards to the four-argument form with a default
timeout. The binary supplies it with a **single-precision** `fmov` (`ftype` 0, value 15.0), and the
four-argument initialiser's types string is `@44@0:8@16@24@32f40` — its timeout parameter encodes
`f`, a float, not `d`.

The parameter itself was already declared `(float)` in both the header and the implementation, so
the signature was right. The constant feeding it was not: `kDefaultPostTimeoutInterval` was an
`NSTimeInterval`, which is a double, narrowed implicitly at its only call site. It is now a `float`.
Its neighbour `kDefaultTimeoutInterval` stays an `NSTimeInterval`, and that is correct — it feeds
Foundation's `-initWithURL:cachePolicy:timeoutInterval:`, whose parameter genuinely is one.

The point worth recording is the gap this exposes in `tools/scan_return_widths.py`. That tool reads
each `method_t` types string but compares only the **return** encoding, which is the first field.
Every parameter encoding sits in the same string and is equally checkable, and a wrong parameter
width is the more dangerous of the two: a widened return is usually harmless, whereas a `double`
parameter where the callee expects a `float` mismatches the calling convention outright. Extending
the sweep across parameters is the obvious next piece of work on that tool.

### The parameter sweep, attempted and discarded

Extending the width check across parameters was the obvious next step, so it was prototyped. It
reported 16 mismatches and **none of them can be trusted**, for a reason worth recording because it
is not the same mistake as the byte-scan failure above.

Selectors are global in Objective-C, and two classes may implement the same one with different
signatures. `all_types()` returns a **selector-keyed** dictionary, so when two classes define
`-UpdateScore:` the later one silently replaces the earlier. Both exist here:
`-[RBMusicARView UpdateScore:]` at `0xc1690` encodes `v20@0:8f16` and `-[RBMusicScoreView
UpdateScore:]` at `0xca138` encodes `v20@0:8i16`. The scan compared the surviving `i` against
`RBMusicARView`'s `(float)` declaration and reported a defect.

`RBMusicARView`'s declaration is correct, which the disassembly confirms independently: its body
opens with `fmul s0,s0,s1`, so the argument arrives in a floating-point register, not `w2`.
"Fixing" it to `int` would have broken a correct method — and the same collision invalidates the
other fifteen reports until each is re-derived.

Two lessons. **Key method metadata by implementation address, not by selector.**
`scan_return_widths.py` shared this flaw, and it is now fixed: it keys each `method_t` by its `imp`
and attributes the declaration through `OBJC_METHODS.md`'s own class-and-address rows rather than
by matching a selector. The difference is not small — 6397 implementations against the 3962
selectors the old keying reported, so roughly 2400 methods were being collapsed away. The result is
still no mismatch anywhere, but it is now a result about implementations rather than about
whichever class happened to be last. And **a bulk scan that has not
been checked against one independently-known case is not evidence**, however coherent its output —
that is now twice in one session, 197 wrong answers from a byte scan and 16 from a keying error,
both plausible-looking.

The class remains real and worth doing: parameter widths are more consequential than return widths,
because a `double` passed where a `float` is expected mismatches the calling convention outright.
It needs keying by `imp` and cross-referencing against `OBJC_METHODS.md` to attribute each encoding
to its class.

### Redone with correct keying, and it finds real defects

With `method_t` keyed by `imp` and attributed through the checklist, the sweep was extended across
parameters. The `-[RBMusicARView UpdateScore:]` false positive is gone, which is the result the
keying fix was supposed to produce, and three genuine defects appear:

- `-[StorePackMusicView setBG:]` (`0xfd100`) took a `BOOL` where the encoding is `i`. The binary
  clamps the argument to `[0, 1]` with **signed** `gt` and `lt` tests, and the lower clamp is
  unreachable for a `BOOL`, so the parameter is a signed int. The file's own comments already said
  it "clamps its argument into this range", contradicting its declared type.
- `-[RBCustomSelectView getCollectionViewMargin]` (`0x16889c`) and `-getCollectionViewStartY:`
  (`0x168850`) both returned `CGFloat`, a double, where the encodings are `f`. Both bodies use
  single-precision registers throughout — the `fcsel` pairs are `s0`/`s1`, not `d0`/`d1`. Worth
  noting that both methods had already been read and verified by hand earlier the same day: the
  constants were checked and correct, and the return width was simply not something that pass
  looked at. A mechanical check and a careful read cover different ground.

`StoreUtil`'s three URL builders — `+musicInfoURL:`, `+packListURL:limit:genre:`, and
`+packInfoURL:UserOpen:` — took `int` where the encodings are `I`, and are fixed. That one had a
second witness needing no disassembly at all: each forwards straight to a `NetworkUtil` method that
already declares the same parameter `unsigned int`, and the sibling `+extendNoteInfoURL:UserOpen:`
was already unsigned. The wrappers disagreed with both the binary and their own callees.

`RBMenuTutorialView`'s three tutorial-type parameters took `NSUInteger` where the encodings are
`I`. The decisive evidence was the property they feed: `-tutorialStatus` encodes `I16@0:8` and
`-setTutorialStatus:` encodes `v20@0:8I16`, so the step identifier is a 32-bit unsigned int
throughout and the property was `NSUInteger` too. Property and all three parameters are now
`unsigned int`.

Worth noting the property itself never appeared in the sweep's output. It is a synthesised
accessor with no explicit declaration in the implementation, so there is nothing for the tool to
compare against — the mismatch was only visible by following the parameters to what they are stored
into. The sweep finds declarations that disagree; it cannot find a declaration that is not written.

`-[BFCodec cipherInit:keyLength:]` took an `int` length where the encoding is `Q`, which is a
genuine 32-against-64-bit size difference rather than a signedness one. The binary confirms it
directly: the prologue does `mov x19,x3`, saving the whole 64-bit register, and forwards the whole
of `x2` to the key schedule. The parameter, the file-static `SetBlowfishKey` it feeds, and the
`(int)` cast at the `NSData` overload are all corrected; the cast had been narrowing an
`NSUInteger` length back down.

The last five were signedness rather than size, and all are now corrected, leaving the sweep at
**zero mismatches across 3097 matched declarations**. Three carried their own corroboration in the
source, needing no disassembly at all:

- `-[RBViewController playGameWithMusicData:RandSeed:]` took `int` where the encoding is `I`, and
  its only caller already computes `unsigned int seed`. The declaration disagreed with its own
  caller.
- `-[StoreExtendNoteCellPhone loadExtendNoteInfo:index:]` took `NSInteger` where the encoding is
  `Q`, while the sibling `-[StoreExtendNoteView loadExtendNoteInfo:index:]` already declared the
  same parameter `NSUInteger`.
- `+[StringConvert stringTransform:withTransform:reverse:]` took `BOOL` where the encoding is `C`.
  Those differ: on this target `BOOL` is a _signed_ char and encodes `c`. The parameter is passed
  straight to `CFStringTransform`, whose last argument is CoreFoundation's `Boolean`, which is an
  _unsigned_ char — so the original declared it `Boolean`, and it now does too.

`-[RBStoreManageHeaderCell initWithReuseIdentifier:frame:section:withTarget:]` and
`-[RBMusicExtendNoteView initWithFrame:ExtendNoteID:MusicSelectedBase:]` were the plain cases,
`NSInteger` against `Q` and `unsigned int` against `i`.

## Mutual infinite recursion in the shipped `RBMusicManager` page-count setter

`-[RBMusicManager releaseClientMusic]` at `0x6cc80` is sixteen bytes long and does exactly one
thing: `mov w2,#0` and a tail branch to `objc_msgSend` with `setClientMusicPageNum:`. It is
`[self setClientMusicPageNum:0]` and nothing else.

`-[RBMusicManager setClientMusicPageNum:]` at `0x6cc90` opens by sending `releaseClientMusic` to
`self`, and then sends **`setClientMusicPageNum:` to `self`** with its own argument, before
allocating the client-music array at twenty entries per page.

So the two call each other unconditionally. Invoking either one recurses until the stack is
exhausted. Every step of that was resolved from the binary rather than inferred: both addresses
come from the class's own method list, the selector was read from its reference slot at `0x3c1158`
rather than from a decompiler label, and the receiver in both sends is the saved entry `x0`.

The reconstruction has to break the cycle, and the first attempt at doing so **did not**. It
stopped `-setClientMusicPageNum:` re-sending its own selector but left its opening
`[self releaseClientMusic]` in place — and since `-releaseClientMusic` is written as
`self.clientMusicPageNum = 0`, that call re-enters the setter, which calls release again. The
self-send was gone and the mutual cycle was not, while the commit message claimed the cycle was
broken. That error was caught only by reading the twin below.

Both are now fixed by dropping the release send from the setter as well as storing directly. The
release would have done nothing but allocate an empty array for the next line to replace, so
nothing observable is lost. This is a deliberate deviation, documented in place, and deliberately
**not** gated behind `ENABLE_PATCHES`: the faithful alternative is an immediate stack overflow, so
there is no build in which reproducing it is useful.

### The same defect in `RBExtendNoteManager`, unfixed until now

`-[RBExtendNoteManager releaseClientMusic]` at `0x1840c0` is the same sixteen-byte
`[self setClientMusicPageNum:0]`, and `-[RBExtendNoteManager setClientMusicPageNum:]` at `0x1840d0`
opens by sending `releaseClientMusic` in turn. The pair recurse identically. Its third send differs
— it stores through `setClientExtendNotePageNum:`, a differently-named property, where the music
manager sends its own selector — which is what makes the music-manager version look like a
copy-paste slip between the two classes rather than an isolated mistake.

Here the reconstruction reproduced the cycle **faithfully and therefore fatally**: calling either
method in the rebuilt code would overflow the stack. It now carries the same fix and the same note.
Worth recording as a pattern: a defect found in one class is worth grepping for in its siblings
before the finding is filed, because a reconstruction that fixed one instance is not evidence that
it fixed the others.

Recorded at length because of how it presented. It first looked like a defect in the checklist's
address mapping — a method appearing to send its own selector reads as misattribution, and that
mapping underpins every `@ghidraAddress` in the tree. The mapping turned out to be right and the
original app turned out to be broken. Confirming the attribution before doubting it was what
separated the two.

### A cycle sweep, attempted and discarded

Since the reconstruction reproduced one fatal recursion faithfully, the obvious follow-up is to
look for others: a source-level scan for methods of one class that send each other unconditionally.
It was written, run, and discarded. All eight of its reports are false.

Every one is the convenience-overload idiom — `-updateScoreData:` forwarding to
`-updateScoreData:spData:`, `-getOptionalZipData:` to `-getOptionalZipData:withDefaultName:`,
`+imageWithName:` to `+imageWithName:useCache:`. The scan's selector extraction captured only the
first keyword of a multi-part send, so a forward to a longer selector read as a self-call.

That is the third scan in this session to produce confident wrong answers, and the three share a
root cause worth naming: each compared the right things but **identified** them imprecisely — a byte
scan that mistook coincidental bytes for `method_t` triples, a map keyed by selector where selectors
are not unique, and now a selector parser that truncates. The comparison logic was sound every time;
the identification was not.

The two real recursions were found by reading, and the second only by reading the first one's
sibling. Sweeps have found real defects in this tree — the width sweep found sixteen — but each
working one compares fully-qualified identities against an independently-known reference. A sweep
that cannot name precisely what it is looking at should be discarded rather than triaged.

## Boxed-literal debt, deliberately not swept

The style rules ask for `@(x)` rather than `[NSNumber numberWith…:x]`. The tree has **99** of the
older form across roughly a dozen files, concentrated in `ScoreData.m` (25) and `MusicData.m` (6).

They are not being converted mechanically, for a reason worth recording rather than treating as
laziness. `@(x)` boxes by the **static type of the expression**, whereas the explicit constructors
name the type outright. Rewriting `numberWithUnsignedInteger:` or `numberWithLongLong:` to `@(x)`
changes the boxed type whenever the argument's declared type differs from the constructor's, and
`-[NSNumber isEqual:]` and the Core Data accessors do care. A sweep here would be a 99-site edit
whose correctness depends on the declared type at every site.

The binary is no help in deciding: `@(x)` compiles to exactly the `numberWith…:` send the
disassembly shows, so both spellings are equally faithful and the audit cannot distinguish them.
This is a style conversion to be done deliberately, per file, alongside a read of each argument's
type — not folded into a verification pass.

## Two of the three rotation base classes returned the wrong orientation masks

`-supportedInterfaceOrientations` exists three times over, once each on `RBBaseViewController`
(`0x202778`), `RBBaseTableViewController` (`0x202930`), and `RBBaseTabBarController` (`0x202b30`).
All three are instruction-identical and all three branch three ways rather than two. The phone gets
an immediate `0x1e`; the pad with no music playing gets `0x6`; otherwise a `csel x20,x9,x8,eq`
picks `4` over `2` on `cmp x0,#2` against the current interface orientation.

`0x6` is `Portrait | PortraitUpsideDown` and `4` is `PortraitUpsideDown`. Two of the three
reconstructions spelled those two arms `Portrait | LandscapeLeft` and `LandscapeLeft`, which are
`18` and `16`. Both are now corrected.

Three independent things agree that the portrait pair is right, which is what makes this a
transcription slip rather than a reading to be argued about:

- `RBBaseTabBarController`, the third sibling, already spelled both arms as the portrait pair.
- `-shouldAutorotateToInterfaceOrientation:` on all three classes tests `sub x8,x19,#1` /
  `cmp x8,#1` / `b.hi`, which admits exactly orientations 1 and 2 and rejects every landscape
  one. Its record entry already said so before this was found.
- No other `UIInterfaceOrientationMask` site in the tree names `LandscapeLeft` on the pad path.

The consequence was user-visible: an iPad holding a rotation lock during playback would have been
told landscape-left was acceptable, when the binary permits only the two portrait orientations —
and the class's own legacy predicate would have refused the rotation it advertised.

The lesson is the one the recursion pair taught earlier. A method that exists in three near-copies
must be read in all three; the copies disagreeing is the signal, and reading only the one that
turned up in the candidate list would have found nothing.

## The duplicate-key guard was blind to seventeen entries, including by construction

The guard added earlier to `tools/objc_update.py` re-reads its own source and counts the keys of
the `VERIFIED` literal, because a duplicate key in a dict literal is silent: Python keeps the last
value and discards the earlier one, so a method's recorded evidence disappears with no error and no
change in the count.

It found the keys with `re.finditer(r'^\s*(0x[0-9a-fA-F]+)\s*:', ...)`, which only matches a key at
the start of a line. Seventeen entries share a line with the end of the previous entry's value, so
the guard could not see them at all — and those seventeen are exactly the ones whose irregular
formatting makes an accidental duplicate most likely in the first place. A check cannot be relied
on where its blind spot and its risk coincide.

It now parses the module with `ast` and walks the literal's keys, which sees every entry regardless
of layout. Demonstrated rather than assumed: injecting a second `0x3d154` into a copy makes the new
guard exit 1 and name the address, while the old pattern reports nothing on that same file, because
it sees only the injected line-start copy and never the original.

This surfaced from an arithmetic disagreement rather than from reading the code. A count of
verified rows came to sixteen more than the evidence entries could account for, which looked at
first like the generator marking rows verified on its own. It was the opposite: the measuring script
shared the guard's regex and so undercounted the evidence. The generator was right the whole time.

`OBJC_METHODS.md` now states the split outright — of the 4974 verified, 3507 come from the two
mechanical passes and 1467 were read by hand — because the percentage alone invites the wrong
reading. A mechanical pass proves one narrow property of a simple body. Every defect recorded in
this file came from a hand read.

## The address audit's primary check never ran, hiding 31 wrong annotations

`tools/audit_ghidra_addresses.py` checks each `@ghidraAddress` against the runtime metadata, and it
handles two annotation styles: a tag in the comment block above the signature, and a tag inside the
method body. The second was correct. The first was not, in three ways at once.

`Binary.method_map()` is keyed by class, kind, and selector and holds absolute addresses, and
`Binary.category_map()` is keyed by kind and selector. That branch looked the first up with a
`(class, selector)` pair, the second with a bare selector string, and then compared the result to a
relative address without rebasing. No lookup could ever hit. Every method annotated above its
signature — **1010 of 1808** — was silently counted as "absent from the metadata" and never
checked. The mismatch branch had never once executed, which is why it also passed the wrong number
of fields to its own `MethodFinding` and would have raised `TypeError` if it ever had.

So `0 mismatched` meant "the 798 annotated inside a body agree", not "every annotation agrees". The
headline was true and the reading of it was wrong, which is the same failure as the duplicate-key
guard above: a check whose blind spot is invisible from its own output.

With the branch fixed to match the working one, 31 annotations disagreed. They fall into three
groups, and none is random:

- **Off-by-one-slot chains.** In runs of adjacent trivial methods, each tag carried its
  neighbour's address: `RBCampaignViewController`'s alert-delegate trio, `RecommendAdAreaView`'s
  five notices, `neWindow`'s three touch handlers, and the `alertView:willDismissWithButtonIndex:`
  and `alertViewCancel:` pairs in both pad detail views. Every one is four bytes low, which is one
  `ret`-sized method.
- **A swapped pair.** `RBStoreExtendNoteList` `-downloaderProceed:` and `-downloaderError:` hold
  each other's addresses exactly.
- **Data addresses instead of code.** Four `+sharedInstance` tags — `RBBonusData`,
  `RBCampaignData`, `RBUnlockData`, `RBUserSettingData` — pointed at the static instance pointer in
  `__data` rather than at the method. `0x3df580` is where the singleton is stored; `0x1f3df8` is the
  routine that vends it.

All 31 are corrected and the audit now reports `0 mismatched` with the check genuinely running, and
"absent from the metadata" down from 1010 to 45. The lesson is worth stating plainly, because it has
now cost twice: when a verification tool reports a clean run, confirm it can see a planted defect
before believing the number.

## The 45 annotations the address audit still cannot match, and why each is fine

Fixing the check above left 45 annotations whose class and selector the metadata does not contain.
They were checked rather than assumed benign, and they fall into three groups, none of which is a
defect:

- **De-inlined helpers.** The reconstruction splits large routines into named helpers, and those
  names are ours, not the binary's. `RBMenuView -buildMenuBarWithThema:isPad:backgroundUsesEffectView:`
  and `RBCustomSelectCollectionView -buildClassicItemsWithLevelTables:` are examples. Several share
  one address on purpose, because they are arms of one routine: the three `RBMenuTutorialView`
  `revealBubble…` helpers all carry `0x13de2c`, and both `snapContentViewOpaque…` helpers carry
  `0x13f7f0`.
- **Category selectors the binary defines twice.** `+showGameCenterError` exists at both `0xdf34`
  and `0x16a6a4`, and `+deleteAlertViewWithDelegate:` at both `0xdc98` and `0x169c24`. A category's
  own metadata does not name the class it extends, so the audit keys categories on kind and
  selector alone and deliberately maps an ambiguous selector to nothing rather than pick an arm. The
  annotations are right; the lookup correctly declines to guess.
- **`.cxx_destruct` annotated as `dealloc`.** `StoreExtendNoteDetailViewPad -dealloc` carries
  `0x271bc`, which is the compiler-generated `.cxx_destruct`, and the body says so. The class
  defines no `dealloc` of its own, so there is nothing for the metadata to match.

The number is worth keeping in view as it changes. A new entry in the first group is ordinary, but a
new one in neither group means an annotation naming a method that does not exist.

## A truncated variadic returned an empty dictionary, and the header called it deliberate

`-[ApplilinkWebAPI commonParameters]` at `0x221184` was reconstructed as `return @{};`, and its
header documented that as intentional: "An empty dictionary; the shipped build adds no common
parameters." Both were wrong, and the second is worse than the first, because a confident comment
stops the next reader looking.

The binary builds it with a nil-terminated `dictionaryWithObjectsAndKeys:`. `x2` carries the first
object and the stack carries the rest: `stp x10,x9,[sp]` and `stp x8,xzr,[sp,#0x10]`, so four
objects and an explicit `nil`. That is two pairs, and the constructor takes object before key, so
the CFStrings decode to `cr` = `0` and `format` = `json`.

Every request built through `-requestWithURL:method:parameters:timeout:cachePolicy:` merges this in,
so the shipped reconstruction was dropping `format=json` from every Applilink web call.

To find out whether more of these were hiding, all 30 call sites of `dictionaryWithObjectsAndKeys:`
were enumerated from the selector's cross-references — with an explicit `limit`, since the bridge
silently caps at 100 without one — and each site's stack-slot count read from the disassembly.

The first attempt at that count was wrong, in the same direction as the defect it was hunting.
Counting every `str`/`stp` to `[sp, …]` in a window before the call also picks up local spills, so
`+[AppDelegate musicListKey]` came back as eleven slots against its five correct pairs. The
arguments are the **contiguous run from `sp+0`**, and anything past the first gap is a spill: the
stores at `[sp,#0x60]` and `[sp,#0x68]` there are locals, and the argument block runs `sp+0x00`
through `sp+0x48` with `xzr` in the last slot.

Counted that way the result carries its own check, because the block must end in the `nil` and so
must have an even slot count. Twenty-six of the thirty satisfy both, and `n` slots then means
`n / 2` pairs. Three independent confirmations: `commonParameters` gives four slots against the two
pairs recovered by hand, `+[AppDelegate getServerData]` ten against its five keychain pairs, and
`musicListKey` ten against its five.

Four did not fit the pattern. All four have since been read, and none is a defect — but two of them
correct the framing above, so "thirty call sites" is itself wrong.

- `lotteryInterstitialWithAdLocation:` at `0x22b118` reported four slots and no `nil`, because the
  window spans **two** variadic calls: a `stringWithFormat:` immediately before it, whose own four
  slots feed four `%d` specifiers. The dictionary's setup is just `stp x8,xzr,[sp]`, so one pair,
  and it overwrites the first two of the format call's slots. The reconstruction matches on both
  counts: four arguments to the format, and `message` under the `Error` key.
- `downloaderFinished:` and `NSFileManagerRB_createDirectorysAtPath` show no argument stores because
  **they are not call sites**. Both hoist the selector pointer into a stack local (`str x8,[sp,#0xf8]`
  and `str x8,[sp,#0x58]`) to reuse inside a loop, and the send happens later from the cached value.
- The `SSZipArchive` site likewise has no adjacent call.

So the cross-references are thirty _reads of the selector reference_, not thirty invocations, and a
scan that assumes a `bl` follows each one will mis-handle both hoisted loads and back-to-back
variadics. Comparing the counted sites to their reconstructions is the remaining work.

### Sweep progress, and a constructor-form inconsistency

Six of the counted sites have been compared against their reconstructions and all six agree on pair
count: `+[AppDelegate getServerData]`, `+setServerData:andB:` and `+musicListKey` at five pairs each,
`-[ApplilinkUdid bundleSeedID]` at four, the lottery site at one, and `commonParameters` at two,
which is the defect already fixed above.

One inconsistency surfaced while checking them, and it is a matter of house style rather than
correctness. `bundleSeedID` builds its keychain query as a `@{…}` literal, while the three
`AppDelegate` routines spell out `dictionaryWithObjectsAndKeys:` and carry a comment explaining why:
a literal compiles to `+dictionaryWithObjects:forKeys:count:`, so the send in the disassembly is not
the one in the source. The resulting dictionary is identical either way, so neither is wrong, but
the tree currently answers the same question two ways. The `AppDelegate` form is the more faithful
one and the comment there is worth keeping whichever way this is settled.

## A tree-wide literal sweep, and two more truncated strings

After the one-codepoint katakana defect in `+convertDJ:`, the same class of error was worth hunting
across the whole tree rather than one file. `tools/scan_literals.py` decodes every record in the
binary's `__cfstring` section — 2223 of them — and checks that each non-ASCII source literal appears
among them. Adjacent literals are joined first, because the compiler concatenates `@"a" @"b"` into
one record and a fragment alone would never match.

The check found two more defects, both truncations rather than substitutions:

- `RBStoreManageSortViewController`'s `kSortTitleArtistName` was `アーティスト名` where the binary
  has `アーティスト名順`. Its three siblings all end in 順, and the binary's record sits directly
  after `楽曲名順` in the same table, so the missing character is not a variant spelling.
- `RBTermView`'s `kTermsDefaultTitle` was `規約等および` where the binary has
  `規約等および各種注意事項`. The short form ends on a conjunction and is not a phrase.

Neither short form exists anywhere in `__cfstring`, which is what settles them: a truncated literal
is not a near-miss of the real one, it is simply absent.

Two remaining reports are explained rather than defects. `RecommendDebug` composes
`[@"テスト" stringByAppendingString:suffix]` at runtime, while the binary stores all six of
`テストA` through `テストF` whole. The values agree; only the construction differs, like the
dictionary-literal and `SSZipArchive` call-chain cases recorded above.

One caveat about the method, learned the hard way. The first version of this sweep wrote the decoded
strings to a newline-separated scratch file and read them back, which split every record containing
`\n` into fragments and reported seven false positives. The tool keeps the set in memory. The two
real findings were unaffected, since neither string contains a newline and both were confirmed by
scanning `__cfstring` for the exact text, but the count in between was wrong and the difference was
mine, not the tree's.

### Selectors, checked the same way

`@selector(...)` deserves the same treatment as a literal, and for a worse reason. Every selector
the shipped build names is a string in `__objc_methname`, and one that is not there can never match:
`respondsToSelector:` answers NO for ever and the guarded call quietly does nothing. That has no
symptom at build time and none at run time either, beyond a feature that never fires.

`tools/scan_literals.py` now checks both. Of 245 distinct selectors named across the tree, **every
one under `Project/` is present in the binary** — no invented selectors anywhere in the
reconstruction.

The only absences are four sites in the vendored `3rdparty/SSZipArchive`, naming two selectors the
shipped build's older copy does not define. The near-miss output shows these are upstream API
changes rather than typos: the binary has `zipArchiveDidUnzipFileAtIndex:totalFiles:archivePath:`
`fileInfo:` where the newer sources call the `Should` variant. That is the same vendored-version
divergence recorded above, now measured rather than assumed.

## Property attributes, checked against the metadata

The binary stores each property's attribute string verbatim — `T@"NSString",C,N,V_name` and the
like — so ownership and atomicity are recorded facts rather than inferences.
`tools/scan_properties.py` reads them from each `class_ro_t`'s property list and compares.

Twenty-seven declarations disagreed. They matter in different ways:

- **Twelve ownership defects.** Eleven properties declared `strong` where the binary says `copy`,
  and one the reverse. The difference is not stylistic: `copy` snapshots a mutable argument, while
  `strong` retains the caller's object and follows its later mutations. Most are the date and
  version strings on `RBUserSettingData`, where a caller mutating the string it passed in would
  have silently changed the stored setting.
- **Thirteen atomicity defects**, all in the same direction: the source said `nonatomic` where the
  metadata has no `N` flag and the property is therefore atomic. Atomic is the default nobody
  writes, so it is the one most easily lost.
- **Two missing `nonatomic`**, the mirror of the above.

The scan now reports zero across 1961 properties in 173 classes.

One correction to the tool was needed first, and it would have made the whole run worthless.
`retain` is the older spelling of `strong` and compiles to the same attribute, so the metadata
cannot tell them apart — but the first version could not either, and reported eighteen perfectly
correct `retain` declarations as defects. That is forty-five findings of which eighteen were noise,
and the noise was concentrated in one shape, which is exactly how a real finding gets dismissed
along with it.

## The reverse question: methods the reconstruction has that the binary does not

`OBJC_METHODS.md` answers which of the binary's methods have a reconstruction. Nothing answered the
reverse until now, and an invented method is as real a defect as a missing one — it just fails
silently instead of visibly. `tools/scan_methods.py` asks it: of 3224 definitions under `Project/`,
79 are not in the metadata.

Separating them matters more than counting them, and one question does it: does the selector name
appear in `__objc_methname` at all? A name the binary has never heard of is one the reconstruction
coined; a name it uses elsewhere is a real framework or delegate selector that this particular class
does not implement.

**Seventy-three are coined**, which is expected. The rules ask for a large routine to be split into
named parts, so those names are ours by construction.

**Six name a selector the binary uses elsewhere**, and each is accounted for:

- `RBMenuView -hitTest:withEvent:` is a deliberate probe, marked `RBPDBG: not in the binary`,
  bounded by `NE_DBG_FIRST(40)` and deferring to `super`, so touch routing is unchanged. It is one
  of 33 such probes across eight files, left in place because the crash they were added for is
  still open.
- `StoreExtendNoteDetailViewPad -dealloc` carries the `.cxx_destruct` address, as recorded above.
- The remaining four — `NetworkUtil`'s two URL builders, `RBNotificationPageView`
  `-didPresentAlertView:`, and `TwitterImageCreaterScoreElement -reset` — are worth reading on their
  own, since each names a selector the shipped build knows but does not put on that class.

The scan exits zero deliberately. Both groups have legitimate members, so this is a report to read
rather than a gate to pass, and treating it as a gate would only teach the next reader to silence it.

## A shared branch arm, and the clamp that went missing with it

`RBEffectSizeSlider -sliderChangeWithTouchPoint:` at `0x3bde0` clamps a touch that falls outside the
bar, and the reconstruction clamped it one way only. The compiler had emitted a single
`bl objc_msgSend` at `0x3be50` serving two selectors: the `b.pl` at `0x3be0c` falls through to load
`barMin` and jumps to that call, while the `b.le` at `0x3be40` falls through to load `barMax` and
falls into it. One call instruction, two arms, and the disassembler annotates it with whichever
selector load sits nearest — `barMax`. The reconstruction had collapsed both arms into a single
`else` returning `barMax`, so a touch to the left of the bar jumped to the maximum instead of the
minimum. The header's own prose said the value "is clamped to `barMin` ... `barMax`", which is the
tell that this was a transcription loss rather than a deliberate simplification.

Two smaller things in the same routine. The conversion at `0x3be88` is `fcvtas`, round to nearest
with ties away from zero, where the reconstruction used a plain C cast, which truncates; they differ
for every offset whose fractional part reaches a half step. And the `cmp`/`cinc`/`asr` that follows
is the ordinary expansion of a signed divide by two, not a hand-written shift with a correction, so
it is now spelled as the division it came from.

The lesson generalises past this routine: a shared call site is invisible in the decompile and
almost invisible in the disassembly, because only the register set up on each path distinguishes the
arms. Where a routine clamps, count the selector loads, not the calls.

## The wrong copy of the same application

Partway through checking a property width, the metadata said one thing and the disassembly said
another: an ivar encoded `Q` at eight bytes whose getter plainly read four with `ldr w0`. Both
readings were correct. They were readings of different binaries.

Three extracted copies of the application sit side by side, and only two are the shipped build.
`audit_ghidra_addresses.py` refuses to report when nearly everything disagrees, and that refusal is
what caught it — 1786 of 1811 annotated methods "mismatched", which is not a tree full of defects
but a tree checked against the wrong artefact. A checker that had dutifully printed those 1786 rows
would have sent a reader off to correct 1786 annotations that were already right.

Verify the artefact before trusting a fact derived from it. The two copies are byte-identical to
each other and differ from the third, so a hash is enough to tell them apart.

## Property types, the dimension the property scan was not checking

`scan_properties.py` reads each property's attribute string but compares only the ownership and
atomicity flags. The leading `T` field — the type encoding, and the only record of a scalar's exact
width and signedness — was parsed and discarded. `scan_property_types.py` now checks it.

It found `RBTutorialStatus`, an `NS_ENUM` backed by `NSUInteger` over a property and ivar the binary
encodes `I`: eight bytes declared where the shipped class kept four. Nothing else in the tree
reveals that. The enumeration's constants all fit either width, the code compiles, and the sentinel
`0xffffffff` is a plausible value in both. Only the metadata distinguishes them, and only the
comparisons — `cmp w0,#0x18` on a 32-bit register — corroborate it.

The scan covers 460 scalar properties and passes. It was regression-tested the only way a passing
checker can be trusted, by putting the defect back and confirming it reappears; a check that has
never failed is indistinguishable from a check that cannot fail, which this tree has already
learned once from the address audit.

Objects are deliberately out of scope: generics, protocol qualifiers, and typedefs make a wrong
answer likely enough there to cost more than it returns, so a clean run means the scalars agree and
says nothing about the rest.

## Four annotated constants that did not hold, and the two ways they failed

The constant half of the address audit had four disagreements, of three distinct kinds.

`kArtworkShadowOpacity` was a wrong value at a right address. The slot at `0x2ec6b8` holds the float
`0x3f19999a`, which is 0.6; the source said 0.15. Those two numbers share a mantissa — 0.15 is
`0x3e19999a` and 0.6 is `0x3f19999a`, one step apart in the exponent — so the misreading produces a
number that is both wrong and entirely plausible. `ldr s0,[x8, #0x6b8]` feeding `setShadowOpacity:`
at `0x1a9b94` settles it.

`kLineViewWhite` and `kTermsTextWhite` were right values at wrong addresses. Both annotations named
a page of `0x3be` where the `adrp` says `0x2ee`, and both wrong addresses landed on real selector
pointers rather than on nothing, so neither looked obviously broken. The values themselves decode
correctly at `0x2eecc0` and `0x2eecc8`. This is the third time the wrong `adrp` page has produced a
believable wrong answer in this tree.

`kProgressWidthInset` was neither: the pool holds -60.0 and the code does `fadd`, while the source
declared +60.0 and subtracted it. Arithmetically identical, and a comment had said so, but it left a
gate permanently red — which trains a reader to ignore it. It is now the negative constant the
binary stores, added as the binary adds it, matching the `kDescriptionHeightInset` convention
already used elsewhere.

## A benign divergence the literal sweep reports, and why it stays

The literal scan reports two absent strings, both in `RecommendDebug`: `テスト` and `テストアプリ`.
Neither is a defect. The binary holds `テストA` through `テストF` and `テストアプリA` through
`テストアプリF` spelled out in full, twelve records, where the reconstruction builds the same twelve
strings by appending a suffix at runtime. The output is identical and the shape is not.

It is left alone rather than guessed at: six full literals are equally consistent with an array the
original iterated and with six unrolled blocks, and the disassembly of that debug class has not been
read. The scan's two rows are documented here so the non-zero count is a known quantity rather than
a mystery for the next reader to re-derive.

## Fifteen blocks that never test the callback, and the guards written around them

`RecommendWebAPI` hands a completion block to every request it makes, and the reconstruction wrapped
each invocation in `if (callback)`. The binary does not. The failed block of
`+layoutIndexWithCallback:` at `0x234408` is the clearest case, four instructions long:

```text
ldr x0,[x0, #0x20]   ; the captured callback
ldr x3,[x0, #0x10]   ; its invoke pointer
mov x1,x2            ; the error
br  x3
```

It loads the block and dereferences it. A nil callback faults on the second instruction. The
finished block at `0x234224` is the same story over three paths — success and both error arms all
reach `blr x8` with no conditional branch anywhere in the block.

Rather than judge these one at a time by eye, all 29 annotated blocks in the file were counted for
conditional-branch-on-zero instructions. Fifteen contain **none at all** while still invoking the
callback, which settles them: a block with no `cbz` or `cbnz` cannot be testing anything for nil.
Eighteen invented guards across those fifteen blocks are now gone. The tree has seen this defect
before — an invented nil guard on a session-regenerate block was dropped earlier — and it is worth
naming the reason it recurs. A guard that cannot fire is invisible in review, reads as prudence, and
costs nothing at runtime, so nothing pushes back on it except the disassembly.

Forty-seven guards remain in this file, all in blocks that do contain a `cbz`. Those are **not**
touched, because the branch in them may be the `isKindOfClass:` test, a dictionary lookup, or a
genuine callback check, and the count alone cannot tell which. They need reading one at a time and
are left open rather than swept.

## Four more of RecommendWebAPI, and a dictionary built the long way

`+setTemporaryCacheWithAdModel:value:expiration:` and `+getTemporaryCacheWithAdModel:` both match.
The setter's expiry is the one interesting branch: `cbz` on the expiration selects `fmov d0, 1.0`
over `scvtf d0,x19`, so a zero expiration means one second rather than none.

The cache entry, though, is built with `dictionaryWithObjectsAndKeys:` where the reconstruction
writes a `@{...}` literal. The four stack slots read object, key, object, key and end in the `xzr`
nil, and they pair `status` with the value string and `expire` with the date, in that order, so the
dictionary that results is the same one. The construction is not: a literal raises on a nil value
where the variadic form silently truncates the list at the first nil. Nothing here can pass nil, so
this is recorded rather than changed, and it remains part of the open question about which spelling
this tree should prefer.

`+clickRegistWithAdIdFrom:adIdTo:adModel:` and `+appStartWithAdIdFrom:adIdTo:adType:` are request
builders rather than the thin wrappers their shorter argument lists suggest; both match, down to the
`dictionaryWithCapacity:` hints of 4 and 3 and the literal `"1"` that `kRecommendWebAPIParamTrue`
holds.

## The other forty-seven, and a filter that was too blunt

The section above left 47 guards in place because their blocks contained a `cbz`, and the count alone
could not say what the branch tested. That was the right call on the evidence available and the
wrong filter. Presence of _a_ conditional branch says nothing; what matters is whether one tests the
register holding the callback.

Re-running the sweep on that question settles the file. For each block, the registers that receive
the captured block — `ldr xN,[xM, #0x20]` — were collected, then checked for a `cbz`/`cbnz` on any
of them. **All 29 blocks report none.** The branches that had blocked the first pass turn out to be
the `isKindOfClass:` test, a `boolValue` result, and in one case the incoming error argument:
`0x22f17c` tests `w24`, a 32-bit register, which cannot be a pointer check at all.

The same question applied to the seven method bodies that guard a callback on an early-return path
gives the same answer. Six retain the callback and never test it. The seventh, `0x230dd4`, does
nil-test three registers, but they hold the `udid` and its neighbours; its callback in `x28` is
invoked through `ldr x8,[x28, #0x10]` and `blr x8` with nothing between.

So every callback invocation in `RecommendWebAPI`, in all 29 blocks and all seven bodies, is
unguarded, and all 65 invented guards are gone. The lesson is about the shape of the first filter
rather than the result: it was conservative in the direction that leaves defects in place, and it
was conservative because it measured something adjacent to the question instead of the question. A
count of branches is not a test of what a branch does.

## A delegated batch, three spot checks, and two addresses that were already done

A second delegated batch of twenty came back all matching. Three claims were re-read here before any
of it was recorded, chosen because each is falsifiable from the instructions alone rather than by
agreeing with a summary.

The first two are a matched pair. `TwitterImageCreater` has two `drawImage:` overloads, one taking a
scale and one not, and the interesting question is whether the second is genuinely scale-free or
merely has a scale of one folded in. It is genuinely scale-free: `0x87ba0` contains `fcvt d0,s8` to
widen the float scale and two `fmul` instructions producing the scaled width and height, while
`0x87c78` contains **no `fmul` at all** and subtracts the raw height. Checking the pair against each
other is what makes the answer solid; either one alone would have been a plausible reading.

The third was the three-argument variadic at `0x8657c`, read from the stack writes as the rules
require: `str x8,[sp]` then `stp x20,x19,[sp,#8]`, so the order is secret, nonce, payload, and the
secret at `0x36bd60` decodes byte for byte as the declared constant.

The batch also carried a real documentation defect. `+packIDForProductID:` was annotated
`@ghidraAddress 0x85a4c (caller reference)`, but that address is the method's own entry point — the
address audit checks it as such and passes. The parenthetical is now gone.

The part worth recording, though, is what happened on recording. Two of the twenty, `0x8f158` and
`0x90778`, were **already verified in an earlier batch**, and the only reason that is visible is the
duplicate-key guard in `objc_update.py`, which refused the write. Without it both would have been
silently overwritten and the totals would have counted eighteen new methods as twenty. So ten per
cent of that batch was redundant work, and the checklist would not have shown it. This is an
argument for the guard, and also for tracking what has been handed out: the guard catches the
double-record, but nothing catches the wasted reading before it.

## A callback declared with one parameter that the binary calls with two

`RecommendAdCache +getAllAdDataWithCallBack:` declared its completion block as
`void (^)(NSError *)`. The binary invokes it with two arguments at all three sites: `mov x1,#0`
followed by `mov x2` holding the error at `0x241cec` and `0x241d8c`, and both registers zeroed at
`0x241e5c`. The receiving block settles it from the other end — the caller's block at `0x241970`
tests `x2`, not `x1`.

This is not a typing nicety. The reconstruction's own caller declared `^(NSError *innerError)`, which
binds `innerError` to `x1`, and `x1` is nil on every path the binary takes. Its `if (innerError ==
nil)` test was therefore always true, so the failure branch could never run. A one-parameter block
called with two arguments does not crash on arm64 — the extra register is simply ignored — which is
exactly why this survived: it compiles, it runs, and it silently takes the wrong branch.

The first argument is nil at every site, so what it was meant to carry cannot be recovered from
these three; the sibling `allAdDataWithCallBack:` has the shape `(data, error)`, and this is
declared to match. The header now says the first slot is always nil, so nobody reads meaning into it
later.

Two smaller defects came with it. None of the three sites tests the callback before dereferencing
it, so its three `if (callback)` guards were invented, the same pattern found across
`RecommendWebAPI`. And two of the three block annotations were wrong: the first carried `0x241c28`,
which is the method's own IMP rather than any block, and the last read `0x241e78` where the `adr`
that builds the block literal says `0x241e5c`.

That last point is worth generalising. `audit_ghidra_addresses.py` validates every annotation on a
declaration line against the runtime metadata, and it passes on this file — because a block's
address lives inside a method body, where the tool does not look. The block annotations are
checkable all the same, and cheaply: the `adr xN,<address>` that stores the invoke pointer into the
block literal names the block, so each one can be read straight out of the enclosing routine. The
neighbouring `+getAllAdStatus` chain, `0x2418dc` into `0x241970` into `0x2419e0`, checks out exactly
that way and is correct.

## Block annotations are unchecked, and one attempt to check them that did not work

Fixing the two wrong block addresses in `+getAllAdDataWithCallBack:` raised the obvious question of
how many others are wrong. `audit_ghidra_addresses.py` cannot say: it matches annotations on
declarations against runtime metadata, and a block has no metadata. Every `@ghidraAddress` written
inside a method body is therefore unverified, and there are hundreds of them.

The idea was to build the set of addresses a block annotation is allowed to name and report anything
outside it. A stack block's invoke slot is filled by an `adr`, so decoding every `adr` in `__text`
gives a candidate set. That much works, and it discriminates correctly on the case that prompted it:
all six real block addresses around `+getAllAdStatus` and `+getAllAdDataWithCallBack:` are `adr`
targets, and both wrong ones are not.

It does not generalise, and the failures are worth recording because each is a way the tree's
conventions are richer than the model:

- A block capturing nothing compiles to a **global** block, a static structure whose invoke slot is
  a stored pointer rather than an instruction. Worse, those are annotated by the address of the
  literal itself, which is in data, not by any code address at all — `RBMenuView.mm`'s "global no-op
  proceed block" is one.
- `adr` reaches one megabyte, so a block whose invoke sits further away is named by an `adrp` and
  `add` pair.
- Even after decoding both forms and every stored pointer landing in `__text`, thirty-three
  annotations were still reported, and the first one checked, `0x507c8`, is a genuine block invoke
  that Ghidra names `HandleApplilinkInitCompletion` and types as taking a `Block_layout *`.

So the candidate set was still incomplete and the scan would have made thirty-three false
accusations. It was deleted rather than committed. A checker that is confidently wrong is worse than
no checker, because its clean runs get believed and its noisy ones get silenced — and this is the
third filter in one session that measured something adjacent to the question instead of the question.

What would work is the reverse direction: rather than guessing where invoke pointers come from, ask
the disassembler what function contains each annotated address and whether that function's first
parameter is a block layout. That is a per-address query against the Ghidra bridge rather than a
static sweep, so it is slower, but it answers the actual question and it is what settled `0x507c8`
here in one call.

## An ASCII literal the literal sweep cannot see

`ScoreData +totalScore` fetches with the predicate `tuneID IN %@`. The reconstruction had it as
`tuneID in %@`. `NSPredicate` treats its keywords case-insensitively, so nothing behaves
differently, and it is corrected only because the tree's rule is to carry the binary's literals
verbatim.

The interesting part is why nothing caught it. `scan_literals.py` decodes all 2223 `__cfstring`
records and checks every source literal against them, and it passes on this file — because it only
checks **non-ASCII** literals. That scope was deliberate: it was built to catch truncated Japanese
strings, where a missing character is invisible in review, and checking every ASCII literal in the
tree against the pool would have meant handling every runtime-composed string as a false positive.

The consequence is worth stating plainly rather than leaving implied. Every ASCII string in the
reconstruction is unchecked. A wrong predicate keyword is harmless; a wrong dictionary key, defaults
key, or format specifier is not, and those are all ASCII. The sweep's clean run means the non-ASCII
literals agree and says nothing whatever about the rest, which is the same shape of limit already
recorded for the address audit and the property scan.

**Correction, same session.** The paragraph above is right that the literal was unchecked and wrong
about what the literal is. There are **two** strings in the binary, `tuneID in %@` at `0x36acc0` and
`tuneID IN %@` at `0x36ace0`, and the two fetches use one each: `+getScoreDatas:` the lowercase,
`+totalScore` the uppercase. The reconstruction had collapsed them into one constant, and the first
fix here changed that shared constant to uppercase — correcting one call site and breaking the
other, which is a worse state than before, since the tree then disagreed with the binary at a place
that had previously agreed with it.

It was caught one method later, by reading `+getScoreDatas:` and seeing the disassembler print the
lowercase form. Both constants now exist and each fetch uses its own. The lesson is narrow and
worth having: a literal shared between two call sites is an assumption about the original source,
not an observation, and a single decoded string only ever proves what one call site holds.
