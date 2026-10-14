#!/usr/bin/env python3
"""Run a command in a pseudo-terminal and answer its prompts.

usage: pty_run.py STEPS_JSON COMMAND [ARG...]

STEPS_JSON is a list of [expected_text, keys_to_send] pairs: wait until the
output contains expected_text, then send keys_to_send. The command's output is
written to stdout and the exit status is the command's own. Exit 99 means an
expected text never appeared within 20 seconds, and 98 that the command ended first.
"""
import json
import os
import pty
import select
import sys
import time

STEP_TIMEOUT = 20


def read_some(fd, timeout):
    """Return bytes read from fd, b"" at end of output, None on timeout."""
    ready, _, _ = select.select([fd], [], [], timeout)
    if not ready:
        return None
    try:
        return os.read(fd, 4096)
    except OSError:
        return b""


def main():
    steps = json.loads(sys.argv[1])
    command = sys.argv[2:]
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(command[0], command)

    seen = b""
    consumed = 0
    for expected, keys in steps:
        deadline = time.time() + STEP_TIMEOUT
        target = expected.encode()
        while target not in seen[consumed:]:
            chunk = read_some(fd, 0.2)
            if chunk == b"":
                break
            if chunk is not None:
                seen += chunk
            if time.time() > deadline:
                sys.stdout.write(seen.decode(errors="replace"))
                sys.stdout.write("\nTIMEOUT waiting for: %s\n" % expected)
                os.kill(pid, 9)
                os.waitpid(pid, 0)
                sys.exit(99)
        if target not in seen[consumed:]:
            sys.stdout.write(seen.decode(errors="replace"))
            sys.stdout.write("\nENDED before: %s\n" % expected)
            os.waitpid(pid, 0)
            sys.exit(98)
        # The screen is redrawn after each key, so only text printed after this
        # point can satisfy the next step.
        consumed = len(seen)
        os.write(fd, keys.encode())

    while True:
        chunk = read_some(fd, STEP_TIMEOUT)
        if not chunk:
            break
        seen += chunk
    _, status = os.waitpid(pid, 0)
    sys.stdout.write(seen.decode(errors="replace"))
    sys.exit(os.waitstatus_to_exitcode(status))


if __name__ == "__main__":
    main()
