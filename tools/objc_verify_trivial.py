#!/usr/bin/env python3
"""Verify methods whose whole body is trivial, and record which ones hold.

Some methods do nothing, and some do nothing but return a constant. Both are checkable without
judgement, and both are worth checking rather than assuming: a method the binary leaves empty while
the reconstruction gives it real work is a fidelity defect, and a constant return is exactly the
kind of value that gets transcribed wrong without anything noticing.

Four shapes are recognised, all read from the instruction words:

``ret``
    The body does nothing. The reconstruction must also do nothing, ignoring documentation comments
    and the ``(void)argument;`` discards the rules ask for on a deliberately unused parameter.

``mov w0,#imm; ret`` and ``mov x0,#imm; ret``
    The body returns a constant. The reconstruction must return the same value, in any of the
    spellings that mean it — a bare integer, ``YES``/``NO``, ``nil``, a hex literal, or a named
    constant the file defines, since the rules require a name rather than a bare number.

a ``dealloc`` that only calls the superclass
    This is the ``dealloc`` ARC writes, and ARC forbids writing it by hand, so the reconstruction
    must either omit it entirely or leave it empty. Its absence is the correct reconstruction rather
    than a gap, which is why some of the methods the checklist counts as unreconstructed should be
    read that way.

This is disassembly, not decompiler output: the instruction words are decoded here, from the bytes.
Anything that does not match one of the shapes, or whose reconstruction cannot be located, is left
unverified rather than assumed correct.

Usage: ``tools/objc_verify_trivial.py <binary>``, where the binary is the one **inside the .ipa**.
"""
import argparse
import glob
import re
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from objc_update import IMAGE_BASE, Metadata, _selector_of  # noqa: E402
from objc_verify_accessors import (AccessorCheck, _adrp, _branch_target,  # noqa: E402
                                  _is_branch_with_link)

OUTPUT = 'tools/objc_verified_trivial.txt'
_RET = 0xD65F03C0
# Lines in a reconstructed body that do not count as work: documentation, ordinary comments, and the
# `(void)argument;` discard the rules prescribe for a parameter the binary ignores.
_INERT = re.compile(r'^\s*(?:/\*|\*|//|\(void\)\s*\w+\s*;|\}?\s*$)')
# `return` spellings that mean zero, and the ones that mean one.
_ZERO = {'0', 'NO', 'nil', 'NULL', 'nullptr', 'false', '0.0', '0x0'}
_ONE = {'1', 'YES', 'true', '0x1'}
# Framework constants a constant-returning method commonly names. Resolving them is what lets the
# comparison be made against the value rather than against the spelling.
_FRAMEWORK = {
    'UIInterfaceOrientationUnknown': 0,
    'UIInterfaceOrientationPortrait': 1,
    'UIInterfaceOrientationPortraitUpsideDown': 2,
    'UIInterfaceOrientationLandscapeLeft': 3,
    'UIInterfaceOrientationLandscapeRight': 4,
    'UIInterfaceOrientationMaskPortrait': 1 << 1,
    'UIInterfaceOrientationMaskPortraitUpsideDown': 1 << 2,
    'UIInterfaceOrientationMaskLandscapeLeft': 1 << 3,
    'UIInterfaceOrientationMaskLandscapeRight': 1 << 4,
    'UIInterfaceOrientationMaskLandscape': (1 << 3) | (1 << 4),
    'UIInterfaceOrientationMaskAll': (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4),
    'UIInterfaceOrientationMaskAllButUpsideDown': (1 << 1) | (1 << 3) | (1 << 4),
    'UIStatusBarStyleDefault': 0,
    'UIStatusBarStyleLightContent': 1,
    'NSNotFound': 0x7FFFFFFFFFFFFFFF,
}


