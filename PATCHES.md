# Build-time patches

This reconstruction aims to be faithful to the shipped binary, so every deliberate deviation is
gated behind a preprocessor flag. A build with the flag undefined stays as close to the original as
possible; the patched code sits under `#ifdef ENABLE_PATCHES` and the original under `#else`.

- **`ENABLE_PATCHES`** — corrections that matter on modern iOS or on 64-bit, where the original's
  behaviour depended on something the armv7 build got for free, and corrections to behaviour the
  original simply got wrong and shipped.

Enable it with `-DENABLE_PATCHES=ON` (CMake) or `make -C theos ENABLE_PATCHES=1` (Theos). The CI
build workflow enables it.

Not every difference from the binary is a patch. A wrong type, a truncated pointer, or a fabricated
method is a reconstruction defect and is simply fixed, because the binary's real behaviour is what
the corrected code expresses. Only changes that make the rebuilt app behave differently from the
original belong here.

Each section below is kept to two paragraphs.

## `ENABLE_PATCHES`

### Runtime strings passed as format strings

**Files:** `Project/RBStoreExtendNoteList.m` — `-parseDictionary:`,
`Project/RBStorePackList.m` — `-parseDictionary:`,
`Project/UIAlertView+RB.m` — `+showColetteThemaUnlockMessage` (0xf3e4)

Three call sites pass a runtime string to `+[NSString stringWithFormat:]` as the format itself, with
no arguments after it. The binary does exactly this, and two of the three
(`g_pLocalizedUpdateRequiredFormat`) carry positional `%1$@` and `%2$@` placeholders that are
therefore never substituted. Reading a specifier with no corresponding argument is undefined: it
consumes whatever the variadic registers happen to hold, which survived on the original only because
those strings came from the shipped catalogue.

The patch passes the string as an argument to a literal `@"%@"` format, so no specifier inside it is
ever interpreted. Rendered text is unchanged for a catalogue string without placeholders; the two
that have them show the placeholders literally instead of reading absent arguments. The unpatched
path keeps the original call and the `-Wformat-security` warning it raises, deliberately — a
faithful build should keep reporting that the original code is unsound.

### The editable Terms of Service text

**File:** `Project/RBTermAgreeView.mm` — `-setupView` (0x1c3e7c)

The terms are presented in a `UITextView`, which is editable unless told otherwise, and the binary
never tells it otherwise. `-setupView` sends that view only `-initWithFrame:`,
`-setTextContainerInset:` and `-setDelegate:`; the class implements no
`-textViewShouldBeginEditing:`; and neither the `setEditable:` selector reference at `0x3bede8` nor
the `setSelectable:` one at `0x3bf7b8` is read from this function. So the shipped app really does
let the player type into the terms, raising the keyboard over a screen meant only to be read.

The patch sets `editable` to `NO`. The delegate stays in place either way, because its scroll
callback is what enables the Agree button once the reader reaches the bottom. Nothing else about the
screen changes, and an unpatched build keeps the original's behaviour.

### The Terms of Service agreement

**File:** `Project/AppDelegate.mm` — `-needUpdateTerms` (0x4ee50)

Accepting the terms POSTs to `[NetworkUtil termAgree]`, and `-sendAgree` assigns `termVersion` only
inside its `success:` block, under a `kServerStatusOK` test. With that endpoint unavailable the
acceptance is never recorded, and `-needUpdateTerms` answers `YES` for a nil `termVersion` before it
ever consults `latestTermVer`, so the gate re-arms on every run.

It is not a launch-time screen: all three themed title scenes test `-needUpdateTerms` on the title
screen's touch pass and pre-empt the first tap with `-showTerms` — Colette in
`TitleColetteScene::RunMainLoop` (0x57ad8), Limelight in `TitleLimelightScene::RenderFrame`
(0x1531fc), and Classic in `TitleClassicScene::RenderFrame` (0x151934). An unpatched build therefore
cannot get past the title screen. The patch reports no outstanding terms so that tap proceeds
normally, and the screen and its whole agree flow are left intact for an unpatched build.

