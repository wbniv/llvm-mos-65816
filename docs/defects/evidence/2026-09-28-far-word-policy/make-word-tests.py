from pathlib import Path
w=Path('.scratch/far-word-policy')
s=(w/'source/far-loop-range.mir').read_text()
a=s.index('---\nname: ne_backedge');b=s.index('...\n',a)+4
base=s[a:b].replace('name: ne_backedge','name: NAME').replace('i8 48','i8 128').replace('i32 8','i32 0').replace('%off:_(s32) = G_ZEXT %iv(s8)','%wide:_(s32) = G_ZEXT %iv(s8)\n    %off:_(s32) = G_SHL %wide, %shift').replace('%value:_(s8) = G_LOAD %addr(p2) :: (volatile load (s8)', '%value:_(s16) = G_LOAD %addr(p2) :: (volatile load (s16)')
cases=[]
def add(name,attr='',change=None,on=True):
 text=base.replace('NAME',name)
 if change:text=change(text)
 cases.append((name,attr,text,on))
add('word_speed')
add('word_size','optsize')
add('word_minsize','minsize optsize')
add('word_noopt','noinline optnone')
add('word129',change=lambda s:s.replace('i8 128','i8 129'),on=False)
add('word_wrap',change=lambda s:s.replace('i8 0','i8 250').replace('i8 128','i8 6'),on=False)
add('word_nonunit',change=lambda s:s.replace('i8 1\n','i8 2\n'),on=False)
add('word_fullcycle',change=lambda s:s.replace('i8 128','i8 0'),on=False)
load='%value:_(s16) = G_LOAD %addr(p2) :: (volatile load (s16), addrspace 2)'
def mixed(s,disp,first):
 extra=f'%extra:_(s32) = G_CONSTANT i32 {disp}\n    %byteptr:_(p2) = G_PTR_ADD %ptr, %extra(s32)\n    %byte:_(s8) = G_LOAD %byteptr(p2) :: (volatile load (s8), addrspace 2)'
 return s.replace(load,extra+'\n    '+load if first else load+'\n    '+extra)
for disp in [1,2]:
 for first in [True,False]:add(f'mixed_{disp}_{int(first)}',change=lambda s,d=disp,f=first:mixed(s,d,f),on=disp==1)
header='''# RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -mos-far-word-index=speed -run-pass=legalizer -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=SPEED
# RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -mos-far-word-index=speed -run-pass=legalizer -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=SPEED
# RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -mos-far-word-index=all -run-pass=legalizer -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=ALL
# RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -mos-far-word-index=all -run-pass=legalizer -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=ALL
# RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -mos-far-word-index=off -run-pass=legalizer -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=OFF
#
# The final byte of every sibling must fit Y8, including when the byte access
# is visited before a word. Speed policy respects function size and no-opt
# attributes. Wrapping and non-unit inductions retain explicit word pointers.
--- |
'''
for name,attr,_,_ in cases:header+=f'  define void @{name}() {attr} {{ ret void }}\n'
header+='...\n'
for name,attr,body,on in cases:
 for prefix,fold in [('SPEED',on and not attr),('ALL',on),('OFF',False)]:
  header+=f'# {prefix}-LABEL: name: {name}\n# {prefix}: = G_LOAD16_FAR_INDIR'+('_IDX ' if fold else ' ')+'\n'
 header+=body+'\n'
runline=header.splitlines()[0]
header=(runline.replace(' -mos-far-word-index=speed','')+'\n'+
        runline.replace(' -mos-far-word-index=speed',' -O3')+'\n'+
        runline.replace(' -mos-far-word-index=speed',' -O0').replace('=SPEED','=OFF')+'\n'+
        runline.replace(' -mos-far-word-index=speed',' -O1').replace('=SPEED','=OFF')+'\n'+header)
header=header.replace('G_LOAD16_FAR_INDIR \n','G_LOAD16_FAR_INDIR{{ }}\n').replace('G_LOAD16_FAR_INDIR_IDX \n','G_LOAD16_FAR_INDIR_IDX\n')
(w/'source/far-word-policy.mir').write_text(header)
