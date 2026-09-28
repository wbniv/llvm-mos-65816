#!/usr/bin/env python3
"""Progress on a separate descriptor; child output and exit codes stay intact."""
import argparse
from contextlib import contextmanager
import os
import selectors
import signal
import subprocess
import sys
import threading
import time


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
