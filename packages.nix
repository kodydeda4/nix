{
  pkgs,
  inputs,
}: {
  # -------------------------------------------------------------------------
  # shared
  # -------------------------------------------------------------------------

  shared = with pkgs; [
    brave
    obsidian
    slack
    # Zed reparses every macro body as Rust, and rsx! (Dioxus) isn't, so its
    # highlighting came out broken: built with an RSX language for it instead
    # (dotfiles/zed/rsx). Not from the cache, so a Zed update is a long build:
    # it comes from its own pinned nixpkgs (flake.nix: nixpkgs-zed), and Zed's
    # own tests are skipped, as they'd only add to it.
    (inputs.nixpkgs-zed.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zed-editor.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./dotfiles/zed/rsx/zed.patch];
      postPatch =
        (old.postPatch or "")
        + ''
          rsx=crates/grammars/src/rsx
          mkdir $rsx
          cp ${./dotfiles/zed/rsx}/{config.toml,injections.scm} $rsx/
          cp crates/grammars/src/rust/{brackets,indents,overrides}.scm $rsx/
          cat crates/grammars/src/rust/highlights.scm ${./dotfiles/zed/rsx/highlights.scm} > $rsx/highlights.scm
        '';
      doCheck = false;
    }))
    alejandra
    btop
    bun
    cbonsai
    cmatrix
    cowsay
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
    xcbeautify # xcodebuild.nvim log formatting
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
    # Cmd+, opens Settings (dotfiles/zen/autoconfig.js). The autoconfig goes in
    # the unwrapped package: Zen's launcher runs the unwrapped binary and Gecko
    # reads prefs next to it, so wrapFirefox's extraPrefs is never loaded.
    (let
      zen = inputs.zen-browser;
      unwrapped = zen.packages.${pkgs.stdenv.hostPlatform.system}.beta-unwrapped.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            lib=$(echo $out/lib/zen-bin-*)
            chmod u+w $lib $lib/defaults/pref
            echo 'pref("general.config.filename", "zen-autoconfig.cfg");' > $lib/defaults/pref/zen-autoconfig.js
            echo 'pref("general.config.obscure_value", 0);' >> $lib/defaults/pref/zen-autoconfig.js
            echo 'pref("general.config.sandbox_enabled", false);' >> $lib/defaults/pref/zen-autoconfig.js
            { echo '// First line must be a comment'; cat ${./dotfiles/zen/autoconfig.js}; } > $lib/zen-autoconfig.cfg
          '';
      });
    in
      import "${zen}/wrap-zen.nix" pkgs.wrapFirefox unwrapped {icon = "zen-browser";})
    discord
    geary
    ghostty
    github-desktop
    gnomeExtensions.blur-my-shell
    mpv
    nwg-displays # display settings (scale, resolution, layout) for Hyprland
    overskride # Bluetooth settings
    papirus-icon-theme
    python3 # Zed's formatters (dotfiles/zed/format); the Mac has its own
    gcc
    git
    gnumake
    unzip
  ];
}
