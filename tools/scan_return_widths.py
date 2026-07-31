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
BASE = 0x100000000
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
    'f': {'float'},
    'd': {'double', 'NSTimeInterval', 'CGFloat'},
}


def fields(encoding):
    """Split a types string into its encodings, honouring nested braces and brackets.

    The layout is return, then self, then the selector, then one entry per argument, each followed
    by its byte offset. Nesting matters: a struct argument such as
    ``^{AudioBufferList=I[1{AudioBuffer=II^v}]}`` contains braces of its own, and a naive split
    drops the arguments after it.
    """
    out, i, size = [], 0, len(encoding)
    while i < size:
        if encoding[i].isdigit():
            i += 1
            continue
        start = i
        while i < size and encoding[i] in '^rnNoORV':
            i += 1
        if i < size and encoding[i] in '{[(':
            depth = 0
            while i < size:
                if encoding[i] in '{[(':
                    depth += 1
                elif encoding[i] in '}])':
                    depth -= 1
                    if depth == 0:
                        i += 1
                        break
                i += 1
        elif i < size:
            i += 1
        out.append(encoding[start:i])
        while i < size and encoding[i].isdigit():
            i += 1
    return out


def types_of(meta, method_list):
    """Implementation address -> (selector, types) for one method list.

    Keyed by ``imp`` rather than by selector. Selectors are global in Objective-C and two classes
    may implement one with different signatures: ``-[RBMusicARView UpdateScore:]`` encodes
    ``v20@0:8f16`` while ``-[RBMusicScoreView UpdateScore:]`` encodes ``v20@0:8i16``. A
    selector-keyed map keeps whichever came last, which both invents mismatches and hides real
    ones.
    """
    offset = meta.offset_of(method_list) if method_list else None
    if offset is None:
        return {}
    entry_size, count = struct.unpack_from('<II', meta._data, offset)
    out = {}
    for index in range(count):
        entry = offset + 8 + index * entry_size
        entry_address = method_list + 8 + index * entry_size
        if entry_size == 12:
            name_off, types_off, imp_off = struct.unpack_from('<iii', meta._data, entry)
            sel = meta.string_at(meta._word(entry_address + name_off))
            types = meta.string_at(meta._word(entry_address + 4 + types_off))
            imp = entry_address + 8 + imp_off
        else:
            name, types_ptr, imp = struct.unpack_from('<QQQ', meta._data, entry)
            sel = meta.string_at(name)
            types = meta.string_at(types_ptr)
        if sel and types:
            out[imp - BASE] = (sel, types)
    return out


def all_types(meta):
    """Implementation address -> (selector, types), from real class and category method lists."""
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


def declared_by_address():
    """Implementation address -> (declared return type, path).

    The checklist already maps every method to its class and address, so it is used to attribute a
    declaration to an implementation rather than matching on the selector alone.
    """
    rows = {}
    for line in (REPO / 'OBJC_METHODS.md').read_text().splitlines():
        cells = [c.strip(' `') for c in line.split('|')]
        if len(cells) >= 8 and cells[7].startswith('0x'):
            rows[int(cells[7], 16)] = (cells[1], cells[2], cells[3])

    found = {}
    files = []
    for root in ('Project', '3rdparty'):
        for ext in ('*.m', '*.mm'):
            files.extend((REPO / root).rglob(ext))
    decl = re.compile(r'^([-+])\s*\(([^)]+)\)\s*(.+?)\{', re.M | re.S)
    by_key = {}
    for path in files:
        try:
            text = path.read_text()
        except Exception:
            continue
        for implementation in re.finditer(r'@implementation\s+(\w+)', text):
            cls = implementation.group(1)
            end = text.find('\n@end', implementation.end())
            region = text[implementation.end():end if end > 0 else len(text)]
            for match in decl.finditer(region):
                kind, ret, sig = match.group(1), ' '.join(match.group(2).split()), match.group(3)
                if ';' in sig or len(sig) > 600:
                    continue
                parts = re.findall(r'(\w+)\s*:', re.sub(r'\([^()]*\)', ' ', sig))
                selector = ''.join(p + ':' for p in parts) if parts else sig.strip().split()[0]
                typed = re.findall(r'\w+\s*:\s*\(([^()]*(?:\([^()]*\)[^()]*)*)\)\s*\w+', sig)
                params = tuple(' '.join(x.split()) for x in typed)
                by_key[(cls, kind, selector)] = (ret, params, str(path.relative_to(REPO)))

    for address, key in rows.items():
        if key in by_key:
            found[address] = by_key[key]
    return found


meta = ou.Metadata(pathlib.Path(sys.argv[1]))
types = all_types(meta)
print(f'{len(types)} implementations with a types string from real method lists')
declared = declared_by_address()
print(f'{len(declared)} of them matched to a declaration in the tree')
problems = []
for address, (selector, encoding) in types.items():
    code = encoding[0]
    if address not in declared:
        continue
    # Parameters first: a wrong parameter width mismatches the calling convention, where a widened
    # return usually does not.
    _ret, params, path = declared[address]
    encoded = fields(encoding)[3:]
    if len(encoded) == len(params):
        for got, want in zip(params, encoded):
            if want not in ALLOWED:
                continue
            spelled = got.replace('const', '').replace('*', '').strip()
            if spelled in ALLOWED[want] or not any(spelled in v for v in ALLOWED.values()):
                continue
            problems.append(f'{path}:{address:#x}: {selector} takes {spelled!r} but encodes '
                            f'{want!r} ({encoding})')
    if code not in ALLOWED:
        continue
    ret, _params, path = declared[address]
    base = ret.replace('const', '').replace('*', '').strip()
    if base in ALLOWED[code] or not any(base in v for v in ALLOWED.values()):
        continue
    problems.append(f'{path}:{address:#x}: {selector} returns {base!r} but encodes '
                    f'{code!r} ({encoding})')
for problem in sorted(set(problems)):
    print(problem)
print(f'--- {len(set(problems))} mismatch(es)')
sys.exit(1 if problems else 0)
