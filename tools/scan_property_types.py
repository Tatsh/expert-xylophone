#!/usr/bin/env python3
"""
Check every scalar ``@property``'s declared type against the class's runtime metadata.

``scan_properties.py`` reads the same attribute strings but compares only their ownership and
atomicity flags, so the leading ``T`` field — the type encoding — went unchecked. That field is the
one place the binary records a scalar's exact width and signedness, and it is where a whole class of
error hides. An ``NS_ENUM`` backed by ``NSUInteger`` over a field the binary encodes ``I`` is
eight bytes where the shipped class kept four: it compiles, it runs, and every read of the ivar
straddles the next field. Nothing else in the tree reveals it, because the enumeration's own
constants all fit either width.

Only scalars are compared. An object property's encoding names its class, which is worth checking
too, but generics, protocol qualifiers, and typedefs make a wrong answer likely enough there that
including it would cost more in false reports than it returns. A property whose declared type this
cannot resolve to a scalar, or whose metadata encoding is not a scalar, is skipped rather than
guessed at, so a clean run means the scalars agree and says nothing about the rest.

Enumeration typedefs are resolved through their ``NS_ENUM``/``NS_OPTIONS``/``NS_CLOSED_ENUM``
declaration, since that backing is what determines the width the compiler emits.
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_ghidra_addresses import Binary  # noqa: E402
from scan_properties import property_map  # noqa: E402

# The 64-bit encodings. BOOL is the C99 bool on arm64, so it encodes B rather than the c it used to
# on the 32-bit builds; CGFloat and NSTimeInterval are both double there.
_SCALARS = {
    'BOOL': 'B',
    'Boolean': 'C',
    'CGFloat': 'd',
    'NSInteger': 'q',
    'NSTimeInterval': 'd',
    'NSUInteger': 'Q',
    '_Bool': 'B',
    'bool': 'B',
    'char': 'c',
    'double': 'd',
    'float': 'f',
    'int': 'i',
    'int16_t': 's',
    'int32_t': 'i',
    'int64_t': 'q',
    'long': 'q',
    'long long': 'q',
    'short': 's',
    'signed': 'i',
    'signed char': 'c',
    'signed int': 'i',
    'signed short': 's',
    'uint16_t': 'S',
    'uint32_t': 'I',
    'uint64_t': 'Q',
    'unsigned': 'I',
    'unsigned char': 'C',
    'unsigned int': 'I',
    'unsigned long': 'Q',
    'unsigned long long': 'Q',
    'unsigned short': 'S',
}

_BLOCK_START = re.compile(r'@(?:interface|implementation)\s+(\w+)')
_PROPERTY = re.compile(r'^[ \t]*@property\s*(?:\([^)]*\))?\s*([^;]+?)\s+(\w+)\s*;', re.M)
_ENUM = re.compile(r'typedef\s+NS_(?:CLOSED_)?(?:ENUM|OPTIONS)\s*\(\s*([\w\s]+?)\s*,\s*(\w+)\s*\)')
# Qualifiers that may sit in front of a type without changing its width.
_QUALIFIERS = re.compile(r'\b(?:nullable|nonnull|null_unspecified|_Nullable|_Nonnull|const|'
                         r'volatile|__block|__weak|__strong|__unsafe_unretained)\b')


def enum_backings(root: Path) -> dict[str, str]:
    """Map each enumeration typedef's name to the encoding of the type backing it."""
    backings: dict[str, str] = {}
    for path in sorted(root.rglob('*.h')):
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        for match in _ENUM.finditer(text):
            encoding = _SCALARS.get(' '.join(match.group(1).split()))
            if encoding is not None:
                backings[match.group(2)] = encoding
    return backings


def _encoding_of(declared: str, backings: dict[str, str]) -> str | None:
    """Resolve a declared type to its encoding letter, or None when it is not a plain scalar."""
    text = ' '.join(_QUALIFIERS.sub(' ', declared).split())
    if not text or any(character in text for character in '*<^(['):
        return None
    return _SCALARS.get(text) or backings.get(text)


def scan(root: Path, metadata: dict[str, dict[str, str]]) -> list[str]:
    """Report declared scalar types whose width or signedness disagrees with the metadata."""
    backings = enum_backings(root)
    findings = []
    for path in sorted(root.rglob('*')):
        if path.suffix not in ('.h', '.m', '.mm'):
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        starts = [(m.start(), m.group(1)) for m in _BLOCK_START.finditer(text)]
        for declaration in _PROPERTY.finditer(text):
            owner = next((name for start, name in reversed(starts)
                          if start < declaration.start()), None)
            attributes = (metadata.get(owner) or {}).get(declaration.group(2)) if owner else None
            if attributes is None:
                continue
            actual = attributes.split(',')[0][1:]
            if actual not in _SCALARS.values():
                continue
            expected = _encoding_of(declaration.group(1), backings)
            if expected is None or expected == actual:
                continue
            line = text[:declaration.start()].count('\n') + 1
            findings.append(f'{path}:{line} {owner}.{declaration.group(2)} declared '
                            f'{" ".join(declaration.group(1).split())!r} ({expected}) but the '
                            f'metadata encodes it {actual} ({attributes})')
    return findings


def main(argv=None) -> int:
    """Run the scan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the binary from inside the .ipa')
    parser.add_argument('--root', type=Path, default=Path('Project'))
    arguments = parser.parse_args(argv)

    metadata = property_map(Binary(arguments.binary))
    findings = scan(arguments.root, metadata)
    scalars = sum(1 for fields in metadata.values() for attributes in fields.values()
                  if attributes.split(',')[0][1:] in _SCALARS.values())
    print(f'scalar properties: {scalars} in the metadata, {len(findings)} disagreements')
    for finding in findings:
        print(f'  {finding}')
    return min(len(findings), 125)


if __name__ == '__main__':
    raise SystemExit(main())
