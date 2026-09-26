from pathlib import Path
import re
import shutil

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent / "native-tests"
out.mkdir(exist_ok=True)
for number in (61, 62):
    patch = next((root / "patches/llvm-mos").glob(f"{number:04d}-*.patch"))
    for part in patch.read_text().split("diff --git ")[1:]:
        lines = part.splitlines()
        target = lines[0].split(" b/", 1)[1]
        if "/test/" not in target or "--- /dev/null" not in lines:
            continue
        body = []
        in_hunk = False
        for line in lines[1:]:
            if line.startswith("@@"):
                in_hunk = True
                continue
            if in_hunk and line.startswith("+"):
                body.append(line[1:])
        expected = int(re.search(r"@@ -0,0 \+1,(\d+) @@", part).group(1))
        assert len(body) == expected, (target, expected, len(body))
        (out / Path(target).name).write_text("\n".join(body) + "\n")
        assert (out / Path(target).name).read_bytes() == (root / "vendor/llvm-mos" / target).read_bytes(), target
for name in ("a16-byte-store.ll", "a16-indirect-byte-store.ll"):
    shutil.copyfile(root / "vendor/llvm-mos/llvm/test/CodeGen/MOS" / name, out / name)
