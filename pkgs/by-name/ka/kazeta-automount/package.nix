{
  lib,
  fetchFromGitHub,
  findutils,
  gawk,
  gnugrep,
  makeWrapper,
  stdenv,
  systemd,
  util-linux,
}:

# Removable-media automount for game carts.
#
# A cart must appear under /run/media/<label> as soon as it is plugged in, with
# no desktop environment involved. The AUR package the Arch image uses is not in
# nixpkgs, so the upstream script is packaged here with the same tweaks Arch
# applied with sed, as explicit substitutions.
stdenv.mkDerivation (finalAttrs: {
  pname = "kazeta-automount";
  version = "unstable-2020-05-08";

  src = fetchFromGitHub {
    owner = "Ferk";
    repo = "udev-media-automount";
    rev = "efca3c5a0548211c84e98de16b41641a961b6273";
    hash = "sha256-oknw9pfwCmuGDZIfcYB/p9neU50qptL31497xd1QGLs=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -D -m 0755 media-automount $out/bin/media-automount
    install -D -m 0644 media-automount@.service $out/lib/systemd/system/media-automount@.service
    install -D -m 0644 media-automount.rules $out/lib/udev/rules.d/99-media-automount.rules

    # The NixOS module exposes these as options.
    install -D -m 0644 media-automount.d/auto $out/share/media-automount.d/auto

    # Kazeta tweaks (the Arch image applied the same edits with sed):
    #  * mount under /run/media, the FHS location NixOS uses
    #  * cart directories are named after the cart, never the filesystem type
    substituteInPlace $out/bin/media-automount \
      --replace-fail "mediadir=/media" "mediadir=/run/media" \
      --replace-fail 'AUTOMOUNT_DIR="''${mediadir}/''${LABEL:-''${dev##*/}}.$TYPE"' \
        'AUTOMOUNT_DIR="''${mediadir}/''${LABEL:-''${dev##*/}}"'

    # udev rules and the template unit must call the store paths NixOS provides.
    substituteInPlace $out/lib/systemd/system/media-automount@.service \
      --replace-fail "/usr/bin/media-automount" "$out/bin/media-automount"
    substituteInPlace $out/lib/udev/rules.d/99-media-automount.rules \
      --replace-fail "/usr/bin/systemctl" "${systemd}/bin/systemctl" \
      --replace-fail 'mmcblk[0-9]p[0-9]' 'mmcblk*'

    # Optical carts (sr*) report "change", not "add".
    cat >> $out/lib/udev/rules.d/99-media-automount.rules <<EOF
    # Kazeta: optical media
    KERNEL=="sr[0-9]*", ACTION=="change", RUN+="${systemd}/bin/systemctl --no-block restart media-automount@%k.service"
    EOF

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/media-automount \
      --prefix PATH : ${
        lib.makeBinPath [
          findutils
          gawk
          gnugrep
          systemd
          util-linux
        ]
      }
  '';

  meta = with lib; {
    description = "udev-driven automount of Kazeta game carts under /run/media";
    homepage = "https://github.com/Ferk/udev-media-automount";
    changelog = "https://github.com/Ferk/udev-media-automount/commits/master";
    license = licenses.gpl2Only;
    maintainers = [ ];
    platforms = platforms.linux;
  };
})
