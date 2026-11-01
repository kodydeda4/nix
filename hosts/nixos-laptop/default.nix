# The ThinkPad. Everything shared with the other Linux machines is in hosts/nixos.
{
  config,
  pkgs,
  ...
}: {
  imports = [./hardware-configuration.nix];

  networking.hostName = "nixos-laptop";

  services.udev.extraRules = ''
    # The Glove80 and MX Vertical (both Bluetooth) wake the laptop from sleep,
    # so the lid doesn't have to be opened. The kernel only keeps Bluetooth
    # listening while asleep if the Bluetooth chip (Intel AX201) may wake the
    # system, and that's off by default: without it, suspending drops every
    # Bluetooth connection and only the lid or power button wakes it up.
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0026", ATTR{power/wakeup}="enabled"

    # The CalDigit TS4 dock as a systemd device, for dock-lid-inhibit below.
    ACTION!="remove", SUBSYSTEM=="thunderbolt", ATTR{vendor_name}=="CalDigit, Inc.", ATTR{device_name}=="TS4", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/sys/subsystem/thunderbolt/devices/dock"
  '';

  # On the dock, closing the lid never suspends. logind already ignores the
  # lid while an external screen is connected, but the monitor drops off the
  # dock whenever it goes to standby (the screen blanking after 11 minutes, or
  # the lock screen's after 3 seconds), and with the lid closed logind then
  # suspends: that's what put the laptop to sleep at the desk, and back to
  # sleep half a minute after waking it. So the lid is ignored for as long as
  # the TS4 is plugged in instead. Unplugging the dock with the lid closed
  # still suspends.
  systemd.services.dock-lid-inhibit = let
    dock = "sys-subsystem-thunderbolt-devices-dock.device";
  in {
    description = "Ignore the lid while the TS4 dock is plugged in";
    wantedBy = [dock];
    bindsTo = [dock];
    after = [dock "systemd-logind.service"];
    serviceConfig.Restart = "on-failure";
    script = ''
      exec ${config.systemd.package}/bin/systemd-inhibit --what=handle-lid-switch \
        --who="TS4 dock" --why="Docked: the lid doesn't matter" --mode=block \
        ${pkgs.coreutils}/bin/sleep infinity
    '';
  };

  # Used for backwards compatibility. Set it to the NixOS version you install
  # with (the installer's /etc/nixos/configuration.nix shows it) and never
  # change it afterwards.
  system.stateVersion = "26.05";
}
