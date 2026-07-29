"""Resolve a runtime layout-table initialiser's decompile into reconstructed C++ field writes.

The three ``Initialize*LayoutTable*`` routines (0x11c9b8, 0x12af9c, 0x7b3b4) are ~90% flat data:
thousands of scalar stores into zero-initialised ``__common`` tables, with no meaningful control
flow. Hand-transcribing them is impractical and error-prone, so this walks the Ghidra decompile in
program order, resolves every right-hand side to concrete words, and maps every destination address
onto a modelled table field.

Right-hand sides it understands, which between them cover every store in 0x11c9b8:

* integer and float-bit-pattern literals;
* ``(undefined8)``/``(undefined4)`` reads of a rodata constant, and the ``>> 0x20`` high half;
* ``NEON_ext(X, X, 8, 1)`` halves. That intrinsic rotates the 16-byte constant left by eight, so
  ``auVarN._0_8_`` is simply the *upper* half of the constant at X -- there is no arithmetic here,
  only a half-swap, and the piecewise ``auVarN._0_8_ =`` / ``._8_8_ =`` builds are handled too;
* copies from a slot the routine has already filled (the mirrored-slot duplication), which are
  emitted as a field-to-field assignment rather than a baked literal so the intent survives.

Floats are emitted through a round-trip check: the shortest ``%g`` form that packs back to the exact
original bit pattern, so no precision is invented.

Inputs (in ``--scratch``): ``rodata.json``, a ``{hex_base: hex_bytes}`` dump of the constant span the
routine reads, and the decompile text. Anything unresolved is reported rather than guessed -- an
empty report is the signal that the emitted body is complete.

Usage:
    python3 tools/layout_table_gen.py --scratch DIR --decompile dec.txt --out body.txt
"""
import argparse
import json
import re
import struct

_ap = argparse.ArgumentParser(description=__doc__)
_ap.add_argument("--scratch", required=True, help="directory holding rodata.json and the decompile")
_ap.add_argument("--decompile", default="dec_11c9b8.txt", help="decompile filename within --scratch")
_ap.add_argument("--out", default="layout_body.txt", help="output filename within --scratch")
_args = _ap.parse_args()
SCRATCH = _args.scratch

rod = {}
for base, hx in json.load(open(SCRATCH + "/rodata.json")).items():
    a0 = int(base, 16)
    for i, byte in enumerate(bytes.fromhex(hx)):
        rod[a0 + i] = byte


def read_rodata(addr, n):
    try:
        return bytes(rod[addr + i] for i in range(n))
    except KeyError:
        return None


PARTS = ["nEnabled", "flX", "flY", "flWidth", "flHeight", "nUvPaletteIndex"]
ANCHOR = ["flX", "flY", "nAnchorMode"]
LAYOUT = ["flX", "flY", "flWidth", "flHeight", "nAnchorMode"]
RECT = ["flX", "flY", "flWidth", "flHeight"]
PAIR = ["flX", "flY"]
INT_FIELDS = {"nEnabled", "nUvPaletteIndex", "nAnchorMode"}

TABLES = [
    (0x1003D6650, "g_aClassicPartsPad", 0x18, 240, PARTS),
    (0x1003D7CD0, "g_aClassicPartsAnchorPad", 0x08, 131, PAIR),
    (0x1003D80E8, "g_aClassicPositionPhonePortrait", 0x0C, 82, ANCHOR),
    (0x1003D84C0, "g_aClassicPositionPhoneLandscape", 0x0C, 82, ANCHOR),
    (0x1003D88A0, "g_aClassicSeparatorPhonePortrait", 0x14, 46, LAYOUT),
    (0x1003D8C40, "g_aClassicSeparatorPhoneLandscape", 0x14, 46, LAYOUT),
    (0x1003D8FD8, "g_aClassicPositionPhoneState", 0x14, 4, LAYOUT),
    (0x1003D9030, "g_aClassicPositionPhoneStatePortrait", 0x14, 4, LAYOUT),
    (0x1003D9080, "g_aClassicPositionPhoneStateLandscape", 0x14, 4, LAYOUT),
    (0x1003D90D0, "g_ClassicCenterPositionPhoneState", 0x10, 1, RECT),
    (0x1003D90E0, "g_ClassicCenterPositionPhonePortrait", 0x10, 1, RECT),
    (0x1003D90F0, "g_ClassicCenterPositionPhoneLandscape", 0x10, 1, RECT),
]


