{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
    pkgs.ncmpcpp
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."ncmpcpp".source = config.lib.file.mkOutOfStoreSymlink "${diskDir}/config";
    };
}
