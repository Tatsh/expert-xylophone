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

Accepting the terms POSTs to `[NetworkUtil termAgree]`, a Konami endpoint that no longer answers, so
`-sendAgree`'s success path can never run and the acceptance is never recorded. An unpatched build
therefore shows the screen again on every launch, with no way past it.

All three themed title scenes gate the screen on `-needUpdateTerms`, so the patch reports no
outstanding terms and the screen is skipped everywhere, first install included. The screen and its
whole agree flow are left intact for an unpatched build.

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
