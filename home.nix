{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.username = "niiixkz";
  home.homeDirectory = "/home/niiixkz";

  programs.git = {
    enable = true;
    userName = "Niiixkz";
    userEmail = "niiixkz@gmail.com";
  };

  imports = [
    ./hyprland/default.nix
    ./tools/default.nix
    ./music/default.nix
    ./game/default.nix
  ];

  home.stateVersion = "25.05";
}
