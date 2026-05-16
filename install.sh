#!/usr/bin/env bash
#
# Phoenix Term installer.
#   bash install.sh              # install (idempotent; backs up existing dotfiles)
#   bash install.sh --uninstall  # remove symlinks, restore backups, strip zshrc source line
#   bash install.sh --doctor     # check that an install is healthy
#   bash install.sh --dry-run    # print every action without touching the filesystem
#   bash install.sh --help
#

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
  bash install.sh --update         Fetch + fast-forward from origin, then re-link
  bash install.sh --check          Report current version and whether origin has updates
  bash install.sh --version        Print current commit + ahead/behind summary
  bash install.sh --uninstall      Remove symlinks, restore most-recent backups,
                                   strip the phoenix.zsh source line from ~/.zshrc
  bash install.sh --doctor         Verify symlinks, brew formulas, and shell wiring
  bash install.sh --settings       Manage preferences (welcome, auto-tmux, etc.)
                                    Subcommands: --list (default), --menu, --ensure,
                                    --get KEY, --set KEY=VALUE
  bash install.sh --help           Show this help

Flags:
  --dry-run    Print every filesystem action without performing it.
EOF
}

# Pre-parse: extract --settings <subcommand> [<key>] so subcommands aren't
# treated as unknown top-level flags.
ARGS=()
while (( $# )); do
  case "$1" in
    --settings)
      MODE=settings
      if [[ -n "${2:-}" && "${2:0:1}" == "-" ]]; then
        SETTINGS_ARG="$2"; shift
        # --get/--set take a KEY after the subcommand
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
  "nvim/colors/phoenix.lua|$HOME/.config/nvim/colors/phoenix.lua"
  "nvim/lua/plugins/colorscheme.lua|$HOME/.config/nvim/lua/plugins/colorscheme.lua"
  "nvim/lua/lualine/themes/phoenix.lua|$HOME/.config/nvim/lua/lualine/themes/phoenix.lua"
)

BREW_FORMULAS=(
  tmux starship zoxide fzf eza bat fd ripgrep lazygit gh atuin yazi
  btop tldr zsh-autosuggestions zsh-fast-syntax-highlighting figlet
)
BREW_CASKS=(ghostty font-comic-shanns-mono-nerd-font)

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

do_install() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    warn "Phoenix Term targets macOS; install on Linux at your own risk."
  fi

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

  local figlet_fonts
  figlet_fonts="$(brew --prefix 2>/dev/null)/share/figlet/fonts"
  if [[ -d "$figlet_fonts" && ! -f "$figlet_fonts/ANSI_Shadow.flf" ]]; then
    say "installing ANSI_Shadow figlet font"
    run cp "$REPO/fonts/ANSI_Shadow.flf" "$figlet_fonts/"
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
    "$HOME/.local/bin/phoenix-tmux-rebalance"

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

  # Offer to customize, but only on a real TTY and only on first install.
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
  local fail=0
  printf "%sPhoenix Term — healthcheck%s\n\n" "$SEA" "$R"

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
  local figlet_fonts; figlet_fonts="$(brew --prefix 2>/dev/null)/share/figlet/fonts"
  if [[ -f "$figlet_fonts/ANSI_Shadow.flf" ]]; then ok "ANSI_Shadow.flf installed"
  else bad "ANSI_Shadow.flf missing in $figlet_fonts"; fail=1; fi

  printf "\n"
  if (( fail )); then
    printf "%sissues found — run %sbash install.sh%s%s to repair.%s\n" "$RED" "$SEA" "$R" "$RED" "$R"
    exit 1
  fi
  printf "%sall green.%s\n" "$GRN" "$R"
}

# ---------- version / check / update (release-tag based) ----------
#
# The update flow keys on git tags ("releases"), not on commits.  Users
# only get notified when you publish a new tagged release.  Convention:
# tag releases as `vX.Y.Z` (annotated tags are nicer but lightweight works).

UPDATE_STAMP="$HOME/.cache/phoenix-term/last-check"

git_in_repo() { command git -C "$REPO" "$@"; }

require_git_repo() {
  if ! git_in_repo rev-parse --git-dir >/dev/null 2>&1; then
    warn "$REPO is not a git repository — initialize with: git -C $REPO init"
    exit 1
  fi
  if ! git_in_repo rev-parse HEAD >/dev/null 2>&1; then
    warn "no commits in $REPO yet — create one before checking for updates"
    exit 1
  fi
}

phoenix_origin_remote() {
  # First remote with "origin" in its name; fall back to the first remote.
  local remotes; remotes=$(git_in_repo remote 2>/dev/null)
  if grep -qx origin <<<"$remotes"; then echo origin
  else echo "$remotes" | head -1; fi
}

phoenix_current_release() {
  # The closest tag reachable from HEAD (the "version" we're running).
  # Returns empty when no tag is reachable; never errors out.
  git_in_repo describe --tags --abbrev=0 HEAD 2>/dev/null || true
}

