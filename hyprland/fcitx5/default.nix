{
  config,
  pkgs,
  lib,
  ...
}:
let
  fcitx5Path = "${config.home.homeDirectory}/nixos/hyprland/fcitx5/config";
in
{
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-rime
        rime-data
        fcitx5-gtk
      ];
    };
  };

  xdg.configFile."fcitx5".source = config.lib.file.mkOutOfStoreSymlink fcitx5Path;
}
