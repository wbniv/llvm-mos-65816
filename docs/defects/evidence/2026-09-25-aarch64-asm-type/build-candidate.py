"""Build the AArch64 constraint guard against the preserved cross-target build."""

import json
from pathlib import Path
import shlex
import shutil
import subprocess

root = Path('/work')
output = Path('/tmp/aarch64-asm-type-fix')
baseline = root / 'build/newton-postra-build'
entries = json.loads((baseline / 'compile_commands.json').read_text())
entry = next(e for e in entries if e['file'].endswith('/AArch64ISelLowering.cpp'))
command = shlex.split(entry['command'])
command[command.index('-o') + 1] = str(output / 'AArch64ISelLowering.cpp.o')
command[-1] = str(output / 'AArch64ISelLowering.cpp')
source_dir = str(Path(entry['file']).parent)
command.insert(1, '-I' + source_dir)
log = root / 'docs/defects/evidence/2026-09-25-aarch64-asm-type/candidate-build.log'

with log.open('w') as stream:
    def run(args, cwd):
        stream.write('$ ' + shlex.join(args) + '\n')
        stream.flush()
        subprocess.run(args, cwd=cwd, stdout=stream,
                       stderr=subprocess.STDOUT, check=True)

    run(command, entry['directory'])
    archive = output / 'libLLVMAArch64CodeGen.a'
    shutil.copy2(baseline / 'lib/libLLVMAArch64CodeGen.a', archive)
    run(['/usr/bin/ar', 'r', str(archive),
         str(output / 'AArch64ISelLowering.cpp.o')], output)
    line = subprocess.check_output(
        ['ninja', '-C', str(baseline), '-t', 'commands', 'bin/llc'],
        text=True).splitlines()[-1]
    args = shlex.split(line)
    assert args[:2] == [':', '&&'] and args[-2:] == ['&&', ':']
    args = args[2:-2]
    args[args.index('-o') + 1] = str(output / 'llc')
    replacements = {
        'lib/libLLVMAArch64CodeGen.a': str(archive),
        'lib/libLLVMSelectionDAG.a': str(
            root / 'build/selectiondag-inlineasm-fix/libLLVMSelectionDAG.a'),
    }
    args = [replacements.get(arg, arg) for arg in args]
    args = [('-Wl,--dependency-file=' + str(output / 'llc-link.d'))
            if arg.startswith('-Wl,--dependency-file=') else
            ('--dependency-file=' + str(output / 'llc-link.d'))
            if arg.startswith('--dependency-file=') else arg for arg in args]
    run(args, baseline)

print('Built assertion-enabled candidate with 0057 and the AArch64 guards.')
