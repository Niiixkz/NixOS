{ config, pkgs, lib, ... }:

{
  home.username = "niiixkz";
  home.homeDirectory = "/home/niiixkz";

  programs.git = {
    enable = true;
    userName = "Niiixkz";
    userEmail = "niiixkz@gmail.com";
  };

  home.file.".bashrc".source = ./home-config/.bashrc;

  imports = [
    ./hyprland/default.nix
    ./tools/default.nix
  ];

  home.stateVersion = "25.05";
}
