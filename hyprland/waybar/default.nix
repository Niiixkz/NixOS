{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = "${config.home.homeDirectory}/NixOS/hyprland/waybar/config";
in

{
  home.packages = with pkgs; [
    waybar
  ];

  xdg.configFile."waybar".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
