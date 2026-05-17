
# ─────────────────────────────────────────────────────────────
#  ✨ Phoenix Terminal Stack — added by Claude
# ─────────────────────────────────────────────────────────────

# User preferences: written by `phoenix-term settings`. Loaded early so the
# PHOENIX_* env vars are visible to every check below.
[ -f "$HOME/.config/phoenix-term/config.zsh" ] && source "$HOME/.config/phoenix-term/config.zsh"

# Homebrew env — Apple Silicon (/opt/homebrew), Intel Mac (/usr/local), or
# Linuxbrew if the user happens to have it. On Debian/Ubuntu without brew,
# every brew check is silently skipped and apt-installed tools take over.
for __brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  [ -x "$__brew" ] && eval "$($__brew shellenv)" && break
done
unset __brew

# Pick up user-local binaries (apt installs symlinked into ~/.local/bin on
# Linux, plus anything the user drops there).
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# ── Starship prompt ─────────────────────────────────────────
command -v starship >/dev/null && eval "$(starship init zsh)"

# ── Zoxide (smart cd) — use `z foo` or `zi` for interactive ─
command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"

# ── FZF (fuzzy finder) ──────────────────────────────────────
# `fzf --zsh` was added in fzf 0.48 (Jan 2024). Ubuntu 24.04's apt fzf is
# older and prints "unknown option: --zsh" to stderr. Fall back to the
# legacy shell-integration files that Debian/Ubuntu's package ships.
if command -v fzf >/dev/null; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    for __fzf_dir in /usr/share/doc/fzf/examples /usr/share/fzf/shell /opt/homebrew/opt/fzf/shell /usr/local/opt/fzf/shell; do
      [[ -f "$__fzf_dir/key-bindings.zsh" ]] && source "$__fzf_dir/key-bindings.zsh"
      [[ -f "$__fzf_dir/completion.zsh"   ]] && source "$__fzf_dir/completion.zsh"
    done
    unset __fzf_dir
  fi
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

# Nvim as default editor — gated on PHOENIX_NVIM_DEFAULT (default on).
if [[ "${PHOENIX_NVIM_DEFAULT:-1}" != "0" ]] && command -v nvim >/dev/null; then
  alias vi='nvim'
  alias vim='nvim'
  export EDITOR=nvim
  export VISUAL=nvim
fi

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
# Subtle gray so the ghost suggestion blends with the dark bg but is
# still legible. Search the usual install paths for Homebrew (macOS) +
# apt (Debian/Ubuntu) — first hit wins.
for __as in \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [ -f "$__as" ] && source "$__as" && break
done
unset __as
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5a5a5a'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ── fast-syntax-highlighting (MUST be sourced last) ────────
# Brew installs to /opt/homebrew/opt/...; on Linux install.sh clones to
# ~/.zsh/plugins/fast-syntax-highlighting (no apt package).
for __fsh in \
  /opt/homebrew/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh \
  /usr/local/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh \
  "$HOME/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"; do
  [ -f "$__fsh" ] && source "$__fsh" && break
done
unset __fsh

# ─────────────────────────────────────────────────────────────
#  Auto-tmux: every new interactive shell drops into a fresh
#  tmux session so the sysmon sidebar (and optional sticky
#  banner) are always there.
# ─────────────────────────────────────────────────────────────
if [[ -o interactive && -z "$TMUX" ]] && command -v tmux >/dev/null; then
  exec tmux new-session
fi

# ─────────────────────────────────────────────────────────────
#  ✨ Welcome banner — rendered with figlet from PHOENIX_NAME.
#  Used only when PHOENIX_BANNER_STICKY=inline. When sticky, the
#  tmux pane spawned by phoenix-tmux-init handles the banner.
# ─────────────────────────────────────────────────────────────
phoenix-welcome() {
  local sea=$'\e[38;2;32;178;170m'
  local dim=$'\e[38;2;90;90;90m'
  local b=$'\e[1m' r=$'\e[0m'
  local name="${PHOENIX_NAME:-DEV PHOENIX}"

  local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
  local rule="${dim}$(printf '─%.0s' $(seq 1 "$cols"))${r}"

  local art
  if command -v figlet >/dev/null 2>&1; then
    art=$(figlet -f ANSI_Shadow -w "$cols" "$name" 2>/dev/null || figlet -w "$cols" "$name" 2>/dev/null || print -- "$name")
  else
    art="$name"
  fi

  local width=$(echo "$art" | awk '{ if (length > m) m=length } END { print m }')
  local lpad=$(( (cols - width) / 2 ))
  (( lpad < 0 )) && lpad=0
  local pad=$(printf '%*s' "$lpad" '')

  print
  print -- "${rule}"
  print
  while IFS= read -r line; do
    print -- "${pad}${sea}${b}${line}${r}"
  done <<< "$art"
  print
  print -- "${rule}"
  print
  # The bottom rule above already separates the banner from the first prompt,
  # so tell the precmd divider to skip itself once.
  __phoenix_skip_next_divider=1
}

