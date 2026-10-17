# System summary on each new interactive terminal. It prints, so it must run
# before the p10k instant prompt below, or p10k warns about console output.
if [[ -o interactive ]] && (( $+commands[fastfetch] )); then
  fastfetch --config examples/26
fi

# Powerlevel10k instant prompt. Keep this near the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# History
HISTFILE="$HOME/.histfile"
HISTSIZE=100000
SAVEHIST=1000000

setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# Completion behavior
zstyle ':completion:*' completer _complete _ignored _correct _approximate
zstyle ':completion:*' max-errors 3

# Oh My Zsh and Powerlevel10k
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-completions
  fast-syntax-highlighting
  zsh-history-substring-search
  colored-man-pages
  command-not-found
  sudo
  extract
  web-search
  copyfile
  copybuffer
  dirhistory
  history
  jsontools
  node
  npm
  python
  pip
)

source "$ZSH/oh-my-zsh.sh"

# Programs and development tools
export EDITOR='nano'
export VISUAL='nano'
export PAGER='less'
export BROWSER='firefox'
export CHROME_EXECUTABLE='/usr/bin/chromium'

export ANDROID_HOME="$HOME/Android/Sdk"
path=(
  "$HOME/.local/bin"
  "$HOME/.bun/bin"
  "$HOME/.cargo/bin"
  "$ANDROID_HOME/cmdline-tools/latest/bin"
  "$ANDROID_HOME/platform-tools"
  $path
)
typeset -U path PATH

export CLICOLOR=1
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# File listing
alias ll='eza -alF --color=always --group-directories-first'
alias la='eza -a --color=always --group-directories-first'
alias l='eza -F --color=always --group-directories-first'
alias ls='eza --color=always --group-directories-first'
alias lt='eza -aT --color=always --group-directories-first'
alias l.='eza -a | grep -E "^\."'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias glog='git log --oneline --graph --decorate'

# Shell and system
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias c='clear'
alias h='history'
alias j='jobs -l'
alias which='type -a'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps auxf'
alias psgrep='ps aux | grep -v grep | grep -i -e VSZ -e'

# Network
alias ping='ping -c 5'
alias myip='curl ipinfo.io/ip'
alias ports='netstat -tulanp'

# Ask before overwriting or removing files.
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias dotshell='qs -p ~/.config/quickshell/dotshell'   # Dot Shell: run, ipc, kill

# Smart directory navigation
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
  alias cd='z'
  alias cdi='zi'
fi

mkcd() {
  if (( $# != 1 )); then
    print -u2 'usage: mkcd DIRECTORY'
    return 2
  fi
  mkdir -p -- "$1" && cd -- "$1"
}

weather() {
  curl -s "wttr.in/${1:-}"
}

# History substring search on both common terminal key sequences.
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down

# Terminal ↔ Dot Shell: notify when long commands end or a command waits for input.
[[ -f "$HOME/.config/zsh/dotterm.zsh" ]] && source "$HOME/.config/zsh/dotterm.zsh"

# Existing fuzzy-finder and machine-local additions, when present.
[[ -f "$HOME/.fzf.zsh" ]] && source "$HOME/.fzf.zsh"
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Powerlevel10k prompt configuration.
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
