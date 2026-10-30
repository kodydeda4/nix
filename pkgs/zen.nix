# Cmd+, opens Settings (dotfiles/zen/autoconfig.js). The autoconfig goes in
# the unwrapped package: Zen's launcher runs the unwrapped binary and Gecko
# reads prefs next to it, so wrapFirefox's extraPrefs is never loaded.
{
  pkgs,
  inputs,
}: let
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
        { echo '// First line must be a comment'; cat ${../dotfiles/zen/autoconfig.js}; } > $lib/zen-autoconfig.cfg
      '';
  });
in
  import "${zen}/wrap-zen.nix" pkgs.wrapFirefox unwrapped {icon = "zen-browser";}