### The store's network gate

**File:** `Project/RBMenuView.mm` — `-SelectStoreButton`

Tapping the store button does not open the store. It POSTs the region to the terms endpoint, walks
the reply for the type 1 record, and only then either prompts to re-accept updated terms or calls
`-StoreOpen`. The reply is used for nothing else. So with no network the request fails, the
network-error alert appears, and the store never opens — taking the manage tab with it, which reads
nothing but local files: the installed tunes, their sizes, and the delete and re-download buttons.

The patch calls `-StoreOpen` directly and skips the request. Nothing is lost by it in a patched
build, because `-needUpdateTerms` already answers `NO` there, so the version the request fetches
decides about a screen that is patched out anyway. It also sidesteps a second way the original
fails to open: the store opens only from inside the loop over the terms list, so a reply carrying no
type 1 record runs neither branch and the button does nothing at all. An unpatched build keeps the
request, the terms comparison, and the alert.

### The web view's in-app link allow-list

**File:** `Project/RBWebView.m` — `-webView:shouldStartLoadWithRequest:navigationType:`

A `reflecbeat://` link carries its real destination in the query. The handler compares that
destination's host against three konaminet hostnames and loads it inside the web view when it
matches, otherwise handing it to Safari. The binary spells those three comparisons out one after
another, against a fixed table.

That is fine until the build is pointed at a replacement server with `API_HOST`, at which point its
own links fail the test and get thrown out to Safari. The patch appends the configured host to the
table and walks the whole table instead of testing the first three slots, so a redirected build
keeps its links in-app. With the default configuration the appended entry simply repeats the third,
which a membership test does not mind. An unpatched build keeps the three literal comparisons and
the three-entry table.

### Drop-in songs and extend notes

**Files:** `Project/RBMusicManager.{h,m}` — `+archiveSearchDirectories`, `+resolveArchivePath:`,
`-reconcilePurchasedMusics` (from `-loadPurchasedMusics`, 0x6b020) and `-createMusicDataArray`
(0x6c18c); `Project/RBExtendNoteManager.{h,m}` — `-addDiscoveredExtendNote:musicID:level:` and
`-createExtendNoteDataArray` (0x1834ec); `Project/MusicData.m` — `+dataWithPath:ID:` (0x5ee64)

Songs and extend notes only ever arrive by purchase: the store writes an entry into `mulist` or
`nolist` and downloads the matching `%09d.rb`. An archive copied in by hand is invisible, because
nothing lists it, and the binary looks for it in one or two fixed places. The patch adds a single
search order — `Library/Private Documents`, `Documents`, `Library/Caches`, then the `.app` itself —
used both to find drop-in archives and to resolve one for playback, and reconciles both lists
against what is actually on disk on every load, registering anything unlisted and forgetting
entries whose archive has gone. Writable locations come first so a drop-in overrides a bundled file
of the same name; `Library/Caches` is in the list because the binary already falls back to it as its
legacy download directory, and omitting it would make a legacy install's songs look missing and get
dropped from `mulist`.

Resolving has to change in three places or a discovered archive would be listed and then fail to
load, since none of the original lookups consult `Documents` or the bundle: `-createMusicDataArray`
for songs, `-createExtendNoteDataArray` for notes, and the extend lookup inside `+dataWithPath:ID:`.
An unpatched build keeps each original lookup exactly — bundle only for the preinstalled songs,
purchased-then-legacy for `mulist`, and purchased only for `nolist`.

Two of the bundle's five archives are skipped outright: the timing-adjust preview the customise
screen plays (999999999) and the tutorial tune (999999998). Both are ordinary archives loaded
straight from the bundle by identifier, so registering either would list it as a song, and
fingerprinting either would make an unlisted copy of it pair as its extend note.

