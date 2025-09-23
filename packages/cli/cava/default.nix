{
  config,
  pkgs,
  lib,
  ...
}:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/cli/cava/config";
in
{
  home.packages = with pkgs; [
    cava
  ];

  xdg.configFile."cava".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
