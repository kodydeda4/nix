# Every NixOS machine (ThinkPad, desktop PC). All packages are listed in
# packages.nix; this file is the Linux-only part: boot, desktop, hardware
# services, apps. Per-machine bits (hardware config, hostname, stateVersion)
# are in hosts/nixos-laptop and hosts/nixos-desktop.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
  # No EDNS0 in resolv.conf: the home router mangles cached EDNS replies (puts
  # the OPT record before the answer), so glibc rejects them and lookups like
  # github.com fail with "Could not resolve hostname" most of the time.
  networking.resolvconf.dnsExtensionMechanism = false;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # GNOME on Wayland, GDM login screen.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  # 12-hour clock on the login screen too (the desktop's is set in home.nix).
  programs.dconf.profiles.gdm.databases = [
    {settings."org/gnome/desktop/interface".clock-format = "12h";}
  ];

  # Hyprland as a second session next to GNOME (pick it on the GDM login
  # screen), with Noctalia as its bar/launcher. Config: dotfiles/hypr.
  programs.hyprland = {
    enable = true;
    # Start it through UWSM so graphical-session.target comes up. Without that,
    # xdg-desktop-portal never starts and apps can't see dark mode (or do
    # screen sharing / file pickers).
    withUWSM = true;
  };
  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true; # bluetooth + UPower for its widgets
  };

  # Fonts like the Mac: SF Pro for the UI, SF Mono for code, Apple emoji
  # everywhere. (GNOME's own font settings are in home.nix.)
  fonts.packages = let
    apple-fonts = inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system};
    # Apple Color Emoji converted for Linux (github.com/samuelngs/apple-emoji-ttf)
    apple-emoji = pkgs.runCommand "apple-color-emoji" {} ''
      install -Dm444 ${pkgs.fetchurl {
        url = "https://github.com/samuelngs/apple-emoji-ttf/releases/download/macos-26-20260722-484daf4e/AppleColorEmoji-Linux.ttf";
        hash = "sha256-43x69iZaxKCvbVe8ZehhCad22ZZug0MzRVf2PaSCUW8=";
      }} $out/share/fonts/truetype/AppleColorEmoji.ttf
    '';
  in [apple-fonts.sf-pro apple-fonts.sf-mono apple-emoji];
  fonts.fontconfig = {
    defaultFonts = {
      sansSerif = ["SF Pro Text"];
      monospace = ["SF Mono"];
      emoji = ["Apple Color Emoji"];
    };
    # Apps that ask for Noto Color Emoji by name (Chromium/Brave, GNOME)
    # get Apple's instead.
    # SF Pro: only the fixed-style files (SF Pro Text / Display). The variable
    # SF-Pro.ttf also holds Compressed / Condensed / Expanded widths, and
    # Electron apps (Obsidian, Discord...) ask for a weight only, so bold text
    # could come out squashed. "SF Pro" (GNOME's font setting) means SF Pro Text.
    localConf = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <selectfont>
          <rejectfont><glob>*/SF-Pro.ttf</glob></rejectfont>
        </selectfont>
        <alias binding="same">
          <family>SF Pro</family>
          <prefer><family>SF Pro Text</family></prefer>
        </alias>
        <match target="pattern">
          <test qual="any" name="family"><string>Noto Color Emoji</string></test>
          <edit name="family" mode="assign" binding="same"><string>Apple Color Emoji</string></edit>
        </match>
      </fontconfig>
    '';
  };

  # Sound (PipeWire, with PulseAudio/ALSA compatibility).
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # ThinkPad BIOS/firmware updates through GNOME Software (or `fwupdmgr update`).
  services.fwupd.enable = true;
  # Battery: GNOME's power profiles (Power Saver / Balanced / Performance).
  services.power-profiles-daemon.enable = true;

  services.tailscale.enable = true;

  # Steam via its module, not a plain package: it's a 32-bit app and needs the
  # 32-bit graphics drivers this turns on (without them: "glXChooseVisual failed").
  programs.steam.enable = true;
  # Steam is an X11 app and Hyprland draws X11 apps at full resolution
  # (force_zero_scaling, dotfiles/hypr), so Steam scales its own UI from the
  # X DPI (Xft.dpi; STEAM_FORCE_DESKTOPUI_SCALING is gone from current Steam).
  # Set to the focused monitor's scale (96 DPI = 1x) each time Steam starts:
  # it can't change while running, so quit it with Cmd+Q and reopen after
  # changing the scale. Other X11 apps started afterwards follow it too.
  # Outside Hyprland (Big Picture in gamescope) it's left alone.
  programs.steam.package = pkgs.steam.override {
    extraProfile = ''
      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE-}" ]; then
        dpi=$(${config.programs.hyprland.package}/bin/hyprctl monitors -j 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .scale * 96 | round')
        [ -n "$dpi" ] && echo "Xft.dpi: $dpi" | ${pkgs.xrdb}/bin/xrdb -merge
      fi
    '';
  };

  # Caps Lock: tap = Esc, hold = Ctrl+Super+Alt (like the Mac's Karabiner setup).
  # Ctrl and Alt are swapped on both sides.
  services.keyd = let
    settings = {
      main = {
        capslock = "overload(hyper, esc)";
        leftcontrol = "layer(alt)";
        leftalt = "layer(cmd)";
        rightcontrol = "layer(alt)";
        rightalt = "layer(cmd)";
      };
      "hyper:C-M-A" = {};
      # Arrows like the Mac (+Shift selects). After the swap, the key next to
      # space (labeled Alt, now Ctrl) is where ⌘ is and Super is where ⌥ is:
      # Alt-key+←/→ = start/end of line (⌘←/⌘→)
      "cmd:C" = {
        left = "home";
        right = "end";
        # Cmd+Tab: GNOME's app switcher (Alt+Tab), held open while Cmd is
        # held, like the Mac. Shift+Tab goes back.
        tab = "swap(appswitch)";
      };
      "appswitch:A" = {
        tab = "A-tab";
        # (other keys come out as Alt+key while Cmd is held: the app switcher's
        # vim keys, dotfiles/noctalia/plugins/app-switcher)
      };
      # (not "cmd+shift": Nix sorts sections, and keyd needs cmd defined first)
      "shift+cmd" = {
        left = "S-home";
        right = "S-end";
      };
      # Super+←/→ = previous/next word (⌥←/⌥→)
      meta = {
        left = "C-left";
        right = "C-right";
      };
      "meta+shift" = {
        left = "C-S-left";
        right = "C-S-right";
      };
    };
    # Cmd+Super, tapped together with nothing else (either one held, the other
    # tapped): F18, which Hyprland binds to show/hide the dock. Held, they act
    # as usual (Cmd+Super+key). `cmdKeys` / `superKeys`: the physical keys.
    dockTap = cmdKeys: superKeys: {
      "cmd:C" = lib.genAttrs superKeys (_: "overload(meta, f18)");
      meta = lib.genAttrs cmdKeys (_: "overload(cmd, f18)");
    };
  in {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings = lib.recursiveUpdate settings
        (dockTap ["leftalt" "rightalt"] ["leftmeta" "rightmeta"]);
    };
    # Glove80: Cmd and Super swapped - its Super-labeled key is Cmd (sends
    # Ctrl) and its Alt-labeled key is Super. Everything else as above.
    keyboards.glove80 = {
      ids = ["16c0:27db"];
      settings = lib.foldl' lib.recursiveUpdate settings [
        {
          main = {
            leftalt = "layer(meta)";
            rightalt = "layer(meta)";
            leftmeta = "layer(cmd)";
            rightmeta = "layer(cmd)";
          };
        }
        (dockTap ["leftmeta" "rightmeta"] ["leftalt" "rightalt"])
      ];
    };
  };
  # Game mode (bar button, dotfiles/hypr/gamemode.sh): plain modifiers. Ctrl,
  # Alt and Super act as labeled - no Ctrl/Alt swap, Cmd layer or Super+←/→ -
  # while keyd keeps running (Caps Lock stays Esc/Meh). keyd's socket is
  # root-only, so two root one-shots change its bindings, and polkit lets my
  # user start just those two without a password.
  systemd.services = let
    keyd = "${pkgs.keyd}/bin/keyd";
  in {
    keyd-gamemode-on = {
      description = "Game mode: keyd modifier remaps off";
      serviceConfig.Type = "oneshot";
      script = ''
        ${keyd} bind reset \
          'leftcontrol = layer(control)' 'rightcontrol = layer(control)' \
          'leftalt = layer(alt)' 'rightalt = layer(alt)' \
          'leftmeta = layer(meta)' 'rightmeta = layer(meta)' \
          'meta.left = M-left' 'meta.right = M-right' \
          'meta.leftalt = layer(alt)' 'meta.rightalt = layer(alt)' \
          'meta.leftmeta = layer(meta)' 'meta.rightmeta = layer(meta)' \
          'meta+shift.left = M-S-left' 'meta+shift.right = M-S-right'
        touch /run/keyd-gamemode
      '';
    };
    keyd-gamemode-off = {
      description = "Game mode: keyd modifier remaps back on";
      serviceConfig.Type = "oneshot";
      script = ''
        ${keyd} bind reset
        rm -f /run/keyd-gamemode
      '';
    };
  };
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          (action.lookup("unit") == "keyd-gamemode-on.service" ||
           action.lookup("unit") == "keyd-gamemode-off.service") &&
          action.lookup("verb") == "start" &&
          subject.user == "kody") {
        return polkit.Result.YES;
      }
    });
  '';

  # nn and the launcher's Nix Reload entry (dotfiles/hypr/nix-reload.sh) rebuild
  # without asking for a password. (Which means passwordless root, since any
  # config can be built: fine for a single-user laptop.)
  security.sudo.extraRules = [
    {
      users = ["kody"];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  # Run prebuilt Linux binaries that expect /lib64/ld-linux-x86-64.so.2, like the
  # Claude Code binary Claude Desktop downloads (without this: exit code 127).
  programs.nix-ld.enable = true;

  users.users.kody = {
    isNormalUser = true;
    description = "Kody";
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.zsh;
  };

  environment.systemPackages = (import ../../packages.nix {inherit pkgs inputs;}).linux;

  # zsh, matching the Mac: history suggestions (→ accepts), syntax
  # highlighting, Ctrl+R fuzzy history and `**<Tab>` fuzzy completion.
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };
}
