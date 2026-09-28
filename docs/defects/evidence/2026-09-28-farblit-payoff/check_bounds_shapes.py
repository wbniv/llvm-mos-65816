from pathlib import Path
import importlib.util,sys,json
spec=importlib.util.spec_from_file_location('shapes','dev/check-farblit-shapes.py');m=importlib.util.module_from_spec(spec);sys.modules[spec.name]=m;spec.loader.exec_module(m)
w=Path('.scratch/farblit-payoff');allrows=[]
for mode in ['a16','xy16']:
 for variant in ['baseline','both']:
  source=w/'source/bounds.c';asm=w/'runs'/f'bounds-{variant}-{mode}.s'
  files,funcs=m.parse_assembly(asm.read_text(),source)
  for name,(instructions,labels) in funcs.items():
   if not name.startswith(('word','copy')):continue
   states,_=m.width_states(instructions,labels);access=[]
   for i,inst in enumerate(instructions):
    if inst.opcode=='lda' and (form:=m.address_form(inst.operand)):
     assert len(states[i])==1,(name,i);a,x=next(iter(states[i]));access.append({'form':form,'m':a,'x':x,'line':inst.line})
   actual=[(r['form'],r['m'],r['x']) for r in access]
   if name.startswith('word'):
    indexed = variant=='both' and name in ['word128','word_pressure']
    expect=[('indirect-y' if indexed else 'indirect',16,8)]
   elif name=='copy_wrapped_index':expect=[('indirect-y',8,8)]
   elif name=='copy248' and variant=='both':expect=[('indirect-y',8,8)]
   else:expect=[('indirect-y',8,16)] if mode=='xy16' else [('indirect',8,8)]
   print(mode,variant,name,actual,flush=True)
   assert actual==expect,(name,mode,variant,actual,expect)
   allrows.append({'mode':mode,'variant':variant,'function':name,'accesses':access,'pass':True})
(w/'bounds-shapes.json').write_text(json.dumps(allrows,indent=2)+'\n')
