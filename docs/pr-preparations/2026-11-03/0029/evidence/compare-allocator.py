#!/usr/bin/env python3
"""Compare retained spill streams and assignment-only instruction bodies."""
import os
import json
from pathlib import Path
import re

root = Path(os.environ.get('REVIEW_ROOT', str(Path(__file__).resolve().parent))) / 'evidence'
comparisons = []
for source, target in [('main', 'pr627'), ('pr627', 'pr628')]:
    baseline = root / ('allocator-' + source)
    candidate = root / ('allocator-' + target)
    for p in sorted(baseline.glob('*-spill.mir')):
        q = candidate / p.name
        comparisons.append({'from': source, 'to': target, 'file': p.name,
                            'identical_spill_mir': p.read_bytes() == q.read_bytes()})
    p, q = baseline / 'undef-normalize.mir', candidate / 'undef-normalize.mir'
    comparisons.append({'from': source, 'to': target, 'file': p.name,
                        'identical_undef_mir': p.read_bytes() == q.read_bytes()})

for p in sorted((root / 'allocator-pr628').glob('*-spill.mir')):
    q = p.with_name(p.name.replace('-spill.mir', '-assign.mir'))
    def body(path):
        return re.split(r'^body:\s*\|\s*$', path.read_text(), flags=re.M)[1]
    comparisons.append({'from': p.name, 'to': q.name,
                        'identical_instruction_body': body(p) == body(q)})

checks = [v for row in comparisons for k, v in row.items() if k.startswith('identical_')]
assert len(checks) == 50, len(checks)
result = {'comparisons': comparisons, 'all_identical': all(checks)}
(root / 'allocator-comparison.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'comparisons': len(checks), 'all_identical': all(checks)}))
raise SystemExit(not all(checks))
