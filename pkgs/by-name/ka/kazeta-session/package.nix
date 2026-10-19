{
  lib,
  fetchFromGitHub,
  stdenv,
  # The session script starts the launcher by absolute path, so it is built
  # against the launcher from this flake.
  kazeta,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "kazeta-session";
  version = "0.1.0";

  # Keep this rev in sync with kazeta and kazeta-mount.
  src = fetchFromGitHub {
    owner = "kazetaos";
    repo = "kazeta";
    rev = "1a09020f4ab77d0060ef5e3fe6c2d97d191917fb";
    hash = "sha256-2XOOJ5MUApIkAP7W+sayiMmt3ijXlsy/wusXIZIncNE=";
  };

  sourceRoot = "source/rootfs";

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -D -m 0755 usr/bin/kazeta-session $out/bin/kazeta-session
    install -D -m 0644 usr/share/polkit-1/rules.d/40-system-tweaks.rules \
      $out/share/polkit-1/rules.d/40-system-tweaks.rules

    # Installed under lib/systemd/system so NixOS picks the drop-in up through
    # systemd.packages: /etc/systemd/system is a generated store path, so a
    # drop-in cannot be added there with environment.etc.
    install -D -m 0644 etc/systemd/system/session-.scope.d/10-timeout.conf \
      $out/lib/systemd/system/session-.scope.d/10-timeout.conf

    # Upstream starts the launcher from /usr/bin; NixOS has no /usr/bin, so the
    # path points straight at the launcher's store path.
    substituteInPlace $out/bin/kazeta-session \
      --replace-fail "kazeta_bin=/usr/bin/kazeta" "kazeta_bin=${kazeta}/bin/kazeta"

    runHook postInstall
  '';

  # Tools the session script calls at runtime: inputplumber, busctl, wpctl,
  # poweroff.
  meta = with lib; {
    description = "Kazeta console session (greetd autologin → launcher → poweroff)";
    homepage = "https://github.com/kazetaos/kazeta";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "kazeta-session";
  };
})
