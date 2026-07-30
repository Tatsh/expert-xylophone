#!/usr/bin/env python3
"""Verify methods whose whole body is trivial, and record which ones hold.

Some methods do nothing, and some do nothing but return a constant. Both are checkable without
judgement, and both are worth checking rather than assuming: a method the binary leaves empty while
the reconstruction gives it real work is a fidelity defect, and a constant return is exactly the
kind of value that gets transcribed wrong without anything noticing.

Three shapes are recognised, all read from the instruction words:

``ret``
    The body does nothing. The reconstruction must also do nothing, ignoring documentation comments
    and the ``(void)argument;`` discards the rules ask for on a deliberately unused parameter.

``mov w0,#imm; ret`` and ``mov x0,#imm; ret``
    The body returns a constant. The reconstruction must return the same value, in any of the
    spellings that mean it — a bare integer, ``YES``/``NO``, ``nil``, or a hex literal.

This is disassembly, not decompiler output: the instruction words are decoded here, from the bytes.
Anything that does not match one of the shapes, or whose reconstruction cannot be located, is left
unverified rather than assumed correct.

Usage: ``tools/objc_verify_trivial.py <binary>``, where the binary is the one **inside the .ipa**.
"""
import argparse
import glob
import re
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from objc_update import IMAGE_BASE, Metadata, _selector_of  # noqa: E402

OUTPUT = 'tools/objc_verified_trivial.txt'
_RET = 0xD65F03C0
# Lines in a reconstructed body that do not count as work: documentation, ordinary comments, and the
# `(void)argument;` discard the rules prescribe for a parameter the binary ignores.
_INERT = re.compile(r'^\s*(?:/\*|\*|//|\(void\)\s*\w+\s*;|\}?\s*$)')
# `return` spellings that mean zero, and the ones that mean one.
_ZERO = {'0', 'NO', 'nil', 'NULL', 'nullptr', 'false', '0.0', '0x0'}
_ONE = {'1', 'YES', 'true', '0x1'}


def _mov_immediate(word: int) -> int | None:
    """Decode a 32- or 64-bit MOVZ of a small immediate, returning the value."""
    # MOVZ Wd,#imm16 is 0x52800000-shaped; MOVZ Xd,#imm16 is 0xd2800000-shaped. Only shift 0 counts,
    # since a shifted immediate is not the plain constant return this recognises.
    if (word & 0xFFE00000) in (0x52800000, 0xD2800000) and (word & 0x1F) == 0:
        return (word >> 5) & 0xFFFF
    if word == 0xAA1F03E0 or word == 0x2A1F03E0:  # mov x0,xzr / mov w0,wzr
        return 0
    return None


def source_bodies(root: str = 'Project') -> dict[tuple[str, str, str], tuple[str, int, list[str]]]:
    """Collect each reconstructed method's body, keyed by class, kind, and selector."""
    out: dict[tuple[str, str, str], tuple[str, int, list[str]]] = {}
    files = glob.glob(f'{root}/**/*.m', recursive=True) + glob.glob(f'{root}/**/*.mm',
                                                                   recursive=True)
    for name in sorted(files):
        lines = Path(name).read_text(errors='replace').splitlines()
        current: str | None = None
        for index, line in enumerate(lines):
            opened = re.match(r'^@implementation\s+(\w+)', line)
            if opened:
                current = opened.group(1)
                continue
            if re.match(r'^@end', line):
                current = None
                continue
            if current is None:
                continue
            start = re.match(r'^([-+])\s*\([^)]*\)\s*(.+)$', line)
            if not start:
                continue
            chunk = start.group(2)
            cursor = index
            while '{' not in chunk and cursor - index < 8 and cursor + 1 < len(lines):
                cursor += 1
                chunk += ' ' + lines[cursor]
            if '{' not in chunk:
                continue
            selector = _selector_of(chunk)
            if not selector:
                continue
            body: list[str] = []
            probe = cursor + 1
            while probe < len(lines) and not lines[probe].startswith('}'):
                body.append(lines[probe])
                probe += 1
            out[(current, start.group(1), selector)] = (name, index + 1, body)
    return out


def _meaningful(body: list[str]) -> list[str]:
    """Strip the lines that do not count as work."""
    return [line for line in body if not _INERT.match(line)]


