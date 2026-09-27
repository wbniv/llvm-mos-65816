#!/usr/bin/env python3
"""Summarize retained carry-cost trials, selection, timing and compilation cost."""

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import statistics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    hashes = {}

    def read(name):
        data = (args.evidence / name).read_bytes()
        hashes[name] = hashlib.sha256(data).hexdigest()
        return json.loads(gzip.decompress(data) if name.endswith('.gz') else data)

    screen = read('screen-summary.json')
    tradeoff = read('tradeoff-summary.json')
    selection = read('selection-summary.json')
    timing = read('timing.json.gz')
    conditional = read('tradeoff-timing.json.gz')
    baselines = {r['name']: r for r in read('linked-baselines.json')}
    compile_time = read('compile-time.json')
    compile_details = read('compile-time-details.json.gz')
    runtime = []
    for row in timing:
        name = row['case']['name']
        baseline = baselines[name]
        runs = {}
        for variant, value in row['runs'].items():
            file_bytes = sum(s['Size'] for s in value['linked_sections'] if s['Type']['Value'] != 8)
            runs[variant] = {
                'master_clocks': value['master_clocks'],
                'delta_clocks': value['master_clocks'] - baseline['master_clocks'],
                'delta_percent': 100 * (value['master_clocks'] / baseline['master_clocks'] - 1),
                'linked_file_bytes': file_bytes,
                'linked_delta_bytes': file_bytes - baseline['file_bytes'],
                'pass': value['pass'], 'repeat_identical': value['repeat_identical']}
        runtime.append({'name': name, 'baseline_master_clocks': baseline['master_clocks'], 'runs': runs})
    totals = {}
    for policy in ('off', 'always', 'select-always', 'select-gated', 'select-three'):
        totals[policy] = {metric: sum(row[policy][metric]['median'] for row in compile_time['cases'])
                          for metric in ('wall_seconds', 'cpu_seconds')}
    compiler_only = {}
    for policy in ('select-always', 'select-gated', 'select-three'):
        compiler_only[policy] = sum(statistics.median(
            sum(run['wall_seconds'] for run in row['record']['runs'].values())
            for row in compile_details if row['policy'] == policy and row['repeat'] >= 0
            and row['case']['source'] == case['source']) for case in compile_time['cases'])
    summary = {
        'scope': 'Screening is a biased 139-case sample. Full selection reuses verified frozen objects. Timing covers named inputs only.',
        'screen': screen, 'tradeoff_screen': tradeoff, 'selection': selection,
        'runtime': runtime, 'conditional_runtime': [
            {'name': r['case']['name'], 'master_clocks': r['runs']['gated:tradeoff:size']['master_clocks'],
             'baseline_master_clocks': baselines[r['case']['name']]['master_clocks']}
            for r in conditional],
        'runtime_summary': {
            'configurations': len(timing),
            'executions': 2 * sum(len(r['runs']) for r in timing + conditional),
            'selected_slower': sum(r['runs']['selection']['delta_clocks'] > 0 for r in runtime),
            'selected_linked_growth': sum(r['runs']['selection']['linked_delta_bytes'] > 0 for r in runtime),
            'all_oracles_and_repeats_pass': all(v['pass'] and v['repeat_identical'] for r in timing + conditional for v in r['runs'].values())},
        'compile_time': compile_time,
        'compile_time_sum_of_medians': totals,
        'compiler_subprocess_sum_of_wall_medians': compiler_only,
        'compile_wall_ratio_to_always': {p: totals[p]['wall_seconds'] / totals['always']['wall_seconds'] for p in totals},
        'input_sha256': hashes}
    args.output.write_text(json.dumps(summary, indent=2) + '\n')


if __name__ == '__main__':
    main()
