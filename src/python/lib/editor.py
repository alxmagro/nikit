"""Handing something to $EDITOR and finding out what came back."""

import os
import subprocess
import tempfile


def open_buffer(content, name="buffer"):
    """Returns (content, changed).

    The comparison is made against the file as written, not against the string
    passed in: writing and reading is not a round trip, since the trailing
    newline survives one and not the other, and everything would look edited.
    """
    with tempfile.TemporaryDirectory() as directory:
        path = os.path.join(directory, name)

        with open(path, "w") as handle:
            handle.write(content if content.endswith("\n") else content + "\n")

        before = _read(path)

        # The editor gets the terminal directly. Whoever called this has our
        # stdout, and a full screen editor painting into a pipe hangs with
        # nobody reading.
        #
        # Opened as a raw descriptor: a tty cannot be seeked, and Python's
        # buffered "r+" insists on it. Opened rather than tested for, too —
        # /dev/tty is there even when the process has no controlling terminal,
        # and only opening it says so.
        command = [os.environ.get("EDITOR", "nano"), path]

        try:
            tty = os.open("/dev/tty", os.O_RDWR)
        except OSError:
            subprocess.run(command)
        else:
            try:
                subprocess.run(command, stdin=tty, stdout=tty, stderr=tty)
            finally:
                os.close(tty)

        after = _read(path)

    return after, after != before


def _read(path):
    with open(path) as handle:
        return handle.read().rstrip("\n")
