{ lib
, stdenvNoCC
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, electron
, src            # pass in your pinned flake input
}:

stdenvNoCC.mkDerivation {
  pname = "dl-desktop";
  version = "4.3.1";
  inherit src;

  nativeBuildInputs = [ makeWrapper copyDesktopItems ];

  # No runtime npm deps, so no npm install / lifecycle scripts / electron download.
  # electron-builder and install-linux.sh are never run.
  dontConfigure = true;
  dontBuild = true;

  desktopItems = [
    (makeDesktopItem {
      name = "ro.go.hmlendea.DL-Desktop";
      desktopName = "Duolingo Desktop";
      comment = "Unofficial desktop client for Duolingo";
      exec = "dl-desktop";
      icon = "dl-desktop";
      categories = [ "Education" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/dl-desktop
    cp -r package.json scripts icon.png $out/lib/dl-desktop/
    install -Dm444 icon.png $out/share/pixmaps/dl-desktop.png

    makeWrapper ${electron}/bin/electron $out/bin/dl-desktop \
      --add-flags "$out/lib/dl-desktop" \
      --set ELECTRON_IS_DEV 0

    runHook postInstall
  '';

  meta = {
    description = "Unofficial desktop client for Duolingo";
    homepage = "https://github.com/hmlendea/dl-desktop";
    license = lib.licenses.gpl3Only;
    mainProgram = "dl-desktop";
    platforms = lib.platforms.linux;
  };
}
