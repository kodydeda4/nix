#!/usr/bin/env bash
# nix-reload.sh: `nn` from the launcher's Nix Reload entry (home.nix), with a
# notification when it starts and when it finishes. No password: sudo lets
# nixos-rebuild run without one (hosts/nixos). Output
# goes to ~/.cache/nix-reload.log.
set -u

REPO="$HOME/Developer/personal/Developer/nix"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/nix-reload.log"
SW=/run/current-system/sw/bin

# notify <title> <body> [replace-id]: prints the notification's id
notify() {
	"$SW/gdbus" call --session \
		--dest org.freedesktop.Notifications \
		--object-path /org/freedesktop/Notifications \
		--method org.freedesktop.Notifications.Notify \
		"Nix Reload" "${3:-0}" "nix-snowflake" "$1" "$2" "[]" "{}" 5000 |
		sed -n 's/^(uint32 \([0-9]*\),)$/\1/p'
}

id=$(notify "Rebuilding…" "Applying the nix config (nn)")
start=$(date +%s)

# -n: never ask for a password (hosts/nixos lets nixos-rebuild run without one)
if /run/wrappers/bin/sudo -n "$SW/nixos-rebuild" switch --flake "$REPO" >"$LOG" 2>&1; then
	notify "Done" "Nix config applied in $(($(date +%s) - start))s" "$id" >/dev/null
else
	status=$?
	if grep -q "a password is required" "$LOG"; then
		notify "Needs a password" "Run nn once in a terminal to allow rebuilding without one" "$id" >/dev/null
	else
		error=$(grep -m1 -i "error" "$LOG" || tail -n1 "$LOG")
		notify "Failed" "${error:-see $LOG} (full output: $LOG)" "$id" >/dev/null
	fi
	exit "$status"
fi
