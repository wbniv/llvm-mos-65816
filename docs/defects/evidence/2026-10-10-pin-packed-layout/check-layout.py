from pathlib import Path
import subprocess, sys
root=Path(__file__).resolve().parents[4]
compiler=Path(sys.argv[1]).resolve()
source=Path(__file__).with_name('arith.i')
output=Path(sys.argv[2]).resolve()
subprocess.run([compiler, '-target', 'mos', '-mcpu=mosw65816', '-ffreestanding', '-Os', '-mllvm', '-verify-machineinstrs', '-c', source, '-o', output],check=True)
