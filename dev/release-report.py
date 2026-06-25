#!/usr/bin/env python3
# dev/release-report.py — render the clean-room release-test results into ONE
# self-contained HTML report (docs/plans/2026-06-25-test-published-snes-compiler.md §D).
#
# Inputs come from a run of dev/test-release.sh:
#   --data       release-report-data.tsv written by the in-container driver
#                (meta/build/doc rows; see dev/release-test-inner.sh)
#   --log        release-test-<method>.log (the timestamped compile+emulation transcript)
#   --artifacts  dir holding the screenshots (mandel-host.png, mandel-<build>.png)
#   --out        output .html path
# Optional host-known package facts (METHOD=local):
#   --tarball-name / --tarball-size / --tarball-sha / --stamp
#
# The screenshots are base64-embedded so the report is a single portable file.
# No third-party deps — stdlib only.
import argparse, base64, html, os, sys


def parse_data(path):
    meta, builds, docs, exes = {}, [], [], []
    if not path or not os.path.exists(path):
        return meta, builds, docs, exes
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            kind = parts[0]
            if kind == "meta" and len(parts) >= 3:
                meta[parts[1]] = "\t".join(parts[2:])
            elif kind == "build" and len(parts) >= 9:
                builds.append({
                    "label": parts[1], "flags": parts[2], "sfc": parts[3],
                    "got": parts[4], "verdict": parts[5],
                    "compile_s": parts[6], "emulate_s": parts[7], "shot": parts[8],
                })
            elif kind == "doc" and len(parts) >= 4:
                docs.append({"name": parts[1], "bytes": parts[2], "type": parts[3]})
            elif kind == "exe" and len(parts) >= 4:
                exes.append({"name": parts[1], "bytes": parts[2], "kind": parts[3]})
    return meta, builds, docs, exes


def human(n):
    try:
        n = float(n)
    except (TypeError, ValueError):
        return "?"
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024


