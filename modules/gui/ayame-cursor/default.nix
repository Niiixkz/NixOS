{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."${config.home.homeDirectory}/.icons/ayame-cursor".source =
        config.lib.file.mkOutOfStoreSymlink "${diskDir}/config";
    };
}
