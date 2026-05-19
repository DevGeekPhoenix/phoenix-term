#!/usr/bin/env bash
# Phoenix Term installer. Run `bash install.sh --help` for subcommands.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SEA=$'\e[38;2;32;178;170m'
DIM=$'\e[38;2;120;120;120m'
YEL=$'\e[38;2;250;189;47m'
RED=$'\e[38;2;251;73;52m'
GRN=$'\e[38;2;152;195;121m'
B=$'\e[1m'
R=$'\e[0m'

say()  { printf "%s•%s %s\n" "$SEA" "$R" "$*"; }
warn() { printf "%s!%s %s\n" "$YEL" "$R" "$*" >&2; }
ok()   { printf "  %s✓%s %s\n" "$GRN" "$R" "$*"; }
bad()  { printf "  %s✗%s %s\n" "$RED" "$R" "$*"; }
dry()  { printf "%s[dry-run]%s %s\n" "$DIM" "$R" "$*"; }

DRY_RUN=0
MODE=install
SETTINGS_ARG=""
SETTINGS_KEY=""

usage() {
  cat <<EOF
Phoenix Term installer

Usage:
  bash install.sh [--dry-run]      Install or update (default)
  bash install.sh --update         Download the latest release and replace the install
  bash install.sh --check          Report installed version and whether a newer release exists
  bash install.sh --version        Print installed version
  bash install.sh --revert         Roll back to the most recent backup created by --update
  bash install.sh --backups        List available backups (versions + timestamps)
  bash install.sh --uninstall      Remove symlinks, restore most-recent backups,
                                   strip the phoenix.zsh source line from ~/.zshrc
  bash install.sh --doctor         Verify symlinks, packages, and shell wiring
  bash install.sh --settings       Manage preferences (welcome, auto-tmux, etc.)
                                    Subcommands: --list (default), --menu, --ensure,
                                    --get KEY, --set KEY=VALUE
  bash install.sh --help           Show this help

Flags:
  --dry-run    Print every filesystem action without performing it.
EOF
}

# Pre-parse --settings <subcommand> [<key>] so they don't get caught by the
# unknown-flag branch below.
ARGS=()
while (( $# )); do
  case "$1" in
    --settings)
      MODE=settings
      if [[ -n "${2:-}" && "${2:0:1}" == "-" ]]; then
        SETTINGS_ARG="$2"; shift
        if [[ "$SETTINGS_ARG" == "--get" || "$SETTINGS_ARG" == "--set" ]]; then
          SETTINGS_KEY="${2:-}"; [[ -n "$SETTINGS_KEY" ]] && shift
        fi
      fi
      shift
      ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

for arg in "$@"; do
  case "$arg" in
    -h|--help)    usage; exit 0 ;;
    --dry-run)    DRY_RUN=1 ;;
    --update)     MODE=update ;;
    --check)      MODE=check ;;
    --version|-V) MODE=version ;;
    --uninstall)  MODE=uninstall ;;
    --doctor)     MODE=doctor ;;
    --revert)     MODE=revert ;;
    --backups)    MODE=backups ;;
    *) warn "unknown argument: $arg"; usage; exit 2 ;;
  esac
done

run() {
  if (( DRY_RUN )); then
    dry "$*"
  else
    "$@"
  fi
}

# ---------- OS detection ----------

PHOENIX_OS=""
PHOENIX_ARCH=""
PHOENIX_DISTRO=""

detect_os() {
  case "$(uname -s)" in
    Darwin) PHOENIX_OS=macos ;;
    Linux)
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        PHOENIX_DISTRO="${ID:-unknown}"
        case "$ID" in
          ubuntu|debian|linuxmint|pop|kali|elementary|raspbian|zorin) PHOENIX_OS=debian ;;
          *)
            case "${ID_LIKE:-}" in
              *debian*|*ubuntu*) PHOENIX_OS=debian ;;
            esac
            ;;
        esac
      fi
      if [[ -z "$PHOENIX_OS" ]]; then
        warn "unsupported Linux distro: ${PHOENIX_DISTRO:-unknown}"
        warn "Phoenix Term supports macOS and Debian/Ubuntu derivatives only"
        exit 1
      fi
      ;;
    *) warn "unsupported OS: $(uname -s)"; exit 1 ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64) PHOENIX_ARCH=x86_64 ;;
    aarch64|arm64) PHOENIX_ARCH=aarch64 ;;
    *) warn "unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
}

sudo_if_needed() {
  if [[ "$PHOENIX_OS" == "macos" ]] || [[ $EUID -eq 0 ]]; then
    run "$@"
  else
    run sudo "$@"
  fi
}

# ---------- Pre-flight checks ----------

_pre_ok()  { printf "  %s✓%s %s\n" "$GRN" "$R" "$*"; }
_pre_bad() { printf "  %s✗%s %s\n" "$RED" "$R" "$*"; }
_pre_fix() { printf "      %s%s%s\n" "$DIM" "$*" "$R"; }

_pre_need_cmd() {
  local cmd="$1" mac_fix="$2" deb_fix="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    _pre_ok "$cmd available"
    return 0
  fi
  _pre_bad "$cmd missing"
  case "$PHOENIX_OS" in
    macos)  _pre_fix "$mac_fix" ;;
    debian) _pre_fix "$deb_fix" ;;
  esac
  return 1
}

_pre_home_writable() {
  if [[ -w "$HOME" ]]; then
    _pre_ok "\$HOME writable ($HOME)"
    return 0
  fi
  _pre_bad "\$HOME is not writable: $HOME"
  _pre_fix "check permissions on your home directory"
  return 1
}

_pre_github_reachable() {
  if curl -fsS --max-time 8 -o /dev/null -w '%{http_code}' \
       https://github.com 2>/dev/null | grep -qE '^(200|301|302)$'; then
    _pre_ok "github.com reachable"
    return 0
  fi
  _pre_bad "github.com unreachable"
  _pre_fix "check network, DNS, proxy, or firewall — the installer needs github.com"
  return 1
}

_pre_disk_space() {
  local avail_kb need_kb=1048576
  avail_kb=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
  avail_kb=${avail_kb:-0}
  local avail_mb=$((avail_kb/1024))
  if (( avail_kb < need_kb )); then
    _pre_bad "disk space: only ${avail_mb}MB free in $HOME (need ≥ 1024MB)"
    _pre_fix "free up some space, then re-run"
    return 1
  fi
  _pre_ok "disk space: ${avail_mb}MB free in $HOME"
}

_pre_not_root_macos() {
  if [[ $EUID -ne 0 ]]; then
    _pre_ok "running as user (not root) — Homebrew requires this"
    return 0
  fi
  _pre_bad "running as root — Homebrew refuses to install as root"
  _pre_fix "exit this shell and re-run as your regular user"
  return 1
}

_pre_sudo_linux() {
  if [[ $EUID -eq 0 ]]; then
    _pre_ok "running as root — sudo not required"
    return 0
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    _pre_bad "sudo missing — apt installs need root"
    _pre_fix "as root: apt install -y sudo && usermod -aG sudo \"\$USER\""
    return 1
  fi
  if sudo -n true 2>/dev/null; then
    _pre_ok "sudo authenticated (passwordless or cached)"
    return 0
  fi
  printf "  %s•%s sudo needs your password to proceed%s\n" "$SEA" "$R" "$R"
  if sudo -v 2>/dev/null; then
    _pre_ok "sudo authenticated"
    return 0
  fi
  _pre_bad "sudo authentication failed"
  _pre_fix "verify your account is in the sudo/wheel group"
  return 1
}

_pre_apt_lock() {
  # cloud-init / unattended-upgrades grab these locks on fresh Ubuntu cloud
  # images for 5-10 min after first boot.
  local locks=(
    /var/lib/dpkg/lock-frontend
    /var/lib/dpkg/lock
    /var/lib/apt/lists/lock
  )
  if ! command -v fuser >/dev/null 2>&1; then
    _pre_ok "apt lock check skipped (fuser not present)"
    return 0
  fi
  local holder l
  for l in "${locks[@]}"; do
    [[ -e "$l" ]] || continue
    holder=$(fuser "$l" 2>/dev/null | tr -d ' ')
    if [[ -n "$holder" ]]; then
      _pre_bad "apt lock held: $l (pid $holder)"
      _pre_fix "wait for the background package operation, or:"
      _pre_fix "  sudo systemctl stop unattended-upgrades  &&  sudo killall apt apt-get"
      return 1
    fi
  done
  _pre_ok "apt lock free"
}