phoenix_latest_release_local() {
  # Highest semver tag in the local repo, or empty if none exist.
  git_in_repo tag --list 'v*' --sort=-v:refname 2>/dev/null | head -1 || true
}

phoenix_fetch_releases() {
  # Fetch only tags from origin, quietly.  Touch the cache stamp so the
  # passive shell-startup check doesn't refetch on the next prompt.
  local remote; remote=$(phoenix_origin_remote)
  [[ -z "$remote" ]] && { warn "no remote configured — add one with: git -C $REPO remote add origin <url>"; return 1; }
  run git_in_repo fetch --quiet --tags --prune "$remote"
  mkdir -p "$(dirname "$UPDATE_STAMP")"
  date +%s > "$UPDATE_STAMP"
}

do_version() {
  require_git_repo
  local cur latest sha date branch ahead_commits
  cur=$(phoenix_current_release)
  latest=$(phoenix_latest_release_local)
  sha=$(git_in_repo rev-parse --short HEAD)
  date=$(git_in_repo log -1 --format=%cs)
  branch=$(git_in_repo rev-parse --abbrev-ref HEAD)

  if [[ -n "$cur" ]]; then
    printf "%sPhoenix Term%s  %s%s%s  (%s · %s · branch %s)\n" \
      "$SEA" "$R" "$SEA$B" "$cur" "$R" "$sha" "$date" "$branch"
    # If HEAD is past the tagged commit, show distance.
    ahead_commits=$(git_in_repo rev-list --count "$cur..HEAD" 2>/dev/null || echo 0)
    (( ahead_commits > 0 )) && printf "  %s%d commit(s) past %s%s\n" "$DIM" "$ahead_commits" "$cur" "$R"
  else
    printf "%sPhoenix Term%s  %sunreleased%s  (%s · %s · branch %s)\n" \
      "$SEA" "$R" "$DIM" "$R" "$sha" "$date" "$branch"
  fi

  if [[ -n "$latest" && "$latest" != "$cur" ]]; then
    printf "  %s▲ latest release: %s%s  (run %sphoenix-term update%s)\n" \
      "$YEL" "$latest" "$R" "$SEA" "$R"
  fi
}

do_check() {
  require_git_repo
  local remote; remote=$(phoenix_origin_remote)
  if [[ -z "$remote" ]]; then
    warn "no remote configured — add one with: git -C $REPO remote add origin <url>"
    exit 1
  fi
  say "fetching releases from $remote"
  phoenix_fetch_releases || exit 1

  local cur latest
  cur=$(phoenix_current_release)
  latest=$(phoenix_latest_release_local)

  if [[ -z "$latest" ]]; then
    printf "%s%s no releases tagged on %s yet.%s\n" "$DIM" "·" "$remote" "$R"
    printf "  %sTip:%s tag a release with: git -C $REPO tag v0.1.0 && git push $remote v0.1.0\n" "$DIM" "$R"
    return 0
  fi

  if [[ "$cur" == "$latest" ]]; then
    printf "%s✓%s on the latest release: %s%s%s\n" "$GRN" "$R" "$SEA$B" "$latest" "$R"
    return 0
  fi

  if [[ -z "$cur" ]]; then
    printf "%s▲%s no release pinned locally — latest is %s%s%s\n" "$YEL" "$R" "$SEA$B" "$latest" "$R"
  else
    printf "%s▲%s update available: %s%s%s → %s%s%s\n" \
      "$YEL" "$R" "$DIM" "$cur" "$R" "$SEA$B" "$latest" "$R"
  fi

  # Show release annotation if available.
  local notes; notes=$(git_in_repo tag -l --format='%(contents:subject)' "$latest" 2>/dev/null)
  [[ -n "$notes" ]] && printf "  %s%s%s\n" "$DIM" "$notes" "$R"

  printf "\n  Run %sphoenix-term update%s to fast-forward to %s.\n" "$SEA" "$R" "$latest"
}

do_update() {
  require_git_repo
  if ! git_in_repo diff --quiet || ! git_in_repo diff --cached --quiet; then
    warn "uncommitted changes in $REPO — commit or stash before --update"
    git_in_repo status --short
    exit 1
  fi
  local remote; remote=$(phoenix_origin_remote)
  if [[ -z "$remote" ]]; then
    warn "no remote configured — add one with: git -C $REPO remote add origin <url>"
    exit 1
  fi

  say "fetching releases from $remote"
  phoenix_fetch_releases || exit 1

  local cur latest
  cur=$(phoenix_current_release)
  latest=$(phoenix_latest_release_local)

  if [[ -z "$latest" ]]; then
    warn "no releases tagged on $remote yet — nothing to update to"
    exit 1
  fi
  if [[ "$cur" == "$latest" ]]; then
    say "already on the latest release: $latest"
    return 0
  fi

  # Refuse to move backwards: if the latest release is an ancestor of HEAD,
  # the user is ahead of the published release (probably mid-development).
  if git_in_repo merge-base --is-ancestor "$latest" HEAD 2>/dev/null; then
    warn "HEAD is already past $latest (you're ahead of the released version) — not moving"
    exit 1
  fi
  # Refuse non-fast-forward updates (local divergence from release line).
  if ! git_in_repo merge-base --is-ancestor HEAD "$latest" 2>/dev/null; then
    warn "your branch has diverged from $latest — fast-forward not possible"
    warn "resolve manually: git -C $REPO log --oneline ${cur:-HEAD}..$latest"
    exit 1
  fi

  say "fast-forwarding ${cur:-HEAD} → $latest"
  run git_in_repo merge --ff-only "$latest"

  if (( DRY_RUN )); then
    dry "would re-exec install.sh to apply any new symlinks"
    return 0
  fi
  say "re-running install.sh from $latest"
  exec bash "$REPO/install.sh"
}

