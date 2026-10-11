# nix

My whole Mac, declared in one repo: apps, CLI tools, macOS settings and dotfiles.
One rebuild turns a fresh Mac into my setup.

Built on [nix-darwin](https://github.com/nix-darwin/nix-darwin) (system),
[Home Manager](https://github.com/nix-community/home-manager) (dotfiles) and
[nix-homebrew](https://github.com/zhaofengli/nix-homebrew) (Homebrew casks + Mac App Store).

## Layout

```
nix/
├── flake.nix       # system: packages, casks, App Store apps, macOS defaults
├── flake.lock      # pinned versions of everything (update with `nix flake update`)
├── home.nix        # dotfile links (Home Manager)
├── scripts/        # executables = commands on PATH (nn, xcodemacros); *.zsh = shell functions .zshrc loads (r)
└── dotfiles/       # the actual config files, linked into ~ and ~/.config
    ├── fastfetch/  → ~/.config/fastfetch      (small greeting on new terminals)
    ├── ghostty/    → ~/.config/ghostty
    ├── git/        → ~/.config/git            (config + one file per GitHub account)
    ├── karabiner/  → ~/.config/karabiner
    ├── nvim/       → ~/.config/nvim           (NvChad; plugins pinned in lazy-lock.json)
    ├── ssh/config  → ~/.ssh/config
    ├── starship/   → ~/.config/starship.toml
    ├── tmux/       → ~/.config/tmux
    ├── yazi/       → ~/.config/yazi           (shortcuts, theme, borders)
    └── zsh/.zshrc  → ~/.zshrc
```

`home.nix` also creates an empty `~/.hushlogin` (hides "Last login") and
shortcut links into other repos: `~/Pictures/wallpapers` and
`~/Music/Music/guitar-pro-tabs/`.

Dotfiles are linked straight to this repo (not copied into the Nix store), so
editing a file here takes effect immediately, no rebuild needed. Apps that save
their own settings (Karabiner) write back into the repo, so changes show up in
`git diff`.

**The repo must live at `~/Developer/personal/Developer/nix`.** The links point at
that path.

## Everyday use

| Command | What it does |
|---|---|
| `nn` | Apply the config (`sudo darwin-rebuild switch --flake …#mac`) |
| `nix fmt` | Format all `.nix` files (alejandra) |
| `nix flake update` | Update nixpkgs, Home Manager, etc. then `nn` |
| `brew update` | Refresh Homebrew's cask list (auto-update is off, see below) |
| `src` | Reload `~/.zshrc` in the current shell |
| `xcodemacros enable\|disable` | Toggle Xcode's prebuilt Swift macros |

### Shell & terminal

- **Ghostty starts tmux** (attaches to the running session). Prefix is Ctrl+A;
  Ctrl+E / Ctrl+V split, Ctrl+H/J/K/L move between tmux panes *and* nvim splits,
  ⌥T / ⌥1-9 / ⌥W manage tabs.
- **zsh**: vi mode (Esc = normal, prompt shows ❯/❮), grey history suggestions
  (→ accepts), syntax highlighting, Ctrl+R fuzzy history (fzf), `cd` is zoxide
  (`cd foo` jumps, `cdi` picks).
- **yazi** (`r` opens it and cds on exit): `g w` work, `g n` this repo,
  `g d` ~/Developer/personal, `g p` wallpapers, `g m` music.

### Adding things

| What | Where |
|---|---|
| CLI tool or app in nixpkgs | `environment.systemPackages` in `flake.nix` (search: `nix search nixpkgs <name>`) |
| App only on Homebrew, or a broken/unsigned nixpkgs build | `homebrew.casks` in `flake.nix` (search: `brew search <name>`) |
| Mac App Store app | `homebrew.masApps` in `flake.nix` (ID from `mas search <name>`) |
| A config file | put it in `dotfiles/`, add one `link` line in `home.nix` |
| A macOS setting | `system.defaults` in `flake.nix` |

Rule of thumb: prefer nixpkgs; use a cask when the nixpkgs app won't open
("damaged" = broken code signature, e.g. Discord) or isn't packaged.

**Flakes only see files git knows about.** After creating a new file, run
`git add` on it before rebuilding, or Nix won't find it.

## New Mac

1. **Install Nix** (Determinate Systems installer):
   ```bash
   curl -fsSL https://install.determinate.systems/nix | sh -s -- install
   ```
2. **Clone this repo** to the exact path (HTTPS for now; SSH keys come later):
   ```bash
   mkdir -p ~/Developer/personal/Developer
   git clone https://github.com/kodydeda4/nix.git ~/Developer/personal/Developer/nix
   ```
3. **First build** (`darwin-rebuild` doesn't exist yet, so run it via `nix run`):
   ```bash
   sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/Developer/personal/Developer/nix#mac
   ```
   Afterwards, open a new terminal and use `nn`.
4. Work through the **manual steps** below.

## Manual steps (can't be automated)

These involve secrets, licenses or macOS permission prompts that only a person
can approve. Do them once per Mac.

**Accounts and keys**
- [ ] Sign in to the App Store (needed for `masApps`). Paid apps (Logic Pro,
      Final Cut Pro) must already be owned by the Apple ID.
- [ ] SSH keys (never committed):
      ```bash
      ssh-keygen -t ed25519 -C kodydeda4@gmail.com -f ~/.ssh/id_ed25519_kodydeda4
      ssh-keygen -t ed25519 -C kody@foresightcares.com -f ~/.ssh/id_ed25519_foresightcares
      ```
      Add each `.pub` to its GitHub account (Settings → SSH and GPG keys).
- [ ] `gh auth login` once per account, choosing **SSH**.
- [ ] Switch this repo's remote to SSH:
      `git remote set-url origin git@github.com:kodydeda4/nix.git`

**macOS permissions**
- [ ] **App Management** for Ghostty (Privacy & Security). Without it, some
      cask installs fail with "Failed to unquarantine".
- [ ] **Karabiner-Elements**: open it and approve the driver extension,
      Input Monitoring and background items.
- [ ] **Tailscale**: approve the network extension, sign in.
- [ ] **Magnet**: allow Accessibility when it first opens.
- [ ] Log out and back in once, so key repeat settings apply.
- [ ] Zen as default browser: click "Use Zen" on the first rebuild's prompt.

**Licensed / not packaged anywhere**
- [ ] Guitar Pro 8: download from guitar-pro.com, activate license.
- [ ] EZdrummer 3: install Toontrack Product Manager from toontrack.com, then
      EZdrummer + expansions from inside it.
- [ ] AmpliTube: sign in to IK Product Manager (installed by Nix), install from there.
- [ ] Private Internet Access: installer from privateinternetaccess.com (the
      Homebrew cask fails during rebuilds).
- [ ] Raycast extensions/snippets/hotkeys: Raycast Cloud Sync or a `.rayconfig`
      import (Raycast keeps settings in an encrypted database, not files).

**Dev tooling**
- [ ] Point the command line tools at Xcode (after Xcode installs):
      `sudo xcode-select -s /Applications/Xcode.app && sudo xcodebuild -runFirstLaunch`
- [ ] Rust: `rustup default stable && rustup target add wasm32-unknown-unknown`
- [ ] nvim: just open it once; lazy.nvim installs the plugins from `lazy-lock.json`.
- [ ] Clone other repos into `~/Developer/personal/` (`Applications/`, `Developer/`,
      `Documents/`, `Music/`, `Pictures/`, `Study/`). The links in
      `~/Music/Music/guitar-pro-tabs/` and `~/Pictures/wallpapers` point at
      `personal/Music/` and `personal/Pictures/wallpapers`.

## Git accounts

Two accounts, switched automatically. Two separate rules:

**Which SSH key (GitHub access) — by GitHub org, from any folder**

| URL | Account | SSH key |
|---|---|---|
| `github.com/foresightcares/…` (HTTPS or SSH) | kody-foresightcares | `id_ed25519_foresightcares` |
| any other `github.com/…` | kodydeda4 | `id_ed25519_kodydeda4` |

`dotfiles/git/config` rewrites every foresightcares URL to the SSH host
`github-foresightcares`, which `dotfiles/ssh/config` maps to the foresightcares
key. Routing by org (not folder) is what makes **Xcode / Swift Package Manager**
work: they clone private packages over HTTPS into caches outside the work folder.
Xcode → Settings → Accounts is *not* used for this.

**Which commit name/email — by folder**

| Folder | Email |
|---|---|
| anywhere (default) | kodydeda4@gmail.com (`kodydeda4.config`) |
| `~/Developer/work/foresightcares/` | kody@foresightcares.com (`foresightcares.config`, via `includeIf`) |

The Starship prompt shows the active account inside a repo (`as  kodydeda4`).
Check a repo with `git config --show-origin user.email`. `gitdir:` only matches
inside a repo, so in a plain folder it always shows the default.

Test access: `ssh -T git@github.com` → "Hi kodydeda4!",
`ssh -T git@github-foresightcares` → "Hi kody-foresightcares!".

Don't set your name/email in GitHub Desktop's settings: it writes into
`dotfiles/git/config` and overrides the per-folder identities.

## Gotchas (learned the hard way)

- **`homebrew.onActivation.autoUpdate` must stay `false`.** With it on, brew
  re-execs itself under nix-homebrew, loses `/opt/homebrew/bin` from its PATH and
  fails with "Unable to install … mas installation failed".
- **mas needs a sudoers rule** (`security.sudo.extraConfig`, with `SETENV`) so
  App Store installs work during a non-interactive rebuild.
- **`cleanup = "zap"`**: anything installed with `brew install` outside this repo
  is removed on rebuild. Add it here instead.
- **Don't link a folder and files inside it** in `home.nix`, and don't switch a
  folder link to per-file links in one rebuild: Home Manager writes through the
  old link into the repo and creates symlink loops ("Too many levels of
  symbolic links"). Remove the old link first.
- **Before adding a link, move whatever already exists at that path** (e.g.
  `mv ~/.config/foo ~/.config/foo.old`).
- **Root-owned files** in the repo (from running git or nix with `sudo`) break
  `git add` / `flake.lock` updates: `sudo chown -R kody ~/Developer/personal/Developer/nix`.
- **"App is damaged"** on a nixpkgs app = broken signature; use its cask instead.
- **Xcode "could not read Username for https://github.com"** when resolving
  packages: the package's org isn't routed to an SSH key. Add an `insteadOf`
  rule for it in `dotfiles/git/config` (see Git accounts), then File → Packages →
  Reset Package Caches.
- **Yazi themes/plugins are plain copies** in `dotfiles/yazi/` (flavors,
  full-border). They don't auto-update.
