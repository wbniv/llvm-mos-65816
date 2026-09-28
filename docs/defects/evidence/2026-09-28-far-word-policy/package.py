from pathlib import Path
import subprocess,hashlib,json,gzip,tarfile,shutil
root=Path.cwd();w=root/'.scratch/far-word-policy';e=root/'docs/defects/evidence/2026-09-28-far-word-policy';e.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def git(where,*args):return subprocess.check_output(['git','-C',str(where),*args],text=True).strip()
author='OpenAI Codex CLI 0.157.1 (session source: vscode), model gpt-6-astra, xhigh reasoning effort; verified session 01a0e67f-298f-7a21-80af-06f867085f84'
prior=dict(disposition='optimization_policy; no new correctness defect or defect status change',related_record='docs/defects/mos-farblit-byte-load-legalization.json',search_terms=['rdw','native-word','tryFarRuntimeIndexFold','G_LOAD16_FAR_INDIR_IDX','legalizeLoadStore16','0069'],sources=['docs/investigations/2026-09-28-farblit-payoff.md','docs/investigations/2026-09-28-farblit-range-integration.md','docs/plans/2026-09-28-farblit-payoff.md','docs/defects/evidence/2026-09-28-farblit-payoff/prior-work.json','docs/defects/evidence/2026-09-28-farblit-range-integration/prior-work.json','TODO.md','docs/upstream-pending-work.md'],patches=['0002','0061','0062','0066','0069'],source_assessment='0062 supplies the M16/Y8 word pseudo; 0069 installs the bounded loop proof but retains byte-only entry and all-users guards. The captured live legalizer is byte-identical to the 0069 integration source. 0070 changes the word admission policy and enforces a Y8 bound for mixed word/byte groups. The existing legalization defect and its immutable evidence remain unchanged.',binary_assessment='The preserved 0069 candidate supplies baseline Clang/llc/lld. The experimental build copies the live build and bind-mounts the candidate legalizer. Disabled output matches 96 baseline objects and 18 ROMs. The final default build and installed compiler reproduce the explicit speed-policy outputs exactly.',history=git(root,'log','-3','--format=%H %s'),vendor_history=git(root/'vendor/llvm-mos','log','-3','--format=%H %s','--','llvm/lib/Target/MOS/MOSLegalizerInfo.cpp'),decision='Adopt speed-only local policy for O2/O3 with no size/optnone attribute; retain Os/Oz behavior. Independent upstream review and exact-destination validation remain separate work.',attribution=author)
(e/'prior-work.json').write_text(json.dumps(prior,indent=2)+'\n')
identity=dict(versions={v:subprocess.check_output([str(w/v/'bin/clang-23'),'--version'],text=True).strip() for v in ['baseline','policy']},attribution=author,root_revision=git(root,'rev-parse','HEAD'),vendor_revision=git(root/'vendor/llvm-mos','rev-parse','HEAD'),source_hashes={p.name:sha(p) for p in (w/'source').glob('MOSLegalizerInfo*.cpp')},tools={v:{n:dict(path=str(w/v/'bin'/n),sha256=sha(w/v/'bin'/n)) for n in ['clang-23','llc','lld']} for v in ['baseline','candidate','policy']},installed={n:dict(path=str(root/'build/llvm-mos-install/bin'/n),sha256=sha(root/'build/llvm-mos-install/bin'/n)) for n in ['clang-23','lld']},built_llc=dict(path=str(root/'build/llvm-mos/bin/llc'),sha256=sha(root/'build/llvm-mos/bin/llc')),patch_hashes={p.name:sha(p) for p in (root/'patches/llvm-mos').glob('*.patch')},emulators=dict(bsnes_probe=sha(root/'.scratch/carry-timing/jgxcycles-verified'),bsnes_revision=git(root/'vendor/bsnes-jg','rev-parse','HEAD'),mame_version=(w/'runs/mame-version.log').read_text().strip()),sdk_revision=git(root/'vendor/llvm-mos-sdk','rev-parse','HEAD'),method='Identical source fixtures and SDK; full LTO for ROM measurements. Calibrated bsnes master clocks; each interval repeated in an independent process with identical result/profile. Main measurements for bounds and pressure exclude called functions and are not used as full-work timing comparisons.',notes=['Initial candidate source is reconstructed by prepare.py with the original Off default and no codegen-level guard; final policy source is captured directly. Default-policy outputs are byte-identical to explicit speed results for the full matrix.','Compiler binaries stay in the preserved workspace. source.tar.gz contains final vendor tracked diff/untracked overlay plus the baseline legalizer override for reconstruction.','The initial patch-stack check filled /tmp and interrupted the first installed control. Both were rerun successfully using a workspace TMPDIR.'])
(e/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
# Capture final compiler source; baseline differs only by the retained legalizer override.
(w/'source/vendor-final.patch.gz').write_bytes(gzip.compress(subprocess.check_output(['git','-C',str(root/'vendor/llvm-mos'),'diff','--binary']),mtime=0))
paths=subprocess.check_output(['git','-C',str(root/'vendor/llvm-mos'),'ls-files','--others','--exclude-standard','-z']).decode().split('\0')
with tarfile.open(w/'source/vendor-final-untracked.tar.gz','w:gz') as t:
 for p in paths:
  if p:t.add(root/'vendor/llvm-mos'/p,arcname=p)
shutil.copy2(root/'.scratch/farblit-payoff/a16.pre',w/'source/trace-a16.pre.mir')
for name in ['results.json','policy-control.json','default-control.json','disabled-control.json','installed-control.json','focused-tests.json','shape-checks.json','shapes.json','trace.json','lit.json','final-lit.json','patch-check.json','0002-control.json']:
 if (w/name).exists():shutil.copy2(w/name,e/name)
for p in w.glob('*commands.json'):
 (e/(p.name+'.gz')).write_bytes(gzip.compress(p.read_bytes(),mtime=0))
for p in w.glob('*sweep.json'):
 (e/(p.name+'.gz')).write_bytes(gzip.compress(p.read_bytes(),mtime=0))
for name in ['candidate.patch','experiment.patch','sweep.py','sweep-o3.py','trace.py','shapes.py','check-tests.py','make-word-tests.py','prepare.py','mame.sh','mame-o3.sh','installed-control.py','package.py']:
 shutil.copy2(w/name,e/name)
for p in w.glob('*.log'):
 if p.stat().st_size > 1000000:(e/(p.name+'.gz')).write_bytes(gzip.compress(p.read_bytes(),mtime=0))
 else:shutil.copy2(p,e/p.name)
for name in ['source','runs','trace','shapes']:
 with tarfile.open(e/(name+('.tar.xz' if name=='runs' else '.tar.gz')), 'w:xz' if name=='runs' else 'w:gz') as t:t.add(w/name,arcname=name)
manifest={str(p.relative_to(e)):dict(bytes=p.stat().st_size,sha256=sha(p)) for p in e.iterdir() if p.is_file() and p.name!='manifest.json'}
(e/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('packaged',len(manifest),'artifacts',sum(p['bytes'] for p in manifest.values()),flush=True)
