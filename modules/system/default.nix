{
  pkgs,
  inputs,
  diskDir,
  ...
}:

let
  entries = builtins.readDir ./.;

  nixFiles = builtins.filter (n: n != "default.nix" && builtins.match ".*\\.nix" n != null) (
    builtins.attrNames entries
  );

  importedModules = map (n: import (./. + "/${n}")) nixFiles;

  nixos-hardware = inputs.nixos-hardware.nixosModules.asus-zephyrus-ga401;
in
{
  packages = [
  ];

  nixosModules = {
    imports = [ nixos-hardware ] ++ importedModules;
  };

  homeModules =
    { config, ... }:
    {
    };
}
