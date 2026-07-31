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

Nine reports remain, all signedness rather than size: `int` against `I`, `NSInteger` against `Q`,
`BOOL` against `C`, in `BFCodec`, `RBMenuTutorialView` (three), `RBStoreManageHeaderCell`,
`RBViewController`, `StoreExtendNoteCellPhone`, `StringConvert`, and `RBMusicExtendNoteView`. They
are lower risk than a width change, since the register is the same size either way, but each is
still a declaration that disagrees with the binary and each needs its own read before changing.
