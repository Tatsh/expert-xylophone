#!/usr/bin/env python3
"""Check every method's declared return type against the binary's own type encoding.

The Objective-C runtime records each method's exact type string, so the correct integer width is
data rather than judgement: `S` is unsigned short, `I` unsigned int, `q` NSInteger, and so on. This
compares that encoding against the return type declared in the tree.

Reuses ``objc_update``'s Mach-O parsing, so every ``method_t`` comes from a real ``class_ro_t``
``baseMethods`` list. That matters. A first attempt found method lists by scanning the image for any
8-byte-aligned pointer to a printable string; it reported 197 mismatches and every one was false,
because a 2.5 MB image contains many coincidental byte runs of that shape. OBJC_AUDIT.md records
the two checks that exposed it.

Regression-tested against the commit before the ``AVBus`` fix, where it reports ``-setSource:`` and
``-currentID`` as ``unsigned int`` against an ``S`` encoding. Exits non-zero on any mismatch.
"""
import importlib.util
import pathlib
import re
import struct
import sys
from collections import defaultdict

REPO = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('ou', REPO / 'tools' / 'objc_update.py')
ou = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ou)

ALLOWED = {
    'c': {'char', 'signed char', 'BOOL'},
    'C': {'unsigned char'},
    's': {'short', 'short int'},
    'S': {'unsigned short', 'unsigned short int'},
    'i': {'int', 'signed int'},
    'I': {'unsigned int', 'unsigned'},
    'q': {'NSInteger', 'long long'},
    'Q': {'NSUInteger', 'unsigned long long'},
    'B': {'BOOL', 'bool'},
}


def types_of(meta, method_list):
    """Selector -> types string for one method list, mirroring Metadata._method_list."""
    offset = meta.offset_of(method_list) if method_list else None
    if offset is None:
        return {}
    entry_size, count = struct.unpack_from('<II', meta._data, offset)
    out = {}
    for index in range(count):
        entry = offset + 8 + index * entry_size
        if entry_size == 12:
            name_off, types_off, _ = struct.unpack_from('<iii', meta._data, entry)
            entry_address = method_list + 8 + index * entry_size
            sel = meta.string_at(meta._word(entry_address + name_off))
            types = meta.string_at(meta._word(entry_address + 4 + types_off))
        else:
            name, types_ptr, _ = struct.unpack_from('<QQQ', meta._data, entry)
            sel = meta.string_at(name)
            types = meta.string_at(types_ptr)
        if sel and types:
            out[sel] = types
    return out


def all_types(meta):
    """Selector -> types string, taken only from real class and category method lists."""
    found = {}
    classlist = meta.section('__objc_classlist')
    if classlist:
        for i in range(classlist.size // 8):
            addr, = struct.unpack_from('<Q', meta._data, classlist.offset + i * 8)
            off = meta.offset_of(addr)
            if off is None:
                continue
            isa, _, _, _, data = struct.unpack_from('<QQQQQ', meta._data, off)
            for ro in (data, meta._metaclass_ro(isa)):
                ro_off = meta.offset_of(ro) if ro else None
                if ro_off is None:
                    continue
                ml, = struct.unpack_from('<Q', meta._data, ro_off + 32)
                found.update(types_of(meta, ml))
    return found


def declared():
    out = defaultdict(set)
    files = []
    for root in ('Project', '3rdparty'):
        for ext in ('*.m', '*.mm', '*.h'):
            files.extend((REPO / root).rglob(ext))
    decl = re.compile(r'^[-+]\s*\(([^)]+)\)\s*(.+?)(?:\{|;)', re.M | re.S)
    for path in files:
        try:
            text = path.read_text()
        except Exception:
            continue
        for m in decl.finditer(text):
            ret = ' '.join(m.group(1).split())
            parts = re.findall(r'(\w+)\s*:', re.sub(r'\([^()]*\)', ' ', m.group(2)))
            sel = ''.join(p + ':' for p in parts) if parts else m.group(2).strip().split()[0]
            out[sel].add((ret, str(path.relative_to(REPO))))
    return out


meta = ou.Metadata(pathlib.Path(sys.argv[1]))
types = all_types(meta)
print(f'{len(types)} selectors with a types string from real method lists')
dec = declared()
problems = []
for sel, encoding in types.items():
    code = encoding[0]
    if code not in ALLOWED:
        continue
    for ret, path in dec.get(sel, ()):
        base = ret.replace('const', '').replace('*', '').strip()
        if base in ALLOWED[code] or not any(base in v for v in ALLOWED.values()):
            continue
        problems.append(f'{path}: {sel} declared {base!r} but encodes {code!r} ({encoding})')
for p in sorted(set(problems)):
    print(p)
print(f'--- {len(set(problems))} mismatch(es)')
sys.exit(1 if problems else 0)
