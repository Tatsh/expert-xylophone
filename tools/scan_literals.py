#!/usr/bin/env python3
"""
Check every non-ASCII string literal in the tree against the binary's CFString pool.

A wrong literal is invisible to the compiler, to the linter, and to a reader: two katakana strings
differing only in a small-versus-full-size kana look identical at a glance, and a truncated one
reads as a plausible shorter label. The binary settles it, because every ``@"..."`` the shipped
build contains is a record in ``__cfstring``.

So the check is membership. Decode every record, then confirm each source literal appears among
them. A literal that does not is either a defect or an artifact of how it is written, and the
report prints the closest record so the two can be compared character by character. Three defects
have been found this way: one small kana for a full-size one, and two strings truncated mid-phrase.

Adjacent literals are joined before the lookup, since the compiler concatenates
``@"a" @"b"`` into one record, and a fragment on its own would never match.

ASCII-only literals are skipped deliberately. They are the large majority, they are readable
enough that an error in one is visible, and many are format strings, keys, or asset names that are
assembled rather than stored whole.

The same argument applies to ``@selector(...)``, so it is checked here too. Every selector the
shipped build names is a string in ``__objc_methname``, and a selector that is not there can never
match: ``respondsToSelector:`` answers NO for ever and the guarded call silently does nothing. That
failure has no symptom at build time and none at run time either, beyond a feature quietly not
working.
"""

import argparse
import difflib
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_ghidra_addresses import Binary  # noqa: E402

# One @"..." literal, honouring backslash escapes so an embedded quote does not end the match.
_LITERAL = re.compile(r'@"([^"\\]*(?:\\.[^"\\]*)*)"')
# A run of adjacent literals, which the compiler concatenates into a single record.
_RUN = re.compile(r'(?:@"(?:[^"\\]*(?:\\.[^"\\]*)*)"\s*)+')
# The CFString flag bit marking a UTF-16 record, whose length counts characters rather than bytes.
_UTF16_FLAG = 0x10
_CFSTRING_RECORD_SIZE = 32
# Below this ratio the closest record is not a near-miss and printing it only misleads.
_SIMILARITY_FLOOR = 0.5


def unescape(text: str) -> str:
    """Resolve the escapes the compiler resolves, so the comparison is against real characters."""
    return (text.replace('\\n', '\n').replace('\\t', '\t').replace('\\"', '"').replace('\\\\',
                                                                                       '\\'))


def cfstrings(binary: Binary) -> set[str]:
    """
    Decode every record in the binary's ``__cfstring`` section.

    Returns
    -------
    set[str]
        Every string literal the shipped build contains.
    """
    section = binary.section('__cfstring')
    out: set[str] = set()
    if section is None:
        return out
    for index in range(section.size // _CFSTRING_RECORD_SIZE):
        record = section.offset + index * _CFSTRING_RECORD_SIZE
        _, flags, pointer, length = struct.unpack_from('<QQQQ', binary._data, record)
        offset = binary.offset_of(pointer)
        if offset is None:
            continue
        wide = bool(flags & _UTF16_FLAG)
        raw = binary._data[offset:offset + (length * 2 if wide else length)]
        try:
            out.add(raw.decode('utf-16-le' if wide else 'utf-8'))
        except UnicodeDecodeError:
            continue
    return out


def selector_names(binary: Binary) -> set[str]:
    """
    Read every selector name the binary defines or references.

    Returns
    -------
    set[str]
        The contents of ``__objc_methname``, which is a run of null-terminated strings.
    """
    section = binary.section('__objc_methname')
    if section is None:
        return set()
    raw = binary._data[section.offset:section.offset + section.size]
    return {part.decode('utf-8', 'replace') for part in raw.split(b'\0') if part}


def scan_selectors(root: Path, names: set[str]) -> list[tuple[str, int, str]]:
    """Report every @selector() in the tree that the binary's selector table does not contain."""
    pattern = re.compile(r'@selector\(\s*([A-Za-z_][A-Za-z0-9_:]*)\s*\)')
    findings = []
    for path in sorted(root.rglob('*')):
        if path.suffix not in ('.m', '.mm'):
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        for number, line in enumerate(text.split('\n'), start=1):
            for match in pattern.finditer(line):
                if match.group(1) not in names:
                    findings.append((str(path), number, match.group(1)))
    return findings


def scan(root: Path, pool: set[str]) -> list[tuple[str, int, str]]:
    """Report every joined non-ASCII literal that the binary does not contain."""
    findings = []
    for path in sorted(root.rglob('*')):
        if path.suffix not in ('.m', '.mm'):
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        for run in _RUN.finditer(text):
            joined = ''.join(unescape(part) for part in _LITERAL.findall(run.group(0)))
            # Only non-ASCII literals are checked; see the module docstring.
            if not any(ord(character) > 0x2000 for character in joined):
                continue
            if joined not in pool:
                findings.append((str(path), text[:run.start()].count('\n') + 1, joined))
    return findings


def main(argv=None) -> int:
    """Run the scan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the binary from inside the .ipa')
    parser.add_argument('--root', type=Path, default=Path('Project'))
    arguments = parser.parse_args(argv)

    binary = Binary(arguments.binary)
    pool = cfstrings(binary)
    findings = scan(arguments.root, pool)
    print(f'literals: {len(pool)} records in the binary, {len(findings)} source literals absent')
    for path, line, literal in findings:
        print(f'  {path}:{line} {literal!r}')
        closest = difflib.get_close_matches(literal, list(pool), n=1, cutoff=_SIMILARITY_FLOOR)
        if closest:
            print(f'    closest record: {closest[0]!r}')

    names = selector_names(binary)
    selectors = scan_selectors(arguments.root, names)
    print(f'selectors: {len(names)} names in the binary, {len(selectors)} source selectors absent')
    for path, line, selector in selectors:
        print(f'  {path}:{line} @selector({selector})')
        closest = difflib.get_close_matches(selector, list(names), n=1, cutoff=_SIMILARITY_FLOOR)
        if closest:
            print(f'    closest name: {closest[0]}')
    return min(len(findings) + len(selectors), 125)


if __name__ == '__main__':
    raise SystemExit(main())
