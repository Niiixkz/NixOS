{
  config,
  pkgs,
  lib,
  ...
}:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/cli/fcitx5/config";
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

  xdg.configFile."fcitx5".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
