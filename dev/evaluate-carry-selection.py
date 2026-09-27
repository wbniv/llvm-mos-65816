#!/usr/bin/env python3
"""Apply the object-size selector to a frozen three-policy census."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import importlib.util
import json
from pathlib import Path
import shutil


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('census', type=Path)
    parser.add_argument('readobj', type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--jobs', type=int, default=3)
    parser.add_argument('--objects-dir', type=Path,
                        help='Directory containing extracted census object archives')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('selection', Path(__file__).with_name('select-carry-object.py'))
    selection = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(selection)
    rows = json.loads(gzip.decompress(args.census.read_bytes()))
    paired = [r for r in rows if all('text' in r[p] for p in ('off', 'always', 'gated'))]
    args.out.mkdir(parents=True, exist_ok=True)

    def evaluate(row):
        costs = {}
        paths = {}
        for policy in ('off', 'always', 'gated'):
            entry = row[policy]
            path = Path(entry['command'][entry['command'].index('-o') + 1])
            if args.objects_dir:
                path = args.objects_dir / path.name
            if selection.digest(path) != entry['object_sha256']:
                raise ValueError(f'Object identity mismatch: {path}')
            costs[policy] = selection.object_cost(args.readobj, path)
            paths[policy] = path
        result = {k: row[k] for k in ('source', 'mode', 'optimization')}
        result['costs'] = costs
        result['objects'] = {p: {'path': str(paths[p]), 'sha256': row[p]['object_sha256']} for p in paths}
        result['selected'] = selection.choose(costs)
        result['selected_file_only'] = selection.choose(costs, True)
        result['selected_file_only_off_always'] = selection.choose({p: costs[p] for p in ('off', 'always')}, True)
        result['selected_file_only_off_gated'] = selection.choose({p: costs[p] for p in ('off', 'gated')}, True)
        result['selected_off_always'] = selection.choose({p: costs[p] for p in ('off', 'always')})
        result['selected_off_gated'] = selection.choose({p: costs[p] for p in ('off', 'gated')})
        selected = result['selected']
        result['growing_functions'] = {fn: size - row['off']['functions'].get(fn, 0)
                                       for fn, size in row[selected]['functions'].items()
                                       if size > row['off']['functions'].get(fn, 0)}
        result['selected_sha256'] = row[selected]['object_sha256']
        name = '.'.join(row[k] for k in ('source', 'mode', 'optimization')).replace('/', '_')
        destination = args.out / (name + '.o')
        shutil.copyfile(paths[selected], destination)
        result['output'] = str(destination.resolve())
        return result

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(evaluate, paired))
    (args.out / 'report.json').write_text(json.dumps(results, indent=2) + '\n')
    summary = {'inputs': len(rows), 'paired': len(results), 'excluded_unpaired': len(rows) - len(results),
               'census_sha256': selection.digest(args.census), 'readobj_sha256': selection.digest(args.readobj),
               'growing_functions_three_way': sum(len(r['growing_functions']) for r in results)}
    for field in ('selected_off_always', 'selected_off_gated', 'selected', 'selected_file_only_off_always', 'selected_file_only_off_gated', 'selected_file_only'):
        summary[field] = {
            'choices': {p: sum(r[field] == p for r in results) for p in ('off', 'always', 'gated')},
            'file_byte_saving': sum(r['costs']['off']['file_bytes'] - r['costs'][r[field]]['file_bytes'] for r in results),
            'text_byte_saving': sum(r['costs']['off']['text_bytes'] - r['costs'][r[field]]['text_bytes'] for r in results),
            'growing_file_bytes': sum(r['costs'][r[field]]['file_bytes'] > r['costs']['off']['file_bytes'] for r in results),
            'growing_writable_bytes': sum(r['costs'][r[field]]['writable_bytes'] > r['costs']['off']['writable_bytes'] for r in results)}
    (args.out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
