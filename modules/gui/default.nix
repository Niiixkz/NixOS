{ pkgs, inputs, ... }:

{
  packages = [
    pkgs.clementine
    pkgs.discord
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
