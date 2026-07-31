#!/usr/bin/env python3
"""
Find accessors the binary implements by hand that the reconstruction leaves to a ``@property``.

Declaring a ``@property`` makes the compiler emit a getter and a setter, which satisfies those
selectors as far as every other check in this tree is concerned: the checklist counts the method as
reconstructed, the address audit finds an implementation to point at, and nothing notices that the
body is a synthesised ivar move. When the shipped class implemented that accessor by hand, the whole
routine is missing and the omission is invisible.

``-[RBMusicView setMusicData:]`` was one. The binary implements it in 1063 instructions: it fills
the jacket, the score readout, the name strips, the panel background and the BPM strip. The
reconstruction declared ``musicData`` as a plain property, so assigning it stored an ivar and drew
nothing, and the picked-song panel came up blank. That defect survived every existing check.

Size is what separates the two cases, and the split is not subtle. Across the 3260 accessors the
median body is 4 instructions and three quarters of them are 14 or fewer — a load and a return, or
an ARC retain, store and release. A hand-written accessor is an order of magnitude larger. This
reports any accessor whose body exceeds a threshold and which the source does not define explicitly,
so an accessor the reconstruction genuinely wrote is not reported however large it is.

Size is measured to the routine's first ``ret``, bounded by the next implementation address. The
gap alone is not a size: methods are not laid out contiguously, and measuring that way reported
``-[RBPastelManager setType:]`` as 230 instructions when it is a four-instruction store followed by
unrelated code. Stopping at the first ``ret`` can only understate a routine that returns early,
which costs a missed report rather than a false accusation.
"""

import argparse
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_ghidra_addresses import Binary  # noqa: E402
from objc_update import IMAGE_BASE, Metadata, _selector_of  # noqa: E402

# Bodies at or below this many instructions are what a synthesised accessor compiles to: a bare
# load and return, or an ARC retain, store and release. The 95th percentile of every accessor in
# the image is 14, so this leaves ordinary accessors alone and still catches a routine.
_TRIVIAL_INSTRUCTIONS = 24

# The arm64 encoding of `ret`, which ends every accessor that is not a tail call.
_RET = 0xD65F03C0

_BLOCK = re.compile(r'^@implementation\s+(\w+)')
_METHOD = re.compile(r'^\s*([-+])\s*\([^)]*\)\s*(.*)$')
_END = re.compile(r'^@end')


def defined_methods(root: Path) -> set[tuple[str, str, str]]:
    """Every method the source defines explicitly, as ``(class, kind, selector)``."""
    found: set[tuple[str, str, str]] = set()
    for path in sorted(root.rglob('*')):
        if path.suffix not in ('.m', '.mm'):
            continue
        try:
            lines = path.read_text(encoding='utf-8').splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        current: str | None = None
        for index, line in enumerate(lines):
            opened = _BLOCK.match(line)
            if opened is not None:
                current = opened.group(1)
                continue
            if _END.match(line):
                current = None
                continue
            if current is None:
                continue
            method = _METHOD.match(line)
            if method is None:
                continue
            # A selector can wrap across lines when clang-format splits its keywords.
            chunk = method.group(2)
            cursor = index
            while '{' not in chunk and ';' not in chunk and cursor - index < 24:
                cursor += 1
                if cursor >= len(lines):
                    break
                chunk += ' ' + lines[cursor]
            selector = _selector_of(chunk)
            if selector:
                found.add((current, method.group(1), selector))
    return found


def scan(root: Path, binary: Path, limit: int) -> list[str]:
    """Report accessors the binary implements by hand and the source leaves synthesised."""
    methods = Metadata(binary).methods()
    addresses = sorted({m.address for m in methods})
    following = dict(zip(addresses, addresses[1:]))
    defined = defined_methods(root)
    image = Binary(binary)
    text = image.section('__text')

    def body_length(address: int, bound: int) -> int:
        """Instructions up to and including the routine's first ret, or the bound."""
        start = text.offset + (address - text.address)
        for index in range(bound):
            word, = struct.unpack_from('<I', image._data, start + index * 4)
            if word == _RET:
                return index + 1
        return bound

    findings = []
    for method in methods:
        if not method.accessor:
            continue
        end = following.get(method.address)
        if end is None:
            continue
        instructions = body_length(method.address, (end - method.address) // 4)
        if instructions <= limit:
            continue
        owner = method.class_name.split(' (')[0]
        if (owner, method.kind, method.selector) in defined:
            continue
        findings.append(f'{method.class_name} {method.kind}{method.selector} is '
                        f'{instructions} instructions at '
                        f'{method.address - IMAGE_BASE:#x}, but the source only declares a property')
    return findings


def main(argv=None) -> int:
    """Run the scan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the binary from inside the .ipa')
    parser.add_argument('--root', type=Path, default=Path('Project'))
    parser.add_argument('--limit', type=int, default=_TRIVIAL_INSTRUCTIONS,
                        help='the largest body still considered a synthesised accessor')
    arguments = parser.parse_args(argv)

    findings = scan(arguments.root, arguments.binary, arguments.limit)
    print(f'accessors over {arguments.limit} instructions with no explicit definition: '
          f'{len(findings)}')
    for finding in sorted(findings):
        print(f'  {finding}')
    return min(len(findings), 125)


if __name__ == '__main__':
    raise SystemExit(main())
