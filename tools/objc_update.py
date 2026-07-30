#!/usr/bin/env python3
"""Regenerate OBJC_METHODS.md: every Objective-C method in the binary, with its status.

The counterpart to :mod:`cxx_update` for the Objective-C side. Where that checklist is driven by
Ghidra's function list, this one is driven by the shipped binary's own runtime metadata, which names
every class, category, method and property the application defines. Nothing Apple ships appears
there: a framework's classes live in the framework, so the only Apple-derived entries are the
categories this application adds to Apple classes, which are the application's own code.

Two statuses are tracked per method and they mean different things.

``Reconstructed``
    The method has a reconstruction in the source tree, either an explicit definition inside the
    class's ``@implementation`` or a ``@property`` that synthesises it.

``Verified``
    The reconstruction has been read against the disassembly, per the five-step process in
    ``.claude/rules/reconstruction.md``. A method can be reconstructed and unverified; that is the
    normal state, and the point of the checklist is to make the gap visible.

Usage: ``tools/objc_update.py <binary>``, where the binary is the one **inside the .ipa** — the
unpacked copy under ``rb458orig`` is a different build and matches nothing.
"""
import argparse
import glob
import re
import struct
import sys
from pathlib import Path
from typing import NamedTuple

PATH = 'OBJC_METHODS.md'
IMAGE_BASE = 0x100000000
DONE = '✅'
NOT = '❌'
_LC_SEGMENT_64 = 0x19
_ZERO_FILL = ('__bss', '__common')
# Methods the compiler emits for a class with ARC-managed or C++-typed ivars. They have no
# reconstruction and never will, so they are counted and excluded rather than listed.
_COMPILER_GENERATED = ('.cxx_construct', '.cxx_destruct')

# Methods read against the disassembly, keyed by their address in the image-base-stripped form.
# A routine belongs here only once its body has actually been compared, not merely because it was
# read or because a constant in it was checked.
VERIFIED = {
    0x2202ec: 'ApplilinkStore -init: the queue is the private serial one from +allocWithZone:',
    0x2204c0: 'ApplilinkStore +allocWithZone:: creates the queue, then re-tests the singleton',
    0xa9108: 'RBMenuView -createMusicList: the csel at 0xa939c picks the artist comparator on 1',
    0x1a1b08: 'UIImage +imageNamedWithoutCache:: the two passes use mirrored iPad tags',
    0x1a2fa4: 'UIImage -clipImageWithRect:: all twelve items, including the d0-d3 mapping',
    0x1ea20: 'RBResourceDownloadViewController -updateLayout: three arms, aligned not centred',
    0x16d5c0: 'RBMusicGridLayout -init: both idiom arms, every constant decoded from the pool',
    0x16d7d8: 'RBMusicGridLayout -prepareLayout: ceiling division, slack, item frames',
    0x16de78: 'RBMusicGridLayout -collectionViewContentSize: tail-call to the ivar',
    0x16de84: 'RBMusicGridLayout per-item attributes: frameless, index passed through',
    0x16deb0: 'RBMusicGridLayout supplementary attributes: the same frameless shape',
    0x16df1c: 'RBMusicGridLayout -layoutAttributesForElementsInRect:: intersection order',
    0x16e0a0: 'RBMusicGridLayout -shouldInvalidateLayoutForBoundsChange:: returns 1',
    0x9dab4: 'RBMenuButton -setupView:: the bounds fcsel and both cap-inset calls',
    0x9d9fc: 'RBMenuButton -initWithType:: super init then setupView:',
    0x5df3c: 'ScoreData -getFrameBonusType: the three-way csel and the 2-collapses-to-1 return',
    0x5d3bc: 'ScoreData +hashScore:: send order, the 1000.0 scale at 0x2f8540, the 16-byte digest',
    # The seven -shouldAutorotateToInterfaceOrientation: bodies that are one unsigned range test,
    # `sub x8,x2,#1; cmp x8,#2; cset w0,cc`, accepting only the two portrait orientations.
    0x7df4: 'RBCampaignDetailViewController -shouldAutorotateToInterfaceOrientation:',
    0x19e00: 'RBResourceDownloadViewController -shouldAutorotateToInterfaceOrientation:',
    0x114854: 'RBTermView -shouldAutorotateToInterfaceOrientation:',
    0x194138: 'RBNotificationPageView -shouldAutorotateToInterfaceOrientation:',
    0x1a9300: 'RBStoreExtendNoteDetailViewController -shouldAutorotateToInterfaceOrientation:',
    0x1c9478: 'RBTermAgreeView -shouldAutorotateToInterfaceOrientation:',
    0x1dc3ec: 'RBStoreDetailViewController -shouldAutorotateToInterfaceOrientation:',
}


