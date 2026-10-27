# nix

My Mac and my ThinkPad, declared in one repo: apps, CLI tools, OS settings,
desktop setup and dotfiles. One rebuild (`nn`) turns a fresh machine into my setup.

| Machine | Flake output | Built on | Desktop |
|---|---|---|---|
| Mac | `#mac` | [nix-darwin](https://github.com/nix-darwin/nix-darwin) + [nix-homebrew](https://github.com/zhaofengli/nix-homebrew) | macOS |
| ThinkPad | `#nixos-laptop` | NixOS | GNOME **or** Hyprland + Noctalia (pick at login) |
| Desktop PC | `#nixos-desktop` | NixOS | same as the ThinkPad |

The two NixOS machines share `hosts/nixos`; `hosts/nixos-laptop` and
`hosts/nixos-desktop` only hold each one's hardware config, hostname and
`stateVersion`. Flake outputs are named after hostnames, so `nn` builds the
right one.

All use [Home Manager](https://github.com/nix-community/home-manager) for the
dotfiles.

## How it fits together

There are three layers. Each machine stacks them like this:

```
                      flake.nix
          (inputs, and which files make each machine)
                 │                         │
            #mac │                         │ #nixos-laptop / #nixos-desktop
                 ▼                         ▼
   ┌─────────────────────────┐ ┌─────────────────────────┐
   │ 1. SYSTEM (root)        │ │ 1. SYSTEM (root)        │
   │  flake.nix `shared`  ◄──┼─┼──► flake.nix `shared`   │  shared settings
   │  hosts/mac/             │ │  hosts/nixos/           │  per-machine OS settings
   ├─────────────────────────┤ ├─────────────────────────┤
   │ 2. USER (Home Manager)  │ │ 2. USER (Home Manager)  │
   │  home.nix  ◄────────────┼─┼──► home.nix             │  one file, OS-only parts gated
   ├─────────────────────────┤ ├─────────────────────────┤
   │ 3. DOTFILES (symlinks)  │ │ 3. DOTFILES (symlinks)  │
   │  dotfiles/*  ◄──────────┼─┼──► dotfiles/*           │  the real config files
   └─────────────────────────┘ └─────────────────────────┘
```

1. **System** – what's installed and how the OS behaves. Every package (both
   machines, Homebrew and the App Store too) is listed in `packages.nix`;
   the files below read from it. The `shared` block in `flake.nix`
   is shared; `hosts/<machine>/default.nix` is everything that only exists on
   that OS (macOS defaults on the Mac; boot, desktops, keyd,
   sound, fonts on the ThinkPad).
2. **User** – `home.nix` decides which dotfiles get linked where, plus a few
   generated files (GTK themes, GNOME settings). Mac-only and Linux-only parts
   are wrapped in `lib.mkIf isDarwin` / `lib.mkIf isLinux` and grouped under
   headed sections in the file.
3. **Dotfiles** – the actual config files, in their apps' own formats. They're
   linked straight to this repo (not copied into the Nix store), so **editing a
   file in `dotfiles/` takes effect immediately, no rebuild needed**. Apps that
   save their own settings (Karabiner, Zed, Xcode, Noctalia) write back into the
   repo, so those changes show up in `git diff`.

Rule of thumb: **installing something or changing an OS setting = a `.nix` file
+ `nn`. Changing how an app behaves = a file in `dotfiles/`, no rebuild.**

**The repo must live at `~/Developer/personal/Developer/nix`.** The links point
at that path.

## Layout

```
nix/
├── flake.nix            # inputs, settings shared by both machines, and the two machines
├── flake.lock           # pinned versions of everything (`nix flake update` to bump)
├── packages.nix         # EVERY package: shared / mac / linux, Homebrew, App Store
├── hosts/
│   ├── mac/default.nix  # MAC: macOS defaults, Homebrew setup, zsh
│   └── nixos/
│       ├── default.nix  # THINKPAD: boot, GNOME + Hyprland, keyd, game mode, fonts, sound, Linux apps
│       └── hardware-configuration.nix   # from the installer (disks, kernel modules)
├── home.nix             # dotfile links + GTK/GNOME settings (sections: shared / Mac / ThinkPad)
├── scripts/             # executables = commands on PATH; *.zsh = shell functions .zshrc loads
└── dotfiles/            # linked into ~ by home.nix
```

### Dotfiles

| Folder | Linked to | Machines | Notes |
|---|---|---|---|
| `zsh/.zshrc` | `~/.zshrc` | both | also puts `scripts/` on PATH |
| `git/` | `~/.config/git` | both | config + one file per GitHub account (see [Git accounts](#git-accounts)) |
| `ssh/config` | `~/.ssh/config` | both | which key per GitHub account |
| `starship/` | `~/.config/starship.toml` | both | prompt |
| `ghostty/` | `~/.config/ghostty` | both | Linux key fixes are generated in `home.nix` (`ghostty-linux/config`) |
| `tmux/` | `~/.config/tmux` | both | |
| `nvim/` | `~/.config/nvim` | both | NvChad; plugins pinned in `lazy-lock.json` |
| `zed/` | `~/.config/zed` | both | |
| `yazi/` | `~/.config/yazi` | both | shortcuts, theme, borders (flavors/plugins are plain copies) |
| `fastfetch/` | `~/.config/fastfetch` | both | greeting on new terminals |
| `karabiner/` | `~/.config/karabiner` | Mac | Caps Lock = Esc/Hyper, Hyper+letter app keys (`app-toggle.sh`), Brave-profile shortcuts |
| `espanso/` | `~/Library/Application Support/espanso` | Mac | text expansion |
| `xcode/KeyBindings/` | `~/Library/Developer/Xcode/UserData/KeyBindings` | Mac | |
| `hypr/` | `~/.config/hypr` | ThinkPad | Hyprland config (`hyprland.lua`) + helper scripts |
| `noctalia/` | `~/.config/noctalia` | ThinkPad | Hyprland's bar / launcher / notifications |
| `gnome-shell/extensions/tile@kody/` | `~/.local/share/gnome-shell/extensions/` | ThinkPad | my GNOME tiling extension |

`home.nix` also creates an empty `~/.hushlogin` (hides "Last login") and
shortcut links into other repos: `~/Pictures/wallpapers` and
`~/Music/Music/guitar-pro-tabs/`.

### Scripts

Run `scripts` to list them, `scripts <name>` for one's full usage.

| Command | What it does |
|---|---|
| `nn` | Apply the config (`darwin-rebuild … #mac` / `nixos-rebuild`, picked by hostname) |
| `repos` | Clone any of my repos missing from `~/Developer` (`repos --list` shows which) |
| `r` | Open yazi; cd to wherever you quit it (`r.zsh`, a shell function) |
| `fpr` | Run SwiftFormat on my Swift repos |
| `ss enable\|disable` | Window shadows on screenshots (Mac only) |
| `xcodemacros enable\|disable` | Xcode's prebuilt Swift macros (Mac only) |
| `xc build\|run\|stop\|scheme\|device` | Build / run / stop / pick the scheme / pick the simulator or iPhone, for the Xcode project here (Zed's ⌘B / ⌘R / ⌘. / ⌃T / ⌃G) |
| `scripts` | List these scripts |

## Everyday use

| Command | What it does |
|---|---|
| `nn` | Rebuild and switch this machine |
| `nix fmt` | Format all `.nix` files (alejandra) |
| `nix flake update` | Update nixpkgs, Home Manager, etc., then `nn` (not Zed: see `nixpkgs-zed` in flake.nix) |
| `brew update` | Refresh Homebrew's cask list (auto-update is off, see Gotchas) |
| `src` | Reload `~/.zshrc` in the current shell |

### Where do I add…?

| What | Where |
|---|---|
| CLI tool or app for both machines | `shared` in `packages.nix` (`nix search nixpkgs <name>`) |
| App for one machine only | `mac` or `linux` in `packages.nix` |
| Mac app only on Homebrew, or with a broken nixpkgs build | `casks` in `packages.nix` (`brew search <name>`) |
| Mac App Store app | `masApps` in `packages.nix` (ID from `mas search <name>`) |
| A macOS setting | `system.defaults` in `hosts/mac/default.nix` |
| A ThinkPad system service / keyboard remap | `hosts/nixos/default.nix` (keyd is there) |
| A GNOME setting | `dconf.settings` in `home.nix` (find the key with `dconf watch /` while changing it in Settings) |
| A Hyprland shortcut or rule | `dotfiles/hypr/hyprland.lua` (reloads on save) |
| A config file for some app | put it in `dotfiles/`, add one `link` line in `home.nix` (inside the Mac/ThinkPad section if it's one OS only) |
| A repo to clone on new machines | `REPOS` in `scripts/repos` |
| A new script | `scripts/<name>`, `chmod +x`, header in the same format as the others |

Prefer nixpkgs; use a cask when the nixpkgs app won't open on the Mac
("damaged" = broken code signature, e.g. Discord) or isn't packaged.

**Flakes only see files git knows about.** After creating a new file, `git add`
it before rebuilding, or Nix won't find it.

Check a change still builds on the *other* machine without switching to it:

```bash
nix eval .#nixosConfigurations.nixos-laptop.config.system.build.toplevel.drvPath
```

```bash
nix eval .#darwinConfigurations.mac.system.drvPath
```

(The first from the Mac, the second from the ThinkPad.) A package that doesn't
exist on that OS fails here.

## Keyboard & shell (both machines)

The goal is the same keys everywhere. On the ThinkPad that's done by **keyd**
(`hosts/nixos/default.nix`), which runs below every desktop:

| Key | Mac (Karabiner) | ThinkPad (keyd) |
|---|---|---|
| Caps Lock tap / hold | Esc / Hyper | Esc / Meh (Ctrl+Super+Alt) |
| Key next to space | ⌘ | acts as ⌘ (sends Ctrl; Ctrl and Alt are swapped) |
| ⌘←/→, ⌥←/→ | line start/end, word jump | same (Super is where ⌥ is) |
| ⌘Tab | app switcher | app switcher |
| Hyper/Meh + letter | open / focus / hide an app: T Ghostty, C Zen, B Zed, X Xcode, F Figma, M Messages, A Claude, … | same idea: T Ghostty, C Brave, X Zed, A Claude, … |

So in the GNOME settings and `hyprland.lua`, **"Cmd" is written as Ctrl.**

- **Ghostty starts tmux** (attaches to the running session). Prefix is Ctrl+A;
  Ctrl+E / Ctrl+V split, Ctrl+H/J/K/L move between tmux panes *and* nvim splits,
  ⌥T / ⌥1-9 / ⌥W manage tabs.
- **zsh**: vi mode (Esc = normal, prompt shows ❯/❮), grey history suggestions
  (→ accepts), syntax highlighting, Ctrl+R fuzzy history (fzf), `cd` is zoxide
  (`cd foo` jumps, `cdi` picks).
- **yazi** (`r`): `g w` work, `g n` this repo, `g d` ~/Developer/personal,
  `g p` wallpapers, `g m` music.

## The ThinkPad's two desktops

On the GDM login screen, the gear icon picks the session:

- **GNOME** – the default. Settings in `home.nix` (`dconf.settings`), tiling via
  my extension `dotfiles/gnome-shell/extensions/tile@kody` (Meh+H/L halves,
  Meh+Shift+H/L ⅔ + ⅓, Meh+Space fill, Meh+Shift+Space center). Blur my Shell
  for the blurred top bar.
- **Hyprland (uwsm-managed)** – *not* plain "Hyprland", which never starts the
  portal so apps miss dark mode. Config in `dotfiles/hypr/hyprland.lua`, with
  [Noctalia](https://docs.noctalia.dev) (`dotfiles/noctalia/`) as the bar,
  launcher (Cmd+Space), notifications and lock screen. Same tiling keys as
  GNOME, plus:
  - Meh+letter opens/focuses/hides an app (T Ghostty, C Zen, X Zed, A Claude, …)
  - Meh+arrows focus, Meh+1-9 workspaces, Meh+F float/tile (Super is left
    to Ghostty, where it acts as ⌥ like the Mac)
  - Meh+0 zen mode (hides bar + dock, drops gaps)
  - Super+drag moves a window (Super+right-drag resizes); drop it on a screen
    edge to snap it like Rectangle: left/right half, top = maximize, corners =
    quarters
  - Cmd+Q force-quits the whole app (`hypr/kill-app.sh`, also used by GNOME)
  - **Game mode** (gamepad button on the bar, `hypr/gamemode.sh`): turns off
    keyd's modifier remaps so Ctrl/Alt/Super act as labeled. It starts two
    root services defined in `hosts/nixos` that polkit lets me run without a password.

Shared between both: SF Pro / SF Mono / Apple emoji fonts, Papirus-Dark icons,
Adwaita cursor, a darker GTK dark mode (all in `hosts/nixos` + `home.nix`).
GTK windows have square corners only in Hyprland (Hyprland links
`hypr/gtk.css` in at start; logging in to GNOME removes it).

Generated, gitignored files: `dotfiles/hypr/noctalia.lua` (border colors from
the wallpaper) and `dotfiles/noctalia/zz-gamemode-state.toml`.

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
4. Work through the [manual steps](#manual-steps-for-the-mac-cant-be-automated) below.

## New Linux machine (ThinkPad / desktop PC)

1. **Install NixOS** from the GNOME graphical ISO (nixos.org/download). Choose
   any desktop in the installer (this config replaces it), and name the user
   **`kody`**.
2. **Clone, copy in the installer's hardware config and `stateVersion`, and
   build**, all in one go. Set `HOST` to the machine: `nixos-desktop` or
   `nixos-laptop` (its folder in `hosts/`, its flake output and its hostname):
   ```bash
   HOST=nixos-desktop; nix-shell -p git --run 'git clone https://github.com/kodydeda4/nix.git ~/Developer/personal/Developer/nix' && cd ~/Developer/personal/Developer/nix && cp /etc/nixos/hardware-configuration.nix hosts/$HOST/ && sed -i "s/system.stateVersion = \".*\";/system.stateVersion = \"$(grep -oP 'system.stateVersion = "\K[^"]+' /etc/nixos/configuration.nix)\";/" hosts/$HOST/default.nix && sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake "path:$PWD#$HOST"
   ```
   (`path:` so the build sees the new, not-yet-committed hardware config;
   `NIX_CONFIG` turns flakes on for this one command, the config turns them
   on for good.) The machine's hostname becomes `$HOST`. Reboot, log in, open
   Ghostty, and use `nn` from then on.
3. **`git add hosts/$HOST`** before the first `nn` (it builds from git, which
   ignores untracked files), and commit + push once SSH keys work (below).
4. Manual steps:
   - [ ] SSH keys + `gh auth login` (same as the Mac steps below; `UseKeychain`
         is ignored on Linux, so run `ssh-add` after login if asked for a passphrase).
   - [ ] `sudo tailscale up` and sign in.
   - [ ] Firmware: `fwupdmgr refresh && fwupdmgr update` (or GNOME Software → Updates).
   - [ ] `repos` to clone the rest of `~/Developer/personal` (after the SSH keys work).
   - [ ] Rust and nvim: same as the Mac's dev tooling steps.

Not on the ThinkPad (yet): Raycast
(Noctalia's launcher / GNOME search instead), espanso, Karabiner's
Brave-profile shortcuts, Figma, and the music software.

### Renaming a Linux machine

The hostname is `networking.hostName` in `hosts/<machine>/default.nix`
(`hostnamectl` changes get undone by the next rebuild). Rename the folder,
the hostname and its line in `flake.nix`, then switch once by the new name,
since `nn` looks for a config named after the *current* hostname:
```bash
sudo nixos-rebuild switch --flake ~/Developer/personal/Developer/nix#<new-name>
```
After that, `nn` works as usual.

## Manual steps for the Mac (can't be automated)

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
- [ ] Rust: `rustup default stable && rustup target add wasm32-unknown-unknown && rustup component add rust-analyzer`
- [ ] nvim: just open it once; lazy.nvim installs the plugins from `lazy-lock.json`.
- [ ] `repos` clones the rest of `~/Developer/personal`. The links in
      `~/Music/Music/guitar-pro-tabs/` and `~/Pictures/wallpapers` point at
      `personal/Music/` and `personal/Pictures/wallpapers`.

## Git accounts

Two accounts, switched automatically. Two separate rules:

**Which SSH key (GitHub access) — by GitHub org, from any folder**

| URL | Account | SSH key |
|---|---|---|
| `github.com/foresightcares/…` (HTTPS or SSH) | kody-foresightcares | `id_ed25519_foresightcares` |
| any other `github.com/…`, from inside `~/Developer/work/foresightcares/` | kody-foresightcares | `id_ed25519_foresightcares` |
| any other `github.com/…`, anywhere else | kodydeda4 | `id_ed25519_kodydeda4` |

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

Test access: `ssh -T git@github.com` → "Hi kodydeda4!" ("Hi kody-foresightcares!"
inside `~/Developer/work/foresightcares/`, via a `Match … exec` rule in
`dotfiles/ssh/config`), `ssh -T git@github-foresightcares` → "Hi kody-foresightcares!".

Don't set your name/email in GitHub Desktop's settings: it writes into
`dotfiles/git/config` and overrides the per-folder identities.

## Gotchas (learned the hard way)

**Both machines**
- **Don't link a folder and files inside it** in `home.nix`, and don't switch a
  folder link to per-file links in one rebuild: Home Manager writes through the
  old link into the repo and creates symlink loops ("Too many levels of
  symbolic links"). Remove the old link first.
- **Before adding a link, move whatever already exists at that path** (e.g.
  `mv ~/.config/foo ~/.config/foo.old`). Otherwise Home Manager renames it to
  `*.hm-backup`.
- **Root-owned files** in the repo (from running git or nix with `sudo`) break
  `git add` / `flake.lock` updates: `sudo chown -R kody ~/Developer/personal/Developer/nix`.
- **Yazi themes/plugins are plain copies** in `dotfiles/yazi/` (flavors,
  full-border). They don't auto-update.

**Mac**
- **`homebrew.onActivation.autoUpdate` must stay `false`.** With it on, brew
  re-execs itself under nix-homebrew, loses `/opt/homebrew/bin` from its PATH and
  fails with "Unable to install … mas installation failed".
- **mas needs a sudoers rule** (`security.sudo.extraConfig`, with `SETENV`) so
  App Store installs work during a non-interactive rebuild.
- **`cleanup = "zap"`**: anything installed with `brew install` outside this repo
  is removed on rebuild. Add it here instead.
- **"App is damaged"** on a nixpkgs app = broken signature; use its cask instead.
- **Xcode "could not read Username for https://github.com"** when resolving
  packages: the package's org isn't routed to an SSH key. Add an `insteadOf`
  rule for it in `dotfiles/git/config` (see Git accounts), then File → Packages →
  Reset Package Caches.

**ThinkPad**
- **`hosts/<machine>/hardware-configuration.nix` must be that machine's** (from
  the installer), or it won't find its disks at boot.
- **Pick "Hyprland (uwsm-managed)"**, not "Hyprland", at login, or apps ignore
  dark mode and screen sharing / file pickers break.
- **DNS lookups failing** ("Could not resolve hostname github.com"): the home
  router mangles EDNS replies; `networking.resolvconf.dnsExtensionMechanism = false`
  in `hosts/nixos` works around it.
- **Prebuilt Linux binaries** (e.g. the Claude Code binary Claude Desktop
  downloads) need `programs.nix-ld.enable`, or they exit with code 127.