preflight() {
  printf "\n%s•%s preflight checks  %s(%s/%s)%s\n" \
    "$SEA" "$R" "$DIM" "$PHOENIX_OS" "$PHOENIX_ARCH" "$R"

  local fail=0

  _pre_need_cmd curl \
    "/usr/bin/curl ships with macOS — your install is broken" \
    "sudo apt update && sudo apt install -y curl" || fail=1
  _pre_need_cmd tar \
    "/usr/bin/tar ships with macOS — your install is broken" \
    "sudo apt install -y tar" || fail=1

  _pre_home_writable    || fail=1
  _pre_github_reachable || fail=1
  _pre_disk_space       || fail=1

  case "$PHOENIX_OS" in
    macos)
      _pre_not_root_macos || fail=1
      # git on macOS comes via Xcode CLT, triggered by the Homebrew installer.
      ;;
    debian)
      _pre_sudo_linux                                                                    || fail=1
      _pre_need_cmd apt-get  "" "this isn't a Debian/Ubuntu derivative — detect_os bug?" || fail=1
      _pre_apt_lock                                                                      || fail=1
      ;;
  esac

  if (( fail )); then
    printf "\n%s✗ preflight failed%s — fix the issues above and re-run %sbash install.sh%s.\n" \
      "$RED" "$R" "$SEA" "$R" >&2
    exit 1
  fi
  printf "%s✓%s preflight passed\n\n" "$GRN" "$R"
}

# src-relative-to-repo|absolute-destination
LINKS=(
  "ghostty/phoenix.config|$HOME/.config/ghostty/config"
  "ghostty/phoenix-bg.jpg|$HOME/.config/ghostty/phoenix-bg.jpg"
  "starship/phoenix.toml|$HOME/.config/starship.toml"
  "tmux/phoenix.conf|$HOME/.tmux.conf"
  "bin/phoenix-sysmon|$HOME/.local/bin/phoenix-sysmon"
  "bin/phoenix-sysmon-toggle|$HOME/.local/bin/phoenix-sysmon-toggle"
  "bin/phoenix-term|$HOME/.local/bin/phoenix-term"
  "bin/phoenix-banner|$HOME/.local/bin/phoenix-banner"
  "bin/phoenix-tmux-init|$HOME/.local/bin/phoenix-tmux-init"
  "bin/phoenix-tmux-rebalance|$HOME/.local/bin/phoenix-tmux-rebalance"
  "bin/phoenix-clip|$HOME/.local/bin/phoenix-clip"
  "nvim/colors/phoenix.lua|$HOME/.config/nvim/colors/phoenix.lua"
  "nvim/lua/plugins/colorscheme.lua|$HOME/.config/nvim/lua/plugins/colorscheme.lua"
  "nvim/lua/lualine/themes/phoenix.lua|$HOME/.config/nvim/lua/lualine/themes/phoenix.lua"
)

BREW_FORMULAS=(
  tmux starship zoxide fzf eza bat fd ripgrep lazygit lazydocker gh atuin yazi
  btop tldr zsh-autosuggestions zsh-fast-syntax-highlighting figlet
  neovim
)
BREW_CASKS=(ghostty font-comic-shanns-mono-nerd-font)

# Tools not in apt (starship, eza, lazygit, lazydocker, atuin, yazi, neovim ≥ 0.9,
# ghostty, zsh-fast-syntax-highlighting) are fetched in install_linux_extras.
# Packages here that don't exist on a given distro are filtered before install.
APT_PACKAGES=(
  zsh tmux git curl wget ca-certificates
  figlet fzf ripgrep btop tldr
  zsh-autosuggestions
  python3 build-essential
  xclip wl-clipboard
  fontconfig unzip tar
  bat fd-find
)

NVIM_LINUX_TARBALL_URL_X86="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz"
NVIM_LINUX_TARBALL_URL_ARM="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-arm64.tar.gz"

NERD_FONT_ZIP_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/ComicShannsMono.zip"

SOURCE_LINE="source $REPO/shell/phoenix.zsh"
SOURCE_LINE_PATTERN='^source .+/shell/phoenix\.zsh$'

# ---------- install ----------

install_brew_packages() {
  local installed missing=()
  installed=$(brew list --formula -1 2>/dev/null || true)
  for f in "${BREW_FORMULAS[@]}"; do
    grep -qx "$f" <<<"$installed" || missing+=("$f")
  done
  if (( ${#missing[@]} == 0 )); then
    say "brew formulas already installed (${#BREW_FORMULAS[@]}/${#BREW_FORMULAS[@]})"
  else
    say "installing brew formulas (${#missing[@]} missing): ${missing[*]}"
    run brew install "${missing[@]}"
  fi

  installed=$(brew list --cask -1 2>/dev/null || true)
  for c in "${BREW_CASKS[@]}"; do
    if grep -qx "$c" <<<"$installed"; then
      continue
    fi
    say "installing brew cask: $c"
    if (( DRY_RUN )); then
      dry "brew install --cask $c"
    else
      brew install --cask "$c" 2>&1 | tail -2 || warn "cask $c failed — install manually if needed"
    fi
  done
}

# ---------- Linux (Debian/Ubuntu) installers ----------

install_apt_packages() {
  sudo_if_needed apt-get update -qq

  local available=() skipped=()
  for pkg in "${APT_PACKAGES[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      skipped+=("$pkg")
    fi
  done
  if (( ${#skipped[@]} > 0 )); then
    warn "apt packages not in this distro's index (skipping): ${skipped[*]}"
  fi

  local missing=()
  for pkg in "${available[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} == 0 )); then
    say "apt packages already installed (${#available[@]}/${#available[@]})"
    return 0
  fi
  say "installing apt packages (${#missing[@]} missing): ${missing[*]}"
  sudo_if_needed apt-get install -y "${missing[@]}"
}

# Debian ships `bat` as `batcat` and `fd` as `fdfind` (name conflicts);
# phoenix.zsh expects the upstream names.
link_debian_renamed_binaries() {
  run mkdir -p "$HOME/.local/bin"
  if [[ -x /usr/bin/batcat && ! -e "$HOME/.local/bin/bat" ]]; then
    run ln -s /usr/bin/batcat "$HOME/.local/bin/bat"
    say "linked batcat → ~/.local/bin/bat"
  fi
  if [[ -x /usr/bin/fdfind && ! -e "$HOME/.local/bin/fd" ]]; then
    run ln -s /usr/bin/fdfind "$HOME/.local/bin/fd"
    say "linked fdfind → ~/.local/bin/fd"
  fi
}

install_starship_linux() {
  command -v starship >/dev/null && return 0
  say "installing starship"
  if (( DRY_RUN )); then
    dry "curl starship install script | sh -s -- -y"
    return 0
  fi
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

install_zoxide_linux() {
  command -v zoxide >/dev/null && return 0
  say "installing zoxide"
  if (( DRY_RUN )); then
    dry "curl zoxide install script | bash"
    return 0
  fi
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
}

install_atuin_linux() {
  command -v atuin >/dev/null && return 0
  say "installing atuin"
  if (( DRY_RUN )); then
    dry "curl atuin install script | sh"
    return 0
  fi
  curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
}

install_gh_linux() {
  command -v gh >/dev/null && return 0
  say "installing GitHub CLI"
  if (( DRY_RUN )); then
    dry "add cli.github.com apt repo and install gh"
    return 0
  fi
  local keyring=/etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo_if_needed mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo_if_needed tee "$keyring" >/dev/null
  sudo_if_needed chmod go+r "$keyring"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://cli.github.com/packages stable main" \
    | sudo_if_needed tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo_if_needed apt-get update -qq
  sudo_if_needed apt-get install -y gh
}

# /releases/latest redirect avoids the 60-req/hr unauth API rate limit.
gh_latest_tag() {
  local repo="$1" resolved tag
  resolved=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$repo/releases/latest" 2>/dev/null || true)
  tag="${resolved##*/tag/}"
  [[ -z "$tag" || "$tag" == "$resolved" ]] && return 1
  echo "$tag"
}

install_eza_linux() {
  command -v eza >/dev/null && return 0
  if apt-cache show eza >/dev/null 2>&1; then
    say "installing eza (apt)"
    sudo_if_needed apt-get install -y eza
    return 0
  fi
  say "installing eza (GitHub release)"
  if (( DRY_RUN )); then dry "fetch eza release binary"; return 0; fi
  local tag arch
  tag=$(gh_latest_tag eza-community/eza); tag="${tag:-v0.18.0}"
  case "$PHOENIX_ARCH" in
    x86_64)  arch=x86_64-unknown-linux-gnu ;;
    aarch64) arch=aarch64-unknown-linux-gnu ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/eza.tar.gz" "https://github.com/eza-community/eza/releases/download/$tag/eza_${arch}.tar.gz"
  tar -xzf "$tmp/eza.tar.gz" -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  mv "$tmp/eza" "$HOME/.local/bin/eza"
  chmod +x "$HOME/.local/bin/eza"
  rm -rf "$tmp"
}

install_lazygit_linux() {
  command -v lazygit >/dev/null && return 0
  say "installing lazygit (GitHub release)"
  if (( DRY_RUN )); then dry "fetch lazygit release binary"; return 0; fi
  local tag ver arch
  tag=$(gh_latest_tag jesseduffield/lazygit); tag="${tag:-v0.44.1}"
  ver="${tag#v}"
  case "$PHOENIX_ARCH" in
    x86_64)  arch=Linux_x86_64 ;;
    aarch64) arch=Linux_arm64 ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/lazygit.tar.gz" "https://github.com/jesseduffield/lazygit/releases/download/$tag/lazygit_${ver}_${arch}.tar.gz"
  tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit
  mkdir -p "$HOME/.local/bin"
  mv "$tmp/lazygit" "$HOME/.local/bin/lazygit"
  chmod +x "$HOME/.local/bin/lazygit"
  rm -rf "$tmp"
}

install_lazydocker_linux() {
  command -v lazydocker >/dev/null && return 0
  say "installing lazydocker (GitHub release)"
  if (( DRY_RUN )); then dry "fetch lazydocker release binary"; return 0; fi
  local tag ver arch
  tag=$(gh_latest_tag jesseduffield/lazydocker); tag="${tag:-v0.24.1}"
  ver="${tag#v}"
  case "$PHOENIX_ARCH" in
    x86_64)  arch=Linux_x86_64 ;;
    aarch64) arch=Linux_arm64 ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/lazydocker.tar.gz" "https://github.com/jesseduffield/lazydocker/releases/download/$tag/lazydocker_${ver}_${arch}.tar.gz"
  tar -xzf "$tmp/lazydocker.tar.gz" -C "$tmp" lazydocker
  mkdir -p "$HOME/.local/bin"
  mv "$tmp/lazydocker" "$HOME/.local/bin/lazydocker"
  chmod +x "$HOME/.local/bin/lazydocker"
  rm -rf "$tmp"
}

install_yazi_linux() {
  command -v yazi >/dev/null && return 0
  say "installing yazi (GitHub release)"
  if (( DRY_RUN )); then dry "fetch yazi release binary"; return 0; fi
  local tag arch
  tag=$(gh_latest_tag sxyazi/yazi); tag="${tag:-v0.3.3}"
  case "$PHOENIX_ARCH" in
    x86_64)  arch=x86_64-unknown-linux-gnu ;;
    aarch64) arch=aarch64-unknown-linux-gnu ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/yazi.zip" "https://github.com/sxyazi/yazi/releases/download/$tag/yazi-${arch}.zip"
  unzip -q "$tmp/yazi.zip" -d "$tmp"
  mkdir -p "$HOME/.local/bin"
  mv "$tmp/yazi-${arch}/yazi" "$HOME/.local/bin/yazi"
  mv "$tmp/yazi-${arch}/ya"   "$HOME/.local/bin/ya" 2>/dev/null || true
  chmod +x "$HOME/.local/bin/yazi"
  rm -rf "$tmp"
}

