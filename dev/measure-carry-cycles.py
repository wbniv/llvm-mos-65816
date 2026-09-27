#!/usr/bin/env python3
"""Time preserved carry-scheduler ROMs and growing census objects in bsnes-jg."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import threading


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('preserved', type=Path)
    parser.add_argument('probe', type=Path)
    parser.add_argument('out', type=Path)
    parser.add_argument('--jobs', type=int, default=3)
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    old = args.preserved.resolve()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    tool = old / 'build/llvm-mos-install/bin'
    evidence = root / 'docs/defects/evidence/2026-09-26-mos-carry-scheduling'
    identity = json.loads((evidence / 'candidate-identity.json').read_text())
    for name in ['clang-23', 'lld', 'llvm-objdump']:
        assert digest(tool / name) == identity['tools'][name], name
    commands = (json.loads((out / 'commands.json').read_text())
                if args.resume and (out / 'commands.json').exists() else [])
    lock = threading.Lock()

    def run(command, name):
        command = [str(v) for v in command]
        process = subprocess.run(command, capture_output=True, text=True, timeout=300)
        (out / (name + '.log')).write_text(process.stdout + process.stderr)
        with lock:
            commands.append({'command': command, 'exit_code': process.returncode,
                             'log': name + '.log'})
            (out / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
        if process.returncode:
            raise RuntimeError(name + ': ' + process.stderr[-1500:])
        return process.stdout

    def symbols(elf, name):
        text = run([tool / 'llvm-objdump', '-t', elf], name + '-symbols')
        return {p[-1]: (int(p[0], 16), int(p[-2], 16))
                for line in text.splitlines() if len(p := line.split()) >= 5
                and re.fullmatch('[0-9a-f]{8}', p[0])}

    oracles = {}
    for name in ['lsystem', 'spiro', 'dctbloom', 'avalanche', 'bf-vm', 'rotkal', 'seqvm']:
        exe = out / (name + '-oracle')
        run(['cc', '-O2', '-I' + str(old / 'examples/65816'),
             old / ('tools/' + name + '-sim.c'), '-o', exe], name + '-host-build')
        text = run([exe], name + '-host-run')
        oracles[name] = int(re.findall(r'0x[0-9a-fA-F]+', text)[-1], 16)

    results = (json.loads((out / 'results.json').read_text())
               if args.resume and (out / 'results.json').exists() else [])
    completed = {row['name'] for row in results}

    def measure(rom, name, function, stop, expected, count):
        syms = symbols(Path(str(rom) + '.elf'), name)
        start, size = syms[function]
        offset, length = syms['corpus_result']
        command = [args.probe.resolve(), rom, root / 'vendor/bsnes-jg/Database',
                   hex(start), hex(start + size), hex(stop), hex(offset), length,
                   hex(expected), 2000, count]
        runs = [json.loads(run(command, name + '-timing-' + str(k))) for k in range(2)]
        assert runs[0] == runs[1], name + ' is not deterministic'
        assert runs[0]['pass']
        dis = run([tool / 'llvm-objdump', '-d', Path(str(rom) + '.elf')], name + '-disassembly')
        return {'rom_sha256': digest(rom), 'function': function, 'start': start,
                'end': start + size, 'stop': stop, 'sample_count': count,
                'inclusive_master_clocks': sum(runs[0]['samples']),
                'exclusive_master_clocks': runs[0]['exclusive_master_clocks'],
                'instructions': runs[0]['instructions'], 'samples': runs[0]['samples'],
                'repeat_identical': True, 'expected': expected,
                'log': name + '-timing-0.log'}

    def save(row):
        a, b = row['baseline'], row['candidate']
        row['percent_change'] = 100 * (b['inclusive_master_clocks'] / a['inclusive_master_clocks'] - 1)
        print(row['name'], a['inclusive_master_clocks'], b['inclusive_master_clocks'],
              round(row['percent_change'], 3), flush=True)
        with lock:
            results.append(row)
            (out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')

    original = old / 'build/carry-original-runtime-a16-driver'
    frozen_runs = json.loads((original / 'results.json').read_text())
    for shape, expected in [('sum', 0x7bf2e264), ('rot', 0xaf1d6a7d)]:
        for mode in ['a16', 'xy16']:
            row = {'name': shape + '-' + mode, 'optimization': 'Os', 'mode': mode,
                   'scope': '24 calls over six bank-boundary input triples'}
            if row['name'] in completed:
                continue
            for label in ['baseline', 'candidate']:
                name = shape + '-' + label + '-' + mode
                rom = original / (name + '.sfc')
                recorded = next(r for r in frozen_runs if r['shape'] == shape
                                and r['mode'] == mode and r['toolchain'] == label)
                assert digest(rom) == recorded['rom_sha256']
                row[label] = measure(rom, name, 'f', 0, expected, 24)
            save(row)

    growth = json.loads((evidence / 'growth-review.json').read_text())['rows']
    def measure_case(case):
        if case['mode'] == '6502':
            return
        base = Path(case['source']).stem
        family = {'rcundef2': 'lsystem', 'lsystem_sim': 'lsystem',
                  'spirograph': 'spiro', 'bf_vm_sim': 'bf-vm',
                  'rotkal_sim': 'rotkal', 'seqvm_sim': 'seqvm'}.get(base, base)
        expected = oracles[family]
        function, stop, count = 'main', 0xffffffff, 1
        scope = 'main entry through the oracle result store'
        if base == 'spirograph':
            function, stop, count = 'hud_update', 0, 1
            scope = 'first HUD update, including called helpers'
        if base == 'dctbloom':
            function, stop, count = 'fill_cell', 0, 128
            scope = '128 fill_cell calls for the first two 8x8 grids'
        stem = case['source'].replace('/', '_') + '.' + case['mode'] + '.' + case['optimization']
        if stem in completed:
            return
        row = {'name': stem, 'source': case['source'], 'optimization': case['optimization'],
               'mode': case['mode'], 'scope': scope, 'size_delta': case['delta']}
        for label, suffix in [('baseline', 'before'), ('candidate', 'after')]:
            name = stem + '.' + label
            obj = old / 'build' / case['census'] / (stem + '.' + suffix + '.o')
            frozen = out / (name + '.o')
            shutil.copyfile(obj, frozen)
            rom = out / (name + '.sfc')
            run([tool / 'mos-clang', '--config', old / 'build/install/bin/mos-snes.cfg',
                 '-mcpu=mosw65816', '-Os', '-fno-lto', frozen,
                 '-Wl,-Map=' + str(out / (name + '.map')), '-o', rom], name + '-link')
            run(['python3', root / 'tools/snes-checksum.py', rom], name + '-checksum')
            row[label] = measure(rom, name, function, stop, expected, count)
            row[label]['object_sha256'] = digest(frozen)
        save(row)
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        list(pool.map(measure_case, growth))
    (out / 'identity.json').write_text(json.dumps({
        'candidate_tools': identity, 'probe_sha256': digest(args.probe.resolve()),
        'oracles': oracles,
        'sdk_files': {str(p.relative_to(old / 'build/install')): digest(p)
                      for p in sorted((old / 'build/install').rglob('*')) if p.is_file()},
        'excluded': 'Two adapted 6502 configurations require an ordinary 6502 timing harness.'
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