def _returned_constant(body: list[str]) -> str | None:
    """Find the sole `return` value in a body, when that is all it does."""
    meaningful = _meaningful(body)
    if len(meaningful) != 1:
        return None
    found = re.match(r'^\s*return\s+(.+?)\s*;\s*$', meaningful[0])
    return found.group(1) if found else None


def file_constants(path: str) -> dict[str, int]:
    """
    Collect the file-scope integer constants a source file defines.

    The rules require a named constant rather than a bare number, so a method that returns one
    returns a name, and the name has to be resolved before the value can be compared.
    """
    out: dict[str, int] = {}
    pattern = re.compile(r'^\s*(?:static\s+)?const(?:expr)?\s+[\w\s*]*?(\bk\w+)\s*=\s*([^;]+);')
    for line in Path(path).read_text(errors='replace').splitlines():
        found = pattern.match(line)
        if not found:
            continue
        try:
            out[found.group(1)] = int(found.group(2).strip().rstrip('fuUlL'), 0)
        except ValueError:
            continue
    return out


def _matches(value: int, spelled: str, constants: dict[str, int]) -> bool:
    """Decide whether a source `return` spelling means the constant the binary returns."""
    spelled = spelled.strip()
    if value == 0 and spelled in _ZERO:
        return True
    if value == 1 and spelled in _ONE:
        return True
    if spelled in constants:
        return constants[spelled] == value
    try:
        return int(spelled, 0) == value
    except ValueError:
        return False


def main(argv=None) -> int:
    """Verify every trivially-shaped method, and record the ones that hold."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the shipped Mach-O from inside the .ipa')
    args = parser.parse_args(argv)
    if not args.binary.is_file():
        print(f'error: no such binary: {args.binary}', file=sys.stderr)
        return 1
    metadata = Metadata(args.binary)
    bodies = source_bodies()
    passed: list[tuple[int, str]] = []
    findings: list[str] = []
    skipped: Counter = Counter()
    for method in metadata.methods():
        if method.accessor or method.selector.startswith('.cxx_'):
            continue
        offset = metadata.offset_of(method.address)
        if offset is None:
            continue
        words = [struct.unpack_from('<I', metadata._data, offset + i * 4)[0] for i in range(2)]
        empty = words[0] == _RET
        constant = _mov_immediate(words[0]) if words[1] == _RET else None
        if not empty and constant is None:
            continue
        key = (method.class_name, method.kind, method.selector)
        found = bodies.get(key)
        if found is None:
            skipped['no reconstruction located'] += 1
            continue
        path, line, body = found
        relative = method.address - IMAGE_BASE
        if empty:
            extra = _meaningful(body)
            if extra:
                findings.append(
                    f'{path}:{line} {method.kind}[{method.class_name} {method.selector}] is '
                    f'empty at {relative:#x} but the reconstruction does {len(extra)} '
                    f'thing(s): {extra[0].strip()[:50]}')
                continue
            passed.append((relative, f'{method.class_name} {method.selector}: empty'))
            continue
        spelled = _returned_constant(body)
        if spelled is None:
            skipped['reconstruction is not a lone return'] += 1
            continue
        if not _matches(constant, spelled, file_constants(path)):
            findings.append(
                f'{path}:{line} {method.kind}[{method.class_name} {method.selector}] returns '
                f'{constant} at {relative:#x}, reconstruction returns {spelled}')
            continue
        passed.append((relative, f'{method.class_name} {method.selector}: returns {constant}'))
    header = ['# Trivially-shaped methods verified against their instructions by',
              '# tools/objc_verify_trivial.py. Each either does nothing, and its reconstruction',
              '# does nothing either, or returns a constant its reconstruction also returns.']
    Path(OUTPUT).write_text('\n'.join(header + [f'{a:#x} {w}' for a, w in sorted(passed)]) + '\n')
    print(f'trivial methods verified: {len(passed)}')
    print(f'wrote {OUTPUT}')
    for reason, count in skipped.most_common():
        print(f'  skipped: {reason} ({count})')
    if findings:
        print(f'\nDEFECTS ({len(findings)}):', file=sys.stderr)
        for finding in findings:
            print(f'  {finding}', file=sys.stderr)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
