{ config, pkgs, ... }:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/gui/miku-cursor/config";
in
{
  xdg.configFile."${config.home.homeDirectory}/.icons/miku-cursor".source =
    config.lib.file.mkOutOfStoreSymlink configPath;
}
