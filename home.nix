{ config, pkgs, ... }:

{
  home.username = "niiixkz";
  home.homeDirectory = "/home/niiixkz";

  programs.git = {
    enable = true;
    userName = "Niiixkz";
    userEmail = "niiixkz@gmail.com";
  };

  programs.firefox.enable = true;

  imports = [
    ./hyprland/default.nix
    ./tools/default.nix
  ];

  home.stateVersion = "25.05";
}
