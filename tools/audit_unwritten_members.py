#!/usr/bin/env python3
"""
Report class members that are read but never written anywhere in the tree.

This is the defect class behind two separate bugs, and nothing else catches it. A member declared
``= {}`` that no code ever assigns compiles cleanly, reads as a plausible zero, and satisfies both
``audit_ghidra_addresses.py`` (which checks that annotated addresses exist, not that fields are
populated) and ``audit_global_initialisers.py`` (which only looks at file-scope globals).

``NoteBornLayer::m_nCapacity`` was one. The binary sets it at the tail of the constructor, three
instructions past a member-init loop's closing branch, and the reconstruction stopped at the branch.
The batch was then built with capacity zero, which under ``NDEBUG`` did no visible harm until the
draw, where it surfaced as an unrelated-looking crash inside the GL driver. The earlier
``g_nVariantScreenHeight`` was the same shape at global scope, and put the play-field camera 512
points out.

A member is treated as written when it is assigned, incremented, subscript-assigned, bound to a
reference, or has its address taken. Members whose declaration carries a real initialiser are fine
by definition, so only ``= {}`` and bare declarations are considered. Aggregates that only ever get
filled through ``memcpy`` or a helper taking ``&member`` are covered by the address-taken rule.

Findings are suspicions, not proof: a member may legitimately be write-once from a constructor this
scan cannot see, or genuinely unused. Read the binary before acting on one.
"""

import argparse
import re
import sys
from pathlib import Path

# `int m_nCapacity = {};` or `int m_nCapacity;`, capturing the name. Anything with a real
# initialiser is deliberately excluded: it already holds a chosen value.
_MEMBER = re.compile(r'^\s*(?:static\s+)?(?:const\s+)?[A-Za-z_][\w:<>,\s*&]*?\b(m_\w+)\s*'
                     r'(?:\[[^\]]*\])?\s*(?:=\s*\{\s*\})?\s*;', re.M)

_SOURCE_SUFFIXES = ('.mm', '.cpp', '.m', '.c')
_HEADER_SUFFIXES = ('.h',)


def declared_members(root):
    """Every `m_`-prefixed member declared with no value, and where it was declared."""
    found = {}
    for path in sorted(root.rglob('*')):
        if path.suffix not in _HEADER_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        names = set(_MEMBER.findall(text))
        if names:
            found[path] = names
    return found


def sibling_sources(header):
    """The implementation files that belong to a header, by the project's one-class-per-file rule."""
    return [header.with_suffix(suffix) for suffix in _SOURCE_SUFFIXES
            if header.with_suffix(suffix).exists()]


def _write_patterns():
    """Every spelling that counts as writing a member."""
    return (
        # `m_x =` and friends. The negative lookahead skips the declaration's own `= {}`, which
        # would otherwise make every zero-initialised member look written where it is declared.
        re.compile(r'\b(m_\w+)\s*(?:\[[^\]]*\]|\.\w+|->\w+)*\s*'
                   r'(?:[-+*/|&^]?=(?!=)(?!\s*\{\s*\}\s*;)|<<=|>>=)'),
        re.compile(r'(?:\+\+|--)\s*(m_\w+)'),
        re.compile(r'\b(m_\w+)\s*(?:\+\+|--)'),
        re.compile(r'&\s*(m_\w+)\b'),
        # A range-for binding a non-const reference writes through it: `for (T &r : m_a)`.
        re.compile(r'for\s*\([^)]*&[^)]*:\s*(m_\w+)\s*\)'),
        # Passed to something that fills it, e.g. `std::memcpy(m_a, ...)` or `Fill(m_a)`.
        re.compile(r'\(\s*(m_\w+)\s*,'),
    )


def written_in(paths):
    """Every member name assigned, mutated, or address-taken in the given files."""
    written = set()
    for path in paths:
        try:
            text = path.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        for pattern in _write_patterns():
            written.update(pattern.findall(text))
    return written


def read_in(paths):
    """Every member name appearing at all in the given files."""
    seen = set()
    name = re.compile(r'\b(m_\w+)\b')
    for path in paths:
        try:
            seen.update(name.findall(path.read_text(encoding='utf-8')))
        except (OSError, UnicodeDecodeError):
            continue
    return seen


def main(argv=None):
    """Run the scan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('Project'))
    arguments = parser.parse_args(argv)

    findings = []
    total = 0
    for header, names in sorted(declared_members(arguments.root).items()):
        sources = sibling_sources(header)
        if not sources:
            continue
        scope = sources + [header]
        written = written_in(scope)
        used = read_in(sources)
        for name in sorted(names):
            total += 1
            # Only members something actually reads matter; an entirely unused one is dead weight,
            # not a value silently defaulting to zero underneath working code.
            if name in written or name not in used:
                continue
            findings.append(f'{header.relative_to(arguments.root.parent)}: {name} is read but '
                            f'never assigned in its own class')

    print(f'zero-initialised members: {total} declared, {len(findings)} never written in their own class')
    for finding in findings:
        print(f'  {finding}')
    return min(len(findings), 125)


if __name__ == '__main__':
    raise SystemExit(main())
