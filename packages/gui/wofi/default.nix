{
  config,
  pkgs,
  lib,
  ...
}:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/gui/wofi/config";
in
{
  home.packages = with pkgs; [
    wofi
  ];

  xdg.configFile."wofi".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
