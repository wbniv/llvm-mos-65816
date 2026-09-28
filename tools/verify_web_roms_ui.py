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
import tty


def clean(line):
    return re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", line).replace("\r", "")


class Display:
    def __init__(self):
        self.active = False
        self.last = None

    def update(self, overall, emulator):
        width = max(0, shutil.get_terminal_size().columns - 1)
        rows = (clean(overall)[:width], clean(emulator)[:width])
        if rows == self.last:
            return
        if not self.active:
            os.write(2, b"\n")  # Reserve two lines below the existing terminal output.
            self.active = True
        os.write(2, ("\r\x1b[1A\r\x1b[K" + rows[0] + "\n\r\x1b[K" + rows[1]).encode())
        self.last = rows

    def close(self):
        if self.active:
            os.write(2, b"\r\x1b[1A\r\x1b[K\n\r\x1b[K\r\x1b[1A")
            self.active = False


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
            display.update(pending if pending.startswith("VERIFY ") else overall,
                           pending if pending.startswith("EMU ") else emulator)
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
