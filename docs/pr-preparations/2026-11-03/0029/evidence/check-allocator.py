#!/usr/bin/env python3
"""Check retained transfer probes independently of virtual register numbering."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(os.environ.get('REVIEW_ROOT', '/review'))
BIN = Path(os.environ.get('REVIEW_BIN', '/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/bin'))
PHASE = sys.argv[1]
OUT = ROOT/'evidence'/(sys.argv[2] if len(sys.argv)>2 else 'allocator-'+PHASE)
OUT.mkdir(exist_ok=False)
ORDER = [5,0,15,3,9,1,14,6,12,2,10,4,13,8,7,11]
ROWS = []

def check_aliases(text):
    """Check live storage overlap from uses/defs, without the compiler graph."""
    count = 0
    for function in re.split(r'^name:\s*',text,flags=re.M)[1:]:
        name=function.splitlines()[0].strip()
        assignments=dict(re.findall(r'id: (\d+), class: [^\n]*?assigned-phys: \'\$(\w+)\'',function))
        body=re.split(r'^body:\s*\|\s*$',function,flags=re.M)[1].split('\n...')[0]
        instructions=[]
        for line in body.splitlines():
            line=line.strip().split(' :: ')[0]
            if not line or line.startswith(('bb.','DBG_','CFI_')):continue
            lhs,rhs=line.split(' = ',1) if ' = ' in line else ('',line)
            implicit_defs=re.findall(r'implicit-def(?: dead)?(?: early-clobber)? (%\d+)',rhs)
            rhs=re.sub(r'implicit-def(?: dead)?(?: early-clobber)? %\d+','',rhs)
            defs=re.findall(r'%\d+',lhs)+implicit_defs
            early=set(re.findall(r'early-clobber (%\d+)',lhs))
            uses=re.findall(r'%\d+',rhs)
            instructions.append((defs,early,uses))
        last={reg:i for i,(_,_,uses) in enumerate(instructions) for reg in uses}
        live=set()
        def units(reg):
            phys=assignments[reg[1:]]
            if re.fullmatch(r'rc\d+lsb',phys):return {(int(phys[2:-3]),0)}
            if re.fullmatch(r'rc\d+',phys):return {(int(phys[2:]),bit) for bit in range(8)}
            if re.fullmatch(r'rs\d+',phys):
                n=2*int(phys[2:]);return {(byte,bit) for byte in [n,n+1] for bit in range(8)}
            raise ValueError('Unknown assignment '+phys)
        def define(reg):
            for other in live:
                if reg!=other and units(reg)&units(other):
                    raise AssertionError((name,'overlapping live storage',reg,other,assignments))
            live.add(reg)
        for i,(defs,early,uses) in enumerate(instructions):
            for reg in early:define(reg)
            for reg in uses:
                if reg not in live:raise AssertionError((name,'use without live definition',reg))
            for reg in uses:
                if last[reg]==i:live.discard(reg)
            for reg in defs:
                if reg not in early:define(reg)
            for reg in defs:
                if last.get(reg,-1)<=i:live.discard(reg)
        count+=1
    if not count:raise ValueError('No MIR functions found')
    return {'alias_check':'pass','functions_checked':count}

def address(text):
    m = re.fullmatch(r'(@(?:input|output)|%stack\.\d+)(?: \+ (\d+))?',text.strip())
    if not m: raise ValueError('Unsupported address: '+text)
    return m[1],int(m[2] or 0)

def evaluate(text, allocated):
    assignments = dict(re.findall(r'id: (\d+), class: [^\n]*?assigned-phys: \'\$(\w+)\'',text))
    memory = {('@input',i): 'input['+str(i)+']' for i in range(16)}
    regs = {}
    outputs = []
    stores = reloads = scratch = 0
    def locations(vreg):
        if not allocated: return [vreg]
        phys=assignments[vreg[1:]]
        if re.fullmatch(r'rc\d+',phys): return [phys]
        if re.fullmatch(r'rs\d+',phys):
            n=2*int(phys[2:]);return ['rc'+str(n),'rc'+str(n+1)]
        raise ValueError('Unexpected physical location: '+phys)
    def read(vreg):
        loc=locations(vreg)
        if len(loc)!=1: raise ValueError('Expected byte register')
        return regs[loc[0]]
    def write(vreg,value):
        for loc in locations(vreg): regs[loc]=value
    body=re.split(r'^body:\s*\|\s*$',text,flags=re.M)[1]
    for line in body.splitlines():
        line=line.strip().split(' :: ')[0]
        if not line or line.startswith('bb.') or line=='...' or line=='RTS': continue
        lhs,instruction=line.split(' = ',1) if ' = ' in line else ('',line)
        for reg in re.findall(r'early-clobber (%\d+)',lhs):
            write(reg,'scratch-clobber'); scratch+=1
        opcode,operands=instruction.split(' ',1)
        if opcode in ['LDAbs','LDStk']:
            dest=re.findall(r'%\d+',lhs)[0]
            key=address(operands.split(', ')[0])
            write(dest,memory[key]); reloads+=key[0].startswith('%stack.')
        elif opcode in ['STAbs','STStk']:
            source,dest,*_=operands.split(', ')
            value=read(re.findall(r'%\d+',source)[0])
            key=address(dest);memory[key]=value;stores+=key[0].startswith('%stack.')
            if key[0]=='@output': outputs.append((key[1],value))
        else: raise ValueError('Unsupported opcode: '+line)
    expected=[(i,'input['+str(v)+']') for i,v in enumerate(ORDER+ORDER[::-1])]
    if outputs!=expected: raise AssertionError({'actual':outputs,'expected':expected})
    if not stores or not reloads: raise AssertionError('Probe did not spill and reload')
    return {'semantic_check':'pass','output_events':len(outputs),'spill_stores':stores,
            'reloads':reloads,'early_clobber_scratch_defs':scratch,'assigned_registers':len(assignments)}

def run(name, args, expected=0, signature=None):
    p=subprocess.run([str(x) for x in args],capture_output=True)
    (OUT/(name+'.mir')).write_bytes(p.stdout)
    (OUT/(name+'.stderr')).write_bytes(p.stderr)
    ok=p.returncode==0 if expected==0 else p.returncode!=0
    if signature: ok=ok and signature.encode() in p.stderr
    row={'name':name,'command':[str(x) for x in args],'exit_code':p.returncode,
         'expected_exit':expected,'expected_signature':signature,'pass':ok}
    ROWS.append(row)
    return p,row

for cpu in ['mos6502','mos65c02','mosw65816','mosspc700']:
    for stack,feature in [('static','+static-stack'),('soft','-static-stack')]:
        for stress in [8,12]:
            stages=['spill','assign'] if PHASE=='pr628' else ['spill']
            for stage in stages:
                name=f'{cpu}-{stack}-{stress}-{stage}'
                args=[BIN/'llc','-mtriple=mos','-mcpu='+cpu,'-mattr='+feature,
                      '-stress-regalloc='+str(stress),'-mos-experimental-regalloc',
                      '-stop-after=mos-imag-reg-'+stage,'-verify-machineinstrs',
                      ROOT/'inputs/pressure-probe.ll','-o','-']
                p,row=run(name,args)
                if p.returncode==0:
                    try:
                        row.update(evaluate(p.stdout.decode(),stage=='assign'))
                        if stage=='assign':row.update(check_aliases(p.stdout.decode()))
                    except Exception as e: row.update({'pass':False,'semantic_check':repr(e)})
                row['mir_sha256']=hashlib.sha256(p.stdout).hexdigest()

p,row=run('undef-normalize',[BIN/'llc','-mtriple=mos','-run-pass=mos-conventional-ssa',
    '-verify-machineinstrs',ROOT/'inputs/boundary-probes.mir','-o','-'])
if p.returncode==0:
    q=subprocess.run(['python3',str(ROOT/'inputs/check-boundary-probes.py'),str(OUT/'undef-normalize.mir')],capture_output=True)
    (OUT/'undef-check.log').write_bytes(q.stdout+q.stderr)
    row['semantic_exit']=q.returncode; row['pass']=row['pass'] and q.returncode==0
run('undef-consumer',[BIN/'llc','-mtriple=mos','-run-pass=mos-conventional-ssa,mos-imag-reg-spill',
    '-verify-machineinstrs',ROOT/'inputs/consumer-boundary.mir','-o','-'],expected=1,
    signature='MOSImagRegSpill requires whole-register, untied virtual operands')
run('0029-production',[BIN/'llc','-mtriple=mos','-mcpu=mos6502','-O2','-verify-machineinstrs',
    ROOT/'inputs/mixed-width-call.ll','-o','-'],expected=1,signature='ran out of registers')
run('0029-experimental',[BIN/'llc','-mtriple=mos','-mcpu=mos6502','-O2','-mos-experimental-regalloc',
    '-stop-after=mos-imag-reg-spill','-verify-machineinstrs',ROOT/'inputs/mixed-width-call.ll','-o','-'],
    expected=1,signature='MOSImagRegSpill')
run('full-experimental-pipeline',[BIN/'llc','-mtriple=mos','-mcpu=mos6502','-O2',
    '-mattr=+static-stack','-stress-regalloc=8','-mos-experimental-regalloc',
    '-verify-machineinstrs',ROOT/'inputs/pressure-probe.ll','-o','-'],expected=1,
    signature='MOSRegAlloc is not implemented' if PHASE=='pr628' else 'MOSImagRegAssign is not implemented')

if PHASE=='pr628':
    for filename,feature,stress in [('imag-regalloc-assign.mir','+static-stack',None),
                                    ('imag-regalloc-assign-tight.mir','-static-stack',2)]:
        args=[BIN/'llc','-mtriple=mos','-mattr='+feature,'-run-pass=mos-imag-reg-assign','-verify-machineinstrs']
        if stress:args+=['-stress-regalloc='+str(stress)]
        p,row=run(filename,args+[ROOT/'pr628/llvm/test/CodeGen/MOS'/filename,'-o','-'])
        if p.returncode==0:
            try:row.update(check_aliases(p.stdout.decode()))
            except Exception as e:row.update({'pass':False,'alias_check':repr(e)})

manifest={'phase':PHASE,'assertions':False,'llc_sha256':hashlib.sha256((BIN/'llc').read_bytes()).hexdigest(),
          'runs':ROWS,'limits':['Pass-level MIR validation; no machine execution or hardware allocator implementation.',
          'Retained native-width and far-pointer reproducers require downstream-only features and are not reclassified.']}
(OUT/'results.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'phase':PHASE,'checks':len(ROWS),'unexpected':[r for r in ROWS if not r['pass']]},indent=2))
sys.exit(any(not row['pass'] for row in ROWS))
