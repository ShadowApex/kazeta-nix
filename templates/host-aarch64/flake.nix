{
  description = "An example Kazeta host config";

  inputs = {
    kazeta.url = "github:shadowapex/kazeta-nix";
  };

  outputs =
    { self, kazeta }:
    {
      # This defines a NixOS host and what config it should use.
      nixosConfigurations.kazeta = kazeta.inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";

        specialArgs = {
          kazeta = kazeta.outputs;
          kazetaPkgs = kazeta.outputs.packages."aarch64-linux";
        };

        modules = [
          kazeta.nixosModules.default
          ./configuration.nix
        ];
      };
    };
}
