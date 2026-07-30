#!/usr/bin/env python3
"""Verify methods whose whole body returns a floating-point constant.

A row height, a corner radius, an arrow size: each is a method that loads one number and returns it.
The value is worth checking rather than assuming, and for these in particular, because the two ways
the compiler supplies such a number are both easy to transcribe wrongly.

``fmov d0,#imm; ret``
    The number is small and regular enough for the eight-bit immediate form, so it is in the
    instruction itself. Decoding it is exact.

``adrp xN,<page>; ldr d0,[xN,#<offset>]; ret``
    The number is in the literal pool and the instructions only say where. These constants sit in
    dense runs eight bytes apart, so the neighbouring slot holds a different but equally plausible
    value, and reading the wrong one produces a reconstruction that looks right. Reading the bytes
    at ``page + offset`` is the only way to settle it, and that is what this does.

The single-precision spellings of both are recognised too, and so is the zeroing idiom, which is
neither of the above: zero has no ``fmov`` immediate encoding, so the compiler emits ``movi d0,#0``
or ``fmov d0,xzr`` instead.

The reconstruction must return the same value and do nothing else. It may spell it as a literal or
name a constant the file defines, since the rules ask for a name rather than a bare number. The
comparison is on the value, never on the spelling. A single-precision constant is compared as
single precision, because the literal in the source is a ``double`` that only has to agree to the
width the binary actually stores.

This is disassembly, not decompiler output: the instruction words are decoded here, from the bytes.
Anything not matching one of the shapes, or whose reconstruction cannot be located, is left
unverified rather than assumed correct.

Usage: ``tools/objc_verify_float_constants.py <binary>``, where the binary is the one **inside the
.ipa**. Run ``tools/objc_update.py`` afterwards to fold the result into the checklist.
"""
import argparse
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from objc_update import IMAGE_BASE, Metadata  # noqa: E402
from objc_verify_accessors import _adrp  # noqa: E402
from objc_verify_trivial import _meaningful, _returned_constant, source_bodies  # noqa: E402

OUTPUT = 'tools/objc_verified_float_constants.txt'
_RET = 0xD65F03C0
# The longest body worth decoding here. Every shape recognised is three instructions and a return.
_SCAN = 5
# `movi d0,#0` and `fmov d0,xzr`, the two ways a zero reaches d0, neither of which is an fmov
# immediate: zero has no encoding in the eight-bit immediate form.
_ZERO_WORDS = {0x2F00E400, 0x9E6703E0}
# A name the source may give a floating-point constant, and the value beside it. Both the C++
# spelling the rules prescribe and the Objective-C one are recognised.
_NAMED = re.compile(
    r'(?:constexpr|const)\s+(?:CGFloat|double|float)\s+(\w+)\s*=\s*(-?[\d.]+)f?\s*;')


def _fmov_immediate(word: int) -> tuple[float, bool] | None:
    """Decode the eight-bit floating-point immediate of an `fmov` into d0 or s0.

    Returns the value and whether it is single precision, or None when the word is not an `fmov`
    immediate into register zero.
    """
    # The fixed fields are bits 31-21 and bits 12-5; the eight-bit immediate sits at bits 20-13 and
    # the destination register at bits 4-0, so neither may be part of the mask.
    if (word & 0xFFE01FE0) not in (0x1E601000, 0x1E201000):
        return None
    if (word & 0x1F) != 0:
        return None
    single = (word & 0xFFE01FE0) == 0x1E201000
    imm8 = (word >> 13) & 0xFF
    sign = (imm8 >> 7) & 1
    upper = (imm8 >> 6) & 1
    low = (imm8 >> 4) & 3
    fraction = imm8 & 0xF
    # The exponent is the sixth bit inverted, then that bit repeated to fill, then the two below it.
    exponent = ((1 - upper) << 10) | ((0xFF if upper else 0) << 2) | low
    bits = (sign << 63) | (exponent << 52) | (fraction << 48)
    value = struct.unpack('<d', struct.pack('<Q', bits))[0]
    return (value, single)


def _pool_load(word: int) -> tuple[int, bool] | None:
    """Decode an `ldr` of d0 or s0 at an unsigned offset, as that offset and the precision."""
    # Only bits 31-22 are fixed here: the offset occupies bits 21-10 and the base register bits 9-5,
    # so masking either of those would reject every real load. The destination is checked
    # separately, because the constant has to arrive in register zero to be the returned value.
    if (word & 0x1F) != 0:
        return None
    if (word & 0xFFC00000) == 0xFD400000:
        return ((((word >> 10) & 0xFFF) * 8), False)
    if (word & 0xFFC00000) == 0xBD400000:
        return ((((word >> 10) & 0xFFF) * 4), True)
    return None


