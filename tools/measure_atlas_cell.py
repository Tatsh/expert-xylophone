#!/usr/bin/env python3
"""
Report where a sprite's artwork actually sits inside its atlas cell.

The target's green gradient looks displaced against its border, and the runtime log rules the
geometry out: at every corner the border and the green are emitted at the same position, the same
rotation and the same scale, and they share an anchor of 32 by 32 and a size of 64 by 64, so their
two quads are identical. The only difference between them is the atlas cell each samples.

That leaves one question this answers: is the green blob centred inside its cell? If it is not, the
sprite draws exactly where it should and the artwork inside it is off, which is why the bottom row
looks wrong and the top does not -- the bottom is rotated a half turn, so the same offset flips to
the opposite side.

Usage:

    tools/measure_atlas_cell.py gm_parts1.png

The default cells are the border and the green, taken from the reconstruction's own UVs scaled by
the 1024-pixel atlas: 0.00195 and 0.10156 across, 0.31055 down, 0.09766 square. Pass --cell to
measure a different rectangle.
"""

import argparse
import struct
import zlib
from pathlib import Path

# (name, x, y, w, h) in pixels, from kGaugeParts' UV fields times 1024.
DEFAULT_CELLS = (
    ('border', 2, 318, 100, 100),
    ('green', 104, 318, 100, 100),
)


def read_png(path):
    """Decode a PNG to (width, height, rows of RGBA bytes) using only the standard library.

    Pillow is not always installed, and this needs one 8-bit RGBA image rather than an imaging
    stack, so the few lines of inflate-and-unfilter are cheaper than the dependency.
    """
    raw = path.read_bytes()
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG')
    width = height = depth = colour = None
    data = bytearray()
    at = 8
    while at < len(raw):
        length = struct.unpack_from('>I', raw, at)[0]
        kind = raw[at + 4:at + 8]
        body = raw[at + 8:at + 8 + length]
        if kind == b'IHDR':
            width, height, depth, colour = struct.unpack('>IIBB', body[:10])
        elif kind == b'IDAT':
            data += body
        elif kind == b'IEND':
            break
        at += 12 + length
    if depth != 8 or colour not in (2, 6):
        raise ValueError(f'need an 8-bit RGB or RGBA PNG, got depth {depth} colour type {colour}')

    channels = 4 if colour == 6 else 3
    stride = width * channels
    flat = zlib.decompress(bytes(data))
    rows = []
    previous = bytearray(stride)
    at = 0
    for _ in range(height):
        filter_kind = flat[at]
        line = bytearray(flat[at + 1:at + 1 + stride])
        at += 1 + stride
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up = previous[i]
            upper_left = previous[i - channels] if i >= channels else 0
            if filter_kind == 1:
                line[i] = (line[i] + left) & 0xFF
            elif filter_kind == 2:
                line[i] = (line[i] + up) & 0xFF
            elif filter_kind == 3:
                line[i] = (line[i] + ((left + up) >> 1)) & 0xFF
            elif filter_kind == 4:
                estimate = left + up - upper_left
                da, db, dc = (abs(estimate - left), abs(estimate - up), abs(estimate - upper_left))
                nearest = left if (da <= db and da <= dc) else (up if db <= dc else upper_left)
                line[i] = (line[i] + nearest) & 0xFF
        rows.append(line)
        previous = line
    return width, height, rows, channels


def centroid(rows, channels, x, y, w, h):
    """The alpha-weighted centre of a cell, relative to the cell's own origin."""
    total = 0.0
    sum_x = 0.0
    sum_y = 0.0
    for row in range(y, min(y + h, len(rows))):
        line = rows[row]
        for column in range(x, x + w):
            base = column * channels
            if base + channels > len(line):
                continue
            if channels == 4:
                weight = line[base + 3]
            else:
                weight = 255 if (line[base] or line[base + 1] or line[base + 2]) else 0
            if not weight:
                continue
            total += weight
            sum_x += weight * (column - x)
            sum_y += weight * (row - y)
    if total == 0.0:
        return None
    return sum_x / total, sum_y / total


def main(argv=None):
    """Measure each cell and print its offset from centre."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('atlas', type=Path, help='the gm_parts1 PNG')
    parser.add_argument('--cell', nargs=5, metavar=('NAME', 'X', 'Y', 'W', 'H'), action='append',
                        help='measure this cell instead of the defaults')
    arguments = parser.parse_args(argv)

    width, height, rows, channels = read_png(arguments.atlas)
    print(f'{arguments.atlas} is {width}x{height}, {channels} channels')

    cells = DEFAULT_CELLS
    if arguments.cell:
        cells = tuple((c[0], int(c[1]), int(c[2]), int(c[3]), int(c[4])) for c in arguments.cell)

    for name, x, y, w, h in cells:
        found = centroid(rows, channels, x, y, w, h)
        if found is None:
            print(f'  {name:8} cell ({x},{y}) {w}x{h}: empty')
            continue
        cx, cy = found
        print(f'  {name:8} cell ({x},{y}) {w}x{h}: content centre ({cx:.1f},{cy:.1f}), '
              f'cell centre ({w / 2:.1f},{h / 2:.1f}), '
              f'offset ({cx - w / 2:+.1f},{cy - h / 2:+.1f})')

    print()
    print('An offset near zero means the artwork is centred and the displacement is elsewhere.')
    print('A non-zero offset on the green but not the border is the whole defect, and the fix is')
    print("the cell's UV origin rather than any of the geometry.")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
