#!/usr/bin/env python3
"""Build an independent bsnes-jg core with instruction-boundary timing hooks."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('out', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    original = root / 'vendor/bsnes-jg'
    out = args.out.resolve()
    core = out / 'bsnes'
    out.mkdir(parents=True, exist_ok=True)
    shutil.copytree(original, core, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('objs', '.git'))
    source = core / 'src/cpu.cpp'
    before = source.read_text()
    needle = '  else if(!status.interruptPending) return instruction();'
    assert before.count(needle) == 1
    after = before.replace('namespace SuperFamicom {', '''extern "C" void cycle_probe_before(uint32_t, uint16_t, uint32_t);
extern "C" void cycle_probe_after(uint16_t, uint32_t);

namespace SuperFamicom {''', 1).replace(needle, '''  else if(!status.interruptPending) {
    cycle_probe_before(r.pc.d, r.s.w, counter.cpu);
    instruction();
    cycle_probe_after(r.s.w, counter.cpu);
    return;
  }''')
    source.write_text(after)
    commands = [
        ['make', '-C', str(core), 'ENABLE_STATIC=1', 'DISABLE_MODULE=1', '-j4'],
        ['g++', '-O2', '-std=c++11', '-I' + str(core / 'src'),
         str(root / 'dev/jgxcycles.cpp'), str(core / 'objs/libbsnes.a'),
         '-lsamplerate', '-lm', '-o', str(out / 'jgxcycles')]]
    with (out / 'build.log').open('w') as log:
        for command in commands:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    identity = {'commands': commands, 'original_cpu_sha256': hashlib.sha256(before.encode()).hexdigest(),
                'instrumented_cpu_sha256': hashlib.sha256(after.encode()).hexdigest(),
                'probe_sha256': hashlib.sha256((out / 'jgxcycles').read_bytes()).hexdigest(),
                'source_hashes': {str(p.relative_to(original)): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for folder in ['src', 'deps', 'mk']
                                  for p in sorted((original / folder).rglob('*')) if p.is_file()}}
    (out / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')


if __name__ == '__main__':
    main()
