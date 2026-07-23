# Reconstruction methodology

This tree reconstructs a decompiled binary. These rules govern how to translate Ghidra output into
faithful C, C++, and Objective-C. The coding style of the resulting source lives in
[c-cpp-objc.md](c-cpp-objc.md); this file is about getting from the binary to that source correctly.

- Tie a reconstructed routine to its binary function with the `@ghidraAddress 0x...` Doxygen tag (a
  custom tag in our Doxygen configuration) on its header declaration; the address is relative to the
  program's image base. In an implementation file this tag appears only inside a block body (see the
  Objective-C block rule in `c-cpp-objc.md`).
- Keep the binary's names. Reconstructed globals keep their Ghidra names (for example the
  `g_`-prefixed globals). Ghidra placeholder names (`FUN_*`, `DAT_*`, `PTR_*`) are never used as
  identifiers in reconstructed code; rename them descriptively and record the address with
  `@ghidraAddress`.
- Model real types, not decompiler artifacts. Use real struct fields (never `field_0xNN`) and real
  pointer, enum, and `BOOL` types (never `void *` for a typed pointer, an `int` that holds a
  pointer, or `undefined`/`undefined4`).
- Document the original 32-bit struct layout with trailing `// +0xNN` offset comments, but treat
  those offsets as documentation only: do not `#pragma pack` or `static_assert` the layout, and
  never read or write a struct by a hardcoded offset. The 32-bit offsets do not hold on the 64-bit
  target, so always go through named fields.
- `reinterpret_cast` is a smell: it usually hides a type or signature bug, especially a
  function-pointer callback ABI. Prefer real types and typed access, and replace such casts at crash
  sites. `void *` is likewise a major smell: use it only for a genuinely opaque raw byte buffer (for
  example the `const void *` data argument of an MD5 helper), never for a typed engine object — those
  get their real class type.
- Recover the true function signature. A Ghidra decompile that uses `in_*` pseudo-variables (for
  example `in_w1`, `in_x2`, `in_stack_*`), or lists them under its Parameters, is missing formal
  parameters: the function takes arguments the decompiler did not bind into the prototype. Never
  model such a function as taking fewer arguments than the `in_*` usage and the disassembly's
  register/stack reads prove (in particular, never as no-arg when it clearly is not) — fix the Ghidra
  prototype, then reconstruct the real signature. Scan for `in_*` whenever a signature looks empty.
- Fix the Ghidra program itself, not only the reconstructed source. As you work a function, in
  Ghidra: give every parameter, local, and return a real type (never a bare `long`/`int`/`undefined*`
  standing in for an object or struct pointer); rename every auto-named variable (`pnVar1`, `lVar2`,
  `uVar3`, `iVar4`, `pcVar5`, …) to a meaningful name; rename and type every `DAT_*`/`FUN_*`/`PTR_*`
  global as it is encountered; and create the real `struct`/`class` types so that offset-and-cast
  access (`*(int *)(in_x0 + i * 4 + 0x28)`) becomes a named field access (`p->nSpriteCount`). A
  function whose first argument is a pointer to a structure is almost always an instance method of
  that structure's class — model it as one. This applies even when the cast is taken _adjacent_ to
  an already-named field: `*(undefined1 *)((long)&x.field + 1) = 1` means a distinct field exists at
  that offset (or the neighbouring field is modelled wrong — for example a `ushort` that is really
  two bytes). Create or correct the struct field so the access is a clean named field; never leave
  such a cast behind.
- Scrutinise return values as hard as arguments: confirm the real return type and whether the value
  is actually returned/used (a discarded return, a returned `this`, or a bool-in-a-wider-register are
  all common), and fix the Ghidra prototype accordingly.
- The decompile is a guide, not the source of truth — verify against the disassembly. If a function
  shows any hint of NEON / vectorisation (SIMD `v`/`q` registers, `ld1`/`st1`, `fmla`, `tbl`, …),
  work it from the **disassembly only**: no guessing, no "best effort" reconstruction from the
  garbled decompile.
- The C/C++ engine phase is done one routine at a time as routines are encountered, never in batches.
  For each routine, in order: (1) read the decompile; (2) fix all typing in Ghidra until the
  decompile reads like normal C++ — the full signature, every local, the return, every global, and
  every struct it reads or writes (per the rules above); (3) if the routine shows any hint of NEON /
  vectorisation, from that point work the disassembly only; (4) write the reconstruction into
  `rbplus-src/`; (5) verify the reconstruction against the disassembly. It is slow but accurate, and
  it is a long task. Do not begin writing the equivalent code until the routine is well-typed.
  `InitializeBackgroundSceneNodes` is the reference example of the target state: it has been fully
  typed in Ghidra (real `this`/struct types, named struct fields, no `in_*`, no `pnVar1`/`lVar2`
  locals, no offset-with-cast access), so its decompile now reads like ordinary C++. Bring every
  engine routine to that same standard before reconstructing it.
- For a very large function body, save the decompiler output and the disassembler output to files,
  then break the function into parts by de-inlining the repeated or logically-distinct blocks into
  helper functions, and reconstruct using those helpers. Mark such helpers `inline` (not
  `__attribute__((always_inline))`) unless the block is genuinely performance-critical and you are
  certain the `always_inline` form will compile.
