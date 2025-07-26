{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = "${config.home.homeDirectory}/NixOS/hyprland/config";
in
{
  home.packages = with pkgs; [
    hyprlock

    swww
    fd

    discord
    betterdiscordctl

    obs-studio
  ];

  gtk = {
    enable = true;
    theme = {
      name = "Materia-dark";
      package = pkgs.materia-theme;
    };
    iconTheme = {
      name = "Dracula";
      package = pkgs.dracula-icon-theme;
    };
    cursorTheme = {
      name = "miku-cursor";
      size = 28;
    };

    gtk2.extraConfig = ''
      gtk-im-module = "fcitx"
    '';

    gtk3.extraConfig = {
      gtk-im-module = "fcitx";
    };

    gtk4.extraConfig = {
      gtk-im-module = "fcitx";
    };
  };

  xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink configPath;

  imports = [
    ./waybar/default.nix
    ./wofi/default.nix
    ./swaync/default.nix
    ./foot/default.nix
    ./miku-cursor/default.nix
    ./firefox/default.nix
    ./pywal/default.nix
    ./nvim/default.nix
    ./fcitx5/default.nix
  ];
}
