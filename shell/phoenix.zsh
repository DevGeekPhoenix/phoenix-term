
# Phoenix Terminal Stack — sourced from ~/.zshrc.

[ -f "$HOME/.config/phoenix-term/config.zsh" ] && source "$HOME/.config/phoenix-term/config.zsh"

# Some tool init scripts emit output without a trailing newline at startup,
# which paints zsh's `%` partial-line marker. Hide the marker — CR-before-prompt
# preservation is still active.
PROMPT_EOL_MARK=''

for __brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  [ -x "$__brew" ] && eval "$($__brew shellenv)" && break
done
unset __brew

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

command -v starship >/dev/null && eval "$(starship init zsh)"

command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"

# `fzf --zsh` requires fzf ≥ 0.48 (Jan 2024); Ubuntu 24.04's apt fzf is older
# and errors out — fall back to the legacy shell-integration files.
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

command -v atuin >/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

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

if [[ "${PHOENIX_NVIM_DEFAULT:-1}" != "0" ]] && command -v nvim >/dev/null; then
  alias vi='nvim'
  alias vim='nvim'
  export EDITOR=nvim
  export VISUAL=nvim
fi

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias g='git'
alias gst='git status'
alias gco='git checkout'
alias gp='git push'
alias gl='git pull'
alias gcm='git commit -m'

alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tl='tmux ls'
alias tk='tmux kill-session -t'

for __as in \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [ -f "$__as" ] && source "$__as" && break
done
unset __as
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5a5a5a'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# fast-syntax-highlighting must be sourced last.
for __fsh in \
  /opt/homebrew/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh \
  /usr/local/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh \
  "$HOME/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"; do
  [ -f "$__fsh" ] && source "$__fsh" && break
done
unset __fsh

if [[ -o interactive && -z "$TMUX" ]] && command -v tmux >/dev/null; then
  exec tmux new-session
fi

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
  # The bottom rule already separates banner from first prompt — skip the
  # precmd divider once so they don't double up.
  __phoenix_skip_next_divider=1
}

# Daily release-update check. /releases/latest redirect avoids GitHub API
# auth + the 60-req/hr unauth rate limit; curl runs in the background so
# it never blocks the prompt.
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

if [[ -o interactive ]]; then
  __phoenix_update_check
  case "${PHOENIX_BANNER_STICKY:-sticky}" in
    inline) phoenix-welcome ;;
  esac
fi

# Initial flag skips the first prompt's divider so it doesn't hang at the
# top of an empty terminal.
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

__phoenix_clear_widget() {
  zle .clear-screen
  [[ -n "$TMUX" ]] && tmux clear-history 2>/dev/null
}
zle -N __phoenix_clear_widget
bindkey '^L' __phoenix_clear_widget
