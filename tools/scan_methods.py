#!/usr/bin/env python3
"""
Check every method the reconstruction defines against the runtime metadata.

`OBJC_METHODS.md` answers the forward question: which of the binary's methods have a
reconstruction. This answers the reverse one, which nothing else did: which of the reconstruction's
methods the binary does not have. Those fall into two very different groups, and the useful part of
this check is telling them apart.

Most are **de-inlined helpers**. The rules ask for a large routine to be broken into named parts,
so those names are ours and the metadata cannot contain them. They are not defects and there are a
lot of them.

The rest name a selector the binary *does* use somewhere else. That is the interesting shape: the
selector is real — a framework override, a delegate callback — but this class is not one of the
classes that implements it. An invented `hitTest:withEvent:` reroutes touches; an invented delegate
callback fires on a class the shipped build never wired up. So the two groups are separated by
asking whether the selector name appears in `__objc_methname` at all, which distinguishes a name we
coined from a name the binary knows.

Neither group is reported as a failure, because both have legitimate members: a helper is expected,
and a deliberate probe or an ARC-shaped `dealloc` standing in for `.cxx_destruct` is a documented
choice. The exit code stays zero and the report is for reading.
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_ghidra_addresses import Binary, _selector_of  # noqa: E402

_IMPLEMENTATION = re.compile(r'@implementation\s+(\w+)')
_METHOD_START = re.compile(r'^\s*([-+])\s*\([^)]*\)\s*(.+)$')
# How far a signature may wrap before its opening brace.
_SIGNATURE_LINES = 8


def selector_names(binary: Binary) -> set[str]:
    """Every selector name the binary contains, whether or not this class implements it."""
    section = binary.section('__objc_methname')
    if section is None:
        return set()
    raw = binary._data[section.offset:section.offset + section.size]
    return {part.decode('utf-8', 'replace') for part in raw.split(b'\0') if part}


def scan(root: Path, binary: Binary) -> tuple[int, list[tuple], list[tuple]]:
    """
    Split the reconstruction's methods into those the metadata has and those it does not.

    Returns
    -------
    tuple[int, list[tuple], list[tuple]]
        The number of definitions seen, the coined names, and the ones naming a real selector.
    """
    metadata = binary.method_map()
    categories = binary.category_map()
    names = selector_names(binary)
    coined, known = [], []
    total = 0
    for path in sorted(root.rglob('*')):
        if path.suffix not in ('.m', '.mm'):
            continue
        try:
            lines = path.read_text(encoding='utf-8').split('\n')
        except (OSError, UnicodeDecodeError):
            continue
        class_name = None
        for number, line in enumerate(lines, start=1):
            opened = _IMPLEMENTATION.match(line.strip())
            if opened:
                class_name = opened.group(1)
                continue
            if line.strip() == '@end':
                class_name = None
                continue
            if class_name is None:
                continue
            start = _METHOD_START.match(line)
            if not start:
                continue
            chunk, last = line, number - 1
            while '{' not in chunk and last - (number - 1) < _SIGNATURE_LINES and last + 1 < len(
                    lines):
                last += 1
                chunk += ' ' + lines[last]
            if '{' not in chunk:
                continue
            selector = _selector_of(chunk[chunk.index(')') + 1:])
            if not selector:
                continue
            total += 1
            kind = start.group(1)
            if (class_name, kind, selector) in metadata or (kind, selector) in categories:
                continue
            entry = (str(path), number, kind, class_name, selector)
            (known if selector in names else coined).append(entry)
    return total, coined, known


def main(argv=None) -> int:
    """Run the scan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the binary from inside the .ipa')
    parser.add_argument('--root', type=Path, default=Path('Project'))
    parser.add_argument('--helpers', action='store_true', help='also list the coined names')
    arguments = parser.parse_args(argv)

    binary = Binary(arguments.binary)
    total, coined, known = scan(arguments.root, binary)
    print(f'methods: {total} defined, {len(coined)} coined helper names, '
          f'{len(known)} naming a selector the binary uses elsewhere')
    for path, line, kind, class_name, selector in known:
        print(f'  {path}:{line} {kind}[{class_name} {selector}]')
    if arguments.helpers:
        for path, line, kind, class_name, selector in coined:
            print(f'  helper {path}:{line} {kind}[{class_name} {selector}]')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
