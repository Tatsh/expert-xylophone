#!/usr/bin/env python3
"""
Check every ``@property``'s declared attributes against the class's runtime metadata.

The binary stores each property's attribute string verbatim — ``T@"NSString",C,N,V_name`` and the
like — so the memory semantics and the atomicity are recorded facts rather than inferences. That
matters because the three ownership attributes differ in ways nothing else reveals:

``copy`` snapshots a mutable argument, ``strong`` retains the caller's object and follows its later
mutations, and ``weak`` does neither and nils itself. Declaring ``strong`` where the binary says
``copy`` means a caller mutating the string it passed in silently changes this object's state.
Declaring ``strong`` where the binary says ``weak`` turns a back-reference into a retain cycle that
leaks the pair. Neither shows up as a warning or a crash, only as behaviour that drifts.

Atomicity is checked for the same reason and is cheaper to get wrong: a property with no ``N`` flag
is atomic, which is the default nobody writes and therefore the one most often lost.

Read-only is checked last, since a property the binary marks ``R`` but the reconstruction leaves
writable exposes a setter the shipped class never had.
"""

import argparse
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_ghidra_addresses import Binary  # noqa: E402

# class_ro_t field offsets, 64-bit ABI.
_RO_NAME = 24
_RO_PROPERTIES = 64
# property_t is a name pointer and an attribute-string pointer.
_PROPERTY_ENTRY = 16
# The attribute-string flags this checks. R is read-only; the rest are ownership and atomicity.
_COPY, _RETAIN, _WEAK, _NONATOMIC, _READONLY = 'C', '&', 'W', 'N', 'R'

_BLOCK_START = re.compile(r'@(?:interface|implementation)\s+(\w+)')
_PROPERTY = re.compile(r'^\s*@property\s*(?:\(([^)]*)\))?\s*[^;]*?\b(\w+)\s*;', re.M)


def property_map(binary: Binary) -> dict[str, dict[str, str]]:
    """
    Read every class's property attribute strings from the metadata.

    Returns
    -------
    dict[str, dict[str, str]]
        Class name to property name to its raw attribute string.
    """
    classlist = binary.section('__objc_classlist')
    out: dict[str, dict[str, str]] = {}
    if classlist is None:
        return out
    for index in range(classlist.size // 8):
        address, = struct.unpack_from('<Q', binary._data, classlist.offset + index * 8)
        offset = binary.offset_of(address)
        if offset is None:
            continue
        *_, data = struct.unpack_from('<QQQQQ', binary._data, offset)
        ro = binary.offset_of(data)
        if ro is None:
            continue
        name = binary.string_at(struct.unpack_from('<Q', binary._data, ro + _RO_NAME)[0])
        properties = struct.unpack_from('<Q', binary._data, ro + _RO_PROPERTIES)[0]
        list_offset = binary.offset_of(properties)
        if list_offset is None:
            continue
        _, count = struct.unpack_from('<II', binary._data, list_offset)
        found: dict[str, str] = {}
        for entry in range(count):
            base = list_offset + 8 + entry * _PROPERTY_ENTRY
            name_pointer, attributes = struct.unpack_from('<QQ', binary._data, base)
            found[binary.string_at(name_pointer)] = binary.string_at(attributes)
        out[name] = found
    return out


def _expected(attributes: str) -> set[str]:
    """Reduce a metadata attribute string to the keywords a declaration should carry."""
    flags = set(attributes.split(','))
    wanted = set()
    if _COPY in flags:
        wanted.add('copy')
    elif _WEAK in flags:
        wanted.add('weak')
    elif _RETAIN in flags:
        wanted.add('strong')
    wanted.add('nonatomic' if _NONATOMIC in flags else 'atomic')
    if _READONLY in flags:
        wanted.add('readonly')
    return wanted


def scan(root: Path, metadata: dict[str, dict[str, str]]) -> list[str]:
    """Report declared attributes that disagree with the metadata."""
    findings = []
    for path in sorted(root.rglob('*')):
        if path.suffix not in ('.m', '.mm', '.h'):
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        starts = [(m.start(), m.group(1)) for m in _BLOCK_START.finditer(text)]
        for declaration in _PROPERTY.finditer(text):
            owner = next((name for start, name in reversed(starts)
                          if start < declaration.start()), None)
            fields = metadata.get(owner) if owner else None
            if not fields:
                continue
            attributes = fields.get(declaration.group(2))
            if attributes is None:
                continue
            declared = {part.strip() for part in (declaration.group(1) or '').split(',')}
            # retain is the older spelling of strong and compiles to the same attribute, so the
            # metadata cannot tell them apart and neither should this.
            if 'retain' in declared:
                declared.add('strong')
            # An unwritten atomicity means atomic, which is the default the source rarely spells.
            if 'nonatomic' not in declared:
                declared.add('atomic')
            wanted = _expected(attributes)
            missing = {flag for flag in wanted if flag not in declared}
            # assign and unsafe_unretained are how a plain pointer is spelled; the metadata has no
            # flag for either, so their absence from `wanted` is not a disagreement.
            missing -= {'strong'} if declared & {'assign', 'unsafe_unretained'} else set()
            if missing:
                line = text[:declaration.start()].count('\n') + 1
                findings.append(f'{path}:{line} {owner}.{declaration.group(2)} declared '
                                f'{sorted(declared - {"atomic"}) or ["atomic"]} but metadata says '
                                f'{sorted(wanted)} ({attributes})')
    return findings


def main(argv=None) -> int:
    """Run the scan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the binary from inside the .ipa')
    parser.add_argument('--root', type=Path, default=Path('Project'))
    arguments = parser.parse_args(argv)

    metadata = property_map(Binary(arguments.binary))
    total = sum(len(v) for v in metadata.values())
    findings = scan(arguments.root, metadata)
    print(f'properties: {total} across {len(metadata)} classes, {len(findings)} disagreements')
    for finding in findings:
        print(f'  {finding}')
    return min(len(findings), 125)


if __name__ == '__main__':
    raise SystemExit(main())
