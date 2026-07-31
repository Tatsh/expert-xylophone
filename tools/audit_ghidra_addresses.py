#!/usr/bin/env python3
"""
Check every @ghidraAddress annotation in the tree against the shipped binary.

An @ghidraAddress is a falsifiable claim, so it can be verified mechanically rather than by reading.
Two kinds are checked:

*methods*
    The Objective-C runtime metadata maps each class and selector to the address of its
    implementation. A method annotated with an address that is not that implementation's is
    reported. A selector absent from the metadata is reported separately: it is either a phantom
    method the reconstruction invented or a signature this script failed to parse.

*constants*
    A numeric constant annotated with an address claims the binary holds that value there. The
    eight bytes at the address are read as both a double and a float, and a constant matching
    neither is reported. Only annotations on the same line as the declaration are checked, because
    an annotation on the preceding line cannot be attributed to one declaration with confidence.

Neither check says anything about a constant carrying no annotation, which is most of them, nor
about whether a correctly addressed routine was transcribed correctly. Both remain matters for
reading the disassembly.
"""
from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, NamedTuple
import argparse
import re
import struct
import sys

if TYPE_CHECKING:
    from collections.abc import Iterator, Sequence

__all__ = ('main',)

IMAGE_BASE = 0x100000000
# Sections whose contents are not in the file, so nothing can be read from them.
_ZERO_FILL = ('__bss', '__common')
_LC_SEGMENT_64 = 0x19
# The share of annotated methods that must disagree before the binary itself is judged to be the
# wrong build rather than the annotations being wrong.
_WRONG_BINARY_RATIO = 0.5
# The start of an Objective-C block literal, which ends the search for a method's own annotation.
# A block literal opens with a caret, optionally a return type, optionally a parameter list, then
# the brace. Matching only '^{' missed every block that declares parameters, so a tag belonging to
# such a block was read as the enclosing method's and reported as a mismatch.
_BLOCK_LITERAL = re.compile(r'\^\s*\w*\s*(?:\([^)]*\)\s*)?\{')
# A double is considered to match a declaration within this absolute tolerance, a float within a
# looser one, since a float literal loses precision.
_DOUBLE_TOLERANCE = 1e-6
_FLOAT_TOLERANCE = 1e-4


class Section(NamedTuple):
    """One Mach-O section, enough of it to map an address to a file offset."""

    name: str
    address: int
    size: int
    offset: int


class MethodFinding(NamedTuple):
    """One annotated method whose address disagrees with the runtime metadata."""

    path: str
    line: int
    class_name: str
    kind: str
    selector: str
    annotated: int
    actual: int | None


class ConstantFinding(NamedTuple):
    """One annotated constant whose declared value is not what the binary holds."""

    path: str
    line: int
    name: str
    declared: float
    as_double: float
    as_float: float


