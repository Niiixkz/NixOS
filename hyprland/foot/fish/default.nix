{
  config,
  pkgs,
  lib,
  ...
}:
let
  fishPath = "${config.home.homeDirectory}/nixos/hyprland/foot/fish/config";
in
{
  xdg.configFile."fish".source = config.lib.file.mkOutOfStoreSymlink fishPath;
}
