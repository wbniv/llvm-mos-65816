#!/usr/bin/env python3
"""Progress on a separate descriptor; child output and exit codes stay intact."""
import argparse
from contextlib import contextmanager
import os
import re
import selectors
import shutil
import signal
import subprocess
import sys
import threading
import time


def style_progress_line(line, width):
    """Render a single terminal row without changing progress snapshots or verdicts."""
    line = re.sub(r"\[([#-]{20})\]", lambda match:
                  "│" + match.group(1).replace("#", "█").replace("-", "░") + "│", line)
    line = line[:max(0, width)]
    if "NO_COLOR" in os.environ:
        return line
    label = line.split(" ", 1)[0]
    color = {"VERIFY": "36", "EMU": "35", "PACE": "32", "BUILD": "34",
             "REBUILD": "33", "LIVE": "36", "DEPLOY": "34"}.get(label, "36")
    if line.startswith(label + " "):
        line = f"\x1b[1;{color}m{label}\x1b[0m" + line[len(label):]
    if label == "PACE":
        line = re.sub(r"([▁▂▃▄▅▆▇█·]+)(?= \|)",
                      lambda match: f"\x1b[1;32m{match.group(1)}\x1b[0m", line)
    line = re.sub(r"│([█░]{20})│", lambda match:
                  f"\x1b[{color}m│\x1b[1;{color}m{match.group(1).split('░')[0]}"
                  f"\x1b[2;37m{'░' * match.group(1).count('░')}\x1b[{color}m│\x1b[0m", line)
    def paint_status(match):
        tone = "32" if match.group(1) == "PASS" else (
            "2;37" if match.group(2) == "0" else
            "31" if match.group(1) == "FAIL" else "33")
        return f"\x1b[{tone}m{match.group(0)}\x1b[0m"
    line = re.sub(r"\b(PASS|FAIL|MISSING) (\d+)\b", paint_status, line)
    return line


class Progress:
    def __init__(self, total, label):
        self.total = max(0, total)
        self.label = label
        self.started = time.monotonic() - max(0, time.time() - float(os.environ.get("TASK_PROGRESS_STARTED", time.time())))
        self.completed = 0
        self.fd = int(os.environ.get("TASK_PROGRESS_FD", "2"))
        try:
            os.fstat(self.fd)
        except OSError:
            self.fd = 2
        self.terminal = os.isatty(self.fd)

    def clear(self):
        if self.terminal:
            os.write(self.fd, b"\r\033[K")

    def update(self, completed, detail=""):
        self.completed = completed
        percent = min(100, completed * 100 // self.total) if self.total else 100
        filled = percent // 5
        elapsed = int(time.monotonic() - self.started)
        line = (f"{self.label} [{'#' * filled}{'-' * (20-filled)}] "
                f"{percent:3d}% {completed}/{self.total} complete | "
                f"{max(0, self.total-completed)} remaining | {elapsed}s | {detail}")
        if self.terminal:
            line = style_progress_line(line, shutil.get_terminal_size().columns - 1)
            line = "\r\033[K" + line + ("\n" if completed >= self.total else "")
        else:
            line = "progress snapshot: " + line + "\n"
        os.write(self.fd, line.encode(errors="replace"))

    @contextmanager
    def watch(self, detail):
        stopped = threading.Event()
        def heartbeat():
            while not stopped.wait(30):
                self.update(self.completed, detail + " | running")
        worker = threading.Thread(target=heartbeat, daemon=True)
        worker.start()
        try:
            yield
        finally:
            stopped.set()
            worker.join()

    def run(self, command, detail=""):
        self.update(self.completed, detail + " | starting")
        fds = (self.fd,) if self.fd > 2 else ()
        child = subprocess.Popen(command, pass_fds=fds, start_new_session=True,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            with selectors.DefaultSelector() as pending:
                pending.register(child.stdout, selectors.EVENT_READ, 1)
                pending.register(child.stderr, selectors.EVENT_READ, 2)
                refreshed = time.monotonic()
                while pending.get_map():
                    for key, _ in pending.select(timeout=1):
                        data = os.read(key.fileobj.fileno(), 65536)
                        if data:
                            self.clear()
                            os.write(key.data, data)
                        else:
                            pending.unregister(key.fileobj)
                            key.fileobj.close()
                    if time.monotonic() - refreshed >= 30:
                        self.update(self.completed, detail + " | running")
                        refreshed = time.monotonic()
            result = child.wait()
        except BaseException:
            self.clear()
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
            raise
        finally:
            child.stdout.close()
            child.stderr.close()
        self.update(self.completed + 1, detail + (" | finished" if result == 0 else f" | exit {result}"))
        if self.completed < self.total:
            self.clear()
        return result if result >= 0 else 128 - result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--total", type=int, required=True)
    parser.add_argument("--done", type=int, default=0)
    parser.add_argument("--label", required=True)
    parser.add_argument("--detail", default="")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    progress = Progress(args.total, args.label)
    progress.completed = args.done
    command = args.command
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        progress.update(args.done, args.detail)
        return 0
    def interrupted(signum, _frame):
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, interrupted)
    try:
        return progress.run(command, args.detail)
    except KeyboardInterrupt:
        progress.clear()
        os.write(progress.fd, f"{args.label}: interrupted\n".encode())
        return 130


if __name__ == "__main__":
    sys.exit(main())
