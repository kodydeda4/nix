{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    nix-homebrew,
    home-manager,
  }: let
    configuration = {
      pkgs,
      config,
      ...
    }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget

      system.primaryUser = "kody";
      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = [
        ## Apps
        pkgs.brave
        pkgs.obsidian
        pkgs.ghostty-bin
        pkgs.zed-editor
        pkgs.raycast
        pkgs.espanso
        pkgs.mos
        pkgs.alt-tab-macos
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

        ## Install Script
        pkgs.mkalias
      ];

      homebrew = {
        enable = true;
        brews = [
          "mas"
          "mole"
        ];
        casks = [
          "zen"
          "github"
          "discord"
          "figma"
          "claude"
          "devcleaner"
          "tailscale-app"
          "betterdisplay"
          "font-sf-pro"
          "font-sf-mono"
          "karabiner-elements"
          "ik-product-manager"
          "proxy-audio-device"
          "iina"
          "private-internet-access"
          "balenaetcher"
        ];
        masApps = {
          "Xcode" = 497799835;
          "Apple Developer" = 640199958;
          "TestFlight" = 899247664;
          "Logic Pro" = 634148309;
          "Final Cut Pro" = 424389933;
          "Magnet" = 441258766;
        };
        onActivation.cleanup = "zap";
        # Must stay false: brew's auto-update re-exec drops /opt/homebrew/bin from
        # its PATH under nix-homebrew, so `brew bundle` can't find mas.
        onActivation.autoUpdate = false;
        onActivation.upgrade = true;
      };

      fonts.packages = [
        pkgs.nerd-fonts.meslo-lg
      ];

      system.defaults.CustomUserPreferences."com.apple.dt.Xcode" = {
        # Use my key binding set (dotfiles/xcode/KeyBindings/Kody.idekeybindings).
        IDEKeyBindingCurrentPreferenceSet = "Kody.idekeybindings";
        # macOS App Shortcuts (System Settings → Keyboard → App Shortcuts), matched
        # by menu title. ~ = Option, @ = Command, ^ = Control, $ = Shift.
        NSUserKeyEquivalents = {
          "Select Column Down" = "~@j";
          "Select Column Up" = "~@k";
        };
      };

      # Zen: App Shortcuts for its Spaces menu (same format as Xcode's above).
      system.defaults.CustomUserPreferences."app.zen-browser.zen".NSUserKeyEquivalents = {
        "Previous Space" = "^h";
        "Next Space" = "^l";
      };

      # Finder: path bar at the bottom of every window, full path in the title.
      system.defaults.finder = {
        ShowPathbar = true;
        _FXShowPosixPathInTitle = true;
      };

      # Fast key repeat. Units are 15 ms; System Settings' fastest is
      # KeyRepeat = 2 and shortest delay is InitialKeyRepeat = 15.
      # Takes effect after logging out and back in.
      system.defaults.NSGlobalDomain = {
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
        # Holding a key repeats it instead of showing the accent picker.
        ApplePressAndHoldEnabled = false;
      };

      security.sudo.extraConfig = ''
        kody ALL=(root) NOPASSWD:SETENV: /opt/homebrew/Cellar/mas/*/libexec/bin/mas
      '';

      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = ["/Applications"];
        };
      in
        pkgs.lib.mkForce ''
          # Set up applications.
          echo "setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while read -r src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';

      # Default browser: Zen ("zen" = app.zen-browser.zen, a Homebrew cask). Only
      # runs when it isn't already set, since macOS shows a confirmation dialog
      # on every change. Runs after `brew bundle`, so Zen is installed by then.
      system.activationScripts.postActivation.text = ''
        if ! sudo -u kody ${pkgs.defaultbrowser}/bin/defaultbrowser | grep -q '^\* zen$'; then
          echo "setting Zen as default browser..." >&2
          sudo -u kody ${pkgs.defaultbrowser}/bin/defaultbrowser zen
        fi
      '';

      # zsh: grey inline suggestions from history (accept with →).
      # Tab completion (compinit) is already on by default.
      programs.zsh.enableAutosuggestions = true;
      # Commands turn green/red as you type, depending on whether they exist.
      programs.zsh.enableSyntaxHighlighting = true;
      # fzf: Ctrl+R fuzzy history search, `**<Tab>` fuzzy file/dir completion.
      programs.zsh.enableFzfHistory = true;
      programs.zsh.enableFzfCompletion = true;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "kody";
          };
        }
        home-manager.darwinModules.home-manager
        {
          users.users.kody.home = "/Users/kody";
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # Move existing files aside instead of failing activation.
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.kody = import ./home.nix;
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."mac".pkgs;

    # `nix fmt` formats every .nix file in the repo with alejandra
    # (or just the files you pass: `nix fmt home.nix`).
    formatter.aarch64-darwin = let
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
    in
      pkgs.writeShellScriptBin "fmt" ''
        exec ${pkgs.alejandra}/bin/alejandra --quiet "''${@:-.}"
      '';
  };
}
