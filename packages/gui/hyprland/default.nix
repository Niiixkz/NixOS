{
  config,
  pkgs,
  lib,
  ...
}:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/gui/hyprland/config";
in
{
  xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
