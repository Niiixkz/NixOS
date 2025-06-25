{
  config,
  pkgs,
  lib,
  ...
}:
let
  hyprlandPath = "${config.home.homeDirectory}/nixos/hyprland/config";
in
{
  home.packages = with pkgs; [
    hyprlock

    swww
    fd

    discord
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
  };

  xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink hyprlandPath;

  imports = [
    ./waybar/default.nix
    ./wofi/default.nix
    ./swaync/default.nix
    ./foot/default.nix
    ./miku-cursor/default.nix
    ./firefox/default.nix
    ./pywal/default.nix
    ./nvim/default.nix
  ];
}
