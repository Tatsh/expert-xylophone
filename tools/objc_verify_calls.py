#!/usr/bin/env python3
"""Triage the methods still to be read, by comparing their call sets with the binary's.

Every screen defect found in this tree so far has had one shape: the reconstruction sends a
different message than the binary does, or names a selector nothing implements. That is visible
without reading a single constant, by recovering the selectors reaching ``objc_msgSend`` and
comparing them with the sends the reconstruction performs.

The source side is parsed with a bracket-depth stack rather than a regular expression. That matters:
a regular expression matches the innermost bracket pair, so ``[a foo:[b bar]]`` reads as one send
instead of two and every nested send is miscounted. Closing order is also evaluation order, so the
stack yields the sequence the binary should produce. Dot syntax counts too, since the rules require
it wherever possible, so ``self.itemSize = x`` is a send of ``setItemSize:``.

**This is triage, not verification, and its output must not be read as a pass mark.** It is listed
here as advisory because the source side cannot be parsed soundly without an Objective-C front end:
subscripting (`self.layouts[i]`, which the rules require) compiles to `objectAtIndexedSubscript:`,
and chained access (`self.button.enabled = x`) sends the intermediate getter too, and neither is
recovered from the text by these heuristics. On classes already read by hand it produced roughly one
false positive for every true one, which is why nothing it reports is recorded as verified.

What it is good for is ordering the work. A method whose call set differs is a better place to start
reading than one that agrees, and two of its four reports on hand-read classes were real: a
deliberate ENABLE_PATCHES deviation, and a genuine difference of idiom.

This is disassembly, not decompiler output: the instruction words are decoded here, from the bytes.

Usage: ``tools/objc_verify_calls.py <binary> [class] [--report]``
"""
import argparse
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from objc_update import IMAGE_BASE, Metadata  # noqa: E402
from objc_verify_accessors import (AccessorCheck, _adrp, _branch_target,  # noqa: E402
                                  _is_branch_with_link)
from objc_verify_trivial import source_bodies  # noqa: E402

OUTPUT = 'tools/objc_call_triage.txt'
_RET = 0xD65F03C0
_SEND_STUBS = ('_objc_msgSend', '_objc_msgSendSuper2')
# Sends the compiler emits that have no counterpart in the source text.
# Sends with no counterpart in the source text: the compiler emits respondsToSelector:
# checks itself, and `[SomeClass class]` on a class object folds away to the class
# reference it already has.
_IMPLICIT = ('respondsToSelector:', 'class')
_LIMIT = 6000


def _ldr_imm64(word: int) -> tuple[int, int, int] | None:
    """Decode a 64-bit LDR with an unsigned immediate: its offset, base, and destination."""
    if (word & 0xFFC00000) != 0xF9400000:
        return None
    return (((word >> 10) & 0xFFF) * 8, (word >> 5) & 0x1F, word & 0x1F)


