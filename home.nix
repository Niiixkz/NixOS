{ config, pkgs, ... }:

{
  home.username = "niiixkz";
  home.homeDirectory = "/home/niiixkz";

  home.packages = with pkgs; [
    foot
  ];

  programs.git = {
    enable = true;
    userName = "Niiixkz";
    userEmail = "niiixkz@gmail.com";
  };

  programs.firefox.enable = true;

  imports = [
    ./hyprland/default.nix
    ./miku-cursor/default.nix
  ];

  home.stateVersion = "25.05";
}
