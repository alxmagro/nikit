# nikit

A setup for Debian, with a bunch of quality of life changes for developers.

```
wget -qO - https://raw.githubusercontent.com/alxmagro/nikit/main/get.sh | bash -s debian_13
```

**What it do?**

- **scripts**:
  - `u-copy` / `u-paste`: carry the clipboard, a file or a stream to another machine, encrypted end to end;
  - `nikit app-folders`: store and sync the folders in your App Grid;
  - `nikit gnome-extensions`: store and sync your GNOME extensions and their settings;
  - `gistpad`: named notes kept as secret gists;
  - `goto`: jump into named roots and drill into them from anywhere;
  - `lanip`: your LAN URL, with a QR code to open it on your phone;
  - `compress` / `decompress`: tar.gz in one word, twelve formats out;
  - `open`: xdg-open, quiet and detached;
- **docker**:
  - Installed with its data directory moved into your home;
- **postgresql**:
  - Installed from the pgdg repository;
- **mise**:
  - Installed and activated in your shell;
- **git**:
  - Installs gh and configures git globals;
- **aliases**:
  - Adds custom aliases;
- **nano**:
  - Modern bindings enabled by default (`Ctrl+C`, `Ctrl+V`, `Ctrl+X`, `Ctrl+Z`, ...);
- **keybindings**:
  - `Super` + arrows drive workspaces and window state;
  - `Super` + `Alt` + arrows carry the window along;
  - `Alt+Tab` walks windows instead of applications;
  - `Super` + `R` opens a terminal (`kgx`);
- **fonts**:
  - Installs Inter, Open Sans and Roboto Mono;
