{
  config,
  pkgs,
  lib,
  ...
}:
let
  cavaPath = "${config.home.homeDirectory}/nixos/music/cava/config";
in
{
  home.packages = with pkgs; [
    cava
  ];

  xdg.configFile."cava".source = config.lib.file.mkOutOfStoreSymlink cavaPath;
}
