#!/bin/sh
# menubar-toggle.sh: Hyper+7 in karabiner.json (the Mac version of Meh+7's
# menu bar part in hypr/hyprland.lua; tmux and nvim are left alone).
#
# Flips System Settings → Control Center → "Automatically hide and show the
# menu bar" between Always and Never, and with it:
# - the Dock: hidden for good (auto-hide on, with a delay so long it never pops
#   up), or back to how it was
# - the wallpaper: solid black on every desktop, or back to the one before
# What to restore is kept in ~/.local/state/menubar-toggle. Goes through System
# Events, so the first run asks to let karabiner_console_user_server control it.
state=${XDG_STATE_HOME:-$HOME/.local/state}/menubar-toggle
black="/System/Library/Desktop Pictures/Solid Colors/Black.png"

hidden=$(osascript -e 'tell application "System Events" to tell dock preferences to set autohide menu bar to not autohide menu bar' \
  -e 'tell application "System Events" to tell dock preferences to get autohide menu bar')

if [ "$hidden" = true ]; then
  # save the wallpaper and Dock settings, unless they're already saved (so a
  # menu bar hidden some other way doesn't save the black wallpaper)
  if [ ! -f "$state" ]; then
    mkdir -p "$(dirname "$state")"
    {
      echo "wallpaper=$(osascript -e 'tell application "System Events" to get picture of desktop 1')"
      echo "autohide=$(defaults read com.apple.dock autohide 2>/dev/null)"
      echo "delay=$(defaults read com.apple.dock autohide-delay 2>/dev/null)"
    } >"$state"
  fi
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 1000
  killall Dock; sleep 1 # the Dock draws the wallpaper, so let it come back first
  osascript -e "tell application \"System Events\" to set picture of every desktop to \"$black\"" >/dev/null
else
  [ -f "$state" ] || exit 0
  wallpaper=$(sed -n 's/^wallpaper=//p' "$state")
  autohide=$(sed -n 's/^autohide=//p' "$state")
  delay=$(sed -n 's/^delay=//p' "$state")
  if [ "$autohide" = 1 ]; then
    defaults write com.apple.dock autohide -bool true
  else
    defaults write com.apple.dock autohide -bool false
  fi
  if [ -n "$delay" ]; then
    defaults write com.apple.dock autohide-delay -float "$delay"
  else
    defaults delete com.apple.dock autohide-delay 2>/dev/null
  fi
  killall Dock; sleep 1 # the Dock draws the wallpaper, so let it come back first
  [ -n "$wallpaper" ] && osascript -e "tell application \"System Events\" to set picture of every desktop to \"$wallpaper\"" >/dev/null
  rm -f "$state"
fi
