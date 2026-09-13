#!/usr/bin/env python3
"""Reject common historical narratives in newly staged code/test comments."""

import re
import subprocess
import sys
from pathlib import Path


HISTORY = re.compile(
    r"\b(?:before|prior to|after) (?:the |this |our )?(?:fix|change|patch)\b|"
    r"\b(?:previously|formerly|historically)\b|"
    r"\bused to\b|\bin the (?:old|previous|original) (?:code|implementation|version)\b|"
    r"\b(?:old|previous|original) (?:implementation|code|version)\b|"
    r"\b(?:was|were) (?:broken|buggy|incorrect)\b|"
    r"\b(?:reviewer|review feedback)\b",
    re.IGNORECASE,
)
C_STYLE = {'.c', '.h', '.cc', '.cpp', '.cxx', '.hpp', '.hh', '.inc', '.td',
           '.js', '.jsx', '.ts', '.tsx', '.rs', '.java', '.go', '.m', '.mm'}
HASH_STYLE = {'.py', '.sh', '.bash', '.cmake', '.yaml', '.yml', '.toml'}
ASM_STYLE = {'.ll', '.mir', '.s', '.asm'}
# Match quoted strings first so comment markers inside them are ignored.
C_TOKENS = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*.*?\*/', re.S)


def git(*args):
    return subprocess.check_output(['git', *args])


def comment_lines(path, text):
    """Map physical line numbers to comment text, keeping prose strings out."""
    suffix = Path(path).suffix.lower()
    result = {}
    if suffix in C_STYLE:
        for match in C_TOKENS.finditer(text):
            value = match.group()
            if not value.startswith(('//', '/*')):
                continue
            first = text.count('\n', 0, match.start()) + 1
            for offset, line in enumerate(value.splitlines()):
                result[first + offset] = line.strip(' /*\t')
    elif suffix in HASH_STYLE | ASM_STYLE or Path(path).name in {'Makefile', 'CMakeLists.txt', 'pre-commit'}:
        for number, line in enumerate(text.splitlines(), 1):
            # MIR embeds LLVM-style comments under its YAML body.
            marker = r'^\s*[#;](.*)' if suffix in ASM_STYLE else r'^\s*#(.*)'
            match = re.match(marker, line)
            if match:
                result[number] = match[1].strip()
    return result


def narratives(comments, changed):
    """Join adjacent comment lines so wrapped phrases are checked too."""
    groups = []
    for number, text in sorted(comments.items()):
        if not groups or groups[-1][-1][0] + 1 != number:
            groups.append([])
        groups[-1].append((number, text))
    for group in groups:
        prose = ' '.join(text for _, text in group)
        if any(number in changed for number, _ in group) and HISTORY.search(prose):
            yield next(number for number, _ in group if number in changed), prose


def patch_comments(text):
    """Read added source lines in a unified patch, retaining bundle line numbers."""
    result = {}
    target = ''
    in_hunk = False
    for number, line in enumerate(text.splitlines(), 1):
        if line.startswith('diff --git '):
            in_hunk = False
        elif line.startswith('+++ '):
            target = line[4:].removeprefix('b/')
        elif line.startswith('@@ '):
            in_hunk = True
        elif in_hunk and line.startswith('+'):
            payload = line[1:]
            parsed = comment_lines(target, payload)
            if parsed:
                result[number] = parsed.get(1, '')
            elif Path(target).suffix.lower() in C_STYLE and re.match(r'^\s*(?:/\*|\*)', payload):
                result[number] = payload.strip(' /*\t')
    return result


def added_lines(path):
    diff = git('diff', '--cached', '--no-ext-diff', '--no-textconv', '--unified=0', '--', path).decode(errors='replace')
    added = set()
    number = None
    for line in diff.splitlines():
        hunk = re.match(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@', line)
        if hunk:
            number = int(hunk[1])
        elif number is not None:
            if line.startswith('+'):
                added.add(number)
                number += 1
            elif line.startswith(' '):
                number += 1
    return added


def main():
    paths = git('diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z').decode().split('\0')
    failures = []
    for path in filter(None, paths):
        text = git('show', ':' + path).decode(errors='replace')
        comments = patch_comments(text) if Path(path).suffix in {'.patch', '.diff'} else comment_lines(path, text)
        failures.extend((path, number, prose) for number, prose in narratives(comments, added_lines(path)))
    for path, number, prose in failures:
        print(f'{path}:{number}: historical narrative in code comment: {prose}', file=sys.stderr)
    if failures:
        print('Describe the current invariant or test expectation. Move bug/fix history to the commit message or PR description.', file=sys.stderr)
        return 1
    print('Comment history: PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
