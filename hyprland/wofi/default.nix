{
  config,
  pkgs,
  lib,
  ...
}:
let
  wofiPath = "${config.home.homeDirectory}/nixos/hyprland/wofi/config";
in

{
  home.packages = with pkgs; [
    wofi
  ];

  xdg.configFile."wofi".source = config.lib.file.mkOutOfStoreSymlink wofiPath;
}
