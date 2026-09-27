#!/usr/bin/env python3
"""Summarize carry-policy subsets and hypothetical selection from retained objects."""

import argparse
import gzip
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('census', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    data = args.census.read_bytes()
    rows = json.loads(gzip.decompress(data))
    policies = ('off', 'always', 'gated')
    paired = [r for r in rows if all('text' in r[p] for p in policies)]
    for row in paired:
        if any(set(row[p]['functions']) != set(row['off']['functions'])
               for p in policies):
            raise ValueError('Function sets differ: ' + row['source'])
    modes = []
    for mode in sorted({r['mode'] for r in paired}):
        subset = [r for r in paired if r['mode'] == mode]
        entry = {'mode': mode, 'configurations': len(subset)}
        for policy in ('always', 'gated'):
            growth = []
            for row in subset:
                for function, before in row['off']['functions'].items():
                    delta = row[policy]['functions'][function] - before
                    if delta > 0:
                        growth.append({
                            'source': row['source'], 'optimization': row['optimization'],
                            'function': function, 'bytes': delta,
                            'object_delta': row[policy]['text'] - row['off']['text']})
            entry[policy] = {
                'text_saving': sum(r['off']['text'] - r[policy]['text'] for r in subset),
                'growing_objects': sum(r[policy]['text'] > r['off']['text'] for r in subset),
                'growing_functions': len(growth), 'function_growth': growth}
        modes.append(entry)
    selections = []
    for choices in (('off', 'always'), policies):
        selections.append({
            'policies': choices,
            'whole_object_text_saving': sum(
                r['off']['text'] - min(r[p]['text'] for p in choices) for r in paired),
            'whole_object_growth': 0,
            'hypothetical_function_text_saving': sum(
                r['off']['functions'][f] - min(r[p]['functions'][f] for p in choices)
                for r in paired for f in r['off']['functions'])})
    output = {
        'schema': 1,
        'attribution': 'OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, xhigh '
                       'reasoning effort; verified session 01a0e126-2178-79f3-adba-51b951fb1f96',
        'source': {'path': args.census.as_posix(), 'sha256': hashlib.sha256(data).hexdigest()},
        'scope': 'Arithmetic on retained object and function sizes; no new compiler or runtime runs. '
                 'Configurations are not independent programs. Function minima are hypothetical: '
                 'cross-function allocation and linked layout have not been recomputed.',
        'configurations': len(rows), 'paired': len(paired), 'modes': modes,
        'selection': selections}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2) + '\n')


if __name__ == '__main__':
    main()
