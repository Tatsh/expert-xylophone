#!/usr/bin/env python3
"""Verify property accessors against the binary's instructions, and record which ones hold.

A synthesised accessor names the ivar it touches indirectly, through the
``_OBJC_IVAR_$_Class._name`` offset variable rather than an immediate. That indirection is what
makes these mechanically checkable, and the check compares two independent sources: the ivar the
instructions actually reach, resolved through that offset variable into the class's ivar list,
against the backing ivar the class's property list declares for the same selector. An accessor
wired to the wrong ivar fails, because those two disagree.

The body is also required to touch nothing else. Only the ARC and property runtime helpers are
allowed to appear, so a hand-written method that merely happens to begin with an ivar load is not
mistaken for a synthesised accessor.

This is disassembly, not decompiler output: the instruction words are decoded here, from the bytes.

Anything whose shape is not recognised is reported unverified rather than assumed correct, so the
count this prints is a floor.

Usage: ``tools/objc_verify_accessors.py <binary>``, where the binary is the one **inside the .ipa**.
"""
import argparse
import re
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from objc_update import IMAGE_BASE, Metadata, _LC_SEGMENT_64  # noqa: E402

OUTPUT = 'tools/objc_verified.txt'
_RET = 0xD65F03C0
# How far past a prologue to look for the ivar-offset load before giving up.
_SCAN = 14
# The runtime entry points a synthesised accessor is allowed to call. Anything else means the body
# does more than move one ivar, so it is not treated as a synthesised accessor.
_ALLOWED_HELPERS = (
    'objc_retain',
    'objc_release',
    'objc_storeStrong',
    'objc_getProperty',
    'objc_setProperty',
    'objc_setProperty_atomic',
    'objc_setProperty_nonatomic',
    'objc_setProperty_atomic_copy',
    'objc_setProperty_nonatomic_copy',
    'objc_copyStruct',
    'objc_autoreleaseReturnValue',
    'objc_retainAutoreleaseReturnValue',
    'objc_retainAutoreleasedReturnValue',
    'objc_loadWeakRetained',
    'objc_storeWeak',
    'objc_destroyWeak',
    'objc_initWeak',
)


def _adrp(word: int, address: int) -> int | None:
    """Decode an ADRP, returning the page it targets."""
    if (word & 0x9F000000) != 0x90000000:
        return None
    immlo = (word >> 29) & 0x3
    immhi = (word >> 5) & 0x7FFFF
    return (address & ~0xFFF) + (((immhi << 2) | immlo) << 12)


def _ldrsw_imm(word: int) -> tuple[int, int, int] | None:
    """Decode an LDRSW with an unsigned immediate, returning its offset, base, and destination."""
    if (word & 0xFFC00000) != 0xB9800000:
        return None
    return (((word >> 10) & 0xFFF) * 4, (word >> 5) & 0x1F, word & 0x1F)


def _is_branch_with_link(word: int) -> bool:
    return (word & 0xFC000000) == 0x94000000


def _is_conditional_branch(word: int) -> bool:
    """Say whether a word is a conditional branch: `b.cond`, `cbz`/`cbnz`, or `tbz`/`tbnz`."""
    if (word & 0xFF000010) == 0x54000000:
        return True
    if (word & 0x7E000000) == 0x34000000:
        return True
    return (word & 0x7E000000) == 0x36000000


def _branch_target(word: int, address: int) -> int:
    imm = word & 0x03FFFFFF
    if imm & 0x02000000:
        imm -= 0x04000000
    return address + imm * 4


