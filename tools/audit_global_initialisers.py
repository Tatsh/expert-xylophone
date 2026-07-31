#!/usr/bin/env python3
"""
Check every annotated scalar global's initial value against the shipped binary.

A global carrying an ``@ghidraAddress`` is a promise about a specific word in the image, and until
now nothing checked it. ``audit_ghidra_addresses.py`` verifies that annotated *methods* land on real
implementations and that constants annotated on a declaration line match the bytes there, but a
file-scope global initialised to ``{}`` slips past both: it compiles, it audits, and it is simply
zero at run time.

That mattered. Thirty-one of the thirty-two annotated globals in ``note_model.mm`` were ``{}`` while
the binary ships real values in ``__data`` -- ``g_nPlayfieldCentreSplit`` is 512, not 0, and
``g_nPlayfieldFieldHeight`` is 1024. Those two alone put every alt-frame sprite 512 points out,
because the load-time seeder computes each marker's Y as ``1 - centreSplit`` before anything has a
chance to recompute it. The defect was invisible in the source and only showed up as a misplaced
play field.

A global living in ``__bss`` or ``__common`` has no file-backed initialiser and is genuinely zero,
so ``{}`` is correct there and is not reported.
"""

import argparse
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_ghidra_addresses import Binary, IMAGE_BASE  # noqa: E402

# `int g_name = {};   // @ghidraAddress 0x3ce934`, with or without a leading extern.
_GLOBAL = re.compile(
    r'^(?:extern\s+)?(int|float|unsigned int)\s+(\w+)\s*=\s*(\{\}|[-\d.f]+)\s*;'
    r'\s*//\s*@ghidraAddress\s+(0x[0-9a-f]+)',
    re.M)

# Sections with no file-backed contents: a global there really is zero at load.
_ZERO_FILL = ('__bss', '__common')

# A global's storage can only live in one of these. An `@ghidraAddress` on a global that resolves
# anywhere else names something that is not a global at all, so the annotation -- and usually the
# global with it -- is invented. `g_nVariantScreenHeight` was exactly that: its 0x3c8834 landed in
# `__objc_ivar`, it was declared without an initialiser, nothing ever wrote it, and the preview
# camera read it as zero and sat 512 points off. The real load was `g_nPlayfieldFieldHeight`.
_GLOBAL_SECTIONS = ('__data', '__bss', '__common', '__const')

# An `@ghidraAddress` naming a global, in either the Doxygen or trailing-comment form.
_ANNOTATED_GLOBAL = re.compile(
    r'@ghidraAddress\s+(0x[0-9a-f]+)[^\n]*\n(?:[^\n]*\n){0,3}?'
    r'\s*(?:extern\s+|static\s+)?(?:int|float|unsigned int|double)\s+(g_\w+)\s*[=;]',
    re.M)


def value_at(binary, address, is_float):
    """The binary's initial value for a global, or None when the address is unmapped."""
    for section in binary._sections:
        if section.address <= address < section.address + section.size:
            if section.name in _ZERO_FILL:
                return 0.0
            offset = section.offset + (address - section.address)
            fmt = '<f' if is_float else '<i'
            return struct.unpack_from(fmt, binary._data, offset)[0]
    return None


def section_of(binary, address):
    """The section an address falls in, or None when it is unmapped."""
    for section in binary._sections:
        if section.address <= address < section.address + section.size:
            return section.name
    return None


def scan_misattributed(root, binary):
    """Report every global whose annotated address is not in a section a global can live in."""
    findings = []
    for path in sorted(root.rglob('*')):
        if path.suffix not in ('.mm', '.cpp', '.m', '.c', '.h'):
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        for address, name in _ANNOTATED_GLOBAL.findall(text):
            section = section_of(binary, IMAGE_BASE + int(address, 16))
            if section is not None and section not in _GLOBAL_SECTIONS:
                findings.append(f'{path.relative_to(root.parent)}: {name} is annotated {address}, '
                                f'which is in {section} -- not a global')
    return findings


def scan(root, binary_path):
    """Report every annotated global whose initialiser disagrees with the image."""
    binary = Binary(binary_path)
    findings = []
    checked = 0
    for path in sorted(root.rglob('*')):
        if path.suffix not in ('.mm', '.cpp', '.m', '.c'):
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        for ctype, name, initialiser, address in _GLOBAL.findall(text):
            checked += 1
            shipped = value_at(binary, IMAGE_BASE + int(address, 16), ctype == 'float')
            if shipped is None:
                continue
            ours = 0.0 if initialiser == '{}' else float(initialiser.rstrip('f'))
            if abs(float(shipped) - ours) > 1e-6:
                findings.append(f'{path.relative_to(root)}: {name} at {address} is '
                                f'{ours:g} but the binary ships {shipped:g}')
    return checked, findings


def main(argv=None):
    """Run the scan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the binary from inside the .ipa')
    parser.add_argument('--root', type=Path, default=Path('Project'))
    arguments = parser.parse_args(argv)

    checked, findings = scan(arguments.root, arguments.binary)
    print(f'annotated scalar globals: {checked} checked, {len(findings)} mismatched')
    for finding in sorted(findings):
        print(f'  {finding}')

    misattributed = scan_misattributed(arguments.root, Binary(arguments.binary))
    print(f'annotated global addresses: {len(misattributed)} outside any global section')
    for finding in sorted(misattributed):
        print(f'  {finding}')
    return min(len(findings) + len(misattributed), 125)


if __name__ == '__main__':
    raise SystemExit(main())
