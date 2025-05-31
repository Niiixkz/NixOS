{ config, pkgs, ... }:

{
  home.username = "niiixkz";
  home.homeDirectory = "/home/niiixkz";

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

  programs.git = {
    enable = true;
    userName = "Niiixkz";
    userEmail = "niiixkz@gmail.com";
  };

  programs.firefox.enable = true;
  
  # home.file."abc".text = ''
  #     xxx
  # '';

  # wayland.windowManager.hyprland.enable = true;

  # programs.hyprland = {
  #   enable = true;
  #   withUWSM = true;
  #   xwayland.enable = true;
  # };

  home.stateVersion = "25.05";
}
