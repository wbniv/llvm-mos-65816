from pathlib import Path
import hashlib
import json
import subprocess

root = Path.cwd()
area = root / '.scratch/upstream-pin-2026-10-09'
source = area / 'source'
binary = area / 'build/bin'
logs = area / 'validation-complete'
logs.mkdir(exist_ok=True)
results = []

def run(name, command, input_bytes=None, source_file=None):
    result = subprocess.run(command, input=input_bytes, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (logs / (name + '.stdout')).write_bytes(result.stdout)
    (logs / (name + '.stderr')).write_bytes(result.stderr)
    record = {'name': name, 'command': [str(x) for x in command], 'exit_code': result.returncode}
    if source_file:
        record.update(source=str(source_file.relative_to(root)), source_sha256=hashlib.sha256(source_file.read_bytes()).hexdigest())
    results.append(record)
    print(name, result.returncode, flush=True)
    return result

run('mos-lit', [binary / 'llvm-lit', '-s', '-j4', source / 'llvm/test/CodeGen/MOS', source / 'llvm/test/MC/MOS'])
prefetch_inputs = [('upstream', source / 'clang/test/CodeGen/builtin-prefetch-arg-type.c'), ('retained', root / 'docs/pr-preparations/2026-10-09/pin-rebase/evidence/builtin-prefetch-int16.c')]
for label, test in prefetch_inputs:
    for triple in (['x86_64-pc-linux', 'msp430', 'avr', 'mos'] if label == 'upstream' else ['x86_64-pc-linux', 'msp430']):
        name = 'prefetch-' + label + '-' + triple
        ir = run(name, [binary / 'clang', '-cc1', '-triple', triple, '-emit-llvm', test, '-o', '-'], source_file=test)
        if not ir.returncode:
            run(name + '-checks', [binary / 'FileCheck', test], ir.stdout, test)

cases = [
    ('examples/snes/corpus/arith.c', False, False),
    ('examples/snes/corpus/globals.c', False, False),
    ('examples/65816/far-value-evidence/m1_bitint24.c', False, False),
    ('examples/65816/far_call.c', False, False),
    ('examples/65816/far_tail.c', False, False),
    ('examples/65816/far_near_call.c', False, False),
    ('examples/65816/far_indir.c', True, False),
    ('examples/65816/far_cast.c', True, False),
    ('examples/65816/packed24/packed24_table.c', True, False),
    ('examples/65816/farcc_imag32.c', True, True),
    ('examples/65816/far_fnptr.c', True, True),
]
for path, native_only, far_cc in cases:
    test = root / path
    for mode, features in [('default', []), ('a16', ['+mos-a16']), ('xy16', ['+mos-a16', '+mos-xy16'])]:
        if native_only and mode == 'default':
            continue
        if far_cc:
            features = features + ['+mos-farcc-imag32']
        for optimization in ['Os', 'O2']:
            name = test.stem + '-' + mode + '-' + optimization
            command = [binary / 'clang', '-target', 'mos', '-mcpu=mosw65816', '-ffreestanding', '-nostdinc', '-isystem', source / 'clang/lib/Headers', '-' + optimization, '-Werror=unknown-attributes', '-Werror=ignored-attributes', '-mllvm', '-verify-machineinstrs']
            for feature in features:
                command += ['-Xclang', '-target-feature', '-Xclang', feature]
            result = run(name, command + ['-c', test, '-o', logs / (name + '.o')], source_file=test)
            if not result.returncode:
                results[-1]['object_sha256'] = hashlib.sha256((logs / (name + '.o')).read_bytes()).hexdigest()
            if result.returncode:
                run(name + '-preprocessed', command + ['-E', test, '-o', logs / (name + '.i')], source_file=test)

identities = {}
for tool in ['llc', 'opt', 'llvm-mc', 'clang', 'lld', 'FileCheck']:
    path = binary / tool
    version_args = ['-flavor', 'gnu', '--version'] if tool == 'lld' else ['--version']
    identities[tool] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'version': subprocess.check_output([path, *version_args], text=True)}
(logs / 'results.json').write_text(json.dumps({'results': results, 'toolchain': identities}, indent=2) + '\n')
raise SystemExit(int(any(item['exit_code'] for item in results)))
