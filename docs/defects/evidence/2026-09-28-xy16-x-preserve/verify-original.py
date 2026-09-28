#!/usr/bin/env python3
"""Build the preserved C input and retain both emulator assertions."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

root = Path('/work')
os.chdir(root)
out = root / 'docs/defects/evidence/2026-09-28-xy16-x-preserve'
tool = root / 'build/xy16-x-preserve/candidate-install/bin'
source = root / 'docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/vlastack_sim.c'
rom, mapfile = out / 'candidate.sfc', out / 'candidate.map'
commands = []

def run(command, name):
    result = subprocess.run([str(x) for x in command], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (out / (name + '.log')).write_text(result.stdout)
    commands.append({'command': [str(x) for x in command], 'exit_code': result.returncode,
                     'log': str((out / (name + '.log')).relative_to(root))})
    print(name, result.returncode, flush=True)
    return result.returncode

status = run([tool / 'mos-clang', '--config', root / 'build/install/bin/mos-snes.cfg',
              '-mcpu=mosw65816', '-Xclang', '-target-feature', '-Xclang', '+mos-xy16',
              '-Os', '-mllvm', '-mos-carry-sched=always', '-Wl,-mllvm,-mos-carry-sched=always',
              '-Wl,--save-temps', '-Wl,-Map=' + str(mapfile), '-o', rom, source], 'candidate-build')
if not status:
    status |= run(['python3', root / 'tools/snes-checksum.py', rom], 'candidate-checksum')
    status |= run([root / 'build/jgxcheck', rom, root / 'vendor/bsnes-jg/Database',
                   '0x200', '2', '0xD77B', '1200'], 'candidate-bsnes')
    status |= run(['bash', '-c', 'source dev/_emu.sh; require_bios; '
                   'SMOKE_SETTLE=1200 SMOKE_SECONDS=25 run_assert '
                   + str(rom) + ' ' + str(mapfile) + ' corpus_result 0xD77B'], 'candidate-mame')
identity = {}
for path in [tool / 'clang-23', tool / 'lld', tool / 'llc', rom, source,
             root / 'build/jgxcheck', Path('/usr/games/mame')]:
    if path.exists():
        identity[str(path)] = hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()
(out / 'candidate-run.json').write_text(json.dumps({'commands': commands, 'sha256': identity,
                                                  'exit_code': status}, indent=2) + '\n')
raise SystemExit(status)
