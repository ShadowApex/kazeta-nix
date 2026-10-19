{
  config,
  lib,
  kazetaPkgs,
  ...
}:

let
  cfg = config.services.kazeta.automount;
in
{
  options.services.kazeta.automount = with lib; {
    enable = mkEnableOption ''
      udev-driven automount of removable media under /run/media so a plugged-in game
      cart shows up in the launcher without a desktop environment
    '';

    package = mkPackageOption kazetaPkgs "kazeta-automount" { };

    mediaDir = mkOption {
      type = types.str;
      default = "/run/media";
      description = "Parent directory cart mounts appear in.";
    };
  };

  config = lib.mkIf cfg.enable {
    # One package provides both the udev rule and the template unit.
    services.udev.packages = [ cfg.package ];
    systemd.packages = [ cfg.package ];

    environment.systemPackages = [ cfg.package ];

    environment.etc."media-automount.d/auto".source = "${cfg.package}/share/media-automount.d/auto";

    systemd.tmpfiles.rules = [ "d ${cfg.mediaDir} 0755 root root -" ];

    boot.kernelModules = [
      "loop"
      "vfat"
      "exfat"
      "ntfs3"
      "squashfs"
    ];
  };
}