Telling the two kinds apart is the whole problem, because they are indistinguishable by name or by
format: both are `%09d.rb` in the same directory, and an extend note is read by the ordinary
`MusicData` parser with its SPECIAL chart in the BASIC slot. What separates them is that an extend
note is a chart _for a song that already exists_, so it ships that song's audio byte for byte. The
patch reads the CRC-32 that the zip's own central directory records for the `bgm` entry — no
decompression, no hashing — and an unlisted archive whose audio CRC matches a known song is
registered in `nolist` as that song's extend note, with the parent taken from the match and
`ExtLevel` from the archive's own basic level. Everything else is a new song and goes to `mulist`.
Identifiers already in either list, and the three bundled songs, are skipped, which is what stops a
song appearing twice. A registered song carries its name and artist, read out of the archive: the
song list itself does not need them, but the store's manage tab draws its rows and its download and
delete prompts from those two fields rather than from the archive. It also carries an item URL built
from the configured endpoint and the archive's own name — `API_SCHEME://API_HOST` plus
`API_BASE_PATH` plus `%09d.rb` — so a replacement server serving it under that name can fetch it
again. That field
cannot simply be left out: `-[StoreDownloadTask initWithURL:]` builds its own copy with
`-[NSString initWithString:]`, which raises on nil, so an entry without one turns the manage tab's
download button into a crash. An unpatched build lists only what was bought.

### Everything unlocked, and nothing to pay for it with

**Files:** `Project/RBExperienceData.mm` — the seven `unlockWith…` queries and `-getPoint`
(0x1bb2fc); `Project/RBUnlockPackageItemData.m` — `-point`; `Project/StoreCampaignItemInfo.m` —
`-bUnlock`, `-termCheck`, `-checkNewUnlock`, `-checkExistPackList:packID:`

The `unlockWith…` methods are queries, not actions: each walks the matching item set and reports
whether it is there. They all report `YES` now, so every BGM, shot, explosion, frame, background,
tune, and theme reads as owned. Nothing outside the class touches those sets, so the patch answers
the question without writing to saved data. Alongside that, `-getPoint` reports a full purse and
every unlock item prices at nothing. Both are patched because they are separate gates:
`-[RBUnlockView yesButtonTap:]` compares cost against balance, and the balance is also what the
point label draws. `-getPoint` is the right place for the balance rather than the raw `point`
property, because the binary reads a different field per theme and answers zero on Classic — so
patching the property would have left two themes out of three unchanged.

The campaign gifts need the same treatment, and one of them exists only because of the patch above.
The tail of `-termCheck` clears its unlock whenever `-unlockWithType:ID:` says the item was already
granted, which in a patched build is always, so unlocking everything would have locked every
campaign item instead. `-termCheck` now grants outright and asks for the download button, `-bUnlock`
reports granted before it has even run, `-checkExistPackList:packID:` treats any pack as owned, and
`-checkNewUnlock` reduces to whether the item still needs downloading. `-alreadyDownload` keeps its
real value throughout: an unlocked tune still has to be fetched, unlike a BGM or a frame. An
unpatched build keeps every original check.

### Free packs and extend notes from the catalogue

**Files:** `Project/StorePackInfo.{h,m}` and `Project/StoreExtendNoteInfo.{h,m}` —
`RBStorePackIsFreeFromCatalog` and `RBStoreExtendNoteIsFreeFromCatalog`;
`Project/RBStorePageViewController.m` — `-detailViewStartPurchase:` (0x1e52f8);
`Project/RBStoreExtendPageViewController.mm` — `-startPurchase:`

A price of zero does not skip the payment flow on its own, for three separate reasons: nothing
branches on the catalogue's price anywhere, the price shown to the player is formatted from the
StoreKit product rather than from the catalogue, and `-beginPurchase:` gates on having a product and
on `+canMakePayments` and never on cost. The patch adds the missing branch, so a catalogue that
prices an item at zero grants it directly through the same `-purchaseSucceeded:` path a completed
transaction would have taken — recording the purchase, refreshing the cell, and starting the
download.

