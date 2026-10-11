# User-level config, managed by Home Manager.
# Dotfiles live in ./dotfiles and are symlinked straight to the repo (not
# copied into /nix/store), so edits take effect immediately and apps can write
# back to them. The repo must be cloned to ~/Developer/personal/Developer/nix.
{
  config,
  pkgs,
  ...
}: let
  dotfiles = "${config.home.homeDirectory}/Developer/personal/Developer/nix/dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  linkPersonal = path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Developer/personal/${path}";
in {
  home.stateVersion = "26.11";

  home.packages = [pkgs.git-lfs];

  # ~/.config/git -> dotfiles/git
  xdg.configFile."git".source = link "git";

  # ~/.ssh/config -> dotfiles/ssh/config
  home.file.".ssh/config".source = link "ssh/config";

  # ~/.zshrc -> dotfiles/zsh/.zshrc
  home.file.".zshrc".source = link "zsh/.zshrc";

  # ~/.config/starship.toml -> dotfiles/starship/starship.toml
  xdg.configFile."starship.toml".source = link "starship/starship.toml";

  # ~/.config/karabiner -> dotfiles/karabiner
  # Link the whole folder, not karabiner.json: the app replaces the file on
  # every save, which would break a file-level link.
  xdg.configFile."karabiner".source = link "karabiner";

  # ~/.config/ghostty -> dotfiles/ghostty
  xdg.configFile."ghostty".source = link "ghostty";

  # Empty ~/.hushlogin hides the "Last login: ..." line in new terminals.
  home.file.".hushlogin".text = "";

  # Xcode key bindings (Settings → Key Bindings). Linked as a folder because
  # Xcode rewrites the .idekeybindings file whenever you change a shortcut.
  home.file."Library/Developer/Xcode/UserData/KeyBindings".source = link "xcode/KeyBindings";

  # ~/.config/zed -> dotfiles/zed (folder link: Zed rewrites settings.json on save)
  xdg.configFile."zed".source = link "zed";

  # ~/.config/nvim -> dotfiles/nvim (NvChad; lazy.nvim writes lazy-lock.json here)
  xdg.configFile."nvim".source = link "nvim";

  # ~/.config/tmux -> dotfiles/tmux
  xdg.configFile."tmux".source = link "tmux";

  # ~/.config/fastfetch -> dotfiles/fastfetch
  xdg.configFile."fastfetch".source = link "fastfetch";

  # ~/.config/yazi -> dotfiles/yazi
  xdg.configFile."yazi".source = link "yazi";

  # Espanso reads ~/Library/Application Support/espanso -> dotfiles/espanso
  # (folder link, so new match/config files are picked up without a rebuild)
  home.file."Library/Application Support/espanso".source = link "espanso";

  # Shortcuts into my personal repos (they're separate git repos, so on a new
  # Mac clone them into ~/Developer/personal first).
  home.file."Music/Music/guitar-pro-tabs/guitar-pro-tabs".source =
    linkPersonal "Music/guitar-pro-tabs";
  home.file."Music/Music/guitar-pro-tabs/guitar-pro-tabs-kody".source =
    linkPersonal "Music/guitar-pro-tabs-kody";
  home.file."Pictures/wallpapers".source = linkPersonal "Pictures/wallpapers";
}
