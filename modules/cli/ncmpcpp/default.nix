{ pkgs, inputs, ... }:

{
  packages = [
    pkgs.ncmpcpp
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."ncmpcpp".source =
        config.lib.file.mkOutOfStoreSymlink "/home/niiixkz/NixOS/modules/cli/ncmpcpp/config";
    };
}
