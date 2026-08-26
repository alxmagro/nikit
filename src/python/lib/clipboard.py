"""The Wayland clipboard.

Everything here is about what the clipboard is offering, not what it holds.
The set of types belongs to whoever owns the clipboard and it changes: once
the application that copied is closed, GNOME takes over and offers only
'text/plain;charset=utf-8'. Naming a type outright is what breaks there.
"""

import os
import shutil
import subprocess
import urllib.parse

FILES_TYPE = "x-special/gnome-copied-files"

# In order of preference. The MIME names first, the X11 ones as a last resort:
# the older names say nothing about encoding.
TEXT_TYPES = [
    "text/plain;charset=utf-8",
    "text/plain",
    "UTF8_STRING",
    "STRING",
    "TEXT",
]


class ClipboardError(Exception):
    """Something the caller should print and give up on."""


def ready():
    if os.environ.get("XDG_SESSION_TYPE") != "wayland":
        raise ClipboardError(
            "Reaching the clipboard needs a Wayland session.\n"
            "Name a file or use '-' to work without it."
        )

    if shutil.which("wl-copy") is None:
        raise ClipboardError(
            "Missing: wl-clipboard. Install with: sudo apt install wl-clipboard"
        )


def types():
    result = subprocess.run(
        ["wl-paste", "--list-types"], capture_output=True, text=True
    )

    if result.returncode != 0:
        raise ClipboardError("The clipboard is empty.")

    return [line for line in result.stdout.splitlines() if line]


def read(mime, binary=False):
    result = subprocess.run(
        ["wl-paste", "--no-newline", "--type", mime], capture_output=True
    )

    if result.returncode != 0:
        raise ClipboardError(f"Could not read the clipboard as '{mime}'.")

    return result.stdout if binary else result.stdout.decode()


def write(data, mime=None):
    args = ["wl-copy"] + (["--type", mime] if mime else [])

    subprocess.run(args, input=data, check=True)


def file_path():
    """The path behind a file copied in the file manager.

    A file copied there also offers text/plain holding its path, so this has to
    be asked about before the text types or a file becomes a string.
    """
    payload = read(FILES_TYPE)
    lines = payload.splitlines()

    if len(lines) < 2:
        return None

    return urllib.parse.unquote(lines[1].removeprefix("file://"))


def offer_file(path, move=False):
    """Points the clipboard at a file on disk.

    'cut' rather than 'copy' means the file manager moves it on paste, which is
    what keeps a folder of arrivals from piling up.
    """
    operation = "cut" if move else "copy"
    uri = urllib.parse.quote(path)

    write(f"{operation}\nfile://{uri}".encode(), FILES_TYPE)


def text_type(offered):
    """Whichever text type is actually on offer, or None."""
    return next((t for t in TEXT_TYPES if t in offered), None)


def image_type(offered):
    return next((t for t in offered if t.startswith("image/")), None)
