{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  home.username = "niiixkz";
  home.homeDirectory = "/home/niiixkz";

  gtk = {
    enable = true;
    cursorTheme = {
      name = "ayame-cursor";
      size = 28;
    };
  };

  imports = [
    ./packages
  ];

  home.stateVersion = "25.05";
}
