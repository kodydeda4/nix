# The desktop PC. Everything shared with the other Linux machines is in hosts/nixos.
{
  lib,
  pkgs,
  inputs,
  ...
}: let
  # Which half of the TV session runs next: steam, desktop or exit.
  tvState = "/run/user/1000/tv-session";
  # The "TV" login session: Big Picture or Hyprland, one after the other.
  # Each half starts by setting the next one to "exit", so it only switches
  # when asked (steamos-session-select / gaming-mode, below) and a crash or
  # a plain quit ends the session instead of looping.
  tvSession = let
    run = pkgs.writeShellScript "tv-session" ''
      # Decky Loader hooks into Steam through CEF remote debugging (Steam's
      # Developer > CEF Remote Debugging switch, which is this file).
      mkdir -p "$HOME/.local/share/Steam"
      touch "$HOME/.local/share/Steam/.cef-enable-remote-debugging"
      echo steam > "${tvState}"
      while :; do
        next=$(cat "${tvState}")
        echo exit > "${tvState}"
        case "$next" in
          steam) steam-gamescope ;;
          desktop) uwsm start -e -D Hyprland hyprland.desktop ;;
          *) exit 0 ;;
        esac
      done
    '';
  in
    (pkgs.writeTextDir "share/wayland-sessions/tv.desktop" ''
      [Desktop Entry]
      Name=TV (Steam Big Picture)
      Exec=${run}
      Type=Application
    '')
    // {providedSessions = ["tv"];};
  # Steam's Switch to Desktop runs this (a SteamOS command, normally with
  # "plasma"); "gamescope" means Big Picture.
  sessionSelect = pkgs.writeShellScriptBin "steamos-session-select" ''
    if [ "$1" = gamescope ]; then next=steam; else next=desktop; fi
    echo "$next" > "${tvState}"
    steam -shutdown
  '';
  # Decky plugins, the Decky store's builds, by the folder name in their zip.
  # The store names each version's zip after its sha256: to update one, put
  # its newest hash from https://plugins.deckbrew.xyz/plugins here.
  deckyPlugins = lib.mapAttrs (folder: hash:
    pkgs.runCommand folder {nativeBuildInputs = [pkgs.unzip];} ''
      unzip -q ${pkgs.fetchurl {
        url = "https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/${hash}.zip";
        sha256 = hash;
      }}
      mv ${folder} $out
    '') {
    # CSS Loader 2.1.3: themes from deckthemes.com
    SDH-CssLoader = "99beaf1374af82408e6d056e0b0147e5fca544e1035fa7ab88419231697bc231";
    # SteamGridDB 1.8.1: game artwork (grids, heroes, logos, icons) from steamgriddb.com
    decky-steamgriddb = "e84f5b1f111af8862b06218479491fbf61036e1bfd9f16f93f9901e9b9ebc5e0";
  };
in {
  imports = [
    # From the installer (/etc/nixos/hardware-configuration.nix), copied in on
    # the first install (README: New Linux machine).
    ./hardware-configuration.nix
    # Just Jovian-NixOS's Decky Loader module (below).
    "${inputs.jovian}/modules/decky-loader.nix"
  ];
  # Adds pkgs.jovianPackages (decky-loader); doesn't replace any packages.
  nixpkgs.overlays = [inputs.jovian.overlays.default];

  networking.hostName = "nixos-desktop";

  # The second NVMe (3.6 TB, ext4, label SSD) with the Steam library.
  # nofail so a missing drive doesn't stop boot.
  fileSystems."/mnt/ssd" = {
    device = "/dev/disk/by-label/SSD";
    fsType = "ext4";
    options = ["defaults" "nofail"];
  };

  # TV setup, like a Steam Deck: boots straight into Steam Big Picture (Steam
  # inside gamescope), GDM logging in automatically to the "TV" session.
  # Big Picture's Power > Switch to Desktop goes to Hyprland, and the
  # launcher's "Gaming Mode" goes back. Quitting either one any other way
  # (Steam's Exit, Hyprland's Log Out) ends up at the GDM login screen.
  programs.steam.gamescopeSession = {
    enable = true;
    # -steamos3: SteamOS mode, which is what adds Power > Switch to Desktop.
    steamArgs = ["-gamepadui" "-steamos3" "-pipewire-dmabuf"];
  };
  # SteamOS commands Steam runs in that mode, as /usr/bin/..., so they go in
  # Steam's FHS sandbox (its /usr), not just the system PATH.
  programs.steam.extraPackages = [
    sessionSelect
    # "No update available" (exit 7), so Steam doesn't try to update the OS.
    (pkgs.writeShellScriptBin "steamos-update" "exit 7")
  ];
  services.displayManager = {
    sessionPackages = [tvSession];
    defaultSession = "tv";
    autoLogin = {
      enable = true;
      user = "kody";
    };
  };
  environment.systemPackages = [
    sessionSelect
    (pkgs.writeShellScriptBin "gaming-mode" ''
      echo steam > "${tvState}"
      uwsm stop
    '')
    (pkgs.makeDesktopItem {
      name = "gaming-mode";
      desktopName = "Gaming Mode";
      comment = "Back to Steam Big Picture";
      exec = "gaming-mode";
      icon = "steam";
    })
  ];

  # Decky Loader: plugins in Big Picture (the plug icon in the Quick Access
  # menu: Guide+A or Ctrl+2), with the plugins in deckyPlugins (above). The
  # loader runs as root (it has to) and runs plugins as me, with its files in
  # ~/homebrew like on a Steam Deck: CSS Loader's themes are in
  # ~/homebrew/themes. Other plugins can come from Decky's store.
  jovian.decky-loader = {
    enable = true;
    user = "kody";
    stateDir = "/home/kody/homebrew";
  };
  # deckyPlugins come from Nix, so Decky's store can't update or uninstall
  # them. Links to plugins taken off the list are removed.
  systemd.services.decky-loader.preStart = lib.mkAfter (''
      mkdir -p /home/kody/homebrew/plugins
      find /home/kody/homebrew/plugins -maxdepth 1 -type l -lname '/nix/store/*' -delete
    ''
    + lib.concatStrings (lib.mapAttrsToList (folder: plugin: ''
        rm -rf /home/kody/homebrew/plugins/${folder}
        ln -s ${plugin} /home/kody/homebrew/plugins/${folder}
      '')
      deckyPlugins));

  # OpenRGB: the app for the case/fan LEDs (motherboard RGB headers and USB
  # fan controllers). Its server runs in the background so the app (and a
  # saved profile) can reach the devices without root; it adds the udev rules
  # and loads the i2c modules the motherboard needs.
  services.hardware.openrgb = {
    enable = true;
    motherboard = "intel";
  };

  # Used for backwards compatibility. Set it to the NixOS version you install
  # with (the installer's /etc/nixos/configuration.nix shows it) and never
  # change it afterwards.
  system.stateVersion = "26.05";
}
