"""Thin wrappers over the gists API, for commands that keep state in a gist.

Nothing here knows what the content is for.
"""

import json
import shutil
import subprocess


class GistError(Exception):
    """Something the caller should print and give up on."""


def ready():
    """Checked up front, or gh's own errors reach the caller as an empty
    answer, which reads like "there is nothing there" instead of "I could
    not ask"."""
    missing = [name for name in ("gh",) if shutil.which(name) is None]

    if missing:
        raise GistError(
            f"Missing: {' '.join(missing)}. "
            f"Install with: sudo apt install {' '.join(missing)}"
        )

    if subprocess.run(["gh", "auth", "status"], capture_output=True).returncode != 0:
        raise GistError("gh is not logged in. Run: gh auth login")


def find(description):
    """Id of the first gist whose description matches exactly, or None."""
    for line in _gh("gist", "list", "--limit", "100").splitlines():
        fields = line.split("\t")

        if len(fields) > 1 and fields[1] == description:
            return fields[0]

    return None


def create(description, filename, content):
    """Creates a secret gist with one file. Returns its URL, which ends in
    the id."""
    body = json.dumps(
        {
            "description": description,
            "public": False,
            "files": {filename: {"content": content}},
        }
    )

    return _gh("api", "-X", "POST", "gists", "--input", "-",
               "--jq", ".html_url", stdin=body).strip()


def files(gist_id):
    """Every file in the gist, as {name: content}.

    Above a megabyte the API stops inlining a file and points at raw_url
    instead, so a truncated one is fetched separately.
    """
    data = json.loads(_gh("api", f"gists/{gist_id}"))
    out = {}

    for name, entry in data["files"].items():
        if entry.get("truncated"):
            out[name] = _fetch(entry["raw_url"])
        else:
            out[name] = entry["content"]

    return out


def read(gist_id, filename=None):
    """Content of one file. Without a name, the first one."""
    contents = files(gist_id)

    if filename is None:
        filename = next(iter(contents), None)

    if filename not in contents:
        raise GistError(f"No file '{filename}' in gist {gist_id}")

    return contents[filename]


def write(gist_id, filename, content):
    """Creates or replaces one file, leaving the others alone."""
    body = json.dumps({"files": {filename: {"content": content}}})

    _gh("api", "-X", "PATCH", f"gists/{gist_id}", "--input", "-", stdin=body)


def rename(gist_id, filename, new_name):
    """Renames one file, keeping its content."""
    body = json.dumps({"files": {filename: {"filename": new_name}}})

    _gh("api", "-X", "PATCH", f"gists/{gist_id}", "--input", "-", stdin=body)


def describe(gist_id, description):
    body = json.dumps({"description": description})

    _gh("api", "-X", "PATCH", f"gists/{gist_id}", "--input", "-", stdin=body)


def remove(gist_id, filename):
    """A null entry is how the API spells "drop this file"."""
    body = json.dumps({"files": {filename: None}})

    _gh("api", "-X", "PATCH", f"gists/{gist_id}", "--input", "-", stdin=body)


def delete(gist_id):
    _gh("gist", "delete", gist_id)


def _gh(*args, stdin=None):
    result = subprocess.run(
        ["gh", *args],
        input=stdin,
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise GistError(result.stderr.strip() or "gh failed")

    return result.stdout


def _fetch(url):
    result = subprocess.run(
        ["curl", "-fsSL", url], capture_output=True, text=True
    )

    if result.returncode != 0:
        raise GistError(f"Could not read {url}")

    return result.stdout
