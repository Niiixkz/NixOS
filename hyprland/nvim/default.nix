{
  config,
  pkgs,
  lib,
  ...
}:
let
  nvimPath = "${config.home.homeDirectory}/nixos/hyprland/nvim/config";
in

{
  home.packages = with pkgs; [
    neovim
  ];

  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink nvimPath;
}
