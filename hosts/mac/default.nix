# The Mac (nix-darwin): Mac-only apps, Homebrew casks, App Store apps and
# macOS settings. Shared packages live in modules/common.nix.
{
  pkgs,
  config,
  ...
}: {
  system.primaryUser = "kody";

  environment.systemPackages = [
    ## Apps
    pkgs.ghostty-bin
    pkgs.raycast
    pkgs.espanso
    pkgs.mos
    pkgs.alt-tab-macos

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

  # Enable alternative shell support in nix-darwin.
  # programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
