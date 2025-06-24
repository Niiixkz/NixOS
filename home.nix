{
  config,
  pkgs,
  lib,
  ...
}:
let
  bashrcPath = "${config.home.homeDirectory}/nixos/home-config/.bashrc";
in
{
  home.username = "niiixkz";
  home.homeDirectory = "/home/niiixkz";

  programs.git = {
    enable = true;
    userName = "Niiixkz";
    userEmail = "niiixkz@gmail.com";
  };

  xdg.configFile."${config.home.homeDirectory}/.bashrc".source =
    config.lib.file.mkOutOfStoreSymlink bashrcPath;

  imports = [
    ./hyprland/default.nix
    ./tools/default.nix
    ./music/default.nix
    ./game/default.nix
  ];

  home.stateVersion = "25.05";
}
