{
  lib,
  fetchFromGitHub,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "kazeta-mount";
  version = "0.1.0";

  # Keep this rev in sync with kazeta and kazeta-session.
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

    install -D -m 0755 usr/bin/kazeta-mount $out/bin/kazeta-mount
    install -D -m 0644 usr/share/polkit-1/rules.d/40-kazeta.rules \
      $out/share/polkit-1/rules.d/40-kazeta.rules

    # pkexec canonicalises the program it runs, so the rule must compare against
    # the store path of this package rather than a /usr/bin symlink.
    substituteInPlace $out/share/polkit-1/rules.d/40-kazeta.rules \
      --replace-fail "/usr/bin/kazeta-mount" "$out/bin/kazeta-mount"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Kazeta game cart mount helper (overlayfs + .kzp cart packages)";
    homepage = "https://github.com/kazetaos/kazeta";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
  };
})