def dest(addr):
    for base, name, stride, count, fields in TABLES:
        if base <= addr < base + stride * count:
            idx, field_off = divmod(addr - base, stride)
            if field_off % 4 or field_off // 4 >= len(fields):
                return None
            f = fields[field_off // 4]
            return (f"{name}.{f}" if count == 1 else f"{name}[{idx}].{f}"), f
    return None


def fmt_float(bits):
    v = struct.unpack("<f", struct.pack("<I", bits))[0]
    if v != v or v in (float("inf"), float("-inf")):
        return None
    for p in range(1, 10):
        s = "%.*g" % (p, v)
        if struct.pack("<f", float(s)) == struct.pack("<I", bits):
            return s + ("f" if ("." in s or "e" in s) else ".0f")
    return None


text = open(SCRATCH + "/" + _args.decompile).read()
neon = {}
mem = {}
stmts = []
bad = []

PIECE = re.compile(r"^\s*(auVar\d+)\._(0|8)_8_\s*=\s*(.+?);\s*$")
STMT = re.compile(r"^\s*(?:(auVar\d+)\s*=\s*(.+?)"
                  r"|(_?(?:DAT|UNK)_1003d[0-9a-f]{4})\s*=\s*(.+?));\s*$")
SYMBOL = r"_?(?:DAT|UNK)_(100[0-9a-f]{6})"


def emit(addr, words, source_exprs=None):
    for i, w in enumerate(words):
        a = addr + 4 * i
        mem[a] = w
        d = dest(a)
        if d is None:
            bad.append(("dest", hex(a)))
            continue
        expr, fname = d
        if source_exprs and source_exprs[i] is not None:
            stmts.append((expr, source_exprs[i]))
            continue
        if fname in INT_FIELDS:
            stmts.append((expr, str(struct.unpack("<i", struct.pack("<I", w))[0])))
        else:
            f = fmt_float(w)
            if f is None:
                bad.append(("float", hex(a)))
                continue
            stmts.append((expr, f))


for line in text.splitlines():
    pm = PIECE.match(line)
    if pm:
        pv = re.fullmatch(SYMBOL, pm.group(3).strip())
        b = read_rodata(int(pv.group(1), 16), 8) if pv else None
        if b is None:
            bad.append(("piece", line.strip()))
            continue
        cur = bytearray(neon.get(pm.group(1), b"\x00" * 16))
        off = int(pm.group(2))
        cur[off:off + 8] = b
        neon[pm.group(1)] = bytes(cur)
        continue
    m = STMT.match(line)
    if not m:
        continue
    if m.group(1):
        rhs = m.group(2).strip()
        mm = re.fullmatch(r"NEON_ext\((.+?),(.+?),8,1\)", rhs)
        if not mm:
            bad.append(("neon", line.strip()))
            continue

        def value16(tok):
            tok = tok.strip()
            if tok.startswith("auVar"):
                return neon.get(tok)
            am = re.fullmatch(SYMBOL, tok)
            return read_rodata(int(am.group(1), 16), 16) if am else None

        va, vb = value16(mm.group(1)), value16(mm.group(2))
        if va is None or vb is None:
            bad.append(("neon-source", line.strip()))
            continue
        neon[m.group(1)] = va[8:] + vb[:8]
        continue

    addr = int(re.sub(r"^_?(?:DAT|UNK)_", "", m.group(3)), 16)
    rhs = m.group(4).strip()

    if re.fullmatch(r"0x[0-9a-f]+|-?\d+", rhs):
        emit(addr, [int(rhs, 0) & 0xFFFFFFFF])
        continue
    mm = re.fullmatch(r"\(undefined8\)" + SYMBOL, rhs)
    if mm:
        b = read_rodata(int(mm.group(1), 16), 8)
        emit(addr, list(struct.unpack("<II", b))) if b else bad.append(("u8", line))
        continue
    mm = re.fullmatch(r"\(undefined4\)" + SYMBOL, rhs)
    if mm:
        b = read_rodata(int(mm.group(1), 16), 4)
        emit(addr, list(struct.unpack("<I", b))) if b else bad.append(("u4", line))
        continue
    mm = re.fullmatch(r"\(undefined4\)\(\(ulong\)" + SYMBOL + r" >> 0x20\)", rhs)
    if mm:
        b = read_rodata(int(mm.group(1), 16) + 4, 4)
        emit(addr, list(struct.unpack("<I", b))) if b else bad.append(("u4h", line))
        continue
    mm = re.fullmatch(r"(auVar\d+)\._(\d+)_(\d+)_", rhs)
    if mm:
        v = neon.get(mm.group(1))
        off, sz = int(mm.group(2)), int(mm.group(3))
        if v is None:
            bad.append(("neon-use", line.strip()))
            continue
        emit(addr, list(struct.unpack("<" + "I" * (sz // 4), v[off:off + sz])))
        continue
    mm = re.fullmatch(r"_?(?:DAT|UNK)_(1003d[0-9a-f]{4})", rhs)
    if mm:                                    # a copy from an already-filled slot
        src = int(mm.group(1), 16)
        wide = rhs.startswith("_")
        n = 2 if wide else 1
        words, exprs = [], []
        for i in range(n):
            sa = src + 4 * i
            if sa not in mem:
                bad.append(("copy-source", line.strip()))
                words = None
                break
            words.append(mem[sa])
            sd = dest(sa)
            exprs.append(sd[0] if sd else None)
        if words:
            emit(addr, words, exprs)
        continue
    mm = re.fullmatch(r"\(float\)(\w+)", rhs)
    if mm:
        d = dest(addr)
        if d:
            stmts.append((d[0], f"static_cast<float>({mm.group(1)})"))
            mem[addr] = 0
        else:
            bad.append(("dest", hex(addr)))
        continue
    mm = re.fullmatch(SYMBOL, rhs)
    if mm:
        wide = rhs.startswith("_")
        b = read_rodata(int(mm.group(1), 16), 8 if wide else 4)
        if b is None:
            bad.append(("copy", line.strip()))
            continue
        emit(addr, list(struct.unpack("<II" if wide else "<I", b)))
        continue
    bad.append(("rhs", line.strip()))

print("statements:", len(stmts), " unresolved:", len(bad))
k = {}
for t, _ in bad:
    k[t] = k.get(t, 0) + 1
print("kinds:", k)
for t, l in bad[:10]:
    print("   ", t, "|", l)
with open(SCRATCH + "/" + _args.out, "w") as fh:
    for e, v in stmts:
        fh.write(f"    {e} = {v};\n")
print("wrote", _args.out)
