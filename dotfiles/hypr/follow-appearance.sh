#!/usr/bin/env bash
# follow-appearance.sh: keeps Noctalia's light / dark mode the same as GNOME's
# color-scheme (what GTK apps, Ghostty and nvim follow), both ways:
#   follow-appearance.sh                 started with Hyprland (hyprland.lua):
#                                        match now, then whenever GNOME's changes
#   follow-appearance.sh from-noctalia   Noctalia's theme_mode_changed hook
#                                        (dotfiles/noctalia/config.toml): Noctalia
#                                        switched, so switch GNOME's to match
# Each side is only set when it differs, so the two never bounce back and forth.
set -u

gnome_mode() {
	case "$(gsettings get org.gnome.desktop.interface color-scheme)" in
	*dark*) echo dark ;;
	*) echo light ;;
	esac
}

if [ "${1:-}" = from-noctalia ]; then
	mode="${NOCTALIA_THEME_MODE:-$(noctalia msg theme-mode-get)}"
	if [ "$mode" != "$(gnome_mode)" ]; then
		gsettings set org.gnome.desktop.interface color-scheme \
			"$([ "$mode" = dark ] && echo prefer-dark || echo default)"
	fi
	exit 0
fi

to_noctalia() {
	local mode
	mode="$(gnome_mode)"
	[ "$(noctalia msg theme-mode-get 2>/dev/null)" = "$mode" ] || noctalia msg theme-mode-set "$mode" >/dev/null
}

# Noctalia may still be starting
for _ in $(seq 40); do
	noctalia msg theme-mode-get >/dev/null 2>&1 && break
	sleep 0.5
done
to_noctalia

gsettings monitor org.gnome.desktop.interface color-scheme | while read -r _; do
	to_noctalia
	# window borders' gray (hyprland.lua)
	hyprctl eval 'apply_border_colors()' >/dev/null
done
