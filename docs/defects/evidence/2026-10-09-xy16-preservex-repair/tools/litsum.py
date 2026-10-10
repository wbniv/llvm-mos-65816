import json, sys, collections
d = json.load(open(sys.argv[1]))
c = collections.Counter(t['code'] for t in d['tests'])
print(' '.join(f'{k}={v}' for k, v in sorted(c.items())))
for t in d['tests']:
    if t['code'] not in ('PASS', 'UNSUPPORTED', 'XFAIL'):
        print(t['code'], t['name'])
