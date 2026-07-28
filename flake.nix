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

    helix = {
      url = "github:helix-editor/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixd = {
      url = "github:nix-community/nixd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qml-language-server = {
      url = "github:cushycush/qml-language-server";
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
      root = "/home/niiixkz/NixOS";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      collectModules =
        evalDir: diskDir:
        let
          entries = builtins.readDir evalDir;

          nixFiles = builtins.filter (n: builtins.match ".*\\.nix" n != null) (builtins.attrNames entries);

          nixFileAttrs = map (n: {
            evalPath = evalDir + "/${n}";
            diskDir = diskDir;
          }) nixFiles;

          subdirs = builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries);
        in
        nixFileAttrs
        ++ builtins.concatMap (
          subdir: collectModules "${evalDir}/${subdir}" "${diskDir}/${subdir}"
        ) subdirs;

      nixFileAttrs = collectModules ./modules "${root}/modules";

      mods = map (
        nixFileAttr:
        import nixFileAttr.evalPath {
          inherit pkgs inputs;
          inherit (nixFileAttr) diskDir;
        }
      ) nixFileAttrs;

      packages = builtins.concatLists (map (mod: mod.packages) mods);
      nixosModules = map (mod: mod.nixosModules) mods;
      homeModules = map (mod: mod.homeModules) mods;
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
