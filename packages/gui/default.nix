{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  home.packages = with pkgs; [
    clementine
    discord
    hyprlock
    obs-studio
    osu-lazer-bin
  ];

  imports = [
    ./firefox
    ./foot
    ./hyprland
    ./miku-cursor
    ./quickshell
  ];
}
