{
  config,
  lib,
  pkgs,
  kazetaPkgs,
  ...
}:

let
  cfg = config.services.kazeta.mount;

  # Used for the persistent cart data dirs.
  sessionUser = lib.attrByPath [ "services" "kazeta" "session" "user" ] "gamer" config;
in
{
  options.services.kazeta.mount = with lib; {
    enable = mkEnableOption ''
      Kazeta game cart mounting: the kazeta-mount helper and the polkit policy
      that lets the console user mount carts without a password
    '';

    package = mkPackageOption kazetaPkgs "kazeta-mount" { };

    dataDir = mkOption {
      type = types.str;
      default = "/var/kazeta";
      description = "Persistent game and cart data. Kept out of the home directory so a reinstall does not touch saves.";
    };
  };

  config = lib.mkIf cfg.enable {
    # kazeta-mount is invoked as `pkexec kazeta-mount ...` by the launcher; the
    # polkit rule shipped with the package approves it for the wheel group.
    security.polkit.enable = true;

    # polkit only reads rules from /etc/polkit-1/rules.d, so the package's rule
    # has to be linked into the system for pkexec to see it.
    environment.etc."polkit-1/rules.d/40-kazeta.rules".source =
      "${cfg.package}/share/polkit-1/rules.d/40-kazeta.rules";

    # pkexec needs a setuid helper to be usable from a normal user session.
    security.polkit.enablePkexecWrapper = true;

    environment.systemPackages = [
      cfg.package
      pkgs.fuse3
    ];

    systemd.tmpfiles.rules = [
      # Ported from the Arch image's /var/kazeta plus the XDG symlinks.
      "d ${cfg.dataDir} 0750 ${sessionUser} ${sessionUser} -"
      "d ${cfg.dataDir}/state 0750 ${sessionUser} ${sessionUser} -"
      "d ${cfg.dataDir}/state/wireplumber 0750 ${sessionUser} ${sessionUser} -"
      "d /home/${sessionUser}/.local 0755 ${sessionUser} ${sessionUser} -"
      "d /home/${sessionUser}/.local/share 0755 ${sessionUser} ${sessionUser} -"
      "d /home/${sessionUser}/.local/state 0755 ${sessionUser} ${sessionUser} -"
      "L /home/${sessionUser}/.local/share/kazeta - ${sessionUser} ${sessionUser} ${cfg.dataDir}"
      "L /home/${sessionUser}/.local/state/wireplumber - ${sessionUser} ${sessionUser} ${cfg.dataDir}/state/wireplumber"
    ];

    boot.kernelModules = [
      "loop"
      "overlay"
    ];
  };
}
