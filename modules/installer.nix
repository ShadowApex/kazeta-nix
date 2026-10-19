{ lib, pkgs, ... }:

{
  # The live image *is* Kazeta: no installer program, no desktop environment.
  imports = [ ./kazeta.nix ];

  # The installation profile autologins as `nixos` through getty; Kazeta uses
  # greetd and the console user.
  services.getty.autologinUser = lib.mkForce null;

  # NetworkManager is the only stack that works on the live image (Wi-Fi, no
  # persisted .network files), so Kazeta's networkd is switched off to avoid two
  # stacks racing. State is tmpfs here, so the persistent dirs are ephemeral.
  networking.useNetworkd = lib.mkForce false;
  systemd.network.enable = lib.mkForce false;
  services.resolved.enable = lib.mkForce false;

  # The installation profile offers Memtest86+ on the boot menu, but the package
  # is x86-only.
  boot.loader.grub.memtest86.enable = lib.mkForce pkgs.stdenv.hostPlatform.isx86_64;

  isoImage.volumeID = lib.mkDefault "kazeta";
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
}
