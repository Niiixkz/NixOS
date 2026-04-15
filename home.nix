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

  imports = [
    ./packages
  ];

  home.stateVersion = "25.05";
}
