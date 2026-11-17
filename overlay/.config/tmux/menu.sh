#!/bin/bash
# Tmux command menu - grouped commands with descriptions in rofi
# Works from Hyprland (no client): tmux targets the last attached session.

THEME="$HOME/.config/tmux/menu.rasi"
KITTY_CMD="kitty --class=tmux-menu"

tmux_cmd() {
  tmux "$@" >/dev/null 2>&1
}

# If the session already has an attached terminal, focus that window (hyprland).
# Returns 0 if focused, 1 if no attached client was found.
focus_existing() {
  local sname="$1"
  local tty pid

  tty=$(tmux list-clients -t "$sname" -F '#{client_tty}' 2>/dev/null | head -1)
  [[ -z $tty ]] && return 1

  # tmux reports /dev/pts/N, ps shows pts/N
  tty="${tty#/dev/}"

  # Find the process owning that tty, then walk up to the kitty process.
  pid=$(ps -eo pid,tty= | awk -v t="$tty" '$2 == t {print $1; exit}')
  [[ -z $pid ]] && return 1

  while [[ -n $pid && $pid != 1 ]]; do
    local comm
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ $comm == kitty* ]]; then
      hyprctl dispatch "hl.dsp.focus({ window = \"pid:$pid\" })" >/dev/null 2>&1 && return 0
      return 1
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}

groups=()
descs=()
cmds=()

add() {
  groups+=("$1")
  descs+=("$2")
  cmds+=("$3")
}

# Special commands in cmds:
#   ASK_WIN / ASK_SESS / ASK_NEW -> asks for a name in rofi
#   KEYS -> lists tmux keybindings in rofi
#   ATTACH_SESS -> lists sessions in rofi, attach or focus selected
#   KITTY:<cmd> -> runs <cmd> in a new kitty window

# --- Start ---
add "Start" "🚀 Open tmux in a new terminal" "KITTY:tmux attach || tmux new -s Work"
add "Start" "🌱 New session" "KITTY:tmux new"
add "Start" "✏️  Session with a name" "ASK_NEW"
# --- Panes ---
add "Panes" "⬅️  Pane left" "select-pane -L"
add "Panes" "➡️  Pane right" "select-pane -R"
add "Panes" "⬆️  Pane up" "select-pane -U"
add "Panes" "⬇️  Pane down" "select-pane -D"
add "Panes" "🔁 Next pane" "select-pane -t :.+"
add "Panes" "🔍 Zoom pane (maximize)" "resize-pane -Z"
add "Panes" "📐 Split vertical (bottom)" "split-window -v -c '#{pane_current_path}'"
add "Panes" "📏 Split horizontal (right)" "split-window -h -c '#{pane_current_path}'"
add "Panes" "❌ Close current pane" "kill-pane"
# --- Windows ---
add "Windows" "🪟 New window" "new-window -c '#{pane_current_path}'"
add "Windows" "⏭️  Next window" "select-window -n"
add "Windows" "⏮️  Previous window" "select-window -p"
add "Windows" "❌ Close current window" "kill-window"
add "Windows" "✏️  Rename window" "ASK_WIN"
# --- Sessions ---
add "Sessions" "⏭️  Next session" "switch-client -n"
add "Sessions" "⏮️  Previous session" "switch-client -p"
add "Sessions" "✏️  Rename session" "ASK_SESS"
add "Sessions" "📋 List / attach session" "ATTACH_SESS"
add "Sessions" "🛑 Kill current session" "kill-session"
# --- Config ---
add "Config" "🔄 Reload configuration" "source-file ~/.config/tmux/tmux.conf"
add "Config" "⌨️  View all keybindings" "KEYS"

# Build the menu: "GROUP | description -- hint"
menu=""
for ((i = 0; i < ${#cmds[@]}; i++)); do
  case ${cmds[$i]} in
    ASK_WIN | ASK_SESS | ASK_NEW) hint="(asks for a name)";;
    KEYS | ATTACH_SESS)           hint="(lists in rofi)";;
    KITTY:*)                      hint="${cmds[$i]#KITTY:}";;
    *)                            hint="${cmds[$i]}";;
  esac
  menu+="${groups[$i]} | ${descs[$i]} -- ${hint}\n"
done

choice=$(printf '%b' "$menu" | rofi -dmenu -i -theme "$THEME" -p "tmux: " -format i 2>/dev/null)
[[ -z $choice ]] && exit 0

cmd="${cmds[$choice]}"

ask() {
  # $1 = prompt str, $2 = placeholder
  rofi -dmenu -i -theme "$THEME" \
    -theme-str $'textbox-prompt-colon { str: "'"$1"$'"; }\nentry { placeholder: "'"$2"$'"; }' \
    -p "$1: " 2>/dev/null
}

case $cmd in
  ASK_WIN)
    name=$(ask "rename" "new window name...")
    [[ -n $name ]] && tmux_cmd rename-window "$name"
    ;;
  ASK_SESS)
    name=$(ask "session" "new session name...")
    [[ -n $name ]] && tmux_cmd rename-session "$name"
    ;;
  ASK_NEW)
    name=$(ask "session" "session name...")
    [[ -n $name ]] && ${KITTY_CMD} -e tmux new -s "$name" &
    ;;
  KEYS)
    tmux list-keys 2>/dev/null | rofi -dmenu -i -theme "$THEME" -p "tmux keybindings: " -mesg "Enter closes" 2>/dev/null
    ;;
  ATTACH_SESS)
    sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)
    [[ -z $sessions ]] && { rofi -theme "$THEME" -e "No active sessions" 2>/dev/null; exit 0; }
    sel=$(printf '%s\n' "$sessions" | rofi -dmenu -i -theme "$THEME" -p "Sessions: " -format i 2>/dev/null)
    [[ -z $sel ]] && exit 0
    sname=$(printf '%s\n' "$sessions" | sed -n "$((sel + 1))p")
    focus_existing "$sname" || ${KITTY_CMD} -e tmux attach -t "$sname" &
    ;;
  KITTY:*)
    ${KITTY_CMD} -e bash -c "${cmd#KITTY:}" &
    ;;
  *)
    eval "tmux $cmd" >/dev/null 2>&1
    ;;
esac
