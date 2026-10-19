{
  bash,
  lib,
  runCommand,
  squashfsTools,
}:

# The "none" cart runtime: the fallback `.kzr` image the launcher mounts as the
# read-only lower layer of every game cart (see `NONE_RUNTIME` in the launcher).
#
# Upstream ships a prebuilt ext4 blob; here it is generated from its contents so
# the image is reproducible: a squashfs (read-only is all a lower layer needs)
# holding the `./.kazeta/share/run` entrypoint the launcher executes inside the
# merged cart mount.
#
# The entrypoint names bash's store path in its shebang: the kernel resolves that
# path before any PATH is consulted, and NixOS has no `/bin/bash`.
runCommand "kazeta-runtimes"
  {
    pname = "kazeta-runtimes";
    version = "0.1.0";

    nativeBuildInputs = [
      bash
      squashfsTools
    ];

    meta = with lib; {
      description = "Kazeta cart runtimes (.kzr images)";
      homepage = "https://github.com/kazetaos/kazeta";
      license = licenses.mit;
      maintainers = [ ];
      platforms = platforms.linux;
    };
  }
  ''
    mkdir -p work/.kazeta/share $out/share/kazeta/runtimes

    printf '#! ${bash}/bin/bash\n\n${bash}/bin/bash $1\n' > work/.kazeta/share/run
    chmod 0755 work/.kazeta/share/run

    # mksquashfs honours SOURCE_DATE_EPOCH, so no explicit timestamp options are
    # needed: the image is reproducible from content alone.
    mksquashfs work $out/share/kazeta/runtimes/none.kzr \
      -noappend -no-progress -no-xattrs \
      -comp zstd -b 262144 \
      -all-root
  ''