def _is_super_only(metadata: Metadata, stubs: dict[int, str], address: int) -> bool:
    """
    Decide whether a body does nothing but call through to the superclass.

    Under ARC a ``dealloc`` of this shape is the one the compiler writes, and writing it by hand is
    not allowed, so the reconstruction should have no ``dealloc`` at all.
    """
    offset = metadata.offset_of(address)
    if offset is None:
        return False
    calls: list[str] = []
    for index in range(30):
        word = struct.unpack_from('<I', metadata._data, offset + index * 4)[0]
        if _is_branch_with_link(word):
            calls.append(stubs.get(_branch_target(word, address + index * 4), '?'))
        if word == _RET:
            return calls == ['_objc_msgSendSuper2']
    return False


def _immediate_into(word: int, register: int) -> int | None:
    """Decode a MOVZ or an ORR-against-zero that puts a small constant into a given register."""
    if (word & 0x1F) != register:
        return None
    if (word & 0xFFE00000) in (0x52800000, 0xD2800000):
        return (word >> 5) & 0xFFFF
    if word in (0xAA1F03E0 | register, 0x2A1F03E0 | register):
        return 0
    if (word & 0x7F800000) == 0x32000000 and ((word >> 5) & 0x1F) == 31:
        width = 64 if (word >> 31) & 1 else 32
        return _bitmask_immediate((word >> 22) & 1, (word >> 16) & 0x3F, (word >> 10) & 0x3F, width)
    return None


