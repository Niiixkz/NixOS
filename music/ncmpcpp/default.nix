{
  config,
  pkgs,
  lib,
  ...
}:
let
  ncmpcppPath = "${config.home.homeDirectory}/nixos/music/ncmpcpp/config";
in
{
  home.packages = with pkgs; [
    ncmpcpp
  ];

  xdg.configFile."ncmpcpp".source = config.lib.file.mkOutOfStoreSymlink ncmpcppPath;
}
