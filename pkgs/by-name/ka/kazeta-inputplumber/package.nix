{
  lib,
  inputplumber,
  runCommand,
}:

# InputPlumber device profiles with Kazeta's overrides applied.
#
# Upstream emulates a Steam Deck, DualSense or Switch Pro controller depending
# on the connected pad; Kazeta standardises every pad onto one Xbox-style
# target, so the launcher always sees the same layout. Arch rewrites the
# installed YAML with sed; here the rewrite happens at build time, so the
# patched profiles are reproducible.
#
# Only `devices/` is rebuilt; the rest is symlinked from nixpkgs so the override
# stays cheap and tracks nixpkgs updates.
runCommand "kazeta-inputplumber-${inputplumber.version}"
  {
    pname = "kazeta-inputplumber";
    version = inputplumber.version;

    meta = with lib; {
      description = "InputPlumber device profiles rewritten to a single Xbox-style target";
      homepage = "https://github.com/kazetaos/kazeta";
      license = licenses.mit;
      maintainers = [ ];
      platforms = platforms.linux;
      mainProgram = "inputplumber";
    };

    passthru = {
      inherit inputplumber;
      updateScript = inputplumber.updateScript;
    };
  }
  ''
    mkdir -p $out/bin $out/share/inputplumber

    for f in ${inputplumber}/bin/*; do
      ln -s "$f" $out/bin/
    done

    if [ -d ${inputplumber}/lib ]; then
      ln -s ${inputplumber}/lib $out/lib
    fi

    for d in ${inputplumber}/share/inputplumber/*; do
      name=$(basename "$d")
      if [ "$name" = "devices" ]; then
        continue
      fi
      ln -s "$d" $out/share/inputplumber/$name
    done

    cp -r ${inputplumber}/share/inputplumber/devices $out/share/inputplumber/devices
    chmod -R u+w $out/share/inputplumber/devices

    # Kazeta overrides: every emulated target becomes the generic Xbox profile.
    for cap in hori-steam gamepad deck-uhid deck xbox-elite xb360 ds5-edge ds5 8bitdo-u2; do
      sed -i "s/^\([[:space:]]*\)- $cap[[:space:]]*$/\1- xbox-series/" \
        $out/share/inputplumber/devices/*.yaml
    done
  ''
