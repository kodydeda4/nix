{
  description = "Mac (nix-darwin) and ThinkPad (NixOS) config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Zed's own nixpkgs (packages.nix): Zed is compiled here with a patch, so
    # it's pinned to a commit `nix flake update` leaves alone. To update Zed,
    # put the commit nixpkgs is locked to (flake.lock) here.
    nixpkgs-zed.url = "github:NixOS/nixpkgs/8edc0c72e3a38faf5434e40d1f19431125fe4b30";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Claude Desktop (official Linux beta), repackaged from Anthropic's apt repo.
    claude-desktop.url = "github:tomsch/claude-desktop-nix";
    # Apple's SF Pro / SF Mono (fetched from Apple) for the ThinkPad. Not in
    # nixpkgs: Apple's license doesn't allow redistribution.
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    apple-fonts.inputs.nixpkgs.follows = "nixpkgs";
    # Zen browser for the ThinkPad (not in nixpkgs; the Mac uses the Homebrew cask).
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    nixpkgs-zed,
    nix-homebrew,
    home-manager,
    claude-desktop,
    apple-fonts,
    zen-browser,
  }: let
    # System config shared by every machine (Mac and ThinkPad). Anything that
    # only exists on one OS goes in hosts/<machine>/default.nix instead.
    shared = {pkgs, ...}: let
      packages = import ./packages.nix {inherit pkgs inputs;};
    in {
      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = packages.shared;
      fonts.packages = packages.fonts;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = ["nix-command" "flakes"];

      # Set Git commit hash for darwin-version / nixos-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;
    };

    # Dotfiles (home.nix), the same on every machine.
    homeManagerConfig = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      # Move existing files aside instead of failing activation.
      home-manager.backupFileExtension = "hm-backup";
      home-manager.users.kody = import ./home.nix;
    };

    # `nix fmt` formats every .nix file in the repo with alejandra
    # (or just the files you pass: `nix fmt home.nix`).
    formatterFor = system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      pkgs.writeShellScriptBin "fmt" ''
        exec ${pkgs.alejandra}/bin/alejandra --quiet "''${@:-.}"
      '';
  in {
    # Mac. Build using:
    # $ darwin-rebuild build --flake .#mac
    darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
      specialArgs = {inherit self inputs;};
      modules = [
        shared
        ./hosts/mac
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "kody";
          };
        }
        home-manager.darwinModules.home-manager
        {users.users.kody.home = "/Users/kody";}
        homeManagerConfig
      ];
    };

    # NixOS machines, named after their hostnames (so `nixos-rebuild --flake .`
    # picks the right one). Build using:
    # $ nixos-rebuild build --flake .#nixos-laptop
    nixosConfigurations = let
      linux = host:
        nixpkgs.lib.nixosSystem {
          specialArgs = {inherit self inputs;};
          modules = [
            shared
            ./hosts/nixos
            host
            home-manager.nixosModules.home-manager
            homeManagerConfig
          ];
        };
    in {
      "nixos-laptop" = linux ./hosts/nixos-laptop;
      "nixos-desktop" = linux ./hosts/nixos-desktop;
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."mac".pkgs;

    formatter.aarch64-darwin = formatterFor "aarch64-darwin";
    formatter.x86_64-linux = formatterFor "x86_64-linux";
  };
}
