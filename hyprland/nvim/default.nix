{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = "${config.home.homeDirectory}/NixOS/hyprland/nvim/config";
in

{
  home.packages = with pkgs; [
    neovim
  ];

  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
