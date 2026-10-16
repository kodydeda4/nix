#!/bin/sh
# app-toggle.sh BUNDLE_ID: Hyper+letter app keys in karabiner.json (the Mac
# version of Meh+letter in hypr/hyprland.lua; some letters differ, e.g. C = Zen).
#
# Opens the app if it isn't running, focuses it if it is (a hidden app is
# shown again), and hides it (Cmd+H) if it's already in front. Bundle ids:
# `osascript -e 'id of app "Name"'`.
id=${1:?usage: app-toggle.sh BUNDLE_ID}

front=$(lsappinfo info -only bundleid "$(lsappinfo front)" | cut -d'"' -f4)

if [ "$front" = "$id" ]; then
  # NSRunningApplication.hide, so it needs no Automation permission (System Events would)
  osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSRunningApplication.runningApplicationsWithBundleIdentifier('$id').firstObject.hide" >/dev/null
else
  open -b "$id"
fi
