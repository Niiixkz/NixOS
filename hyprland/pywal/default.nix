{
  config,
  pkgs,
  lib,
  ...
}:
let
  pywalPath = "${config.home.homeDirectory}/nixos/hyprland/pywal/config";
in

{
  home.packages = with pkgs; [
    pywal
    imagemagick
  ];

  xdg.configFile."wal".source = config.lib.file.mkOutOfStoreSymlink pywalPath;
}
