{
  lib,
  rustPlatform,
  fetchFromGitHub,
  alsa-lib,
  eudev,
  libevdev,
  libGL,
  libX11,
  libxi,
  libxkbcommon,
  makeWrapper,
  pkg-config,
  # The launcher hardcodes the fallback cart runtime as
  # /usr/share/kazeta/runtimes/none.kzr; NixOS has no /usr/share, so the path is
  # rewritten to the runtime image this flake builds.
  kazetaRuntimes,
}:

let
  noneRuntime = "${kazetaRuntimes}/share/kazeta/runtimes/none.kzr";
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "kazeta";
  version = "0.1.0";

  # Keep this rev in sync with kazeta-mount and kazeta-session.
  src = fetchFromGitHub {
    owner = "kazetaos";
    repo = "kazeta";
    rev = "1a09020f4ab77d0060ef5e3fe6c2d97d191917fb";
    hash = "sha256-2XOOJ5MUApIkAP7W+sayiMmt3ijXlsy/wusXIZIncNE=";
  };

  sourceRoot = "source/bios";

  cargoHash = "sha256-wG8odGVAufoz1sMBeVFjsWAWgctIfhLEou77dhpHdqc=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    alsa-lib
    eudev
    libevdev
  ];

  postPatch = ''
    substituteInPlace src/launcher.rs \
      --replace-fail '"/usr/share/kazeta/runtimes/none.kzr"' "\"${noneRuntime}\""
  '';

  # macroquad (miniquad) dlopens libX11, libxkbcommon and libXi, in that order,
  # plus OpenGL and ALSA, and gilrs/evdev need libudev/libevdev. None of it is
  # linked statically, so all of it has to be visible in LD_LIBRARY_PATH; a
  # missing library aborts the launcher inside gamescope.
  postInstall = ''
    wrapProgram $out/bin/kazeta \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          alsa-lib
          eudev
          libevdev
          libGL
          libX11
          libxi
          libxkbcommon
        ]
      }"
  '';

  meta = with lib; {
    description = "Kazeta game cart launcher";
    homepage = "https://github.com/kazetaos/kazeta";
    changelog = "https://github.com/kazetaos/kazeta/releases";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "kazeta";
    platforms = platforms.linux;
  };
})
