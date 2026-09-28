#!/usr/bin/env python3
"""Check real legalizer outputs and reject opcode-prefix substitutions."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);a=p.parse_args();r=a.root.resolve();w=r/'build/far-word-upstream';out=w/'sensitivity';out.mkdir(exist_ok=True);llc=w/'candidate/llc';fc=w/'build/bin/FileCheck';tests=w/'source/llvm/test/CodeGen/MOS'
records=[];positives=[]
for file,configs,ops in [('far-loop-range.mir',[('A16',['-mattr=+mos-a16']),('XY16',['-mattr=+mos-a16,+mos-xy16']),('OFF',['-mattr=+mos-a16','-mos-far-loop-range=false'])],['G_LOAD_FAR_INDIR','G_LOAD_FAR_INDIR_IDX','G_LOAD_FAR_INDIR_IDX16']),('far-word-policy.mir',[('SPEED',['-mattr=+mos-a16']),('ALL',['-mattr=+mos-a16','-mos-far-word-index=all']),('OFF',['-mattr=+mos-a16','-mos-far-word-index=off'])],['G_LOAD16_FAR_INDIR','G_LOAD16_FAR_INDIR_IDX','G_LOAD16_FAR_INDIR_IDX16'])]:
 for prefix,flags in configs:
  cmd=[str(llc),'-mtriple=mos','-mcpu=mosw65816',*flags,'-run-pass=legalizer','-verify-machineinstrs',str(tests/file),'-o','-'];raw=subprocess.run(cmd,capture_output=True,text=True);assert raw.returncode==0,raw.stderr
  text=raw.stdout;(out/(file+'.'+prefix+'.out')).write_text(text)
  check=[str(fc),str(tests/file),'--check-prefix='+prefix];pos=subprocess.run(check,input=text,text=True,capture_output=True);assert pos.returncode==0,pos.stderr;positives.append(dict(file=file,prefix=prefix,command=cmd,sha256=hashlib.sha256(text.encode()).hexdigest()))
  labels=list(re.finditer(r'^name:[ \t]+(\w+)[ \t]*$',text,re.M))
  for i,label in enumerate(labels):
   start,end=label.end(),labels[i+1].start() if i+1<len(labels) else len(text)
   matches=list(re.finditer(r'\b'+ops[0]+r'(?:_IDX(?:16)?)?\b',text[start:end]));assert len(matches)==1,(file,label[1],matches)
   match=matches[0];begin=start+match.start();finish=start+match.end()
   for replacement in ops:
    if replacement==match[0]:continue
    mutant=text[:begin]+replacement+text[finish:];res=subprocess.run(check,input=mutant,text=True,capture_output=True)
    records.append(dict(file=file,prefix=prefix,function=label[1],expected=match[0],replacement=replacement,returncode=res.returncode))
    assert res.returncode==1,records[-1]
summary=dict(positive_passes=len(positives),mutations=len(records),rejected=sum(x['returncode']==1 for x in records))
(out/'results.json').write_text(json.dumps(dict(summary=summary,positives=positives,mutations=records),indent=2)+'\n');print(summary)
