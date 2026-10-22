# The desktop PC. Everything shared with the other Linux machines is in hosts/nixos.
{pkgs, ...}: let
  # Which half of the TV session runs next: steam, desktop or exit.
  tvState = "/run/user/1000/tv-session";
  # The "TV" login session: Big Picture or Hyprland, one after the other.
  # Each half starts by setting the next one to "exit", so it only switches
  # when asked (steamos-session-select / gaming-mode, below) and a crash or
  # a plain quit ends the session instead of looping.
  tvSession = let
    run = pkgs.writeShellScript "tv-session" ''
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
in {
  # From the installer (/etc/nixos/hardware-configuration.nix), copied in on
  # the first install (README: New Linux machine).
  imports = [./hardware-configuration.nix];

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
