{ pkgs, inputs, ... }:

{
  packages = [
    pkgs.pywal
    pkgs.imagemagick
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."wal".source = config.lib.file.mkOutOfStoreSymlink ./config;
    };
}
