# The ThinkPad. Everything shared with the other Linux machines is in hosts/nixos.
{
  imports = [./hardware-configuration.nix];

  networking.hostName = "nixos-laptop";

  # Used for backwards compatibility. Set it to the NixOS version you install
  # with (the installer's /etc/nixos/configuration.nix shows it) and never
  # change it afterwards.
  system.stateVersion = "26.05";
}
