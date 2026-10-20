#!/usr/bin/env bash
# menubar-wallpaper.sh: the Mac's frosted menu bar that fades into the
# wallpaper. Noctalia's bar is transparent (dotfiles/noctalia) and a blur
# can't fade out, so the wallpaper itself gets it: a copy sized to the monitor,
# with a light blur behind the bar, strongest at the top and tapering off to
# sharp at the bar's bottom edge. That copy becomes the wallpaper.
#
#   menubar-wallpaper.sh            every monitor (Hyprland start, a monitor
#                                   plugged in: hyprland.lua)
#   menubar-wallpaper.sh <monitor>  one monitor, e.g. DP-2
#   Noctalia's wallpaper_changed hook (dotfiles/noctalia/config.toml) runs it
#   with NOCTALIA_WALLPAPER_PATH / _CONNECTOR set: a newly picked wallpaper.
#
# Copies it made itself are skipped, so setting one doesn't start it again.
set -u

OUT="${XDG_STATE_HOME:-$HOME/.local/state}/menubar-wallpapers"
mkdir -p "$OUT"

# "<width> <height> <scale>" of a monitor in physical pixels
monitor_size() {
	hyprctl monitors | awk -v m="$1" '
		/^Monitor / { on = ($2 == m) }
		on && /^\t[0-9]+x[0-9]+@/ { split($1, a, /[x@]/); w = a[1]; h = a[2] }
		on && /^\tscale:/ { print w, h, $2; exit }'
}

# the bar's height on a monitor (logical px), 34 when it can't be found
bar_height() {
	local h
	h=$(hyprctl layers | awk -v m="$1" '
		/^Monitor / { on = ($2 == m ":") }
		on && /namespace: noctalia-bar/ { sub(/.*xywh: /, ""); split($0, a, /[ ,]/); print a[4]; exit }')
	echo "${h:-34}"
}

# make <monitor>'s copy of <wallpaper> and set it
apply() {
	local monitor="$1" src="$2"
	case "$src" in "$OUT"/*) return 0 ;; esac # already one of ours
	[ -f "$src" ] || return 0

	local size w h scale bar fade solid sigma margin strip out
	size=$(monitor_size "$monitor")
	[ -n "$size" ] || return 0
	read -r w h scale <<<"$size"
	bar=$(awk -v b="$(bar_height "$monitor")" -v s="$scale" 'BEGIN { printf "%d", b * s + 0.5 }')
	# subtle, like the Mac's: a light blur, strongest at the top of the screen
	# and weakening steadily to nothing at the bar's bottom edge
	fade=$bar
	solid=0
	sigma=$((bar / 5))
	margin=$((sigma * 3)) # blur a taller strip, so its bottom edge isn't smeared
	strip=$((bar + margin))
	local steps=12

	out="$OUT/$monitor-$(basename "${src%.*}")-${w}x${h}-${bar}-subtle.png"
	if [ ! -f "$out" ]; then
		rm -f "$OUT/$monitor-"*.png # this monitor's older copies
		# A real taper: blending one blurred copy in over a gradient still looks
		# sharp wherever any of the sharp wallpaper shows, so the edge looked
		# hard. Instead, blurs of increasing strength (weak ones on a curve, so
		# the faintest are barely there) each cover a little more of the fade,
		# from the bottom up. (ImageMagick's true variable blur took ~50s.)
		local args=() k s top width rest
		for k in $(seq 1 "$steps"); do
			s=$(awk -v S="$sigma" -v k="$k" -v n="$steps" 'BEGIN { printf "%.2f", S * (k / n) ^ 2 }')
			top=$((solid + fade * (steps - k) / steps))
			width=$(((fade * 2 + steps - 1) / steps))
			rest=$((strip - top - width))
			[ "$rest" -lt 1 ] && rest=1
			args+=(
				\( mpr:strip -blur "0x$s" \)
				\( -size "${w}x${top}" xc:white \( -size "${w}x${width}" gradient:white-black \)
				\( -size "${w}x${rest}" xc:black \) -append -crop "${w}x${strip}+0+0" +repage \)
				-composite
			)
		done
		# the wallpaper filling the screen, its top strip tapered, laid back over it
		magick "$src" -resize "${w}x${h}^" -gravity center -extent "${w}x${h}" +repage \
			-write mpr:base \( +clone -gravity north -crop "${w}x${strip}+0+0" +repage -write mpr:strip \) \
			+swap +delete "${args[@]}" \
			mpr:base +swap -gravity north -compose over -composite "$out" || return 1
	fi
	noctalia msg wallpaper-set "$monitor" "$out" >/dev/null
}

monitors() {
	hyprctl monitors | awk '/^Monitor / { print $2 }'
}

if [ -n "${NOCTALIA_WALLPAPER_PATH:-}" ]; then
	# Noctalia's hook: a wallpaper was picked, for one monitor or all of them
	for m in ${NOCTALIA_WALLPAPER_CONNECTOR:-$(monitors)}; do
		apply "$m" "$NOCTALIA_WALLPAPER_PATH"
	done
	exit 0
fi

# Noctalia may still be starting
for _ in $(seq 40); do
	noctalia msg wallpaper-get >/dev/null 2>&1 && break
	sleep 0.5
done
for m in ${1:-$(monitors)}; do
	apply "$m" "$(noctalia msg wallpaper-get "$m")"
done
