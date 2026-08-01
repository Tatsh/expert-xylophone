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

## `ENABLE_PATCHES`

### Runtime strings passed as format strings

**Files:** `Project/RBStoreExtendNoteList.m` — `-parseDictionary:`,
`Project/RBStorePackList.m` — `-parseDictionary:`,
`Project/UIAlertView+RB.m` — `+showColetteThemaUnlockMessage` (0xf3e4)

Three call sites pass a runtime string to `+[NSString stringWithFormat:]` as the format itself,
with no arguments after it. The binary does exactly this, and two of the three strings
(`g_pLocalizedUpdateRequiredFormat`) carry positional `%1$@` and `%2$@` placeholders that are
therefore never substituted — the message reaches the player with the placeholders still in it.

Reading a specifier with no corresponding argument is undefined: it consumes whatever the variadic
registers happen to hold. It survived on the original because those strings came from the shipped
catalogue and the layout was stable, but it is not safe to rely on.

The patch passes the string as an argument to a literal `@"%@"` format, so no specifier inside it is
ever interpreted. The rendered text is unchanged for a catalogue string with no placeholders; for
the two that do have them, the patched build shows the placeholders literally instead of reading
absent arguments. The unpatched path keeps the original call and the `-Wformat-security` warning it
raises, which is left in place deliberately: a faithful build should keep reporting that the
original code is unsound.

### The editable Terms of Service text

**File:** `Project/RBTermAgreeView.mm` — `-setupView` (0x1c3e7c)

The terms are presented in a `UITextView`, which is editable unless told otherwise, and the binary
never tells it otherwise. `-setupView` sends that view only `-initWithFrame:`,
`-setTextContainerInset:` and `-setDelegate:`; the class implements no
`-textViewShouldBeginEditing:`; and neither the `setEditable:` selector reference at `0x3bede8` nor
the `setSelectable:` one at `0x3bf7b8` is read from this function, their callers all being other
classes. So the shipped app really does let the player type into the terms, and raises the keyboard
over a screen meant only to be read and scrolled.

The patch sets `editable` to `NO`. The delegate is left in place either way, because the scroll
callback is what enables the Agree button once the reader reaches the bottom. Nothing else about the
screen changes, and an unpatched build keeps the original's behaviour.

### The Terms of Service agreement

**File:** `Project/AppDelegate.mm` — `-needUpdateTerms` (0x4ee50)

Accepting the terms POSTs to `[NetworkUtil termAgree]`, a Konami endpoint that no longer answers, so
`-sendAgree`'s success path can never run and the acceptance is never recorded. An unpatched build
therefore shows the screen again on every launch, and there is no way past it.

All three themed title scenes gate the screen on `-needUpdateTerms`, so the patch reports no
outstanding terms and the screen is skipped everywhere, first install included. The screen and its
whole agree flow are left intact for an unpatched build.

### The music grid's per-item layout attributes

**File:** `Project/RBMusicGridLayout.m` — `-layoutAttributesForItemAtIndexPath:` (0x16de84)

The binary builds a fresh attributes object and never assigns it a frame, so it answers
`CGRectZero` for every item. It does forward the caller's index path: `x2` is left untouched across
the tail call at 0x16de9c, so the incoming argument reaches
`+layoutAttributesForCellWithIndexPath:` unchanged. Placement is left entirely to
`-layoutAttributesForElementsInRect:`, which `-prepareLayout` fills in properly.

That was sufficient on the iOS this was built for, which asked the layout for the elements in a
rect. Current UIKit also asks per item, and takes the `CGRectZero` answer at face value, so every
cell is laid out with no size and the song grid renders empty.

The patch answers with the attributes `-prepareLayout` already prepared for that index, which is
exactly what `-layoutAttributesForElementsInRect:` hands back for the same item, so the two routes
agree. An unpatched build returns the frameless object and keeps the original's behaviour.

### The query-string builder's non-string values

**File:** `Project/RBHttpUtil.m` — `+dictionaryToQueryData:` (0x36754)

The binary hands each dictionary value straight to `CFURLCreateStringByAddingPercentEscapes`,
which requires a `CFStringRef`. Several callers put `NSNumber`s in that dictionary:
`+[RBServerAPIManager unlockedAPIWithType:identity:point:]` boxes all three of its arguments, at
0x17d52c, 0x17d554 and 0x17d580, and the escape then sends `-length` to a `__NSCFNumber`.

The shipped app has the same defect. It is reached on a modern build because CoreFoundation now
forwards the unrecognised selector and raises, where the CoreFoundation this was built against did
not. The result is an abort the moment an item is unlocked for points, which also strands the
tutorial: its unlock-item step cannot be completed if completing it terminates the process.

The patch converts a non-string value with `-description` before escaping. String values take the
same path they always did, so an unpatched build is unaffected and a patched one differs only
where the binary would have crashed.

### The unzip completion callback's thread

**File:** `Project/RBResourceDownloadViewController.m` —
`-zipArchiveDidUnzipArchiveAtPath:zipInfo:unzippedPath:` (0x1ca44)

The binary is seven instructions that tail-call `-success` at 0x1ca54. SSZipArchive delivers that
callback on the detached thread running `-unzip:`, so `-success` — which dismisses the controller —
runs off the main thread. Current iOS traps that with an `EXC_BREAKPOINT` out of
`FBSMainRunLoopSerialQueue`, where the iOS this was built for tolerated it.

The patch marshals the call to the main queue. An unpatched build makes the direct call the binary
makes, and crashes on a modern device at the end of the resource download.

This deviation predates the patch convention and ran ungated for some time; it is gated and
recorded here now rather than being left as an undocumented exception.

### The sprite batch's matrix palette on a driver without the extension

**File:** `Project/GameSystem/src/Render/neSpriteInstancing.mm` —
`ne::C_SPRITE_INSTANCING_2D::EmitMatrixSprites`

Every per-sprite transform in the batch's slow path rides `GL_OES_matrix_palette`: the draw enables
the palette and the weight and matrix-index client arrays, points the latter two into the template
vertex buffer, and writes one palette matrix per sprite. The binary queries the extension once, at
`0x21c98`, only to decide whether to read the palette size, and then uses the palette
unconditionally — reasonable on its armv7 iOS targets, where it was always advertised.

Where it is not advertised, the two `glWeightPointerOES` and `glMatrixIndexPointerOES` calls never
take effect while their arrays are still enabled, so the draw walks an enabled vertex array whose
pointer is `NULL` and faults at address zero inside `gleRunVertexSubmitImmediate`. The world-space
batch has no axis-aligned fast path, so every play-field frame takes this route.

The guard also requires a bound array buffer, which was added when a zero `m_dwArrayVbo` was
thought to reach the same NULL walk by a second route. That turned out not to happen: every draw
logged on the device carried a live array buffer, and the address-zero crash this was written for
was eventually traced to three sprite batches built with zero capacity, whose constructors never
set the capacity the binary assigns. The buffer term is left in place as a cheap precondition, but
it is not what fixed anything.

The patch checks the capability the renderer already recorded. With the extension present nothing
changes and the binary's path runs exactly as before. Without it, the palette and the two skinning
arrays stay disabled, the model-view is set to identity, and each sprite's composed transform is
applied to its four quad corners on the CPU instead — the same geometry the palette matrix would
have produced, at the cost of the per-sprite matrix upload.

The unpatched build keeps the unconditional palette path, and crashes on such a driver, which is
what the original binary would do.