# Apt's neovim is too old for LazyVim (wants ≥ 0.9). Use the upstream stable
# tarball into /opt with a /usr/local/bin/nvim symlink.
install_neovim_linux() {
  if command -v nvim >/dev/null; then
    local ver
    ver=$(nvim --version 2>/dev/null | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ -n "$ver" ]]; then
      local maj min
      maj=$(echo "$ver" | cut -d. -f1 | tr -d v)
      min=$(echo "$ver" | cut -d. -f2)
      if (( maj > 0 || (maj == 0 && min >= 9) )); then
        say "neovim already installed ($ver)"
        return 0
      fi
      say "neovim $ver is too old for LazyVim — upgrading"
    fi
  fi
  say "installing neovim stable (GitHub release)"
  if (( DRY_RUN )); then dry "fetch neovim stable tarball, extract to /opt"; return 0; fi
  local url
  case "$PHOENIX_ARCH" in
    x86_64)  url="$NVIM_LINUX_TARBALL_URL_X86" ;;
    aarch64) url="$NVIM_LINUX_TARBALL_URL_ARM" ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/nvim.tar.gz" "$url"
  sudo_if_needed mkdir -p /opt
  sudo_if_needed rm -rf /opt/nvim-linux-x86_64 /opt/nvim-linux-arm64 /opt/nvim-linux64
  sudo_if_needed tar -C /opt -xzf "$tmp/nvim.tar.gz"
  local extracted
  extracted=$(tar -tzf "$tmp/nvim.tar.gz" | head -1 | cut -d/ -f1)
  sudo_if_needed ln -sf "/opt/$extracted/bin/nvim" /usr/local/bin/nvim
  rm -rf "$tmp"
}

install_zsh_fsh_linux() {
  local dst="$HOME/.zsh/plugins/fast-syntax-highlighting"
  [[ -d "$dst" ]] && return 0
  say "installing zsh-fast-syntax-highlighting"
  run git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting "$dst"
}

