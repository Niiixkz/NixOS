{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = "${config.home.homeDirectory}/NixOS/music/ncmpcpp/config";
in
{
  home.packages = with pkgs; [
    ncmpcpp
  ];

  xdg.configFile."ncmpcpp".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
