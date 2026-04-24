{ config, pkgs, ... }:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/gui/ayame-cursor/config";
in
{
  xdg.configFile."${config.home.homeDirectory}/.icons/ayame-cursor".source =
    config.lib.file.mkOutOfStoreSymlink configPath;
}
