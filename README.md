# nikit

Setup for Debian: Docker, PostgreSQL, Git, Shortcuts, Aliases and Scripts.

```
wget -qO - https://raw.githubusercontent.com/alxmagro/nikit/main/get.sh | bash -s debian_13
```

**What is this?**

A setup for Debian, with a bunch of quality of life changes for developers. One module per concern,
run in order. What it writes to the home directory stays in `~/.local/share/nikit`.

**What it do?**

- Installs Docker, with its data directory moved into your home;
- Installs PostgreSQL from the pgdg repository;
- Installs mise, and wrappers for the Claude, Codex, Copilot and Gemini CLIs;
- Installs gh and configures git globals;
- Nano: Modern bindings enabled by default (`Ctrl+C`, `Ctrl+V`, `Ctrl+X`, `Ctrl+Z`, ...);
- Shortcuts:
  - `Super` + arrows drive workspaces and window state;
  - `Super` + `Alt` + arrows carry the window along;
  - `Alt+Tab` walks windows instead of applications;
- Bash aliases:
  - `..` to go up
  - `dcu` `dcd` `dce` `dcr` `dprune-all`;
  - `tt` to duplicate a terminal tab;
  - `gpad` alias for `gistpad`;
- Scripts:
  - `gistpad`: named notes kept as secret gists;
  - `goto`: jump to named folders from anywhere;
  - `lanip`: your LAN URL, with a QR code to open it on your phone;
  - `compress` / `decompress`: tar.gz in one word, twelve formats out;
  - `open`: xdg-open, quiet and detached;

## Usage

From a checkout, the installer takes an OS and, optionally, single modules:

```
./install.sh                        # list the supported systems
./install.sh debian_13              # run everything
./install.sh debian_13 docker.sh    # run only the modules named
```

Running it again is safe: Docker, PostgreSQL and mise step aside when they
are already installed.