The check sits above each entry point's `product == nil` guard, because a genuinely free item need
not have a StoreKit product at all and that guard would otherwise reject it first. Free identifiers
are tracked in a file-static set filled while the catalogue is parsed, rather than on the objects,
so neither class gains an ivar or accessor the shipped one lacks; the two predicates are free
functions for the same reason. An item counts as free only when the catalogue says so explicitly —
`StoreExtendNoteInfo.price` is read with a bare `-intValue`, so an absent price leaves it at zero,
which must not be mistaken for free. A catalogue that sends no price behaves exactly as before, and
an unpatched build always goes through StoreKit.

### Skipping the first-run tutorials

**File:** `Project/RBTutorialManager.m` — `+needStartTutorialMusicselect` (0x3578c),
`+needStartTutorialPlay` (0x358ec), `+needStartTutorialCustomize` (0x35a40),
`+needStartTutorialStore` (0x35c50)

These four gates decide whether each walkthrough runs. Each answers on a stored per-tutorial seen
flag, and the play and customise ones additionally on the total record count and on whether nothing
has been unlocked yet. Under `SKIP_TUTORIAL` all four answer `NO`, so no walkthrough ever starts.

This one needs its own flag as well as `ENABLE_PATCHES`, and is guarded on both, so a patched build
still gets the tutorials unless they are asked to go. Enable with `-DSKIP_TUTORIAL=ON` (CMake) or
`SKIP_TUTORIAL=1` (Theos), alongside the patches flag. There is no need to also mark the tutorials
seen in the saved settings, the way an older tweak did by writing every status key: the four
`isTutorial…` predicates report whether a walkthrough is currently running, and with nothing ever
started they answer `NO` on their own.

### The per-install purchased-content list key

**File:** `Project/AppDelegate.mm` — `+musicListKey` (0x50cb8)

The MD5 of this key is the BFCodec key for the purchased-content lists — `mulist`, `prodlist` and
`nolist`. The binary generates a UUID once per install with `CFUUIDCreate`, stores it in the keychain
as a generic password, and reuses it thereafter. The lists are therefore readable only on the device
that wrote them, and a keychain that is cleared, not restored, or not carried across a reinstall
strands them silently: the files are still there and still decrypt to nothing useful.

The patch returns a fixed UUID instead, which makes the lists portable between devices and builds
and possible to decrypt offline. It does not consult the keychain at all, so the value is identical
everywhere rather than merely stable per install — the trade being that a list written under a
per-install key will not decrypt under a patched build, and vice versa. An unpatched build keeps the
generate-and-store behaviour exactly.

### The music grid's per-item layout attributes

**File:** `Project/RBMusicGridLayout.m` — `-layoutAttributesForItemAtIndexPath:` (0x16de84)

The binary builds a fresh attributes object and never assigns it a frame, so it answers
`CGRectZero` for every item; it does forward the caller's index path, since `x2` is untouched across
the tail call at 0x16de9c. Placement is left entirely to `-layoutAttributesForElementsInRect:`,
which `-prepareLayout` fills in properly. That was sufficient on the iOS this was built for, which
asked the layout for the elements in a rect.

Current UIKit also asks per item and takes the `CGRectZero` answer at face value, so every cell is
laid out with no size and the song grid renders empty. The patch answers with the attributes
`-prepareLayout` already prepared for that index — exactly what
`-layoutAttributesForElementsInRect:` hands back for the same item, so the two routes agree. An
unpatched build returns the frameless object.

### The query-string builder's non-string values

**File:** `Project/RBHttpUtil.m` — `+dictionaryToQueryData:` (0x36754)