def binary_selectors(metadata: Metadata, stubs: dict[int, str], address: int,
                     end: int) -> tuple[list[str], int]:
    """
    Recover the selectors a method sends, in order, by tracking what reaches ``x1``.

    The scan stops at ``end``, the next method's address, because a body ending in a tail-called
    send has no return to stop at and would otherwise read the next method's sends as its own.
    """
    offset = metadata.offset_of(address)
    if offset is None:
        return [], 1
    pages: dict[int, int] = {}
    holding: dict[int, str] = {}
    out: list[str] = []
    untracked = 0
    for index in range(min(_LIMIT, max(1, (end - address) // 4))):
        word = struct.unpack_from('<I', metadata._data, offset + index * 4)[0]
        here = address + index * 4
        page = _adrp(word, here)
        if page is not None:
            pages[word & 0x1F] = page
            continue
        # A selector is often loaded once and moved into x1 per call, especially inside a loop, so
        # register-to-register moves have to propagate what a register holds or the send looks
        # unnamed.
        if (word & 0xFFE0FFE0) == 0xAA0003E0:
            source_register = (word >> 16) & 0x1F
            destination = word & 0x1F
            if source_register in holding:
                holding[destination] = holding[source_register]
            else:
                holding.pop(destination, None)
            continue
        load = _ldr_imm64(word)
        if load is not None:
            byte_offset, base, destination = load
            if base in pages:
                pointer = metadata._word(pages[base] + byte_offset)
                name = metadata.string_at(pointer) if pointer else ''
                holding[destination] = name
            else:
                holding.pop(destination, None)
            continue
        if _is_branch_with_link(word) or (word & 0xFC000000) == 0x14000000:
            symbol = stubs.get(_branch_target(word, here), '')
            if symbol in _SEND_STUBS:
                name = holding.get(1)
                if name:
                    out.append(name)
                else:
                    untracked += 1
            continue
        if word == _RET:
            break
    return out, untracked


def _strip(text: str) -> str:
    """Remove comments and string literals, keeping length-neutral placeholders."""
    out: list[str] = []
    index = 0
    length = len(text)
    while index < length:
        two = text[index:index + 2]
        if two == '//':
            while index < length and text[index] != '\n':
                index += 1
            continue
        if two == '/*':
            index += 2
            while index < length and text[index:index + 2] != '*/':
                index += 1
            index += 2
            continue
        char = text[index]
        if char in '"\'':
            quote = char
            index += 1
            while index < length and text[index] != quote:
                index += 2 if text[index] == '\\' else 1
            index += 1
            out.append('""')
            continue
        out.append(char)
        index += 1
    return ''.join(out)


def source_selectors(body: list[str]) -> list[str]:
    """
    Recover the selectors a reconstructed body sends, in evaluation order.

    Bracketed sends are matched with a stack, so a send nested inside another is counted and ordered
    correctly: the inner one closes first, which is also when it is evaluated.
    """
    text = _strip('\n'.join(body))
    out: list[str] = []
    stack: list[int] = []
    for index, char in enumerate(text):
        if char == '[':
            stack.append(index)
            continue
        if char != ']' or not stack:
            continue
        inner = text[stack.pop() + 1:index]
        # Drop any nested send already counted, so this one's keywords are only its own.
        flattened = re.sub(r'\[[^\[\]]*\]', ' ', inner)
        while '[' in flattened:
            flattened = re.sub(r'\[[^\[\]]*\]', ' ', flattened)
        if ':' in flattened:
            keywords = re.findall(r'(\w+)\s*:', flattened)
            if keywords:
                out.append(''.join(f'{k}:' for k in keywords))
        else:
            parts = flattened.split()
            if len(parts) == 2 and re.fullmatch(r'\w+', parts[1]):
                out.append(parts[1])
    for match in re.finditer(r'(\w+)(?:\.\w+)*\.(\w+)\s*(=(?!=))?', text):
        receiver, member, assigned = match.group(1), match.group(2), match.group(3)
        if receiver in ('self', 'super') or receiver[:1].islower():
            out.append(f'set{member[:1].upper()}{member[1:]}:' if assigned else member)
    return out


def main(argv=None) -> int:
    """Compare each method's send sequence with its reconstruction's, and record agreement."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, help='the shipped Mach-O from inside the .ipa')
    parser.add_argument('only', nargs='?', help='restrict to one class, for spot-checking')
    parser.add_argument('--report', action='store_true', help='print each disagreement')
    args = parser.parse_args(argv)
    if not args.binary.is_file():
        print(f'error: no such binary: {args.binary}', file=sys.stderr)
        return 1
    metadata = Metadata(args.binary)
    stubs = AccessorCheck(metadata)._stubs
    bodies = source_bodies()
    methods = metadata.methods()
    starts = sorted({m.address for m in methods})
    following = dict(zip(starts, starts[1:]))
    passed: list[tuple[int, str]] = []
    reports: list[str] = []
    unread = 0
    for method in methods:
        if method.accessor or method.selector.startswith('.cxx_'):
            continue
        if args.only and method.class_name != args.only:
            continue
        found = bodies.get((method.class_name, method.kind, method.selector))
        if found is None:
            continue
        path, line, body = found
        end = following.get(method.address, method.address + 4 * _LIMIT)
        expected, untracked = binary_selectors(metadata, stubs, method.address, end)
        if untracked or not expected:
            unread += 1
            continue
        actual = source_selectors(body)
        # Sets, not counts. How many times a selector is sent is not a reliable signal: the
        # compiler may re-send a getter where the reconstruction caches it in a local, and the
        # reverse, both faithfully. What is reliable is whether a selector is sent at all, which is
        # the defect this catches — a message the binary sends and the reconstruction never does, or
        # one the reconstruction invents.
        wanted = {s for s in expected if s not in _IMPLICIT}
        got = {s for s in actual if s not in _IMPLICIT}
        if wanted == got:
            passed.append((method.address - IMAGE_BASE,
                           f'{method.class_name} {method.selector}: sends the same '
                           f'{len(wanted)} selector(s)'))
            continue
        missing = sorted(wanted - got)
        invented = sorted(got - wanted)
        reports.append(f'{path}:{line} {method.kind}[{method.class_name} {method.selector}] '
                       f'@{method.address - IMAGE_BASE:#x} binary {len(wanted)} source {len(got)}\n'
                       f'    only in binary: {missing[:5]}\n    only in source: {invented[:5]}')
    header = ['# Triage for the per-routine reading still to be done, from',
              '# tools/objc_verify_calls.py. These methods send a DIFFERENT set of selectors than',
              '# the binary does, so they are the ones to read first. Expect false positives: the',
              '# source side does not parse subscripting or chained dot access, both of which send',
              '# messages the text does not name. Nothing here is a verdict.']
    Path(OUTPUT).write_text('\n'.join(header + reports) + '\n')
    print(f'call sets agree: {len(passed)}, differ: {len(reports)}, not readable: {unread}')
    print(f'wrote {OUTPUT}')
    if args.report:
        for report in reports:
            print(report)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
