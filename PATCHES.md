# Build-time patches

This reconstruction aims to be faithful to the shipped binary, so every deliberate deviation is
gated behind a preprocessor flag. A build with the flag undefined stays as close to the original as
possible; the patched code sits under `#ifdef ENABLE_PATCHES` and the original under `#else`.

- **`ENABLE_PATCHES`** — corrections that matter on modern iOS or on 64-bit, where the original's
  behaviour depended on something the armv7 build got for free.

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
