{
  config,
  lib,
  kazetaPkgs,
  ...
}:

let
  cfg = config.services.kazeta.inputplumber;
in
{
  options.services.kazeta.inputplumber = with lib; {
    enable = mkEnableOption ''
      InputPlumber gamepad handling with Kazeta's device profiles: every pad is
      standardised onto one Xbox-style emulated target
    '';

    package = mkOption {
      type = types.package;
      default = kazetaPkgs.kazeta-inputplumber;
      defaultText = lib.literalExpression "kazetaPkgs.kazeta-inputplumber";
      example = lib.literalExpression "pkgs.inputplumber";
      description = "InputPlumber package whose device profiles are installed system-wide.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Kazeta's profiles replace nixpkgs' InputPlumber so only one copy of the
    # device configs lands in the system profile; Arch does the same with sed.
    nixpkgs.overlays = [
      (final: prev: {
        inputplumber = cfg.package;
      })
    ];

    services.inputplumber = {
      enable = true;
      package = cfg.package;
    };

    # /run/current-system/sw/share/inputplumber is where the daemon finds its
    # device profiles; without linking, only one package's share dir would win.
    environment.pathsToLink = [ "/share/inputplumber" ];
  };
}