class Section(NamedTuple):
    """One Mach-O section."""

    name: str
    address: int
    size: int
    offset: int


class Method(NamedTuple):
    """One Objective-C method from the runtime metadata."""

    class_name: str
    kind: str
    selector: str
    address: int
    accessor: bool


class Metadata:
    """The shipped Mach-O's Objective-C metadata."""

    def __init__(self, path: Path) -> None:
        self._data = path.read_bytes()
        self._sections = list(self._read_sections())

    def _read_sections(self):
        n_commands, = struct.unpack_from('<I', self._data, 16)
        offset = 32
        for _ in range(n_commands):
            command, size = struct.unpack_from('<II', self._data, offset)
            if command == _LC_SEGMENT_64:
                n_sections, = struct.unpack_from('<I', self._data, offset + 64)
                cursor = offset + 72
                for _ in range(n_sections):
                    name = self._data[cursor:cursor + 16].rstrip(b'\0').decode()
                    address, section_size = struct.unpack_from('<QQ', self._data, cursor + 32)
                    file_offset, = struct.unpack_from('<I', self._data, cursor + 48)
                    yield Section(name, address, section_size, file_offset)
                    cursor += 80
            offset += size

    def offset_of(self, address: int) -> int | None:
        """Map a virtual address to a file offset, or ``None`` when unmapped."""
        for section in self._sections:
            if section.address <= address < section.address + section.size:
                if section.name in _ZERO_FILL:
                    return None
                return section.offset + (address - section.address)
        return None

    def section(self, name: str) -> Section | None:
        """Find a section by name."""
        return next((s for s in self._sections if s.name == name), None)

    def string_at(self, address: int) -> str:
        """Read a NUL-terminated string, or ``'?'`` when unreadable."""
        offset = self.offset_of(address)
        if offset is None:
            return '?'
        return self._data[offset:self._data.index(b'\0', offset)].decode('utf-8', 'replace')

    def _word(self, address: int) -> int:
        offset = self.offset_of(address)
        return 0 if offset is None else struct.unpack_from('<Q', self._data, offset)[0]

    def _accessors(self, properties: int) -> set[str]:
        """Derive the selectors a class's property list synthesises."""
        offset = self.offset_of(properties) if properties else None
        if offset is None:
            return set()
        entry_size, count = struct.unpack_from('<II', self._data, offset)
        out: set[str] = set()
        for index in range(count):
            entry = offset + 8 + index * entry_size
            name = self.string_at(struct.unpack_from('<Q', self._data, entry)[0])
            attributes = self.string_at(struct.unpack_from('<Q', self._data, entry + 8)[0])
            getter = re.search(r'(?:^|,)G([^,]+)', attributes)
            setter = re.search(r'(?:^|,)S([^,]+)', attributes)
            out.add(getter.group(1) if getter else name)
            if 'R' not in attributes.split(','):
                out.add(setter.group(1) if setter else f'set{name[:1].upper()}{name[1:]}:')
        return out

    def _method_list(self, method_list: int) -> list[tuple[str, int]]:
        """Walk a method list, returning each selector and implementation address."""
        offset = self.offset_of(method_list) if method_list else None
        if offset is None:
            return []
        entry_size, count = struct.unpack_from('<II', self._data, offset)
        out: list[tuple[str, int]] = []
        for index in range(count):
            entry = offset + 8 + index * entry_size
            # A 12-byte entry is a relative method list: each field is a signed offset from itself.
            if entry_size == 12:
                name_offset, _, imp_offset = struct.unpack_from('<iii', self._data, entry)
                entry_address = method_list + 8 + index * entry_size
                out.append((self.string_at(self._word(entry_address + name_offset)),
                            entry_address + 8 + imp_offset))
            else:
                name, _, implementation = struct.unpack_from('<QQQ', self._data, entry)
                out.append((self.string_at(name), implementation))
        return out

    def methods(self) -> list[Method]:
        """Enumerate every method the binary defines, from the class list and the category list."""
        out: list[Method] = []
        classlist = self.section('__objc_classlist')
        if classlist is not None:
            for index in range(classlist.size // 8):
                address, = struct.unpack_from('<Q', self._data, classlist.offset + index * 8)
                out.extend(self._class_methods(address))
        catlist = self.section('__objc_catlist')
        if catlist is not None:
            for index in range(catlist.size // 8):
                address, = struct.unpack_from('<Q', self._data, catlist.offset + index * 8)
                out.extend(self._category_methods(address))
        return out

    def _class_methods(self, class_address: int) -> list[Method]:
        offset = self.offset_of(class_address)
        if offset is None:
            return []
        isa, _, _, _, data = struct.unpack_from('<QQQQQ', self._data, offset)
        out: list[Method] = []
        for ro, kind in ((data, '-'), (self._metaclass_ro(isa), '+')):
            ro_offset = self.offset_of(ro) if ro else None
            if ro_offset is None:
                continue
            name = self.string_at(struct.unpack_from('<Q', self._data, ro_offset + 24)[0])
            method_list, = struct.unpack_from('<Q', self._data, ro_offset + 32)
            properties, = struct.unpack_from('<Q', self._data, ro_offset + 64)
            accessors = self._accessors(properties)
            for selector, implementation in self._method_list(method_list):
                out.append(Method(name, kind, selector, implementation, selector in accessors))
        return out

    def _metaclass_ro(self, isa: int) -> int:
        offset = self.offset_of(isa)
        if offset is None:
            return 0
        *_, data = struct.unpack_from('<QQQQQ', self._data, offset)
        return data

    def _category_methods(self, category_address: int) -> list[Method]:
        offset = self.offset_of(category_address)
        if offset is None:
            return []
        name, _, instance_methods, class_methods = struct.unpack_from('<QQQQ', self._data, offset)
        # The class a category extends is reached through a reference the linker binds at load time,
        # so it cannot be named from the file. The category's own name is recorded instead.
        label = f'({self.string_at(name)})'
        out: list[Method] = []
        for method_list, kind in ((instance_methods, '-'), (class_methods, '+')):
            for selector, implementation in self._method_list(method_list):
                out.append(Method(label, kind, selector, implementation, False))
        return out


def reconstructed(root: Path) -> tuple[set[tuple[str, str, str]], set[tuple[str, str]]]:
    """
    Collect what the source tree reconstructs.

    Returns
    -------
    tuple[set, set]
        Keyed definitions of ``(class, kind, selector)``, and ``(kind, selector)`` pairs for
        anything defined in a category, whose class cannot be matched by name.
    """
    keyed: set[tuple[str, str, str]] = set()
    loose: set[tuple[str, str]] = set()
    implementation = re.compile(r'^@implementation\s+(\w+)(?:\s*\(\s*(\w+)\s*\))?')
    interface = re.compile(r'^@interface\s+(\w+)(?:\s*\(\s*\w*\s*\))?')
    end = re.compile(r'^@end')
    method = re.compile(r'^\s*([-+])\s*\([^)]*\)\s*(.+)$')
    prop = re.compile(r'^\s*@property\s*(?:\(([^)]*)\))?\s*.*?([A-Za-z_]\w*)\s*;')
    files = []
    for pattern in ('Project/**/*.m', 'Project/**/*.mm', 'Project/**/*.h'):
        files += glob.glob(pattern, recursive=True)
    for name in sorted(set(files)):
        lines = Path(name).read_text(errors='replace').splitlines()
        current: str | None = None
        is_category = False
        for index, line in enumerate(lines):
            opened = implementation.match(line) or interface.match(line)
            if opened:
                current = opened.group(1)
                is_category = '(' in line.split(current, 1)[1][:3]
                continue
            if end.match(line):
                current = None
                continue
            if current is None:
                continue
            found = method.match(line)
            if found:
                chunk = found.group(2)
                cursor = index
                while '{' not in chunk and ';' not in chunk and cursor - index < 8:
                    cursor += 1
                    if cursor >= len(lines):
                        break
                    chunk += ' ' + lines[cursor]
                selector = _selector_of(chunk)
                if selector:
                    keyed.add((current, found.group(1), selector))
                    if is_category:
                        loose.add((found.group(1), selector))
                continue
            declared = prop.match(line)
            if declared:
                attributes = declared.group(1) or ''
                name_ = declared.group(2)
                getter = re.search(r'getter\s*=\s*(\w+)', attributes)
                keyed.add((current, '-', getter.group(1) if getter else name_))
                if 'readonly' not in attributes:
                    setter = re.search(r'setter\s*=\s*(\w+:?)', attributes)
                    if setter:
                        selector = setter.group(1)
                        keyed.add((current, '-', selector if selector.endswith(':') else
                                   f'{selector}:'))
                    else:
                        keyed.add((current, '-', f'set{name_[:1].upper()}{name_[1:]}:'))
    return keyed, loose


def _selector_of(signature: str) -> str:
    """Build a selector from a method signature's text after the return type."""
    text = signature.split('{')[0].split(';')[0].strip()
    if ':' not in text:
        return re.split(r'[\s(]', text)[0]
    return ''.join(f'{part}:' for part in re.findall(r'(\w+)\s*:', text))


def mechanically_verified() -> dict[int, str]:
    """
    Read the addresses the mechanical passes proved against the instructions.

    Returns
    -------
    dict[int, str]
        Each verified address and what it was shown to do.
    """
    out: dict[int, str] = {}
    for name in ('tools/objc_verified.txt', 'tools/objc_verified_trivial.txt'):
        path = Path(name)
        if not path.is_file():
            continue
        for line in path.read_text().splitlines():
            if line.startswith('#') or not line.strip():
                continue
            address, _, why = line.partition(' ')
            out[int(address, 16)] = why
    return out


def render(methods: list[Method], keyed, loose) -> str:
    """Build the checklist document."""
    listed = [m for m in methods if m.selector not in _COMPILER_GENERATED]
    skipped = len(methods) - len(listed)
    mechanical = mechanically_verified()
    rows = []
    done = verified = 0
    for m in sorted(listed, key=lambda m: m.address):
        is_reconstructed = ((m.class_name, m.kind, m.selector) in keyed
                    or (m.kind, m.selector) in loose)
        relative = m.address - IMAGE_BASE
        is_verified = relative in VERIFIED or relative in mechanical
        done += is_reconstructed
        verified += is_verified
        rows.append(f'| `{m.class_name}` | `{m.kind}` | `{m.selector}` | '
                    f'{"prop" if m.accessor else ""} | {DONE if is_reconstructed else NOT} | '
                    f'{DONE if is_verified else NOT} | `{m.address - IMAGE_BASE:#x}` |')
    accessors = sum(1 for m in listed if m.accessor)
    mechanical_count = sum(1 for m in listed
                           if m.accessor and (m.address - IMAGE_BASE) in mechanical)
    header = f'''# Objective-C methods to verify

Every Objective-C method the binary defines, from its own runtime metadata. Nothing Apple ships
appears here: a framework's classes live in the framework, so the only Apple-derived rows are the
categories this application adds to Apple classes, which are its own code. The
{skipped} `.cxx_construct`/`.cxx_destruct` methods the compiler emits for ARC-managed and C++-typed
ivars are counted and excluded, since they have no reconstruction and never will.

`Reconstructed` is whether a reconstruction exists in the source tree, either an explicit
definition in the class's `@implementation` or a `@property` that synthesises it. `Verified` is
whether that reconstruction has been read against the disassembly, per the five-step process in
[.claude/rules/reconstruction.md](.claude/rules/reconstruction.md). **The two are independent, and
the gap between them is the point of this file.** `prop` marks a method a property list synthesises.

A category cannot be attributed to the class it extends: that class is reached through a reference
the linker binds at load time, so the file never names it, and a category's own name is the
category's. Those rows carry the category name in parentheses and are matched on the selector alone.

Total: {len(listed)} — {done} reconstructed, {verified} verified
({100.0 * verified / len(listed):.1f}%).
{accessors} are property accessors. Two mechanical passes account for most of the verified
count and record their evidence per address: `tools/objc_verify_accessors.py` shows an accessor
moves exactly the ivar its property declares, and `tools/objc_verify_trivial.py` shows an empty or
constant-returning body agrees with its reconstruction. Everything else was read by hand.

Regenerate with `tools/objc_update.py <binary>`, where the binary is the one **inside the .ipa**;
the unpacked copy under `rb458orig` is a different build and matches nothing.

| Class | Kind | Selector | Prop | Reconstructed | Verified | Address |
| ----- | :--: | -------- | :--: | :-----------: | :------: | ------- |
'''
    return header + '\n'.join(rows) + '\n'


def main(argv=None) -> int:
    """Regenerate the checklist."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the shipped Mach-O from inside the .ipa')
    parser.add_argument('root', type=Path, nargs='?', default=Path('Project'),
                        help='the reconstructed source root (default: Project)')
    args = parser.parse_args(argv)
    if not args.binary.is_file():
        print(f'error: no such binary: {args.binary}', file=sys.stderr)
        return 1
    metadata = Metadata(args.binary)
    methods = metadata.methods()
    if not methods:
        print('error: no Objective-C metadata found; is this the right binary?', file=sys.stderr)
        return 1
    keyed, loose = reconstructed(args.root)
    Path(PATH).write_text(render(methods, keyed, loose))
    print(f'wrote {PATH}: {len(methods)} method(s) from the metadata')
    # A VERIFIED entry naming an address the metadata does not define is a claim about a routine
    # that does not exist, which is worse than no claim, so say so rather than silently dropping it.
    defined = {m.address - IMAGE_BASE for m in methods}
    stale = sorted(set(VERIFIED) - defined)
    for address in stale:
        print(f'error: VERIFIED names {address:#x}, which the metadata does not define: '
              f'{VERIFIED[address]}', file=sys.stderr)
    return 1 if stale else 0


if __name__ == '__main__':
    raise SystemExit(main())
