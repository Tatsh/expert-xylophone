#!/usr/bin/env python3
"""
Check every ivar the reconstruction names against the class's own runtime metadata.

An ivar is the one part of a class the binary describes completely: its name, its exact type
encoding, and its size in bytes. So a reconstruction can be checked against it rather than argued
about, and two distinct errors become visible.

The first is a name that does not exist. That is a compile error in the real class, so it only
happens when a reconstructed ``@interface`` invents a field the shipped class never had, or spells
one differently. Such a field is not merely cosmetic: code reads and writes it happily while the
shipped build kept its state somewhere else.

The second is a width that disagrees. The encoding says whether a field is a four-byte ``int``
(``i``) or an eight-byte ``NSInteger`` (``q``), whether it is signed, and whether a boolean is
``BOOL`` (``c``, signed char) or a CoreFoundation ``Boolean`` (``C``, unsigned char). Declaring the
wrong one changes what the field can hold and, for the sub-64-bit cases, silently truncates.

Only ivars declared inside an ``@interface`` block are checked, since those are the ones with a
metadata counterpart. A local, a property-backed synthesised field the source never names, or a
C++ member of an engine class has nothing to compare against.
"""

import argparse
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_ghidra_addresses import Binary  # noqa: E402

# class_ro_t field offsets, 64-bit ABI: the name and the ivar list.
_RO_NAME = 24
_RO_IVARS = 48
# ivar_t is offset pointer, name, type, alignment, size.
_IVAR_ENTRY = 32
# The encodings whose declared spelling this checks, mapped to the C type the rules require.
_ENCODING_TO_TYPE = {
    'c': 'char', 'C': 'unsigned char', 's': 'short', 'S': 'unsigned short',
    'i': 'int', 'I': 'unsigned int', 'q': 'NSInteger', 'Q': 'NSUInteger',
    'f': 'float', 'd': 'double', 'B': 'BOOL',
}
# The start of a class body that may carry an ivar block. Both spellings are checked: the
# reconstruction puts ivars under @implementation as often as under @interface.
#
# The gap before the brace is deliberately narrow. Excluding ; and @ stops a class extension such
# as `@interface X ()` — whose body holds method declarations and no brace — from running on into
# the following @implementation and lending it its own name. Excluding the parenthesis and the two
# method sigils stops a class with no ivar block at all from claiming the first method body it
# happens to precede. An earlier version allowed both, which reported a method-local `static` as a
# missing ivar while missing a real invented one in a sibling class.
_BLOCK_START = re.compile(r'@(?:interface|implementation)\s+(\w+)[^;@{()+\-]*\{')
_DECLARATION = re.compile(r'^\s*([A-Za-z_][\w\s*<>,]*?)\s*(\*?\s*)(\b[A-Za-z_]\w*)\s*;', re.M)


def _balanced(text: str, open_brace: int) -> tuple[str, int]:
    """Return the body between @p open_brace and its matching close, and the closing index."""
    depth = 0
    for index in range(open_brace, len(text)):
        if text[index] == '{':
            depth += 1
        elif text[index] == '}':
            depth -= 1
            if depth == 0:
                return text[open_brace + 1:index], index
    return '', len(text)


def ivar_map(binary: Binary) -> dict[str, dict[str, tuple[str, int]]]:
    """
    Read every class's ivars from the runtime metadata.

    Returns
    -------
    dict[str, dict[str, tuple[str, int]]]
        Class name to ivar name to its type encoding and byte size.
    """
    classlist = binary.section('__objc_classlist')
    out: dict[str, dict[str, tuple[str, int]]] = {}
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
        ivars = struct.unpack_from('<Q', binary._data, ro + _RO_IVARS)[0]
        list_offset = binary.offset_of(ivars)
        if list_offset is None:
            continue
        _, count = struct.unpack_from('<II', binary._data, list_offset)
        fields: dict[str, tuple[str, int]] = {}
        for entry in range(count):
            base = list_offset + 8 + entry * _IVAR_ENTRY
            _, name_pointer, type_pointer, _, size = struct.unpack_from('<QQQII', binary._data,
                                                                       base)
            fields[binary.string_at(name_pointer)] = (binary.string_at(type_pointer), size)
        out[name] = fields
    return out


def scan(root: Path, metadata: dict[str, dict[str, tuple[str, int]]]) -> list[str]:
    """Report ivars the metadata does not define, and declared types that disagree with it."""
    findings = []
    for path in sorted(root.rglob('*')):
        if path.suffix not in ('.m', '.mm', '.h'):
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        for block in _BLOCK_START.finditer(text):
            class_name = block.group(1)
            body, _ = _balanced(text, block.end() - 1)
            fields = metadata.get(class_name)
            if fields is None:
                continue
            line_base = text[:block.end()].count('\n') + 1
            for declaration in _DECLARATION.finditer(body):
                declared, star, field = declaration.groups()
                declared = declared.strip()
                if declared in ('return', 'else') or not field:
                    continue
                line = line_base + body[:declaration.start()].count('\n')
                if field not in fields:
                    findings.append(f'{path}:{line} {class_name}.{field} is not in the metadata')
                    continue
                encoding, _ = fields[field]
                expected = _ENCODING_TO_TYPE.get(encoding)
                # Only the scalar encodings are checked, and only when the source names a plain C
                # or Cocoa type. A typedef such as GLuint or an int-backed NS_ENUM resolves to the
                # right width and is not evidence of anything, so reporting it would bury the
                # cases that are: an int where the field encodes q, or the reverse.
                if declared not in _ENCODING_TO_TYPE.values():
                    continue
                if expected is not None and not star and declared != expected:
                    findings.append(f'{path}:{line} {class_name}.{field} declared {declared!r} '
                                    f'but encodes {encoding!r}, which is {expected}')
    return findings


def main(argv=None) -> int:
    """Run the scan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the binary from inside the .ipa')
    parser.add_argument('--root', type=Path, default=Path('Project'))
    arguments = parser.parse_args(argv)

    metadata = ivar_map(Binary(arguments.binary))
    total = sum(len(v) for v in metadata.values())
    findings = scan(arguments.root, metadata)
    print(f'ivars: {total} across {len(metadata)} classes, {len(findings)} disagreements')
    for finding in findings:
        print(f'  {finding}')
    return min(len(findings), 125)


if __name__ == '__main__':
    raise SystemExit(main())
