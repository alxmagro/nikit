"""Carrying one thing between machines through a gist, encrypted end to end.

The payload is a tar holding two members, so the kind and the original
filename travel inside the encryption instead of in the gist listing:

    meta   kind and name
    data   the bytes

Recipients are the SSH public keys registered on the GitHub account, which
GitHub already publishes. Nothing has to be copied between machines: each one
decrypts with the SSH private key it already owns, and a machine is revoked by
removing its key from the account.
"""

import datetime
import io
import os
import shutil
import subprocess
import tarfile
import tempfile

from . import gist

DESCRIPTION = "nikit.u-share"
FILENAME = "clip.age"
INBOX = os.path.join(
    os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")),
    "nikit",
    "share",
)
KEY = os.path.expanduser("~/.ssh/id_ed25519")

# What raw_url still serves. Above it the gist has to be cloned, which is a
# different tool than this one wants to be.
LIMIT = 10 * 1024 * 1024


class ShareError(Exception):
    """Something the caller should print and give up on."""


def ready():
    if shutil.which("age") is None:
        raise ShareError("Missing: age. Install with: sudo apt install age")

    if not os.path.isfile(KEY):
        raise ShareError(
            f"No SSH key at {KEY}, and it is what decrypts here.\n"
            "Create one with: ssh-keygen -t ed25519"
        )

    gist.ready()


def find():
    return gist.find(DESCRIPTION)


def store(kind, name, data, mime=None):
    """Replaces whatever was stored. Only one thing is ever kept, so this drops
    the old gist rather than committing over it: a gist keeps every revision
    reachable."""
    armoured = _encrypt(_pack(kind, name, data, mime))

    if len(armoured) > LIMIT:
        raise ShareError(
            f"Too large: {_human(len(data))} becomes {_human(len(armoured))} "
            f"once encrypted.\nThe limit is {_human(LIMIT)}, which is about "
            f"{_human(LIMIT * 3 // 4)} before encryption."
        )

    gist_id = find()

    if gist_id:
        gist.delete(gist_id)

    gist.create(DESCRIPTION, FILENAME, armoured)


def take(gist_id):
    """The stored payload, as (kind, name, data, mime)."""
    return _unpack(_decrypt(gist.read(gist_id, FILENAME)))


def drop(gist_id):
    gist.delete(gist_id)


def _recipients():
    """Every machine on the account can open what any other one sends."""
    user = subprocess.run(
        ["gh", "api", "user", "--jq", ".login"], capture_output=True, text=True
    ).stdout.strip()

    keys = subprocess.run(
        ["curl", "-fsSL", f"https://github.com/{user}.keys"],
        capture_output=True,
        text=True,
    )

    if keys.returncode != 0 or not keys.stdout.strip():
        raise ShareError(
            f"No SSH public keys on the account of '{user}', so there is "
            "nobody to encrypt to.\nAdd one at: https://github.com/settings/keys"
        )

    return keys.stdout


def _pack(kind, name, data, mime):
    meta = f"kind: {kind}\nname: {name}\n"

    if mime:
        meta += f"mime: {mime}\n"

    buffer = io.BytesIO()

    with tarfile.open(fileobj=buffer, mode="w") as archive:
        _add(archive, "meta", meta.encode())
        _add(archive, "data", data)

    return buffer.getvalue()


def _unpack(blob):
    with tarfile.open(fileobj=io.BytesIO(blob), mode="r") as archive:
        meta = archive.extractfile("meta").read().decode()
        data = archive.extractfile("data").read()

    fields = dict(
        line.split(": ", 1) for line in meta.splitlines() if ": " in line
    )

    return fields.get("kind"), fields.get("name"), data, fields.get("mime")


def _add(archive, name, payload):
    info = tarfile.TarInfo(name)
    info.size = len(payload)

    archive.addfile(info, io.BytesIO(payload))


def _encrypt(blob):
    with tempfile.TemporaryDirectory() as directory:
        path = os.path.join(directory, "recipients")

        with open(path, "w") as handle:
            handle.write(_recipients())

        result = subprocess.run(
            ["age", "-a", "-R", path], input=blob, capture_output=True
        )

    if result.returncode != 0:
        raise ShareError(result.stderr.decode().strip() or "age failed")

    return result.stdout.decode()


def _decrypt(armoured):
    result = subprocess.run(
        ["age", "-d", "-i", KEY], input=armoured.encode(), capture_output=True
    )

    if result.returncode != 0:
        raise ShareError(
            f"Could not decrypt it with {KEY}.\n"
            "This machine's key was probably not on the account when it was "
            "sent.\n" + result.stderr.decode().strip()
        )

    return result.stdout


def _human(size):
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return f"{size:.1f}{unit}".replace(".0", "")

        size /= 1024


def stamp(extension):
    now = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")

    return f"clipboard-{now}.{extension}"
