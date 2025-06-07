{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    swww
    fd
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
    ./wofi/default.nix
    ./swaync/default.nix
    ./foot/default.nix
    ./miku-cursor/default.nix
    ./firefox/default.nix
    ./pywal/default.nix
  ];
}
