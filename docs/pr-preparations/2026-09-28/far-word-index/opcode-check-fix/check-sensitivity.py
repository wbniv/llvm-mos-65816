#!/usr/bin/env python3
"""Require exact far-load opcode assertions on captured legalizer output."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--filecheck", required=True, type=Path)
    parser.add_argument("--checks", required=True, type=Path)
    parser.add_argument("--inputs", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    checks = args.checks.read_text()
    variants = ("G_LOAD_FAR_INDIR", "G_LOAD_FAR_INDIR_IDX", "G_LOAD_FAR_INDIR_IDX16")
    opcode = re.compile(r"\bG_LOAD_FAR_INDIR(?:_IDX(?:16)?)?\b")
    results = []
    positives = []
    for prefix in ("A16", "XY16", "OFF"):
        command = [str(args.filecheck.resolve()), str(args.checks.resolve()),
                   "--check-prefix=" + prefix]
        source = args.inputs / (prefix.lower() + ".mir")
        data = source.read_text()
        positive = subprocess.run(command, input=data, text=True, capture_output=True)
        positives.append({"prefix": prefix, "command": command,
                          "input_sha256": digest(data.encode()),
                          "returncode": positive.returncode, "stderr": positive.stderr})
        expected = re.findall(
            r"^# " + prefix + r"-LABEL: name: (\w+)\n# " + prefix
            + r": = (G_LOAD_FAR_INDIR(?:_IDX(?:16)?)?)", checks, re.MULTILINE)
        names = list(re.finditer(r"^name:[ \t]+(\w+)[ \t]*$", data, re.MULTILINE))
        sections = {match[1]: (match.end(), names[i + 1].start()
                              if i + 1 < len(names) else len(data))
                    for i, match in enumerate(names)}
        if len(expected) != len(sections) or len(expected) != 26:
            raise ValueError(f"{prefix}: require one assertion for each of 26 functions")
        for name, wanted in expected:
            start, end = sections[name]
            matches = list(opcode.finditer(data, start, end))
            if len(matches) != 1 or matches[0][0] != wanted:
                raise ValueError(f"{prefix}/{name}: input must contain exactly {wanted}")
            match = matches[0]
            # Each input differs in exactly one complete opcode token. Retaining
            # all other functions lets FileCheck exercise the real label scopes.
            for replacement in variants:
                if replacement == wanted:
                    continue
                mutant = data[:match.start()] + replacement + data[match.end():]
                result = subprocess.run(command, input=mutant, text=True, capture_output=True)
                results.append({"prefix": prefix, "function": name,
                                "expected": wanted, "replacement": replacement,
                                "input_sha256": digest(mutant.encode()),
                                "returncode": result.returncode, "stderr": result.stderr})
    summary = {"positive_passes": sum(row["returncode"] == 0 for row in positives),
               "positive_runs": len(positives), "expectations": len(results) // 2,
               "mutations": len(results),
               "rejected": sum(row["returncode"] == 1 for row in results),
               "accepted_wrong_opcodes": sum(row["returncode"] == 0 for row in results),
               "unexpected_exit_codes": sum(row["returncode"] not in (0, 1)
                                            for row in results)}
    report = {"checks_sha256": digest(args.checks.read_bytes()),
              "filecheck_sha256": digest(args.filecheck.read_bytes()),
              "runner_sha256": digest(Path(__file__).read_bytes()),
              "summary": summary, "positive_runs": positives, "mutations": results}
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(summary, sort_keys=True))
    return 0 if (summary["positive_passes"] == 3 and summary["rejected"] == 156) else 1


if __name__ == "__main__":
    raise SystemExit(main())
