{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = "${config.home.homeDirectory}/NixOS/hyprland/foot/fish/config";
in
{
  xdg.configFile."fish".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
