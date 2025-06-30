{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = "${config.home.homeDirectory}/NixOS/music/cava/config";
in
{
  home.packages = with pkgs; [
    cava
  ];

  xdg.configFile."cava".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