def class_names(metadata: Metadata) -> dict[int, str]:
    """Map each class object's address to its name, so a class receiver can be identified."""
    out: dict[int, str] = {}
    classlist = metadata.section('__objc_classlist')
    if classlist is None:
        return out
    for index in range(classlist.size // 8):
        address, = struct.unpack_from('<Q', metadata._data, classlist.offset + index * 8)
        offset = metadata.offset_of(address)
        if offset is None:
            continue
        ro, = struct.unpack_from('<Q', metadata._data, offset + 32)
        ro_offset = metadata.offset_of(ro)
        if ro_offset is None:
            continue
        out[address] = metadata.string_at(
            struct.unpack_from('<Q', metadata._data, ro_offset + 24)[0])
    return out


def _constant_string(metadata: Metadata, address: int) -> str | None:
    """Read the text of the constant string object at an address, or None if it is not one.

    A literal `@"..."` is a four-field structure and the characters are behind the pointer in its
    third field, sixteen bytes in.
    """
    try:
        pointer = metadata._word(address + 16)
    except (TypeError, struct.error):
        return None
    if not pointer:
        return None
    try:
        return metadata.string_at(pointer)
    except (TypeError, struct.error):
        return None


def _forwarded_send(metadata: Metadata, stubs: dict[int, str], classes: dict[int, str],
                    address: int) -> tuple[str, str, int | str | None] | None:
    """
    Recover a body that is nothing but a tail-call send, as receiver, selector, and argument.

    These bodies set up at most a receiver in x0, a selector in x1 and one argument in x2, then
    branch to objc_msgSend. A receiver left untouched is self; one loaded from a class reference is
    that class. The argument is either an immediate or a constant string, the latter formed as an
    `adrp` and an `add` rather than loaded, and returned as its text so the comparison can be made
    against what the reconstruction actually spells. Anything else means it is not a plain forward,
    and it is rejected.
    """
    offset = metadata.offset_of(address)
    if offset is None:
        return None
    pages: dict[int, int] = {}
    receiver = 'self'
    selector: str | None = None
    argument: int | str | None = None
    for index in range(8):
        word = struct.unpack_from('<I', metadata._data, offset + index * 4)[0]
        here = address + index * 4
        if word == 0xD503201F:  # nop, emitted between an adrp and its load
            continue
        page = _adrp(word, here)
        if page is not None:
            pages[word & 0x1F] = page
            continue
        if (word & 0xFFC00000) == 0xF9400000:  # ldr xT,[xN,#imm]
            byte_offset = ((word >> 10) & 0xFFF) * 8
            base, target = (word >> 5) & 0x1F, word & 0x1F
            if base not in pages or target not in (0, 1):
                return None
            pointer = metadata._word(pages[base] + byte_offset)
            if target == 1:
                selector = metadata.string_at(pointer) if pointer else None
            elif pointer in classes:
                receiver = classes[pointer]
            else:
                return None
            continue
        # `add xD,xN,#imm`, which completes the address an `adrp` began. Only a constant string
        # being passed as the argument is accepted here; anything else is an address this cannot
        # account for.
        if (word & 0xFF800000) == 0x91000000:
            destination, base = word & 0x1F, (word >> 5) & 0x1F
            if destination != 2 or base not in pages:
                return None
            text = _constant_string(metadata, pages[base] + ((word >> 10) & 0xFFF))
            if text is None:
                return None
            argument = text
            continue
        immediate = _immediate_into(word, 2)
        if immediate is not None:
            argument = immediate
            continue
        if (word & 0xFC000000) == 0x14000000:
            if stubs.get(_branch_target(word, here)) != '_objc_msgSend' or selector is None:
                return None
            return (receiver, selector, argument)
        return None
    return None


def _spelled_string(spelled: str, path: str) -> str | None:
    """Read the text a source argument carries, as a literal or a constant the file defines."""
    text = spelled.strip()
    literal = re.fullmatch(r'@"([^"\\]*)"', text)
    if literal is not None:
        return literal.group(1)
    named = re.search(rf'\b{re.escape(text)}\s*=\s*@"([^"\\]*)"\s*;', _file_text(path))
    return named.group(1) if named is not None else None


def _file_text(path: str) -> str:
    """The text of a reconstruction file, or empty when it cannot be read."""
    try:
        return Path(path).read_text()
    except OSError:
        return ''


def _sent_send(body: list[str]) -> tuple[str, str, str | None] | None:
    """
    Recover the single send a body performs, as receiver, selector, and argument text.

    Dot syntax counts, and is the common spelling here because the rules require it: `return
    self.foo;` is a send of `foo` to self, and `self.foo = x;` is a send of `setFoo:`.
    """
    meaningful = _meaningful(body)
    if len(meaningful) != 1:
        return None
    line = meaningful[0]
    getter = re.match(r'^\s*return\s+self\.(\w+)\s*;\s*$', line)
    if getter:
        return ('self', getter.group(1), None)
    setter = re.match(r'^\s*self\.(\w+)\s*=\s*([^;=]+);\s*$', line)
    if setter:
        name = setter.group(1)
        return ('self', f'set{name[:1].upper()}{name[1:]}:', setter.group(2).strip())
    found = re.match(r'^\s*(?:return\s+)?\[(\w+)\s+([^\[\]]+)\]\s*;\s*$', line)
    if not found:
        return None
    receiver, inner = found.group(1), found.group(2).strip()
    if ':' in inner:
        selector = ''.join(f'{k}:' for k in re.findall(r'(\w+)\s*:', inner))
        argument = inner.split(':', 1)[1].strip()
        return (receiver, selector, argument)
    return (receiver, inner, None) if re.fullmatch(r'\w+', inner) else None


def _sent_selector(body: list[str]) -> str | None:
    """
    Find the sole selector a body sends to self, when a single send is all it does.

    Dot syntax counts, and is the common spelling here because the rules require it: `return
    self.foo;` is a send of `foo`, and `self.foo = x;` is a send of `setFoo:`.
    """
    meaningful = _meaningful(body)
    if len(meaningful) != 1:
        return None
    line = meaningful[0]
    getter = re.match(r'^\s*return\s+self\.(\w+)\s*;\s*$', line)
    if getter:
        return getter.group(1)
    setter = re.match(r'^\s*self\.(\w+)\s*=\s*[^;=]+;\s*$', line)
    if setter:
        name = setter.group(1)
        return f'set{name[:1].upper()}{name[1:]}:'
    found = re.match(r'^\s*(?:return\s+)?\[self\s+([^\[\]]+)\]\s*;\s*$', line)
    if not found:
        return None
    inner = found.group(1).strip()
    if ':' in inner:
        return ''.join(f'{k}:' for k in re.findall(r'(\w+)\s*:', inner))
    return inner if re.fullmatch(r'\w+', inner) else None


def _bitmask_immediate(n: int, immr: int, imms: int, width: int) -> int | None:
    """
    Decode an arm64 logical immediate, the encoding ``orr wD,wzr,#imm`` uses.

    A constant return is often assembled as an ORR against the zero register rather than a MOVZ, so
    reading only MOVZ misses it. The encoding is a rotated run of ones, described by the
    N, immr and imms fields.
    """
    length = (n << 6) | (~imms & 0x3F)
    size = 1 << (length.bit_length() - 1) if length else 0
    if size == 0 or size > width:
        return None
    ones = (imms & (size - 1)) + 1
    if ones == size:
        return None
    pattern = (1 << ones) - 1
    rotation = immr & (size - 1)
    pattern = ((pattern >> rotation) | (pattern << (size - rotation))) & ((1 << size) - 1)
    value = 0
    for shift in range(0, width, size):
        value |= pattern << shift
    return value & ((1 << width) - 1)


def _orr_immediate(word: int) -> int | None:
    """Decode ``orr wD,wzr,#imm`` or its 64-bit form into the value it returns."""
    if (word & 0x7F800000) != 0x32000000 or ((word >> 5) & 0x1F) != 31 or (word & 0x1F) != 0:
        return None
    width = 64 if (word >> 31) & 1 else 32
    return _bitmask_immediate((word >> 22) & 1, (word >> 16) & 0x3F, (word >> 10) & 0x3F, width)


def _mov_immediate(word: int) -> int | None:
    """Decode a 32- or 64-bit MOVZ of a small immediate, returning the value."""
    # MOVZ Wd,#imm16 is 0x52800000-shaped; MOVZ Xd,#imm16 is 0xd2800000-shaped. Only shift 0 counts,
    # since a shifted immediate is not the plain constant return this recognises.
    if (word & 0xFFE00000) in (0x52800000, 0xD2800000) and (word & 0x1F) == 0:
        return (word >> 5) & 0xFFFF
    if word == 0xAA1F03E0 or word == 0x2A1F03E0:  # mov x0,xzr / mov w0,wzr
        return 0
    return None


def source_bodies(root: str = 'Project') -> dict[tuple[str, str, str], tuple[str, int, list[str]]]:
    """Collect each reconstructed method's body, keyed by class, kind, and selector."""
    out: dict[tuple[str, str, str], tuple[str, int, list[str]]] = {}
    files = glob.glob(f'{root}/**/*.m', recursive=True) + glob.glob(f'{root}/**/*.mm',
                                                                   recursive=True)
    for name in sorted(files):
        lines = Path(name).read_text(errors='replace').splitlines()
        current: str | None = None
        for index, line in enumerate(lines):
            opened = re.match(r'^@implementation\s+(\w+)', line)
            if opened:
                current = opened.group(1)
                continue
            if re.match(r'^@end', line):
                current = None
                continue
            if current is None:
                continue
            start = re.match(r'^([-+])\s*\([^)]*\)\s*(.+)$', line)
            if not start:
                continue
            chunk = start.group(2)
            cursor = index
            while '{' not in chunk and cursor - index < 8 and cursor + 1 < len(lines):
                cursor += 1
                chunk += ' ' + lines[cursor]
            if '{' not in chunk:
                continue
            selector = _selector_of(chunk)
            if not selector:
                continue
            body: list[str] = []
            probe = cursor + 1
            while probe < len(lines) and not lines[probe].startswith('}'):
                body.append(lines[probe])
                probe += 1
            out[(current, start.group(1), selector)] = (name, index + 1, body)
    return out


def _meaningful(body: list[str]) -> list[str]:
    """Strip the lines that do not count as work."""
    return [line for line in body if not _INERT.match(line)]


def _returned_constant(body: list[str]) -> str | None:
    """Find the sole `return` value in a body, when that is all it does."""
    meaningful = _meaningful(body)
    if len(meaningful) != 1:
        return None
    found = re.match(r'^\s*return\s+(.+?)\s*;\s*$', meaningful[0])
    return found.group(1) if found else None


def _evaluate(expression: str, known: dict[str, int]) -> int | None:
    """Evaluate a constant expression made of names, integers, and bitwise ors."""
    total = 0
    for part in expression.split('|'):
        part = part.strip()
        if part in known:
            total |= known[part]
            continue
        try:
            total |= int(part.rstrip('fuUlL'), 0)
        except ValueError:
            return None
    return total


def file_constants(path: str) -> dict[str, int]:
    """
    Collect the integer constants a source file and its header define.

    The rules require a named constant rather than a bare number, so a method that returns or passes
    one names it, and the name has to be resolved before the value can be compared. Definitions are
    matched across newlines, since a mask built from several named bits is usually wrapped.

    In a header any identifier assigned a constant counts, which is what picks up an ``NS_ENUM``'s
    members. In an implementation file only the k-prefixed form does, because a bare assignment
    there is as likely to be ordinary code as a definition.
    """
    known: dict[str, int] = dict(_FRAMEWORK)
    definition = re.compile(r'(?:static\s+)?const(?:expr)?\s+[\w\s*]*?\b(k\w+)\s*=\s*([^;]+);')
    enumerated = re.compile(r'\b(k\w+)\s*=\s*([^,;}]+)')
    header_enumerated = re.compile(r'^\s*([A-Za-z_]\w*)\s*=\s*([^,;}]+?)\s*,?\s*(?:/\*|$)',
                                   re.MULTILINE)
    header = Path(path).with_suffix('.h')
    for source, patterns in ((Path(path), (definition, enumerated)),
                             (header, (definition, enumerated, header_enumerated))):
        if not source.is_file():
            continue
        text = source.read_text(errors='replace')
        for pattern in patterns:
            for found in pattern.finditer(text):
                value = _evaluate(' '.join(found.group(2).split()), known)
                if value is not None:
                    known.setdefault(found.group(1), value)
    return known


def _matches(value: int, spelled: str, constants: dict[str, int]) -> bool:
    """Decide whether a source `return` spelling means the constant the binary returns."""
    spelled = spelled.strip()
    if value == 0 and spelled in _ZERO:
        return True
    if value == 1 and spelled in _ONE:
        return True
    known = constants
    if spelled in known:
        return known[spelled] == value
    evaluated = _evaluate(spelled, known)
    return evaluated is not None and evaluated == value


def main(argv=None) -> int:
    """Verify every trivially-shaped method, and record the ones that hold."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the shipped Mach-O from inside the .ipa')
    args = parser.parse_args(argv)
    if not args.binary.is_file():
        print(f'error: no such binary: {args.binary}', file=sys.stderr)
        return 1
    metadata = Metadata(args.binary)
    stubs = AccessorCheck(metadata)._stubs
    classes = class_names(metadata)
    bodies = source_bodies()
    passed: list[tuple[int, str]] = []
    findings: list[str] = []
    skipped: Counter = Counter()
    for method in metadata.methods():
        # A method a property declares is normally the accessor pass's to verify, but that pass can
        # only speak for one that moves a backing ivar, and some declared properties are computed
        # instead. Where such a body is one of the shapes here, usually a forward to another
        # method, this pass can settle it, so an accessor is offered rather than skipped. One that
        # really does move an ivar matches none of these shapes and falls through untouched.
        if method.selector.startswith('.cxx_'):
            continue
        offset = metadata.offset_of(method.address)
        if offset is None:
            continue
        words = [struct.unpack_from('<I', metadata._data, offset + i * 4)[0] for i in range(2)]
        empty = words[0] == _RET
        constant = None
        if words[1] == _RET:
            constant = _mov_immediate(words[0])
            if constant is None:
                constant = _orr_immediate(words[0])
        super_only = (method.selector == 'dealloc'
                      and _is_super_only(metadata, stubs, method.address))
        forwarded = _forwarded_send(metadata, stubs, classes, method.address)
        if not empty and constant is None and not super_only and forwarded is None:
            continue
        key = (method.class_name, method.kind, method.selector)
        found = bodies.get(key)
        if found is None:
            # A dealloc the binary leaves as nothing but the super call is one ARC writes itself,
            # and ARC forbids writing it by hand, so its absence from the tree is the correct
            # reconstruction rather than a gap.
            if super_only or (method.selector == 'dealloc' and empty):
                passed.append((method.address - IMAGE_BASE,
                               f'{method.class_name} dealloc: ARC writes it; correctly omitted'))
                continue
            skipped['no reconstruction located'] += 1
            continue
        path, line, body = found
        relative = method.address - IMAGE_BASE
        if super_only:
            extra = _meaningful(body)
            if extra:
                findings.append(
                    f'{path}:{line} -[{method.class_name} dealloc] is only the super call at '
                    f'{relative:#x} but the reconstruction does {len(extra)} thing(s)')
                continue
            passed.append((relative, f'{method.class_name} dealloc: super call only'))
            continue
        if forwarded is not None:
            sent = _sent_send(body)
            if sent is None:
                skipped['forward, but the reconstruction is not a lone send'] += 1
                continue
            receiver, selector, argument = forwarded
            got_receiver, got_selector, got_argument = sent
            if (got_receiver, got_selector) != (receiver, selector):
                findings.append(
                    f'{path}:{line} {method.kind}[{method.class_name} {method.selector}] sends '
                    f'{selector} to {receiver} at {relative:#x}, reconstruction sends '
                    f'{got_selector} to {got_receiver}')
                continue
            if isinstance(argument, str):
                # The reconstruction has to pass the same text. It may spell it as a literal or
                # name a file constant holding it, and either is compared on the text itself.
                spelled_text = None
                if got_argument is not None:
                    spelled_text = _spelled_string(got_argument, path)
                if spelled_text != argument:
                    findings.append(
                        f'{path}:{line} {method.kind}[{method.class_name} {method.selector}] '
                        f'passes "{argument}" at {relative:#x}, reconstruction passes '
                        f'{got_argument}')
                    continue
            elif argument is not None:
                if got_argument is None or not _matches(argument, got_argument,
                                                        file_constants(path)):
                    findings.append(
                        f'{path}:{line} {method.kind}[{method.class_name} {method.selector}] '
                        f'passes {argument} at {relative:#x}, reconstruction passes '
                        f'{got_argument}')
                    continue
            passed.append((relative, f'{method.class_name} {method.selector}: sends {selector} '
                                     f'to {receiver}'))
            continue
        if empty:
            extra = _meaningful(body)
            if extra:
                findings.append(
                    f'{path}:{line} {method.kind}[{method.class_name} {method.selector}] is '
                    f'empty at {relative:#x} but the reconstruction does {len(extra)} '
                    f'thing(s): {extra[0].strip()[:50]}')
                continue
            passed.append((relative, f'{method.class_name} {method.selector}: empty'))
            continue
        spelled = _returned_constant(body)
        if spelled is None:
            skipped['reconstruction is not a lone return'] += 1
            continue
        if not _matches(constant, spelled, file_constants(path)):
            findings.append(
                f'{path}:{line} {method.kind}[{method.class_name} {method.selector}] returns '
                f'{constant} at {relative:#x}, reconstruction returns {spelled}')
            continue
        passed.append((relative, f'{method.class_name} {method.selector}: returns {constant}'))
    header = ['# Trivially-shaped methods verified against their instructions by',
              '# tools/objc_verify_trivial.py. Each either does nothing, and its reconstruction',
              '# does nothing either, or returns a constant its reconstruction also returns.']
    Path(OUTPUT).write_text('\n'.join(header + [f'{a:#x} {w}' for a, w in sorted(passed)]) + '\n')
    print(f'trivial methods verified: {len(passed)}')
    print(f'wrote {OUTPUT}')
    for reason, count in skipped.most_common():
        print(f'  skipped: {reason} ({count})')
    if findings:
        print(f'\nDEFECTS ({len(findings)}):', file=sys.stderr)
        for finding in findings:
            print(f'  {finding}', file=sys.stderr)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
