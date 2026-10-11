#=====================================================================================
# r — yazi
#
# Opens yazi; when you quit it, this shell cds to the folder you ended up in.
# A shell function loaded by .zshrc rather than a script on PATH, because a
# separate program can't change the calling shell's directory.
#
# Usage:
#   r                   open yazi in the current folder
#   r <path>            open yazi at <path>
#=====================================================================================

function r() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
