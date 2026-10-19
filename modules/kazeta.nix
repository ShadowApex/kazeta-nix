{
  lib,
  pkgs,
  kazetaPkgs,
  ...
}:

let
  # 32-bit multilib and the NVIDIA driver stack only exist for x86_64 in
  # nixpkgs; an aarch64 console uses mesa and its SoC's own KMS driver.
  x86Only = pkgs.stdenv.hostPlatform.isx86_64;
in
{
  imports = [ ./services ];

  # Kazeta is a game console, not a desktop: autologin, a gamescope launcher,
  # carts mounted from removable media. Behaviour mirrors the Arch image in
  # github.com/kazetaos/kazeta, audited in README.md.
  services.kazeta.session.enable = true;
  services.kazeta.mount.enable = true;
  services.kazeta.automount.enable = true;
  services.kazeta.inputplumber.enable = true;

  # ─── Boot ───────────────────────────────────────────────────────────────────
  # Parity with Arch's rolling `linux`; gamescope needs the newest drivers.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
  ]
  ++ lib.optionals x86Only [
    "nvidia-drm.modeset=1"
  ];
  # kmscon renders the VT itself, so no fbdev fallback. vkms provides a KMS
  # device when there is no GPU.
  services.kmscon = {
    enable = true;
    config = {
      fbdev = false;
    };
  };

  boot.initrd.availableKernelModules = [
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sr_mod"
    "mmc_block"
  ]
  ++ lib.optionals x86Only [
    # PCI host controllers as PC firmware enumerates them; on aarch64 the
    # board's own controller drivers come from its generated hardware config.
    "xhci_pci"
    "ehci_pci"
    "ahci"
  ];
  boot.extraModulePackages = [ ];

  # ─── Identity ───────────────────────────────────────────────────────────────
  # So lsb-release and the launcher report Kazeta, not generic NixOS.
  system.nixos.variantName = "Kazeta";
  system.nixos.variant_id = "kazeta";

  i18n.defaultLocale = "en_US.UTF-8";

  # FNA/XNA titles resolve their timezone through /etc/localtime.
  time.timeZone = lib.mkDefault "UTC";

  fonts.packages = [ pkgs.liberation_ttf ];

  # ─── Networking ─────────────────────────────────────────────────────────────
  # Parity with the Arch image's SERVICES list.
  networking.useNetworkd = true;
  services.resolved.enable = true;

  systemd.network = {
    enable = true;
    networks."00-kazeta-ethernet" = {
      matchConfig.Name = "en*";
      networkConfig = {
        DHCP = true;
        IPv6PrivacyExtensions = true;
      };
    };
  };

  # ─── Audio ──────────────────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  security.rtkit.enable = true;

  # Arch disabled the iec958 (S/PDIF) profile by editing alsa-card-profile's
  # mixer config, which NixOS ships read-only: S/PDIF is pushed to the bottom of
  # the session priority order instead.

  # SPA-JSON unescapes string values once, so every regex backslash is written
  # doubled here.
  environment.etc."wireplumber/wireplumber.conf.d/51-kazeta.conf".text = ''
    wireplumber.settings = {
      device.routes.default-sink-volume = 0.9
    }

    monitor.alsa.rules = [
      {
        matches = [ { node.name = "~alsa_output\\..*\\.hdmi.*" } ]
        actions = { update-props = { priority.session = 1300 } }
      }
      {
        matches = [ { node.name = "~alsa_output\\.usb-.*" } ]
        actions = { update-props = { priority.session = 1400 } }
      }
      {
        matches = [ { node.name = "~alsa_output\\..*iec958.*" } ]
        actions = { update-props = { priority.session = -1 } }
      }
    ]
  '';

  # ─── Graphics and games ─────────────────────────────────────────────────────
  programs.gamescope.enable = true;

  # 32-bit Vulkan and OpenGL are required: most of the catalog is 32-bit Windows
  # or Linux builds running through Wine or Steam. The i686 package set behind
  # them is only defined for x86_64.
  hardware.graphics = {
    enable = true;
    enable32Bit = x86Only;
  };

  # Read-only, derived from the X server's video driver list; gamescope runs
  # without an X server, so the modules are loaded explicitly.
  services.xserver.videoDrivers = lib.optionals x86Only [ "nvidia" ];

  hardware.nvidia = lib.optionalAttrs x86Only {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    powerManagement.enable = false;
  };

  boot.kernelModules = [
    "vkms"
  ]
  ++ lib.optionals x86Only [
    "nvidia"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  hardware.enableRedistributableFirmware = true;
  # Carts ship prebuilt game binaries that expect a normal Linux filesystem
  # layout; nix-ld supplies the libraries they try to load.
  programs.nix-ld = {
    enable = true;
    libraries = [
      pkgs.alsa-lib
      pkgs.cairo
      pkgs.expat
      pkgs.icu
      pkgs.stdenv.cc.cc.lib
      pkgs.glibc
      pkgs.keyutils
      pkgs.libGL
      pkgs.libdrm
      pkgs.libunwind
      pkgs.ncurses5
      pkgs.stdenv.cc.cc
      pkgs.systemd
      pkgs.vulkan-loader
      pkgs.libx11
      pkgs.libxcursor
      pkgs.libxfixes
      pkgs.libxi
      pkgs.libxrandr
    ]
    ++ pkgs.steam-run.args.multiPkgs pkgs;
  };

  # ─── Security ───────────────────────────────────────────────────────────────
  security.polkit.enable = true;

  # Policy: the console account has no password, so wheel gets sudo without one.
  security.sudo.wheelNeedsPassword = false;

  # ─── Nix policy ─────────────────────────────────────────────────────────────
  # Carts carry whatever licensing they carry, so unfree packages are accepted
  # outright instead of named one by one.
  nixpkgs.config.allowUnfree = true;

  # Hosts are rebuilt from their own flake, which needs both new CLI features.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.nixPath = [ "nixpkgs=channel:nixos-unstable" ];

  # ─── Maintenance ────────────────────────────────────────────────────────────
  services.fstrim.enable = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  # ─── Packages ───────────────────────────────────────────────────────────────
  # Parity with the Arch manifest: pipewire, gamescope, greetd, inputplumber,
  # wireplumber, sudo and rtkit come from the options above; the rest are the
  # console utilities the image ships.
  environment.systemPackages =
    with pkgs;
    [
      fuse2
      fuse3
      htop
      less
      lsb-release
      vim
      which
    ]
    ++ [
      kazetaPkgs.kazeta
      kazetaPkgs.kazeta-mount
      kazetaPkgs.kazeta-session
    ];
}