install_ghostty_linux() {
  # The Ghostty snap is sandboxed even when advertised as classic, which
  # prevents `command = zsh -l` from finding /usr/bin/zsh on the host —
  # Ghostty silently falls back to bash and phoenix.zsh never sources.
  # The .deb route puts Ghostty in /usr/bin with full host access.
  if command -v ghostty >/dev/null; then
    local ghostty_path; ghostty_path=$(command -v ghostty)
    if [[ "$ghostty_path" == /snap/* ]]; then
      say "removing snap ghostty (sandboxed — blocks zsh launch)"
      if (( DRY_RUN )); then dry "snap remove ghostty"
      else sudo_if_needed snap remove ghostty >/dev/null 2>&1 || warn "snap remove ghostty failed"; fi
    else
      say "ghostty already installed ($ghostty_path)"
      return 0
    fi
  fi

  say "installing ghostty via mkasberg/ghostty-ubuntu (.deb)"
  if (( DRY_RUN )); then dry "run mkasberg/ghostty-ubuntu install.sh"; return 0; fi

  if bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"; then
    ok_msg "ghostty installed via .deb"
    return 0
  fi

  warn "mkasberg ghostty .deb install failed — falling back to snap"
  if command -v snap >/dev/null; then
    if sudo_if_needed snap install ghostty --classic >/dev/null 2>&1; then
      ok_msg "ghostty installed via snap"
      warn "  snap confinement may prevent zsh launching; if tmux/banner don't appear,"
      warn "  remove the snap and run mkasberg's installer manually:"
      warn "    sudo snap remove ghostty"
      warn "    bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)\""
      return 0
    fi
    warn "snap install ghostty also failed"
  fi
  warn "could not auto-install Ghostty on this distro."
  warn "install manually from https://ghostty.org/download — phoenix works without it"
  warn "in any truecolor terminal (Alacritty, Kitty, foot, GNOME Terminal)."
  return 0
}

ok_msg() { printf "  %s✓%s %s\n" "$GRN" "$R" "$*"; }

install_nerd_font_linux() {
  local font_dir="$HOME/.local/share/fonts/ComicShannsMono"
  if [[ -d "$font_dir" ]] && ls "$font_dir"/*.ttf >/dev/null 2>&1; then
    say "ComicShannsMono Nerd Font already installed"
    return 0
  fi
  say "installing ComicShannsMono Nerd Font"
  if (( DRY_RUN )); then dry "fetch nerd font zip, extract to $font_dir, fc-cache"; return 0; fi
  run mkdir -p "$font_dir"
  local tmp; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/font.zip" "$NERD_FONT_ZIP_URL"
  unzip -qo "$tmp/font.zip" -d "$font_dir"
  rm -rf "$tmp"
  command -v fc-cache >/dev/null && run fc-cache -f "$font_dir"
}

# Without chsh: Ghostty's `command = zsh -l` *should* cover us, but the .deb
# install of Ghostty 1.3.1 silently drops that directive — terminals fall
# back to bash and phoenix.zsh never sources. chsh is the durable fix.
ensure_zsh_login_shell_linux() {
  local zsh_path
  zsh_path=$(command -v zsh) || { warn "zsh not on PATH — skipping default-shell change"; return 0; }

  # Read login shell from passwd, not $SHELL (lags chsh in already-running sessions).
  local login_shell
  login_shell=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
  if [[ "$login_shell" == "$zsh_path" || "$login_shell" == "/bin/zsh" || "$login_shell" == "/usr/bin/zsh" ]]; then
    say "default shell is already zsh ($login_shell)"
    return 0
  fi

  # chsh refuses shells absent from /etc/shells.
  if [[ -f /etc/shells ]] && ! grep -qxF "$zsh_path" /etc/shells; then
    say "registering $zsh_path in /etc/shells"
    if (( DRY_RUN )); then
      dry "echo $zsh_path | sudo tee -a /etc/shells"
    else
      echo "$zsh_path" | sudo_if_needed tee -a /etc/shells >/dev/null
    fi
  fi

  say "setting default shell to zsh ($zsh_path)"
  if (( DRY_RUN )); then dry "chsh -s $zsh_path $USER"; return 0; fi
  if sudo_if_needed chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    ok_msg "default shell set to zsh — log out and back in (or reboot) to activate"
    export PHOENIX_LOGIN_SHELL_CHANGED=1
  else
    warn "chsh failed — set the default shell manually:  chsh -s $zsh_path"
  fi
}

# Each helper runs in a subshell so `set -e` stays armed inside it — bash
# disables errexit when a function appears on the LHS of `||`, which would
# otherwise let a mid-function curl failure cascade silently.
install_linux_extras() {
  ( link_debian_renamed_binaries ) || warn "renaming bat/fd symlinks failed"
  ( install_starship_linux )       || warn "starship install failed — phoenix prompt won't show until installed"
  ( install_zoxide_linux )         || warn "zoxide install failed — 'cd <fragment>' won't work"
  ( install_atuin_linux )          || warn "atuin install failed — Ctrl-R history search won't work"
  ( install_gh_linux )             || warn "gh install failed — try later: sudo apt install gh (after the cli.github.com repo step)"
  ( install_eza_linux )            || warn "eza install failed — 'ls' alias will fall back to default ls"
  ( install_lazygit_linux )        || warn "lazygit install failed — 'lg' alias unavailable"
  ( install_lazydocker_linux )     || warn "lazydocker install failed — 'ld' alias unavailable"
  ( install_yazi_linux )           || warn "yazi install failed — 'y' file-manager alias unavailable"
  ( install_neovim_linux )         || warn "neovim install failed — LazyVim won't run; install nvim ≥ 0.9 and re-run"
  ( install_zsh_fsh_linux )        || warn "zsh-fast-syntax-highlighting clone failed — syntax highlighting off"
  ( install_ghostty_linux )        || warn "ghostty install failed — see message above"
  ( install_nerd_font_linux )      || warn "nerd font install failed — terminal will fall back to default font"
  # No subshell so PHOENIX_LOGIN_SHELL_CHANGED can propagate to do_install.
  ensure_zsh_login_shell_linux  || warn "couldn't set zsh as default shell — terminals may still launch bash"
}

backup_and_link() {
  local src="$1" dest="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    return 0
  fi
  if [[ -L "$dest" || -e "$dest" ]]; then
    local bak="${dest}.bak-$(date +%Y%m%d%H%M%S)"
    run mv "$dest" "$bak"
    say "backed up $dest → $bak"
  fi
  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
  say "linked $dest → $src"
}

ensure_zshrc_source() {
  local zshrc="$HOME/.zshrc"
  if [[ ! -f "$zshrc" ]]; then
    run touch "$zshrc"
  fi

  local exact=0 any=0
  if grep -Fqx "$SOURCE_LINE" "$zshrc" 2>/dev/null; then exact=1; fi
  if grep -Eq "$SOURCE_LINE_PATTERN" "$zshrc" 2>/dev/null; then any=1; fi
  local count=0
  if (( any )); then
    count=$(grep -Ec "$SOURCE_LINE_PATTERN" "$zshrc" 2>/dev/null || echo 0)
  fi

  if (( exact && count == 1 )); then
    return 0
  fi

  if (( any )); then
    say "rewriting phoenix.zsh source line in ~/.zshrc"
    if (( DRY_RUN )); then
      dry "strip $count phoenix.zsh source line(s) and re-add $SOURCE_LINE"
      return 0
    fi
    local tmp; tmp=$(mktemp)
    grep -Ev "$SOURCE_LINE_PATTERN" "$zshrc" > "$tmp" || true
    mv "$tmp" "$zshrc"
  fi

  say "appending phoenix.zsh source line to ~/.zshrc"
  if (( DRY_RUN )); then
    dry "append # Phoenix Term + $SOURCE_LINE to $zshrc"
  else
    printf "\n# Phoenix Term\n%s\n" "$SOURCE_LINE" >> "$zshrc"
  fi
}

install_packages_macos() {
  if ! command -v brew >/dev/null; then
    say "installing Homebrew"
    if (( DRY_RUN )); then
      dry "curl Homebrew install script | bash"
    else
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    fi
  fi
  say "installing brew packages"
  install_brew_packages
}

install_packages_debian() {
  say "installing apt packages"
  install_apt_packages
  say "installing Linux extras (starship, eza, lazygit, lazydocker, neovim, ghostty, fonts, …)"
  install_linux_extras
}

do_install() {
  detect_os
  preflight

  case "$PHOENIX_OS" in
    macos)  install_packages_macos ;;
    debian) install_packages_debian ;;
  esac

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    say "installing Oh-My-Zsh"
    if (( DRY_RUN )); then
      dry "curl Oh-My-Zsh install script | sh (RUNZSH=no CHSH=no)"
    else
      RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
  fi

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [[ ! -d "$zsh_custom/plugins/zsh-completions" ]]; then
    say "installing zsh-completions plugin"
    run git clone --depth 1 https://github.com/zsh-users/zsh-completions "$zsh_custom/plugins/zsh-completions"
  fi

  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    say "installing TPM (tmux plugin manager)"
    run git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi

  # Must run BEFORE the LINKS loop: LazyVim clones into ~/.config/nvim and
  # refuses if the dir is non-empty, which a stray symlink from a previous
  # run would cause.
  if [[ ! -e "$HOME/.config/nvim/init.lua" ]]; then
    say "bootstrapping LazyVim starter into ~/.config/nvim"
    if (( DRY_RUN )); then
      dry "git clone LazyVim/starter ~/.config/nvim && rm -rf ~/.config/nvim/.git"
    else
      if [[ -d "$HOME/.config/nvim" ]] && [[ -n "$(ls -A "$HOME/.config/nvim" 2>/dev/null)" ]]; then
        local bak="$HOME/.config/nvim.bak-$(date +%Y%m%d%H%M%S)"
        mv "$HOME/.config/nvim" "$bak"
        say "backed up ~/.config/nvim → $bak"
      fi
      git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
      rm -rf "$HOME/.config/nvim/.git"
    fi
  fi

  local figlet_fonts=""
  case "$PHOENIX_OS" in
    macos)  figlet_fonts="$(brew --prefix 2>/dev/null)/share/figlet/fonts" ;;
    debian)
      for d in /usr/share/figlet /usr/share/figlet/fonts; do
        [[ -d "$d" ]] && figlet_fonts="$d" && break
      done
      ;;
  esac
  if [[ -n "$figlet_fonts" && -d "$figlet_fonts" && ! -f "$figlet_fonts/ANSI_Shadow.flf" ]]; then
    say "installing ANSI_Shadow figlet font"
    if [[ "$PHOENIX_OS" == "debian" ]]; then
      sudo_if_needed cp "$REPO/fonts/ANSI_Shadow.flf" "$figlet_fonts/"
    else
      run cp "$REPO/fonts/ANSI_Shadow.flf" "$figlet_fonts/"
    fi
  fi

  for entry in "${LINKS[@]}"; do
    backup_and_link "$REPO/${entry%%|*}" "${entry##*|}"
  done

  run chmod +x \
    "$HOME/.local/bin/phoenix-sysmon" \
    "$HOME/.local/bin/phoenix-sysmon-toggle" \
    "$HOME/.local/bin/phoenix-term" \
    "$HOME/.local/bin/phoenix-banner" \
    "$HOME/.local/bin/phoenix-tmux-init" \
    "$HOME/.local/bin/phoenix-tmux-rebalance" \
    "$HOME/.local/bin/phoenix-clip"

  ensure_zshrc_source

  if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
    say "installing tmux plugins"
    if (( DRY_RUN )); then
      dry "~/.tmux/plugins/tpm/bin/install_plugins"
    else
      "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || true
    fi
  fi

  local config_was_fresh=0
  [[ -f "$PHOENIX_CFG_FILE" ]] || config_was_fresh=1
  settings_ensure

  print_banner
  if [[ "${PHOENIX_LOGIN_SHELL_CHANGED:-0}" == "1" ]]; then
    printf "\n  %s!%s Your default shell was changed to zsh. ${SEA}Log out and back in${R}\n" "$YEL" "$R"
    printf "    (or reboot) for new terminal windows to pick it up.\n\n"
  fi

  if (( config_was_fresh )) && [[ -t 0 ]] && ! (( DRY_RUN )); then
    printf "\n  Customize settings now? %s[y/N]%s " "$DIM" "$R"
    local answer; read -r answer || answer=""
    case "$answer" in
      [yY]*) settings_menu ;;
    esac
  fi
}

print_banner() {
  cat <<EOF

${SEA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}
${SEA}  Phoenix Term installed.${R}

  Open a new Ghostty window (or run ${SEA}exec zsh${R}) to see it live.

  ${DIM}Customize:${R}
    export PHOENIX_WELCOME=0            # skip welcome banner
    export PHOENIX_AUTO_TMUX=0          # don't auto-launch tmux

  ${DIM}Tmux:${R}
    Ctrl-a S        toggle system-monitor sidebar
    Ctrl-a |        split right
    Ctrl-a -        split down

  ${DIM}Maintenance:${R}
    ${SEA}phoenix-term${R}              everyday CLI (run with no args for help)
    ${SEA}phoenix-term settings${R}     interactive preferences (welcome, auto-tmux, …)
    ${SEA}phoenix-term doctor${R}       check the install is healthy
    ${SEA}phoenix-term update${R}       fetch + fast-forward to latest release tag
    ${SEA}phoenix-term uninstall${R}    remove and restore backups
${SEA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}
EOF
}

# ---------- uninstall ----------

do_uninstall() {
  say "removing Phoenix Term symlinks (repo at $REPO will not be touched)"
  for entry in "${LINKS[@]}"; do
    local src="$REPO/${entry%%|*}" dest="${entry##*|}"
    if [[ -L "$dest" ]]; then
      local target; target="$(readlink "$dest")"
      if [[ "$target" == "$src" ]]; then
        run rm "$dest"
        say "removed $dest"
        local newest; newest=$(ls -1t "${dest}.bak-"* 2>/dev/null | head -1 || true)
        if [[ -n "$newest" ]]; then
          run mv "$newest" "$dest"
          say "restored $dest ← $(basename "$newest")"
        fi
      else
        warn "$dest → $target is not ours — leaving alone"
      fi
    elif [[ -e "$dest" ]]; then
      warn "$dest exists but is not a symlink — leaving alone"
    fi
  done

  local zshrc="$HOME/.zshrc"
  if [[ -f "$zshrc" ]] && grep -Eq "$SOURCE_LINE_PATTERN" "$zshrc"; then
    say "stripping phoenix.zsh source line from ~/.zshrc"
    if (( DRY_RUN )); then
      dry "remove phoenix.zsh source line(s) from $zshrc"
    else
      local tmp; tmp=$(mktemp)
      awk -v pat="$SOURCE_LINE_PATTERN" '
        { lines[NR]=$0 }
        END {
          for (i=1; i<=NR; i++) {
            if (lines[i] ~ pat) continue
            if (lines[i]=="# Phoenix Term" && i<NR && lines[i+1] ~ pat) continue
            print lines[i]
          }
        }
      ' "$zshrc" > "$tmp"
      mv "$tmp" "$zshrc"
    fi
  fi

  printf "\n%s  Phoenix Term uninstalled.%s\n\n" "$SEA" "$R"
}

# ---------- doctor ----------

do_doctor() {
  detect_os
  local fail=0
  printf "%sPhoenix Term — healthcheck%s  %s(%s/%s)%s\n\n" \
    "$SEA" "$R" "$DIM" "$PHOENIX_OS" "$PHOENIX_ARCH" "$R"

  printf "%ssymlinks%s\n" "$DIM" "$R"
  for entry in "${LINKS[@]}"; do
    local src="$REPO/${entry%%|*}" dest="${entry##*|}"
    if [[ ! -e "$src" ]]; then
      bad "$dest (repo source missing: $src)"; fail=1; continue
    fi
    if [[ ! -L "$dest" ]]; then
      if [[ -e "$dest" ]]; then bad "$dest (exists but not a symlink)"
      else bad "$dest (missing)"; fi
      fail=1; continue
    fi
    local target; target="$(readlink "$dest")"
    if [[ "$target" != "$src" ]]; then
      bad "$dest → $target (expected $src)"; fail=1; continue
    fi
    ok "$dest"
  done

  case "$PHOENIX_OS" in
    macos)
      printf "\n%sbrew formulas%s\n" "$DIM" "$R"
      if command -v brew >/dev/null; then
        local installed
        installed=$(brew list --formula -1 2>/dev/null || true)
        for f in "${BREW_FORMULAS[@]}"; do
          if grep -qx "$f" <<<"$installed"; then ok "$f"; else bad "$f"; fail=1; fi
        done
        printf "\n%sbrew casks%s\n" "$DIM" "$R"
        installed=$(brew list --cask -1 2>/dev/null || true)
        for c in "${BREW_CASKS[@]}"; do
          if grep -qx "$c" <<<"$installed"; then ok "$c"; else bad "$c"; fail=1; fi
        done
      else
        bad "brew not in PATH"; fail=1
      fi
      ;;
    debian)
      printf "\n%sapt packages%s\n" "$DIM" "$R"
      for pkg in "${APT_PACKAGES[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then ok "$pkg"; else bad "$pkg"; fail=1; fi
      done
      printf "\n%sLinux extras%s\n" "$DIM" "$R"
      local tool
      for tool in starship zoxide atuin gh eza lazygit lazydocker yazi nvim; do
        if command -v "$tool" >/dev/null; then ok "$tool ($(command -v "$tool"))"
        else bad "$tool not in PATH"; fail=1; fi
      done
      if [[ -d "$HOME/.zsh/plugins/fast-syntax-highlighting" ]]; then
        ok "zsh-fast-syntax-highlighting"
      else
        bad "zsh-fast-syntax-highlighting missing"; fail=1
      fi
      if [[ -d "$HOME/.local/share/fonts/ComicShannsMono" ]] \
         && ls "$HOME/.local/share/fonts/ComicShannsMono"/*.ttf >/dev/null 2>&1; then
        ok "ComicShannsMono Nerd Font"
      else
        bad "ComicShannsMono Nerd Font missing"; fail=1
      fi
      if command -v ghostty >/dev/null; then ok "ghostty ($(command -v ghostty))"
      else bad "ghostty not in PATH — install manually if needed"; fail=1; fi
      ;;
  esac

  printf "\n%sshell wiring%s\n" "$DIM" "$R"
  if [[ -f "$HOME/.zshrc" ]] && grep -Fqx "$SOURCE_LINE" "$HOME/.zshrc"; then
    ok "~/.zshrc sources $REPO/shell/phoenix.zsh"
  elif [[ -f "$HOME/.zshrc" ]] && grep -Eq "$SOURCE_LINE_PATTERN" "$HOME/.zshrc"; then
    bad "~/.zshrc sources phoenix.zsh from a different repo path — re-run install"
    fail=1
  else
    bad "~/.zshrc does not source phoenix.zsh"; fail=1
  fi

  printf "\n%sfiglet font%s\n" "$DIM" "$R"
  local figlet_fonts=""
  case "$PHOENIX_OS" in
    macos) figlet_fonts="$(brew --prefix 2>/dev/null)/share/figlet/fonts" ;;
    debian)
      for d in /usr/share/figlet /usr/share/figlet/fonts; do
        [[ -d "$d" ]] && figlet_fonts="$d" && break
      done
      ;;
  esac
  if [[ -n "$figlet_fonts" && -f "$figlet_fonts/ANSI_Shadow.flf" ]]; then
    ok "ANSI_Shadow.flf installed ($figlet_fonts)"
  else
    bad "ANSI_Shadow.flf missing in ${figlet_fonts:-(figlet not installed)}"; fail=1
  fi

  printf "\n%sruntime deps%s\n" "$DIM" "$R"
  if command -v python3 >/dev/null; then ok "python3 ($(python3 --version 2>&1))"
  else bad "python3 missing — phoenix-sysmon won't run"; fail=1; fi
  if command -v nvim >/dev/null; then ok "nvim ($(nvim --version | head -1))"
  else bad "nvim missing"; fail=1; fi
  if [[ -f "$HOME/.config/nvim/init.lua" ]]; then ok "~/.config/nvim/init.lua (LazyVim)"
  else bad "~/.config/nvim/init.lua missing — LazyVim not bootstrapped"; fail=1; fi

  printf "\n"
  if (( fail )); then
    printf "%sissues found — run %sbash install.sh%s%s to repair.%s\n" "$RED" "$SEA" "$R" "$RED" "$R"
    exit 1
  fi
  printf "%sall green.%s\n" "$GRN" "$R"
}

# ---------- version / check / update (GitHub Releases over HTTPS) ----------
#
# Updates track GitHub Releases (not git tags). /releases/latest redirect
# avoids API auth + the 60-req/hr unauth rate limit. Installed version is
# $REPO/.version (written by bootstrap.sh / do_update); dev clones fall
# back to `git describe`.

PHOENIX_GH_REPO="${PHOENIX_GH_REPO:-DevGeekPhoenix/phoenix-term}"
UPDATE_STAMP="$HOME/.cache/phoenix-term/last-check"
LATEST_CACHE="$HOME/.cache/phoenix-term/latest-release"
VERSION_FILE="$REPO/.version"

phoenix_current_version() {
  if [[ -f "$VERSION_FILE" ]]; then
    head -1 "$VERSION_FILE" | tr -d '[:space:]'
    return 0
  fi
  if command git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    command git -C "$REPO" describe --tags --abbrev=0 HEAD 2>/dev/null || true
  fi
}

phoenix_fetch_latest_release() {
  local resolved tag
  resolved=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$PHOENIX_GH_REPO/releases/latest" 2>/dev/null || true)
  tag="${resolved##*/tag/}"
  if [[ -z "$tag" || "$tag" == "$resolved" ]]; then
    return 1
  fi
  mkdir -p "$(dirname "$LATEST_CACHE")"
  printf '%s\n' "$tag" > "$LATEST_CACHE"
  date +%s > "$UPDATE_STAMP"
  printf '%s\n' "$tag"
}

phoenix_latest_release_cached() {
  [[ -f "$LATEST_CACHE" ]] && head -1 "$LATEST_CACHE" | tr -d '[:space:]'
}

do_version() {
  local cur cached
  cur=$(phoenix_current_version)
  cached=$(phoenix_latest_release_cached)

  if [[ -n "$cur" ]]; then
    printf "%sPhoenix Term%s  %s%s%s  (%s)\n" \
      "$SEA" "$R" "$SEA$B" "$cur" "$R" "$REPO"
  else
    printf "%sPhoenix Term%s  %sdev clone%s  (%s)\n" \
      "$SEA" "$R" "$DIM" "$R" "$REPO"
  fi

  if [[ -n "$cached" && "$cached" != "$cur" ]]; then
    printf "  %s▲ latest release: %s%s  (run %sphoenix-term update%s)\n" \
      "$YEL" "$cached" "$R" "$SEA" "$R"
  fi
}

do_check() {
  say "checking latest release on $PHOENIX_GH_REPO"
  local latest cur
  latest=$(phoenix_fetch_latest_release) \
    || { warn "could not resolve latest release — network down or no releases published yet"; exit 1; }
  cur=$(phoenix_current_version)

  if [[ -z "$cur" ]]; then
    printf "%s▲%s no installed version recorded — latest is %s%s%s\n" \
      "$YEL" "$R" "$SEA$B" "$latest" "$R"
    printf "\n  Run %sphoenix-term update%s to install %s.\n" "$SEA" "$R" "$latest"
    return 0
  fi
  if [[ "$cur" == "$latest" ]]; then
    printf "%s✓%s on the latest release: %s%s%s\n" "$GRN" "$R" "$SEA$B" "$latest" "$R"
    return 0
  fi
  printf "%s▲%s update available: %s%s%s → %s%s%s\n" \
    "$YEL" "$R" "$DIM" "$cur" "$R" "$SEA$B" "$latest" "$R"
  printf "\n  Run %sphoenix-term update%s to upgrade to %s.\n" "$SEA" "$R" "$latest"
}

do_update() {
  # Dev clones (git checkouts) are the user's working tree — don't clobber.
  if [[ -d "$REPO/.git" ]]; then
    warn "$REPO is a git clone — use 'git pull' here, not 'phoenix-term update'"
    warn "the release-based updater is for installs made via bootstrap.sh"
    exit 1
  fi

  say "checking latest release on $PHOENIX_GH_REPO"
  local latest cur
  latest=$(phoenix_fetch_latest_release) \
    || { warn "could not resolve latest release — network down?"; exit 1; }
  cur=$(phoenix_current_version)

  if [[ -n "$cur" && "$cur" == "$latest" ]]; then
    say "already on the latest release: $latest"
    return 0
  fi

  local url="https://github.com/$PHOENIX_GH_REPO/archive/refs/tags/$latest.tar.gz"
  say "downloading $latest"
  if (( DRY_RUN )); then
    dry "curl $url, extract, replace $REPO, re-exec install.sh"
    return 0
  fi

  local tmp src_dir
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  curl -fsSL --retry 3 --connect-timeout 10 "$url" -o "$tmp/phoenix.tar.gz" \
    || { warn "download failed: $url"; exit 1; }
  tar -C "$tmp" -xzf "$tmp/phoenix.tar.gz"
  src_dir=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
  [[ -d "$src_dir" ]] || { warn "extraction failed"; exit 1; }

  local bak="$REPO.bak-$(date +%Y%m%d%H%M%S)"
  say "moving $REPO → $bak"
  mv "$REPO" "$bak"
  mv "$src_dir" "$REPO"
  echo "$latest" > "$REPO/.version"

  if [[ -f "$HOME/.config/phoenix-term/config.zsh" ]]; then
    say "user settings preserved → $HOME/.config/phoenix-term/config.zsh"
  fi

  say "re-running install.sh from $latest"
  exec bash "$REPO/install.sh"
}

# ---------- backups / revert ----------

phoenix_list_backups() {
  local dir version ts human
  for dir in $(ls -1dt "$REPO".bak-* 2>/dev/null); do
    [[ -d "$dir" ]] || continue
    version="(unknown)"
    if [[ -f "$dir/.version" ]]; then
      version=$(head -1 "$dir/.version" 2>/dev/null | tr -d '[:space:]')
      [[ -z "$version" ]] && version="(unknown)"
    fi
    ts="${dir##*.bak-}"
    if [[ ${#ts} -eq 14 ]]; then
      human="${ts:0:4}-${ts:4:2}-${ts:6:2} ${ts:8:2}:${ts:10:2}:${ts:12:2}"
    else
      human="$ts"
    fi
    printf "%s|%s|%s\n" "$dir" "$version" "$human"
  done
}

do_backups() {
  printf "%sPhoenix Term — backups%s  %s($REPO.bak-*)%s\n\n" \
    "$SEA" "$R" "$DIM" "$R"
  local entries
  entries=$(phoenix_list_backups)
  if [[ -z "$entries" ]]; then
    printf "  %sno backups yet — they're created automatically by%s %sphoenix-term update%s.\n" \
      "$DIM" "$R" "$SEA" "$R"
    return 0
  fi
  printf "  %-4s  %-14s  %-19s  %s\n" "#" "VERSION" "DATE" "PATH"
  printf "  %s%s%s\n" "$DIM" "────  ──────────────  ───────────────────  ────" "$R"
  local i=1 path version date_iso
  while IFS='|' read -r path version date_iso; do
    printf "  %s%-4d%s  %s%-14s%s  %s  %s\n" \
      "$SEA" "$i" "$R" "$SEA$B" "$version" "$R" "$date_iso" "${path/#$HOME/~}"
    i=$((i+1))
  done <<< "$entries"
  printf "\n  Roll back to the most recent: %sphoenix-term revert%s\n" "$SEA" "$R"
}

do_revert() {
  if [[ -d "$REPO/.git" ]]; then
    warn "$REPO is a git clone — use git commands here, not 'phoenix-term revert'"
    warn "(the revert flow is for release-tarball installs made via bootstrap.sh)"
    exit 1
  fi

  local target
  target=$(phoenix_list_backups | head -1 | cut -d'|' -f1)
  if [[ -z "$target" ]]; then
    warn "no backups found at $REPO.bak-*"
    warn "backups are created automatically by 'phoenix-term update' — there's nothing to roll back to."
    exit 1
  fi

  local target_version="(unknown)" cur_version="(unknown)"
  [[ -f "$target/.version" ]] && target_version=$(head -1 "$target/.version" 2>/dev/null | tr -d '[:space:]')
  [[ -f "$REPO/.version"   ]] && cur_version=$(head -1 "$REPO/.version"   2>/dev/null | tr -d '[:space:]')

  printf "\n%sPhoenix Term — revert%s\n" "$SEA" "$R"
  printf "  %sfrom:%s  %s%s%s  (%s)\n"  "$DIM" "$R" "$SEA$B" "$cur_version"    "$R" "$REPO"
  printf "  %sto:%s    %s%s%s  (%s)\n\n" "$DIM" "$R" "$SEA$B" "$target_version" "$R" "$target"

  if (( DRY_RUN )); then
    dry "rotate $REPO → new .bak-<ts>, move $target into place, re-exec install.sh"
    return 0
  fi

  # Revert is itself revertable: rotate current aside, then restore target.
  local rolled="$REPO.bak-$(date +%Y%m%d%H%M%S)"
  mv "$REPO" "$rolled"
  say "rotated current install → $rolled"
  mv "$target" "$REPO"
  say "restored $target → $REPO"

  if [[ -f "$HOME/.config/phoenix-term/config.zsh" ]]; then
    say "user settings preserved → $HOME/.config/phoenix-term/config.zsh"
  fi

  say "re-running install.sh to refresh symlinks against $target_version"
  exec bash "$REPO/install.sh"
}

# ---------- settings ----------
#
# Settings row layout:  KEY | DEFAULT | TYPE | DESCRIPTION | TYPE_ARGS
#   TYPE ∈ { text, enum, path, bool }
#   TYPE_ARGS  enum → "v1,v2,…"; bool → "on/off" (slash, not |, since | is the
#                                                  outer-row delimiter).

PHOENIX_CFG_DIR="$HOME/.config/phoenix-term"
PHOENIX_CFG_FILE="$PHOENIX_CFG_DIR/config.zsh"

SETTINGS=(
  "PHOENIX_NAME|DEV PHOENIX|text|Your name shown on the welcome banner & sysmon title|"
  "PHOENIX_BANNER_STICKY|sticky|enum|How the welcome banner appears|sticky,inline,off"
  "PHOENIX_BG|phoenix|path|Ghostty background image (used when bg-mode=image) — path or 'phoenix'|"
  "PHOENIX_BG_MODE|image|enum|image: bg image with opaque banner/sysmon. color: solid color whole window|image,color"
  "PHOENIX_BG_COLOR|#0c0f11|text|Bg color (whole window when mode=color; banner/sysmon overlay when mode=image)|"
  "PHOENIX_NVIM_DEFAULT|1|bool|Make nvim the default editor (alias vi/vim, set \$EDITOR)|on/off"
)

PHOENIX_GHOSTTY_USER_CONF="$HOME/.config/ghostty/phoenix-user.conf"

settings_field() {
  local key="$1" n="$2" row
  for row in "${SETTINGS[@]}"; do
    if [[ "${row%%|*}" == "$key" ]]; then
      echo "$row" | cut -d'|' -f"$n"
      return 0
    fi
  done
  return 1
}

settings_default() { settings_field "$1" 2; }
settings_type()    { settings_field "$1" 3; }
settings_desc()    { settings_field "$1" 4; }
settings_type_args() { settings_field "$1" 5; }

settings_get() {
  # Reads only the config file; the shell env may carry stale values from
  # a prior `phoenix.zsh` source.
  local key="$1"
  if [[ -f "$PHOENIX_CFG_FILE" ]]; then
    local v; v=$(grep -E "^export $key=" "$PHOENIX_CFG_FILE" 2>/dev/null | tail -1 \
                 | sed -E "s/^export $key=//" | sed -E 's/^"(.*)"$/\1/')
    [[ -n "$v" ]] && { echo "$v"; return; }
  fi
  settings_default "$key"
}

settings_set() {
  local key="$1" value="$2"
  if ! settings_field "$key" 1 >/dev/null; then
    warn "unknown setting: $key"
    return 1
  fi
  local type; type=$(settings_type "$key")

  case "$type" in
    bool)
      [[ "$value" == "0" || "$value" == "1" ]] || {
        warn "$key is bool — value must be 0 or 1 (got: $value)"; return 1; }
      ;;
    enum)
      local args; args=$(settings_type_args "$key")
      if ! grep -qE "(^|,)$value(,|$)" <<<"$args"; then
        warn "$key: invalid value '$value' — must be one of: $args"
        return 1
      fi
      ;;
  esac

  run mkdir -p "$PHOENIX_CFG_DIR"
  (( DRY_RUN )) && { dry "set $key=$value in $PHOENIX_CFG_FILE"; return; }
  if [[ ! -f "$PHOENIX_CFG_FILE" ]]; then settings_ensure; fi

  # Apply side-effects BEFORE writing so a failure (e.g. missing image)
  # doesn't desync config from reality.
  case "$key" in
    PHOENIX_BG)       settings_apply_bg "$value" || return 1 ;;
    PHOENIX_BG_MODE)  settings_apply_bg_mode "$value" "$(settings_get PHOENIX_BG_COLOR)" ;;
    PHOENIX_BG_COLOR) settings_apply_bg_mode "$(settings_get PHOENIX_BG_MODE)" "$value" ;;
  esac

  local escaped="${value//\"/\\\"}"
  local tmp; tmp=$(mktemp)
  if grep -qE "^export $key=" "$PHOENIX_CFG_FILE"; then
    awk -v k="$key" -v v="\"$escaped\"" '
      $0 ~ "^export " k "=" { print "export " k "=" v; next }
      { print }
    ' "$PHOENIX_CFG_FILE" > "$tmp"
  else
    cat "$PHOENIX_CFG_FILE" > "$tmp"
    printf 'export %s="%s"\n' "$key" "$escaped" >> "$tmp"
  fi
  mv "$tmp" "$PHOENIX_CFG_FILE"
}