class Body:
    """The instruction words of one method, up to and including its first return."""

    def __init__(self, metadata: Metadata, address: int) -> None:
        self.words: list[int] = []
        offset = metadata.offset_of(address)
        if offset is None:
            return
        for index in range(_SCAN):
            word = struct.unpack_from('<I', metadata._data, offset + index * 4)[0]
            self.words.append(word)
            if word == _RET:
                return
        self.words = []


def returned_constant(metadata: Metadata, address: int) -> tuple[float, bool, int | None] | None:
    """Recover the constant a body returns, when returning a constant is all it does.

    Gives the value, whether it is single precision, and the address it was read from when it came
    out of the literal pool. That address is worth having: it is what a later audit needs in order
    to re-check the value rather than trust this run.
    """
    words = Body(metadata, address).words
    if not words or words[-1] != _RET:
        return None
    body = words[:-1]
    if len(body) == 1:
        if body[0] in _ZERO_WORDS:
            return (0.0, False, None)
        immediate = _fmov_immediate(body[0])
        if immediate is not None:
            return (immediate[0], immediate[1], None)
        return None
    if len(body) == 2:
        page = _adrp(body[0], address)
        load = _pool_load(body[1])
        if page is None or load is None:
            return None
        # The `ldr` must read the page the `adrp` just formed; any other base register is a value
        # this cannot account for.
        if ((body[0] & 0x1F) != ((body[1] >> 5) & 0x1F)):
            return None
        source = page + load[0]
        offset = metadata.offset_of(source)
        if offset is None:
            return None
        if load[1]:
            value = struct.unpack_from('<f', metadata._data, offset)[0]
            return (float(value), True, source)
        value = struct.unpack_from('<d', metadata._data, offset)[0]
        return (value, False, source)
    return None


def file_float_constants(path: str) -> dict[str, float]:
    """Collect the floating-point constants a file defines, so a named return can be resolved."""
    try:
        text = Path(path).read_text()
    except OSError:
        return {}
    return {name: float(value) for name, value in _NAMED.findall(text)}


def _spelled_value(spelled: str, constants: dict[str, float]) -> float | None:
    """Read the value a `return` spells, as a literal or as a name the file defines."""
    text = spelled.strip().rstrip('f').strip()
    # A cast the rules require around a narrowing return carries no value of its own.
    text = re.sub(r'^static_cast<\s*\w+\s*>\s*\((.*)\)$', r'\1', text).strip()
    text = text.strip('()')
    try:
        return float(text)
    except ValueError:
        pass
    if text in constants:
        return constants[text]
    return None


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the shipped Mach-O from inside the .ipa')
    parser.add_argument('--root', default='Project')
    args = parser.parse_args(argv)

    metadata = Metadata(args.binary)
    methods = metadata.methods()
    if not methods:
        print('error: no Objective-C metadata found; is this the right binary?', file=sys.stderr)
        return 1
    bodies = source_bodies(args.root)

    verified: list[str] = []
    shape = 0
    unmatched = 0
    for method in methods:
        constant = returned_constant(metadata, method.address)
        if constant is None:
            continue
        shape += 1
        value, single, source = constant
        found = bodies.get((method.class_name, method.kind, method.selector))
        if found is None:
            unmatched += 1
            continue
        path, _, body = found
        spelled = _returned_constant(body)
        if spelled is None or len(_meaningful(body)) != 1:
            unmatched += 1
            continue
        theirs = _spelled_value(spelled, file_float_constants(path))
        if theirs is None:
            unmatched += 1
            continue
        # A single-precision constant is only stored to that width, so the comparison is made
        # there; a double is compared exactly, because nothing has rounded it.
        if single:
            agrees = struct.pack('<f', theirs) == struct.pack('<f', value)
        else:
            agrees = theirs == value
        if not agrees:
            where = f' from {source:#x}' if source else ''
            print(f'defect: {method.kind}[{method.class_name} {method.selector}] '
                  f'at {method.address - IMAGE_BASE:#x} returns {value!r}{where}, '
                  f'the reconstruction returns {spelled} ({theirs!r})')
            continue
        note = f'returns {value!r}'
        if source is not None:
            note += f', read from the pool at {source - IMAGE_BASE:#x}'
        verified.append(f'{method.address - IMAGE_BASE:#x} {note}')

    Path(OUTPUT).write_text('\n'.join(sorted(verified)) + '\n')
    print(f'{shape} method(s) return a floating-point constant; {len(verified)} verified, '
          f'{unmatched} had no reconstruction to compare against')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
