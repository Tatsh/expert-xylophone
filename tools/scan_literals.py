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

    pool = cfstrings(Binary(arguments.binary))
    findings = scan(arguments.root, pool)
    print(f'literals: {len(pool)} records in the binary, {len(findings)} source literals absent')
    for path, line, literal in findings:
        print(f'  {path}:{line} {literal!r}')
        closest = difflib.get_close_matches(literal, list(pool), n=1, cutoff=_SIMILARITY_FLOOR)
        if closest:
            print(f'    closest record: {closest[0]!r}')
    return min(len(findings), 125)


if __name__ == '__main__':
    raise SystemExit(main())
