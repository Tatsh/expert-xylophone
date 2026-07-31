#!/usr/bin/env python3
"""Check the reconstruction's constant-folded geometry for arithmetic that cannot be valid.

The frame-fit rule in ``.claude/rules/reconstruction.md`` asks that a recovered frame be confirmed
to sit inside its container, because a transposed ``{width, height}`` is individually plausible in
both orders and only the arithmetic distinguishes them. Most of that check needs a runtime parent
size and cannot be automated. A useful part of it can: where every argument folds to a number, some
results are wrong no matter what the parent turns out to be.

Two shapes are reported, and both have already occurred in this tree:

1. A negative width or height. ``-[RBCustomSelectCollectionView setupView]`` modelled a cap inset as
   ``25 - capInset``, which went negative on the wide layout.
2. Cap insets that cannot fit their own image, or are negative. ``-[RBMenuButton setupView:]`` took
   its right cap from the image's height, so the two horizontal caps exceeded the width whenever the
   image was taller than wide, leaving an image that draws as a flat block.

This is a floor, not the frame-fit check itself: it sees only fully constant expressions, so a frame
built from a runtime ``bounds`` is invisible to it. A clean run means the constant-folded subset is
sound, nothing more.
"""
from __future__ import annotations

import pathlib
import re
import sys

SOURCE_ROOTS = ('Project', '3rdparty')
NUMBER = re.compile(r'^-?\d+(?:\.\d+)?f?$')
CONSTANT = re.compile(
    r'(?:constexpr|static\s+const(?:expr)?)\s+(?:[\w:<>]+\s+)+?(\w+)\s*=\s*'
    r'(-?[\d.]+f?)\s*;')
RECT = re.compile(r'CGRectMake\s*\(')
INSETS = re.compile(r'UIEdgeInsetsMake\s*\(')
TERNARY = re.compile(r'\b(\w+)\s*=\s*[^;?]+\?\s*(\w+)\s*:\s*(\w+)\s*;')
# Bound the combinatorial fold; a frame built from more distinct branched names than this is
# reported as unfoldable rather than expanded.
MAX_BRANCHED_NAMES = 4


def _sources() -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    for root in SOURCE_ROOTS:
        found.extend(pathlib.Path(root).rglob('*.m'))
        found.extend(pathlib.Path(root).rglob('*.mm'))
    return sorted(found)


def _constants(text: str) -> dict[str, float]:
    values = {}
    for match in CONSTANT.finditer(text):
        try:
            values[match.group(1)] = float(match.group(2).rstrip('f'))
        except ValueError:
            continue
    return values


def _split_arguments(text: str, start: int) -> tuple[list[str], int] | None:
    """Split the comma-separated arguments of a call whose '(' is at `start`."""
    depth, current, args = 0, [], []
    for i in range(start, len(text)):
        char = text[i]
        if char in '([':
            depth += 1
            if depth == 1:
                continue
        elif char in ')]':
            depth -= 1
            if depth == 0:
                args.append(''.join(current).strip())
                return args, i
        if depth == 1 and char == ',':
            args.append(''.join(current).strip())
            current = []
            continue
        current.append(char)
    return None


def _branch_locals(text: str, constants: dict[str, float]) -> dict[str, list[float]]:
    """Map a local assigned from a two-armed ternary over constants to both of its values.

    This is the codebase's dominant layout idiom — ``wideFont ? kFooWide : kFooNarrow`` — and a
    defect usually lives in one arm only, so both have to be folded. Without this the check misses
    the very shape it exists to find.
    """
    branched: dict[str, list[float]] = {}
    for match in TERNARY.finditer(text):
        name, first, second = match.group(1), match.group(2), match.group(3)
        values = [constants.get(first), constants.get(second)]
        if all(v is not None for v in values):
            branched[name] = sorted({values[0], values[1]})
    return branched


def _fold_all(expression: str, constants: dict[str, float],
              branched: dict[str, list[float]]) -> list[float] | None:
    """Every value an expression can take, or None if it is not fully constant.

    A name bound to a ternary contributes both of its arms, so the caller sees each reachable
    result rather than one arbitrary arm.
    """
    tokens = re.findall(r'[A-Za-z_]\w*|-?\d+\.?\d*f?|[-+*/()]', expression)
    if ''.join(tokens).replace(' ', '') != expression.replace(' ', ''):
        return None
    variable = [t for t in tokens if t in branched]
    if len(set(variable)) > MAX_BRANCHED_NAMES:
        return None
    choices: list[list[float]] = [branched[n] for n in dict.fromkeys(variable)]
    names = list(dict.fromkeys(variable))
    results = []
    for combination in _product(choices):
        binding = dict(zip(names, combination))
        rebuilt = []
        for token in tokens:
            if NUMBER.match(token):
                rebuilt.append(token.rstrip('f'))
            elif token in '+-*/()':
                rebuilt.append(token)
            elif token in binding:
                rebuilt.append(repr(binding[token]))
            elif token in constants:
                rebuilt.append(repr(constants[token]))
            else:
                return None
        try:
            results.append(float(eval(''.join(rebuilt), {'__builtins__': {}}, {})))  # noqa: S307
        except (SyntaxError, ZeroDivisionError, TypeError, NameError):
            return None
    return results or None


def _product(choices: list[list[float]]) -> list[tuple[float, ...]]:
    combinations: list[tuple[float, ...]] = [()]
    for options in choices:
        combinations = [c + (o,) for c in combinations for o in options]
    return combinations


def check_negative_extents() -> list[str]:
    problems = []
    for path in _sources():
        text = path.read_text()
        constants = _constants(text)
        branched = _branch_locals(text, constants)
        for match in RECT.finditer(text):
            split = _split_arguments(text, match.end() - 1)
            if not split or len(split[0]) != 4:
                continue
            line = text[:match.start()].count('\n') + 1
            for name, index in (('width', 2), ('height', 3)):
                values = _fold_all(split[0][index], constants, branched)
                for value in values or []:
                    if value < 0:
                        problems.append(
                            f'{path}:{line}: CGRectMake {name} folds to {value:g}')
    return problems


def check_cap_insets() -> list[str]:
    problems = []
    for path in _sources():
        text = path.read_text()
        constants = _constants(text)
        branched = _branch_locals(text, constants)
        for match in INSETS.finditer(text):
            split = _split_arguments(text, match.end() - 1)
            if not split or len(split[0]) != 4:
                continue
            line = text[:match.start()].count('\n') + 1
            names = ('top', 'left', 'bottom', 'right')
            for name, argument in zip(names, split[0]):
                for value in _fold_all(argument, constants, branched) or []:
                    if value < 0:
                        problems.append(
                            f'{path}:{line}: UIEdgeInsetsMake {name} folds to {value:g}')
    return problems


def main() -> int:
    negative = check_negative_extents()
    insets = check_cap_insets()
    for problem in negative + insets:
        print(problem)
    if not (negative or insets):
        print('No negative constant-folded extents or cap insets found.')
    else:
        print(f'{len(negative) + len(insets)} problem(s).')
    return 1 if (negative or insets) else 0


if __name__ == '__main__':
    sys.exit(main())
