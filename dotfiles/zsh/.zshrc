# hello kody. 
#
#
#
#  i  t     i s    t  i   m   e      t  o      t   r    a  n  s   c   e  n  d  . .  . 
#=====================================================================================
# init
#=====================================================================================

# Start tmux when Ghostty opens: attach to the running session, or start one.
# Only in Ghostty (not VS Code/Zed/Claude terminals), and not inside tmux itself.
if [[ -z "$TMUX" && "$TERM_PROGRAM" == "ghostty" ]]; then
	tmux attach || tmux new-session
fi

# Small greeting on every new terminal (dotfiles/fastfetch/config.jsonc).
fastfetch && echo

#=====================================================================================
# vi mode
#=====================================================================================
# Esc = normal mode, i/a = insert. Must come before other bindkeys: `bindkey -v`
# resets the keymap. Starship shows ❯ in insert mode and ❮ in normal mode.

bindkey -v
export KEYTIMEOUT=1   # switch to normal mode instantly after Esc (10 ms)

# Backspace/Ctrl+W/Ctrl+U can delete past where insert mode started.
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^H' backward-delete-char
bindkey -M viins '^W' backward-kill-word
bindkey -M viins '^U' backward-kill-line

# Cursor shape: beam in insert mode, block in normal mode.
function zle-keymap-select zle-line-init {
	case $KEYMAP in
		vicmd)      printf '\e[2 q' ;;
		viins|main) printf '\e[6 q' ;;
	esac
}
zle -N zle-keymap-select
zle -N zle-line-init

#=====================================================================================
# completion
#=====================================================================================
# Tab completion (compinit) and grey history suggestions are turned on in
# flake.nix (programs.zsh). This just makes the Tab menu nicer.

zstyle ':completion:*' menu select                          # arrow keys through matches
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"     # colored file matches
zstyle ':completion:*:descriptions' format '%F{8}-- %d --%f'  # group headers
zstyle ':completion:*' group-name ''

# Autosuggestions: → accepts the whole suggestion, ⌥→ accepts one word.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey '^[[1;3C' forward-word

#=====================================================================================
# alias
#=====================================================================================

# general
alias src="source ~/.zshrc"
alias ls='lsd -lah --color=always --group-directories-first --blocks name,size'
alias ll="ls"
alias gg="lazygit"
alias ff='clear && fastfetch && echo'
alias tt="smassh"
alias h="history"
alias conf="cd ~/Developer/personal/Developer/nix/dotfiles/; nvim ."

if [[ "$OSTYPE" == darwin* ]]; then
	alias ip-address="ipconfig getifaddr en0"
else
	alias ip-address="hostname -I | cut -d' ' -f1"
fi
alias internet-speed-test="speedtest-cli --simple"
alias bonsai="cbonsai --seed 119 --live"

#=====================================================================================
# nix
#=====================================================================================

NIX_CONFIG_DIR="$HOME/Developer/personal/Developer/nix"

# Repo scripts: executables (nn, xcodemacros, ...) are commands on PATH;
# *.zsh files are shell functions loaded here (e.g. r, which cds this shell).
export PATH="$NIX_CONFIG_DIR/scripts:$PATH"
for f in "$NIX_CONFIG_DIR"/scripts/*.zsh(N); do source "$f"; done

#=====================================================================================
# nvim
#=====================================================================================

export EDITOR="nvim"

#=====================================================================================
# npm
#=====================================================================================

# Node comes from nix (read-only), so `npm install -g` goes to ~/.npm-global.
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

#=====================================================================================
# zoxide
#=====================================================================================
# `cd` is zoxide: `cd foo` jumps to the most-used folder matching "foo",
# `cdi` picks interactively with fzf. Plain paths (`cd ..`, `cd ~/x`) work as usual.

eval "$(zoxide init zsh --cmd cd)"

#=====================================================================================
# starship
#=====================================================================================

eval "$(starship init zsh)"