class AccessorCheck:
    """Compares each accessor's instructions with the ivar its property declares."""

    def __init__(self, metadata: Metadata) -> None:
        self._metadata = metadata
        self._ivars = self._read_ivars()
        self._declared = self._read_property_backings()
        self._stubs = self._read_stub_names()

    def _read_ivars(self) -> dict[int, tuple[str, str]]:
        """Map each ivar offset variable's address to its class and ivar name."""
        data = self._metadata._data
        out: dict[int, tuple[str, str]] = {}
        for ro_offset, class_name in self._class_ro_offsets():
            ivars, = struct.unpack_from('<Q', data, ro_offset + 48)
            ivars_offset = self._metadata.offset_of(ivars) if ivars else None
            if ivars_offset is None:
                continue
            entry_size, count = struct.unpack_from('<II', data, ivars_offset)
            for slot in range(count):
                entry = ivars_offset + 8 + slot * entry_size
                offset_var, ivar_name, _ = struct.unpack_from('<QQQ', data, entry)
                out[offset_var] = (class_name, self._metadata.string_at(ivar_name))
        return out

    def _read_property_backings(self) -> dict[tuple[str, str], str]:
        """Map each class and accessor selector to the backing ivar its property declares."""
        data = self._metadata._data
        out: dict[tuple[str, str], str] = {}
        for ro_offset, class_name in self._class_ro_offsets():
            properties, = struct.unpack_from('<Q', data, ro_offset + 64)
            offset = self._metadata.offset_of(properties) if properties else None
            if offset is None:
                continue
            entry_size, count = struct.unpack_from('<II', data, offset)
            for slot in range(count):
                entry = offset + 8 + slot * entry_size
                name = self._metadata.string_at(struct.unpack_from('<Q', data, entry)[0])
                attributes = self._metadata.string_at(
                    struct.unpack_from('<Q', data, entry + 8)[0])
                backing = re.search(r'(?:^|,)V(.*)$', attributes)
                if not backing:
                    continue
                getter = re.search(r'(?:^|,)G([^,]+)', attributes)
                setter = re.search(r'(?:^|,)S([^,]+)', attributes)
                out[(class_name, getter.group(1) if getter else name)] = backing.group(1)
                if 'R' not in attributes.split(','):
                    key = setter.group(1) if setter else f'set{name[:1].upper()}{name[1:]}:'
                    out[(class_name, key)] = backing.group(1)
        return out

    def _class_ro_offsets(self):
        """Yield each class's ``class_ro`` file offset and name, for both halves of the pair."""
        data = self._metadata._data
        classlist = self._metadata.section('__objc_classlist')
        if classlist is None:
            return
        for index in range(classlist.size // 8):
            address, = struct.unpack_from('<Q', data, classlist.offset + index * 8)
            offset = self._metadata.offset_of(address)
            if offset is None:
                continue
            ro, = struct.unpack_from('<Q', data, offset + 32)
            ro_offset = self._metadata.offset_of(ro)
            if ro_offset is None:
                continue
            name = self._metadata.string_at(struct.unpack_from('<Q', data, ro_offset + 24)[0])
            yield ro_offset, name

    def _read_stub_names(self) -> dict[int, str]:
        """Map each stub address in ``__stubs`` to the symbol it forwards to."""
        out: dict[int, str] = {}
        data = self._metadata._data
        stubs = self._metadata.section('__stubs')
        indirect = self._metadata.section('__la_symbol_ptr') or self._metadata.section('__got')
        if stubs is None or indirect is None:
            return out
        symbols = self._symbol_names()
        # Each stub is 12 bytes: adrp, ldr, br. The ldr's target names the slot it jumps through.
        for offset in range(0, stubs.size, 12):
            address = stubs.address + offset
            file_offset = self._metadata.offset_of(address)
            if file_offset is None:
                continue
            first, second = struct.unpack_from('<II', data, file_offset)
            page = _adrp(first, address)
            if page is None:
                continue
            slot = page + ((second >> 10) & 0xFFF) * 8
            if slot in symbols:
                out[address] = symbols[slot]
        return out

    def _symbol_names(self) -> dict[int, str]:
        """Map each lazy or non-lazy pointer slot to its symbol name, via the indirect table."""
        data = self._metadata._data
        out: dict[int, str] = {}
        n_commands, = struct.unpack_from('<I', data, 16)
        offset = 32
        symtab = dysymtab = None
        pointer_sections: list[tuple[int, int, int]] = []
        for _ in range(n_commands):
            command, size = struct.unpack_from('<II', data, offset)
            if command == 0x2:
                symtab = struct.unpack_from('<IIII', data, offset + 8)
            elif command == 0xB:
                dysymtab = struct.unpack_from('<' + 'I' * 18, data, offset + 8)
            elif command == _LC_SEGMENT_64:
                n_sections, = struct.unpack_from('<I', data, offset + 64)
                cursor = offset + 72
                for _ in range(n_sections):
                    name = data[cursor:cursor + 16].rstrip(b'\0').decode()
                    if name in ('__la_symbol_ptr', '__got'):
                        address, section_size = struct.unpack_from('<QQ', data, cursor + 32)
                        # reserved1 is the section's first index into the indirect symbol table.
                        reserved1, = struct.unpack_from('<I', data, cursor + 68)
                        pointer_sections.append((address, section_size, reserved1))
                    cursor += 80
            offset += size
        if symtab is None or dysymtab is None:
            return out
        sym_offset, n_syms, str_offset, _ = symtab
        # indirectsymoff and nindirectsyms are the thirteenth and fourteenth fields after the
        # command header; the two after them are extreloff and nextrel, easy to take by mistake.
        indirect_offset, n_indirect = dysymtab[12], dysymtab[13]
        for address, section_size, reserved1 in pointer_sections:
            for slot in range(section_size // 8):
                index = reserved1 + slot
                if index >= n_indirect:
                    break
                symbol_index, = struct.unpack_from('<I', data, indirect_offset + index * 4)
                if symbol_index >= n_syms:
                    continue
                name_offset, = struct.unpack_from('<I', data, sym_offset + symbol_index * 16)
                name_start = str_offset + name_offset
                end = data.index(b'\0', name_start)
                out[address + slot * 8] = data[name_start:end].decode('utf-8', 'replace')
        return out

    def _words(self, address: int, count: int) -> list[int]:
        offset = self._metadata.offset_of(address)
        if offset is None:
            return []
        return [struct.unpack_from('<I', self._metadata._data, offset + i * 4)[0]
                for i in range(count)]

    def check(self, class_name: str, selector: str, address: int) -> tuple[bool, str]:
        """
        Decide whether one accessor moves exactly the ivar its property declares.

        Returns
        -------
        tuple[bool, str]
            Whether it verified, and the ivar it agrees on or the reason it did not.
        """
        declared = self._declared.get((class_name, selector))
        if declared is None:
            return False, 'the property list declares no backing ivar for this selector'
        words = self._words(address, _SCAN)
        if not words:
            return False, 'unreadable'
        # Stop at the first instruction that ends the body. These are only a few instructions long,
        # so a fixed window would run into the next method and appear to touch a second ivar. A
        # return is one ending; an unconditional branch is the other, and it is the easier one to
        # miss, because a body that ends by tail-calling a runtime helper contains no return at all
        # and so is never truncated by looking for one.
        for index, word in enumerate(words):
            if word == _RET or (word & 0xFC000000) == 0x14000000:
                words = words[:index + 1]
                break
        touched: set[str] = set()
        for index, word in enumerate(words):
            page = _adrp(word, address + index * 4)
            if page is None:
                continue
            following = _ldrsw_imm(words[index + 1]) if index + 1 < len(words) else None
            if following is None:
                continue
            ivar = self._ivars.get(page + following[0])
            if ivar is not None:
                touched.add(ivar[1])
        if not touched:
            return False, 'no ivar-offset load found in the body'
        if len(touched) > 1:
            return False, f'touches more than one ivar: {sorted(touched)}'
        name = touched.pop()
        if name != declared:
            return False, f'moves {name} where the property declares {declared}'
        # Every call must be a runtime helper; anything else means the body does more than this.
        for index, word in enumerate(words):
            if word == _RET:
                break
            if not _is_branch_with_link(word):
                continue
            target = _branch_target(word, address + index * 4)
            symbol = self._stubs.get(target, '')
            if symbol.lstrip('_') not in _ALLOWED_HELPERS:
                return False, f'calls {symbol or hex(target - IMAGE_BASE)}, not a runtime helper'
        # A conditional branch means the instructions after the first return are reachable, so the
        # window read above is not the whole body and nothing here can speak for the rest of it.
        # These are real: the shape it admits is the setter that compares before storing and then
        # redraws, which does more than move its ivar and must not pass as though it did not.
        for word in words:
            if word == _RET:
                break
            if _is_conditional_branch(word):
                return False, 'branches before returning, so this window is not the whole body'
        # An unconditional branch is a tail call rather than a jump within the body, and it has to
        # be held to the same standard as a call: a body that ends by branching to objc_msgSend
        # performs a send, whatever its prefix looks like.
        for index, word in enumerate(words):
            if word == _RET:
                break
            if (word & 0xFC000000) != 0x14000000:
                continue
            target = _branch_target(word, address + index * 4)
            symbol = self._stubs.get(target, '')
            if symbol.lstrip('_') not in _ALLOWED_HELPERS:
                return False, (f'tail-calls {symbol or hex(target - IMAGE_BASE)}, '
                               'not a runtime helper')
        return True, f'{class_name}.{name}'


def main(argv=None) -> int:
    """Verify every property accessor, and record the ones that hold."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the shipped Mach-O from inside the .ipa')
    args = parser.parse_args(argv)
    if not args.binary.is_file():
        print(f'error: no such binary: {args.binary}', file=sys.stderr)
        return 1
    metadata = Metadata(args.binary)
    check = AccessorCheck(metadata)
    passed: list[tuple[int, str]] = []
    failed: list[tuple[str, str]] = []
    for method in metadata.methods():
        if not method.accessor:
            continue
        ok, why = check.check(method.class_name, method.selector, method.address)
        if ok:
            passed.append((method.address - IMAGE_BASE, why))
        else:
            failed.append((f'{method.class_name} {method.selector}', why))
    header = ['# Property accessors verified against their instructions by',
              '# tools/objc_verify_accessors.py. Each moves exactly the ivar its property list',
              '# declares as the backing store, reached through the _OBJC_IVAR_$_ offset variable,',
              '# and calls nothing but the ARC and property runtime helpers.']
    body = [f'{address:#x} {why}' for address, why in sorted(passed)]
    Path(OUTPUT).write_text('\n'.join(header + body) + '\n')
    print(f'accessors verified: {len(passed)}, unverified: {len(failed)}')
    print(f'wrote {OUTPUT}')
    for why, count in Counter(w for _, w in failed).most_common(10):
        print(f'  unverified: {why} ({count})')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
