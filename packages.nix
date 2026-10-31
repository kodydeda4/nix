{
  pkgs,
  inputs,
}: let
  zed = import ./pkgs/zed.nix {inherit pkgs inputs;};
  zen = import ./pkgs/zen.nix {inherit pkgs inputs;};
in {
  # -------------------------------------------------------------------------
  # shared
  # -------------------------------------------------------------------------

  shared = with pkgs; [
    brave
    obsidian
    slack
    zed
    alejandra
    btop
    bun
    cbonsai
    cmatrix
    cowsay
    delta
    dioxus-cli
    fastfetch
    fd
    firebase-tools
    fzf
    gh
    herdr
    imagemagick
    git-lfs
    jdk
    lazygit
    lsd
    neovim
    nodejs
    prettier
    ripgrep
    rustlings
    rustup
    shfmt
    smassh
    speedtest-cli
    starship
    stylua
    swiftformat
    tmux
    tree-sitter
    wasm-bindgen-cli_0_2_129
    yazi
    zoxide
    awscli2
  ];

  fonts = with pkgs; [
    nerd-fonts.meslo-lg
  ];

  # -------------------------------------------------------------------------
  # mac
  # -------------------------------------------------------------------------

  mac = with pkgs; [
    ghostty-bin
    raycast
    espanso
    mos
    alt-tab-macos
    mkalias
    xcbeautify
  ];

  # Android SDK + NDK for `dx serve --android` (Dioxus). Versions match what
  # dx 0.8's Gradle template builds with (compileSdk 34, AGP 8.7 → build-tools
  # 34.0.0); the SDK is read-only in the store, so Gradle can't fetch extras.
  androidSdk =
    (pkgs.androidenv.composeAndroidPackages {
      platformVersions = ["34"];
      buildToolsVersions = ["34.0.0"];
      includeNDK = true;
      includeEmulator = false;
      includeSystemImages = false;
    }).androidsdk;

  masApps = {
    "Apple Developer" = 640199958;
    "Final Cut Pro" = 424389933;
    "Logic Pro" = 634148309;
    "Magnet" = 441258766;
    "TestFlight" = 899247664;
    "Xcode" = 497799835;
  };

  casks = [
    "balenaetcher"
    "betterdisplay"
    "claude"
    "devcleaner"
    "discord"
    "figma"
    "font-sf-mono"
    "font-sf-pro"
    "github"
    "iina"
    "ik-product-manager"
    "karabiner-elements"
    "proxy-audio-device"
    "tailscale-app"
    "zen"
  ];

  brews = [
    "mas"
    "mole"
    "xcode-build-server"
  ];

  # -------------------------------------------------------------------------
  # linux
  # -------------------------------------------------------------------------

  linux = with pkgs; [
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default
    zen
    discord
    geary
    ghostty
    github-desktop
    gnomeExtensions.blur-my-shell
    mpv
    nwg-displays
    overskride
    papirus-icon-theme
    python3
    gcc
    git
    gnumake
    unzip
    wl-clipboard
  ];
}
