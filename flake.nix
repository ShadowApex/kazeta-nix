{
  description = "Kazeta OS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      # Kazeta is a gaming console image. It runs on both x86_64 and aarch64;
      # the x86-only parts (32-bit game binaries, NVIDIA) are gated inside the
      # modules rather than by dropping the architecture.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Custom packages, or nixpkgs ones that need Kazeta-specific changes.
      packagesForSystem =
        pkgs:
        with pkgs;
        let
          # The launcher reaches its fallback runtime by absolute path and the
          # session script starts the launcher by absolute path, so both are
          # wired to the packages built here.
          kazetaRuntimes = callPackage ./pkgs/by-name/ka/kazeta-runtimes/package.nix { };
          kazeta = callPackage ./pkgs/by-name/ka/kazeta/package.nix { inherit kazetaRuntimes; };
        in
        {
          inherit kazeta;
          kazeta-automount = callPackage ./pkgs/by-name/ka/kazeta-automount/package.nix { };
          kazeta-inputplumber = callPackage ./pkgs/by-name/ka/kazeta-inputplumber/package.nix { };
          kazeta-mount = callPackage ./pkgs/by-name/ka/kazeta-mount/package.nix { };
          kazeta-runtimes = kazetaRuntimes;
          kazeta-session = callPackage ./pkgs/by-name/ka/kazeta-session/package.nix { inherit kazeta; };
        };

      # A host flake for one architecture, named without the -linux suffix.
      hostTemplate = arch: {
        path = ./templates/host-${arch};
        description = "A Kazeta host on ${arch}";
        welcomeText = ''
          # Kazeta configuration
          You're ready to start using Kazeta!

          ## Usage
          Apply the configuration with:
          `sudo nixos-rebuild switch`
        '';
      };

      # The live image boots straight into the Kazeta launcher; there is no
      # installer program, the ISO *is* the system.
      # Reference: https://haseebmajid.dev/posts/2024-02-04-how-to-create-a-custom-nixos-iso/
      isoFor =
        system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            kazeta = self;
            kazetaPkgs = self.packages.${system};
          };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
            self.nixosModules.installer
          ];
        };
    in
    {
      nixosModules = {
        default = ./modules/kazeta.nix;
        installer = ./modules/installer.nix;
      };

      packages = forAllSystems packagesForSystem;

      templates = {
        default = self.templates.x86_64;
        x86_64 = hostTemplate "x86_64";
        aarch64 = hostTemplate "aarch64";
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      nixosConfigurations = {
        iso-x86_64 = isoFor "x86_64-linux";
        iso-aarch64 = isoFor "aarch64-linux";
      };
    };
}
