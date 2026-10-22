# User-level config, managed by Home Manager.
# Dotfiles live in ./dotfiles and are symlinked straight to the repo (not
# copied into /nix/store), so edits take effect immediately and apps can write
# back to them. The repo must be cloned to ~/Developer/personal/Developer/nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  dotfiles = "${config.home.homeDirectory}/Developer/personal/Developer/nix/dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  linkPersonal = path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Developer/personal/${path}";
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
in {
  home.stateVersion = "26.11";

  # ~/.config/git -> dotfiles/git
  xdg.configFile."git".source = link "git";

  # ~/.ssh/config -> dotfiles/ssh/config
  home.file.".ssh/config".source = link "ssh/config";

  # ~/.zshrc -> dotfiles/zsh/.zshrc
  home.file.".zshrc".source = link "zsh/.zshrc";

  # ~/.config/starship.toml -> dotfiles/starship/starship.toml
  xdg.configFile."starship.toml".source = link "starship/starship.toml";

  # direnv + nix-direnv: a repo's `.envrc` (`use flake`) loads its dev shell on
  # `cd`, cached so it's instant after the first load. The zsh hook is in
  # dotfiles/zsh/.zshrc (Home Manager doesn't manage that file).
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ~/.config/ghostty -> dotfiles/ghostty
  xdg.configFile."ghostty".source = link "ghostty";

  # Empty ~/.hushlogin hides the "Last login: ..." line in new terminals.
  home.file.".hushlogin".text = "";

  # ~/.config/zed -> dotfiles/zed (folder link: Zed rewrites settings.json on save)
  xdg.configFile."zed".source = link "zed";

  # ~/.config/nvim -> dotfiles/nvim (NvChad; lazy.nvim writes lazy-lock.json here)
  xdg.configFile."nvim".source = link "nvim";

  # ~/.config/tmux -> dotfiles/tmux
  xdg.configFile."tmux".source = link "tmux";

  # ~/.config/fastfetch -> dotfiles/fastfetch
  xdg.configFile."fastfetch".source = link "fastfetch";

  # ~/.config/yazi -> dotfiles/yazi
  xdg.configFile."yazi".source = link "yazi";

  # Shortcuts into my personal repos (they're separate git repos, so on a new
  # Mac clone them into ~/Developer/personal first).
  home.file."Music/Music/guitar-pro-tabs/guitar-pro-tabs".source =
    linkPersonal "Music/guitar-pro-tabs";
  home.file."Music/Music/guitar-pro-tabs/guitar-pro-tabs-kody".source =
    linkPersonal "Music/guitar-pro-tabs-kody";
  home.file."Pictures/wallpapers".source = linkPersonal "Pictures/wallpapers";

  #=====================================================================================
  # Mac only
  #=====================================================================================

  # ~/.config/karabiner -> dotfiles/karabiner
  # Link the whole folder, not karabiner.json: the app replaces the file on
  # every save, which would break a file-level link.
  xdg.configFile."karabiner" = lib.mkIf isDarwin {source = link "karabiner";};

  # Xcode key bindings (Settings → Key Bindings). Linked as a folder because
  # Xcode rewrites the .idekeybindings file whenever you change a shortcut.
  home.file."Library/Developer/Xcode/UserData/KeyBindings" = lib.mkIf isDarwin {source = link "xcode/KeyBindings";};

  # Espanso reads ~/Library/Application Support/espanso -> dotfiles/espanso
  # (folder link, so new match/config files are picked up without a rebuild)
  home.file."Library/Application Support/espanso" = lib.mkIf isDarwin {source = link "espanso";};

  #=====================================================================================
  # ThinkPad (Linux) only
  #=====================================================================================

  # GNOME: fast key repeat, same as the Mac (225 ms delay, 30 ms interval).
  dconf.settings = lib.mkIf isLinux {
    "org/gnome/desktop/peripherals/keyboard" = {
      delay = lib.hm.gvariant.mkUint32 225;
      repeat-interval = lib.hm.gvariant.mkUint32 30;
    };
    # SF Pro / SF Mono, like the Mac (installed in hosts/nixos). GTK apps read
    # these in Hyprland too.
    "org/gnome/desktop/interface" = {
      font-name = "SF Pro 11";
      document-font-name = "SF Pro 11";
      monospace-font-name = "SF Mono 11";
      clock-format = "12h";
      # Dark mode. Apps read it through xdg-desktop-portal, so in Hyprland it
      # needs the "Hyprland (uwsm-managed)" session (see hosts/nixos).
      color-scheme = "prefer-dark";
      icon-theme = "Papirus-Dark";
      # No window animations (tiling, minimizing, ...). GNOME only has this
      # one global switch, so the overview and workspaces stop animating too.
      enable-animations = false;
    };
    "org/gnome/desktop/wm/preferences".titlebar-font = "SF Pro Bold 11";
    # Tapping Super does nothing (it normally opens the overview).
    "org/gnome/mutter".overlay-key = "";
    # Cmd+Space (the key next to space sends Ctrl, see keyd in hosts/nixos)
    # opens the overview's search, GNOME's Spotlight/Raycast.
    "org/gnome/shell/keybindings" = {
      toggle-overview = ["<Control>space"];
      # Cmd+Shift+4: GNOME's screenshot tool (pick a region), like the Mac
      show-screenshot-ui = ["Print" "<Shift><Control>4"];
    };
    # Cmd+H hides (minimizes) the window, in every app.
    "org/gnome/desktop/wm/keybindings" = {
      minimize = ["<Control>h"];
      # Cmd+` / Cmd+Shift+`: next/previous window of the same app, like the Mac
      switch-group = ["<Control>Above_Tab"];
      switch-group-backward = ["<Shift><Control>Above_Tab"];
    };
    # Ctrl+Cmd+Q locks the screen, like the Mac. The Ctrl-labeled key sends Alt
    # and Cmd sends Ctrl (keyd), so it arrives as Ctrl+Alt+Q.
    "org/gnome/settings-daemon/plugins/media-keys".screensaver = "<Control><Alt>q";
    # Window tiling on Meh shortcuts (dotfiles/gnome-shell/extensions/tile@kody),
    # and Blur my Shell (blurred top bar, overview and dash; installed in hosts/nixos).
    "org/gnome/shell" = {
      # GNOME hides Log Out when there's only one user; show it anyway.
      always-show-log-out = true;
      disable-user-extensions = false;
      enabled-extensions = ["tile@kody" "blur-my-shell@aunetx"];
    };
  };

  # Square GTK window corners in Hyprland only (GNOME keeps its rounded ones):
  # Hyprland links dotfiles/hypr/gtk.css to ~/.config/gtk-{3,4}.0/hyprland.css
  # at start, and logging in to GNOME deletes it (autostart entry below).
  # Hyprland's own corners are off in dotfiles/hypr.
  # Also a darker dark mode for libadwaita (GNOME) apps: near-black instead of
  # Adwaita's default dark grays. Only in dark mode: applied always, light mode
  # got dark text on these dark backgrounds. (Media query + CSS variables:
  # GTK 4.16 / libadwaita 1.6 and up.)
  xdg.configFile."gtk-4.0/gtk.css" = lib.mkIf isLinux {
    text = ''
      @import url("hyprland.css");

      @media (prefers-color-scheme: dark) {
        :root {
          --window-bg-color: #121212;
          --view-bg-color: #0d0d0d;
          --headerbar-bg-color: #161616;
          --headerbar-backdrop-color: #121212;
          --sidebar-bg-color: #161616;
          --sidebar-backdrop-color: #121212;
          --secondary-sidebar-bg-color: #121212;
          --card-bg-color: #1c1c1c;
          --dialog-bg-color: #181818;
          --popover-bg-color: #1c1c1c;
          --thumbnail-bg-color: #1c1c1c;
        }
      }
    '';
  };
  # Adwaita cursor (GNOME's) for apps outside GNOME too, e.g. in Hyprland:
  # writes ~/.icons/default so apps without a theme setting use it.
  home.pointerCursor = lib.mkIf isLinux {
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
  };

  # Older GTK 3 apps (and GTK apps outside GNOME, e.g. in Hyprland) don't read
  # the settings above; tell them directly.
  xdg.configFile."gtk-3.0/settings.ini" = lib.mkIf isLinux {
    text = ''
      [Settings]
      gtk-application-prefer-dark-theme=1
      gtk-icon-theme-name=Papirus-Dark
      gtk-cursor-theme-name=Adwaita
      gtk-cursor-theme-size=24
    '';
  };
  xdg.configFile."gtk-4.0/settings.ini" = lib.mkIf isLinux {
    text = ''
      [Settings]
      gtk-icon-theme-name=Papirus-Dark
      gtk-cursor-theme-name=Adwaita
      gtk-cursor-theme-size=24
    '';
  };
  xdg.configFile."gtk-3.0/gtk.css" = lib.mkIf isLinux {
    text = ''
      @import url("hyprland.css");

      /* Darker dark mode, matching gtk-4.0/gtk.css */
      @define-color theme_bg_color #121212;
      @define-color theme_base_color #0d0d0d;
      @define-color theme_unfocused_bg_color #121212;
      @define-color theme_unfocused_base_color #0d0d0d;
    '';
  };
  xdg.configFile."autostart/gtk-rounded-corners.desktop" = lib.mkIf isLinux {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=GTK rounded corners
      Exec=sh -c 'rm -f ~/.config/gtk-3.0/hyprland.css ~/.config/gtk-4.0/hyprland.css'
      OnlyShowIn=GNOME;
      NoDisplay=true
    '';
  };

  # ~/.config/hypr -> dotfiles/hypr
  xdg.configFile."hypr" = lib.mkIf isLinux {source = link "hypr";};

  # ~/.config/noctalia -> dotfiles/noctalia (folder link: the settings GUI
  # writes settings.toml here, so changes land in the repo)
  xdg.configFile."noctalia" = lib.mkIf isLinux {source = link "noctalia";};

  # ~/.local/share/gnome-shell/extensions/tile@kody -> dotfiles/gnome-shell/extensions/tile@kody
  xdg.dataFile."gnome-shell/extensions/tile@kody" = lib.mkIf isLinux {
    source = link "gnome-shell/extensions/tile@kody";
  };

  # Commands in Noctalia's launcher (Cmd+Space), next to the apps.
  xdg.desktopEntries = lib.mkIf isLinux {
    toggle-dock = {
      name = "Toggle Dock";
      comment = "Show or hide the dock";
      icon = "view-app-grid-symbolic";
      # toggle_dock() is in dotfiles/hypr/hyprland.lua
      exec = ''hyprctl eval "toggle_dock()"'';
    };
    toggle-bar = {
      name = "Toggle Menu Bar";
      comment = "Show or hide the bar at the top of the screen";
      icon = "view-continuous-symbolic";
      exec = ''hyprctl eval "toggle_bar()"'';
    };
    toggle-gaps = {
      name = "Toggle Gaps";
      comment = "Add or remove the space around windows";
      icon = "view-grid-symbolic";
      exec = ''hyprctl eval "toggle_gaps()"'';
    };
    toggle-borders = {
      name = "Toggle Borders";
      comment = "Show or hide window borders";
      icon = "view-restore-symbolic";
      exec = ''hyprctl eval "toggle_borders()"'';
    };
    toggle-shadows = {
      name = "Toggle Shadows";
      comment = "Show or hide window shadows";
      icon = "weather-overcast-symbolic";
      exec = ''hyprctl eval "toggle_shadows()"'';
    };
    toggle-appearance = {
      name = "Toggle Appearance";
      comment = "Switch between light and dark mode";
      icon = "weather-clear-night-symbolic";
      exec = "bash ${config.home.homeDirectory}/.config/hypr/toggle-appearance.sh";
    };
    nix-reload = {
      name = "Nix Rebuild";
      comment = "Apply the nix config (nn), with a notification when it's done";
      icon = "nix-snowflake";
      exec = "bash ${config.home.homeDirectory}/.config/hypr/nix-reload.sh";
    };
    # Replaces GNOME Clocks' own entry (same name): in Hyprland it opens Clocks
    # or brings its window forward, even when it's hidden or behind others,
    # which the usual way of opening it didn't (open-clocks.sh).
    "org.gnome.clocks" = {
      name = "Clocks";
      comment = "Clocks for world times, plus alarms, stopwatch and a timer";
      icon = "org.gnome.clocks";
      exec = "bash ${config.home.homeDirectory}/.config/hypr/open-clocks.sh";
      categories = ["GNOME" "GTK" "Utility" "Clock"];
    };
  };

  # Ghostty on Linux: keyd makes Cmd send Ctrl and the Ctrl-labeled key send
  # Alt, and Super sits where ⌥ is. Ghostty turns them back into the Mac's
  # modifiers (remaps don't chain): Cmd = super, Ctrl-labeled key = ctrl,
  # Super = alt. So ⌃J/K reach nvim as Ctrl, ⌥J/K and Super+T / Super+1-9
  # reach tmux as M-j/k/t/1-9, and the Mac config's cmd+... keybinds work here
  # as-is. (Loaded by dotfiles/ghostty/config.)
  # Ghostty's Linux defaults use Ctrl+Shift, so Cmd+N/W/Q/C/V and font size are
  # set like the Mac's (except Cmd+0, which toggles nvim's file tree from the
  # main config), and take Alt+1-9 for its own tabs (the Mac doesn't), so
  # those are unbound. Super+←/→ (keyd sends Ctrl+←/→, so super here) jumps
  # words like ⌥←/→ in the Mac's Ghostty.
  xdg.configFile."ghostty-linux/config" = lib.mkIf isLinux {
    text = ''
      key-remap = ctrl=super
      key-remap = alt=ctrl
      key-remap = super=alt
      keybind = super+n=new_window
      keybind = super+w=close_surface
      keybind = super+q=quit
      keybind = super+c=copy_to_clipboard
      keybind = super+v=paste_from_clipboard
      keybind = super+equal=increase_font_size:1
      keybind = super+minus=decrease_font_size:1
      keybind = super+left=esc:b
      keybind = super+right=esc:f
      ${lib.concatMapStrings (i: ''
        keybind = alt+${i}=unbind
        keybind = alt+digit_${i}=unbind
      '') ["1" "2" "3" "4" "5" "6" "7" "8" "9"]}
    '';
  };
}
