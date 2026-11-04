#!/bin/sh
# menubar-toggle.sh: Hyper+7 in karabiner.json (the Mac version of Meh+7's
# menu bar part in hypr/hyprland.lua; tmux and nvim are left alone).
#
# Flips System Settings → Control Center → "Automatically hide and show the
# menu bar" between Always and Never. Goes through System Events, so the first
# run asks to let karabiner_console_user_server control it.
osascript -e 'tell application "System Events" to tell dock preferences to set autohide menu bar to not autohide menu bar' >/dev/null
