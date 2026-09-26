from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile

root = Path.cwd()
evidence = root / 'docs/defects/evidence/2026-09-26-far-memset'
archive = root / 'build/defect-baselines/2026-09-26-far-memset'
test = root / 'vendor/llvm-mos/llvm/test/CodeGen/MOS/far-memset.ll'
shutil.copy2(test, evidence / 'far-memset.ll')
runs = []

def run(name, command, expected=0, stdin=None, cwd=root):
    command = [str(x) for x in command]
    result = subprocess.run(command, cwd=cwd, input=stdin, capture_output=True)
    (evidence / (name + '.stdout')).write_bytes(result.stdout)
    (evidence / (name + '.stderr')).write_bytes(result.stderr)
    runs.append(dict(name=name, command=command, working_directory=str(cwd),
                     exit_code=result.returncode, expected_exit=expected))
    assert result.returncode == expected, (name, result.stderr.decode())
    return result.stdout

for name, binary in [('baseline', 'llc-without-0013'), ('candidate', 'llc')]:
    for mode, attr in [('a16', '+mos-a16'), ('xy16', '+mos-a16,+mos-xy16')]:
        label = f'focused-{name}-{mode}'
        output = run(label, [archive / 'bin' / binary, '-mtriple=mos',
                            '-mcpu=mosw65816', '-mattr=' + attr,
                            '-verify-machineinstrs', evidence / 'far-memset.ll', '-o', '-'])
        run(label + '-check', [archive / 'bin/FileCheck', evidence / 'far-memset.ll'],
            expected=1 if name == 'baseline' else 0, stdin=output)

assert (evidence / 'baseline/prelegalizer.mir').read_bytes() == (evidence / 'candidate/prelegalizer.mir').read_bytes()
run('legalizer-difference', ['diff', '-u', evidence / 'baseline/legalized.mir', evidence / 'candidate/legalized.mir'], expected=1)

with tempfile.TemporaryDirectory(prefix='far-memset-patch-') as temporary:
    scratch = Path(temporary)
    rel = Path('llvm/lib/Target/MOS/MOSLegalizerInfo.cpp')
    (scratch / rel).parent.mkdir(parents=True)
    shutil.copy2(archive / 'without-0013' / rel, scratch / rel)
    run('patch-apply', ['git', 'apply', '--unsafe-paths', '--directory=' + str(scratch),
                        root / 'patches/llvm-mos/0013-320-far-memops.patch'])
    assert (scratch / rel).read_bytes() == (root / 'vendor/llvm-mos' / rel).read_bytes()
    assert (scratch / 'llvm/test/CodeGen/MOS/far-memset.ll').read_bytes() == test.read_bytes()
    run('patch-reverse', ['git', 'apply', '-R', '--unsafe-paths', '--directory=' + str(scratch),
                          root / 'patches/llvm-mos/0013-320-far-memops.patch'])
    assert (scratch / rel).read_bytes() == (archive / 'without-0013' / rel).read_bytes()
    run('test-import', ['git', 'apply', '--unsafe-paths', '--directory=' + str(scratch),
                       '--include=**/far-memset.ll', root / 'patches/llvm-mos/0013-320-far-memops.patch'])
    assert (scratch / 'llvm/test/CodeGen/MOS/far-memset.ll').read_bytes() == test.read_bytes()
    assert (scratch / rel).read_bytes() == (archive / 'without-0013' / rel).read_bytes()

for path in sorted((root / 'vendor/llvm-mos/llvm/test/CodeGen/MOS').glob('far-*.ll')):
    run('verify-' + path.stem, [archive / 'bin/llc', '-mtriple=mos', '-mcpu=mosw65816',
                              '-mattr=+mos-a16', '-verify-machineinstrs', path, '-o', '/dev/null'])

(evidence / 'validation.json').write_text(json.dumps(dict(runs=runs,
    identical_prelegalizer_mir=True, compiler_source_change=False,
    patch_roundtrip=True), indent=2) + '\n')
print('Focused red/green, prelegalizer identity, patch round-trip/import, and far-codegen checks pass.')
