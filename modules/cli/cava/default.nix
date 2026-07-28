{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
    pkgs.cava
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."cava".source = config.lib.file.mkOutOfStoreSymlink "${diskDir}/config";
    };
}
