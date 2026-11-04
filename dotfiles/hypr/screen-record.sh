#!/usr/bin/env bash
# screen-record.sh: Cmd+Shift+5 in hyprland.lua, like the Mac. The first press
# picks what to record (drag a region, or click a monitor for all of it; Esc
# cancels) and starts recording; the next press stops it. Saved to
# ~/Videos/Screencasts and copied, like Cmd+Shift+4's screenshots.
set -u

# Already recording: stop it. The press that started it saves the file below.
if pkill -INT -x wf-recorder; then
  exit 0
fi

geom=$(slurp -o) || exit 0
# x264 needs an even width and height
read -r xy size <<<"$geom"
w=${size%x*} h=${size#*x}
geom="$xy $((w / 2 * 2))x$((h / 2 * 2))"

dir="$HOME/Videos/Screencasts"
mkdir -p "$dir"
file="$dir/recording_$(date +%Y%m%d_%H%M%S).mp4"
wf-recorder -g "$geom" -f "$file"

[ -s "$file" ] || exit 1
wl-copy -t text/uri-list "file://$file"
noctalia msg notification-show "Screen recording saved" "$file"
