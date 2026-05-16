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
R=$'\e[0m'

say()  { printf "%s•%s %s\n" "$SEA" "$R" "$*"; }
warn() { printf "%s!%s %s\n" "$YEL" "$R" "$*" >&2; }
ok()   { printf "  %s✓%s %s\n" "$GRN" "$R" "$*"; }
bad()  { printf "  %s✗%s %s\n" "$RED" "$R" "$*"; }
dry()  { printf "%s[dry-run]%s %s\n" "$DIM" "$R" "$*"; }

DRY_RUN=0
MODE=install

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
  bash install.sh --help           Show this help

Flags:
  --dry-run    Print every filesystem action without performing it.
EOF
}

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

  run chmod +x "$HOME/.local/bin/phoenix-sysmon" "$HOME/.local/bin/phoenix-sysmon-toggle"

  ensure_zshrc_source

  if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
    say "installing tmux plugins"
    if (( DRY_RUN )); then
      dry "~/.tmux/plugins/tpm/bin/install_plugins"
    else
      "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || true
    fi
  fi

  print_banner
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
    bash install.sh --doctor        check the install is healthy
    bash install.sh --uninstall     remove and restore backups
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

# ---------- version / check / update ----------

UPDATE_STAMP="$HOME/.cache/phoenix-term/last-check"

git_in_repo() { command git -C "$REPO" "$@"; }

git_upstream() {
  # Echo the upstream ref (e.g. origin/main) or empty if not configured.
  git_in_repo rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null
}

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

do_version() {
  require_git_repo
  local short date branch upstream ahead behind
  short=$(git_in_repo rev-parse --short HEAD)
  date=$(git_in_repo log -1 --format=%cs)
  branch=$(git_in_repo rev-parse --abbrev-ref HEAD)
  upstream=$(git_upstream)
  printf "%sPhoenix Term%s  %s%s%s  (%s, branch %s)\n" \
    "$SEA" "$R" "$SEA$B" "$short" "$R" "$date" "$branch"
  if [[ -n "$upstream" ]]; then
    ahead=$(git_in_repo rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)
    behind=$(git_in_repo rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)
    printf "  vs %s: %s%d ahead%s, %s%d behind%s\n" \
      "$upstream" "$SEA" "$ahead" "$R" "$SEA" "$behind" "$R"
  else
    printf "  %sno upstream configured%s — set one with: git -C %s push -u origin %s\n" \
      "$DIM" "$R" "$REPO" "$branch"
  fi
}

do_check() {
  require_git_repo
  local upstream; upstream=$(git_upstream)
  if [[ -z "$upstream" ]]; then
    warn "no upstream configured — push first: git -C $REPO push -u origin \$(git -C $REPO branch --show-current)"
    exit 1
  fi
  say "fetching $upstream"
  run git_in_repo fetch --quiet "${upstream%%/*}"
  mkdir -p "$(dirname "$UPDATE_STAMP")"
  date +%s > "$UPDATE_STAMP"

  local behind ahead
  behind=$(git_in_repo rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)
  ahead=$(git_in_repo rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)

  if (( behind == 0 )); then
    printf "%s✓%s already up to date with %s\n" "$GRN" "$R" "$upstream"
    (( ahead > 0 )) && printf "  %s(%d local commit(s) not yet pushed)%s\n" "$DIM" "$ahead" "$R"
    return 0
  fi

  printf "%s▲%s %d new commit(s) on %s:\n" "$YEL" "$R" "$behind" "$upstream"
  git_in_repo log "HEAD..$upstream" --oneline --no-decorate | sed 's/^/    /'
  printf "\n  Run %sbash install.sh --update%s to fast-forward.\n" "$SEA" "$R"
  (( ahead > 0 )) && printf "  %s(also %d local commit(s) not yet pushed)%s\n" "$DIM" "$ahead" "$R"
}

do_update() {
  require_git_repo
  local upstream; upstream=$(git_upstream)
  if [[ -z "$upstream" ]]; then
    warn "no upstream configured — push first: git -C $REPO push -u origin \$(git -C $REPO branch --show-current)"
    exit 1
  fi
  if ! git_in_repo diff --quiet || ! git_in_repo diff --cached --quiet; then
    warn "uncommitted changes in $REPO — commit or stash before --update"
    git_in_repo status --short
    exit 1
  fi

  say "fetching $upstream"
  run git_in_repo fetch --quiet "${upstream%%/*}"

  local behind ahead
  behind=$(git_in_repo rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)
  ahead=$(git_in_repo rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)

  if (( ahead > 0 )); then
    warn "local branch is $ahead commit(s) ahead of $upstream — push or rebase first"
    exit 1
  fi
  if (( behind == 0 )); then
    say "already up to date with $upstream"
    mkdir -p "$(dirname "$UPDATE_STAMP")"; date +%s > "$UPDATE_STAMP"
    return 0
  fi

  say "fast-forwarding $behind commit(s):"
  git_in_repo log "HEAD..$upstream" --oneline --no-decorate | sed 's/^/    /'
  run git_in_repo merge --ff-only "$upstream"
  mkdir -p "$(dirname "$UPDATE_STAMP")"; date +%s > "$UPDATE_STAMP"

  if (( DRY_RUN )); then
    dry "would re-exec install.sh to apply any new symlinks"
    return 0
  fi
  say "re-running install.sh from the freshly pulled tree"
  exec bash "$REPO/install.sh"
}

case "$MODE" in
  install)   do_install ;;
  update)    do_update ;;
  check)     do_check ;;
  version)   do_version ;;
  uninstall) do_uninstall ;;
  doctor)    do_doctor ;;
esac
