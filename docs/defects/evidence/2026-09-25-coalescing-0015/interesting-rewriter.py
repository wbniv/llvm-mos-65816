from pathlib import Path
import subprocess,sys,resource
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
r=Path(__file__).resolve().parents[4]
b=r/'build/coalescing-0015-contrast'
args=['-mtriple=mos','-mcpu=mosw65816','-verify-machineinstrs',sys.argv[1],'-o','/dev/null']
def run(exe,passes):
 return subprocess.run([str(exe),'-run-pass='+passes,*args],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
valid=run(b/'llc-noguard-no0028','none')
if valid.returncode:sys.exit(1)
red=run(b/'llc-noguard-no0028','greedy,virtregrewriter')
if b'Using an undefined physical register' not in red.stderr:sys.exit(1)
green=run(b/'llc','greedy,virtregrewriter')
sys.exit(0 if green.returncode==0 else 1)
