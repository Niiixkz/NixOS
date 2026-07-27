{ pkgs, inputs, ... }:

{
  packages = [
    pkgs.cava
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."cava".source =
        config.lib.file.mkOutOfStoreSymlink "/home/niiixkz/NixOS/modules/cli/cava/config";
    };
}
