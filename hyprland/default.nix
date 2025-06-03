{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    nwg-look # for gdk cursor and themes
    catppuccin-gtk
    dracula-icon-theme

    swww
    pywal
    fd

    wofi
  ];

  home.file.".config/hypr/hyprland.conf".source = ./config/hyprland.conf;
  home.file.".config/hypr/random_wallpaper.sh" = {
    source = ./config/random_wallpaper.sh;
    executable = true;
  };
  home.file.".config/hypr/wallpapers" = {
    source = ./config/wallpapers;
    recursive = true;
  };

  imports = [
    ./waybar/default.nix
    ./swaync/default.nix
    ./foot/default.nix
  ];
}
