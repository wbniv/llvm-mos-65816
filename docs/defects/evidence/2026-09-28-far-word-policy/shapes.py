from pathlib import Path
import subprocess,importlib.util,sys,json
root=Path.cwd();w=root/'.scratch/far-word-policy';out=w/'shapes';out.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('shapes',root/'dev/check-farblit-shapes.py');m=importlib.util.module_from_spec(spec);sys.modules[spec.name]=m;spec.loader.exec_module(m)
rows=[];commands=[]
for policy in ['off','speed','all']:
 for mode in ['a16','xy16']:
  for opt in ['Os','Oz','O2']:
   for fixture in ['farblit','bounds']:
    source=w/'source'/(fixture+'.c');name='-'.join([policy,fixture,mode,opt]);path=out/(name+'.s')
    cmd=[w/'candidate/bin/mos-clang','--config',root/'build/install/bin/mos-snes-hirom.cfg','-mcpu=mosw65816','-Xclang','-target-feature','-Xclang','+mos-a16']
    if mode=='xy16':cmd+=['-Xclang','-target-feature','-Xclang','+mos-xy16']
    cmd+=['-'+opt,'-gline-tables-only','-mllvm','-mos-far-word-index='+policy,'-mllvm','-verify-machineinstrs','-fno-lto','-S',source,'-o',path]
    p=subprocess.run(list(map(str,cmd)),text=True,capture_output=True);commands.append(dict(command=list(map(str,cmd)),status=p.returncode));assert not p.returncode,p.stderr
    files,funcs=m.parse_assembly(path.read_text(),source)
    markers=m.source_markers(source)
    for fn,(ins,labels) in funcs.items():
     states,_=m.width_states(ins,labels);access=[]
     for i,inst in enumerate(ins):
      if inst.opcode=='lda' and (form:=m.address_form(inst.operand)):
       if fixture=='farblit' and markers.get(inst.location[1])!='rdw':continue
       if fixture=='bounds' and not fn.startswith('word'):continue
       assert len(states[i])==1,(name,fn,inst)
       a,x=next(iter(states[i]));access.append(dict(form=form,m=a,x=x,line=inst.line))
     if access:
      actual=[(a['form'],a['m'],a['x']) for a in access]
      rows.append(dict(policy=policy,fixture=fixture,mode=mode,opt=opt,function=fn,accesses=access))
      print(name,fn,actual,flush=True)
(w/'shapes.json').write_text(json.dumps(rows,indent=2)+'\n');(w/'shape-commands.json').write_text(json.dumps(commands,indent=2)+'\n')
