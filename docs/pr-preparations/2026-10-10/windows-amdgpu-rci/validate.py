import gzip
import pathlib
import subprocess

work = pathlib.Path(__file__).resolve().parent
root = work.parents[3]
checker = root / '.scratch/upstream-pin-2026-10-09/build/bin/FileCheck'
lines = dict(enumerate((work / 'captured-windows-prefix.txt').read_text().splitlines(), 1))
assert 6 in lines and 8 in lines, lines
captured = '\n'.join(lines[i] for i in range(1, 9)) + '\n'
(work / 'captured-windows-prefix.txt').write_text(captured)
original = (work / 'original.mir').read_text()
fixed = (work / 'fixed.mir').read_text()
for name, text in [('original', original), ('fixed', fixed)]:
    checks = [line for line in text.splitlines() if line.startswith('# CHECK')][:3]
    (work / (name + '-prefix.check')).write_text('\n'.join(checks) + '\n')

def check(label, file, text, expected):
    result = subprocess.run([str(checker), str(file)], input=text, text=True, capture_output=True)
    (work / (label + '.log.gz')).write_bytes(gzip.compress((result.stdout + result.stderr).encode(), mtime=0))
    assert (result.returncode == 0) == expected, (label, result.returncode, result.stderr)
    print(label + ': PASS')

check('original-rejects-captured-windows', work / 'original-prefix.check', captured, False)
check('fixed-accepts-captured-windows', work / 'fixed-prefix.check', captured, True)
# The log abbreviates its middle; reconstruct the remaining required trace lines.
trace = captured + lines[6] + '\nRunning pass: PrintMIRPreparePass on [module]\n'
check('fixed-accepts-windows-shaped-complete-trace', work / 'fixed.mir', trace, True)
spaced = trace.replace(',class llvm::', ', class llvm::')
check('original-accepts-spaced-trace', work / 'original.mir', spaced, True)
check('fixed-accepts-spaced-trace', work / 'fixed.mir', spaced, True)
invalidated = trace.replace(lines[6] + '\nRunning pass: PrintMIRPreparePass', lines[6] + '\nRunning analysis: MachineRegisterClassAnalysis on test_wwm_reserved\nRunning pass: PrintMIRPreparePass')
check('fixed-rejects-recomputed-analysis', work / 'fixed.mir', invalidated, False)
check('fixed-rejects-wrong-analysis', work / 'fixed.mir', trace.replace('MachineRegisterClassAnalysis', 'OtherAnalysis'), False)
