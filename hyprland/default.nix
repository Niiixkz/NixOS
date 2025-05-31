{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    foot
    nwg-look # for gdk cursor and themes
    catppuccin-gtk
    dracula-icon-theme

    swww
    pywal
    fd

    waybar
    wofi
    swaynotificationcenter
  ];

  home.file.".config/hypr/hyprland.conf".source = ./config/hyprland.conf;
  home.file.".config/hypr/random_wallpaper.sh" = {
    source = ./config/random_wallpaper.sh;
    executable = true;
  };
}
