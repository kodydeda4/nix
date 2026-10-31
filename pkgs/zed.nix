# Zed reparses every macro body as Rust, and rsx! (Dioxus) isn't, so its
# highlighting came out broken: built with an RSX language for it instead
# (dotfiles/zed/rsx). Not from the cache, so a Zed update is a long build:
# it comes from its own pinned nixpkgs (flake.nix: nixpkgs-zed), and Zed's
# own tests are skipped, as they'd only add to it.
{
  pkgs,
  inputs,
}: let
  rsx = ../dotfiles/zed/rsx;
in
  inputs.nixpkgs-zed.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zed-editor.overrideAttrs (old: {
    patches = (old.patches or []) ++ [(rsx + "/zed.patch")];
    postPatch =
      (old.postPatch or "")
      + ''
        rsx=crates/grammars/src/rsx
        mkdir $rsx
        cp ${rsx}/{config.toml,injections.scm} $rsx/
        cp crates/grammars/src/rust/{brackets,indents,overrides}.scm $rsx/
        cat crates/grammars/src/rust/highlights.scm ${rsx + "/highlights.scm"} > $rsx/highlights.scm
      '';
    doCheck = false;
  })
