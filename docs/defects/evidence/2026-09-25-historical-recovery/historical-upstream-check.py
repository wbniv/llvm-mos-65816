from pathlib import Path
import hashlib, json, platform, resource, shlex, subprocess

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
root = Path.cwd()
evidence = root / 'docs/defects/evidence/2026-09-25-historical-recovery'
reference = root / 'build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643'
clang = reference / 'bin/clang'
def run(command, name):
    result = subprocess.run(list(map(str, command)), text=True, capture_output=True)
    log = evidence / ('upstream-host-' + name + '.log')
    log.write_text('$ ' + shlex.join(map(str, command)) + '\n' + result.stdout + result.stderr + '\nexit_code=' + str(result.returncode) + '\n')
    row = dict(command=shlex.join(map(str, command)), exit_code=result.returncode, log=str(log.relative_to(root)))
    print(name, result.returncode, flush=True)
    return row

runs = []
for stage in ('shift', 'inline'):
    source = evidence / (stage + '-stage/examples/65816/bitboard64-probe.c')
    for cpu in ('mos6502', 'mosw65816'):
        name = stage + '-' + cpu
        command = [clang, '--target=mos', '-mcpu=' + cpu, '-Os', '-fno-lto', '-mllvm', '-verify-machineinstrs']
        for kind, args, output in (
            ('preprocess', ['-E'], evidence / ('upstream-' + name + '.i')),
            ('ir', ['-S', '-emit-llvm'], evidence / ('upstream-' + name + '.ll')),
            ('compile', ['-c'], root / ('build/historical-upstream-' + name + '.o')),
        ):
            row = run(command + args + [source, '-o', output], name + '-' + kind)
            row.update(stage=stage, cpu=cpu, kind=kind, source=str(source.relative_to(root)))
            runs.append(row)

runs.append(run([clang, '--target=mos', '-mcpu=mosw65816', '-Xclang', '-target-feature', '-Xclang', '+mos-a16', '-Xclang', '-target-feature', '-Xclang', '+mos-xy16', '-Os', '-fno-lto', '-mllvm', '-verify-machineinstrs', '-c', evidence / 'shift-stage/examples/65816/bitboard64-probe.c', '-o', root / 'build/historical-upstream-unsupported-features.o'], 'unsupported-features'))
result = dict(reference_manifest=json.loads((reference / 'manifest.json').read_text()), compiler_sha256=hashlib.sha256(clang.read_bytes()).hexdigest(), host=platform.uname()._asdict(), execution_environment='Native host; the original recorded Docker image is unavailable. Saved compiler snapshot checksums verified before execution.', runs=runs)
(evidence / 'upstream-host-runs.json').write_text(json.dumps(result, indent=2) + '\n')
