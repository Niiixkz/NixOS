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
    obs-studio
    osu-lazer-bin
  ];

  imports = [
    ./ayame-cursor
    ./firefox
    ./foot
    ./hyprland
    ./quickshell
  ];
}
