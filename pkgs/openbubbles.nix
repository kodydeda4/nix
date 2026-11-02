# OpenBubbles (iMessage client, a BlueBubbles fork that needs no Mac server).
# Not in nixpkgs: this repackages the prebuilt Linux release from GitHub. To
# update, bump the version and hash (`nix store prefetch-file <url>`).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  copyDesktopItems,
  makeDesktopItem,
  gtk3,
  webkitgtk_4_1,
  libsoup_3,
  libnotify,
  libappindicator-gtk3,
  libdbusmenu,
  libepoxy,
  fontconfig,
  mpv-unwrapped,
  zlib,
}:
stdenv.mkDerivation rec {
  pname = "openbubbles";
  version = "1.15.0+205";

  src = fetchurl {
    url = "https://github.com/OpenBubbles/openbubbles-app/releases/download/${lib.escapeURL "v${version}"}/bluebubbles-linux-x86_64.tar";
    hash = "sha256-VYSk5529Ivzxm1H7b/ZCbX8TJVVnfhrp00IfBGV7Vjo=";
  };
  # The tarball has no top-level directory.
  sourceRoot = ".";

  nativeBuildInputs = [autoPatchelfHook makeWrapper wrapGAppsHook3 copyDesktopItems];
  buildInputs = [
    gtk3
    webkitgtk_4_1
    libsoup_3
    libnotify
    libappindicator-gtk3
    libdbusmenu
    libepoxy
    fontconfig
    mpv-unwrapped
    zlib
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;

  # Flutter finds data/ and lib/ next to the executable, so it stays in one dir.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/opt/openbubbles
    cp -r bluebubbles data lib $out/opt/openbubbles
    # The video plugins link the old libmpv.so.1; nixpkgs' mpv is libmpv.so.2,
    # which still has every function they use.
    for f in libmedia_kit_native_event_loop.so libmedia_kit_video_plugin.so; do
      patchelf --replace-needed libmpv.so.1 libmpv.so.2 $out/opt/openbubbles/lib/$f
    done
    install -Dm644 data/flutter_assets/assets/icon/icon.png $out/share/icons/hicolor/1024x1024/apps/openbubbles.png
    runHook postInstall
  '';

  # LD_LIBRARY_PATH for the libraries Dart loads itself (dlopen), e.g. libmpv.
  postFixup = ''
    makeWrapper $out/opt/openbubbles/bluebubbles $out/bin/openbubbles \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : $out/opt/openbubbles/lib:${lib.makeLibraryPath [mpv-unwrapped]}
  '';

  # Its window class is BlueBubbles' binary name.
  desktopItems = [
    (makeDesktopItem {
      name = "openbubbles";
      desktopName = "OpenBubbles";
      comment = "iMessage client";
      exec = "openbubbles";
      icon = "openbubbles";
      startupWMClass = "bluebubbles";
      categories = ["Network" "InstantMessaging" "Chat"];
    })
  ];

  meta = {
    description = "iMessage client (BlueBubbles fork, no Mac server needed)";
    homepage = "https://openbubbles.app";
    license = lib.licenses.unfree; # app is Apache-2.0, bundled objectbox isn't
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    platforms = ["x86_64-linux"];
    mainProgram = "openbubbles";
  };
}
