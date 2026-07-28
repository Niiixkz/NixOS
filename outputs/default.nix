{
  self,
  nixpkgs,
  home-manager,
  ...
}@inputs:

let
  system = "x86_64-linux";
  root = "/home/niiixkz/NixOS";

  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  collected = import ../lib/collectModules.nix {
    inherit pkgs inputs root;
  };
in
{
  nixosConfigurations.NixOS = nixpkgs.lib.nixosSystem {
    inherit system pkgs;

    modules = [
      home-manager.nixosModules.home-manager
      {
        environment.systemPackages = collected.packages;

        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.niiixkz = {
          imports = collected.homeModules;

          home.stateVersion = "25.05";
        };
      }
    ]
    ++ collected.nixosModules;
  };
}
