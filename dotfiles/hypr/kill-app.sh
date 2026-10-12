#!/usr/bin/env bash
# kill-app.sh PID: force-kill (SIGKILL) the whole app that owns PID. Used by
# Cmd+Q in hyprland.lua and in GNOME (gnome-shell/extensions/tile@kody).
#
# Apps are often several processes (Brave's wrapper + browser, Steam's client +
# webhelpers), and killing just the window's process lets the app respawn it.
# So: walk up from PID to the app's top process - the last one before whatever
# launched it (Hyprland, GNOME Shell, Noctalia, systemd, a shell) - then kill it and
# everything under it.
set -u
pid=${1:?usage: kill-app.sh PID}

# launchers: never killed, and the walk stops below them (comm names are cut
# to 15 chars, e.g. ".Hyprland-wrapp")
stop='^(\.?Hyprland.*|start-hyprland|\.?gnome-shell.*|\.?noctalia.*|systemd|uwsm.*|sh|bash|zsh|fish)$'

top=$pid
while :; do
  parent=$(ps -o ppid= -p "$top" | tr -d ' ')
  [ -z "$parent" ] || [ "$parent" -le 1 ] && break
  [[ $(ps -o comm= -p "$parent") =~ $stop ]] && break
  top=$parent
done
[[ $(ps -o comm= -p "$top") =~ $stop ]] && exit 1

pids=$top
queue=$top
while [ -n "$queue" ]; do
  queue=$(pgrep -P "$(tr ' ' ',' <<<"$queue")" | tr '\n' ' ' | sed 's/ $//')
  pids="$pids $queue"
done
# shellcheck disable=SC2086
kill -KILL $pids 2>/dev/null