settings_apply_bg() {
  local value="$1"
  local dest="$HOME/.config/ghostty/phoenix-bg.jpg"
  local target
  case "$value" in
    phoenix|"") target="$REPO/ghostty/phoenix-bg.jpg" ;;
    "~/"*)      target="$HOME/${value#\~/}" ;;
    *)          target="$value" ;;
  esac
  if [[ ! -f "$target" ]]; then
    warn "background image not found: $target"
    return 1
  fi
  run mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" || -e "$dest" ]]; then run rm "$dest"; fi
  run ln -s "$target" "$dest"
  say "ghostty background → $target  (reload Ghostty to apply)"
}

settings_apply_bg_mode() {
  # mode/color passed explicitly because settings_set calls us BEFORE writing
  # the new value, so settings_get would still return the old one.
  local mode="${1:-image}"
  local color="${2:-$(settings_get PHOENIX_BG_COLOR)}"
  [[ -z "$color" ]] && color="#0c0f11"

  # ----- Ghostty override file -----

  run mkdir -p "$(dirname "$PHOENIX_GHOSTTY_USER_CONF")"
  if (( DRY_RUN )); then
    dry "write $PHOENIX_GHOSTTY_USER_CONF for mode=$mode color=$color"
  else
    case "$mode" in
      color)
        {
          echo "# Phoenix Term — generated by phoenix-term settings (mode=color)"
          echo "# Disable the wallpaper image and use a solid bg color."
          echo "background-image ="
          echo "background = $color"
        } > "$PHOENIX_GHOSTTY_USER_CONF"
        ;;
      *)
        {
          echo "# Phoenix Term — generated by phoenix-term settings (mode=image)"
          echo "# Image mode: main config's background-image directive stands."
        } > "$PHOENIX_GHOSTTY_USER_CONF"
        ;;
    esac
  fi

  # ----- tmux pane + border styling -----

  command -v tmux >/dev/null 2>&1 || return 0

  local pane_style border_style
  case "$mode" in
    image)
      pane_style="bg=default"
      border_style="fg=#1c2027"
      ;;
    color)
      pane_style="bg=$color"
      border_style="fg=#1c2027,bg=$color"
      ;;
  esac

  tmux set-option -g pane-border-style "$border_style" 2>/dev/null || true
  tmux set-option -g pane-active-border-style "$border_style" 2>/dev/null || true

  tmux list-panes -a -F '#{pane_id}' 2>/dev/null \
    | while read -r p; do
        tmux select-pane -t "$p" -P "$pane_style" 2>/dev/null || true
      done

  say "bg-mode $mode ($color) — reload Ghostty (cmd+,) to apply image/color change"
}

