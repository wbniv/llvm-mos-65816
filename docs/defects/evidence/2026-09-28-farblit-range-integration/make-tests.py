from pathlib import Path
w=Path(__file__).resolve().parent
cases=[
 dict(name='ne_backedge'),dict(name='eq_exit',exit=True),dict(name='nonzero_start',start=17),
 dict(name='unsigned_end',end=248),dict(name='offset_256',end=249,fold=False),
 dict(name='wrapped_induction',start=250,end=6,fold=False),dict(name='full_cycle',end=0,fold=False),
 dict(name='equal_start_end',start=48,end=48,fold=False),dict(name='step_two',step=2,fold=False),
 dict(name='eq_backedge',polarity=1,fold=False),dict(name='ne_exit',exit=True,polarity=0,fold=False),
 dict(name='compare_phi',lhs='%iv',fold=False),dict(name='borrow_input',carry=0,fold=False),
 dict(name='carry_flag',flag='%carryout',fold=False),dict(name='negative_flag',flag='%negative',fold=False),
 dict(name='overflow_flag',flag='%overflow',fold=False),
 dict(name='zero_copy',copies=1),dict(name='four_copies',copies=4),dict(name='five_copies',copies=5,fold=False),
 dict(name='scale_fits',end=124,scale=True),dict(name='scale_overflows_y',end=129,scale=True,fold=False),
 dict(name='narrow_scale_wraps',end=140,narrow=True,fold=False),
 dict(name='narrow_add_wraps',wrap=True,fold=False),dict(name='multiple_blocks',multiblock=True,fold=False),
 dict(name='generic_ne',generic=True),dict(name='generic_eq',generic=True,exit=True),
]
header='''# RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -run-pass=legalizer -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=A16
# RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -run-pass=legalizer -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=XY16
# RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -mos-far-loop-range=false -run-pass=legalizer -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=OFF
#
# A byte induction value is bounded only when a unit increment reaches a larger
# constant before wrapping. Both exit orientations use the SBC zero result with
# carry set. Other flags, steps, wrapping recurrences and control-flow shapes
# retain their known-bits bounds. Constant displacement and scaling must fit Y.
# Generic comparisons exercise branch legalization before the memory fold.
'''
parts=[header]
for c in cases:
 n=c['name'];fold=c.get('fold',True)
 # The narrow scale/add cases retain a full byte bound plus displacement eight.
 xy='G_LOAD_FAR_INDIR_IDX' if fold else 'G_LOAD_FAR_INDIR_IDX16'
 checks=f'# A16-LABEL: name: {n}\n# A16: = '+('G_LOAD_FAR_INDIR_IDX ' if fold else 'G_LOAD_FAR_INDIR ')+'\n'
 checks+=f'# XY16-LABEL: name: {n}\n# XY16: = {xy} \n# OFF-LABEL: name: {n}\n# OFF: = G_LOAD_FAR_INDIR \n'
 start=c.get('start',0);end=c.get('end',48);step=c.get('step',1);carry=c.get('carry',1)
 back='%bb.3' if c.get('multiblock') else '%bb.1';dest='%bb.2' if c.get('exit') else back;other=back if c.get('exit') else '%bb.2'
 polarity=c.get('polarity',int(c.get('exit',False)))
 offset='    %off:_(s32) = G_ZEXT %iv(s8)\n'
 if c.get('scale'):offset='    %wide:_(s32) = G_ZEXT %iv(s8)\n    %off:_(s32) = G_SHL %wide, %shift\n'
 if c.get('narrow'):offset='    %small:_(s8) = G_SHL %iv, %step\n    %off:_(s32) = G_ZEXT %small(s8)\n'
 if c.get('wrap'):offset='    %small:_(s8) = G_ADD %iv, %wrapadd\n    %off:_(s32) = G_ZEXT %small(s8)\n'
 comparison=f'    %sub:_(s8), %carryout:_(s1), %negative:_(s1), %overflow:_(s1), %zero:_(s1) = G_SBC {c.get("lhs","%next")}, %end, %carry\n'
 flag=c.get('flag','%zero')
 for i in range(c.get('copies',0)):
  comparison+=f'    %copy{i}:_(s1) = COPY {flag}(s1)\n';flag=f'%copy{i}'
 comparison+=f'    G_BRCOND_IMM {flag}(s1), {dest}, {polarity}\n'
 if c.get('generic'):comparison=f'    %cond:_(s1) = G_ICMP intpred({"eq" if c.get("exit") else "ne"}), %next(s8), %end\n    G_BRCOND %cond(s1), {dest}\n'
 parts.append(checks+f'''---
name: {n}
tracksRegLiveness: true
body: |
  bb.0:
    successors: %bb.1
    liveins: $rs0, $rs2
    %lo:_(s16) = COPY $rs0
    %hi:_(s16) = COPY $rs2
    %raw:_(s32) = G_MERGE_VALUES %lo(s16), %hi(s16)
    %base:_(p2) = G_INTTOPTR %raw(s32)
    %start:_(s8) = G_CONSTANT i8 {start}
    %end:_(s8) = G_CONSTANT i8 {end}
    %step:_(s8) = G_CONSTANT i8 {step}
    %carry:_(s1) = G_CONSTANT i1 {carry}
    %disp:_(s32) = G_CONSTANT i32 8
    %shift:_(s32) = G_CONSTANT i32 1
    %wrapadd:_(s8) = G_CONSTANT i8 248
    G_BR %bb.1
  bb.1:
    successors: {back}, %bb.2
    %iv:_(s8) = G_PHI %start(s8), %bb.0, %next(s8), {back}
{offset}    %ptr:_(p2) = G_PTR_ADD %base, %off(s32)
    %addr:_(p2) = G_PTR_ADD %ptr, %disp(s32)
    %value:_(s8) = G_LOAD %addr(p2) :: (volatile load (s8), addrspace 2)
    %next:_(s8) = G_ADD %iv, %step
{comparison}    G_BR {other}
  bb.2:
    RTS
'''+('  bb.3:\n    successors: %bb.1\n    G_BR %bb.1\n' if c.get('multiblock') else '')+'...\n')
(w/'source/far-loop-range.mir').write_text('\n'.join(parts))