The binary hands each dictionary value straight to `CFURLCreateStringByAddingPercentEscapes`, which
requires a `CFStringRef`. Several callers put `NSNumber`s in that dictionary:
`+[RBServerAPIManager unlockedAPIWithType:identity:point:]` boxes all three of its arguments, at
0x17d52c, 0x17d554 and 0x17d580, and the escape then sends `-length` to a `__NSCFNumber`.

The shipped app has the same defect; it is only reached on a modern build because CoreFoundation now
forwards the unrecognised selector and raises. The result is an abort the moment an item is unlocked
for points, which also strands the tutorial, whose unlock step cannot be completed if completing it
terminates the process. The patch converts a non-string value with `-description` before escaping,
so string values take the path they always did and a patched build differs only where the binary
would have crashed.

### The unzip completion callback's thread

**File:** `Project/RBResourceDownloadViewController.m` —
`-zipArchiveDidUnzipArchiveAtPath:zipInfo:unzippedPath:` (0x1ca44)

The binary is seven instructions that tail-call `-success` at 0x1ca54. SSZipArchive delivers that
callback on the detached thread running `-unzip:`, so `-success` — which dismisses the controller —
runs off the main thread. Current iOS traps that with an `EXC_BREAKPOINT` out of
`FBSMainRunLoopSerialQueue`, where the iOS this was built for tolerated it.

The patch marshals the call to the main queue; an unpatched build makes the direct call the binary
makes and crashes on a modern device at the end of the resource download. This deviation predates
the patch convention and ran ungated for some time — it is gated and recorded here now rather than
left as an undocumented exception.

### The sprite batch's matrix palette on a driver without the extension

**File:** `Project/GameSystem/src/Render/neSpriteInstancing.mm` —
`ne::C_SPRITE_INSTANCING_2D::EmitMatrixSprites`

Every per-sprite transform in the batch's slow path rides `GL_OES_matrix_palette`. The binary
queries the extension once, at `0x21c98`, only to decide whether to read the palette size, then uses
the palette unconditionally — reasonable on its armv7 targets, where it was always advertised. Where
it is not, the `glWeightPointerOES` and `glMatrixIndexPointerOES` calls never take effect while
their arrays stay enabled, so the draw walks an enabled vertex array whose pointer is `NULL` and
faults at address zero inside `gleRunVertexSubmitImmediate`. The world-space batch has no
axis-aligned fast path, so every play-field frame takes this route.

The patch checks the capability the renderer already recorded: with the extension present nothing
changes, and without it the palette and both skinning arrays stay disabled, the model-view is set to
identity, and each sprite's composed transform is applied to its four quad corners on the CPU
instead. The guard also requires a bound array buffer, added when a zero `m_dwArrayVbo` was thought
to reach the same NULL walk; that turned out not to happen — the address-zero crash it was written
for was traced to three sprite batches built with zero capacity — so the buffer term is a cheap
precondition rather than the fix. An unpatched build keeps the unconditional palette path.

### The bars that flicker between black and light

**File:** `Project/AppDelegate.mm` — `-application:didFinishLaunchingWithOptions:` (0x1c50)

The app was built seven years before dark mode, ships no dark assets, and sets its window to
`blackColor` — which the original relied on, because in its day every bar drew its own opaque
background over it. Two later changes break that: iOS 13 gives the app a dark appearance it has no
artwork for, and iOS 15 makes an unconfigured `UINavigationBar` or `UITabBar` fully transparent at
its scroll edge, so the black window shows through and the bars appear to flip between black and
light as content scrolls behind them.

`UIUserInterfaceStyle` in the Info.plist pins the appearance but does nothing about the
transparency: a light bar with no background over a black window is still black. The patch also sets
`overrideUserInterfaceStyle` on the window and installs opaque `UINavigationBarAppearance` and
`UITabBarAppearance` objects through the appearance proxies before any store view controller is
built, with `UITabBar`'s `scrollEdgeAppearance` set only on iOS 15 and later. An unpatched build
keeps the bare window and shows the black bars.

