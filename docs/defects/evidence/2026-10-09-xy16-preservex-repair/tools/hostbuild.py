#!/usr/bin/env python3
"""Recompile one MOS TU with host g++ and relink a tool from an existing
LLVM build dir (paths as seen inside wrap.sh, i.e. /work/...).
usage: hostbuild.py BUILD_DIR(in-ns) TU_REL(src-relative path in compile db) SRC_COPY OUT_DIR TOOL..."""
import json, shlex, subprocess, sys, os, re
bdir, tu_rel, src_copy, out = sys.argv[1:5]; tools = sys.argv[5:]
CLANG_ONLY = {'-Werror=unguarded-availability-new', '-Wc++98-compat-extra-semi',
              '-Wcovered-switch-default', '-Wstring-conversion', '-Wno-pass-failed',
              '-Wctad-maybe-unsupported', '-Winvalid-pch', '-fdiagnostics-color'}
def filt(args):
    r, i = [], 0
    while i < len(args):
        a = args[i]
        if a == '-Xclang': i += 2; continue
        if a in CLANG_ONLY: i += 1; continue
        r.append(a); i += 1
    return r
os.makedirs(out, exist_ok=True)
db = json.load(open(f'{bdir}/compile_commands.json'))
ent = [e for e in db if e['file'].endswith(tu_rel)]
assert len(ent) == 1, ent
args = shlex.split(ent[0]['command'])
objrel = args[args.index('-o') + 1]
args = filt(args)
args[0] = 'g++'
args[args.index('-o') + 1] = f'{out}/fixed.o'
args[args.index('-c') + 1] = src_copy
print('COMPILE:', ' '.join(args), flush=True)
subprocess.run(args, cwd=ent[0]['directory'], check=True)
nin = open(f'{bdir}/build.ninja').read()
for tool in tools:
    m = re.search(rf'^build bin/{re.escape(tool)}: (\S+) (.*?)(?: \|.*)?\n((?:  .*\n)+)', nin, re.M)
    rule, ins, block = m.group(1), m.group(2), m.group(3)
    var = dict(re.findall(r'^  (\w+) = (.*)$', block, re.M))
    link = var.get('LINK_FLAGS', '').replace('-fuse-ld=lld', '-fuse-ld=bfd')
    link = link.replace('-Wl,--color-diagnostics', '')
    link = re.sub(r'-Xlinker --dependency-file=\S+', '', link)
    libs = var.get('LINK_LIBRARIES', '').replace('$$', '$')
    flags = ' '.join(filt(shlex.split(var.get('FLAGS', ''))))
    objs = ins.split()
    # The replacement object precedes the archives, so the archive member that
    # defines the same symbols is never pulled in.
    cmd = f'g++ {flags} {link} {out}/fixed.o {" ".join(objs)} -o {out}/{tool} {var.get("LINK_PATH", "")} {libs}'
    print('LINK:', tool, flush=True)
    subprocess.run(cmd, shell=True, cwd=bdir, check=True)
