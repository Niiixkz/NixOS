{
  config,
  pkgs,
  lib,
  ...
}:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/gui/waybar/config";
in
{
  home.packages = with pkgs; [
    waybar
  ];

  xdg.configFile."waybar".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
