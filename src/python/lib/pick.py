"""The fzf menus, so that every list in nikit looks the same.

One function per kind of menu rather than one function with switches: they
behave differently enough that a single entry point would take more arguments
than it saves. What they share is the look, and that lives in one list.
"""

import shutil
import subprocess

STYLE = [
    "--height", "40%",
    "--layout", "reverse",
    "--info", "hidden",
    "--no-separator",
    "--prompt", "$ ",
    "--header-first",
    "--pointer", "›",
    "--color",
    "fg+:-1:regular,bg+:-1,prompt:15:regular,query:-1:regular"
    ",pointer:4,hl:4,hl+:4,header:8,marker:4",
]


def ready():
    return shutil.which("fzf") is not None


def keys(choices, header, expect):
    """Pick one, and report which key was used to pick it. fzf prints that key
    on the first line and the choice on the second."""
    lines = _run(choices, ["--header", header, "--expect", expect])

    if not lines:
        return None, None

    return lines[0], (lines[1] if len(lines) > 1 else None)


def many(choices, header, marked=()):
    """Pick several, with `marked` already selected."""
    return _run(
        choices,
        [
            "--multi",
            "--marker", "✓ ",
            "--header", header,
            "--bind", "ctrl-a:select-all",
            "--bind", _preselect(choices, marked),
        ],
    )


def _run(choices, args):
    result = subprocess.run(
        ["fzf", *STYLE, *args],
        input="\n".join(choices),
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        return None

    return result.stdout.splitlines()


def _preselect(choices, marked):
    """fzf cannot start with items selected, so they are selected on the load
    event, which is when the list is finished and pos(n) has somewhere to
    land."""
    marked = set(marked)
    steps = [
        f"pos({n})+select"
        for n, choice in enumerate(choices, start=1)
        if choice in marked
    ]

    return "load:" + "+".join([*steps, "pos(1)"])