### The iOS 15 section-header top padding

**File:** `Project/RBStoreManageViewController.m` — `-loadView` (0x1ce97c)

`-loadView` builds a plain-style `UITableView` whose backdrop is white 47/255, and the screen's
default sort is download order, in which the table reports one section and returns nothing for both
`-tableView:heightForHeaderInSection:` and `-tableView:viewForHeaderInSection:`. On the SDK the
binary was linked against, that section began at the very top of the table.

`UITableView.sectionHeaderTopPadding` arrived in iOS 15 and defaults to
`UITableViewAutomaticDimension`, which a plain table resolves to 22 pt above every section header,
including a nil zero-height one — pushing 22 pt of the table's own dark backdrop between the
navigation bar and the first row, so the list appears to have both a stray gap and a mismatched
background. The patch sets the property to zero behind an `@available(iOS 15.0, *)` guard; an
unpatched build keeps the modern default.

### The playlist sort segments

**File:** `Project/RBPlaylistViewController.m` — `-viewWillAppear:` (0x92398)

The binary tints the music/artist sort segments by walking `segmentedControl.subviews` and sending
each child the private `-isSelected` and `-setTintColor:`, unguarded — the `-isSelected` send is at
`0x924f8`, branched on by the `cbz w0` at `0x924fc`. `UISegmentedControl` was later rebuilt on a
visual-provider architecture, so its children are background and label views that do not implement
`-isSelected`; the send reaches `-[UIResponder doesNotRecognizeSelector:]` and aborts the app the
moment the playlist screen appears. The four tint arms reduce to one rule — MUSIC always letters in
`musicColor` and ARTIST in `artistColor`, whichever is selected — and because exactly one segment is
selected at a time, the per-state API reproduces that per-segment colouring.

Setting a segment's `tintColor` did two different things depending on state, and the patch
reproduces both: the selected segment is a solid block of its own colour with the title knocked out
white, and the unselected one is transparent, outlined and lettered in its colour, on a capsule
rounded at both ends. Colours come from `self.musicColor` and `self.artistColor`, which
`-viewDidLoad` assigns per theme. This is as close as `UISegmentedControl` reaches: the outline is a
layer border on the whole control, so it also traces the filled half, where the original outlines
only the unselected segment. Closing that gap needs per-segment chrome the class does not expose —
either a `UISegmentedControl` subclass adding a border sublayer in `layoutSubviews`, or a fully
custom two-button control — and the remaining difference is one coloured line, so it is deliberately
left as is. An unpatched build keeps the unguarded walk and crashes on a modern iOS.

### The toolbar's missing shadow line

**File:** `Project/AppDelegate.mm` — `-application:didFinishLaunchingWithOptions:` (0x1c50)

The playlist popover's sort row lives in the navigation controller's toolbar. The appearance proxies
installed for `UINavigationBar` and `UITabBar` had no `UIToolbar` counterpart, so the toolbar kept
the modern transparent scroll-edge appearance and lost the shadow line that separates it from the
table above.

The patch installs an opaque `UIToolbarAppearance` alongside the other two, with
`scrollEdgeAppearance` set only on iOS 15 and later. An unpatched build leaves the toolbar
transparent and draws no separator.

### The search field's grey fill

**File:** `Project/RBMenuView.mm` — `-CreateView` (0xa47f8)

`-CreateView` sends `-setBackgroundColor:` white to the search bar at `0xa6ea0`. iOS 13 moved the
editable field into a `UISearchTextField` that draws its own translucent grey fill, which that send
no longer reaches, so the field renders grey where the shipped build renders white.

The patch sets `searchTextField.backgroundColor` as well, behind an `@available(iOS 13.0, *)` guard.
An unpatched build keeps the single original send and shows the grey field.
