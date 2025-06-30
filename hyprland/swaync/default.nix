{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = "${config.home.homeDirectory}/NixOS/hyprland/swaync/config";
in

{
  home.packages = with pkgs; [
    swaynotificationcenter
  ];

  xdg.configFile."swaync".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
