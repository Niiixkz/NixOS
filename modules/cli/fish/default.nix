{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    programs.fish.enable = true;
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."fish".source =
        config.lib.file.mkOutOfStoreSymlink "/home/niiixkz/NixOS/modules/cli/fish/config";
    };
}
