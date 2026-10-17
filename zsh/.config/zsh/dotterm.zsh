# Terminal ↔ Dot Shell. Sourced from ~/.zshrc, after oh-my-zsh.
#
#   - A command that ran DOTTERM_LONG seconds or more (default 10) notifies
#     when it ends, unless its terminal is the focused window.
#   - While a command runs, dotwait (~/.local/bin) notifies when it sits
#     blocked on input (a sudo password, a [Y/n]) and you're elsewhere.
#   - yay -S installs without the [Y/n].
#
# Both notifications share one replace tag per shell, so "Done" replaces
# "Waiting for input" instead of stacking.
[[ -o interactive ]] || return
(( $+commands[notify-send] )) || return
zmodload zsh/datetime
autoload -Uz add-zsh-hook

# Full-screen and interactive programs: always waiting on you, never "done".
(( ${+DOTTERM_IGNORE} )) || typeset -ga DOTTERM_IGNORE=(nvim vim vi nano less more man htop btop top ssh mosh rmpc cava watch tail journalctl fzf zi z cd tmux zellij python ipython node bun lazygit yazi ranger)

typeset -g _dt_start=0 _dt_cmd= _dt_title= _dt_watch=0

# Ghostty runs every window in one process, so a window is told apart by the
# title this shell gave it.
_dt_focused() {
  (( $+commands[hyprctl] && $+commands[jq] )) || return 1
  local w
  w=$(hyprctl -j activewindow 2>/dev/null | jq -r '(.class // "") + "\t" + (.title // "")' 2>/dev/null) || return 1
  [[ ${w%%$'\t'*} == com.mitchellh.ghostty && ${w#*$'\t'} == "$_dt_title" ]]
}

_dt_preexec() {
  local cmd=${${1//[[:cntrl:]]/ }[1,80]}
  local first=${${(z)1}[1]}
  first=${first:t}
  _dt_start=0 _dt_watch=0
  (( ${DOTTERM_IGNORE[(Ie)$first]} )) && return
  [[ $first == sudo ]] && (( ${DOTTERM_IGNORE[(Ie)${${(z)1}[2]:t}]} )) && return

  _dt_start=$EPOCHREALTIME _dt_cmd=$cmd _dt_title=$cmd
  print -rn -- $'\e]2;'"$_dt_title"$'\a'
  if (( $+commands[dotwait] )); then
    dotwait $$ "$_dt_title" &!
    _dt_watch=$!
  fi
}

_dt_precmd() {
  local st=$?
  (( _dt_watch )) && kill $_dt_watch 2>/dev/null
  _dt_watch=0
  (( _dt_start )) || return 0
  local took=$(( EPOCHREALTIME - _dt_start ))
  _dt_start=0
  (( took >= ${DOTTERM_LONG:-10} )) || return 0
  _dt_focused && return 0

  local s=${took%.*} t
  (( s < 60 )) && t="${s}s" || t="$(( s / 60 ))m $(( s % 60 ))s"
  if (( st == 0 )); then
    notify-send --app-name terminal --urgency low \
      --hint "string:x-canonical-private-synchronous:dotterm-$$" "Done in $t" "$_dt_cmd"
  else
    notify-send --app-name terminal --urgency normal \
      --hint "string:x-canonical-private-synchronous:dotterm-$$" "Failed (exit $st) after $t" "$_dt_cmd"
  fi
  return 0
}

add-zsh-hook preexec _dt_preexec        # appended: runs after oh-my-zsh's title hook, so this title wins
precmd_functions=(_dt_precmd $precmd_functions)   # first, so $? is still the command's

# yay -S installs without the [Y/n]: --needed skips what's already installed,
# --noconfirm takes pacman's defaults (it still stops on a conflict).
# Upgrades (-Syu) and removals (-R) keep their prompts.
yay() {
  if [[ $1 == -S ]]; then
    command yay -S --needed --noconfirm "${@:2}"
  else
    command yay "$@"
  fi
}
