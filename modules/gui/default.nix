{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = with pkgs; [
    clementine
    kitty
    obs-studio
    osu-lazer-bin
    sillytavern
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
    };
}
