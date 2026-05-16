
# ─────────────────────────────────────────────────────────────
#  ✨ Phoenix Terminal Stack — added by Claude
# ─────────────────────────────────────────────────────────────

# Homebrew env (Apple Silicon)
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

# ── Starship prompt ─────────────────────────────────────────
command -v starship >/dev/null && eval "$(starship init zsh)"

# ── Zoxide (smart cd) — use `z foo` or `zi` for interactive ─
command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"

# ── FZF (fuzzy finder) ──────────────────────────────────────
if command -v fzf >/dev/null; then
  source <(fzf --zsh)
  export FZF_DEFAULT_OPTS="
    --height 60% --layout=reverse --border=rounded
    --color=bg+:#1c2027,bg:#111418,spinner:#c7910c,hl:#c7910c
    --color=fg:#bec6d0,header:#11B7D4,info:#d46ec0,pointer:#c7910c
    --color=marker:#00a884,fg+:#bec6d0,prompt:#c7910c,hl+:#f1b115"
  command -v fd >/dev/null && export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  command -v fd >/dev/null && export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# ── Atuin (magic history) ───────────────────────────────────
# First time only:  atuin import auto    (and optionally `atuin login`/`atuin register`)
command -v atuin >/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# ── Yazi: `y` cd's to wherever you exit yazi ────────────────
if command -v yazi >/dev/null; then
  function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi

# ── Aliases — modern replacements ───────────────────────────
if command -v eza >/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias l='eza -lh  --icons --group-directories-first'
  alias ll='eza -la --icons --group-directories-first --git'
  alias lt='eza --tree --level=2 --icons'
  alias ltt='eza --tree --level=3 --icons'
fi
command -v bat     >/dev/null && alias cat='bat --paging=never --style=plain'
command -v bat     >/dev/null && export MANPAGER="sh -c 'col -bx | bat -l man -p'"
command -v fd      >/dev/null && alias find='fd'
command -v lazygit >/dev/null && alias lg='lazygit'
command -v btop    >/dev/null && alias top='btop'
command -v nvim    >/dev/null && alias vi='nvim' && alias vim='nvim'

# Quick nav
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias g='git'
alias gst='git status'
alias gco='git checkout'
alias gp='git push'
alias gl='git pull'
alias gcm='git commit -m'

# Tmux quality of life
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tl='tmux ls'
alias tk='tmux kill-session -t'

