import hashlib, importlib.util, json, re, subprocess, sys
from pathlib import Path
root = Path.cwd()
work = root / '.scratch/farblit-payoff'
out = work / 'runs'
tool = root / 'build/llvm-mos-install/bin'
source = root / 'examples/65816/farblit.c'
spec = importlib.util.spec_from_file_location('shapes', root / 'dev/check-farblit-shapes.py')
shapes = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = shapes
spec.loader.exec_module(shapes)
original_expectations = shapes.expectations
commands = []

def run(args, name):
    args = list(map(str, args))
    p = subprocess.run(args, capture_output=True, text=True, timeout=300)
    (out / (name + '.log')).write_text(p.stdout + p.stderr)
    commands.append({'command': args, 'exit_code': p.returncode, 'log': name + '.log'})
    (work / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    assert p.returncode == 0, name + '\n' + p.stderr[-2500:]
    return p.stdout

def symbols(elf, name):
    text = run([tool/'llvm-objdump', '-t', elf], name+'-symbols')
    return {p[-1]: (int(p[0],16),int(p[-2],16)) for l in text.splitlines()
            if len(p:=l.split()) >= 5 and re.fullmatch('[0-9a-f]{8}',p[0])}

def code(dis):
    return [(m[1], m[2].split()) for l in dis.splitlines()
            if (m:=re.match(r'^\s*([0-9a-f]+):\s+((?:[0-9a-f]{2} )+)', l))]

run(['cc','-DHOST','-O2',source,'-o',out/'host'], 'host-build')
expected = int(run([out/'host'], 'host'),16)
rows=[]
for mode in ['a16','xy16']:
    features = '+mos-a16'+(',+mos-xy16' if mode=='xy16' else '')
    for variant in ['baseline','range','both']:
        name=variant+'-'+mode
        compiler=work/'bin'/('llc-baseline' if variant=='baseline' else 'llc-candidate')
        options=[] if variant=='baseline' else ['-mos-far-range-experiment']
        if variant=='both': options+=['-mos-far-word-experiment']
        flags=['-mtriple=mos','-mcpu=mosw65816','-mattr='+features,
               '-x=mir','-start-before=legalizer','-verify-machineinstrs',*options]
        for typ,ext in [('asm','s'),('obj','o')]:
            run([compiler,*flags,'-filetype='+typ,work/(mode+'.pre'),'-o',out/(name+'.'+ext)],name+'-'+typ)
        run([compiler,*flags,'-stop-after=legalizer',work/(mode+'.pre'),'-o',out/(name+'.after.mir')],name+'-after')
        def expectations(m,f):
            e=original_expectations(m,f)
            if variant in ['range','both']: e['cp8']=[('lda','indirect-y',8,8),('sta','indirect-y',8,8)]
            if variant=='both': e['rdw']=[('lda','indirect-y',16,8)]
            return e
        shapes.expectations=expectations
        asm=(out/(name+'.s')).read_text()
        report=shapes.check_shapes(asm,source,mode,'main')
        (out/(name+'.shapes.json')).write_text(json.dumps(report,indent=2)+'\n')
        labels=[(i+1,m[1]) for i,l in enumerate(asm.splitlines()) if (m:=re.match(r'(\.LBB\d+_\d+):',l))]
        regions={}
        for probe in ['rdw','cp8']:
            line=report[probe][0]['assembly_line']
            j=max(i for i,(n,l) in enumerate(labels) if n<line)
            regions[probe]=[labels[j][1].replace('.LBB','payoff_bb'),'payoff_'+probe+'_end']
        labelled=asm.replace('.LBB','payoff_bb')
        for probe,(first,last) in regions.items():
            branch = re.compile(r'(^\s*(?:bne|jmp)\s+'+re.escape(first)+r'\s*$)',re.M)
            assert len(branch.findall(labelled))==1,(name,probe)
            labelled=branch.sub(r'\1\n'+last+':',labelled)
        (out/(name+'.labels.s')).write_text(labelled)
        run([tool/'llvm-mc','-triple=mos','-mcpu=mosw65816','-mattr='+features,'-filetype=obj',out/(name+'.labels.s'),'-o',out/(name+'.labels.o')],name+'-labels')
        plain=run([tool/'llvm-objdump','-dr','--mcpu=mosw65816',out/(name+'.o')],name+'-plain-dis')
        lab=run([tool/'llvm-objdump','-dr','--mcpu=mosw65816',out/(name+'.labels.o')],name+'-labels-dis')
        assert code(plain)==code(lab), name+' instructions changed by labels'
        # Code relocations must also agree; branch labels are resolved by the assembler.
        rel=lambda d:[l.strip() for l in d.splitlines() if 'R_MOS_' in l]
        assert rel(plain)==rel(lab), name+' relocations changed by labels'
        rom=out/(name+'.sfc')
        run([tool/'mos-clang','--config',root/'build/install/bin/mos-snes-hirom.cfg','-mcpu=mosw65816','-Os','-fno-lto',out/(name+'.labels.o'),root/'build/farblit_tbl.s','-Wl,-Map='+str(out/(name+'.map')),'-o',rom],name+'-link')
        run(['python3',root/'tools/snes-checksum.py','--hirom',rom],name+'-checksum')
        syms=symbols(Path(str(rom)+'.elf'),name)
        run([tool/'llvm-objdump','-d',Path(str(rom)+'.elf')],name+'-linked-dis')
        resultoff,resultlen=syms['corpus_result']
        regions['main']=['main',None]
        row={'variant':variant,'mode':mode,'main_bytes':syms['main'][1],'rom_bytes':rom.stat().st_size,'rom_sha256':hashlib.sha256(rom.read_bytes()).hexdigest(),'regions':{}}
        for probe,(first,last) in regions.items():
            start=syms[first][0]; stop=syms[last][0] if last else 0xffffffff
            end=stop if last else start+syms['main'][1]
            cmd=[root/'.scratch/carry-timing/jgxcycles-verified',rom,root/'vendor/bsnes-jg/Database',hex(start),hex(end),hex(stop),hex(resultoff),resultlen,hex(expected),240,1]
            samples=[json.loads(run(cmd,name+'-'+probe+'-timing-'+str(k))) for k in range(2)]
            assert samples[0]==samples[1] and samples[0]['pass'],name+' '+probe
            row['regions'][probe]={'bytes':end-start,'start':start,'stop':stop,'master_clocks':sum(samples[0]['samples']),'instructions':samples[0]['instructions'],'repeat_identical':True}
        rows.append(row)
        (work/'results.json').write_text(json.dumps({'expected':expected,'rows':rows},indent=2)+'\n')
        print(name,row['main_bytes'],{k:v['master_clocks'] for k,v in row['regions'].items()},flush=True)
