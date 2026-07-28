{
  pkgs,
  inputs,
  diskDir,
  ...
}:

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
        config.lib.file.mkOutOfStoreSymlink "${diskDir}/config/starship.toml";
    };
}
