{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  home.packages = with pkgs; [
    discord
    hyprlock
    obs-studio
    osu-lazer-bin
  ];

  imports = [
    ./eww
    ./firefox
    ./foot
    ./hyprland
    ./miku-cursor
    ./quickshell
  ];
}
