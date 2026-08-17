{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
    pkgs.clementine
    pkgs.obs-studio
    pkgs.osu-lazer-bin
    pkgs.sillytavern
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
    };
}