# ── zsh-autosuggestions (fish-like ghost text) ─────────────
# Subtle gray so the ghost suggestion blends with the dark Warp bg
# but is still legible — matches Warp's own dim suggestion style.
[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5a5a5a'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ── fast-syntax-highlighting (MUST be sourced last) ────────
# Using FSH's shipped default theme — no custom palette override.
# (Earlier I had a custom theme here; removed at user request to
# "undo every terminal color".)
FSH_PLUGIN=/opt/homebrew/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
[ -f "$FSH_PLUGIN" ] && source "$FSH_PLUGIN"

# ─────────────────────────────────────────────────────────────
#  Auto-tmux: every new interactive shell drops into a fresh
#  tmux session (so the sysmon sidebar + tmux niceties are
#  always there). Set PHOENIX_AUTO_TMUX=0 to opt out.
# ─────────────────────────────────────────────────────────────
if [[ -o interactive && -z "$TMUX" && "${PHOENIX_AUTO_TMUX:-1}" != "0" ]] && command -v tmux >/dev/null; then
  exec tmux new-session
fi

# ─────────────────────────────────────────────────────────────
#  ✨ Welcome banner — printed on every new interactive shell.
#  ASCII art generated from `figlet -f ANSI_Shadow "Dev Phoenix"`
#  and baked in (no runtime figlet dependency). Colored in
#  LightSeaGreen #20b2aa to match the Starship pills + fg.
# ─────────────────────────────────────────────────────────────
phoenix-welcome() {
  local sea=$'\e[38;2;32;178;170m'    # #20b2aa  LightSeaGreen — accent
  local dim=$'\e[38;2;90;90;90m'      # #5a5a5a  rule / muted
  local fg=$'\e[38;2;200;200;200m'    # #c8c8c8  info text
  local b=$'\e[1m' r=$'\e[0m'

  # Center the 83-col-wide banner block in whatever the terminal width is.
  local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
  local width=83
  local lpad=$(( (cols - width) / 2 ))
  (( lpad < 0 )) && lpad=0
  local pad=$(printf '%*s' "$lpad" '')
  # Rule spans the full terminal width.
  local rule="${dim}$(printf '─%.0s' $(seq 1 "$cols"))${r}"

  local now=$(date "+%a %d %b %Y  ·  %H:%M")
  local os="macOS $(uname -sr | awk '{print $2}')"
  local cwd="${PWD/#$HOME/~}"
  local shell_info="ghostty · zsh"

  print
  print -- "${rule}"
  print
  print -- "${pad}${sea}${b}██████╗ ███████╗██╗   ██╗    ██████╗ ██╗  ██╗ ██████╗ ███████╗███╗   ██╗██╗██╗  ██╗${r}"
  print -- "${pad}${sea}${b}██╔══██╗██╔════╝██║   ██║    ██╔══██╗██║  ██║██╔═══██╗██╔════╝████╗  ██║██║╚██╗██╔╝${r}"
  print -- "${pad}${sea}${b}██║  ██║█████╗  ██║   ██║    ██████╔╝███████║██║   ██║█████╗  ██╔██╗ ██║██║ ╚███╔╝ ${r}"
  print -- "${pad}${sea}${b}██║  ██║██╔══╝  ╚██╗ ██╔╝    ██╔═══╝ ██╔══██║██║   ██║██╔══╝  ██║╚██╗██║██║ ██╔██╗ ${r}"
  print -- "${pad}${sea}${b}██████╔╝███████╗ ╚████╔╝     ██║     ██║  ██║╚██████╔╝███████╗██║ ╚████║██║██╔╝ ██╗${r}"
  print -- "${pad}${sea}${b}╚═════╝ ╚══════╝  ╚═══╝      ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝${r}"
  print
  print -- "${pad}${sea}${b}                          ❮❮  W E L C O M E   B A C K  ❯❯${r}"
  print
  #printf "%s  ${sea}◉${r}  ${fg}%-36s${r}  ${sea}◉${r}  ${fg}%s${r}\n" "$pad" "$now" "$os"
  #printf "%s  ${sea}◉${r}  ${fg}%-36s${r}  ${sea}◉${r}  ${fg}%s${r}\n" "$pad" "$cwd" "$shell_info"
  #print
  print -- "${rule}"
  print
  # The bottom rule above already separates the banner from the first prompt,
  # so tell the precmd divider to skip itself once.
  __phoenix_skip_next_divider=1
}

# ─────────────────────────────────────────────────────────────
#  Release-update check — at most once per day, fetched in the
#  background. Compares the closest tag reachable from HEAD against
#  the highest semver tag on origin. Notifies only on tagged releases.
#  Disable with: export PHOENIX_NO_UPDATE_CHECK=1
# ─────────────────────────────────────────────────────────────
__phoenix_update_check() {
  [[ "${PHOENIX_NO_UPDATE_CHECK:-0}" = "1" ]] && return

  local repo="${PHOENIX_REPO:-${${(%):-%x}:A:h:h}}"
  [[ -d "$repo/.git" ]] || return
  command git -C "$repo" rev-parse HEAD >/dev/null 2>&1 || return
  command git -C "$repo" remote | read -r _ 2>/dev/null || return

  local cache="$HOME/.cache/phoenix-term"
  local stamp="$cache/last-check"
  local now=$(date +%s)
  local last=0
  [[ -f "$stamp" ]] && last=$(cat "$stamp" 2>/dev/null || echo 0)

  # Background tag-fetch at most once per 24h. Quiet & detached so it
  # never blocks the prompt; the result is read on the *next* shell.
  if (( now - last > 86400 )); then
    mkdir -p "$cache"
    echo "$now" > "$stamp"
    ( command git -C "$repo" fetch --quiet --tags --prune origin >/dev/null 2>&1 & disown ) 2>/dev/null
  fi

  local current latest
  current=$(command git -C "$repo" describe --tags --abbrev=0 HEAD 2>/dev/null)
  latest=$(command git -C "$repo" tag --list 'v*' --sort=-v:refname 2>/dev/null | head -1)
  [[ -z "$latest" ]] && return
  [[ "$current" == "$latest" ]] && return

  # If HEAD is already past the latest tag, the user is ahead — don't nag.
  command git -C "$repo" merge-base --is-ancestor "$latest" HEAD 2>/dev/null && return

  local yel=$'\e[38;2;250;189;47m' dim=$'\e[38;2;120;120;120m' sea=$'\e[38;2;32;178;170m' r=$'\e[0m'
  if [[ -n "$current" ]]; then
    print -- "${yel}▲${r} ${dim}Phoenix Term:${r} ${current} → ${sea}${latest}${r} — run ${sea}phoenix-term update${r}"
  else
    print -- "${yel}▲${r} ${dim}Phoenix Term:${r} new release ${sea}${latest}${r} available — run ${sea}phoenix-term update${r}"
  fi
}

# Auto-show on every new interactive shell (incl. new tmux panes / Ghostty tabs).
# To suppress: `export PHOENIX_WELCOME=0` before sourcing, or comment the line below.
if [[ -o interactive ]]; then
  __phoenix_update_check
  [[ "${PHOENIX_WELCOME:-1}" != "0" ]] && phoenix-welcome
fi

# ─────────────────────────────────────────────────────────────
#  Full-width divider above every prompt — separates each
#  command's input/output block visually. Uses $COLUMNS, so it
#  auto-adjusts on window resize.
# ─────────────────────────────────────────────────────────────
__phoenix_prompt_divider() {
  if (( ${__phoenix_skip_next_divider:-0} )); then
    __phoenix_skip_next_divider=0
    return
  fi
  local dim=$'\e[38;2;90;90;90m' r=$'\e[0m'
  print -- "${dim}${(l:COLUMNS::─:)}${r}"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd __phoenix_prompt_divider