def img_data_uri(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")


def esc(s):
    return html.escape(str(s if s is not None else ""))


# Canonical reader-doc reading order (mirrors dev/build-release-docs.sh) — the report
# lists docs in this order, not alphabetically. README first; unknown docs sort last.
DOC_ORDER = ["readme", "65816-opcodes", "snes-hardware", "snes-registers",
             "snes-bootup", "emulator-screenshots", "oop-in-c"]


def doc_sort_key(d):
    stem = os.path.splitext(os.path.basename(d["name"]))[0].lower()
    rank = DOC_ORDER.index(stem) if stem in DOC_ORDER else len(DOC_ORDER)
    return (rank, stem, 0 if d.get("type") == "md" else 1)


CSS = """
:root{--bg:#0f1117;--panel:#171a23;--ink:#e6e8ee;--muted:#9aa3b2;--line:#2a2f3a;
      --grn:#3fb950;--red:#f85149;--accent:#58a6ff;--mono:'JetBrains Mono',ui-monospace,Menlo,Consolas,monospace}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1000px;margin:0 auto;padding:32px 24px 80px}
header{border:1px solid var(--line);border-radius:14px;padding:22px 26px;
       background:linear-gradient(135deg,#1b2030,#12151d)}
h1{margin:0 0 4px;font-size:22px;letter-spacing:.2px}
.sub{color:var(--muted);font-size:13px}
.badge{display:inline-block;padding:4px 12px;border-radius:999px;font-weight:700;font-size:13px;letter-spacing:.4px}
.badge.pass{background:rgba(63,185,80,.15);color:var(--grn);border:1px solid rgba(63,185,80,.4)}
.badge.fail{background:rgba(248,81,73,.15);color:var(--red);border:1px solid rgba(248,81,73,.4)}
h2{font-size:15px;text-transform:uppercase;letter-spacing:1.2px;color:var(--accent);margin:34px 0 12px}
.panel{border:1px solid var(--line);border-radius:12px;background:var(--panel);overflow:hidden}
table{border-collapse:collapse;width:100%;font-size:14px}
th,td{text-align:left;padding:9px 14px;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--muted);font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.6px}
tr:last-child td{border-bottom:none}
td.mono,.k{font-family:var(--mono);font-size:13px}
.k{color:var(--muted);white-space:nowrap;width:1%}
.pass{color:var(--grn);font-weight:700}.fail{color:var(--red);font-weight:700}
.shots{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:18px}
.shot{border:1px solid var(--line);border-radius:12px;background:var(--panel);padding:12px;text-align:center}
.shot img{width:100%;image-rendering:pixelated;border-radius:6px;background:#000}
.shot .cap{margin-top:8px;font-size:12px;color:var(--muted)}
pre{background:#0b0d12;border:1px solid var(--line);border-radius:12px;padding:16px 18px;overflow:auto;
    font-family:var(--mono);font-size:12.5px;line-height:1.5;color:#c9d1d9}
.foot{margin-top:40px;color:var(--muted);font-size:12px;text-align:center}
.total{color:var(--muted);font-size:12px;padding:8px 14px}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--log", required=True)
    ap.add_argument("--artifacts", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--tarball-name", default="")
    ap.add_argument("--tarball-size", default="")
    ap.add_argument("--tarball-sha", default="")
    ap.add_argument("--stamp", default="")
    a = ap.parse_args()

    meta, builds, docs, exes = parse_data(a.data)
    docs = sorted(docs, key=doc_sort_key)   # canonical reading order, not alphabetical
    result = meta.get("result", "FAIL")
    ok = result == "PASS"

    # --- header --------------------------------------------------------------
    parts = []
    parts.append('<div class="wrap"><header>')
    parts.append('<div style="display:flex;justify-content:space-between;align-items:flex-start;gap:16px">')
    parts.append("<div><h1>llvm-mos-65816 — release verification report</h1>"
                 f'<div class="sub">clean-room test of the <b>published</b> SNES compiler · '
                 f'generated {esc(meta.get("finished", ""))}</div></div>')
    parts.append(f'<span class="badge {"pass" if ok else "fail"}">{esc(result)}</span>')
    parts.append("</div></header>")

    def kv_table(rows):
        out = ['<div class="panel"><table>']
        for k, v in rows:
            if v in (None, ""):
                continue
            out.append(f'<tr><td class="k">{esc(k)}</td><td class="mono">{esc(v)}</td></tr>')
        out.append("</table></div>")
        return "".join(out)

    # --- release package -----------------------------------------------------
    parts.append("<h2>Release package</h2>")
    pkg_rows = [
        ("tarball", a.tarball_name or meta.get("pkg_url", "")),
        ("size", human(a.tarball_size) if a.tarball_size else None),
        ("sha256", a.tarball_sha or None),
        ("version / stamp", a.stamp or meta.get("pkg_version", "")),
        ("source", meta.get("pkg_source", "")),
        ("compiler", meta.get("compiler_version", "")),
        ("compiler path", meta.get("compiler_path", "")),
        ("install tree", human(meta.get("tree_bytes")) if meta.get("tree_bytes") else None),
    ]
    parts.append(kv_table(pkg_rows))

    # --- bundled documentation ----------------------------------------------
    parts.append("<h2>Bundled documentation</h2>")
    if docs:
        rows = ['<div class="panel"><table><tr><th>document</th><th>type</th><th>size</th></tr>']
        total = 0
        for d in docs:
            try:
                total += int(d["bytes"])
            except ValueError:
                pass
            rows.append(f'<tr><td class="mono">{esc(d["name"])}</td>'
                        f'<td class="mono">{esc(d["type"]).upper()}</td>'
                        f'<td class="mono">{human(d["bytes"])}</td></tr>')
        rows.append(f'<tr><td class="total" colspan="3">{len(docs)} file(s), {human(total)} total</td></tr>')
        rows.append("</table></div>")
        parts.append("".join(rows))
    else:
        parts.append('<div class="panel"><div class="total">no .md/.pdf docs found in the package</div></div>')

    # --- executables ---------------------------------------------------------
    parts.append("<h2>Executables</h2>")
    if exes:
        rows = ['<div class="panel"><table><tr><th>file</th><th>size</th><th>kind</th></tr>']
        bin_total = 0
        for e in exes:
            is_bin = e["kind"] == "binary"
            if is_bin:
                try:
                    bin_total += int(e["bytes"])
                except ValueError:
                    pass
            size = human(e["bytes"]) if is_bin else "—"
            rows.append(f'<tr><td class="mono">{esc(e["name"])}</td>'
                        f'<td class="mono">{size}</td>'
                        f'<td class="mono">{esc(e["kind"])}</td></tr>')
        nbin = sum(1 for e in exes if e["kind"] == "binary")
        extra = ""
        if meta.get("bin_total"):
            try:
                others = int(meta["bin_total"]) - len(exes)
                if others > 0:
                    extra = f" · +{others} other per-platform driver symlinks/.cfg in bin/"
            except ValueError:
                pass
        rows.append(f'<tr><td class="total" colspan="3">{nbin} binaries, {human(bin_total)} total{extra}</td></tr>')
        rows.append("</table></div>")
        parts.append("".join(rows))
    else:
        parts.append('<div class="panel"><div class="total">no executables recorded</div></div>')

    # --- configuration -------------------------------------------------------
    parts.append("<h2>Configuration</h2>")
    cfg_rows = [
        ("method", meta.get("method", "")),
        ("program / grid", f'{meta.get("program","")}  ({meta.get("grid","")})'),
        ("builds tested", ", ".join(b["label"] for b in builds)),
        ("oracle CRC", meta.get("oracle", "")),
        ("frames", meta.get("frames", "")),
        ("emulator", f'bsnes-jg {meta.get("bsnes","?")} (embedded SPC700 IPL — no BIOS, no sound)'),
        ("rig base", meta.get("ubuntu", "")),
        ("host", f'{meta.get("host_arch","")} · {meta.get("host_cpus","")} CPU'),
        ("started", meta.get("started", "")),
        ("finished", meta.get("finished", "")),
    ]
    parts.append(kv_table(cfg_rows))

    # --- results -------------------------------------------------------------
    parts.append("<h2>Results</h2>")
    rrows = ['<div class="panel"><table>'
             '<tr><th>build</th><th>flags</th><th>ROM</th><th>got</th><th>expect</th>'
             '<th>compile</th><th>emulate</th><th>verdict</th></tr>']
    oracle = meta.get("oracle", "")
    for b in builds:
        vcls = "pass" if b["verdict"] == "PASS" else "fail"
        rrows.append(
            f'<tr><td class="mono">{esc(b["label"])}</td>'
            f'<td class="mono">{esc(b["flags"] or "—")}</td>'
            f'<td class="mono">{human(b["sfc"])}</td>'
            f'<td class="mono">{esc(b["got"])}</td>'
            f'<td class="mono">{esc(oracle)}</td>'
            f'<td class="mono">{esc(b["compile_s"])}s</td>'
            f'<td class="mono">{esc(b["emulate_s"])}s</td>'
            f'<td class="{vcls}">{esc(b["verdict"])}</td></tr>')
    rrows.append("</table></div>")
    parts.append("".join(rrows))

    # --- screenshots ---------------------------------------------------------
    shots = []
    host_png = os.path.join(a.artifacts, "mandel-host.png")
    if os.path.exists(host_png):
        shots.append((host_png, f'host reference ({meta.get("grid","")})'))
    for b in builds:
        p = os.path.join(a.artifacts, b["shot"])
        if b["shot"] and os.path.exists(p):
            shots.append((p, f'SNES @ bsnes-jg — {b["label"]} (got {b["got"]})'))
    if shots:
        parts.append("<h2>Screenshots</h2><div class=\"shots\">")
        for p, cap in shots:
            parts.append(f'<div class="shot"><img alt="{esc(cap)}" src="{img_data_uri(p)}">'
                         f'<div class="cap">{esc(cap)}</div></div>')
        parts.append("</div>")

    # --- log -----------------------------------------------------------------
    parts.append("<h2>Compile &amp; emulation log</h2>")
    try:
        with open(a.log, encoding="utf-8", errors="replace") as f:
            log_txt = f.read()
    except OSError:
        log_txt = "(log unavailable)"
    parts.append(f"<pre>{esc(log_txt)}</pre>")

    parts.append('<div class="foot">llvm-mos-65816 clean-room release test · '
                 'docs/plans/2026-06-25-test-published-snes-compiler.md</div>')
    parts.append("</div>")

    doc = ("<!doctype html><html lang=en><head><meta charset=utf-8>"
           "<meta name=viewport content=\"width=device-width,initial-scale=1\">"
           f"<title>llvm-mos-65816 release report — {esc(a.stamp or result)}</title>"
           f"<style>{CSS}</style></head><body>{''.join(parts)}</body></html>")
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(doc)

    # --- Markdown sibling (previews via `task md`, feeds the PDF pipeline) ----
    # Screenshots are referenced by relative path (the .md lives next to the PNGs),
    # so the report stays small and renders in the repo's md workflow.
    md_path = os.path.splitext(a.out)[0] + ".md"
    write_markdown(md_path, meta, builds, docs, exes, a, shots, log_txt, result)

    print(f"release-report: wrote {a.out} ({len(doc)//1024} KiB) + {os.path.basename(md_path)} "
          f"({len(shots)} screenshot(s), {len(docs)} doc(s))")
    return 0


def md_cell(s):
    return str(s if s is not None else "").replace("|", "\\|").replace("\n", " ") or "—"


def write_markdown(path, meta, builds, docs, exes, a, shots, log_txt, result):
    L = []
    L.append("# llvm-mos-65816 — release verification report")
    L.append("")
    L.append(f"**RESULT: {result}** · clean-room test of the *published* SNES compiler · "
             f"generated {meta.get('finished','')}"
             + (f" · `{a.stamp}`" if a.stamp else ""))
    L.append("")

    L.append("## Release package")
    L.append("")
    L.append("| field | value |")
    L.append("|---|---|")
    for k, v in [
        ("tarball", a.tarball_name or meta.get("pkg_url", "")),
        ("size", human(a.tarball_size) if a.tarball_size else ""),
        ("sha256", a.tarball_sha or ""),
        ("version / stamp", a.stamp or meta.get("pkg_version", "")),
        ("source", meta.get("pkg_source", "")),
        ("compiler", meta.get("compiler_version", "")),
        ("compiler path", meta.get("compiler_path", "")),
        ("install tree", human(meta.get("tree_bytes")) if meta.get("tree_bytes") else ""),
    ]:
        if v:
            L.append(f"| {md_cell(k)} | `{md_cell(v)}` |")
    L.append("")

    L.append("## Bundled documentation")
    L.append("")
    if docs:
        L.append("| document | type | size |")
        L.append("|---|---|---|")
        total = 0
        for d in docs:
            try:
                total += int(d["bytes"])
            except ValueError:
                pass
            L.append(f"| `{md_cell(d['name'])}` | {md_cell(d['type']).upper()} | {human(d['bytes'])} |")
        L.append("")
        L.append(f"*{len(docs)} file(s), {human(total)} total.*")
    else:
        L.append("*No .md/.pdf docs found in the package.*")
    L.append("")

    L.append("## Executables")
    L.append("")
    if exes:
        L.append("| file | size | kind |")
        L.append("|---|---|---|")
        bin_total = 0
        for e in exes:
            is_bin = e["kind"] == "binary"
            if is_bin:
                try:
                    bin_total += int(e["bytes"])
                except ValueError:
                    pass
            size = human(e["bytes"]) if is_bin else "—"
            L.append(f"| `{md_cell(e['name'])}` | {size} | {md_cell(e['kind'])} |")
        nbin = sum(1 for e in exes if e["kind"] == "binary")
        extra = ""
        if meta.get("bin_total"):
            try:
                others = int(meta["bin_total"]) - len(exes)
                extra = f" · +{others} other per-platform driver symlinks/.cfg in `bin/`" if others > 0 else ""
            except ValueError:
                pass
        L.append("")
        L.append(f"*{nbin} binaries, {human(bin_total)} total{extra}.*")
    else:
        L.append("*No executables recorded.*")
    L.append("")

    L.append("## Configuration")
    L.append("")
    L.append("| field | value |")
    L.append("|---|---|")
    for k, v in [
        ("method", meta.get("method", "")),
        ("program / grid", f'{meta.get("program","")} ({meta.get("grid","")})'),
        ("builds tested", ", ".join(b["label"] for b in builds)),
        ("oracle CRC", meta.get("oracle", "")),
        ("frames", meta.get("frames", "")),
        ("emulator", f'bsnes-jg {meta.get("bsnes","?")} (embedded SPC700 IPL — no BIOS, no sound)'),
        ("rig base", meta.get("ubuntu", "")),
        ("host", f'{meta.get("host_arch","")} · {meta.get("host_cpus","")} CPU'),
        ("started", meta.get("started", "")),
        ("finished", meta.get("finished", "")),
    ]:
        if v.strip(" ()·"):
            L.append(f"| {md_cell(k)} | {md_cell(v)} |")
    L.append("")

    L.append("## Results")
    L.append("")
    L.append("| build | flags | ROM | got | expect | compile | emulate | verdict |")
    L.append("|---|---|---|---|---|---|---|---|")
    oracle = meta.get("oracle", "")
    for b in builds:
        L.append(f"| `{md_cell(b['label'])}` | `{md_cell(b['flags'] or '—')}` | {human(b['sfc'])} | "
                 f"`{md_cell(b['got'])}` | `{md_cell(oracle)}` | {md_cell(b['compile_s'])}s | "
                 f"{md_cell(b['emulate_s'])}s | **{md_cell(b['verdict'])}** |")
    L.append("")

    if shots:
        L.append("## Screenshots")
        L.append("")
        for p, cap in shots:
            L.append(f"**{md_cell(cap)}**")
            L.append("")
            L.append(f'<img src="{os.path.basename(p)}" width="384" style="image-rendering:pixelated">')
            L.append("")

    L.append("## Compile & emulation log")
    L.append("")
    L.append("```")
    L.append(log_txt.rstrip("\n"))
    L.append("```")
    L.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L))


if __name__ == "__main__":
    sys.exit(main())
