#!/usr/bin/env bash
# gamemode.sh on|off|toggle: game mode, from the bar's gamepad button
# (dotfiles/noctalia).
#
# On:  plain modifiers - Ctrl, Alt and Super act as labeled (keyd's Ctrl/Alt
#      swap, Cmd layer and Super+←/→ off; Caps Lock stays Esc/Meh) - and the
#      button lights up.
# Off: the modifier remaps are back.
#
# The keyd changes run as root in keyd-gamemode-on/-off.service (hosts/nixos);
# polkit lets my user start them without a password.
set -u

# Noctalia loads every *.toml in its config dir; this one only styles the
# button (gitignored, rewritten on every toggle)
state_toml="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/zz-gamemode-state.toml"

case "${1:-toggle}" in
  toggle) if [ -e /run/keyd-gamemode ]; then mode=off; else mode=on; fi ;;
  on | off) mode=$1 ;;
  *) echo "usage: $0 on|off|toggle" >&2; exit 1 ;;
esac

systemctl start "keyd-gamemode-$mode.service"

if [ "$mode" = on ]; then
  cat >"$state_toml" <<'EOF'
# Game mode is ON (written by dotfiles/hypr/gamemode.sh)
[widget.gamemode]
capsule = true
capsule_fill = "primary"
color = "on_primary"
tooltip = "Game mode: on"
EOF
else
  cat >"$state_toml" <<'EOF'
# Game mode is off (written by dotfiles/hypr/gamemode.sh)
EOF
fi

noctalia msg config-reload >/dev/null 2>&1 || true
