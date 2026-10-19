{
  config,
  lib,
  pkgs,
  kazetaPkgs,
  ...
}:

let
  cfg = config.services.kazeta.session;
in
{
  options.services.kazeta.session = with lib; {
    enable = mkEnableOption ''
      Kazeta console session: greetd autologin as a single user straight into the
      Kazeta launcher, with no desktop manager in between
    '';

    package = mkPackageOption kazetaPkgs "kazeta-session" { };

    launcherPackage = mkPackageOption kazetaPkgs "kazeta" { };

    user = mkOption {
      type = types.str;
      default = "gamer";
      description = "The only account Kazeta logs into automatically.";
    };

    passwordLogin = mkEnableOption ''
      password login for the Kazeta account. Disabled by default: the console logs
      in automatically and `passwd` is used to give the account a password later
    '';

    handlePowerKey = mkOption {
      type = types.enum [
        "poweroff"
        "reboot"
        "halt"
        "kexec"
        "suspend"
        "hibernate"
        "hybrid-sleep"
        "suspend-then-hibernate"
        "lock"
        "ignore"
      ];
      default = "lock";
      description = "What the power button does. A short press asks the session to quit, a long press powers off.";
    };
  };

  config = lib.mkIf cfg.enable {
    # greetd runs the launcher on VT1 as soon as the system is up. When the
    # launcher exits (the session script powers the machine off itself), greetd
    # falls back to powering off rather than dropping to a login prompt.
    services.greetd = {
      enable = true;
      settings = {
        terminal.vt = 1;
        initial_session = {
          command = lib.getExe cfg.package;
          user = cfg.user;
        };
        default_session = {
          command = "${lib.getExe' pkgs.systemd "poweroff"}";
          user = cfg.user;
        };
      };
    };

    users.groups.input = { };

    # polkit reads rules from /etc/polkit-1/rules.d only: the wheel-group policy
    # for timedate and power-off/reboot comes from the session package.
    environment.etc."polkit-1/rules.d/40-system-tweaks.rules".source =
      "${cfg.package}/share/polkit-1/rules.d/40-system-tweaks.rules";

    # Tools the session script calls at runtime: busctl/wpctl, poweroff,
    # inputplumber.
    environment.systemPackages = [
      cfg.package
      cfg.launcherPackage
    ];

    users.users.${cfg.user} = {
      isNormalUser = true;
      # wheel: polkit rules let the console user mount carts and power off;
      # input: gamescope and inputplumber talk to evdev devices.
      extraGroups = [
        "wheel"
        "input"
      ];
      initialHashedPassword = lib.mkIf (!cfg.passwordLogin) "";
    };

    services.logind = {
      # The launcher owns the session, so logind must not kill it on suspend or
      # when the lid closes on a handheld.
      settings.Login = {
        KillUserProcesses = lib.mkDefault true;
        HandlePowerKey = cfg.handlePowerKey;
        HandlePowerKeyLongPress = "poweroff";
        HandleVolumeKeys = "ignore";
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };
    };

    # The session-scope drop-in reaches /etc/systemd/system through
    # systemd.packages, not environment.etc.
    systemd.packages = [ cfg.package ];
  };
}
