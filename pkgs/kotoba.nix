{
  lib,
  stdenv,
  fetchFromGitLab,
  rustPlatform,
  cargo,
  rustc,
  meson,
  ninja,
  pkg-config,
  wrapGAppsHook4,
  desktop-file-utils,
  gtk4,
  libadwaita,
  sqlite,
}:

stdenv.mkDerivation rec {
  pname = "kotoba";
  version = "unstable-2026";

  src = fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "haydn";
    repo = "kotoba";
    rev = "main";
    hash = "sha256-DVXwstm+6XVQybdro3dbn5R6JnFHxfS+iYqm/P5S5eo=";
  };
cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = "sha256-3juPjaGGQxJQvNjRm7GGZbV8AL9YUKUHwpPHbJyIJuM=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    wrapGAppsHook4
    desktop-file-utils
    rustPlatform.cargoSetupHook
    cargo
    rustc
  ];

  buildInputs = [
    gtk4
    libadwaita
    sqlite
  ];

  meta = with lib; {
    description = "Offline Japanese-English dictionary app built with GTK4 and Rust";
    homepage = "https://gitlab.gnome.org/haydn/kotoba";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "kotoba";
  };
}
