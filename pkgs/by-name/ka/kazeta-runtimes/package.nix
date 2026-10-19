{
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
runCommand "kazeta-runtimes"
  {
    pname = "kazeta-runtimes";
    version = "0.1.0";

    nativeBuildInputs = [ squashfsTools ];

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

    printf '#! /bin/bash\n\nbash $1\n' > work/.kazeta/share/run
    chmod 0755 work/.kazeta/share/run

    # mksquashfs honours SOURCE_DATE_EPOCH, so no explicit timestamp options are
    # needed: the image is reproducible from content alone.
    mksquashfs work $out/share/kazeta/runtimes/none.kzr \
      -noappend -no-progress -no-xattrs \
      -comp zstd -b 262144 \
      -all-root
  ''
