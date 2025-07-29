{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = "${config.home.homeDirectory}/NixOS/hyprland/wlogout/config";
in

{
  home.packages = with pkgs; [
    wlogout
  ];

  xdg.configFile."wlogout".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
