# Dozer, hides menu bar icons (github.com/Mortennn/Dozer). Not in nixpkgs, and
# Homebrew dropped its cask, so this unpacks the official release DMG.
{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:
stdenvNoCC.mkDerivation rec {
  pname = "dozer";
  version = "4.0.0";

  src = fetchurl {
    url = "https://github.com/Mortennn/Dozer/releases/download/v${version}/Dozer.${version}.dmg";
    hash = "sha256-2NN6EUydqy8WpW5g2Kl3EVujT+QI/3lH0NdAKPHyKEM=";
  };

  nativeBuildInputs = [undmg];
  sourceRoot = "Dozer.app";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications/Dozer.app
    cp -R . $out/Applications/Dozer.app
    runHook postInstall
  '';

  meta = {
    description = "Hide menu bar icons on macOS";
    homepage = "https://github.com/Mortennn/Dozer";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
