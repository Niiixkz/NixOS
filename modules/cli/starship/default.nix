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
      xdg.configFile."starship.toml".source = config.lib.file.mkOutOfStoreSymlink ./config/starship.toml;
    };
}
