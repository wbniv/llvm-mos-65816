#!/usr/bin/env python3
"""Keep ROM and frame progress on two live lines in the current terminal."""
import errno
import os
import pty
import re
import selectors
import shutil
import signal
import subprocess
import sys
import time
import tty

from task_progress import style_progress_line


def clean(line):
    return re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", line).replace("\r", "")


class Display:
    def __init__(self):
        self.active = False
        self.last = None

    def update(self, overall, emulator, pace):
        width = max(0, shutil.get_terminal_size().columns - 1)
        rows = tuple(style_progress_line(clean(line), width)
                     for line in (overall, emulator, pace))
        if rows == self.last:
            return
        if not self.active:
            os.write(2, b"\n\n")  # Reserve three lines below the existing terminal output.
            self.active = True
        os.write(2, ("\r\x1b[2A\r\x1b[K" + rows[0] + "\n\r\x1b[K" + rows[1]
                     + "\n\r\x1b[K" + rows[2]).encode())
        self.last = rows

    def close(self):
        if self.active:
            os.write(2, b"\r\x1b[2A\r\x1b[K\n\r\x1b[K\n\r\x1b[K\r\x1b[2A")
            self.active = False


def pace_line(samples):
    if not samples:
        return "PACE | collecting a five-second sample"
    recent = samples[-16:]
    scale = max(recent)
    glyphs = "▁▂▃▄▅▆▇█"
    bars = "".join(glyphs[min(7, (value * 8 - 1) // scale)] if value else "·"
                   for value in recent)
    return f"PACE {bars} | {samples[-1]} ROMs / 5s | peak {max(samples)}"


def stop(proc):
    if proc.poll() is not None:
        return
    os.killpg(proc.pid, signal.SIGTERM)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.wait()


def run(command, display):
    read_fd, write_fd = pty.openpty()
    tty.setraw(write_fd)
    env = dict(os.environ, VERIFY_WEB_ROMS_UI_CHILD="1", TASK_PROGRESS_FD=str(write_fd))
    proc = subprocess.Popen(command, env=env, pass_fds=(write_fd,),
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            start_new_session=True)
    os.close(write_fd)
    streams = {proc.stdout.fileno(): "stdout", proc.stderr.fileno(): "stderr",
               read_fd: "progress"}
    buffers = {fd: b"" for fd in streams}
    messages = []
    overall = "VERIFY | preparing ROM checks"
    emulator = "EMU | waiting for first ROM"
    sampled_at = time.monotonic()
    sampled_done = 0
    done = 0
    samples = []
    selector = selectors.DefaultSelector()
    for fd in streams:
        selector.register(fd, selectors.EVENT_READ)
    try:
        while selector.get_map() or proc.poll() is None:
            for key, _ in selector.select(timeout=0.1):
                fd = key.fd
                try:
                    data = os.read(fd, 65536)
                except OSError as error:
                    if streams[fd] != "progress" or error.errno != errno.EIO:
                        raise
                    data = b""
                if data:
                    buffers[fd] += data
                    separator = b"[\r\n]" if streams[fd] == "progress" else b"\n"
                    while re.search(separator, buffers[fd]):
                        raw, buffers[fd] = re.split(separator, buffers[fd], maxsplit=1)
                        line = clean(raw.decode(errors="replace"))
                        if streams[fd] == "progress":
                            if line.startswith("VERIFY "):
                                overall = line
                            elif line.startswith("EMU "):
                                emulator = line
                        else:
                            messages.append(line)
                            if line.startswith("EMU "):
                                emulator = line
                else:
                    if buffers[fd]:
                        line = clean(buffers[fd].decode(errors="replace"))
                        if streams[fd] != "progress":
                            messages.append(line)
                        elif line.startswith("VERIFY "):
                            overall = line
                        elif line.startswith("EMU "):
                            emulator = line
                        buffers[fd] = b""
                    selector.unregister(fd)
                    if streams[fd] == "stdout":
                        proc.stdout.close()
                    elif streams[fd] == "stderr":
                        proc.stderr.close()
                    else:
                        os.close(fd)
            pending = clean(buffers[read_fd].decode(errors="replace"))
            shown_overall = pending if pending.startswith("VERIFY ") else overall
            count = re.search(r"\b(\d+)/(\d+) complete\b", shown_overall)
            if count:
                done = int(count.group(1))
            now = time.monotonic()
            if now - sampled_at >= 5:
                samples.append(max(0, done - sampled_done))
                sampled_done = done
                sampled_at = now
            display.update(shown_overall,
                           pending if pending.startswith("EMU ") else emulator,
                           pace_line(samples))
        return proc.wait(), messages
    finally:
        selector.close()
        stop(proc)
        for stream in (proc.stdout, proc.stderr):
            stream.close()
        try:
            os.close(read_fd)
        except OSError:
            pass


def main():
    command = sys.argv[1:]
    if not command:
        return 2

    def interrupted(_signum, _frame):
        raise KeyboardInterrupt
    previous = signal.signal(signal.SIGTERM, interrupted)
    display = Display()
    try:
        try:
            status, messages = run(command, display)
        except KeyboardInterrupt:
            return 130
    finally:
        display.close()
        signal.signal(signal.SIGTERM, previous)
    if status:
        for line in messages[-30:]:
            print(line)
    else:
        for line in messages:
            if line.startswith(("verify-web-roms:", "title-entropy:", "ALL PASS")):
                print(line)
    return status if status >= 0 else 128 - status


if __name__ == "__main__":
    sys.exit(main())
