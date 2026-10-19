{
  description = "Kazeta OS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      # Kazeta is a gaming console image: gamescope, 32-bit game binaries and
      # NVIDIA support only make sense on x86_64 today.
      systems = [ "x86_64-linux" ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Custom packages, or nixpkgs ones that need Kazeta-specific changes.
      packagesForSystem =
        pkgs: with pkgs; {
          kazeta = callPackage ./pkgs/by-name/ka/kazeta/package.nix { };
          kazeta-automount = callPackage ./pkgs/by-name/ka/kazeta-automount/package.nix { };
          kazeta-inputplumber = callPackage ./pkgs/by-name/ka/kazeta-inputplumber/package.nix { };
          kazeta-mount = callPackage ./pkgs/by-name/ka/kazeta-mount/package.nix { };
          kazeta-runtimes = callPackage ./pkgs/by-name/ka/kazeta-runtimes/package.nix { };
          kazeta-session = callPackage ./pkgs/by-name/ka/kazeta-session/package.nix { };
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
        x86_64 = {
          path = ./templates/host-x86_64;
          description = "A Kazeta host";
          welcomeText = ''
            # Kazeta configuration
            You're ready to start using Kazeta!

            ## Usage
            Apply the configuration with:
            `sudo nixos-rebuild switch`
          '';
        };
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      # Reference: https://haseebmajid.dev/posts/2024-02-04-how-to-create-a-custom-nixos-iso/
      nixosConfigurations = {
        iso-x86_64 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            kazeta = self;
            kazetaPkgs = self.packages."x86_64-linux";
          };
          # The live image boots straight into the Kazeta launcher; there is no
          # installer program, the ISO *is* the system.
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
            self.nixosModules.installer
          ];
        };
      };
    };
}
