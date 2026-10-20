#!/usr/bin/env bash
# The launcher's Clocks entry (home.nix). In Hyprland: open Clocks, or bring
# its window forward (open_clocks() in hyprland.lua). In GNOME: just open it.
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
	exec hyprctl eval "open_clocks()"
fi
exec gnome-clocks "$@"
