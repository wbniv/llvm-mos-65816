from pathlib import Path
import re
r=Path.cwd()
for name,base,source in [('mos',r/'build/llvm-mos',r/'vendor/llvm-mos/llvm'),('cross',r/'build/0041-inlineasm-build',r/'build/0041-inlineasm-src/llvm')]:
 out=r/('build/shift-inlineasm-lit-'+name);(out/'test').mkdir(parents=True,exist_ok=True)
 tool=base/'bin'
 if name=='cross':
  tool=out/'bin';tool.mkdir(exist_ok=True)
  for p in (base/'bin').iterdir():
   dst=tool/p.name
   if not dst.exists():dst.symlink_to(r/'build/inlineasm-bounds-fix/llc' if p.name=='llc' else p.resolve())
 data=(base/'test/lit.site.cfg.py').read_text()
 for key,value in {'llvm_src_root':source,'llvm_obj_root':out,'llvm_tools_dir':tool,'llvm_lib_dir':base/'lib','llvm_shlib_dir':base/'lib'}.items():
  data=re.sub(r'^config\.'+key+r' = .*$',lambda m:'config.'+key+' = '+repr(str(value)),data,flags=re.M)
 (out/'test/lit.site.cfg.py').write_text(data)
 for sub in ['CodeGen/MOS','MC/MOS','CodeGen/AArch64/GlobalISel','CodeGen/ARM/GlobalISel','CodeGen/X86/GlobalISel']:(out/'test'/sub).mkdir(parents=True,exist_ok=True)
print('Prepared separate lit output directories and cross-target candidate tools.')