settings_ensure() {
  # CONTRACT: MUST NOT overwrite an existing config — user settings are
  # preserved across every install/update/revert. The early return is
  # load-bearing for that guarantee.
  if [[ -f "$PHOENIX_CFG_FILE" ]]; then return 0; fi
  run mkdir -p "$PHOENIX_CFG_DIR"
  if (( DRY_RUN )); then dry "write default config to $PHOENIX_CFG_FILE"; return; fi
  {
    echo "# Phoenix Term — preferences (edit with: phoenix-term settings)"
    echo "# Each value can also be exported in your shell before sourcing phoenix.zsh."
    echo
    local s key def
    for s in "${SETTINGS[@]}"; do
      key="${s%%|*}"
      def=$(echo "$s" | cut -d'|' -f2)
      printf 'export %s="%s"\n' "$key" "$def"
    done
  } > "$PHOENIX_CFG_FILE"
  say "wrote default config: $PHOENIX_CFG_FILE"
}

settings_render_label() {
  local key="$1" val="$2" type
  type=$(settings_type "$key")
  case "$type" in
    bool)
      local labels on off
      labels=$(settings_type_args "$key")
      on="${labels%%/*}"; off="${labels#*/}"
      if [[ "$val" == "1" ]]; then printf "%s%s%s" "$GRN" "$on" "$R"
      else printf "%s%s%s" "$YEL" "$off" "$R"; fi
      ;;
    enum)
      local default; default=$(settings_default "$key")
      if [[ "$val" == "$default" ]]; then printf "%s%s%s" "$GRN" "$val" "$R"
      elif [[ "$val" == "off" ]]; then printf "%s%s%s" "$YEL" "$val" "$R"
      else printf "%s%s%s" "$SEA" "$val" "$R"; fi
      ;;
    text)
      printf "%s%s%s" "$SEA" "$val" "$R"
      ;;
    path)
      if [[ "$val" == "phoenix" || -z "$val" ]]; then
        printf "%s%s%s" "$DIM" "phoenix (default)" "$R"
      else
        printf "%s%s%s" "$SEA" "${val/#$HOME/~}" "$R"
      fi
      ;;
    *)
      printf "%s" "$val"
      ;;
  esac
}

