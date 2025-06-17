{ config, pkgs, ... }:
let
  miku-cursorPath = "${config.home.homeDirectory}/nixos/hyprland/miku-cursor/config";
in
{
  xdg.configFile."${config.home.homeDirectory}/.icons/miku-cursor".source =
    config.lib.file.mkOutOfStoreSymlink miku-cursorPath;
}
