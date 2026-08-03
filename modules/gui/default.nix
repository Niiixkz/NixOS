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
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
    };
}
