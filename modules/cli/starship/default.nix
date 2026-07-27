{ pkgs, inputs, ... }:

{
  packages = [
    pkgs.starship
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."starship.toml".source =
        config.lib.file.mkOutOfStoreSymlink "/home/niiixkz/NixOS/modules/cli/starship/config/starship.toml";
    };
}
