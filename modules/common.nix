# System config shared by every machine (Mac and ThinkPad). Anything that only
# exists on one OS goes in hosts/<machine>/default.nix instead.
{
  pkgs,
  self,
  ...
}: {
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search by name, run:
  # $ nix search nixpkgs <name>
  environment.systemPackages = [
    ## Apps
    pkgs.brave
    pkgs.obsidian
    pkgs.zed-editor
    pkgs.slack

    ## CLI
    pkgs.neovim
    pkgs.lazygit
    pkgs.tmux
    pkgs.lsd
    pkgs.zoxide
    pkgs.fzf
    pkgs.ripgrep
    pkgs.tree-sitter
    pkgs.alejandra
    pkgs.stylua
    pkgs.prettier
    pkgs.shfmt
    pkgs.swiftformat
    pkgs.gh
    pkgs.btop
    pkgs.yazi
    pkgs.starship
    pkgs.smassh
    pkgs.cbonsai
    pkgs.cowsay
    pkgs.fastfetch
    pkgs.speedtest-cli
    pkgs.cmatrix
    pkgs.nodejs
    pkgs.bun
    pkgs.firebase-tools
    pkgs.jdk
    pkgs.rustup
    pkgs.dioxus-cli
    pkgs.wasm-bindgen-cli_0_2_129
  ];

  fonts.packages = [
    pkgs.nerd-fonts.meslo-lg
  ];

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Set Git commit hash for darwin-version / nixos-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;
}
