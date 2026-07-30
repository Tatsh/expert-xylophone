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
