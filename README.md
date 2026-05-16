# Phoenix Term

A complete, opinionated terminal stack for macOS — Ghostty + tmux + Starship + LazyVim, with a live system-monitor sidebar, a welcome banner, per-command divider rules, and a cohesive LightSeaGreen + Phoenix color theme across every layer.

## What's inside

| Layer                | Component                                                     |
| -------------------- | ------------------------------------------------------------- |
| Terminal             | Ghostty (Kali-style dark background, LightSeaGreen text)      |
| Shell                | zsh + Oh-My-Zsh + zsh-autosuggestions + fast-syntax-highlight |
| Prompt               | Starship with Warp-style rounded pills                        |
| Multiplexer          | tmux (TPM + tmux-resurrect + tmux-continuum)                  |
| Sidebar              | `phoenix-sysmon` — CPU / mem / disk / network / battery       |
| Welcome              | Per-shell figlet banner ("ANSI Shadow")                       |
| Editor               | Neovim / LazyVim with the `phoenix` Black-and-Gold colorscheme|
| Fuzzy / nav / search | fzf · zoxide · fd · ripgrep · eza · bat · atuin · yazi · btop |

## Install

```sh
git clone https://github.com/<you>/phoenix-term.git
cd phoenix-term
bash install.sh
```

The installer:

1. Installs Homebrew if you don't have it
2. Installs every CLI tool listed above (`brew install ...`)
3. Installs Ghostty + the Comic Shanns Mono Nerd Font cask
4. Installs Oh-My-Zsh + the `zsh-completions` plugin
5. Installs TPM (tmux plugin manager) and bootstraps plugins
6. Copies the `ANSI_Shadow.flf` figlet font into your `figlet` install
7. Symlinks every config (backing up any existing file with a timestamp)
8. Appends one `source <repo>/shell/phoenix.zsh` line to your `~/.zshrc`

It is idempotent — re-running it is safe.

## Use it

Open a new Ghostty window. You will see:

- The welcome banner with your name in ANSI-Shadow figlet, centered
- A new tmux session automatically (one per window — gets destroyed on close)
- A 34-column system-monitor sidebar pinned to the right
- A full-width divider rule above every prompt (separates command blocks)

### Key bindings (tmux prefix is `Ctrl-a`)

| Binding          | Action                                  |
| ---------------- | --------------------------------------- |
| `Ctrl-a S`       | Toggle the `phoenix-sysmon` sidebar     |
| `Ctrl-a \|`      | Split pane right                        |
| `Ctrl-a -`       | Split pane down                         |
| `Ctrl-a h/j/k/l` | Move between panes (vim keys)           |
| `Ctrl-a r`       | Reload tmux config                      |
| `Cmd-T`          | New Ghostty tab (new tmux session)      |
| `Cmd-D`          | Split right within Ghostty              |

## Customize

```sh
# Override before the source line in ~/.zshrc, or set in your env.
export PHOENIX_NAME="Your Name"        # text on the welcome banner + sidebar
export PHOENIX_WELCOME=0               # disable the welcome banner
export PHOENIX_AUTO_TMUX=0             # don't auto-launch tmux on new shells
```

To use your own wallpaper, drop a JPG at `~/.config/ghostty/phoenix-bg.jpg` (the symlink will pick it up). The included image is pre-darkened to ~30 % brightness so colors stay readable on top — to re-darken an arbitrary image:

```sh
python3 -c "from PIL import Image, ImageEnhance; \
  i=Image.open('original.jpg').convert('RGB'); \
  ImageEnhance.Brightness(i).enhance(0.30).save('phoenix-bg.jpg','JPEG',quality=92)"
```

## Layout

```
phoenix-term/
├── install.sh                    one-shot installer
├── README.md
├── ghostty/
│   ├── phoenix.config            → ~/.config/ghostty/config
│   └── phoenix-bg.jpg            → ~/.config/ghostty/phoenix-bg.jpg
├── starship/
│   └── phoenix.toml              → ~/.config/starship.toml
├── tmux/
│   └── phoenix.conf              → ~/.tmux.conf
├── nvim/
│   ├── colors/phoenix.lua        → ~/.config/nvim/colors/phoenix.lua
│   ├── lua/plugins/colorscheme.lua
│   └── lua/lualine/themes/phoenix.lua
├── shell/
│   └── phoenix.zsh               sourced from ~/.zshrc
├── bin/
│   ├── phoenix-sysmon            → ~/.local/bin/phoenix-sysmon
│   └── phoenix-sysmon-toggle     → ~/.local/bin/phoenix-sysmon-toggle
└── fonts/
    └── ANSI_Shadow.flf           welcome-banner figlet font
```

## Uninstall

The installer backed up every replaced file as `<path>.bak-<timestamp>`. Remove the symlinks and restore the backups, then remove the `source <repo>/shell/phoenix.zsh` line from `~/.zshrc`.

## Requirements

- macOS (Apple Silicon or Intel)
- Internet (the installer pulls Homebrew, Oh-My-Zsh, TPM, fonts)
- `git`, `curl`, `python3` (Apple Command Line Tools is enough)

## License

MIT.
