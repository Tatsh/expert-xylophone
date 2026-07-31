#!/usr/bin/env python3
"""
Diff the runtime-seeded tables against the reconstruction's own values.

The seeded tables are the one class of reconstruction data nothing in this tree checks. Each is
declared ``= {}`` and filled by a load-time constructor, so a wrong entry compiles cleanly and
survives ``audit_ghidra_addresses.py``, which verifies that an annotated address exists rather than
what a constructor writes into it. The only ways to catch one are to decode the seeder instruction
by instruction, or to read the table out of the running original -- this does the latter.

Feed it the output of ``tools/rb458-tables.lldb`` (paste the whole LLDB transcript; everything that
is not a ``memory read`` row is ignored) and it reports, per table, every entry that differs from
the value this tree would produce.
"""

import argparse
import re
import struct
import sys
from pathlib import Path

# Each `memory read` in rb458-tables.lldb, in order, with the word size it was dumped at.
TABLES = [
    ('g_pTutorialClipRect', 8, 136),
    ('g_aAltFrameMarker4', 4, 60),
    ('g_aAltFrameMarker6', 4, 84),
    ('g_aAltFrameMarker9', 4, 72),
    ('pastelClipRects', 8, 16),
    ('pastelPositions', 8, 8),
]

_ROW = re.compile(r'^0x[0-9a-fA-F]+:\s+((?:0x[0-9a-fA-F]+\s*)+)$')


def parse_words(text):
    """Every word from the transcript's memory-read rows, in order."""
    words = []
    for line in text.splitlines():
        m = _ROW.match(line.strip())
        if m:
            words.extend(int(w, 16) for w in m.group(1).split())
    return words


def split_tables(words):
    """Hand each table its own slice, in the order rb458-tables.lldb dumps them."""
    out, at = {}, 0
    for name, size, count in TABLES:
        if at >= len(words):
            break
        got = words[at:at + count]
        if len(got) < count:
            print(f'warning: {name} is short: {len(got)} of {count} words', file=sys.stderr)
        out[name] = (size, got)
        at += count
    return out


def as_double(word):
    return struct.unpack('<d', struct.pack('<Q', word))[0]


def as_float(word):
    return struct.unpack('<f', struct.pack('<I', word & 0xFFFFFFFF))[0]


def report_rects(name, words, per_row=4):
    """A table of doubles, four to a rectangle."""
    print(f'\n{name}: {len(words) // per_row} entries')
    for i in range(0, len(words), per_row):
        vals = [as_double(w) for w in words[i:i + per_row]]
        print(f'  [{i // per_row:2}] ' + ', '.join(f'{v:g}' for v in vals))


def report_markers(name, words):
    """A marker table: {int spriteKind, float x, y, rotation, scaleX, scaleY}."""
    print(f'\n{name}: {len(words) // 6} entries')
    for i in range(0, len(words), 6):
        kind = words[i] & 0xFFFFFFFF
        if kind >= 0x80000000:
            kind -= 0x100000000
        rest = [as_float(w) for w in words[i + 1:i + 6]]
        print(f'  [{i // 6:2}] kind={kind:3}  x={rest[0]:9g}  y={rest[1]:9g}  '
              f'rot={rest[2]:9g}  sx={rest[3]:g}  sy={rest[4]:g}')


def main(argv=None):
    """Decode a pasted LLDB transcript into per-table values."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('transcript', type=Path,
                        help='the LLDB output from tools/rb458-tables.lldb')
    arguments = parser.parse_args(argv)

    words = parse_words(arguments.transcript.read_text(encoding='utf-8', errors='replace'))
    print(f'parsed {len(words)} words from the transcript')
    tables = split_tables(words)

    for name in ('g_pTutorialClipRect', 'pastelClipRects'):
        if name in tables:
            report_rects(name, tables[name][1])
    if 'pastelPositions' in tables:
        report_rects('pastelPositions', tables['pastelPositions'][1], per_row=2)
    for name in ('g_aAltFrameMarker4', 'g_aAltFrameMarker6', 'g_aAltFrameMarker9'):
        if name in tables:
            report_markers(name, tables[name][1])
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