class Binary:
    """The shipped Mach-O, indexed well enough to read addresses and Objective-C metadata."""

    def __init__(self, path: Path) -> None:
        self._data = path.read_bytes()
        self._sections = list(self._read_sections())

    def _read_sections(self) -> Iterator[Section]:
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
        """
        Map a virtual address to a file offset.

        Parameters
        ----------
        address : int
            The virtual address, including the image base.

        Returns
        -------
        int | None
            The file offset, or ``None`` when no section covers the address or its section is
            zero-filled.
        """
        for section in self._sections:
            if section.address <= address < section.address + section.size:
                if section.name in _ZERO_FILL:
                    return None
                return section.offset + (address - section.address)
        return None

    def section(self, name: str) -> Section | None:
        """
        Find a section by name.

        Parameters
        ----------
        name : str
            The section name, for example ``__objc_classlist``.

        Returns
        -------
        Section | None
            The section, or ``None`` when the binary has none by that name.
        """
        return next((s for s in self._sections if s.name == name), None)

    def string_at(self, address: int) -> str:
        """
        Read a NUL-terminated string.

        Parameters
        ----------
        address : int
            The virtual address of the first byte.

        Returns
        -------
        str
            The string, or ``'?'`` when the address is unreadable.
        """
        offset = self.offset_of(address)
        if offset is None:
            return '?'
        end = self._data.index(b'\0', offset)
        return self._data[offset:end].decode('utf-8', 'replace')

    def word_at(self, address: int) -> int:
        """
        Read a 64-bit word.

        Parameters
        ----------
        address : int
            The virtual address.

        Returns
        -------
        int
            The word, or zero when the address is unreadable.
        """
        offset = self.offset_of(address)
        return struct.unpack_from('<Q', self._data, offset)[0] if offset is not None else 0

    def doubles_at(self, address: int) -> tuple[float, float] | None:
        """
        Read eight bytes as both a double and a float.

        Parameters
        ----------
        address : int
            The virtual address.

        Returns
        -------
        tuple[float, float] | None
            The value read as a double and as a float, or ``None`` when unreadable.
        """
        offset = self.offset_of(address)
        if offset is None or offset + 8 > len(self._data):
            return None
        return (struct.unpack_from('<d', self._data, offset)[0],
                struct.unpack_from('<f', self._data, offset)[0])

    def method_map(self) -> dict[tuple[str, str, str], int]:
        """
        Map every class, kind, and selector in the metadata to its implementation address.

        Returns
        -------
        dict[tuple[str, str, str], int]
            Keyed by the class name, ``'-'`` or ``'+'``, and the selector.
        """
        classlist = self.section('__objc_classlist')
        out: dict[tuple[str, str, str], int] = {}
        if classlist is None:
            return out
        for index in range(classlist.size // 8):
            class_address, = struct.unpack_from('<Q', self._data, classlist.offset + index * 8)
            offset = self.offset_of(class_address)
            if offset is None:
                continue
            isa, _, _, _, data = struct.unpack_from('<QQQQQ', self._data, offset)
            self._collect_methods(data, '-', out)
            meta_offset = self.offset_of(isa)
            if meta_offset is not None:
                *_, meta_data = struct.unpack_from('<QQQQQ', self._data, meta_offset)
                self._collect_methods(meta_data, '+', out)
        return out

    def category_map(self) -> dict[tuple[str, str], int]:
        """
        Map every kind and selector defined in a category to its implementation address.

        Categories are keyed without a class name. A category on a framework class points at that
        class through a reference the linker binds at load time, so the name cannot be read from the
        file, and the category's own name is the category's rather than the class's.

        A selector defined by more than one category cannot be attributed, since the class each
        belongs to is unreadable, so it maps to ``None`` and its annotation is left unverifiable
        rather than reported against whichever category happened to come first.

        Returns
        -------
        dict[tuple[str, str], int | None]
            Keyed by ``'-'`` or ``'+'`` and the selector; ``None`` where two categories collide.
        """
        catlist = self.section('__objc_catlist')
        out: dict[tuple[str, str], int | None] = {}
        if catlist is None:
            return out
        for index in range(catlist.size // 8):
            address, = struct.unpack_from('<Q', self._data, catlist.offset + index * 8)
            offset = self.offset_of(address)
            if offset is None:
                continue
            _, _, instance_methods, class_methods = struct.unpack_from('<QQQQ', self._data, offset)
            for methods, kind in ((instance_methods, '-'), (class_methods, '+')):
                if not methods:
                    continue
                keyed: dict[tuple[str, str, str], int] = {}
                self._collect_method_list(methods, '', kind, keyed)
                for (_, method_kind, selector), implementation in keyed.items():
                    key = (method_kind, selector)
                    if key in out and out[key] != implementation:
                        out[key] = None
                    else:
                        out.setdefault(key, implementation)
        return out

    def _collect_methods(self, class_ro: int, kind: str,
                         out: dict[tuple[str, str, str], int]) -> None:
        offset = self.offset_of(class_ro)
        if offset is None:
            return
        class_name = self.string_at(struct.unpack_from('<Q', self._data, offset + 24)[0])
        method_list = struct.unpack_from('<Q', self._data, offset + 32)[0]
        self._collect_method_list(method_list, class_name, kind, out)

    def _collect_method_list(self, method_list: int, class_name: str, kind: str,
                             out: dict[tuple[str, str, str], int]) -> None:
        list_offset = self.offset_of(method_list) if method_list else None
        if list_offset is None:
            return
        entry_size, count = struct.unpack_from('<II', self._data, list_offset)
        for index in range(count):
            entry = list_offset + 8 + index * entry_size
            # A 12-byte entry is a relative method list: each field is a signed offset from itself.
            if entry_size == 12:
                name_offset, _, imp_offset = struct.unpack_from('<iii', self._data, entry)
                entry_address = method_list + 8 + index * entry_size
                selector = self.string_at(self.word_at(entry_address + name_offset))
                implementation = entry_address + 8 + imp_offset
            else:
                name, _, implementation = struct.unpack_from('<QQQ', self._data, entry)
                selector = self.string_at(name)
            out[(class_name, kind, selector)] = implementation


_ADDRESS = re.compile(r'@ghidraAddress\s+(0x[0-9a-fA-F]+)')
_IMPLEMENTATION = re.compile(r'^@implementation\s+(\w+)')
_END = re.compile(r'^@end')
_METHOD_START = re.compile(r'^\s*([-+])\s*\([^)]*\)\s*(.+)$')
_NUMBER = r'[-+]?\d+(?:\.\d+)?f?'
# The value may be a bare literal or a division of two literals. The latter is how an eight-bit
# colour component is spelled — 47.0f / 255.0f — and reading it keeps those constants checked
# rather than dropping them for being an expression.
_ANNOTATED_CONSTANT = re.compile(r'\b(k\w+|g_\w+)\s*=\s*(' + _NUMBER +
                                 r'(?:\s*/\s*' + _NUMBER + r')?'
                                 r')\s*;.*@ghidraAddress\s+(0x[0-9a-fA-F]+)')


def _selector_of(signature: str) -> str:
    """
    Recover a selector from the text of a method definition.

    Parameters
    ----------
    signature : str
        Everything after the return type, up to and including the opening brace.

    Returns
    -------
    str
        The selector, for example ``unzip:`` or ``alertView:clickedButtonAtIndex:``.
    """
    depth = 0
    stripped = ''
    for character in signature.split('{')[0]:
        if character == '(':
            depth += 1
        elif character == ')':
            depth -= 1
            continue
        if depth == 0:
            stripped += character
    selector = ''
    for token in stripped.replace('\n', ' ').split():
        if ':' in token:
            selector += token.split(':')[0] + ':'
        elif not selector:
            selector = token
    return selector.strip()


def _sources(root: Path, suffixes: Sequence[str]) -> list[Path]:
    return sorted(path for suffix in suffixes for path in root.rglob('*' + suffix))


def audit_methods(root: Path, binary: Binary) -> tuple[int, list[MethodFinding], int]:
    """
    Check every annotated method definition against the runtime metadata.

    Parameters
    ----------
    root : Path
        The directory holding the reconstructed sources.
    binary : Binary
        The shipped binary.

    Returns
    -------
    tuple[int, list[MethodFinding], int]
        The number checked, the mismatches, and the count whose selector the metadata lacks.
    """
    metadata = binary.method_map()
    # A category's methods are not in the class list, and a category on a framework class does not
    # name that class in the file at all, so they are matched on the selector alone.
    categories = binary.category_map()
    checked = 0
    mismatches: list[MethodFinding] = []
    unknown = 0
    for path in _sources(root, ('.m', '.mm')):
        lines = path.read_text(errors='replace').splitlines()
        class_name: str | None = None
        for index, line in enumerate(lines):
            opened = _IMPLEMENTATION.match(line)
            if opened:
                class_name = opened.group(1)
                continue
            if _END.match(line):
                class_name = None
                continue
            if class_name is None:
                continue
            start = _METHOD_START.match(line)
            if not start:
                continue
            chunk = line
            last = index
            while '{' not in chunk and last - index < 8 and last + 1 < len(lines):
                last += 1
                chunk += ' ' + lines[last]
            if '{' not in chunk:
                continue
            selector = _selector_of(chunk[chunk.index(')') + 1:])
            if not selector:
                continue
            annotated = None
            # The rules put the tag on the declaration, which for a definition means the comment
            # block directly above the signature. Looking only below the opening brace missed
            # every annotation written that way, and there are more of those than of the other
            # kind, so a clean run was reporting on a minority of them. Only comment lines are
            # walked, so this cannot reach up into the previous method's body.
            for probe in range(index - 1, max(index - 5, -1), -1):
                above = lines[probe].strip()
                if not above.startswith(('/**', '*', '//')) and not above.endswith('*/'):
                    break
                found = _ADDRESS.search(lines[probe])
                if found:
                    annotated = int(found.group(1), 16)
                    break
            if annotated is not None:
                checked += 1
                # Both maps are keyed by kind as well as selector, and both hold absolute
                # addresses. This branch looked them up with a pair and a bare string and then
                # compared without rebasing, so neither lookup could ever hit: every method
                # annotated above its signature was counted as absent from the metadata and never
                # checked. The block below, for methods annotated inside the body, had it right.
                expected = metadata.get((class_name, start.group(1), selector))
                if expected is None:
                    expected = categories.get((start.group(1), selector))
                if expected is None:
                    unknown += 1
                elif expected - IMAGE_BASE != annotated:
                    mismatches.append(
                        MethodFinding(path,
                                      index + 1,
                                      class_name,
                                      start.group(1),
                                      selector,
                                      annotated,
                                      expected))
                continue
            for probe in range(last, min(last + 4, len(lines))):
                found = _ADDRESS.search(lines[probe])
                if found:
                    annotated = int(found.group(1), 16)
                    break
                # By convention an implementation file carries a tag inside a block body, where it
                # records the block's own address. Once a block literal opens, any tag below belongs
                # to that block and must not be read as the enclosing method's.
                if _BLOCK_LITERAL.search(lines[probe]):
                    break
            if annotated is None:
                continue
            checked += 1
            actual = metadata.get((class_name, start.group(1), selector))
            if actual is None:
                actual = categories.get((start.group(1), selector))
            if actual is None:
                unknown += 1
            elif actual - IMAGE_BASE != annotated:
                mismatches.append(
                    MethodFinding(str(path), index + 1, class_name, start.group(1), selector,
                                  annotated, actual))
    return checked, mismatches, unknown


def audit_constants(root: Path, binary: Binary) -> tuple[int, list[ConstantFinding]]:
    """
    Check every same-line annotated numeric constant against the binary.

    Parameters
    ----------
    root : Path
        The directory holding the reconstructed sources.
    binary : Binary
        The shipped binary.

    Returns
    -------
    tuple[int, list[ConstantFinding]]
        The number checked and the mismatches.
    """
    checked = 0
    mismatches: list[ConstantFinding] = []
    for path in _sources(root, ('.m', '.mm', '.h', '.cpp', '.c')):
        for index, line in enumerate(path.read_text(errors='replace').splitlines()):
            found = _ANNOTATED_CONSTANT.search(line)
            if not found:
                continue
            address = int(found.group(3), 16)
            if address < IMAGE_BASE:
                address += IMAGE_BASE
            values = binary.doubles_at(address)
            if values is None:
                continue
            as_double, as_float = values
            spelled = found.group(2)
            if '/' in spelled:
                # Divide at single precision, which is what the f-suffixed literals compile to.
                numerator, denominator = (float(part.strip().rstrip('f'))
                                          for part in spelled.split('/'))
                declared = struct.unpack('<f', struct.pack('<f', numerator / denominator))[0]
            else:
                declared = float(spelled.rstrip('f'))
            checked += 1
            if (abs(as_double - declared) > _DOUBLE_TOLERANCE
                    and abs(as_float - declared) > _FLOAT_TOLERANCE):
                mismatches.append(
                    ConstantFinding(str(path), index + 1, found.group(1), declared, as_double,
                                    as_float))
    return checked, mismatches


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument('binary', type=Path, help='the shipped Mach-O to check against')
    parser.add_argument('root',
                        nargs='?',
                        type=Path,
                        default=Path('Project'),
                        help='the reconstructed source root (default: Project)')
    parser.add_argument('--quiet',
                        action='store_true',
                        help='print the totals only, without each finding')
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    """
    Run both audits and report.

    Parameters
    ----------
    argv : Sequence[str] | None
        The command-line arguments (defaults to ``sys.argv``).

    Returns
    -------
    int
        The number of mismatches found, capped so it stays a usable exit status.
    """
    args = _parse_args(argv)
    if not args.binary.is_file():
        print(f'error: no such binary: {args.binary}', file=sys.stderr)
        return 1
    binary = Binary(args.binary)

    checked, method_findings, unknown = audit_methods(args.root, binary)
    print(f'methods: {checked} annotated, {len(method_findings)} mismatched, '
          f'{unknown} selector(s) absent from the metadata')
    # An annotation set that disagrees with the binary this wholesale is not a set of defects: the
    # annotations follow whichever build the Ghidra project holds, so a different build of the same
    # application mismatches on nearly every address at once. Reporting those as findings sends the
    # reader chasing thousands of phantom defects, so refuse instead.
    if checked and len(method_findings) > checked * _WRONG_BINARY_RATIO:
        print(f'error: {len(method_findings)} of {checked} annotated methods disagree, which means '
              'this binary is not the build the annotations were taken from. Point the audit at '
              'the binary loaded in the Ghidra project.',
              file=sys.stderr)
        return 1
    if not args.quiet:
        for finding in method_findings:
            actual = 'none' if finding.actual is None else f'{finding.actual - IMAGE_BASE:#x}'
            print(f'  {finding.path}:{finding.line} {finding.kind}[{finding.class_name} '
                  f'{finding.selector}] annotated {finding.annotated:#x} actual {actual}')

    const_checked, const_findings = audit_constants(args.root, binary)
    print(f'constants: {const_checked} annotated on the declaration line, '
          f'{len(const_findings)} mismatched')
    if not args.quiet:
        for constant in const_findings:
            print(f'  {constant.path}:{constant.line} {constant.name} '
                  f'declared={constant.declared:g} double={constant.as_double:g} '
                  f'float={constant.as_float:g}')

    return min(len(method_findings) + len(const_findings), 125)


if __name__ == '__main__':
    raise SystemExit(main())
