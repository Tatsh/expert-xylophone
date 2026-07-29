#!/usr/bin/env python3
"""Transcribe binary-resident float tables into C++ initialiser rows.

Reads a span of the program image through the Ghidra HTTP bridge and prints each float as the
shortest decimal literal that round-trips through ``struct.pack('<f')``, forced into plain notation
so that a value such as 1000.0 never comes out as ``1e+03``. Every value is verified: a float whose
shortest form does not repack to the original four bytes is reported rather than emitted.

Usage::

    tools/rom_float_dump.py 0x30a510 64 --cols 8
    tools/rom_float_dump.py 0x30a7c8 80 --rows 8   # ten rows of eight floats
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
import urllib.parse
import urllib.request
from decimal import Decimal

BRIDGE = 'http://127.0.0.1:8089'
PROGRAM = 'rb458'
IMAGE_BASE = 0x100000000
CHUNK = 2048


def read_memory(address: int, length: int) -> bytes:
    """Read ``length`` bytes at the image-relative ``address`` through the bridge."""
    out = bytearray()
    while len(out) < length:
        want = min(CHUNK, length - len(out))
        query = urllib.parse.urlencode({
            'program': PROGRAM,
            'address': hex(IMAGE_BASE + address + len(out)),
            'length': want,
        })
        with urllib.request.urlopen(f'{BRIDGE}/read_memory?{query}', timeout=60) as response:
            payload = json.loads(response.read().decode())
        out += bytes.fromhex(payload['hex'])
    return bytes(out[:length])


def shortest_float(raw: bytes) -> str:
    """Return the shortest plain-notation decimal literal that repacks to ``raw`` exactly."""
    value = struct.unpack('<f', raw)[0]
    for precision in range(1, 18):
        text = f'{value:.{precision}g}'
        if struct.pack('<f', float(text)) == raw:
            plain = format(Decimal(text), 'f')
            return plain if '.' in plain else f'{plain}.0'
    raise ValueError(f'no round-tripping literal for {raw.hex()}')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('address', help='image-relative start address, e.g. 0x30a510')
    parser.add_argument('count', type=int, help='number of floats to read')
    parser.add_argument('--cols', type=int, default=6, help='floats per emitted row')
    parser.add_argument('--rows', type=int, default=0, help='emit braced rows of this many floats')
    args = parser.parse_args()

    address = int(args.address, 0)
    data = read_memory(address, args.count * 4)
    literals = [f'{shortest_float(data[i * 4:i * 4 + 4])}f' for i in range(args.count)]

    if args.rows:
        if args.count % args.rows:
            print(f'count {args.count} is not a multiple of --rows {args.rows}', file=sys.stderr)
            return 1
        for start in range(0, args.count, args.rows):
            print('    {' + ', '.join(literals[start:start + args.rows]) + '},')
    else:
        for start in range(0, args.count, args.cols):
            print('    ' + ', '.join(literals[start:start + args.cols]) + ',')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