settings_edit_one() {
  local key="$1" type cur args
  type=$(settings_type "$key")
  cur=$(settings_get "$key")
  args=$(settings_type_args "$key")
  case "$type" in
    bool)
      local new
      if [[ "$cur" == "1" ]]; then new=0; else new=1; fi
      settings_set "$key" "$new"
      printf "%s✓%s %s = %s\n" "$GRN" "$R" "$key" "$(settings_render_label "$key" "$new")"
      ;;
    enum)
      printf "  Choices: %s\n" "$args"
      printf "  Current: %s\n" "$(settings_render_label "$key" "$cur")"
      printf "  New (Enter to keep): "
      local new; read -r new || true
      [[ -z "$new" ]] && return 0
      if ! grep -qE "(^|,)$new(,|$)" <<<"$args"; then
        warn "invalid value '$new' — must be one of: $args"
        return 1
      fi
      settings_set "$key" "$new"
      printf "%s✓%s %s = %s\n" "$GRN" "$R" "$key" "$(settings_render_label "$key" "$new")"
      ;;
    text)
      printf "  Current: %s\n" "$(settings_render_label "$key" "$cur")"
      printf "  New (Enter to keep): "
      local new; read -r new || true
      [[ -z "$new" ]] && return 0
      settings_set "$key" "$new"
      printf "%s✓%s %s = %s\n" "$GRN" "$R" "$key" "$(settings_render_label "$key" "$new")"
      ;;
    path)
      printf "  Current: %s\n" "$(settings_render_label "$key" "$cur")"
      printf "  New path (or 'phoenix' to reset, Enter to keep): "
      local new; read -r new || true
      [[ -z "$new" ]] && return 0
      settings_set "$key" "$new" || return 1
      printf "%s✓%s %s = %s\n" "$GRN" "$R" "$key" "$(settings_render_label "$key" "$(settings_get "$key")")"
      ;;
  esac
}

