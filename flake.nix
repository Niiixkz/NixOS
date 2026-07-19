{
  description = "NixOS Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      collectNixFiles =
        dir:
        let
          entries = builtins.readDir dir;

          files = builtins.filter (n: builtins.match ".*\\.nix" n != null) (builtins.attrNames entries);

          here = map (n: dir + "/${n}") files;

          children = builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries);
        in
        here ++ builtins.concatMap (n: collectNixFiles (dir + "/${n}")) children;

      paths = collectNixFiles ./modules;

      packages = builtins.concatLists (map (path: (import path { inherit pkgs inputs; }).packages) paths);
      nixosModules = map (path: (import path { inherit pkgs inputs; }).nixosModules) paths;
      homeModules = map (path: (import path { inherit pkgs inputs; }).homeModules) paths;
    in
    {
      nixosConfigurations = {
        NixOS = nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [
            ./hardware-configuration.nix
            nixos-hardware.nixosModules.asus-zephyrus-ga401

            home-manager.nixosModules.home-manager
            {
              environment.systemPackages = packages;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.niiixkz = {
                imports = homeModules;

                home.stateVersion = "25.05";
              };
            }
          ]
          ++ nixosModules;
        };
      };
    };
}
