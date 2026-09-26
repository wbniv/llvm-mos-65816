import resource, subprocess, sys
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
p = subprocess.run(['/home/will/llvm-mos-65816/build/defect-baselines/2026-09-25-historical-recovery/bin/llc', '-mtriple=mos', '-mcpu=mosw65816', '-mattr=+mos-a16', '-O2', '-verify-machineinstrs', sys.argv[1], '-o', '/dev/null'], capture_output=True, text=True)
raise SystemExit(0 if p.returncode and 'unable to legalize instruction:' in p.stderr and 'G_ANYEXT' in p.stderr else 1)
