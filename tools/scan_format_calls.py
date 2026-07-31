#!/usr/bin/env python3
"""Scan the reconstruction for two defect shapes that a decompile cannot show.

Ghidra renders a variadic ``objc_msgSend`` with only its fixed arguments, because the rest are
passed on the stack. A reconstruction written from that decompile silently drops arguments and
still compiles, so the loss is invisible in review. Both checks here target that failure.

``+[StoreUtil productIDForPackID:]`` is the worked example: it formatted a bare ``"%05d"`` where
the binary formats ``"%@%05d"`` over a prefix, so every StoreKit lookup queried an identifier no
product has.

The three checks catch progressively subtler forms:

1. A format call whose specifier count disagrees with its argument count.
2. A file-local string constant defined and never referenced. This found the missing
   ``itunes.apple.com`` host guard in ``+[StoreUtil affiliateParametersFromURL:]``.
3. A prefix constant that is parsed but never produced. Checks one and two both miss the
   product-id defect, because ``"%05d"`` is self-consistent and the prefixes *were* referenced —
   by the inverse mappings, which stripped a prefix the forward mappings never added. That
   round-trip asymmetry is the only shape that shows it.

Checks one and two gate the exit code. Check three is advisory, because most of what it finds is
correct: a consumer-side protocol parser has no producing side in this tree at all. The twelve
``applilink://`` scheme and query-key constants across ``RecommendCore``, ``RecommendAdAreaView``,
``RewardCore``, and ``RewardWebViewController`` are all of that kind, since the remote ad and
reward pages build those URLs and the app only reads them. Treat a hit as worth a look only where
this tree is also supposed to build the string.
"""
from __future__ import annotations

import pathlib
import re
import sys

SOURCE_ROOTS = ('Project', '3rdparty')
FORMAT_SELECTORS = re.compile(
    r'(?:stringWithFormat|initWithFormat|appendFormat|localizedStringWithFormat):')
STRING_LITERAL = r'@"(?:[^"\\]|\\.)*"'
LITERAL_BODY = re.compile(r'@"((?:[^"\\]|\\.)*)"')
# A run of adjacent literals is one string; clang-format wraps long formats across several lines.
ADJACENT_LITERALS = re.compile(r'\s*(?:\s*' + STRING_LITERAL + r')+')
STRING_CONSTANT = re.compile(r'static\s+NSString\s*\*\s*const\s+(\w+)\s*=\s*((?:\s*' +
                             STRING_LITERAL + r')+)\s*;')
CONVERSION_SPECIFIER = re.compile(
    r'%(?!%)[-+ #0-9.*]*(?:l{1,2}|h{1,2}|z|q)?[@dDiuUxXoOfeEgGcCsSpaAF]')


def _joined(text: str) -> str:
    return ''.join(LITERAL_BODY.findall(text))


def _string_constants(text: str) -> dict[str, str]:
    return {m.group(1): _joined(m.group(2)) for m in STRING_CONSTANT.finditer(text)}


def _bracket_argument(text: str) -> str:
    """Return the message arguments following a selector, up to its unmatched closing bracket."""
    depth, out = 0, []
    for char in text:
        if char == '[':
            depth += 1
        elif char == ']':
            if depth == 0:
                break
            depth -= 1
        out.append(char)
    return ''.join(out)


def _top_level_commas(text: str) -> int:
    depth, count = 0, 0
    for char in text:
        if char in '([{':
            depth += 1
        elif char in ')]}':
            depth -= 1
        elif char == ',' and depth == 0:
            count += 1
    return count


def _sources() -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    for root in SOURCE_ROOTS:
        found.extend(pathlib.Path(root).rglob('*.m'))
        found.extend(pathlib.Path(root).rglob('*.mm'))
    return sorted(found)


def check_format_arity() -> list[str]:
    """Report every format call whose specifier count disagrees with its argument count."""
    problems = []
    for path in _sources():
        text = path.read_text()
        constants = _string_constants(text)
        for match in FORMAT_SELECTORS.finditer(text):
            argument = _bracket_argument(text[match.end():match.end() + 2000])
            literal = ADJACENT_LITERALS.match(argument)
            if literal:
                fmt, rest = _joined(literal.group(0)), argument[literal.end():]
            else:
                named = re.match(r'\s*(\w+)\s*(?=,|$)', argument)
                if not named or named.group(1) not in constants:
                    continue
                fmt, rest = constants[named.group(1)], argument[named.end():]
            specifiers = len(CONVERSION_SPECIFIER.findall(fmt))
            supplied = _top_level_commas(rest)
            if specifiers != supplied:
                line = text[:match.start()].count('\n') + 1
                problems.append(f'{path}:{line}: {specifiers} specifier(s) but {supplied} '
                                f'argument(s): {fmt[:60]!r}')
    return problems


def check_unreferenced_constants() -> list[str]:
    """Report file-local string constants that are defined and never used."""
    problems = []
    for path in _sources():
        text = path.read_text()
        for match in STRING_CONSTANT.finditer(text):
            name = match.group(1)
            if len(re.findall(r'\b' + re.escape(name) + r'\b', text)) == 1:
                line = text[:match.start()].count('\n') + 1
                problems.append(f'{path}:{line}: {name} is defined and never referenced')
    return problems


def check_parsed_but_unproduced_prefixes() -> list[str]:
    """Report a prefix constant the tree strips but never emits.

    A constant reached through ``hasPrefix:`` or ``substringFromIndex:`` describes a string shape
    the code expects to receive. Something has to build that shape, so the same constant should
    also reach a format call or a concatenation. When it never does, the producing side is
    formatting without it.
    """
    problems = []
    for path in _sources():
        text = path.read_text()
        for name in _string_constants(text):
            escaped = re.escape(name)
            parses = re.search(r'(?:hasPrefix:|substringFromIndex:)\s*' + escaped + r'\b', text)
            produces = re.search(
                r'(?:Format:[^;]*?|stringByAppending\w*:\s*)\b' + escaped + r'\b', text, re.S)
            if parses and not produces:
                line = text[:parses.start()].count('\n') + 1
                problems.append(f'{path}:{line}: {name} is stripped as a prefix but never '
                                f'emitted; the producing side may have dropped it')
    return problems


def main() -> int:
    arity = check_format_arity()
    unused = check_unreferenced_constants()
    asymmetric = check_parsed_but_unproduced_prefixes()
    for problem in arity + unused:
        print(problem)
    if asymmetric:
        print('Advisory, mostly consumer-side parsers with no producer in this tree:')
        for problem in asymmetric:
            print(f'  {problem}')
    if arity:
        print(f'{len(arity)} format call(s) disagree with their argument count.')
    if unused:
        print(f'{len(unused)} unreferenced string constant(s); each may mark a dropped argument.')
    if asymmetric:
        print(f'{len(asymmetric)} prefix(es) parsed but never produced (advisory).')
    if not (arity or unused):
        print('No format-arity or unreferenced-constant problems found.')
    return 1 if (arity or unused) else 0


if __name__ == '__main__':
    sys.exit(main())
