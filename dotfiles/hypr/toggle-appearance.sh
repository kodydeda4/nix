#!/usr/bin/env bash
# toggle-appearance.sh: switch between light and dark mode, from the launcher's
# Toggle Appearance entry (home.nix). Flips GNOME's color-scheme, which apps
# follow (GTK, Ghostty, nvim's configs/appearance.lua), and Noctalia's own
# theme mode with it.
set -u

if [ "$(gsettings get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'" ]; then
  gsettings set org.gnome.desktop.interface color-scheme default
  noctalia msg theme-mode-set light
else
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark
  noctalia msg theme-mode-set dark
fi
