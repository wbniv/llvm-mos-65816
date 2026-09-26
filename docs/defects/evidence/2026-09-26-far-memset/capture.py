from pathlib import Path
import hashlib
import json
import shlex
import shutil
import subprocess
import tarfile

root = Path.cwd()
evidence = root / 'docs/defects/evidence/2026-09-26-far-memset'
archive = root / 'build/defect-baselines/2026-09-26-far-memset'
evidence.mkdir(parents=True, exist_ok=False)
archive.mkdir(parents=True, exist_ok=False)
vendor = root / 'vendor/llvm-mos'
build = root / 'build/llvm-mos'
source_rel = Path('llvm/lib/Target/MOS/MOSLegalizerInfo.cpp')
patch = root / 'patches/llvm-mos/0013-320-far-memops.patch'

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

commands = []
def run(argv, cwd=root):
    argv = [str(x) for x in argv]
    result = subprocess.run(argv, cwd=cwd, capture_output=True)
    commands.append(dict(command=argv, cwd=str(cwd), exit_code=result.returncode))
    with (evidence / 'capture-build.log').open('ab') as log:
        log.write(('$ ' + shlex.join(argv) + '\n').encode())
        log.write(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(shlex.join(argv))
    return result.stdout

shutil.copy2(root / 'examples/65816/far_memset.c', evidence / 'original.c.txt')
shutil.copy2(patch, evidence / '0013.patch.txt')
shutil.copy2(root / 'docs/320-far-memset-miscompile.md', evidence / 'original-report.md.txt')
shutil.copy2(root / 'docs/document-dependencies.json', evidence / 'prior-dependencies.json')
(evidence / 'historical-commit.txt').write_bytes(run(['git', 'show', '-s', '--format=fuller', 'a81874d']))
(evidence / 'original-source-commit.txt').write_bytes(run(['git', 'log', '-1', '--format=fuller', '--', 'examples/65816/far_memset.c']))
(archive / 'vendor.diff').write_bytes(run(['git', '-C', vendor, 'diff', '--binary', 'HEAD']))
with tarfile.open(archive / 'patches.tar.gz', 'w:gz') as tar:
    tar.add(root / 'patches/llvm-mos', arcname='patches/llvm-mos')
shutil.copy2(build / 'CMakeCache.txt', archive / 'CMakeCache.txt')
shutil.copy2(build / 'compile_commands.json', archive / 'compile_commands.json')
(archive / 'bin').mkdir()
for name, src in {
    'llc': build / 'bin/llc',
    'clang': root / 'build/llvm-mos-install/bin/clang',
    'ld.lld': root / 'build/llvm-mos-install/bin/ld.lld',
    'llvm-objdump': build / 'bin/llvm-objdump',
    'FileCheck': build / 'bin/FileCheck',
    'jgxcheck': root / 'build/jgxcheck',
}.items():
    shutil.copy2(src, archive / 'bin' / name)
shutil.copytree(root / 'build/llvm-mos-install/lib/clang', archive / 'lib/clang', symlinks=True)
shutil.copytree(root / 'build/install', archive / 'sdk', symlinks=True)
shutil.copytree(root / 'vendor/bsnes-jg/Database', archive / 'Database', symlinks=True)

base_src = archive / 'without-0013' / source_rel
base_src.parent.mkdir(parents=True)
shutil.copy2(vendor / source_rel, base_src)
run(['patch', '--batch', '--fuzz=0', '-R', '-p1', '-i', patch], archive / 'without-0013')
verify_src = archive / 'roundtrip' / source_rel
verify_src.parent.mkdir(parents=True)
shutil.copy2(base_src, verify_src)
run(['patch', '--batch', '--fuzz=0', '-p1', '-i', patch], archive / 'roundtrip')
assert verify_src.read_bytes() == (vendor / source_rel).read_bytes()
shutil.copy2(base_src, evidence / 'legalizer-without-0013.cpp.txt')
shutil.copy2(vendor / source_rel, evidence / 'legalizer-with-0013.cpp.txt')

entry = next(x for x in json.loads((build / 'compile_commands.json').read_text())
             if x['file'].endswith('/MOSLegalizerInfo.cpp'))
obj = archive / 'MOSLegalizerInfo.cpp.o'
compile_command = shlex.split(entry['command'])
compile_command[compile_command.index('-o') + 1] = str(obj)
compile_command[-1] = str(base_src)
run(compile_command, Path(entry['directory']))
lib = archive / 'libLLVMMOSCodeGen.a'
shutil.copy2(build / 'lib/libLLVMMOSCodeGen.a', lib)
run(['/usr/bin/ar', 'r', lib, obj])
link_line = run(['ninja', '-C', build, '-t', 'commands', 'bin/llc']).decode().splitlines()[-1]
link = shlex.split(link_line)
assert link[:2] == [':', '&&'] and link[-2:] == ['&&', ':']
link = link[2:-2]
link[link.index('-o') + 1] = str(archive / 'bin/llc-without-0013')
link = [str(lib) if x == 'lib/libLLVMMOSCodeGen.a' else x for x in link]
run(link, build)

identity = {
    'description': 'Current fork comparison with exactly patch 0013 removed from MOSLegalizerInfo.cpp; reconstructed, not the June compiler.',
    'attribution': 'OpenAI Codex CLI 0.157.0 (codex-tui), model gpt-6-astra, xhigh reasoning effort; session 01a0db16-f6a0-7e32-ada6-0c8098813933.',
    'vendor_revision': run(['git', '-C', vendor, 'rev-parse', 'HEAD']).decode().strip(),
    'repository_revision': run(['git', 'rev-parse', 'HEAD']).decode().strip(),
    'host': run(['uname', '-a']).decode().strip(),
    'roundtrip_identical': True,
    'commands': commands,
    'sha256': {str(p.relative_to(root)): sha(p) for p in archive.rglob('*') if p.is_file()},
    'patch_hashes': {str(p.relative_to(root)): sha(p) for p in sorted((root / 'patches/llvm-mos').glob('*.patch'))},
}
(evidence / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')
print('Captured tools, SDK, inputs, and reconstructed comparison compiler.', flush=True)
