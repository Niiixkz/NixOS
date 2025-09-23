{
  config,
  pkgs,
  lib,
  ...
}:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/gui/wlogout/config";
in
{
  home.packages = with pkgs; [
    wlogout
  ];

  xdg.configFile."wlogout".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
