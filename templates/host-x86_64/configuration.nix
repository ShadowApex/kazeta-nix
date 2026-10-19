# Host-specific settings only. The console itself comes from
# kazeta.nixosModules.default; run `nixos-generate-config` to create
# hardware-configuration.nix for the machine you are installing on.
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.05";
}