# ---------- settings ----------
#
# User preferences stored as sourceable shell at ~/.config/phoenix-term/config.zsh.
# phoenix.zsh sources it at the top of every interactive shell, so the env vars
# are set before any behavior check runs.
#
# Row layout:  KEY | DEFAULT | TYPE | DESCRIPTION | TYPE_ARGS
#   TYPE      ∈ { text, enum, path, bool }
#   TYPE_ARGS  enum → comma-separated allowed values (first one is "on" color)
#              bool → "on-label|off-label"  (using a literal | INSIDE the field
#                                            isn't possible with our delimiter,
#                                            so use a slash:  "on/off")

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

# Generated Ghostty overrides written by settings — points at this file
# from repo/ghostty/phoenix.config's `config-file` directive. The phoenix
# main config never gets edited; mode changes only touch this user file.
PHOENIX_GHOSTTY_USER_CONF="$HOME/.config/ghostty/phoenix-user.conf"

settings_field() {
  # Echo the Nth (1-based) field of the row matching KEY in SETTINGS.
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
  # Reads only the persisted config file. The shell env may carry stale
  # values from a prior `phoenix.zsh` source, so we deliberately ignore it.
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

  # Type-specific validation, applied before any side-effect.
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

  # Apply side-effects before writing, so a failure (e.g. missing image)
  # doesn't leave the config out of sync with reality. Pass new values
  # explicitly — settings_get reads the file, which hasn't been written yet.
  case "$key" in
    PHOENIX_BG)       settings_apply_bg "$value" || return 1 ;;
    PHOENIX_BG_MODE)  settings_apply_bg_mode "$value" "$(settings_get PHOENIX_BG_COLOR)" ;;
    PHOENIX_BG_COLOR) settings_apply_bg_mode "$(settings_get PHOENIX_BG_MODE)" "$value" ;;
  esac

  # Always quote stored values so spaces (e.g. PHOENIX_NAME="My Name") survive.
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
  # Resolve a PHOENIX_BG value to an image path and repoint the symlink.
  #   "phoenix"   → repo's ghostty/phoenix-bg.jpg
  #   "<path>"    → that file (expanded, must exist)
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
  # Two modes:
  #   image  — Ghostty draws the wallpaper. No per-pane styling; the
  #            image shows through banner, main, sysmon, and dividers.
  #   color  — Ghostty's `background = <color>` paints the whole window.
  #            Cells inherit it. We also set the pane-border bg so the
  #            1-cell divider line picks up the same color.
  # Mode and color are passed explicitly — settings_set calls us with the
  # new values before they hit the config file, so we can't rely on
  # settings_get for whichever is changing.
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
      # Every pane transparent. Image shows through; dividers stay default.
      pane_style="bg=default"
      border_style="fg=#1c2027"
      ;;
    color)
      # Every pane explicitly painted with the bg color. Dividers too.
      pane_style="bg=$color"
      border_style="fg=#1c2027,bg=$color"
      ;;
  esac

  tmux set-option -g pane-border-style "$border_style" 2>/dev/null || true
  tmux set-option -g pane-active-border-style "$border_style" 2>/dev/null || true

  # Apply pane bg to EVERY phoenix pane across all sessions — not just
  # banner/sysmon, also the main shell pane so its cells (and any cells
  # without explicit bg in its content) match the chosen mode.
  tmux list-panes -a -F '#{pane_id}' 2>/dev/null \
    | while read -r p; do
        tmux select-pane -t "$p" -P "$pane_style" 2>/dev/null || true
      done

  say "bg-mode $mode ($color) — reload Ghostty (cmd+,) to apply image/color change"
}

settings_ensure() {
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
  # Colored, human-friendly rendering of a value, given its key.
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
        # Squash $HOME → ~ for readability.
        printf "%s%s%s" "$SEA" "${val/#$HOME/~}" "$R"
      fi
      ;;
    *)
      printf "%s" "$val"
      ;;
  esac
}

settings_edit_one() {
  # Drive the per-setting prompt based on the field's type.
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
        # Also reset the background symlink to repo default.
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
  settings)  do_settings ;;
esac
