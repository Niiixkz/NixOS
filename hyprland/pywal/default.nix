{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = "${config.home.homeDirectory}/NixOS/hyprland/pywal/config";
in

{
  home.packages = with pkgs; [
    pywal
    imagemagick
  ];

  xdg.configFile."wal".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
