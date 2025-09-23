{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  home.username = "niiixkz";
  home.homeDirectory = "/home/niiixkz";

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

  imports = [
    ./packages
  ];

  home.stateVersion = "25.05";
}
