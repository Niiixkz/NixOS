{
  config,
  pkgs,
  lib,
  ...
}:
let
  swayncPath = "${config.home.homeDirectory}/nixos/hyprland/swaync/config";
in

{
  home.packages = with pkgs; [
    swaynotificationcenter
  ];

  xdg.configFile."swaync".source = config.lib.file.mkOutOfStoreSymlink swayncPath;
}
