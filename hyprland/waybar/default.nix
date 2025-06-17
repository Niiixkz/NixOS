{
  config,
  pkgs,
  lib,
  ...
}:
let
  waybarPath = "${config.home.homeDirectory}/nixos/hyprland/waybar/config";
in

{
  home.packages = with pkgs; [
    waybar
  ];

  xdg.configFile."waybar".source = config.lib.file.mkOutOfStoreSymlink waybarPath;
}
