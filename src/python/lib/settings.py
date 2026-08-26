"""Reading and writing GNOME settings.

Whatever has a schema goes through Gio, which hands back a list as a list and
a string as a string. dconf's own dump format is still needed for the subtrees
that have no schema on this side — an extension's settings live under its own
id, and only the extension ships that schema.
"""

import subprocess

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio  # noqa: E402


def at(schema, path):
    """A relocatable schema bound to one path, which is how GNOME stores a
    list of things that have no fixed key of their own — an app folder, an
    extension. The path is what tells one apart from the next."""
    return Gio.Settings.new_with_path(schema, path)


def get_value(schema, key):
    """A key whose type is richer than a string or a list of them, unpacked
    into plain Python."""
    return Gio.Settings.new(schema).get_value(key).unpack()


def get_list(schema, key):
    return Gio.Settings.new(schema).get_strv(key)


def set_list(schema, key, values):
    Gio.Settings.new(schema).set_strv(key, values)


def reset(schema, key):
    Gio.Settings.new(schema).reset(key)


def dump(path):
    """A dconf subtree, in the format dconf load reads back."""
    result = subprocess.run(
        ["dconf", "dump", path], capture_output=True, text=True
    )

    return result.stdout if result.returncode == 0 else ""


def load(path, content):
    subprocess.run(["dconf", "load", path], input=content, text=True, check=True)


def reset_tree(path):
    subprocess.run(["dconf", "reset", "-f", path], check=True)