# ─────────────────────────────────────────────────────────────
#  Release-update check — at most once per day. Resolves the
#  latest GitHub Release via the /releases/latest redirect (no
#  API auth needed, not subject to the 60-req/hr rate limit),
#  fires curl in the background so it never blocks the prompt,
#  and compares against the installed version stored in
#  $repo/.version (written by bootstrap.sh / install.sh).
# ─────────────────────────────────────────────────────────────
__phoenix_update_check() {
  local repo="${PHOENIX_REPO:-${${(%):-%x}:A:h:h}}"
  local gh="${PHOENIX_GH_REPO:-DevGeekPhoenix/phoenix-term}"
  command -v curl >/dev/null 2>&1 || return

  local cache="$HOME/.cache/phoenix-term"
  local stamp="$cache/last-check"
  local latest_cache="$cache/latest-release"
  local now=$(date +%s)
  local last=0
  [[ -f "$stamp" ]] && last=$(cat "$stamp" 2>/dev/null || echo 0)

  if (( now - last > 86400 )); then
    mkdir -p "$cache"
    echo "$now" > "$stamp"
    # Background: follow the /releases/latest redirect, parse the tag out
    # of the resolved URL, drop into the cache file. Non-blocking.
    {
      local resolved tag
      resolved=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
        "https://github.com/$gh/releases/latest" 2>/dev/null)
      tag="${resolved##*/tag/}"
      [[ -n "$tag" && "$tag" != "$resolved" ]] && printf '%s\n' "$tag" > "$latest_cache"
    } &!
    return
  fi

  [[ -f "$latest_cache" ]] || return
  local latest current
  latest=$(<"$latest_cache")
  latest="${latest//[[:space:]]/}"
  [[ -z "$latest" ]] && return

  if [[ -f "$repo/.version" ]]; then
    current=$(<"$repo/.version")
    current="${current//[[:space:]]/}"
  elif [[ -d "$repo/.git" ]]; then
    current=$(command git -C "$repo" describe --tags --abbrev=0 HEAD 2>/dev/null)
  fi
  [[ "$current" == "$latest" ]] && return

  local yel=$'\e[38;2;250;189;47m' dim=$'\e[38;2;120;120;120m' sea=$'\e[38;2;32;178;170m' r=$'\e[0m'
  if [[ -n "$current" ]]; then
    print -- "${yel}▲${r} ${dim}Phoenix Term:${r} ${current} → ${sea}${latest}${r} — run ${sea}phoenix-term update${r}"
  else
    print -- "${yel}▲${r} ${dim}Phoenix Term:${r} new release ${sea}${latest}${r} available — run ${sea}phoenix-term update${r}"
  fi
}

# ─────────────────────────────────────────────────────────────
#  On every new interactive shell:
#   • run the release-update check (silent if no upstream / no new tag)
#   • print the welcome banner inline only when STICKY=inline
#     (sticky → tmux pane handles it; off → nothing)
# ─────────────────────────────────────────────────────────────
if [[ -o interactive ]]; then
  __phoenix_update_check
  case "${PHOENIX_BANNER_STICKY:-sticky}" in
    inline) phoenix-welcome ;;
  esac
fi

# ─────────────────────────────────────────────────────────────
#  Divider printed AFTER each command's output (visually: a
#  full-width rule between the previous command's result and the
#  next prompt). Skipped for the first prompt of a fresh shell so
#  you don't see a divider hanging at the top of an empty terminal.
# ─────────────────────────────────────────────────────────────
__phoenix_skip_next_divider=1

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