settings_menu() {
  settings_ensure
  while true; do
    printf "\n%s%sPhoenix Term — settings%s\n" "$SEA" "$B" "$R"
    printf "%sstored at %s%s\n\n" "$DIM" "$PHOENIX_CFG_FILE" "$R"
    local i=1 row key desc val
    for row in "${SETTINGS[@]}"; do
      key="${row%%|*}"
      desc=$(settings_desc "$key")
      val=$(settings_get "$key")
      printf "  %s%d)%s  %-23s  [%s]\n" "$SEA" "$i" "$R" "$key" "$(settings_render_label "$key" "$val")"
      printf "      %s%s%s\n" "$DIM" "$desc" "$R"
      i=$((i+1))
    done
    printf "\n  %sr)%s  reset all to defaults\n" "$SEA" "$R"
    printf "  %sq)%s  quit\n\n" "$SEA" "$R"
    printf "Choose %s1-%d%s, %sr%s, %sq%s: " "$SEA" "${#SETTINGS[@]}" "$R" "$SEA" "$R" "$SEA" "$R"
    local choice; read -r choice || return 0
    case "$choice" in
      [qQ]|exit|"") break ;;
      [rR])
        rm -f "$PHOENIX_CFG_FILE"
        settings_ensure
        settings_apply_bg phoenix || true
        say "reset to defaults"
        ;;
      [1-9])
        local idx=$((choice-1))
        if (( idx >= 0 && idx < ${#SETTINGS[@]} )); then
          settings_edit_one "${SETTINGS[$idx]%%|*}"
        else
          warn "no setting $choice"
        fi
        ;;
      *) warn "unknown choice: $choice" ;;
    esac
  done
  printf "%s•%s reload with: %sexec zsh%s\n" "$SEA" "$R" "$SEA" "$R"
}

do_settings() {
  local sub="${SETTINGS_ARG:-}"
  case "$sub" in
    --ensure)  settings_ensure ;;
    --get)
      local k="${SETTINGS_KEY:-}"
      [[ -z "$k" ]] && { warn "--get needs KEY"; exit 2; }
      settings_get "$k"
      ;;
    --set)
      local pair="${SETTINGS_KEY:-}"
      [[ "$pair" != *=* ]] && { warn "--set expects KEY=VALUE"; exit 2; }
      local k="${pair%%=*}" v="${pair#*=}"
      settings_set "$k" "$v" || exit 1
      printf "%s✓%s %s = %s\n" "$GRN" "$R" "$k" "$(settings_render_label "$k" "$(settings_get "$k")")"
      ;;
    --list|"")
      settings_ensure
      printf "%s%sPhoenix Term — settings%s  %s(%s)%s\n" "$SEA" "$B" "$R" "$DIM" "$PHOENIX_CFG_FILE" "$R"
      local row key desc val
      for row in "${SETTINGS[@]}"; do
        key="${row%%|*}"
        desc=$(settings_desc "$key")
        val=$(settings_get "$key")
        printf "  %-23s  [%s]  %s%s%s\n" "$key" "$(settings_render_label "$key" "$val")" "$DIM" "$desc" "$R"
      done
      ;;
    --menu)
      settings_menu
      ;;
    *) warn "unknown settings subcommand: $sub"; exit 2 ;;
  esac
}

case "$MODE" in
  install)   do_install ;;
  update)    do_update ;;
  check)     do_check ;;
  version)   do_version ;;
  uninstall) do_uninstall ;;
  doctor)    do_doctor ;;
  revert)    do_revert ;;
  backups)   do_backups ;;
  settings)  do_settings ;;
esac
